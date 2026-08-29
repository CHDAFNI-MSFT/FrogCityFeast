#!/usr/bin/env bash
set -euo pipefail

mode="${1:-smoke}"
if [[ "$mode" != "smoke" && "$mode" != "release" ]]; then
  echo "Usage: $0 [smoke|release]" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/tools/toolchain.json"
godot_bin="${GODOT_BIN:-$repo_root/.tools/bin/godot}"

read_manifest() {
  python3 -c \
    'import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
value = data
for key in sys.argv[2].split("."):
    value = value[key]
print(value)' \
    "$manifest" "$1"
}

for command_name in python3 xcodebuild xcode-select xcrun unzip; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "$command_name is required for iOS builds." >&2
    exit 1
  }
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS exports require macOS." >&2
  exit 1
fi

if [[ ! -f "$repo_root/project.godot" ]]; then
  echo "project.godot is missing." >&2
  exit 1
fi

if [[ ! -x "$godot_bin" ]]; then
  echo "Pinned Godot executable is missing: $godot_bin" >&2
  exit 1
fi

: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required.}"
: "${IOS_BUNDLE_ID:?IOS_BUNDLE_ID is required.}"
: "${IOS_SHORT_VERSION:?IOS_SHORT_VERSION is required.}"
: "${IOS_BUILD_NUMBER:?IOS_BUILD_NUMBER is required.}"

if [[ ! "$APPLE_TEAM_ID" =~ ^[A-Za-z0-9]{10}$ ]]; then
  echo "APPLE_TEAM_ID must contain exactly 10 alphanumeric characters." >&2
  exit 1
fi

if [[ ! "$IOS_BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "IOS_BUNDLE_ID must use reverse-DNS syntax." >&2
  exit 1
fi

if [[ ! "$IOS_SHORT_VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "IOS_SHORT_VERSION must contain one to three numeric components." >&2
  exit 1
fi

if [[ ! "$IOS_BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "IOS_BUILD_NUMBER must contain one to three numeric components." >&2
  exit 1
fi

expected_godot_version="$(read_manifest godot.version)"
actual_godot_version="$("$godot_bin" --version)"
if [[ "$actual_godot_version" != "$expected_godot_version.stable."* ]]; then
  echo "Expected Godot $expected_godot_version, found $actual_godot_version." >&2
  exit 1
fi

template_version="$expected_godot_version.stable"
template_dir="$HOME/Library/Application Support/Godot/export_templates/$template_version"
if [[ ! -f "$template_dir/version.txt" ]]; then
  echo "Godot export templates are missing from $template_dir." >&2
  exit 1
fi

expected_xcode_version="$(read_manifest appleBuild.xcodeVersion)"
actual_xcode_version="$(xcodebuild -version | sed -n '1s/^Xcode //p')"
if [[ "$actual_xcode_version" != "$expected_xcode_version" ]]; then
  echo "Expected Xcode $expected_xcode_version, found $actual_xcode_version." >&2
  exit 1
fi

expected_developer_dir="$(read_manifest appleBuild.xcodeDeveloperDir)"
actual_developer_dir="$(xcode-select -p)"
if [[ "$actual_developer_dir" != "$expected_developer_dir" ]]; then
  echo "Expected xcode-select to use $expected_developer_dir, found $actual_developer_dir." >&2
  exit 1
fi

expected_ios_sdk="$(read_manifest appleBuild.iosSdkVersion)"
actual_ios_sdk="$(xcrun --sdk iphoneos --show-sdk-version)"
if [[ "$actual_ios_sdk" != "$expected_ios_sdk" ]]; then
  echo "Expected iOS SDK $expected_ios_sdk, found $actual_ios_sdk." >&2
  exit 1
fi

if [[ "$mode" == "release" ]]; then
  for command_name in security codesign openssl; do
    command -v "$command_name" >/dev/null 2>&1 || {
      echo "$command_name is required for signed releases." >&2
      exit 1
    }
  done
  if [[ ! -x "/usr/libexec/PlistBuddy" ]]; then
    echo "/usr/libexec/PlistBuddy is required for signed releases." >&2
    exit 1
  fi
fi

echo "iOS $mode preflight passed."
