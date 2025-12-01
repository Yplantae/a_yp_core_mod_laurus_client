#!/bin/sh
# ============================================================
# Flutter Multi-Target Build + Product Export (POSIX sh)
# - 최대 호환: 표준 /bin/sh (bash 3.2 포함)에서 동작
# - 단계별 예시/설명, 최종 요약(옵션/영향/예상 산출물/실행 커맨드) 후 확인 실행
# - 배포용 최종물만 1_PRODUCT/{platform}/{timestamp} 로 복사
# - 기본: 클린(Y), 모드=release, 난독화=yes, target=aab
# - NEW: --auto 프리셋 (모든 플랫폼 공통 릴리즈 기본, iOS는 ExportOptions 자동 적용)
# ============================================================

# -------- Colors (POSIX-safe: printf 사용) --------
BOLD="$(printf '\033[1m')"
DIM="$(printf '\033[2m')"
RED="$(printf '\033[31m')"
GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
RESET="$(printf '\033[0m')"

# -------- Defaults --------
NOW_STAMP="$(date +%Y%m%d_%H%M%S)"
DEFAULT_TARGETS="aab"            # aab,apk,ios,macos,linux,web,windows
DEFAULT_MODE="release"           # release|profile|debug
DEFAULT_OBFUSCATE="yes"          # yes|no
DEFAULT_SPLIT_DIR="build/symbols/${NOW_STAMP}"

# iOS 전용 기본 ExportOptions 경로
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
IOS_EXPORT_OPTIONS_PLIST_DEFAULT="${SCRIPT_DIR}/ios/export_options_appstore.plist"

# -------- State (mutable) --------
TARGETS="${DEFAULT_TARGETS}"
MODE="${DEFAULT_MODE}"
OBFUSCATE="${DEFAULT_OBFUSCATE}"
SPLIT_DIR="${DEFAULT_SPLIT_DIR}"
VERBOSE="no"
EXPORT_PRODUCTS="yes"
DO_CLEAN_REQUESTED="yes"         # 기본값: Y(예)
EXTRA_ARGS=""                    # (선택) '--' 뒤 인자 문자열
AUTO_PRESET="no"                 # NEW: --auto 사용 여부

# -------- Paths --------
OUT_BASE="${SCRIPT_DIR}/1_PRODUCT"

# -------- Small utils --------
lower() { printf "%s" "$1" | tr '[:upper:]' '[:lower:]'; }
is_macos() { [ "$(uname 2>/dev/null)" = "Darwin" ]; }
is_windows_shell() {
  case "$(uname 2>/dev/null)" in
    *MINGW*|*MSYS*|*CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

say() { printf "%s\n" "$*"; }
ok()  { printf "%s✓%s %s\n" "$GREEN" "$RESET" "$*"; }
warn(){ printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
err() { printf "%s✗%s %s\n" "$RED" "$RESET" "$*" >&2; }

# run: 실행 + 실패시 종료(명확한 메시지). 로그는 stderr로!
run() {
  _cmd="$*"
  printf "%s… run:%s %s\n" "$DIM" "$RESET" "$_cmd" >&2
  "$@"
  _ec=$?
  if [ $_ec -ne 0 ]; then
    err "command failed (exit=$_ec): $_cmd"
    exit $_ec
  fi
}

ensure_flutter() {
  if command -v flutter >/dev/null 2>&1; then
    return 0
  fi
  err "Flutter CLI not found in PATH."
  exit 1
}

# 안전 복사: 파일은 cp -p, 디렉토리는 rsync -a(없으면 cp -R). --delete 미사용.
# 복사 후 대상 폴더가 비면 경고.
copy_path() {
  _src="$1"
  _dst="$2"

  run mkdir -p "$_dst"

  if [ -d "$_src" ]; then
    if command -v rsync >/dev/null 2>&1; then
      run rsync -a "$_src"/ "$_dst"/
    else
      run cp -R "$_src" "$_dst"/
    fi
    _has="$(ls -A "$_dst" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$_has" -eq 0 ]; then
      warn "copy seems empty → $_dst"
    fi
  else
    run cp -p "$_src" "$_dst"/
    _dstfile="$_dst/$(basename "$_src")"
    if [ ! -f "$_dstfile" ]; then
      warn "file not found after copy: $_dstfile"
    fi
  fi
}

ensure_outdir() {
  _platform="$1"
  _dir="${OUT_BASE}/${_platform}/${NOW_STAMP}"
  run mkdir -p "$_dir"
  printf "%s" "$_dir"
}

# -------- Targets parsing (comma → space, dedup, lowercase) --------
TARGETS_LIST=""  # space-separated list
parse_targets() {
  TARGETS_LIST=""
  _SEEN=" "
  for _t in $(printf "%s" "$TARGETS" | tr ',' ' '); do
    _t_norm="$(lower "$_t")"
    [ -z "$_t_norm" ] && continue
    case " $_SEEN " in
      *" $_t_norm "*) ;; # already seen
      *)
        _SEEN="$_SEEN$_t_norm "
        TARGETS_LIST="$(printf "%s %s" "$TARGETS_LIST" "$_t_norm")"
        ;;
    esac
  done
  TARGETS_LIST="$(printf "%s" "$TARGETS_LIST" | sed 's/^ *//')"
}

