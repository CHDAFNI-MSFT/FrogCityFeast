#!/usr/bin/env bash
set -euo pipefail

require_gui_editors=false
if [[ "${1:-}" == "--require-gui-editors" ]]; then
  require_gui_editors=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--require-gui-editors]" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/tools/toolchain.json"
export PATH="$repo_root/.tools/bin:$PATH"

expected_godot_version="$(
  python3 -c \
    'import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["godot"]["version"])' \
    "$manifest"
)"

godot_version="$(godot --version)"
expected_godot_prefix="$expected_godot_version.stable."
if [[ "$godot_version" != "$expected_godot_prefix"* ]]; then
  echo "Expected Godot $expected_godot_version, found $godot_version." >&2
  exit 1
fi
echo "[ok] Godot $godot_version"

git lfs version
ffmpeg -version | head -n 1

if command -v magick >/dev/null 2>&1; then
  magick -version | head -n 1
elif command -v convert >/dev/null 2>&1; then
  convert -version | head -n 1
else
  echo "ImageMagick is not available." >&2
  exit 1
fi

if $require_gui_editors; then
  case "$(uname -s)" in
    Darwin)
      [[ -d "/Applications/Krita.app" ]] || {
        echo "Krita is not installed." >&2
        exit 1
      }
      [[ -d "/Applications/Audacity.app" ]] || {
        echo "Audacity is not installed." >&2
        exit 1
      }
      ;;
    Linux)
      command -v krita >/dev/null 2>&1 || {
        echo "Krita is not installed." >&2
        exit 1
      }
      command -v audacity >/dev/null 2>&1 || {
        echo "Audacity is not installed." >&2
        exit 1
      }
      ;;
  esac
fi

echo "Toolchain verification passed."
