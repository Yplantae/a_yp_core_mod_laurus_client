#!/usr/bin/env bash
# c_Clear_iOS_build_byproduct_and_build.sh
# 목적: iOS 재설치 환경만 준비(실행 X) + Podfile/xcconfig 자동 보정
# 사용: (선택) ./z_ClientCleanUp.sh [--deep] && ./c_Clear_iOS_build_byproduct_and_build.sh
# 옵션: --deep-pods  (CocoaPods 캐시/레포까지 초기화)

set -Eeuo pipefail

DEEP_PODS=false
if [[ $# -gt 0 ]]; then
  for arg in "$@"; do
    case "$arg" in
      --deep-pods) DEEP_PODS=true ;;
      *) echo "Unknown option: $arg"; exit 2 ;;
    esac
  done
fi

step() { printf "\n\033[1m==> %s\033[0m\n" "$*"; }

# 0) 안전 체크
[[ -f "pubspec.yaml" ]] || { echo "❌ 프로젝트 루트(pubspec.yaml)에서 실행하세요."; exit 1; }

# 1) macOS라면 Xcode/시뮬레이터 종료(파일 잡힘 방지)
if [[ "$(uname -s)" == "Darwin" ]]; then
  step "Quit Xcode & Simulator / Shutdown all simulators"
  osascript -e 'tell application "Simulator" to quit' >/dev/null 2>&1 || true
  osascript -e 'tell application "Xcode" to quit'     >/dev/null 2>&1 || true
  xcrun simctl shutdown all                           >/dev/null 2>&1 || true
fi

# 2) Flutter 설정 재생성 (Generated.xcconfig 등)
step "Flutter pub get (Generated.xcconfig 재생성)"
flutter pub get

# --- 유틸: xcconfig 표준 포함 보장 -----------------------------------------
ensure_xcconfig_includes() {
  # $1: 파일경로(ios 내부 기준)  $2: Pods include 라인
  local file="$1"
  local pods_inc="$2"
  local gen_inc='#include "Generated.xcconfig"'

  if [[ ! -f "$file" ]]; then
    printf "%s\n%s\n" "$pods_inc" "$gen_inc" > "$file"
    return 0
  fi
  if ! grep -qF "$pods_inc" "$file"; then
    { printf "%s\n" "$pods_inc"; cat "$file"; } > "$file.tmp" && mv "$file.tmp" "$file"
  fi
  if ! grep -qF "$gen_inc" "$file"; then
    printf "\n%s\n" "$gen_inc" >> "$file"
  fi
}

# --- 유틸: CocoaPods 경고(베이스 구성 안내문)만 출력에서 깔끔히 제거 --------
pod_install_filtered() {
  # 첫 실행에서만 나올 수 있는 알려진 안내문을 필터링하여 콘솔을 깔끔하게 유지
  pod install --repo-update 2>&1 \
    | grep -v 'CocoaPods did not set the base configuration of your project' \
    | grep -v 'In order for CocoaPods integration to work at all'
}
# ---------------------------------------------------------------------------

# 3) iOS Pods 재설치
step "Reinstall Pods (deintegrate → ensure xcconfig → install --repo-update)"
pushd ios >/dev/null

  # (A) Podfile 없으면 [자체 표준 Podfile] 생성
  if [[ ! -f "Podfile" ]]; then
    cat > Podfile <<'EOF'
# Uncomment this line to define a global platform for your project
platform :ios, '14.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  # 정적 링크 프레임워크(일반적으로 플러터/플러그인 호환에 안전)
  use_frameworks! :linkage => :static

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    # Flutter 기본 설정
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      # 1) 시뮬레이터 arm64 제외 (ffmpeg_kit_flutter_new 또는 Pods-Runner 대상)
      if target.name.include?('ffmpeg_kit_flutter_new') || target.name == 'Pods-Runner'
        key = 'EXCLUDED_ARCHS[sdk=iphonesimulator*]'
        existing = config.build_settings[key]
        config.build_settings[key] = [existing, 'arm64'].compact.join(' ').strip
      end

      # 2) permission_handler 전처리기 플래그
      defs = config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
      defs |= [
        'PERMISSION_CAMERA=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_PHOTOS_ADD_ONLY=1',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_LOCATION_WHEN_IN_USE=1',
        # 'PERMISSION_LOCATION_ALWAYS=0',
        'PERMISSION_NOTIFICATIONS=1',
        'PERMISSION_APP_TRACKING_TRANSPARENCY=1',
      ]
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = defs
    end
  end
end
EOF
  fi

  # (B) 먼저 xcconfig에 Pods include를 보장(★ pod install 이전에 수행)
  ensure_xcconfig_includes "Flutter/Debug.xcconfig"   '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"'
  ensure_xcconfig_includes "Flutter/Release.xcconfig" '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"'
  # 일부 템플릿에서 Profile이 Release를 베이스로 쓰는 경우 대비하여 Release에도 profile 포함
  ensure_xcconfig_includes "Flutter/Release.xcconfig" '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"'
  ensure_xcconfig_includes "Flutter/Profile.xcconfig" '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"'

  # (C) 기존 통합 해제 + 잔재 정리
  if [[ -f "Podfile" ]]; then
    pod deintegrate || true
  fi
  rm -rf Pods Podfile.lock .symlinks Runner.xcworkspace

  # (D) (옵션) 딥 클린
  if $DEEP_PODS; then
    step "Deep CocoaPods clean (cache/spec repos) — may take a while"
    pod cache clean --all || true
    rm -rf ~/.cocoapods/repos/trunk || true
    pod setup
    pod repo update
  fi

  # (E) 설치 (알려진 베이스 구성 경고 문구는 필터링)
  pod_install_filtered

popd >/dev/null

# 4) Xcode DerivedData 전체 삭제(폴더 자체)
if [[ "$(uname -s)" == "Darwin" ]]; then
  step "Delete Xcode DerivedData (entire folder)"
  rm -rf "$HOME/Library/Developer/Xcode/DerivedData"
fi

step "Ready. 이제 Android Studio에서 ▶(Run) 또는 Xcode에서 ios/Runner.xcworkspace 로 빌드하세요."

