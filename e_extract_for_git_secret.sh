#!/usr/bin/env bash
# e_extract_for_git_secret.sh
# macOS 전용 — 프로젝트 루트 기준 상대경로로 파일을 찾아
# GitHub Secrets에 붙여넣을 값을 항목별로 출력합니다.
# * 파일(.jks/.p12/.mobileprovision/.p8/…): base64(1줄)
# * 문자열: 실제값 출력 (SHOW_SECRET_VALUES=0이면 비노출)

set -euo pipefail

############################################
# 0) CONFIG — 여기만 수정
############################################
ENV_SUFFIX="PROD"        # DEV / STAGE / PROD
SHOW_SECRET_VALUES=1     # 1: 문자열값 출력, 0: 미출력(안내만)
COPY_TO_CLIPBOARD=0      # 1: 각 항목 출력 후 pbcopy

# Android (프로젝트 루트 기준)
KEY_PROPERTIES_FILE="android/key.properties"
ANDROID_KEYSTORE_CANDIDATES=(
  "android/app/keystore.jks"
  "android/keystore.jks"
)
ANDROID_GOOGLE_SERVICES_JSON_FILE="android/app/google-services.json"  # (선택)

# iOS
IOS_CERT_P12_FILE="ios/certs/dist.p12"                        # .p12 (필수)
IOS_CERT_PASSWORD_FILE="ios/certs/dist.p12.pass"              # (선택) .p12 암호 텍스트
IOS_PROVISION_FILE="ios/profiles/app.mobileprovision"         # .mobileprovision (필수)
APPSTORE_P8_CANDIDATES=( "ios/AuthKey_*.p8" )                 # (선택) App Store Connect API 키
IOS_PLIST_FILE="ios/Runner/GoogleService-Info.plist"          # (선택) iOS Firebase

# (선택) App Store Connect Key ID/Issuer ID 텍스트 파일 경로(없으면 env로 입력)
APPSTORE_KEY_ID_FILE="ios/appstoreconnect_key_id.txt"
APPSTORE_ISSUER_ID_FILE="ios/appstoreconnect_issuer_id.txt"

# (선택) Hosting SA
FIREBASE_HOSTING_SA_FILE="ops/firebase-hosting-sa.json"

PRINT_SHA256=1
SHOW_OPTIONALS=1
############################################


############################################
# 유틸
############################################
b64() { /usr/bin/base64 < "$1" | tr -d '\n'; }
sha256() { command -v shasum >/dev/null 2>&1 && shasum -a 256 "$1" | awk '{print $1}' || echo "(no shasum)"; }
hr() { printf '%*s\n' "${COLUMNS:-100}" '' | tr ' ' '='; }

find_first() {
  local arr=("$@")
  for p in "${arr[@]}"; do
    for q in $p; do
      [[ -f "$q" ]] && { echo "$q"; return 0; }
    done
  done
  return 1
}

prop_get() {
  local file="$1" ; local key="$2"
  awk -v K="$key" '
    BEGIN{ FS="=" }
    /^[[:space:]]*#/ {next}
    NF>=1 {
      k=$1; sub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      if (k==K) {
        v=substr($0, index($0, "=")+1)
        sub(/^[[:space:]]+/, "", v); sub(/[[:space:]\r]+$/, "", v)
        print v; exit
      }
    }' "$file"
}

emit_copy_block() {
  local title="$1" ; local value="$2"
  echo "-----8<----- COPY THIS VALUE: START ${title} -----8<-----"
  echo "${value}"
  echo "-----8<----- COPY THIS VALUE: END   ${title} -----8<-----"
  if [[ "${COPY_TO_CLIPBOARD}" -eq 1 ]]; then
    printf "%s" "${value}" | pbcopy
    echo "(copied) ${title} → clipboard"
  fi
}

