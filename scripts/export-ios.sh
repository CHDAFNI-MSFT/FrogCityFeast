#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-$repo_root/.tools/bin/godot}"
build_root="$repo_root/build/ios"
export_target="$build_root/SamuelIcecream"
xcode_project="$build_root/SamuelIcecream.xcodeproj"
logs_dir="$repo_root/build/logs"
ios_display_name="Frog City Feast"

: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required.}"
: "${IOS_BUNDLE_ID:?IOS_BUNDLE_ID is required.}"
: "${IOS_SHORT_VERSION:?IOS_SHORT_VERSION is required.}"
: "${IOS_BUILD_NUMBER:?IOS_BUILD_NUMBER is required.}"

rm -rf -- "$build_root"
mkdir -p "$build_root" "$logs_dir"

cleanup_generated_preset() {
  rm -f -- "$repo_root/export_presets.cfg"
}
trap cleanup_generated_preset EXIT

python3 "$repo_root/scripts/render-export-presets.py" \
  --team-id "$APPLE_TEAM_ID" \
  --bundle-id "$IOS_BUNDLE_ID" \
  --short-version "$IOS_SHORT_VERSION" \
  --build-number "$IOS_BUILD_NUMBER"

run_godot() {
  local label="$1"
  shift
  local log_path="$logs_dir/godot-ios-$label.log"

  if ! "$godot_bin" "$@" 2>&1 | tee "$log_path"; then
    echo "Godot failed during iOS $label." >&2
    exit 1
  fi

  if grep -E "SCRIPT ERROR:|Parse Error:|Failed to load script" "$log_path"; then
    echo "Godot reported project errors during iOS $label." >&2
    exit 1
  fi
}

run_godot import --headless --path "$repo_root" --import
run_godot export \
  --headless \
  --path "$repo_root" \
  --export-release "iOS" \
  "$export_target"

if [[ ! -d "$xcode_project" ]]; then
  echo "Godot did not create the expected Xcode project: $xcode_project" >&2
  exit 1
fi

python3 "$repo_root/scripts/validate-ios-generated-project.py" \
  --build-root "$build_root" \
  --app-dir "$export_target" \
  --xcode-project "$xcode_project" \
  --team-id "$APPLE_TEAM_ID" \
  --bundle-id "$IOS_BUNDLE_ID" \
  --display-name "$ios_display_name" \
  --short-version "$IOS_SHORT_VERSION" \
  --build-number "$IOS_BUILD_NUMBER"

xcode_list_json="$build_root/xcode-project.json"
xcodebuild -list -project "$xcode_project" -json > "$xcode_list_json"
xcode_scheme="$(
  python3 -c \
    'import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
schemes = data.get("project", {}).get("schemes", [])
if len(schemes) != 1:
    raise SystemExit(f"Expected one Xcode scheme, found {len(schemes)}.")
print(schemes[0])' \
    "$xcode_list_json"
)"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "xcode_project=$xcode_project"
    echo "xcode_scheme=$xcode_scheme"
  } >> "$GITHUB_OUTPUT"
fi

echo "Exported Xcode project: $xcode_project"
echo "Xcode scheme: $xcode_scheme"
