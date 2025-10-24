# std_call_scan

> [English](README.md) [Korean](README.ko.md) 

작은 **Clang LibTooling** 기반 유틸리티로, C++ 소스(.cpp)를 AST로 파싱하여 **모든 함수/메서드/생성자 호출**을 찾고, 각 호출 대상(callee)이 **`noexcept`** 인지 판정하여 **CSV**로 출력합니다.  
CSV는 `stdout`으로 출력되며 파일로 리다이렉트하여 저장할 수 있습니다.

> 컬럼: `file,line,col,kind,qualified-name,noexcept,signature,callee-source`

<br />

## 특징

- 자유 함수, 멤버 함수, 생성자, 연산자 호출까지 폭넓게 탐지
- `FunctionProtoType::isNothrow()`를 이용해 `noexcept` 여부 판정
- 선택 옵션:
  - `--only-std` — 정규화 이름이 `std::`로 시작하는 호출만 남김
  - `--name-prefix <prefix>` — 정규화 이름 접두로 필터(예: `std::filesystem::`)
  - `--csv-header` — CSV 헤더 1행 출력
- 기본적으로 시스템 헤더 호출은 제외(필요 시 소스의 매처를 수정)

<br />

## 요구 사항

- CMake **≥ 3.20**
- LLVM/Clang 개발 환경(헤더 + 라이브러리) 설치
  - Rocky/Red Hat 예:
    ```bash
    sudo dnf install clang clang-devel llvm llvm-devel libedit-devel libffi-devel libxml2-devel zlib-devel libzstd-devel
    ```
  - Ubuntu 예:
    ```bash
    sudo apt install clang libclang-dev llvm-dev libedit-dev libffi-dev libxml2-dev zlib1g-dev libzstd-dev
    ```

<br />

## 빌드

### Linux

```bash
# 프로젝트 루트에서
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

생성된 실행 파일은 보통 `build/std_call_scan` 입니다.

### Windows

- (1) 다음 싸이트에서 LLVM 과 clang 을 다운로드 한다.
   - https://github.com/vovkos/llvm-package-windows
   - 파일 (최신 버전 설치. `amd64`:64비트, `msvc17`:VS2022 )
      - llvm-x.x.x-windows-`amd64`-`msvc17`-XXX.7z
      - clang-x.x.x-windows-`amd64`-`msvc17`-XXX.7z
- (2) 같은 경로에 압축을 해제한다.
   - `C:\llvm-package` 에 해제했다고 가정한다. 
- (3) 다음과 같이 환경 변수를 설정한다.
   - `PATH` : `C:\llvm-package\bin` 
   - `LLVM_DIR` : `C:\llvm-package\lib\cmake\llvm`
   - `Clang_DIR` : `C:\llvm-package\lib\cmake\clang`
- (4) Visual Studio 명령창에서 `cmake` 실행 (`ninja` 사전 설치할 것)
  ```
    mkdir build && cd build
  
    cmake -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_C_COMPILER=clang-cl ^
  -DCMAKE_CXX_COMPILER=clang-cl ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL ^
  -DLLVM_DIR="C:/llvm-package/lib/cmake/llvm" ^
  -DClang_DIR="C:/llvm-package/lib/cmake/clang" ^
  ..
  ```
   - 한 줄 명령: 
   `cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL -DLLVM_DIR="C:/llvm-package/lib/cmake/llvm" -DClang_DIR="C:/llvm-package/lib/cmake/clang" ..`
- (5) 빌드 실행: `ninja -v`
 


<br />

## 사용법

```bash
# 스크립트를 실행하기 전에 build_scan_env.sh의 변수 편집
./sh/build_scan_env.sh
```
 
### CSV 스키마

- **file**: 호출 위치를 포함하는 소스 파일 경로
- **line**, **col**: 호출 위치(1‑base)
- **kind**: `call`(자유 함수), `method`(멤버), `construct`(생성자), `opcall`(연산자 호출) 등
- **qualified-name**: 정규화된 대상 이름(예: `std::filesystem::create_directory`)
- **noexcept**: 해당 함수 타입이 `nothrow`이면 `1`, 아니면 `0`
- **signature**: 사람이 읽기 좋은 함수 시그니처
- **callee-source**: 호출 표현식의 소스 일부 스니펫

> ⚠️ **주의/제한**
>
> - 표준 라이브러리 구현(libstdc++/libc++/MSVC STL) 및 템플릿 인스턴스에 따라 결과가 달라질 수 있습니다.
> - 기본적으로 시스템 헤더는 제외됩니다. 포함하려면 `scanner.cpp`의 매처를 수정하십시오.
> - `noexcept` 결과는 Clang이 인지한 함수 타입을 기준으로 하며, 코드를 실행하는 것이 아닙니다.

<br />

## 예시

```bash
# 현재 프로젝트 파일로 스모크 테스트
./build/std_call_scan --csv-header scanner.cpp
```

<br />

## 라이선스

[`LICENSE`](LICENSE) 파일을 참고하십시오.

---