# -------- Flags builders (POSIX: 단순 문자열) --------
obf_on() {
  _x="$(lower "$OBFUSCATE")"
  case "$_x" in y|yes|on|true) return 0 ;; *) return 1 ;; esac
}
verbose_flag() { [ "$VERBOSE" = "yes" ] && printf "%s" "-v" || printf "%s" ""; }
mode_flag()    { printf -- "--%s" "$MODE"; }
obf_flags() {
  if obf_on; then
    printf "%s" "--obfuscate --split-debug-info=$SPLIT_DIR"
  else
    printf "%s" ""
  fi
}

# -------- iOS EXTRA_ARGS 계산 (NEW: --auto 프리셋 반영) --------
# 사용자가 이미 --export-options-plist 지정 시 그 값을 우선.
ios_effective_extra_args() {
  _extra="$EXTRA_ARGS"
  case "$_extra" in
    *--export-options-plist=*) ;;  # 이미 지정됨 → 그대로 사용
    *)
      if [ "$AUTO_PRESET" = "yes" ] && [ -f "$IOS_EXPORT_OPTIONS_PLIST_DEFAULT" ]; then
        _extra="$_extra --export-options-plist=$IOS_EXPORT_OPTIONS_PLIST_DEFAULT"
      fi
      ;;
  esac
  printf "%s" "$_extra"
}

# -------- Builders --------
build_aab() {
  _V="$(verbose_flag)"; _M="$(mode_flag)"; _O="$(obf_flags)"
  run flutter build appbundle $_M ${_V:+$_V} $_O $EXTRA_ARGS
  ok "AAB build complete."
}
build_apk() {
  _V="$(verbose_flag)"; _M="$(mode_flag)"; _O="$(obf_flags)"
  run flutter build apk --split-per-abi $_M ${_V:+$_V} $_O $EXTRA_ARGS
  ok "APK build complete."
}
build_ios() {
  if ! is_macos; then err "iOS build requires macOS."; exit 1; fi
  _V="$(verbose_flag)"; _M="$(mode_flag)"; _O="$(obf_flags)"
  _EXTRA_IOS="$(ios_effective_extra_args)"
  run flutter build ipa $_M ${_V:+$_V} $_O $_EXTRA_IOS
  ok "IPA build complete."
}
build_macos() {
  if ! is_macos; then warn "macOS build requires macOS. Skipping."; return 0; fi
  _V="$(verbose_flag)"; _M="$(mode_flag)"; _O="$(obf_flags)"
  run flutter build macos $_M ${_V:+$_V} $_O $EXTRA_ARGS
  ok "macOS build complete."
}
build_linux() {
  _V="$(verbose_flag)"; _M="$(mode_flag)"; _O="$(obf_flags)"
  run flutter build linux $_M ${_V:+$_V} $_O $EXTRA_ARGS
  ok "Linux build complete."
}
build_web() {
  _V="$(verbose_flag)"; _M="$(mode_flag)"; _O="$(obf_flags)"
  run flutter build web $_M ${_V:+$_V} $_O $EXTRA_ARGS
  ok "Web build complete."
}
build_windows() {
  _V="$(verbose_flag)"; _M="$(mode_flag)"; _O="$(obf_flags)"
  run flutter build windows $_M ${_V:+$_V} $_O $EXTRA_ARGS
  ok "Windows build complete."
}

