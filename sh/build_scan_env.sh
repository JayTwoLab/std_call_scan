#!/usr/bin/env bash
# build_scan_env.sh
# 목적: sc.sh 실행 준비 자동화 (clang++ 빌드 및 compile_commands.json 생성)

set -euo pipefail

# === 프로젝트/경로 설정 ===
PROJ_ROOT="/home/j2/workspace/dev/github/jaytwo-library"
BUILD_DIR="${PROJ_ROOT}/build-clang"     # clang++ 전용 빌드 폴더
SCAN_SCRIPT="${HOME}/sc.sh"              # 앞서 만든 스캔 스크립트

# === 도구 확인 ===
need() { command -v "$1" >/dev/null 2>&1 || { echo "[오류] '$1' 명령을 찾을 수 없습니다."; exit 1; }; }
need clang
need clang++

# (권장) 리소스 디렉터리 확인
RES_DIR="$(clang -print-resource-dir)"
if [[ ! -f "${RES_DIR}/include/stddef.h" ]]; then
  echo "[오류] clang 리소스 헤더가 보이지 않습니다: ${RES_DIR}/include/stddef.h"
  echo "       clang 패키지 설치 상태를 확인하세요."
  exit 1
fi

# === RHEL/SCL(예: gcc-toolset-14) 환경 힌트 (있어도/없어도 무방) ===
# - SCL 사용 시, clang이 해당 표준 라이브러리/헤더를 잘 찾도록 힌트를 줍니다.
# - 없어도 진행됩니다. 필요 시 주석 해제하세요.
GCC_TOOLCHAIN_HINT="/opt/rh/gcc-toolset-14/root/usr"
CMAKE_TOOLCHAIN_CXX_FLAGS=""
CMAKE_TOOLCHAIN_C_FLAGS=""
if [[ -d "${GCC_TOOLCHAIN_HINT}" ]]; then
  CMAKE_TOOLCHAIN_CXX_FLAGS="--gcc-toolchain=${GCC_TOOLCHAIN_HINT}"
  CMAKE_TOOLCHAIN_C_FLAGS="--gcc-toolchain=${GCC_TOOLCHAIN_HINT}"
  echo "[정보] SCL toolchain 감지: ${GCC_TOOLCHAIN_HINT}"
fi

# === CMake Configure (clang++ 빌드 폴더 새로 생성) ===
echo "[정보] CMake configure (clang++)"
rm -rf "${BUILD_DIR}"
cmake -S "${PROJ_ROOT}" -B "${BUILD_DIR}" \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  ${CMAKE_TOOLCHAIN_CXX_FLAGS:+-DCMAKE_CXX_FLAGS="${CMAKE_TOOLCHAIN_CXX_FLAGS}"} \
  ${CMAKE_TOOLCHAIN_C_FLAGS:+-DCMAKE_C_FLAGS="${CMAKE_TOOLCHAIN_C_FLAGS}"}

# === 빌드 ===
echo "[정보] CMake build"
cmake --build "${BUILD_DIR}" -j

# === compile_commands.json 확인 ===
if [[ ! -f "${BUILD_DIR}/compile_commands.json" ]]; then
  echo "[오류] ${BUILD_DIR}/compile_commands.json 이 없습니다."
  exit 1
fi
echo "[정보] compile_commands.json 확인 OK"

# === sc.sh 존재/실행 권한 점검 ===
if [[ ! -f "${SCAN_SCRIPT}" ]]; then
  echo "[오류] 스캔 스크립트를 찾을 수 없습니다: ${SCAN_SCRIPT}"
  echo "       먼저 sc.sh 를 생성해 주세요."
  exit 1
fi
chmod +x "${SCAN_SCRIPT}"

# === 스캔 실행 ===
echo "[정보] 스캔 시작 (sc.sh)"
"${SCAN_SCRIPT}"

echo "[완료] 빌드+스캔 완료"
