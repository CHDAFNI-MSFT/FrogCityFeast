#!/usr/bin/env python3

import argparse
import json
import plistlib
import re
from pathlib import Path


UNUSED_PRIVACY_KEYS = {
    "NSCameraUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSPhotoLibraryUsageDescription",
}
EXPECTED_PRIVACY_REASONS = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1"},
    "NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1"},
    "NSPrivacyAccessedAPICategoryDiskSpace": {"E174.1"},
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate and sanitize a generated Godot iOS project."
    )
    parser.add_argument("--build-root", required=True, type=Path)
    parser.add_argument("--app-dir", required=True, type=Path)
    parser.add_argument("--xcode-project", required=True, type=Path)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--short-version", required=True)
    parser.add_argument("--build-number", required=True)
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def validate_build_setting(
    project_text: str,
    name: str,
    expected_value: str,
) -> None:
    pattern = re.compile(
        rf"^\s*{re.escape(name)}\s*=\s*{re.escape(expected_value)};\s*$",
        re.MULTILINE,
    )
    require(
        len(pattern.findall(project_text)) >= 2,
        f"The generated Xcode project does not consistently set {name}.",
    )


def sanitize_localized_strings(
    strings_paths: list[Path],
) -> dict[Path, str]:
    privacy_pattern = re.compile(
        r'^\s*(NSCameraUsageDescription|NSMicrophoneUsageDescription|'
        r'NSPhotoLibraryUsageDescription)\s*=\s*"([^"]*)";\s*$'
    )
    sanitized: dict[Path, str] = {}

    for path in strings_paths:
        output_lines: list[str] = []
        for line in path.read_text(encoding="utf-8").splitlines():
            if not any(key in line for key in UNUSED_PRIVACY_KEYS):
                output_lines.append(line)
                continue
            match = privacy_pattern.fullmatch(line)
            require(
                match is not None and match.group(2) == "",
                f"{path} contains an unexpected privacy-purpose declaration.",
            )
        sanitized[path] = "\n".join(output_lines) + "\n"

    return sanitized


def validate_privacy_manifest(path: Path) -> None:
    require(path.is_file(), "The generated PrivacyInfo.xcprivacy is missing.")
    with path.open("rb") as source:
        manifest = plistlib.load(source)

    require(
        manifest.get("NSPrivacyTracking") is False,
        "The generated privacy manifest must declare tracking as disabled.",
    )
    require(
        not manifest.get("NSPrivacyTrackingDomains"),
        "The generated privacy manifest unexpectedly declares tracking domains.",
    )
    require(
        not manifest.get("NSPrivacyCollectedDataTypes"),
        "The generated privacy manifest unexpectedly declares collected data.",
    )

    actual_reasons: dict[str, set[str]] = {}
    for entry in manifest.get("NSPrivacyAccessedAPITypes", []):
        api_type = entry.get("NSPrivacyAccessedAPIType")
        reasons = entry.get("NSPrivacyAccessedAPITypeReasons")
        require(
            isinstance(api_type, str) and isinstance(reasons, list),
            "The generated privacy manifest contains a malformed API entry.",
        )
        actual_reasons[api_type] = set(reasons)

    require(
        actual_reasons == EXPECTED_PRIVACY_REASONS,
        "The generated privacy manifest does not match the reviewed Godot "
        "required-reason API declarations.",
    )


def validate_app_icon(app_dir: Path) -> None:
    iconset_dir = app_dir / "Images.xcassets" / "AppIcon.appiconset"
    contents_path = iconset_dir / "Contents.json"
    require(contents_path.is_file(), "The generated AppIcon catalog is missing.")
    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    images = contents.get("images", [])
    require(isinstance(images, list), "The AppIcon catalog is malformed.")

    has_store_icon = False
    for image in images:
        filename = image.get("filename")
        if filename:
            require(
                (iconset_dir / filename).is_file(),
                f"The generated AppIcon file is missing: {filename}",
            )
        if image.get("size") == "1024x1024" and filename:
            has_store_icon = True

    require(
        has_store_icon,
        "The generated AppIcon catalog has no 1024x1024 App Store icon.",
    )


def main() -> None:
    args = parse_args()
    build_root = args.build_root.resolve()
    app_dir = args.app_dir.resolve()
    xcode_project = args.xcode_project.resolve()

    plist_paths = sorted(app_dir.glob("*-Info.plist"))
    require(
        len(plist_paths) == 1,
        f"Expected one generated application Info.plist, found {len(plist_paths)}.",
    )
    plist_path = plist_paths[0]
    with plist_path.open("rb") as source:
        info = plistlib.load(source)

    for key in UNUSED_PRIVACY_KEYS:
        if key in info:
            require(
                info[key] == "",
                f"{key} is set even though the game does not use that capability.",
            )
            del info[key]

    require(
        info.get("ITSAppUsesNonExemptEncryption") is False,
        "The generated app must declare that it uses no non-exempt encryption.",
    )

    localized_strings = sanitize_localized_strings(
        sorted(app_dir.glob("*.lproj/InfoPlist.strings"))
    )
    validate_privacy_manifest(build_root / "PrivacyInfo.xcprivacy")
    validate_app_icon(app_dir)

    project_file = xcode_project / "project.pbxproj"
    require(project_file.is_file(), "The generated Xcode project file is missing.")
    project_text = project_file.read_text(encoding="utf-8")
    validate_build_setting(
        project_text,
        "DEVELOPMENT_TEAM",
        args.team_id,
    )
    validate_build_setting(
        project_text,
        "PRODUCT_BUNDLE_IDENTIFIER",
        args.bundle_id,
    )
    validate_build_setting(
        project_text,
        "INFOPLIST_KEY_CFBundleDisplayName",
        f'"{args.display_name}"',
    )
    validate_build_setting(
        project_text,
        "MARKETING_VERSION",
        args.short_version,
    )
    validate_build_setting(
        project_text,
        "CURRENT_PROJECT_VERSION",
        args.build_number,
    )
    require(
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" in project_text,
        "The generated Xcode project does not select the AppIcon catalog.",
    )
    require(
        project_text.count('TARGETED_DEVICE_FAMILY = "2";') >= 2,
        "The generated Xcode project is not restricted to iPad.",
    )
    require(
        "PrivacyInfo.xcprivacy in Resources" in project_text,
        "The generated Xcode project does not embed its privacy manifest.",
    )

    temporary_plist = plist_path.with_suffix(".plist.tmp")
    with temporary_plist.open("wb") as output:
        plistlib.dump(info, output, fmt=plistlib.FMT_XML, sort_keys=False)
    temporary_plist.replace(plist_path)
    for path, content in localized_strings.items():
        path.write_text(content, encoding="utf-8", newline="\n")

    print("Validated and sanitized generated iOS project metadata.")


if __name__ == "__main__":
    main()
