#!/usr/bin/env bash
set -euo pipefail

include_gui_editors=false
install_export_templates=false
skip_system_tools=false

usage() {
  echo "Usage: $0 [--include-gui-editors] [--install-export-templates] [--skip-system-tools]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-gui-editors)
      include_gui_editors=true
      ;;
    --install-export-templates)
      install_export_templates=true
      ;;
    --skip-system-tools)
      skip_system_tools=true
      ;;
    *)
      usage
      exit 2
      ;;
  esac
  shift
done

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

sha512_file() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    shasum -a 512 "$1" | awk '{print $1}'
  else
    sha512sum "$1" | awk '{print $1}'
  fi
}

download_verified() {
  local url="$1"
  local destination="$2"
  local expected_hash="$3"
  local partial_destination="$destination.partial"
  local actual_hash

  mkdir -p "$(dirname "$destination")"

  if [[ -f "$destination" ]]; then
    actual_hash="$(sha512_file "$destination")"
    if [[ "$actual_hash" != "$expected_hash" ]]; then
      echo "Removing cached download with an invalid checksum: $destination"
      rm -f -- "$destination"
    fi
  fi

  if [[ ! -f "$destination" ]]; then
    rm -f -- "$partial_destination"
    curl --fail --location --output "$partial_destination" "$url"
    actual_hash="$(sha512_file "$partial_destination")"
    if [[ "$actual_hash" != "$expected_hash" ]]; then
      rm -f -- "$partial_destination"
      echo "Checksum verification failed for $url." >&2
      exit 1
    fi
    mv "$partial_destination" "$destination"
  fi
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
  local archive install_dir executable

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
  install_dir="$godot_root/$version"

  mkdir -p "$downloads_dir" "$install_dir" "$bin_dir"
  download_verified \
    "https://github.com/godotengine/godot/releases/download/$release_tag/$asset" \
    "$archive" \
    "$expected_hash"

  unzip -q -o "$archive" -d "$install_dir"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    executable="$install_dir/Godot.app/Contents/MacOS/Godot"
  else
    executable="$install_dir/${asset%.zip}"
  fi

  chmod +x "$executable"
  ln -sfn "$executable" "$bin_dir/godot"
}

install_export_templates() {
  local version release_tag asset expected_hash archive
  local expected_template_version template_root template_dir
  local staging_dir template_source embedded_version

  version="$(read_manifest godot.version)"
  release_tag="$(read_manifest godot.releaseTag)"
  asset="$(read_manifest godot.downloads.exportTemplates.asset)"
  expected_hash="$(read_manifest godot.downloads.exportTemplates.sha512)"
  archive="$downloads_dir/$asset"
  expected_template_version="$version.stable"

  case "$(uname -s)" in
    Darwin)
      template_root="$HOME/Library/Application Support/Godot/export_templates"
      ;;
    Linux)
      template_root="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"
      ;;
    *)
      echo "Export template installation is unsupported on $(uname -s)." >&2
      exit 1
      ;;
  esac

  template_dir="$template_root/$expected_template_version"
  if [[ -f "$template_dir/version.txt" ]]; then
    embedded_version="$(tr -d '\r\n' < "$template_dir/version.txt")"
    if [[ "$embedded_version" == "$expected_template_version" ]]; then
      echo "Godot export templates $expected_template_version are already installed."
      return
    fi
  fi

  download_verified \
    "https://github.com/godotengine/godot/releases/download/$release_tag/$asset" \
    "$archive" \
    "$expected_hash"

  staging_dir="$(mktemp -d "$tools_root/export-templates.XXXXXX")"
  unzip -q "$archive" -d "$staging_dir"
  template_source="$staging_dir/templates"

  if [[ ! -f "$template_source/version.txt" ]]; then
    rm -rf -- "$staging_dir"
    echo "The export template archive has an unexpected layout." >&2
    exit 1
  fi

  embedded_version="$(tr -d '\r\n' < "$template_source/version.txt")"
  if [[ "$embedded_version" != "$expected_template_version" ]]; then
    rm -rf -- "$staging_dir"
    echo "Expected template version $expected_template_version, found $embedded_version." >&2
    exit 1
  fi

  case "$template_dir" in
    "$template_root"/*) ;;
    *)
      rm -rf -- "$staging_dir"
      echo "Refusing to replace an unsafe template path: $template_dir" >&2
      exit 1
      ;;
  esac

  rm -rf -- "$template_dir"
  mkdir -p "$template_dir"
  cp -R "$template_source/." "$template_dir/"
  rm -rf -- "$staging_dir"
  echo "Installed Godot export templates $expected_template_version."
}

if ! $skip_system_tools; then
  install_system_tools
fi

for required_command in python3 curl unzip git git-lfs; do
  command -v "$required_command" >/dev/null 2>&1 || {
    echo "$required_command is required." >&2
    exit 1
  }
done

install_godot
if $install_export_templates; then
  install_export_templates
fi
git lfs install

echo
echo "Tool installation complete."
echo "Add this directory to PATH for the current shell:"
echo "  export PATH=\"$bin_dir:\$PATH\""
echo "Then run scripts/verify-unix.sh."