# -------- Exporters (only deployable artifacts) --------
export_aab() {
  _dst="$(ensure_outdir android-aab)"
  _f="$(ls -1 build/app/outputs/bundle/release/*.aab 2>/dev/null | head -n 1)"
  if [ -z "$_f" ]; then
    _f="$(ls -1 build/app/outputs/bundle/*/*.aab 2>/dev/null | head -n 1)"
  fi
  if [ -z "$_f" ]; then
    warn "No .aab found to export."
    return 0
  fi
  copy_path "$_f" "$_dst"
  ok "Exported AAB → $_dst"
}
export_apk() {
  _dst="$(ensure_outdir android-apk)"
  _count=0
  for _f in build/app/outputs/flutter-apk/*.apk; do
    [ -e "$_f" ] || continue
    copy_path "$_f" "$_dst"
    _count=$(( _count + 1 ))
  done
  if [ "$_count" -eq 0 ]; then warn "No .apk found to export."; return 0; fi
  ok "Exported APK(s) → $_dst"
}
export_ios() {
  _dst="$(ensure_outdir ios)"
  _f="$(ls -1 build/ios/ipa/*.ipa 2>/dev/null | head -n 1)"
  if [ -z "$_f" ]; then warn "No .ipa found to export."; return 0; fi
  copy_path "$_f" "$_dst"
  ok "Exported IPA → $_dst"
}
export_macos() {
  _dst="$(ensure_outdir macos)"
  _app="$(ls -1d build/macos/Build/Products/Release/*.app 2>/dev/null | head -n 1)"
  if [ -z "$_app" ]; then warn "No .app found to export."; return 0; fi
  copy_path "$_app" "$_dst"
  ok "Exported macOS .app → $_dst"
}
export_linux() {
  _dst="$(ensure_outdir linux)"
  _bundle="$(ls -1d build/linux/*/release/bundle 2>/dev/null | head -n 1)"
  if [ -z "$_bundle" ]; then warn "No linux bundle dir found to export."; return 0; fi
  copy_path "${_bundle}/" "${_dst}/"
  ok "Exported Linux bundle → $_dst"
}
export_web() {
  _dst="$(ensure_outdir web)"
  if [ ! -d "build/web" ]; then warn "No build/web dir found to export."; return 0; fi
  copy_path "build/web/" "${_dst}/"
  ok "Exported Web site → $_dst"
}
export_windows() {
  _dst="$(ensure_outdir windows)"
  _rel="$(ls -1d build/windows/*/runner/Release 2>/dev/null | head -n 1)"
  if [ -z "$_rel" ]; then warn "No windows Release dir found to export."; return 0; fi
  copy_path "${_rel}/" "${_dst}/"
  ok "Exported Windows Release → $_dst"
}

