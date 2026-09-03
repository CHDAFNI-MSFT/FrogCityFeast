#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${RUNNER_TEMP:?RUNNER_TEMP is required.}"
: "${GITHUB_ENV:?GITHUB_ENV is required.}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required.}"
: "${IOS_BUNDLE_ID:?IOS_BUNDLE_ID is required.}"
: "${APPLE_CERTIFICATE_BASE64:?APPLE_CERTIFICATE_BASE64 is required.}"
: "${APPLE_CERTIFICATE_PASSWORD:?APPLE_CERTIFICATE_PASSWORD is required.}"

signing_distribution="${IOS_SIGNING_DISTRIBUTION:-app-store}"
ad_hoc_device_env_names=()
profile_input_mode=""
case "$signing_distribution" in
  app-store)
    : "${APPLE_PROVISIONING_PROFILE_BASE64:?APPLE_PROVISIONING_PROFILE_BASE64 is required for App Store signing.}"
    if [[ -n "${APPLE_PROVISIONING_PROFILE_PATH:-}" ]]; then
      echo "APPLE_PROVISIONING_PROFILE_PATH is not permitted for App Store signing." >&2
      exit 1
    fi
    profile_input_mode="base64"
    ;;
  ad-hoc)
    profile_input_count=0
    if [[ -n "${APPLE_PROVISIONING_PROFILE_BASE64:-}" ]]; then
      profile_input_mode="base64"
      profile_input_count=$((profile_input_count + 1))
    fi
    if [[ -n "${APPLE_PROVISIONING_PROFILE_PATH:-}" ]]; then
      profile_input_mode="path"
      profile_input_count=$((profile_input_count + 1))
    fi
    if (( profile_input_count != 1 )); then
      echo "Ad Hoc signing requires exactly one provisioning profile Base64 value or path." >&2
      exit 1
    fi

    normalized_device_udids=()
    normalized_device_count=0
    for device_env_name in \
      IOS_AD_HOC_DEVICE_UDID_1 \
      IOS_AD_HOC_DEVICE_UDID_2 \
      IOS_AD_HOC_DEVICE_UDID_3; do
      device_udid="${!device_env_name:-}"
      if [[ -z "$device_udid" ]]; then
        echo "$device_env_name is required." >&2
        exit 1
      fi
      if [[ ! "$device_udid" =~ ^([A-Fa-f0-9]{40}|[A-Fa-f0-9]{8}-[A-Fa-f0-9]{16})$ ]]; then
        echo "$device_env_name has an unsupported format." >&2
        exit 1
      fi

      normalized_device_udid="$(
        printf "%s" "$device_udid" | tr "[:lower:]" "[:upper:]"
      )"
      if (( normalized_device_count > 0 )); then
        for existing_device_udid in "${normalized_device_udids[@]}"; do
          if [[ "$normalized_device_udid" == "$existing_device_udid" ]]; then
            echo "The protected Ad Hoc device UDIDs must be unique." >&2
            exit 1
          fi
        done
      fi

      normalized_device_udids+=("$normalized_device_udid")
      normalized_device_count=$((normalized_device_count + 1))
      ad_hoc_device_env_names+=("$device_env_name")
      echo "::add-mask::$device_udid"
    done
    ;;
  *)
    echo "IOS_SIGNING_DISTRIBUTION must be app-store or ad-hoc." >&2
    exit 1
    ;;
esac

certificate_path="$RUNNER_TEMP/frogcityfeast-distribution.p12"
profile_path="$RUNNER_TEMP/frogcityfeast-provisioning.mobileprovision"
profile_plist="$RUNNER_TEMP/frogcityfeast-profile.plist"
certificate_pem="$RUNNER_TEMP/frogcityfeast-distribution.pem"
signing_identity_pem="$RUNNER_TEMP/frogcityfeast-signing-identity.pem"
keychain_path="$RUNNER_TEMP/frogcityfeast-signing.keychain-db"
installed_profile_name="FrogCityFeast-CI.mobileprovision"
modern_profile_dir="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
legacy_profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"

decode_base64() {
  printf "%s" "$1" |
    python3 -c \
      'import base64, binascii, sys
try:
    encoded = b"".join(sys.stdin.buffer.read().split())
    sys.stdout.buffer.write(base64.b64decode(encoded, validate=True))
except binascii.Error as error:
    raise SystemExit(f"Invalid base64 secret: {error}")' \
      > "$2"
}

decode_base64 "$APPLE_CERTIFICATE_BASE64" "$certificate_path"
if [[ "$profile_input_mode" == "base64" ]]; then
  decode_base64 "$APPLE_PROVISIONING_PROFILE_BASE64" "$profile_path"
else
  expected_api_profile_path="$RUNNER_TEMP/frogcityfeast-api-provisioning.mobileprovision"
  if [[ "$APPLE_PROVISIONING_PROFILE_PATH" != "$expected_api_profile_path" ]]; then
    echo "The API provisioning profile path is not the expected RUNNER_TEMP file." >&2
    exit 1
  fi
  if [[ -L "$APPLE_PROVISIONING_PROFILE_PATH" || ! -f "$APPLE_PROVISIONING_PROFILE_PATH" ]]; then
    echo "The API provisioning profile path must be a regular non-symlink file." >&2
    exit 1
  fi
  runner_temp_directory="$(cd "$RUNNER_TEMP" && pwd -P)"
  profile_source_directory="$(
    cd "$(dirname "$APPLE_PROVISIONING_PROFILE_PATH")" && pwd -P
  )"
  if [[ "$profile_source_directory" != "$runner_temp_directory" ]]; then
    echo "The API provisioning profile must be located directly under RUNNER_TEMP." >&2
    exit 1
  fi
  if [[ -L "$profile_path" ]]; then
    echo "The validated provisioning profile destination must not be a symlink." >&2
    exit 1
  fi
  cp "$APPLE_PROVISIONING_PROFILE_PATH" "$profile_path"
