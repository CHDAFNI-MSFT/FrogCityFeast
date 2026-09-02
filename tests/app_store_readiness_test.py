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
METADATA_SYNC_SCRIPT = REPO_ROOT / "scripts" / "sync-app-store-metadata.mjs"
METADATA_WORKFLOW = (
    REPO_ROOT / ".github" / "workflows" / "app-store-metadata.yml"
)
SUPPORT_PATH = REPO_ROOT / "docs" / "app-support.md"
PRIVACY_PATH = REPO_ROOT / "docs" / "privacy-policy.md"
PAGES_CONFIG_PATH = REPO_ROOT / "docs" / "_config.yml"
SUPPORT_ISSUE_PATH = (
    REPO_ROOT / ".github" / "ISSUE_TEMPLATE" / "game-support.yml"
)
PRIVACY_ISSUE_PATH = (
    REPO_ROOT / ".github" / "ISSUE_TEMPLATE" / "privacy-question.yml"
)
SUPPORT_URL = "https://chdafni-msft.github.io/SamuelIcecream/support/"
PRIVACY_URL = "https://chdafni-msft.github.io/SamuelIcecream/privacy/"


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
    require(metadata.get("version") == "0.1.0", "Metadata version changed.")
    require(
        metadata.get("support_url") == SUPPORT_URL,
        "The reviewed support URL changed.",
    )
    require(
        metadata.get("privacy_policy_url") == PRIVACY_URL,
        "The reviewed privacy URL changed.",
    )
    require(
        metadata.get("copyright") == "2026 Chase Dafnis",
        "The reviewed copyright changed.",
    )
    require(metadata.get("pricing") == "free", "Pricing must remain free.")
    require(
        metadata.get("storefronts") == "all_except_china_mainland",
        "The reviewed storefront selection changed.",
    )
    require(
        metadata.get("eu_dsa_status") == "non-trader",
        "The reviewed EU DSA status changed.",
    )
    require(
        metadata.get("schema_version") == 2
        and metadata.get("platform") == "IOS"
        and metadata.get("release_type") == "MANUAL",
        "The metadata sync identity or manual release policy changed.",
    )
    require(
        metadata.get("primary_category_id") == "GAMES"
        and metadata.get("primary_subcategory_one_id") == "GAMES_CASUAL"
        and metadata.get("primary_subcategory_two_id")
        == "GAMES_ADVENTURE",
        "The App Store category identifiers changed.",
    )
    require(
        metadata.get("content_rights_declaration")
        == "DOES_NOT_USE_THIRD_PARTY_CONTENT"
        and metadata.get("app_privacy") == "NO_DATA_COLLECTED",
        "Content-rights or privacy declarations changed.",
    )
    age_rating = metadata.get("age_rating", {})
    require(
        age_rating.get("violenceCartoonOrFantasy") == "FREQUENT"
        and all(
            age_rating.get(field) == "NONE"
            for field in (
                "alcoholTobaccoOrDrugUseOrReferences",
                "contests",
                "gamblingSimulated",
                "gunsOrOtherWeapons",
                "medicalOrTreatmentInformation",
                "profanityOrCrudeHumor",
                "sexualContentGraphicAndNudity",
                "sexualContentOrNudity",
                "horrorOrFearThemes",
                "matureOrSuggestiveThemes",
                "violenceRealisticProlongedGraphicOrSadistic",
                "violenceRealistic",
            )
        ),
        "The reviewed age-rating frequency answers changed.",
    )


def validate_public_support() -> None:
    for path in (
        SUPPORT_PATH,
        PRIVACY_PATH,
        PAGES_CONFIG_PATH,
        SUPPORT_ISSUE_PATH,
        PRIVACY_ISSUE_PATH,
    ):
        require(path.is_file(), f"Required public support file is missing: {path}")
    support = SUPPORT_PATH.read_text(encoding="utf-8")
    privacy = PRIVACY_PATH.read_text(encoding="utf-8")
    require(
        "REQUIRED_BEFORE_SUBMISSION" not in support + privacy,
        "Published support and privacy pages retain a placeholder.",
    )
    require(SUPPORT_URL in support, "Support page omits its canonical URL.")
    require(PRIVACY_URL in support, "Support page omits the privacy URL.")
    require(
        "issues/new?template=game-support.yml" in support,
        "Support page omits the public support form.",
    )
    require(
        "issues/new?template=privacy-question.yml" in privacy,
        "Privacy page omits the public privacy form.",
    )
    for path in (SUPPORT_ISSUE_PATH, PRIVACY_ISSUE_PATH):
        content = path.read_text(encoding="utf-8")
        require(
            "will be public" in content
            and "sensitive information" in content,
            f"Public issue form lacks its privacy warning: {path}",
        )


def validate_metadata_sync() -> None:
    require(
        METADATA_SYNC_SCRIPT.is_file(),
        "The App Store metadata sync script is missing.",
    )
    require(
        METADATA_WORKFLOW.is_file(),
        "The protected App Store metadata workflow is missing.",
    )
    result = subprocess.run(
        ["node", str(METADATA_SYNC_SCRIPT), "--print-values"],
        check=True,
        capture_output=True,
        text=True,
    )
    values = json.loads(result.stdout)
    require(
        values.get("version") == "0.1.0"
        and values.get("releaseType") == "MANUAL"
        and values.get("appPrivacy") == "NO_DATA_COLLECTED",
        "The metadata sync does not report the reviewed release values.",
    )
    workflow = METADATA_WORKFLOW.read_text(encoding="utf-8")
    sync_script = METADATA_SYNC_SCRIPT.read_text(encoding="utf-8")
    require(
        "workflow_dispatch:" in workflow
        and "confirm_sync:" in workflow
        and workflow.count("inputs.version == '0.1.0'") == 2
        and "name: app-store" in workflow
        and "name: testflight" in workflow,
        "The metadata workflow is not manual, pinned, and double-gated.",
    )
    require(
        "archive-and-upload-ios" not in workflow
        and "actions/upload-artifact" not in workflow,
        "The metadata workflow can upload or publish an artifact.",
    )
    require(
        all(
            forbidden not in sync_script
            for forbidden in (
                "reviewSubmissions",
                "appStoreVersionReleaseRequests",
                "relationships/build",
                "appStoreVersionSubmissions",
            )
        ),
        "The metadata script can select a build, submit, or release.",
    )
    require(
        sync_script.index("const existingVersion = await findVersion")
        < sync_script.index("await updateAppAndCategories")
        and '"partial_failure"' in sync_script
        and "appliedResources" in sync_script,
        "The metadata script writes before version preflight or hides partial writes.",
    )


def main() -> None:
    validate_export_options()
    validate_metadata()
    validate_public_support()
    validate_metadata_sync()
    print("App Store readiness checks passed.")


if __name__ == "__main__":
    main()
