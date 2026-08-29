#!/usr/bin/env python3

import argparse
import re
from pathlib import Path


TEAM_ID_PATTERN = re.compile(r"^[A-Za-z0-9]{10}$")
BUNDLE_ID_PATTERN = re.compile(
    r"^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$"
)
VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){0,2}$")
BUILD_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){0,2}$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render the generated Godot iOS export preset."
    )
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--short-version", required=True)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def require_match(value: str, pattern: re.Pattern[str], label: str) -> None:
    if not pattern.fullmatch(value):
        raise SystemExit(f"Invalid {label}: {value!r}")


def main() -> None:
    args = parse_args()
    require_match(args.team_id, TEAM_ID_PATTERN, "Apple Team ID")
    require_match(args.bundle_id, BUNDLE_ID_PATTERN, "iOS bundle identifier")
    require_match(args.short_version, VERSION_PATTERN, "short version")
    require_match(args.build_number, BUILD_PATTERN, "build number")

    repo_root = Path(__file__).resolve().parent.parent
    template_path = repo_root / "tools" / "export-presets.ios.cfg.template"
    output_path = args.output or repo_root / "export_presets.cfg"
    replacements = {
        "@APPLE_TEAM_ID@": args.team_id,
        "@IOS_BUNDLE_ID@": args.bundle_id,
        "@IOS_SHORT_VERSION@": args.short_version,
        "@IOS_BUILD_NUMBER@": args.build_number,
    }

    rendered = template_path.read_text(encoding="utf-8")
    for token, value in replacements.items():
        rendered = rendered.replace(token, value)

    if re.search(r"@[A-Z0-9_]+@", rendered):
        raise SystemExit("The export preset template contains unresolved values.")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8", newline="\n")
    print(f"Rendered {output_path}")


if __name__ == "__main__":
    main()
