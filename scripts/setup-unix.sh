#!/usr/bin/env bash
set -euo pipefail

include_gui_editors=false
if [[ "${1:-}" == "--include-gui-editors" ]]; then
  include_gui_editors=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--include-gui-editors]" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/tools/toolchain.json"
tools_root="$repo_root/.tools"
downloads_dir="$tools_root/downloads"
godot_root="$tools_root/godot"
bin_dir="$tools_root/bin"

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

install_system_tools() {
  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null 2>&1 || {
        echo "Homebrew is required on macOS: https://brew.sh" >&2
        exit 1
      }
      brew install python git-lfs imagemagick ffmpeg
      if $include_gui_editors; then
        brew install --cask krita audacity
      fi
      ;;
    Linux)
      command -v apt-get >/dev/null 2>&1 || {
        echo "The automated Linux setup currently supports apt-based hosts." >&2
        exit 1
      }

      local sudo_command=()
      if [[ "$(id -u)" -ne 0 ]]; then
        command -v sudo >/dev/null 2>&1 || {
          echo "sudo is required to install Linux packages." >&2
          exit 1
        }
        sudo_command=(sudo)
      fi

      "${sudo_command[@]}" apt-get update
      "${sudo_command[@]}" apt-get install -y \
        ca-certificates curl unzip python3 git-lfs imagemagick ffmpeg
      if $include_gui_editors; then
        "${sudo_command[@]}" apt-get install -y krita audacity
      fi
      ;;
    *)
      echo "Unsupported operating system: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

install_godot() {
  local version release_tag platform_key asset expected_hash
  local archive partial_archive install_dir executable actual_hash

  version="$(read_manifest godot.version)"
  release_tag="$(read_manifest godot.releaseTag)"

  case "$(uname -s):$(uname -m)" in
    Darwin:*)
      platform_key="macosUniversal"
      ;;
    Linux:x86_64|Linux:amd64)
      platform_key="linuxX64"
      ;;
    Linux:aarch64|Linux:arm64)
      platform_key="linuxArm64"
      ;;
    *)
      echo "No pinned Godot build for $(uname -s) $(uname -m)." >&2
      exit 1
      ;;
  esac

  asset="$(read_manifest "godot.downloads.$platform_key.asset")"
  expected_hash="$(read_manifest "godot.downloads.$platform_key.sha512")"
  archive="$downloads_dir/$asset"
  partial_archive="$archive.partial"
  install_dir="$godot_root/$version"

  mkdir -p "$downloads_dir" "$install_dir" "$bin_dir"

  if [[ -f "$archive" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
      actual_hash="$(shasum -a 512 "$archive" | awk '{print $1}')"
    else
      actual_hash="$(sha512sum "$archive" | awk '{print $1}')"
    fi
    if [[ "$actual_hash" != "$expected_hash" ]]; then
      echo "Removing cached Godot archive with an invalid checksum."
      rm -f "$archive"
    fi
  fi

  if [[ ! -f "$archive" ]]; then
    rm -f "$partial_archive"
    curl --fail --location --output "$partial_archive" \
      "https://github.com/godotengine/godot/releases/download/$release_tag/$asset"

    if [[ "$(uname -s)" == "Darwin" ]]; then
      actual_hash="$(shasum -a 512 "$partial_archive" | awk '{print $1}')"
    else
      actual_hash="$(sha512sum "$partial_archive" | awk '{print $1}')"
    fi
    if [[ "$actual_hash" != "$expected_hash" ]]; then
      rm -f "$partial_archive"
      echo "Godot archive checksum verification failed." >&2
      exit 1
    fi
    mv "$partial_archive" "$archive"
  fi

  if [[ ! -f "$archive" ]]; then
    echo "Godot archive checksum verification failed." >&2
    exit 1
  fi

  unzip -q -o "$archive" -d "$install_dir"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    executable="$install_dir/Godot.app/Contents/MacOS/Godot"
  else
    executable="$install_dir/${asset%.zip}"
  fi

  chmod +x "$executable"
  ln -sfn "$executable" "$bin_dir/godot"
}

install_system_tools
command -v python3 >/dev/null 2>&1 || {
  echo "python3 installation did not provide a python3 command." >&2
  exit 1
}
install_godot
git lfs install

echo
echo "Tool installation complete."
echo "Add this directory to PATH for the current shell:"
echo "  export PATH=\"$bin_dir:\$PATH\""
echo "Then run scripts/verify-unix.sh."