print_file_secret() {
  local secret_name="$1"; local file_path="$2"; local req_opt="$3"
  echo; hr
  echo "SECRET NAME : ${secret_name}"
  echo "SOURCE FILE : ${file_path}"
  echo "HOW TO PASTE: GitHub → Settings → Secrets and variables → Actions → (Environment: ${ENV_SUFFIX}) → New secret"
  echo "             Name=${secret_name}, Value=아래 base64 본문(START/END 제외) 붙여넣기"
  if [[ ! -f "$file_path" ]]; then
    echo "STATUS      : ${req_opt} file NOT FOUND → 건너뜀"
    hr; return 0
  fi
  local size; size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "?")
  local sum=""; [[ "$PRINT_SHA256" -eq 1 ]] && sum=$(sha256 "$file_path")
  local val; val=$(b64 "$file_path")
  echo "FILE SIZE   : ${size} bytes"
  [[ -n "$sum" ]] && echo "SHA-256     : ${sum}"
  echo
  emit_copy_block "${secret_name}" "${val}"
  hr
}

print_string_secret_from_file() {
  local secret_name="$1"; local file_path="$2"; local key="$3"
  echo; hr
  echo "SECRET NAME : ${secret_name}"
  echo "SOURCE      : ${file_path} → ${key}"
  echo "HOW TO PASTE: GitHub → Settings → Secrets and variables → Actions → (Environment: ${ENV_SUFFIX}) → New secret"
  echo "             Name=${secret_name}, Value=아래 문자열 그대로 붙여넣기"
  if [[ ! -f "$file_path" ]]; then
    echo "STATUS      : source file NOT FOUND"
    hr; return 0
  fi
  local val; val="$(prop_get "$file_path" "$key" || true)"
  if [[ -z "${val}" ]]; then
    echo "STATUS      : key '${key}' NOT FOUND in ${file_path}"
    hr; return 0
  fi
  if [[ "${SHOW_SECRET_VALUES}" -eq 1 ]]; then
    echo; emit_copy_block "${secret_name}" "${val}"
  else
    echo; echo "(hidden) SHOW_SECRET_VALUES=0 → 값 미출력. 파일에서 직접 복사하세요."
  fi
  hr
}

print_string_secret() {
  local secret_name="$1"; local value="${2:-}"
  echo; hr
  echo "SECRET NAME : ${secret_name}"
  echo "HOW TO PASTE: GitHub → Settings → Secrets and variables → Actions → (Environment: ${ENV_SUFFIX}) → New secret"
  echo "             Name=${secret_name}, Value=아래 문자열 그대로 붙여넣기"
  if [[ -z "${value}" ]]; then
    echo; echo "(empty) 값을 스크립트에 전달하거나 수동 입력하세요. (예: IOS_CERT_PASSWORD 환경변수)"
  else
    if [[ "${SHOW_SECRET_VALUES}" -eq 1 ]]; then
      echo; emit_copy_block "${secret_name}" "${value}"
    else
      echo; echo "(hidden) SHOW_SECRET_VALUES=0 → 값 미출력"
    fi
  fi
  hr
}

print_string_secret_from_plain_file() {
  local secret_name="$1"; local file_path="$2"
  echo; hr
  echo "SECRET NAME : ${secret_name}"
  echo "SOURCE FILE : ${file_path}"
  echo "HOW TO PASTE: GitHub → Settings → Secrets and variables → Actions → (Environment: ${ENV_SUFFIX}) → New secret"
  if [[ ! -f "$file_path" ]]; then
    echo "STATUS      : source file NOT FOUND"
    hr; return 0
  fi
  local val; val="$(cat "$file_path")"
  if [[ "${SHOW_SECRET_VALUES}" -eq 1 ]]; then
    echo; emit_copy_block "${secret_name}" "${val}"
  else
    echo; echo "(hidden) SHOW_SECRET_VALUES=0 → 값 미출력"
  fi
  hr
}

print_info_only() {
  local secret_name="$1"; local note="$2"
  echo; hr
  echo "SECRET NAME : ${secret_name}"
  echo "HOW TO PASTE: GitHub → Settings → Secrets and variables → Actions → (Environment: ${ENV_SUFFIX}) → New secret"
  echo "INFO        : ${note}"
  hr
}

