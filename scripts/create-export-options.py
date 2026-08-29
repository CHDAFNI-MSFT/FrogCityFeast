#!/usr/bin/env python3

import argparse
import plistlib
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create Xcode TestFlight export options."
    )
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--profile-name", required=True)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    options = {
        "destination": "upload",
        "manageAppVersionAndBuildNumber": False,
        "method": "app-store-connect",
        "provisioningProfiles": {
            args.bundle_id: args.profile_name,
        },
        "signingCertificate": "Apple Distribution",
        "signingStyle": "manual",
        "stripSwiftSymbols": True,
        "teamID": args.team_id,
        "uploadSymbols": True,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as output:
        plistlib.dump(options, output, fmt=plistlib.FMT_XML, sort_keys=True)
    print(f"Created {args.output}")


if __name__ == "__main__":
    main()
