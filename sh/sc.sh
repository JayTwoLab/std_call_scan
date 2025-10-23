#!/usr/bin/env bash
# 목적: jaytwo-library의 src/*.cpp를 std_call_scan으로 스캔하여 CSV 생성
# 특징:
#   - clang 리소스 디렉터리 자동 감지 후 -extra-arg로 주입
#   - 파일별로 개별 실행 (한 파일에서 크래시 나도 전체는 계속 진행)
#   - CSV 헤더 1회 출력, 실패 파일 목록 따로 기록
#   - 공백/특수문자 안전(-print0/-0)

set -euo pipefail

# === 경로 설정 ===
SCAN_BIN="${HOME}/std_call_scan"   # std_call_scan 실행 파일
SRC_DIR="/home/j2/workspace/dev/github/jaytwo-library/j2_library/src"
BUILD_DIR="/home/j2/workspace/dev/github/jaytwo-library/build-clang"  # clang++로 만든 빌드
OUT_CSV="${HOME}/scan_report.csv"
FAIL_LIST="${HOME}/scan_failures.txt"

# === 전제 조건 점검 ===
if [[ ! -x "$SCAN_BIN" ]]; then
  echo "[오류] 실행 파일 없음: $SCAN_BIN"
  exit 1
fi
if [[ ! -d "$SRC_DIR" ]]; then
  echo "[오류] 소스 디렉터리 없음: $SRC_DIR"
  exit 1
fi
if [[ ! -f "$BUILD_DIR/compile_commands.json" ]]; then
  echo "[오류] 컴파일 데이터베이스 없음: $BUILD_DIR/compile_commands.json"
  echo "       (예) clang++로 빌드 폴더 생성:"
  echo "       cmake -S /home/j2/workspace/dev/github/jaytwo-library -B $BUILD_DIR \\"
  echo "             -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
  echo "       cmake --build $BUILD_DIR -j"
  exit 1
fi

# === clang 리소스 디렉터리 감지 및 검증 ===
RES_DIR="$(clang -print-resource-dir 2>/dev/null || true)"
if [[ -z "${RES_DIR}" ]]; then
  echo "[오류] 'clang -print-resource-dir' 가 실패했습니다. clang 설치를 확인하세요."
  exit 1
fi
if [[ ! -f "${RES_DIR}/include/stddef.h" ]]; then
  echo "[오류] 리소스 헤더가 보이지 않습니다: ${RES_DIR}/include/stddef.h"
  exit 1
fi

# === 실행 정보 출력 ===
echo "[정보] SCAN_BIN   : $SCAN_BIN"
echo "[정보] SRC_DIR    : $SRC_DIR"
echo "[정보] BUILD_DIR  : $BUILD_DIR"
echo "[정보] RES_DIR    : $RES_DIR"
echo "[정보] OUT_CSV    : $OUT_CSV"
echo "[정보] FAIL_LIST  : $FAIL_LIST"

# === 출력 파일 초기화 ===
echo "file,line,col,kind,qualified-name,noexcept,signature,callee-source" > "$OUT_CSV"
: > "$FAIL_LIST"

# === 공통 extra-arg 구성 ===
#  - libTooling 계열 표준 옵션: -extra-arg=<flag>
#  - 드라이버/cc1 모두 먹히는 -isystem 리소스 include 경로를 확실히 추가
EXTRA_ARGS=(
  -extra-arg=-isystem
  -extra-arg="${RES_DIR}/include"
  -extra-arg="-resource-dir=${RES_DIR}"
)

# === 파일별 안전 실행 루프 ===
# 한 파일에서 크래시해도 전체 검사는 계속 진행합니다.
count_total=0
count_ok=0
count_fail=0

while IFS= read -r -d '' f; do
  count_total=$((count_total+1))
  echo "[${count_total}] 처리: $f"
  if "$SCAN_BIN" -p "$BUILD_DIR" "${EXTRA_ARGS[@]}" "$f" >> "$OUT_CSV"; then
    count_ok=$((count_ok+1))
  else
    echo "$f" >> "$FAIL_LIST"
    count_fail=$((count_fail+1))
    echo "  -> 실패: $f (계속 진행)"
  fi
done < <(find "$SRC_DIR" -name '*.cpp' -print0)

echo
echo "[완료] 총 ${count_total}개 파일 처리 / 성공 ${count_ok} / 실패 ${count_fail}"
echo "[결과] CSV  : $OUT_CSV"
echo "[결과] 실패 : $FAIL_LIST (비었으면 모든 파일 성공)"
