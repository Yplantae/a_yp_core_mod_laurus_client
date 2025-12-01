#!/bin/zsh

# =====================================================
# Flutter Multi-Platform Configuration Collector
# =====================================================

# -----------------------------------------------------
# CRITICAL FIX: Change CWD to the script's directory
# This ensures the script is executed from the Flutter project root
# (assuming the script file resides in the project root).
# -----------------------------------------------------
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR" || exit 1

# -----------------------------
# Zsh Options for robustness
# -----------------------------
# 일치하는 파일이 없을 때 (glob이 비어있을 때) 에러 대신 빈 리스트를 반환하여 스크립트 중단 방지
setopt nullglob

# -----------------------------
# Validate Flutter project root
# -----------------------------
echo "🚀 Current Working Directory (CWD): $(pwd)" # CWD가 스크립트 위치로 변경되었는지 확인

if [ ! -f "pubspec.yaml" ]; then
  echo "[ERROR] pubspec.yaml not found in current directory."
  echo "This script must be executed at the Flutter project root."
  exit 1
else
  echo "[INFO] pubspec.yaml found. Proceeding with config collection."
fi

# -----------------------------
# Prepare timestamped output directory
# -----------------------------
TS=$(date +"%y%m%d_%H%M%S")
OUTDIR="z_gathered_configs_${TS}"

mkdir -p "$OUTDIR"

OUT_ANDROID="${OUTDIR}/android.txt"
OUT_IOS="${OUTDIR}/ios.txt"
OUT_WEB="${OUTDIR}/web.txt"
OUT_FIREBASE="${OUTDIR}/firebase.txt"
OUT_MISC="${OUTDIR}/misc.txt"

# 결과 파일 초기화
echo "" > "$OUT_ANDROID"
echo "" > "$OUT_IOS"
echo "" > "$OUT_WEB"
echo "" > "$OUT_FIREBASE"
echo "" > "$OUT_MISC"


# -----------------------------
# Helper function
# -----------------------------
# 파일 내용을 결과 파일에 추가합니다. 파일이 존재하지 않으면 무시합니다.
append_file() {
  local filepath="$1"
  local outfile="$2"

  if [ -f "$filepath" ]; then
    {
      echo ""
      echo ""
      echo ""
      echo "[ $filepath ] =============================="
      cat "$filepath"
      echo ""
      echo ""
      echo ""
    } >> "$outfile"
  fi
}


# =====================================================
# 📱 Android Configurations
# =====================================================
ANDROID_FILES=(
  ".firebaserc"
  "firebase.json"
  "android/build.gradle"
  "android/app/build.gradle"
  "android/settings.gradle"
  "android/gradle.properties"
  "android/local.properties"
  "android/app/src/main/AndroidManifest.xml"
  "android/app/src/debug/AndroidManifest.xml"
  "android/app/src/profile/AndroidManifest.xml"
  "android/app/google-services.json"
  "android/app/proguard-rules.pro"
)

for f in "${ANDROID_FILES[@]}"; do
  append_file "$f" "$OUT_ANDROID"
done


# =====================================================
# 🍎 iOS Configurations
# =====================================================
IOS_FILES=(
  ".firebaserc"
  "firebase.json"
  "ios/Runner/Info.plist"
  "ios/Runner/Debug.xcconfig"
  "ios/Runner/Release.xcconfig"
  "ios/Runner/AppDelegate.swift"
  "ios/Runner/GoogleService-Info.plist"
  "ios/Runner.xcodeproj/project.pbxproj"
  "ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata"
  "ios/Flutter/AppFrameworkInfo.plist"
  "ios/Flutter/Debug.xcconfig"
  "ios/Flutter/flutter_export_environment.sh"
  "ios/Flutter/Release.xcconfig"
  "ios/Podfile"
  "ios/Podfile.lock"
)

for f in "${IOS_FILES[@]}"; do
  append_file "$f" "$OUT_IOS"
done



# =====================================================
# 🌐 Web Configurations
# =====================================================
WEB_LIST=(
  ".firebaserc"
  "firebase.json"
  "web/index.html"
  "web/manifest.json"
  "web/firebase-messaging-sw.js"
)

for f in "${WEB_LIST[@]}"; do
  append_file "$f" "$OUT_WEB"
done

# Web의 기타 JS/CSS 파일 수집
find ./web -type f \( -iname "*.js" -o -iname "*.css" \) | while read -r wf; do
  append_file "$wf" "$OUT_WEB"
done


# =====================================================
# 🔥 Firebase & Service Credentials
# =====================================================
FIREBASE_BASE_FILES=(
  ".firebaserc"
  "firebase.json"
  "pubspec.yaml" # 종속성 확인을 위해 포함
  "android/app/google-services.json"
  "ios/Runner/GoogleService-Info.plist"
  "android/app/appcheck.json" # App Check 설정 파일
)

for f in "${FIREBASE_BASE_FILES[@]}"; do
  append_file "$f" "$OUT_FIREBASE"
done

# 프로젝트 전반에서 Firebase/Service/Credential 관련 JSON 파일 검색
find . -type f -iname "*.json" | grep -Ei "firebase|service|cred|google|api" | while read -r jf; do
  # 이미 명시적으로 포함된 파일은 제외
  if [[ "$jf" != *"android/app/google-services.json"* ]] && [[ "$jf" != *"android/app/appcheck.json"* ]]; then
      append_file "$jf" "$OUT_FIREBASE"
  fi
done


# =====================================================
# ⚙️ Misc / General Configurations
# =====================================================
MISC_FILES=(
  "analysis_options.yaml"
  ".metadata"
  ".packages"
  "README.md"
)

for f in "${MISC_FILES[@]}"; do
  append_file "$f" "$OUT_MISC"
done


echo ""
echo "✅ [OK] Configs gathered successfully into the directory: $OUTDIR"
echo ""

# 결과를 모은 디렉토리로 이동하는 명령어를 출력합니다.
echo "To view results, run: cd $OUTDIR"