# -------- Clean (deferred; run just before building) --------
run_project_clean() {
  printf "%s▶ Running Project Clean%s\n" "$BOLD" "$RESET"

  if is_windows_shell; then
    if [ -f "${SCRIPT_DIR}/z_ClientCleanUp.bat" ] && command -v cmd.exe >/dev/null 2>&1; then
      run cmd.exe /c "$(printf "%s" "${SCRIPT_DIR}" | sed 's#/#\\#g')\\z_ClientCleanUp.bat" --deep
      return 0
    fi
  else
    if [ -f "${SCRIPT_DIR}/z_ClientCleanUp.sh" ]; then
      run chmod -x-w "${SCRIPT_DIR}/z_ClientCleanUp.sh" >/dev/null 2>&1 || true
      run chmod +x "${SCRIPT_DIR}/z_ClientCleanUp.sh"
      run "${SCRIPT_DIR}/z_ClientCleanUp.sh" --deep
      return 0
    fi
  fi

  if command -v flutter >/dev/null 2>&1; then
    run flutter clean
  else
    warn "flutter not found; skipping 'flutter clean'."
  fi
}

# -------- Interactive Wizard --------
interactive() {
  printf "%sFlutter Multi-Target Build (Interactive)%s\n\n" "$BOLD" "$RESET"

  printf "%s예시:%s aab(.aab) / apk(.apk) / ios(.ipa) / macOS(.app 폴더) / linux(bundle 폴더) / windows(Release 폴더) / web(정적 사이트 폴더)\n" "$DIM" "$RESET"
  printf "1) 대상 플랫폼들(쉼표 구분) [default: %s]: " "$DEFAULT_TARGETS"
  read ans_t
  [ -n "$ans_t" ] && TARGETS="$ans_t"

  printf "%s예시:%s release(배포용) / profile(성능분석) / debug(개발용)\n" "$DIM" "$RESET"
  printf "2) 빌드 모드 [default: %s]: " "$DEFAULT_MODE"
  read ans_m
  [ -n "$ans_m" ] && MODE="$(lower "$ans_m")"

  printf "%s설명:%s '난독화 적용'은 Dart 심볼 제거로 리버스엔지니어링 난이도 ↑. 크래시 역추적 위해 심볼 디렉터리 저장 권장.\n" "$DIM" "$RESET"
  printf "3) 난독화 적용? (on/off) [default: %s]: " "$DEFAULT_OBFUSCATE"
  read ans_o
  [ -n "$ans_o" ] && OBFUSCATE="$(lower "$ans_o")"

  if obf_on; then
    printf "%s설명:%s '--split-debug-info' 디렉터리 = 난독화 복원(스택 역매핑) 심볼(.json) 저장 위치\n" "$DIM" "$RESET"
    printf "%s예시:%s build/symbols  또는  %s\n" "$DIM" "$RESET" "$DEFAULT_SPLIT_DIR"
    printf "4) 심볼 저장 디렉터리 경로 [default: %s]: " "$DEFAULT_SPLIT_DIR"
    read ans_s
    [ -n "$ans_s" ] && SPLIT_DIR="$ans_s"
  fi

  printf "%s예시:%s y → -v 상세로그 / n → 요약로그\n" "$DIM" "$RESET"
  printf "5) verbose 출력할까요? [y/N]: "
  read ans_v
  ans_v="$(lower "${ans_v:-n}")"
  case "$ans_v" in y|yes) VERBOSE="yes" ;; *) VERBOSE="no" ;; esac

  printf "%s설명:%s '예' 선택 시 최종 실행 직전에 z_ClientCleanUp.sh/.bat --deep (있으면) 또는 flutter clean 실행 (기본: 예)\n" "$DIM" "$RESET"
  printf "6) 빌드 전 클린을 수행할까요? [Y/n]: "
  read ans_c
  ans_c="$(lower "${ans_c:-y}")"
  case "$ans_c" in n|no) DO_CLEAN_REQUESTED="no" ;; *) DO_CLEAN_REQUESTED="yes" ;; esac

  printf "%s설명:%s 빌드 후 최종 배포물만 1_PRODUCT/{platform}/%s 로 복사합니다.\n" "$DIM" "$RESET" "$NOW_STAMP"
  printf "7) 산출물을 1_PRODUCT 로 복사할까요? [Y/n]: "
  read ans_e
  ans_e="$(lower "${ans_e:-y}")"
  case "$ans_e" in n|no) EXPORT_PRODUCTS="no" ;; *) EXPORT_PRODUCTS="yes" ;; esac

  printf "%s옵션:%s --auto 프리셋을 쓰려면 CLI에서 직접 --auto를 주면 됩니다.\n" "$DIM" "$RESET"
}

