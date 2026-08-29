#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
derived_data="$repo_root/build/ios/DerivedData"

: "${IOS_XCODE_PROJECT:?IOS_XCODE_PROJECT is required.}"
: "${IOS_XCODE_SCHEME:?IOS_XCODE_SCHEME is required.}"

rm -rf -- "$derived_data"

xcodebuild \
  -project "$IOS_XCODE_PROJECT" \
  -scheme "$IOS_XCODE_SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM="" \
  build

echo "Unsigned generic iOS device build passed."
