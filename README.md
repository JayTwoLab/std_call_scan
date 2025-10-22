# std_call_scan

> [English](README.md) [Korean](README.ko.md) 

A tiny **Clang LibTooling** utility that parses C++ source files into an AST, finds **every function/method/constructor call**, and reports whether the callee is **`noexcept`**.  
The tool prints a CSV to `stdout`, which you can redirect to a file.

> Columns: `file,line,col,kind,qualified-name,noexcept,signature,callee-source`

## Features

- Walks calls to free functions, member methods, constructors, and overloaded operators
- Evaluates `noexcept` via `FunctionProtoType::isNothrow()`
- Optional filters:
  - `--only-std` — keep only calls whose qualified name starts with `std::`
  - `--name-prefix <prefix>` — keep only calls with a given qualified-name prefix (e.g., `std::filesystem::`)
  - `--csv-header` — print a header row
- (By default) system headers are excluded; you can tweak the matcher in the source if you need them

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

## Build

```bash
# from the project root
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

This will produce an executable (e.g., `build/std_call_scan`).

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

## Examples

```bash
# Current project file as a smoke test
./build/std_call_scan --csv-header scanner.cpp
```

## License

See [`LICENSE`](LICENSE).

---

*Generated on 2025-10-22 15:07:30*