# INVENTORY용 헬퍼
inv_status_glob() { local g="$1"; for f in $g; do [[ -f "$f" ]] && { echo "FOUND"; return; }; done; echo "NOT FOUND"; }
inv_status_file() { [[ -f "$1" ]] && echo "FOUND" || echo "NOT FOUND"; }
inv_status_env()  { [[ -n "${!1-}" ]] && echo "SET" || echo "EMPTY"; }
inv_row() { printf "%-42s | %-22s | %-35s | %-9s\n" "$1" "$2" "$3" "$4"; }

echo "== Emit GitHub Secrets (ENV_SUFFIX=${ENV_SUFFIX}) =="

############################################
# INVENTORY — 대상 파일·경로 및 사용처 요약
############################################
hr
echo "# INVENTORY — 대상 파일·경로 및 사용처 요약"
echo
printf "%-42s | %-22s | %-35s | %-9s\n" "Path (glob ok)" "Purpose" "Suggested Secret Name" "Status"
printf "%-42s-+-%-22s-+-%-35s-+-%-9s\n" "$(printf '%.0s-' {1..42})" "$(printf '%.0s-' {1..22})" "$(printf '%.0s-' {1..35})" "$(printf '%.0s-' {1..9})"

# Android
KS_FOUND_PATH="$(find_first "${ANDROID_KEYSTORE_CANDIDATES[@]}" || true)"
inv_row "${KS_FOUND_PATH:-${ANDROID_KEYSTORE_CANDIDATES[0]}}" "Android keystore" "ANDROID_KEYSTORE_B64_${ENV_SUFFIX}" "$( [[ -n "$KS_FOUND_PATH" ]] && echo FOUND || echo NOT\ FOUND )"
inv_row "${KEY_PROPERTIES_FILE}" "Android signing props" "ANDROID_KEYSTORE_PASSWORD_${ENV_SUFFIX}" "$(inv_status_file "${KEY_PROPERTIES_FILE}")"
inv_row "${KEY_PROPERTIES_FILE}" "Android signing props" "ANDROID_KEY_ALIAS_${ENV_SUFFIX}"     "$(inv_status_file "${KEY_PROPERTIES_FILE}")"
inv_row "${KEY_PROPERTIES_FILE}" "Android signing props" "ANDROID_KEY_PASSWORD_${ENV_SUFFIX}"  "$(inv_status_file "${KEY_PROPERTIES_FILE}")"
inv_row "${ANDROID_GOOGLE_SERVICES_JSON_FILE}" "(opt) Firebase Android" "GOOGLE_SERVICES_JSON_${ENV_SUFFIX}_B64" "$(inv_status_file "${ANDROID_GOOGLE_SERVICES_JSON_FILE}")"

# iOS
inv_row "${IOS_CERT_P12_FILE}" "iOS dist cert (.p12)" "IOS_CERT_P12_B64_${ENV_SUFFIX}" "$(inv_status_file "${IOS_CERT_P12_FILE}")"
inv_row "ENV:IOS_CERT_PASSWORD or ${IOS_CERT_PASSWORD_FILE}" "iOS .p12 password" "IOS_CERT_PASSWORD_${ENV_SUFFIX}" "$( [[ -n "${IOS_CERT_PASSWORD-}" ]] && echo SET || ( [[ -f "${IOS_CERT_PASSWORD_FILE}" ]] && echo FOUND || echo EMPTY ) )"
inv_row "${IOS_PROVISION_FILE}" "iOS prov profile" "IOS_PROVISION_PROFILE_B64_${ENV_SUFFIX}" "$(inv_status_file "${IOS_PROVISION_FILE}")"
inv_row "ios/AuthKey_*.p8" "ASC API key (.p8)" "APPSTORE_API_KEY_P8_${ENV_SUFFIX}_B64" "$(inv_status_glob "ios/AuthKey_*.p8")"
inv_row "${APPSTORE_KEY_ID_FILE}" "ASC API Key ID" "APPSTORE_API_KEY_ID_${ENV_SUFFIX}" "$(inv_status_file "${APPSTORE_KEY_ID_FILE}")"
inv_row "${APPSTORE_ISSUER_ID_FILE}" "ASC Issuer ID" "APPSTORE_ISSUER_ID_${ENV_SUFFIX}" "$(inv_status_file "${APPSTORE_ISSUER_ID_FILE}")"
inv_row "${IOS_PLIST_FILE}" "(opt) Firebase iOS" "IOS_GOOGLE_SERVICE_INFO_${ENV_SUFFIX}_B64" "$(inv_status_file "${IOS_PLIST_FILE}")"
inv_row "${FIREBASE_HOSTING_SA_FILE}" "(opt) Hosting SA" "FIREBASE_HOSTING_SA_JSON_${ENV_SUFFIX}_B64" "$(inv_status_file "${FIREBASE_HOSTING_SA_FILE}")"
hr