# -------- Expected outputs (for summary) --------
print_expected_outputs() {
  for T in $TARGETS_LIST; do
    case "$T" in
      aab)     say "  - android-aab → build/app/outputs/bundle/release/*.aab     → export → 1_PRODUCT/android-aab/${NOW_STAMP}/" ;;
      apk)     say "  - android-apk → build/app/outputs/flutter-apk/*.apk        → export → 1_PRODUCT/android-apk/${NOW_STAMP}/" ;;
      ios)     say "  - ios         → build/ios/ipa/*.ipa                         → export → 1_PRODUCT/ios/${NOW_STAMP}/" ;;
      macos)   say "  - macos       → build/macos/Build/Products/Release/*.app    → export → 1_PRODUCT/macos/${NOW_STAMP}/" ;;
      linux)   say "  - linux       → build/linux/*/release/bundle/               → export → 1_PRODUCT/linux/${NOW_STAMP}/" ;;
      web)     say "  - web         → build/web/                                   → export → 1_PRODUCT/web/${NOW_STAMP}/" ;;
      windows) say "  - windows     → build/windows/*/runner/Release/              → export → 1_PRODUCT/windows/${NOW_STAMP}/" ;;
      *)       say "  - ${T}        → (unknown target)" ;;
    esac
  done
}

print_planned_commands() {
  _V="$(verbose_flag)"; _M="$(mode_flag)"; _O="$(obf_flags)"
  for T in $TARGETS_LIST; do
    case "$T" in
      aab)     say "  flutter build appbundle $_M ${_V:+$_V} $_O $EXTRA_ARGS" ;;
      apk)     say "  flutter build apk --split-per-abi $_M ${_V:+$_V} $_O $EXTRA_ARGS" ;;
      ios)
        _EXTRA_IOS="$(ios_effective_extra_args)"
        say "  flutter build ipa $_M ${_V:+$_V} $_O $_EXTRA_IOS"
        ;;
      macos)   say "  flutter build macos $_M ${_V:+$_V} $_O $EXTRA_ARGS" ;;
      linux)   say "  flutter build linux $_M ${_V:+$_V} $_O $EXTRA_ARGS" ;;
      web)     say "  flutter build web $_M ${_V:+$_V} $_O $EXTRA_ARGS" ;;
      windows) say "  flutter build windows $_M ${_V:+$_V} $_O $EXTRA_ARGS" ;;
      *)       say "  (unknown target: $T)" ;;
    esac
  done
}

print_summary() {
  printf "%sSummary (Planned)%s\n" "$BOLD" "$RESET"
  say "  targets           : $TARGETS_LIST"
  say "  mode              : $MODE"
  say "  obfuscate         : $OBFUSCATE"
  if obf_on; then say "  split-debug-info  : $SPLIT_DIR"; fi
  if [ "$VERBOSE" = "yes" ]; then say "  verbose           : on"; else say "  verbose           : off"; fi
  say "  clean before build: $DO_CLEAN_REQUESTED"
  say "  export products   : $EXPORT_PRODUCTS"
  say "  auto preset       : $AUTO_PRESET"
  say "  expected outputs  :"
  print_expected_outputs
  say "  will run commands :"
  print_planned_commands
  printf "\n"
}

print_diagnostics() {
  printf "%sDiagnostics%s\n" "$BOLD" "$RESET"
  printf "  Shell:     "; (sh --version 2>/dev/null || echo "$(ps -p $$ -o comm=)"); printf "\n"
  printf "  System:    "; uname -a 2>/dev/null || true; printf "\n"
  if command -v flutter >/dev/null 2>&1; then
    printf "  Flutter:   "; flutter --version 2>/dev/null | head -n 3
    printf "  Dart:      "; dart --version 2>/dev/null || true; printf "\n"
  else
    printf "  Flutter:   not found in PATH\n"
  fi
  printf "\n"
}

