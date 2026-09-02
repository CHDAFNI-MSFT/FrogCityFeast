#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner_temp="${RUNNER_TEMP:-}"
installed_profile_name="FrogCityFeast-CI.mobileprovision"
cleanup_failed=0

remove_file() {
  local path="$1"
  if ! rm -f -- "$path"; then
    echo "Failed to remove temporary file: $path" >&2
    cleanup_failed=1
  elif [[ -e "$path" || -L "$path" ]]; then
    echo "Temporary file remains after cleanup: $path" >&2
    cleanup_failed=1
  fi
}

remove_tree() {
  local path="$1"
  if ! rm -rf -- "$path"; then
    echo "Failed to remove temporary directory: $path" >&2
    cleanup_failed=1
  elif [[ -e "$path" || -L "$path" ]]; then
    echo "Temporary directory remains after cleanup: $path" >&2
    cleanup_failed=1
  fi
}

if [[ -n "$runner_temp" ]]; then
  keychain_path="$runner_temp/frogcityfeast-signing.keychain-db"
  if [[ -e "$keychain_path" || -L "$keychain_path" ]]; then
    if ! security delete-keychain "$keychain_path" 2>/dev/null; then
      echo "Failed to delete the temporary signing keychain." >&2
      cleanup_failed=1
    fi
    if [[ -e "$keychain_path" || -L "$keychain_path" ]]; then
      echo "The temporary signing keychain remains after cleanup." >&2
      cleanup_failed=1
    fi
  fi

  for path in \
    "$runner_temp/frogcityfeast-distribution.p12" \
    "$runner_temp/frogcityfeast-distribution.pem" \
    "$runner_temp/frogcityfeast-provisioning.mobileprovision" \
    "$runner_temp/frogcityfeast-profile.plist" \
    "$runner_temp/TestFlightExportOptions.plist" \
    "$runner_temp/AppStoreExportOptions.plist" \
    "$runner_temp/AdHocExportOptions.plist" \
    "$runner_temp/frogcityfeast-exported-profile.mobileprovision" \
    "$runner_temp/frogcityfeast-exported-profile.plist"; do
    remove_file "$path"
  done

  remove_tree "$runner_temp/app-store-connect"
  remove_tree "$runner_temp/ios-upload"
  remove_tree "$runner_temp/ios-ad-hoc-export"
fi

remove_file \
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$installed_profile_name"
remove_file \
  "$HOME/Library/MobileDevice/Provisioning Profiles/$installed_profile_name"
remove_tree "$repo_root/build"

if (( cleanup_failed != 0 )); then
  echo "Temporary iOS signing cleanup was incomplete." >&2
  exit 1
fi

echo "Temporary iOS signing material was removed and verified."
