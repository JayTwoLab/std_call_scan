// scanner.cpp
// 목적:
//   - 지정한 소스들(.cpp)을 AST로 파싱하여 "모든 함수 호출"을 전수 조사
//   - 각 호출의 예외 명세(noexcept 여부)를 판정하여 CSV로 출력
//
// 출력 컬럼:
//   file,line,col,kind,qualified-name,noexcept,signature,callee-source
//
// 빌드/실행은 README의 "사용 개요" 참조
//
// 주의사항:
//   - 시스템 헤더 안의 호출은 기본 제외(필요 시 주석 해제하여 포함 가능)
//   - noexcept 판정은 FunctionProtoType::isNothrow() 결과를 사용
//   - 생성자, 멤버함수, 자유함수, 연산자 호출을 모두 처리
//   - 구현(libstdc++/libc++/MSVC STL)과 템플릿 인스턴스에 따라 결과는 달라질 수 있음

#include <string>
#include <iostream>
#include <sstream>
#include <vector>
#include <utility>

#include "clang/AST/ASTContext.h"
#include "clang/AST/Type.h"
#include "clang/AST/DeclCXX.h"
#include "clang/Frontend/FrontendActions.h"
#include "clang/Tooling/CommonOptionsParser.h"
#include "clang/Tooling/Tooling.h"
#include "clang/ASTMatchers/ASTMatchFinder.h"
#include "clang/Lex/Lexer.h"
#include "llvm/Support/CommandLine.h"

using namespace clang;
using namespace clang::tooling;
using namespace clang::ast_matchers;

namespace {

// ---------------------- 옵션 정의 ----------------------

// std:: 네임스페이스 하위 호출만 보고 싶다면 1
static llvm::cl::opt<bool> OnlyStd(
  "only-std",
  llvm::cl::desc("std:: 네임스페이스 호출만 보고 (default: 0)"),
  llvm::cl::init(0));

// 접두 필터: "std::filesystem::" 처럼 특정 도메인만 걸러내기
static llvm::cl::opt<std::string> NamePrefix(
  "name-prefix",
  llvm::cl::desc("정규화 이름 접두 필터(예: std::filesystem::)"),
  llvm::cl::init(""));

// CSV 헤더 출력 여부
static llvm::cl::opt<bool> CsvHeader(
  "csv-header",
  llvm::cl::desc("CSV 헤더 출력 (default: 0)"),
  llvm::cl::init(0));

// ---------------------- 유틸 함수 ----------------------

// CSV 안전한 인용: 내부의 " 를 "" 로 이스케이프하고 전체를 "..." 로 감싼다.
static std::string csv_quote(std::string s) {
  std::string out;
  out.reserve(s.size() + 2);
  out.push_back('"');
  for (char c : s) {
    if (c == '"') out += "\"\"";
    else out.push_back(c);
  }
  out.push_back('"');
  return out;
}

// 소스 텍스트 추출(호출 지점 표시용, 너무 길면 자를 수 있음)
static std::string get_source_snippet(const SourceRange& R,
                                      const SourceManager& SM,
                                      const LangOptions& LO) {
  CharSourceRange CR = CharSourceRange::getTokenRange(R);
  llvm::StringRef SR = Lexer::getSourceText(CR, SM, LO);
  std::string s = SR.str();
  // 너무 긴 경우 절단(가독 목적)
  const size_t MAX_LEN = 200;
  if (s.size() > MAX_LEN) {
    s.erase(MAX_LEN);
    s += "...";
  }
  return s;
}

// 함수(또는 생성자)의 정규화 이름 작성
static std::string get_qualified_name(const Decl* D) {
  if (!D) return {};
  if (const auto* FD = llvm::dyn_cast<FunctionDecl>(D)) {
    return FD->getQualifiedNameAsString();
  }
  if (const auto* CD = llvm::dyn_cast<CXXConstructorDecl>(D)) {
    // 생성자는 클래스 이름을 반환
    return CD->getParent()->getQualifiedNameAsString() + "::" +
           CD->getNameAsString();
  }
  if (const auto* MD = llvm::dyn_cast<CXXMethodDecl>(D)) {
    return MD->getQualifiedNameAsString();
  }
  return {};
}

// 함수 시그니처(Pretty) 생성
static std::string get_pretty_signature(const FunctionDecl* FD) {
  if (!FD) return {};
  std::string Sig;
  llvm::raw_string_ostream OS(Sig);
  FD->print(OS);
  return OS.str();
}

// 예외 명세(noexcept) 판정
static bool is_nothrow_function(const FunctionDecl* FD) {
  if (!FD) return false;
  const Type* Ty = FD->getType().getTypePtrOrNull();
  if (!Ty) return false;
  if (const auto* FPT = Ty->getAs<FunctionProtoType>()) {
    return FPT->isNothrow();
  }
  return false;
}

// ---------------------- 콜백 ----------------------

struct CallDump : public MatchFinder::MatchCallback {
  const SourceManager* SM{nullptr};
  const LangOptions* LO{nullptr};

  void run(const MatchFinder::MatchResult& Result) override {
    if (!SM) SM = Result.SourceManager;
    if (!LO) LO = &Result.Context->getLangOpts();

    // 다양한 호출 형태를 한 번에 처리
    if (const auto* CE = Result.Nodes.getNodeAs<CallExpr>("call")) {
      handleCallExpr(*CE, Result);
    }
    if (const auto* ME = Result.Nodes.getNodeAs<CXXMemberCallExpr>("mcall")) {
      handleMemberCallExpr(*ME, Result);
    }
    if (const auto* CX = Result.Nodes.getNodeAs<CXXConstructExpr>("ctor")) {
      handleConstructExpr(*CX, Result);
    }
    if (const auto* OE = Result.Nodes.getNodeAs<CXXOperatorCallExpr>("opcall")) {
      handleOperatorCallExpr(*OE, Result);
    }
  }

