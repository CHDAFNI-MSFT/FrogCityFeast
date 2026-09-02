#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

: "${RUNNER_TEMP:?RUNNER_TEMP is required.}"
: "${IOS_XCODE_PROJECT:?IOS_XCODE_PROJECT is required.}"
: "${IOS_XCODE_SCHEME:?IOS_XCODE_SCHEME is required.}"
: "${IOS_KEYCHAIN_PATH:?IOS_KEYCHAIN_PATH is required.}"
: "${IOS_PROVISIONING_PROFILE_NAME:?IOS_PROVISIONING_PROFILE_NAME is required.}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required.}"
: "${IOS_BUNDLE_ID:?IOS_BUNDLE_ID is required.}"
: "${IOS_DISTRIBUTION:?IOS_DISTRIBUTION is required.}"
: "${APP_STORE_CONNECT_KEY_ID:?APP_STORE_CONNECT_KEY_ID is required.}"
: "${APP_STORE_CONNECT_ISSUER_ID:?APP_STORE_CONNECT_ISSUER_ID is required.}"
: "${APP_STORE_CONNECT_PRIVATE_KEY_BASE64:?APP_STORE_CONNECT_PRIVATE_KEY_BASE64 is required.}"

if [[ ! "$APP_STORE_CONNECT_KEY_ID" =~ ^[A-Za-z0-9]{10}$ ]]; then
  echo "APP_STORE_CONNECT_KEY_ID must contain 10 alphanumeric characters." >&2
  exit 1
fi

if [[ ! "$APP_STORE_CONNECT_ISSUER_ID" =~ ^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$ ]]; then
  echo "APP_STORE_CONNECT_ISSUER_ID must be a UUID." >&2
  exit 1
fi

archive_path="$repo_root/build/ios/FrogCityFeast.xcarchive"
export_path="$RUNNER_TEMP/ios-upload"
api_key_dir="$RUNNER_TEMP/app-store-connect"

case "$IOS_DISTRIBUTION" in
  internal-testflight)
    export_options_path="$RUNNER_TEMP/TestFlightExportOptions.plist"
    ;;
  app-store)
    export_options_path="$RUNNER_TEMP/AppStoreExportOptions.plist"
    ;;
  *)
    echo "IOS_DISTRIBUTION must be internal-testflight or app-store." >&2
    exit 1
    ;;
esac

rm -rf -- "$archive_path" "$export_path" "$api_key_dir"

xcodebuild \
  -project "$IOS_XCODE_PROJECT" \
  -scheme "$IOS_XCODE_SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -archivePath "$archive_path" \
  -derivedDataPath "$repo_root/build/ios/DerivedData" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  PROVISIONING_PROFILE_SPECIFIER="$IOS_PROVISIONING_PROFILE_NAME" \
  OTHER_CODE_SIGN_FLAGS="--keychain $IOS_KEYCHAIN_PATH" \
  archive

mkdir -p "$api_key_dir"
api_key_path="$api_key_dir/AuthKey_$APP_STORE_CONNECT_KEY_ID.p8"
printf "%s" "$APP_STORE_CONNECT_PRIVATE_KEY_BASE64" |
  python3 -c \
    'import base64, binascii, sys
try:
    encoded = b"".join(sys.stdin.buffer.read().split())
    sys.stdout.buffer.write(base64.b64decode(encoded, validate=True))
except binascii.Error as error:
    raise SystemExit(f"Invalid App Store Connect key: {error}")' \
    > "$api_key_path"
chmod 600 "$api_key_path"

if ! openssl pkey -in "$api_key_path" -check -noout >/dev/null 2>&1; then
  echo "The decoded App Store Connect key is not a valid private key." >&2
  exit 1
fi

python3 "$repo_root/scripts/create-export-options.py" \
  --team-id "$APPLE_TEAM_ID" \
  --bundle-id "$IOS_BUNDLE_ID" \
  --profile-name "$IOS_PROVISIONING_PROFILE_NAME" \
  --distribution "$IOS_DISTRIBUTION" \
  --output "$export_options_path"

xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options_path" \
  -exportPath "$export_path" \
  -authenticationKeyPath "$api_key_path" \
  -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"

if [[ "$IOS_DISTRIBUTION" == "internal-testflight" ]]; then
  echo "The signed build was uploaded for internal-only TestFlight testing."
else
  echo "The signed build was uploaded as a normal App Store candidate."
  echo "It was not submitted for App Review or released."
fi
