#!/usr/bin/env python3

import argparse
import os
import plistlib
import re
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

BUNDLE_ID_PATTERN = re.compile(r"^[A-Za-z0-9]+(?:[.-][A-Za-z0-9]+)+$")
VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+)+$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create an Apple Ad Hoc OTA installation manifest.",
    )
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--bundle-version", required=True)
    parser.add_argument("--title", required=True)
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_package_url(package_url: str) -> str:
    require(bool(package_url), "IOS_OTA_IPA_URL is required.")
    parsed = urlsplit(package_url)
    require(
        parsed.scheme == "https",
        "The OTA package URL must use HTTPS.",
    )
    require(
        parsed.hostname is not None
        and parsed.hostname.endswith(".blob.core.windows.net"),
        "The OTA package URL must use Azure Blob Storage.",
    )
    require(
        parsed.username is None
        and parsed.password is None
        and parsed.port is None
        and not parsed.fragment,
        "The OTA package URL contains unsupported authority components.",
    )
    require(
        parsed.path.endswith(".ipa"),
        "The OTA package URL must identify an IPA.",
    )
    query = parse_qs(parsed.query, keep_blank_values=True)
    require(
        query.get("si") == ["device-install"],
        "The OTA package URL must use the device-install access policy.",
    )
    require(
        len(query.get("sig", [])) == 1 and bool(query["sig"][0]),
        "The OTA package URL must contain one SAS signature.",
    )
    require(
        query.get("spr") == ["https"],
        "The OTA package SAS must be HTTPS-only.",
    )
    return package_url


def build_manifest(
    package_url: str,
    bundle_id: str,
    bundle_version: str,
    title: str,
) -> dict[str, object]:
    validate_package_url(package_url)
    require(
        BUNDLE_ID_PATTERN.fullmatch(bundle_id) is not None,
        "The OTA bundle identifier is invalid.",
    )
    require(
        VERSION_PATTERN.fullmatch(bundle_version) is not None,
        "The OTA bundle version is invalid.",
    )
    require(
        bool(title) and len(title) <= 80,
        "The OTA title is invalid.",
    )
    return {
        "items": [
            {
                "assets": [
                    {
                        "kind": "software-package",
                        "url": package_url,
                    },
                ],
                "metadata": {
                    "bundle-identifier": bundle_id,
                    "bundle-version": bundle_version,
                    "kind": "software",
                    "title": title,
                },
            },
        ],
    }


def main() -> None:
    args = parse_args()
    package_url = os.environ.get("IOS_OTA_IPA_URL", "")
    manifest = build_manifest(
        package_url,
        args.bundle_id,
        args.bundle_version,
        args.title,
    )
    with args.output.open("xb") as destination:
        plistlib.dump(
            manifest,
            destination,
            fmt=plistlib.FMT_XML,
            sort_keys=False,
        )
    args.output.chmod(0o600)


if __name__ == "__main__":
    main()
