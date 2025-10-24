# std_call_scan

> [English](README.md) [Korean](README.ko.md) 

A tiny **Clang LibTooling** utility that parses C++ source files into an AST, finds **every function/method/constructor call**, and reports whether the callee is **`noexcept`**.  
The tool prints a CSV to `stdout`, which you can redirect to a file.

> Columns: `file,line,col,kind,qualified-name,noexcept,signature,callee-source`

<br />

## Features

- Walks calls to free functions, member methods, constructors, and overloaded operators
- Evaluates `noexcept` via `FunctionProtoType::isNothrow()`
- Optional filters:
  - `--only-std` — keep only calls whose qualified name starts with `std::`
  - `--name-prefix <prefix>` — keep only calls with a given qualified-name prefix (e.g., `std::filesystem::`)
  - `--csv-header` — print a header row
- (By default) system headers are excluded; you can tweak the matcher in the source if you need them

<br />

## Requirements

- CMake **≥ 3.20**
- A working LLVM/Clang development environment (headers + libs)
  - Rocky/Red Hat example:
    ```bash
    sudo dnf install clang clang-devel llvm llvm-devel libedit-devel libffi-devel libxml2-devel zlib-devel libzstd-devel
    ```
  - Ubuntu example:
    ```bash
    sudo apt install clang libclang-dev llvm-dev libedit-dev libffi-dev libxml2-dev zlib1g-dev libzstd-dev
    ```

<br />

## Build

### Linux

```bash
# from the project root
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

This will produce an executable (e.g., `build/std_call_scan`).

### Windows 

* (1) Download LLVM and Clang from the following site:

  * [https://github.com/vovkos/llvm-package-windows](https://github.com/vovkos/llvm-package-windows)
  * Files (install the latest version. `amd64`: 64-bit, `msvc17`: VS2022)

    * llvm-x.x.x-windows-`amd64`-`msvc17`-XXX.7z
    * clang-x.x.x-windows-`amd64`-`msvc17`-XXX.7z

* (2) Extract them to the same path.

  * Assume extraction to `C:\llvm-package`.

* (3) Set environment variables as follows:

  * `PATH` : `C:\llvm-package\bin`
  * `LLVM_DIR` : `C:\llvm-package\lib\cmake\llvm`
  * `Clang_DIR` : `C:\llvm-package\lib\cmake\clang`

* (4) Run `cmake` in the Visual Studio command prompt (**make sure `ninja` is pre-installed**):

  ```bash
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

  * One-line command:

    ```bash
    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL -DLLVM_DIR="C:/llvm-package/lib/cmake/llvm" -DClang_DIR="C:/llvm-package/lib/cmake/clang" ..
    ```

* (5) Execute build:

  ```bash
  ninja -v
  ```

<br />

## Usage

```bash
# Analyze one or more .cpp files and write CSV to a file
./build/std_call_scan --csv-header path/to/a.cpp path/to/b.cpp > report.csv
```

Common filters:

```bash
# Only std:: calls
./build/std_call_scan --only-std src/**/*.cpp > std_calls.csv

# Only std::filesystem:: calls
./build/std_call_scan --name-prefix std::filesystem:: src/**/*.cpp > fs_calls.csv
```

### CSV Schema

- **file**: source file path containing the call site
- **line**, **col**: 1‑based position of the call site
- **kind**: `call` (free function), `method` (member), `construct` (constructor), `opcall` (operator call), etc.
- **qualified-name**: fully qualified callee name (e.g., `std::filesystem::create_directory`)
- **noexcept**: `1` if the callee is nothrow (per Clang's type system), `0` otherwise
- **signature**: a pretty function signature
- **callee-source**: a short source snippet of the call expression

> ⚠️ **Notes & Limitations**
>
> - Results can vary by standard library implementation (libstdc++/libc++/MSVC STL) and template instantiation.
> - System headers are excluded by default; edit the matcher in `scanner.cpp` if you want to include them.
> - The `noexcept` result reflects the callee type as seen by Clang; it does **not** run your code.

<br />

## Examples

```bash
# Current project file as a smoke test
./build/std_call_scan --csv-header scanner.cpp
```

<br />

## License

See [`LICENSE`](LICENSE).

---


