#!/usr/bin/env python3

import json
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
EXPORT_OPTIONS_SCRIPT = REPO_ROOT / "scripts" / "create-export-options.py"
METADATA_PATH = REPO_ROOT / "tools" / "app-store-metadata.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def create_options(distribution: str, output: Path) -> dict:
    subprocess.run(
        [
            sys.executable,
            str(EXPORT_OPTIONS_SCRIPT),
            "--team-id",
            "CV7JQ487YU",
            "--bundle-id",
            "com.chdafni.frogcityfeast",
            "--profile-name",
            "Frog City Feast App Store",
            "--distribution",
            distribution,
            "--output",
            str(output),
        ],
        check=True,
    )
    with output.open("rb") as source:
        return plistlib.load(source)


def validate_export_options() -> None:
    with tempfile.TemporaryDirectory() as temporary_directory:
        temporary_root = Path(temporary_directory)
        internal = create_options(
            "internal-testflight",
            temporary_root / "internal.plist",
        )
        app_store = create_options(
            "app-store",
            temporary_root / "app-store.plist",
        )

    require(
        internal.get("testFlightInternalTestingOnly") is True,
        "The internal TestFlight export must remain internal-only.",
    )
    require(
        "testFlightInternalTestingOnly" not in app_store,
        "The normal App Store export must omit the TestFlight-only key.",
    )
    for options in (internal, app_store):
        require(
            options.get("method") == "app-store-connect",
            "Both signed distributions must use App Store Connect export.",
        )
        require(
            options.get("signingStyle") == "manual",
            "Both signed distributions must retain manual signing.",
        )
        require(
            options.get("destination") == "upload",
            "Both signed distributions must explicitly upload.",
        )


def validate_metadata() -> None:
    with METADATA_PATH.open(encoding="utf-8") as source:
        metadata = json.load(source)

    limits = {
        "name": 30,
        "subtitle": 30,
        "promotional_text": 170,
        "description": 4000,
        "whats_new": 4000,
    }
    for field, limit in limits.items():
        value = metadata.get(field)
        require(isinstance(value, str), f"Metadata field {field} is missing.")
        require(
            len(value) <= limit,
            f"Metadata field {field} exceeds {limit} characters.",
        )

    keywords = metadata.get("keywords")
    require(isinstance(keywords, str), "Metadata keywords are missing.")
    require(
        len(keywords.encode("utf-8")) <= 100,
        "Metadata keywords exceed Apple's 100-byte limit.",
    )
    require(
        metadata.get("primary_category") == "Games"
        and metadata.get("primary_subcategory") == "Casual"
        and metadata.get("secondary_subcategory") == "Adventure",
        "The reviewed Games, Casual, and Adventure categories changed.",
    )

    combined_copy = " ".join(
        str(metadata.get(field, "")).lower()
        for field in ("subtitle", "promotional_text", "description")
    )
    for inaccurate_claim in ("ice cream delivery", "pixel art", "retro"):
        require(
            inaccurate_claim not in combined_copy,
            f"Metadata contains the inaccurate claim {inaccurate_claim!r}.",
        )
    for required_claim in (
        "no ads",
        "no in-app purchases",
        "no account",
        "no data collection",
    ):
        require(
            required_claim in combined_copy,
            f"Metadata omits the reviewed claim {required_claim!r}.",
        )

    for field in ("support_url", "privacy_policy_url"):
        value = metadata.get(field)
        require(isinstance(value, str), f"Metadata field {field} is missing.")
        require(
            value.startswith("https://")
            or value == "REQUIRED_BEFORE_SUBMISSION",
            f"Metadata field {field} must be HTTPS or explicitly pending.",
        )


def main() -> None:
    validate_export_options()
    validate_metadata()
    print("App Store readiness checks passed.")


if __name__ == "__main__":
    main()
