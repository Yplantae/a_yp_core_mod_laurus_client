#!/bin/bash

ANDROID_JSON_PATH="android/app/google-services.json"
IOS_PLIST_PATH="ios/Runner/GoogleService-Info.plist"
MACOS_PLIST_PATH="macos/Runner/GoogleService-Info.plist"
FIREBASE_OPTIONS_PATH="lib/firebase_options.dart"

encode_file() {
  local label=$1
  local path=$2

  if [ -f "$path" ]; then
    echo "✅ $label found. Encoding..."
    echo ""
    echo "-------------------- $label --------------------"
    base64 < "$path"
    echo "-------------------- END $label --------------------"
    echo ""
  else
    echo "⚠️ WARNING: $label not found at $path"
    echo ""
  fi
}

echo "==========================================="
echo "📦 Firebase 설정 파일 base64 인코딩 결과"
echo "💡 GitHub Secrets 등록 시 아래 값을 복사하세요"
echo "==========================================="
echo ""

encode_file "ANDROID_GOOGLE_SERVICES_JSON" "$ANDROID_JSON_PATH"
encode_file "IOS_GOOGLE_SERVICE_INFO_PLIST" "$IOS_PLIST_PATH"
encode_file "MACOS_GOOGLE_SERVICE_INFO_PLIST" "$MACOS_PLIST_PATH"
encode_file "FIREBASE_OPTIONS_DART" "$FIREBASE_OPTIONS_PATH"

echo "✅ 완료. 위 내용을 복사해서 GitHub Secrets에 붙여넣으세요."