  void handleCallExpr(const CallExpr& CE, const MatchFinder::MatchResult& R) {
    const FunctionDecl* FD = CE.getDirectCallee();
    if (!FD) return;

    std::string qname = get_qualified_name(FD);
    if (OnlyStd && qname.rfind("std::", 0) != 0) return;
    if (!NamePrefix.empty() && qname.rfind(NamePrefix, 0) != 0) return;

    bool nothrow = is_nothrow_function(FD);

    PresumedLoc PLoc = SM->getPresumedLoc(CE.getExprLoc());
    std::string sig = get_pretty_signature(FD);
    std::string snippet = get_source_snippet(CE.getSourceRange(), *SM, *LO);

    print_csv(PLoc, "call", qname, nothrow, sig, snippet);
  }

  void handleMemberCallExpr(const CXXMemberCallExpr& ME,
                            const MatchFinder::MatchResult& R) {
    const FunctionDecl* FD = ME.getDirectCallee();
    if (!FD) return;

    std::string qname = get_qualified_name(FD);
    if (OnlyStd && qname.rfind("std::", 0) != 0) return;
    if (!NamePrefix.empty() && qname.rfind(NamePrefix, 0) != 0) return;

    bool nothrow = is_nothrow_function(FD);

    PresumedLoc PLoc = SM->getPresumedLoc(ME.getExprLoc());
    std::string sig = get_pretty_signature(FD);
    std::string snippet = get_source_snippet(ME.getSourceRange(), *SM, *LO);

    print_csv(PLoc, "member-call", qname, nothrow, sig, snippet);
  }

  void handleConstructExpr(const CXXConstructExpr& CX,
                           const MatchFinder::MatchResult& R) {
    const FunctionDecl* FD = CX.getConstructor();
    if (!FD) return;

    std::string qname = get_qualified_name(FD);
    if (OnlyStd && qname.rfind("std::", 0) != 0) return;
    if (!NamePrefix.empty() && qname.rfind(NamePrefix, 0) != 0) return;

    bool nothrow = is_nothrow_function(FD);

    PresumedLoc PLoc = SM->getPresumedLoc(CX.getExprLoc());
    std::string sig = get_pretty_signature(FD);
    std::string snippet = get_source_snippet(CX.getSourceRange(), *SM, *LO);

    print_csv(PLoc, "construct", qname, nothrow, sig, snippet);
  }

  void handleOperatorCallExpr(const CXXOperatorCallExpr& OE,
                              const MatchFinder::MatchResult& R) {
    const FunctionDecl* FD = OE.getDirectCallee();
    if (!FD) return;

    std::string qname = get_qualified_name(FD);
    if (OnlyStd && qname.rfind("std::", 0) != 0) return;
    if (!NamePrefix.empty() && qname.rfind(NamePrefix, 0) != 0) return;

    bool nothrow = is_nothrow_function(FD);

    PresumedLoc PLoc = SM->getPresumedLoc(OE.getExprLoc());
    std::string sig = get_pretty_signature(FD);
    std::string snippet = get_source_snippet(OE.getSourceRange(), *SM, *LO);

    print_csv(PLoc, "operator-call", qname, nothrow, sig, snippet);
  }

  void print_csv(const PresumedLoc& P,
                 const char* kind,
                 const std::string& qname,
                 bool nothrow,
                 const std::string& sig,
                 const std::string& snippet) {
    std::string file = P.isValid() ? P.getFilename() : "<unknown>";
    unsigned line = P.isValid() ? P.getLine() : 0;
    unsigned col  = P.isValid() ? P.getColumn() : 0;

    // CSV: file,line,col,kind,qualified-name,noexcept,signature,callee-source
    std::cout
      << csv_quote(file) << ","
      << line << ","
      << col << ","
      << csv_quote(kind) << ","
      << csv_quote(qname) << ","
      << (nothrow ? "noexcept" : "may-throw") << ","
      << csv_quote(sig) << ","
      << csv_quote(snippet)
      << "\n";
  }
};

} // namespace

int main(int argc, const char** argv) {
  llvm::cl::OptionCategory Cat("std-call-scan options");
  auto ExpectedParser = CommonOptionsParser::create(argc, argv, Cat);
  if (!ExpectedParser) {
    llvm::errs() << ExpectedParser.takeError();
    return 1;
  }
  CommonOptionsParser& OptionsParser = ExpectedParser.get();
  ClangTool Tool(OptionsParser.getCompilations(),
                 OptionsParser.getSourcePathList());

  if (CsvHeader) {
    std::cout
      << "file,line,col,kind,qualified-name,noexcept,signature,callee-source\n";
  }

  // 매처: 호출 4종 모두 (시스템 헤더 제외)
  auto M1 = callExpr(unless(isExpansionInSystemHeader())).bind("call");
  auto M2 = cxxMemberCallExpr(unless(isExpansionInSystemHeader())).bind("mcall");
  auto M3 = cxxConstructExpr(unless(isExpansionInSystemHeader())).bind("ctor");
  auto M4 = cxxOperatorCallExpr(unless(isExpansionInSystemHeader())).bind("opcall");

  // 시스템 헤더까지 포함하려면 위의 unless(...)를 제거하세요.

  CallDump Printer;
  MatchFinder Finder;
  Finder.addMatcher(M1, &Printer);
  Finder.addMatcher(M2, &Printer);
  Finder.addMatcher(M3, &Printer);
  Finder.addMatcher(M4, &Printer);

  return Tool.run(newFrontendActionFactory(&Finder).get());
}
