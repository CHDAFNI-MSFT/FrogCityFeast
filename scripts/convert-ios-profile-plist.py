#!/usr/bin/env python3

import argparse
import base64
import datetime
import json
import plistlib
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert an Apple provisioning profile plist to JSON.",
    )
    parser.add_argument("profile_plist", type=Path)
    return parser.parse_args()


def make_json_compatible(value: object) -> object:
    if isinstance(value, dict):
        if not all(isinstance(key, str) for key in value):
            raise ValueError("The profile plist contains a non-string key.")
        return {
            key: make_json_compatible(item)
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [make_json_compatible(item) for item in value]
    if isinstance(value, bytes):
        return base64.b64encode(value).decode("ascii")
    if isinstance(value, datetime.datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=datetime.timezone.utc)
        return value.astimezone(datetime.timezone.utc).isoformat().replace(
            "+00:00",
            "Z",
        )
    if value is None or isinstance(value, (bool, int, float, str)):
        return value
    raise ValueError(
        f"The profile plist contains an unsupported {type(value).__name__} value.",
    )


def main() -> None:
    args = parse_args()
    with args.profile_plist.open("rb") as source:
        profile = plistlib.load(source)
    json.dump(
        make_json_compatible(profile),
        fp=sys.stdout,
        ensure_ascii=True,
        separators=(",", ":"),
    )


if __name__ == "__main__":
    main()
