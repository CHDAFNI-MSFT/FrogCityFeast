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

ad_hoc_device_env_names=(
  IOS_AD_HOC_DEVICE_UDID_1
  IOS_AD_HOC_DEVICE_UDID_2
  IOS_AD_HOC_DEVICE_UDID_3
)
for device_env_name in "${ad_hoc_device_env_names[@]}"; do
  device_udid="${!device_env_name:-}"
  if [[ -z "$device_udid" ]]; then
    echo "$device_env_name is required." >&2
    exit 1
  fi
  echo "::add-mask::$device_udid"
done

archive_path="$repo_root/build/ios/FrogCityFeast-AdHoc.xcarchive"
export_path="$RUNNER_TEMP/ios-ad-hoc-export"
export_options_path="$RUNNER_TEMP/AdHocExportOptions.plist"
exported_profile="$RUNNER_TEMP/frogcityfeast-exported-profile.mobileprovision"
exported_profile_plist="$RUNNER_TEMP/frogcityfeast-exported-profile.plist"

rm -rf -- "$archive_path" "$export_path"
rm -f -- "$export_options_path" "$exported_profile" "$exported_profile_plist"

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

python3 "$repo_root/scripts/create-export-options.py" \
  --team-id "$APPLE_TEAM_ID" \
  --bundle-id "$IOS_BUNDLE_ID" \
  --profile-name "$IOS_PROVISIONING_PROFILE_NAME" \
  --distribution ad-hoc \
  --output "$export_options_path"

xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options_path" \
  -exportPath "$export_path"

ipa_paths=()
while IFS= read -r -d '' candidate; do
  ipa_paths+=("$candidate")
done < <(
  find "$export_path" -maxdepth 1 -type f -name "*.ipa" -print0
)
if (( ${#ipa_paths[@]} != 1 )); then
  echo "Expected exactly one Ad Hoc IPA; found ${#ipa_paths[@]}." >&2
  exit 1
fi
ipa_path="${ipa_paths[0]}"

app_paths=()
while IFS= read -r -d '' candidate; do
  app_paths+=("$candidate")
done < <(
  find "$archive_path/Products/Applications" \
    -maxdepth 1 \
    -type d \
    -name "*.app" \
    -print0
)
if (( ${#app_paths[@]} != 1 )); then
  echo "Expected exactly one archived app; found ${#app_paths[@]}." >&2
  exit 1
fi
codesign --verify --deep --strict "${app_paths[0]}"

if ! unzip -p "$ipa_path" "Payload/*.app/embedded.mobileprovision" > "$exported_profile"; then
  echo "The exported IPA does not contain a provisioning profile." >&2
  exit 1
fi
security cms -D -i "$exported_profile" > "$exported_profile_plist"

python3 - \
  "$exported_profile_plist" \
  "$APPLE_TEAM_ID" \
  "$IOS_BUNDLE_ID" \
  "${ad_hoc_device_env_names[@]}" <<'PY'
import os
import plistlib
import re
import sys

profile_path, team_id, bundle_id, *device_env_names = sys.argv[1:]
with open(profile_path, "rb") as source:
    profile = plistlib.load(source)

udid_pattern = re.compile(
    r"^(?:[A-Fa-f0-9]{40}|[A-Fa-f0-9]{8}-[A-Fa-f0-9]{16})$"
)
expected_devices = set()
for environment_name in device_env_names:
    device_udid = os.environ.get(environment_name)
    if not device_udid or not udid_pattern.fullmatch(device_udid):
        raise SystemExit("An approved device UDID is missing or malformed.")
    normalized_device_udid = device_udid.upper()
    if normalized_device_udid in expected_devices:
        raise SystemExit("The approved device UDIDs must be unique.")
    expected_devices.add(normalized_device_udid)

entitlements = profile.get("Entitlements", {})
if entitlements.get("application-identifier") != f"{team_id}.{bundle_id}":
    raise SystemExit("The exported IPA profile has the wrong application identifier.")
if entitlements.get("get-task-allow") is not False:
    raise SystemExit("The exported IPA permits development debugging.")
devices = profile.get("ProvisionedDevices")
if not isinstance(devices, list) or not all(
    isinstance(profile_udid, str) and udid_pattern.fullmatch(profile_udid)
    for profile_udid in devices
):
    raise SystemExit("The exported IPA profile has a malformed device list.")
profile_devices = {profile_udid.upper() for profile_udid in devices}
if len(profile_devices) != len(devices):
    raise SystemExit("The exported IPA profile contains duplicate device UDIDs.")
if profile_devices != expected_devices:
    raise SystemExit(
        "The exported IPA profile does not exactly match the approved devices."
    )
if profile.get("ProvisionsAllDevices") is True:
    raise SystemExit("The exported IPA uses enterprise provisioning.")
PY

ipa_sha256="$(shasum -a 256 "$ipa_path" | awk '{print $1}')"
echo "Ad Hoc IPA validated with SHA-256 $ipa_sha256."
echo "No signed package was uploaded or published."