############################################
# 1) ANDROID — (기존 로직 그대로)
############################################
echo; echo "### ANDROID"
KS=$(find_first "${ANDROID_KEYSTORE_CANDIDATES[@]}") || KS=""
if [[ -z "${KS}" ]]; then
  echo; hr
  echo "SECRET NAME : ANDROID_KEYSTORE_B64_${ENV_SUFFIX}"
  echo "SOURCE FILE : ${ANDROID_KEYSTORE_CANDIDATES[*]}"
  echo "STATUS      : REQUIRED keystore 파일을 찾지 못함 → CONFIG에서 경로 수정"
  hr
else
  print_file_secret "ANDROID_KEYSTORE_B64_${ENV_SUFFIX}" "${KS}" "REQUIRED"
fi

print_string_secret_from_file "ANDROID_KEYSTORE_PASSWORD_${ENV_SUFFIX}" "${KEY_PROPERTIES_FILE}" "storePassword"
print_string_secret_from_file "ANDROID_KEY_ALIAS_${ENV_SUFFIX}"         "${KEY_PROPERTIES_FILE}" "keyAlias"
print_string_secret_from_file "ANDROID_KEY_PASSWORD_${ENV_SUFFIX}"      "${KEY_PROPERTIES_FILE}" "keyPassword"

[[ "$SHOW_OPTIONALS" -eq 1 ]] && print_file_secret "GOOGLE_SERVICES_JSON_${ENV_SUFFIX}_B64" "${ANDROID_GOOGLE_SERVICES_JSON_FILE}" "OPTIONAL"

############################################
# 2) iOS / iPadOS — (추가)
############################################
echo; echo "### iOS / iPadOS"

# 2-1) 필수 파일: .p12 / .mobileprovision
print_file_secret "IOS_CERT_P12_B64_${ENV_SUFFIX}"          "${IOS_CERT_P12_FILE}"   "REQUIRED"
print_file_secret "IOS_PROVISION_PROFILE_B64_${ENV_SUFFIX}" "${IOS_PROVISION_FILE}"  "REQUIRED"

# 2-2) .p12 암호: env > 파일 > 안내
IOS_CERT_PASSWORD_VAL="${IOS_CERT_PASSWORD-}"
if [[ -z "${IOS_CERT_PASSWORD_VAL}" && -f "${IOS_CERT_PASSWORD_FILE}" ]]; then
  IOS_CERT_PASSWORD_VAL="$(cat "${IOS_CERT_PASSWORD_FILE}")"
fi
if [[ -n "${IOS_CERT_PASSWORD_VAL}" ]]; then
  print_string_secret "IOS_CERT_PASSWORD_${ENV_SUFFIX}" "${IOS_CERT_PASSWORD_VAL}"
else
  print_info_only "IOS_CERT_PASSWORD_${ENV_SUFFIX}" "환경변수 IOS_CERT_PASSWORD 또는 ${IOS_CERT_PASSWORD_FILE} 파일로 제공하세요."
fi