# -------- Final confirmation + Execute --------
final_confirm_and_execute() {
  print_summary
  print_diagnostics

  printf "위 설정으로 실행할까요? [Y/n]: "
  read final_ans
  final_ans="$(lower "${final_ans:-y}")"
  case "$final_ans" in
    n|no)
      warn "Aborted by user."
      exit 0
      ;;
    *)
      ;;
  esac

  # Clean (deferred)
  if [ "$DO_CLEAN_REQUESTED" = "yes" ]; then
    run_project_clean
  fi

  # Build
  ensure_flutter
  if obf_on; then run mkdir -p "$SPLIT_DIR"; fi

  for T in $TARGETS_LIST; do
    case "$T" in
      aab)     build_aab     ;;
      apk)     build_apk     ;;
      ios)     build_ios     ;;
      macos)   build_macos   ;;
      linux)   build_linux   ;;
      web)     build_web     ;;
      windows) build_windows ;;
      *)       warn "Unknown target '$T' skipped." ;;
    esac
  done

  # Export
  if [ "$EXPORT_PRODUCTS" = "yes" ]; then
    run mkdir -p "$OUT_BASE"
    for T in $TARGETS_LIST; do
      case "$T" in
        aab)     export_aab     ;;
        apk)     export_apk     ;;
        ios)     export_ios     ;;
        macos)   export_macos   ;;
        linux)   export_linux   ;;
        web)     export_web     ;;
        windows) export_windows ;;
        *)       ;;
      esac
    done
    say ""
    ok "All products exported under: ${OUT_BASE}/<platform>/${NOW_STAMP}"
  fi

  ok "All requested builds finished."
}

# -------- CLI parsing --------
if [ "$#" -gt 0 ]; then
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -t|--targets)
        TARGETS="$2"; shift 2 ;;
      -m|--mode)
        MODE="$(lower "$2")"; shift 2 ;;
      -o|--obfuscate)
        OBFUSCATE="$(lower "$2")"; shift 2 ;;
      -S|--split-dir)
        SPLIT_DIR="$2"; shift 2 ;;
      -v|--verbose)
        VERBOSE="yes"; shift 1 ;;
      -c|--clean)
        DO_CLEAN_REQUESTED="yes"; shift 1 ;;
      --no-export)
        EXPORT_PRODUCTS="no"; shift 1 ;;
      --auto)  # NEW: 프리셋
        AUTO_PRESET="yes"
        MODE="release"   # 모든 플랫폼 공통 릴리즈 기본
        shift 1 ;;
      -h|--help)
        printf "%sUsage%s: %s [options]\n" "$BOLD" "$RESET" "$0"
        say "  -t, --targets LIST     aab,apk,ios,macos,linux,web,windows (comma)"
        say "  -m, --mode MODE        release|profile|debug"
        say "  -o, --obfuscate on|off yes|no"
        say "  -S, --split-dir PATH   path for --split-debug-info"
        say "  -v, --verbose          add -v to flutter build"
        say "  -c, --clean            run cleanup before build (default: on)"
        say "  --no-export            skip export to 1_PRODUCT"
        say "  --auto                 release 프리셋(+ iOS는 ExportOptions 자동 적용)"
        say "  --                     pass the following args directly to flutter build"
        exit 0 ;;
      --)
        shift
        EXTRA_ARGS="$*"
        break ;;
      *)
        err "Unknown arg: $1"; exit 1 ;;
    esac
  done
else
  interactive
fi

# -------- Normalize & Guard --------
parse_targets
if [ -z "$TARGETS_LIST" ]; then
  err "No valid targets specified."
  exit 1
fi

# -------- Final step --------
final_confirm_and_execute