fi
chmod 600 "$certificate_path" "$profile_path"

security cms -D -i "$profile_path" > "$profile_plist"
chmod 600 "$profile_plist"
profile_uuid="$(/usr/libexec/PlistBuddy -c "Print :UUID" "$profile_plist")"
profile_name="$(/usr/libexec/PlistBuddy -c "Print :Name" "$profile_plist")"
profile_team_id="$(
  /usr/libexec/PlistBuddy -c "Print :TeamIdentifier:0" "$profile_plist"
)"
profile_application_id="$(
  /usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" \
    "$profile_plist"
)"

if [[ ! "$profile_uuid" =~ ^[A-Fa-f0-9-]{36}$ ]]; then
  echo "The provisioning profile UUID is malformed." >&2
  exit 1
fi

if [[ "$profile_name" == *$'\n'* || "$profile_name" == *$'\r'* ]]; then
  echo "The provisioning profile name contains an invalid newline." >&2
  exit 1
fi

if [[ "$profile_team_id" != "$APPLE_TEAM_ID" ]]; then
  echo "The provisioning profile Team ID does not match APPLE_TEAM_ID." >&2
  exit 1
fi

if [[ "$profile_application_id" != "$APPLE_TEAM_ID.$IOS_BUNDLE_ID" ]]; then
  echo "The provisioning profile does not match IOS_BUNDLE_ID." >&2
  exit 1
fi

if ! openssl pkcs12 \
  -in "$certificate_path" \
  -clcerts \
  -nokeys \
  -passin env:APPLE_CERTIFICATE_PASSWORD \
  -out "$certificate_pem" \
  >/dev/null 2>&1; then
  echo "The Apple Distribution certificate could not be decoded." >&2
  exit 1
fi
chmod 600 "$certificate_pem"

if ! openssl pkcs12 \
  -in "$certificate_path" \
  -clcerts \
  -nodes \
  -passin env:APPLE_CERTIFICATE_PASSWORD \
  -out "$signing_identity_pem" \
  >/dev/null 2>&1; then
  echo "The Apple Distribution signing identity could not be decoded." >&2
  exit 1
fi
chmod 600 "$signing_identity_pem"

validation_args=(
  --profile-plist "$profile_plist"
  --certificate-pem "$certificate_pem"
  --team-id "$APPLE_TEAM_ID"
  --bundle-id "$IOS_BUNDLE_ID"
  --distribution "$signing_distribution"
)
if [[ "$signing_distribution" == "ad-hoc" ]]; then
  for device_env_name in "${ad_hoc_device_env_names[@]}"; do
    validation_args+=(--device-udid-env "$device_env_name")
  done
fi

python3 "$repo_root/scripts/validate-ios-signing-material.py" \
  "${validation_args[@]}"

mkdir -p "$modern_profile_dir" "$legacy_profile_dir"
cp "$profile_path" "$modern_profile_dir/$installed_profile_name"
cp "$profile_path" "$legacy_profile_dir/$installed_profile_name"

keychain_password="$(openssl rand -base64 32)"
security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"

existing_keychains=()
existing_keychain_count=0
while IFS= read -r existing_keychain; do
  existing_keychains+=("$existing_keychain")
  existing_keychain_count=$((existing_keychain_count + 1))
done < <(
  security list-keychains -d user |
    sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//'
)
if (( existing_keychain_count > 0 )); then
  security list-keychains \
    -d user \
    -s "$keychain_path" \
    "${existing_keychains[@]}"
else
  security list-keychains -d user -s "$keychain_path"
fi

security import "$signing_identity_pem" \
  -k "$keychain_path" \
  -f pemseq \
  -T /usr/bin/codesign
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$keychain_password" \
  "$keychain_path"

if ! security find-identity -v -p codesigning "$keychain_path" |
  grep "Apple Distribution" >/dev/null; then
  echo "The certificate does not provide an Apple Distribution identity." >&2
  exit 1
fi

{
  # Godot 4.7.2 reads the release UUID from the debug override constant.
  echo "GODOT_APPLE_PLATFORM_PROVISIONING_PROFILE_UUID_DEBUG=$profile_uuid"
  echo "GODOT_APPLE_PLATFORM_PROVISIONING_PROFILE_UUID_RELEASE=$profile_uuid"
  echo "GODOT_APPLE_PLATFORM_PROFILE_SPECIFIER_RELEASE=$profile_name"
  echo "IOS_PROVISIONING_PROFILE_NAME=$profile_name"
  echo "IOS_KEYCHAIN_PATH=$keychain_path"
} >> "$GITHUB_ENV"

echo "::add-mask::$profile_uuid"
echo "::add-mask::$profile_name"
echo "Apple signing material is ready in the temporary keychain."
