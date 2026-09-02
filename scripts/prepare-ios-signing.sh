#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${RUNNER_TEMP:?RUNNER_TEMP is required.}"
: "${GITHUB_ENV:?GITHUB_ENV is required.}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required.}"
: "${IOS_BUNDLE_ID:?IOS_BUNDLE_ID is required.}"
: "${APPLE_CERTIFICATE_BASE64:?APPLE_CERTIFICATE_BASE64 is required.}"
: "${APPLE_CERTIFICATE_PASSWORD:?APPLE_CERTIFICATE_PASSWORD is required.}"
: "${APPLE_PROVISIONING_PROFILE_BASE64:?APPLE_PROVISIONING_PROFILE_BASE64 is required.}"

certificate_path="$RUNNER_TEMP/frogcityfeast-distribution.p12"
profile_path="$RUNNER_TEMP/frogcityfeast-app-store.mobileprovision"
profile_plist="$RUNNER_TEMP/frogcityfeast-profile.plist"
certificate_pem="$RUNNER_TEMP/frogcityfeast-distribution.pem"
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
decode_base64 "$APPLE_PROVISIONING_PROFILE_BASE64" "$profile_path"
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

python3 "$repo_root/scripts/validate-ios-signing-material.py" \
  --profile-plist "$profile_plist" \
  --certificate-pem "$certificate_pem" \
  --team-id "$APPLE_TEAM_ID" \
  --bundle-id "$IOS_BUNDLE_ID"

mkdir -p "$modern_profile_dir" "$legacy_profile_dir"
cp "$profile_path" "$modern_profile_dir/$installed_profile_name"
cp "$profile_path" "$legacy_profile_dir/$installed_profile_name"

keychain_password="$(openssl rand -base64 32)"
security create-keychain -p "$keychain_password" "$keychain_path"
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"

existing_keychains=()
while IFS= read -r existing_keychain; do
  existing_keychains+=("$existing_keychain")
done < <(
  security list-keychains -d user |
    sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//'
)
security list-keychains \
  -d user \
  -s "$keychain_path" \
  "${existing_keychains[@]}"

security import "$certificate_path" \
  -k "$keychain_path" \
  -P "$APPLE_CERTIFICATE_PASSWORD" \
  -t cert \
  -f pkcs12 \
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
