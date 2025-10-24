# 윈도우즈 빌드

- (1) 다음 싸이트에서 LLVM 과 clang 을 다운로드 한다.
   - https://github.com/vovkos/llvm-package-windows
   - 파일 (최신 버전 설치. `amd64`:64비트, `msvc17`:VS2022 )
      - llvm-x.x.x-windows-`amd64`-`msvc17`-XXX.7z
      - clang-x.x.x-windows-`amd64`-`msvc17`-XXX.7z
- (2) 같은 경로에 압축을 해제한다.
   - `C:\llvm-package` 에 해제했다고 가정한다. 
- (3) 다음과 같이 환경 변수를 설정한다.
   - `PATH` : `C:\llvm-package\bin` (bin 경로)
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
  
