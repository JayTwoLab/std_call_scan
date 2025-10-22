cmake_minimum_required(VERSION 3.20)
project(std_call_scan LANGUAGES C CXX)

# Rocky Linux 9 clang 관련 패키지 설치 명령
#  sudo dnf install clang clang-devel llvm llvm-devel libedit-devel libffi-devel libxml2-devel zlib-devel libzstd-devel
#
# Ubuntu clang 관련 패키지 설치 명령
#  sudo apt install clang libclang-dev llvm-dev libedit-dev libffi-dev libxml2-dev zlib1g-dev libzstd-dev

set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON)

find_package(LLVM  REQUIRED CONFIG)
find_package(Clang REQUIRED CONFIG)
find_package(Threads REQUIRED)

message(STATUS "LLVM_DIR = ${LLVM_DIR}")
message(STATUS "Clang_DIR = ${Clang_DIR}")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(SYSTEM ${LLVM_INCLUDE_DIRS})
include_directories(SYSTEM ${CLANG_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

add_executable(std_call_scan scanner.cpp)

# 1) 분할 라이브러리(clangTooling 등)가 있는 배포판이라면 그걸 사용
if (TARGET clangTooling AND TARGET clangASTMatchers AND TARGET clangBasic)
  target_link_libraries(std_call_scan PRIVATE
    clangTooling
    clangASTMatchers
    clangBasic
    Threads::Threads
    ${CMAKE_DL_LIBS}
  )

# 2) (현재 환경) 모놀리식 libclang-cpp + libLLVM 조합
else()
  # libclang-cpp 찾기
  set(_llvm_lib_hints
      ${LLVM_LIBRARY_DIRS}
      /usr/lib /usr/lib64 /usr/lib/llvm*/lib /lib64)
  find_library(CLANG_CPP_LIB NAMES clang-cpp HINTS ${_llvm_lib_hints} REQUIRED)

  # llvm-config로 LLVM과 시스템 라이브러리 리스트 가져오기
  find_program(LLVM_CONFIG_EXECUTABLE NAMES llvm-config REQUIRED)
  execute_process(
    COMMAND ${LLVM_CONFIG_EXECUTABLE} --libs --system-libs
    OUTPUT_VARIABLE _LLVM_LIBS_RAW
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  separate_arguments(_LLVM_LIBS NATIVE_COMMAND "${_LLVM_LIBS_RAW}")

  message(STATUS "Using monolithic libclang-cpp: ${CLANG_CPP_LIB}")
  message(STATUS "llvm-config libs: ${_LLVM_LIBS}")

  target_link_libraries(std_call_scan PRIVATE
    ${CLANG_CPP_LIB}      # libclang-cpp.so
    ${_LLVM_LIBS}         # -lLLVM-19 등 + 필요 시스템 라이브러리
    Threads::Threads
    ${CMAKE_DL_LIBS}
  )
endif()

# (선택) 런타임 rpath 힌트
if (DEFINED LLVM_LIBRARY_DIRS AND LLVM_LIBRARY_DIRS)
  list(GET LLVM_LIBRARY_DIRS 0 _first)
  if (_first)
    target_link_options(std_call_scan PRIVATE "-Wl,-rpath,${_first}")
  endif()
endif()