# 2-3) .mobileprovision 파싱 → 프로파일명 / TeamID / BundleID
if [[ -f "${IOS_PROVISION_FILE}" ]]; then
  PLIST_XML="$(/usr/bin/security cms -D -i "${IOS_PROVISION_FILE}" 2>/dev/null || true)"
  PROFILE_NAME="$(printf "%s" "$PLIST_XML" | /usr/bin/plutil -extract Name raw -o - - 2>/dev/null || true)"
  TEAM_ID="$(printf "%s" "$PLIST_XML" | /usr/bin/plutil -extract TeamIdentifier.0 raw -o - - 2>/dev/null || true)"
  APPID="$(printf "%s" "$PLIST_XML" | /usr/bin/plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null || true)"
  BUNDLE_ID="${APPID#${TEAM_ID}.}"

  [[ -n "${PROFILE_NAME}" ]] && print_string_secret "IOS_PROFILE_NAME_${ENV_SUFFIX}" "${PROFILE_NAME}"
  [[ -n "${TEAM_ID}"     ]] && print_string_secret "APPLE_TEAM_ID_${ENV_SUFFIX}"     "${TEAM_ID}"
  [[ -n "${BUNDLE_ID}"   ]] && print_string_secret "IOS_BUNDLE_ID_${ENV_SUFFIX}"     "${BUNDLE_ID}"
else
  echo; hr
  echo "INFO        : ${IOS_PROVISION_FILE} 를 찾을 수 없어 프로파일 메타 파싱을 생략합니다."
  hr
fi

# 2-4) (선택) App Store Connect API 키(.p8) → base64
P8_FILE="$(find_first "${APPSTORE_P8_CANDIDATES[@]}")" || P8_FILE=""
if [[ -n "${P8_FILE}" ]]; then
  print_file_secret "APPSTORE_API_KEY_P8_${ENV_SUFFIX}_B64" "${P8_FILE}" "OPTIONAL"
else
  echo; hr
  echo "SECRET NAME : APPSTORE_API_KEY_P8_${ENV_SUFFIX}_B64"
  echo "SOURCE FILE : ${APPSTORE_P8_CANDIDATES[*]}"
  echo "STATUS      : OPTIONAL .p8 파일을 찾지 못함 → 자동 업로드 미사용 시 정상"
  hr
fi

# 2-5) (선택) App Store Connect Key ID / Issuer ID — 파일 > env > 안내
if [[ -f "${APPSTORE_KEY_ID_FILE}" ]]; then
  print_string_secret_from_plain_file "APPSTORE_API_KEY_ID_${ENV_SUFFIX}" "${APPSTORE_KEY_ID_FILE}"
elif [[ -n "${APPSTORE_API_KEY_ID-}" ]]; then
  print_string_secret "APPSTORE_API_KEY_ID_${ENV_SUFFIX}" "${APPSTORE_API_KEY_ID}"
else
  print_info_only "APPSTORE_API_KEY_ID_${ENV_SUFFIX}" "App Store Connect → Keys → Key ID (또는 ${APPSTORE_KEY_ID_FILE} 파일에 저장)"
fi

if [[ -f "${APPSTORE_ISSUER_ID_FILE}" ]]; then
  print_string_secret_from_plain_file "APPSTORE_ISSUER_ID_${ENV_SUFFIX}" "${APPSTORE_ISSUER_ID_FILE}"
elif [[ -n "${APPSTORE_ISSUER_ID-}" ]]; then
  print_string_secret "APPSTORE_ISSUER_ID_${ENV_SUFFIX}" "${APPSTORE_ISSUER_ID}"
else
  print_info_only "APPSTORE_ISSUER_ID_${ENV_SUFFIX}" "App Store Connect → Keys → Issuer ID(UUID) (또는 ${APPSTORE_ISSUER_ID_FILE} 파일에 저장)"
fi

# 2-6) (선택) iOS Firebase plist → base64
if [[ "$SHOW_OPTIONALS" -eq 1 ]]; then
  print_file_secret "IOS_GOOGLE_SERVICE_INFO_${ENV_SUFFIX}_B64" "${IOS_PLIST_FILE}" "OPTIONAL"
fi

# 2-7) (선택) Hosting SA → base64
if [[ "$SHOW_OPTIONALS" -eq 1 ]]; then
  print_file_secret "FIREBASE_HOSTING_SA_JSON_${ENV_SUFFIX}_B64" "${FIREBASE_HOSTING_SA_FILE}" "OPTIONAL"
fi

