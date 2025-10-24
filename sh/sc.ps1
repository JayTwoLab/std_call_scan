#!/usr/bin/env pwsh
# sc.ps1
# 목적: jaytwo-library의 src/*.cpp를 std_call_scan으로 스캔하여 CSV 생성

$ErrorActionPreference = "Stop"

# === 경로 설정 ===
$PROJ_ROOT = "C:/workspace/dev/github/jaytwo-library"
$SRC_DIR   = "$PROJ_ROOT/j2_library/src"
$BUILD_DIR = "$PROJ_ROOT/build-clang"

$STD_PRJ_ROOT = "C:/workspace/dev/std_call_scan"
$SCAN_BIN = "$STD_PRJ_ROOT/build/std_call_scan.exe"

$OUT_CSV  = "$HOME/scan_report.csv"
$FAIL_LIST = "$HOME/scan_failures.txt"

# === 전제 조건 점검 ===
if (-not (Test-Path $SCAN_BIN)) {
    Write-Error "[오류] 실행 파일 없음: $SCAN_BIN"
    exit 1
}
if (-not (Test-Path $SRC_DIR)) {
    Write-Error "[오류] 소스 디렉터리 없음: $SRC_DIR"
    exit 1
}
if (-not (Test-Path "$BUILD_DIR/compile_commands.json")) {
    Write-Error "[오류] 컴파일 데이터베이스 없음: $BUILD_DIR/compile_commands.json"
    exit 1
}

# === clang 리소스 디렉터리 감지 및 검증 ===
$RES_DIR = & clang -print-resource-dir
if (-not (Test-Path "$RES_DIR/include/stddef.h")) {
    Write-Error "[오류] 리소스 헤더가 보이지 않습니다: $RES_DIR/include/stddef.h"
    exit 1
}

# === 실행 정보 출력 ===
Write-Output "[정보] SCAN_BIN   : $SCAN_BIN"
Write-Output "[정보] SRC_DIR    : $SRC_DIR"
Write-Output "[정보] BUILD_DIR  : $BUILD_DIR"
Write-Output "[정보] RES_DIR    : $RES_DIR"
Write-Output "[정보] OUT_CSV    : $OUT_CSV"
Write-Output "[정보] FAIL_LIST  : $FAIL_LIST"

# === 출력 파일 초기화 ===
"file,line,col,kind,qualified-name,noexcept,signature,callee-source" | Out-File $OUT_CSV -Encoding UTF8
"" | Out-File $FAIL_LIST -Encoding UTF8

# === 파일별 안전 실행 루프 ===
$count_total = 0
$count_ok = 0
$count_fail = 0

Get-ChildItem -Recurse -Path $SRC_DIR -Filter *.cpp | ForEach-Object {
    $f = $_.FullName
    $count_total++
    Write-Output "[$count_total] 처리: $f"
    try {
        & $SCAN_BIN -p $BUILD_DIR `
            -extra-arg=-isystem `
            -extra-arg="$RES_DIR/include" `
            -extra-arg="-resource-dir=$RES_DIR" `
            $f | Out-File -Append -Encoding UTF8 $OUT_CSV
        $count_ok++
    }
    catch {
        Add-Content -Path $FAIL_LIST -Value $f
        Write-Output "  -> 실패: $f (계속 진행)"
        $count_fail++
    }
}

Write-Output ""
Write-Output "[완료] 총 $count_total 개 파일 처리 / 성공 $count_ok / 실패 $count_fail"
Write-Output "[결과] CSV  : $OUT_CSV"
Write-Output "[결과] 실패 : $FAIL_LIST (비었으면 모든 파일 성공)"
