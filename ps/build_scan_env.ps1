#!/usr/bin/env pwsh
# build_scan_env.ps1
# 목적: sc.ps1 실행 준비 자동화 (clang++ 빌드 및 compile_commands.json 생성)

$ErrorActionPreference = "Stop"

# === 프로젝트/경로 설정 ===
$PROJ_ROOT  = "C:/workspace/dev/github/jaytwo-library"   # j2 라이브러리
$BUILD_DIR  = "$PROJ_ROOT/build-clang"                   # clang++ 전용 빌드 폴더

$STD_PRJ_ROOT = "C:/workspace/dev/std_call_scan"
$SCAN_SCRIPT  = "$STD_PRJ_ROOT/ps/sc.ps1"                # 스캔 스크립트

# === 도구 확인 ===
function Need($cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "[오류] '$cmd' 명령을 찾을 수 없습니다."
        exit 1
    }
}
Need "clang"
Need "clang++"
Need "cmake"

# === clang 리소스 디렉터리 확인 ===
$RES_DIR = & clang -print-resource-dir
if (-not (Test-Path "$RES_DIR/include/stddef.h")) {
    Write-Error "[오류] clang 리소스 헤더가 보이지 않습니다: $RES_DIR/include/stddef.h"
    exit 1
}

# === CMake Configure (clang++ 빌드 폴더 새로 생성) ===
Write-Output "[정보] CMake configure (clang++)"
if (Test-Path $BUILD_DIR) { Remove-Item -Recurse -Force $BUILD_DIR }
cmake -S $PROJ_ROOT -B $BUILD_DIR `
  -DCMAKE_CXX_COMPILER=clang++ `
  -DCMAKE_C_COMPILER=clang `
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

# === 빌드 ===
Write-Output "[정보] CMake build"
cmake --build $BUILD_DIR -j

# === compile_commands.json 확인 ===
if (-not (Test-Path "$BUILD_DIR/compile_commands.json")) {
    Write-Error "[오류] $BUILD_DIR/compile_commands.json 이 없습니다."
    exit 1
}
Write-Output "[정보] compile_commands.json 확인 OK"

# === 스캔 실행 ===
if (-not (Test-Path $SCAN_SCRIPT)) {
    Write-Error "[오류] 스캔 스크립트를 찾을 수 없습니다: $SCAN_SCRIPT"
    exit 1
}
Write-Output "[정보] 스캔 시작 (sc.ps1)"
& $SCAN_SCRIPT

Write-Output "[완료] 빌드+스캔 완료"
