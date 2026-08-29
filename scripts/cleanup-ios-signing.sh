#!/usr/bin/env bash
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner_temp="${RUNNER_TEMP:-}"
installed_profile_name="SamuelIcecream-CI.mobileprovision"

if [[ -n "$runner_temp" ]]; then
  security delete-keychain \
    "$runner_temp/samuelicecream-signing.keychain-db" \
    2>/dev/null || true
  rm -f -- \
    "$runner_temp/samuelicecream-distribution.p12" \
    "$runner_temp/samuelicecream-app-store.mobileprovision" \
    "$runner_temp/samuelicecream-profile.plist" \
    "$runner_temp/TestFlightExportOptions.plist"
  rm -rf -- \
    "$runner_temp/app-store-connect" \
    "$runner_temp/ios-upload"
fi

rm -f -- \
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$installed_profile_name" \
  "$HOME/Library/MobileDevice/Provisioning Profiles/$installed_profile_name"
rm -rf -- "$repo_root/build/ios"

echo "Temporary iOS signing material was removed."
