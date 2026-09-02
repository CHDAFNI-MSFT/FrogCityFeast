#!/usr/bin/env python3

import argparse
import plistlib
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create Xcode App Store Connect export options."
    )
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--profile-name", required=True)
    parser.add_argument(
        "--distribution",
        required=True,
        choices=("internal-testflight", "app-store", "ad-hoc"),
    )
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    options = {
        "manageAppVersionAndBuildNumber": False,
        "provisioningProfiles": {
            args.bundle_id: args.profile_name,
        },
        "signingCertificate": "Apple Distribution",
        "signingStyle": "manual",
        "stripSwiftSymbols": True,
        "teamID": args.team_id,
    }
    if args.distribution == "ad-hoc":
        options["destination"] = "export"
        options["method"] = "release-testing"
    else:
        options["destination"] = "upload"
        options["method"] = "app-store-connect"
        options["uploadSymbols"] = True
        if args.distribution == "internal-testflight":
            options["testFlightInternalTestingOnly"] = True

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as output:
        plistlib.dump(options, output, fmt=plistlib.FMT_XML, sort_keys=True)
    print(f"Created {args.output}")


if __name__ == "__main__":
    main()
