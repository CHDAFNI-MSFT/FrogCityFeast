#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-$repo_root/.tools/bin/godot}"
logs_dir="$repo_root/build/logs"

if [[ ! -x "$godot_bin" ]]; then
  if command -v godot >/dev/null 2>&1; then
    godot_bin="$(command -v godot)"
  else
    echo "Godot is not available. Run scripts/setup-unix.sh first." >&2
    exit 1
  fi
fi

mkdir -p "$logs_dir"

run_checked() {
  local label="$1"
  shift
  local log_path="$logs_dir/godot-$label.log"

  "$godot_bin" "$@" 2>&1 | tee "$log_path"
  if grep -E "SCRIPT ERROR:|Parse Error:|Failed to load script" "$log_path"; then
    echo "Godot reported project errors during $label." >&2
    exit 1
  fi
}

run_checked import --headless --path "$repo_root" --import
run_checked ios-pipeline-smoke --headless --path "$repo_root" \
  --script res://tests/ios_pipeline_smoke.gd
run_checked ios-release-pipeline-smoke --headless --path "$repo_root" \
  --script res://tests/ios_release_pipeline_smoke.gd
run_checked startup --headless --path "$repo_root" --quit-after 2
run_checked navigation-smoke --headless --path "$repo_root" \
  --script res://tests/navigation_smoke.gd
run_checked district-smoke --headless --path "$repo_root" \
  --script res://tests/district_smoke.gd
run_checked secret-district-smoke --headless --path "$repo_root" \
  --script res://tests/secret_district_smoke.gd
run_checked audio-smoke --headless --path "$repo_root" \
  --script res://tests/audio_smoke.gd
run_checked production-art-smoke --headless --path "$repo_root" \
  --script res://tests/production_art_smoke.gd
run_checked progression-smoke --headless --path "$repo_root" \
  --script res://tests/progression_smoke.gd
run_checked power-smoke --headless --path "$repo_root" \
  --script res://tests/power_smoke.gd
run_checked enormous-growth-smoke --headless --path "$repo_root" \
  --script res://tests/enormous_growth_smoke.gd
run_checked achievement-smoke --headless --path "$repo_root" \
  --script res://tests/achievement_smoke.gd
run_checked prototype-smoke --headless --path "$repo_root" \
  --script res://tests/prototype_smoke.gd
run_checked ux-smoke --headless --path "$repo_root" \
  --script res://tests/ux_smoke.gd
run_checked performance-smoke --headless --path "$repo_root" \
  --script res://tests/performance_smoke.gd
run_checked tutorial-smoke --headless --path "$repo_root" \
  --script res://tests/tutorial_smoke.gd

echo "Godot project checks passed."
