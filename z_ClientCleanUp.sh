#!/usr/bin/env bash
# z_ClientCleanUp.sh
set -Eeuo pipefail

# ===============================
# Flutter Client Clean Up (Safe)
# - 기본: 프로젝트 내부 캐시 + OS별/플러그인 생성물 삭제
# - --deep: ~/.pub-cache, ~/.gradle 등 전역 캐시까지 삭제
# - --wipe-local-properties: android/local.properties 삭제
# - macOS: Xcode/시뮬레이터 종료 후 DerivedData "폴더 자체" 통삭제
# ===============================

echo "================ CleanUp Modes ================"
echo "{normal}                 : 현재 프로젝트 내부 캐시 및 OS별/플러그인 생성물 삭제"
echo "  --deep               : {normal} + 전역 캐시(~/.pub-cache, ~/.gradle) 삭제"
echo "  --wipe-local-properties : local.properties까지 삭제 (SDK 경로 재설정 필요)"
echo "================================================"
echo

usage() {
  cat <<'USAGE'
Usage: z_ClientCleanUp.sh [--deep] [--wipe-local-properties]

Options:
  --deep                   전역 캐시(~/.pub-cache, ~/.gradle)까지 삭제 (모든 프로젝트에 영향)
  --wipe-local-properties  android/local.properties도 삭제 (경로/키 재생성 필요)
USAGE
}

DEEP=false
WIPE_LOCAL_PROPERTIES=false
if [[ $# -gt 0 ]]; then
  for arg in "$@"; do
    case "$arg" in
      --deep) DEEP=true ;;
      --wipe-local-properties) WIPE_LOCAL_PROPERTIES=true ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
    esac
  done
fi

# ---- 안전 체크: 프로젝트 루트 확인 ------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
if [[ ! -f "pubspec.yaml" ]]; then
  echo "❌ pubspec.yaml이 없습니다. 프로젝트 루트에서 실행하세요."
  exit 1
fi

echo "🔧 Clean Up Start (deep=${DEEP}, wipe_local_properties=${WIPE_LOCAL_PROPERTIES})"

# ---- 유틸: 안전 삭제 ---------------------------------------------------------
rm_safe() {
  local target="$1"
  if [[ -e "$target" ]]; then
    rm -rf "$target"
    echo "  🗑  removed: $target"
  fi
}

# ---- macOS: Xcode/시뮬레이터 종료(파일 잡힘 방지) ----------------------------
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "🛑 macOS: Quit Xcode & Simulator / Shutdown all simulators"
  osascript -e 'tell application "Simulator" to quit' >/dev/null 2>&1 || true
  osascript -e 'tell application "Xcode" to quit'     >/dev/null 2>&1 || true
  xcrun simctl shutdown all                           >/dev/null 2>&1 || true
fi

# ---- Flutter/Project 캐시 ----------------------------------------------------
rm_safe "build"
rm_safe ".dart_tool"
rm_safe ".packages"
rm_safe "pubspec.lock"

# ---- iOS/macOS ----------------------------------------------------------------
rm_safe "ios/Pods"
rm_safe "ios/Flutter/App.framework"
rm_safe "ios/Flutter/Flutter.framework"
rm_safe "ios/DerivedData"
rm_safe "ios/.symlinks"
rm_safe "ios/Podfile.lock"
rm_safe "macos/Pods"
rm_safe "macos/Flutter/FlutterMacOS.framework"
rm_safe "macos/Podfile.lock"

# ---- Android -----------------------------------------------------------------
rm_safe "android/.gradle"
rm_safe "android/app/build"
if $WIPE_LOCAL_PROPERTIES; then
  rm_safe "android/local.properties"
else
  if [[ -f "android/local.properties" ]]; then
    echo "  🔒 kept: android/local.properties (경로/키 보존). 지우려면 --wipe-local-properties"
  fi
fi
rm_safe "android/.idea"

# ---- Web ---------------------------------------------------------------------
rm_safe "web/.dart_tool"
rm_safe "web/.generated"
rm_safe "web/generated"

# ---- Linux -------------------------------------------------------------------
rm_safe "linux/flutter/ephemeral"
rm_safe "linux/.generated"
rm_safe "linux/generated"

# ---- Windows -----------------------------------------------------------------
rm_safe "windows/flutter/ephemeral"
rm_safe "windows/.generated"
rm_safe "windows/generated"

# ---- Firebase Functions ------------------------------------------------------
rm_safe "firebase/functions/node_modules"

# ---- Xcode DerivedData: "폴더 자체" 통삭제 -----------------------------------
if [[ "$(uname -s)" == "Darwin" ]]; then
  DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
  if [[ -d "$DERIVED" && -w "$DERIVED" ]]; then
    rm_safe "$DERIVED"           # ← 기존의 "$DERIVED/*" 대신 폴더 자체 삭제
  else
    echo "  ℹ️  skip: $DERIVED (없거나 쓰기 불가). 필요 시 권한 확인: sudo chown -R \"$USER\":staff \"$DERIVED\""
  fi
fi

# ---- 플러그인/패키지 생성물 ---------------------------------------------------
rm_safe ".generated"
rm_safe "generated"
rm_safe "ios/.generated"
rm_safe "android/.generated"
rm_safe "macos/.generated"
rm_safe "linux/.generated"
rm_safe "windows/.generated"
rm_safe "web/.generated"

# 코드 생성 산출물(패턴) — 디렉터리 자체 삭제가 아닌 파일 패턴이라 유지
shopt -s nullglob
GENS=(lib/**/*.g.dart lib/**/*.freezed.dart lib/**/*.mocks.dart)
if ((${#GENS[@]})); then rm -rf "${GENS[@]}"; echo "  🗑  removed generated dart files"; fi
shopt -u nullglob

# ---- 개인 전역 캐시(선택: --deep) -------------------------------------------
if $DEEP; then
  rm_safe "$HOME/.pub-cache"
  rm_safe "$HOME/.gradle"
fi

# ---- flutter clean -----------------------------------------------------------
if command -v flutter >/dev/null 2>&1; then
  echo "🚿 flutter clean …"
  flutter clean >/dev/null
  echo "  ✅ flutter clean done"
else
  echo "  ⚠️  flutter 명령을 찾지 못해 flutter clean 생략"
fi

echo "✅ Clean Up Completed (deep=${DEEP}, wipe_local_properties=${WIPE_LOCAL_PROPERTIES})"

