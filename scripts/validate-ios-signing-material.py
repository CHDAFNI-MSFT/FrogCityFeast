#!/usr/bin/env python3

import argparse
import datetime
import hashlib
import os
import plistlib
import re
import subprocess
from pathlib import Path

UDID_PATTERN = re.compile(
    r"^(?:[A-Fa-f0-9]{40}|[A-Fa-f0-9]{8}-[A-Fa-f0-9]{16})$"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate an Apple distribution certificate and profile."
    )
    parser.add_argument("--profile-plist", required=True, type=Path)
    parser.add_argument("--certificate-pem", required=True, type=Path)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument(
        "--distribution",
        required=True,
        choices=("app-store", "ad-hoc"),
    )
    parser.add_argument(
        "--device-udid-env",
        action="append",
        default=[],
        help="Environment variable containing an approved Ad Hoc device UDID.",
    )
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def run_openssl(*arguments: str) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["openssl", *arguments],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )


def validate_exact_ad_hoc_devices(
    approved_device_udids: list[str],
    provisioned_devices: object,
) -> set[str]:
    require(
        all(
            isinstance(device_udid, str)
            and UDID_PATTERN.fullmatch(device_udid) is not None
            for device_udid in approved_device_udids
        ),
        "An approved Ad Hoc device UDID has an unsupported format.",
    )
    expected_device_udids = {
        device_udid.upper() for device_udid in approved_device_udids
    }
    require(
        len(expected_device_udids) == len(approved_device_udids),
        "The approved Ad Hoc device UDIDs must be unique.",
    )
    require(
        isinstance(provisioned_devices, list)
        and all(
            isinstance(device_udid, str)
            and UDID_PATTERN.fullmatch(device_udid) is not None
            for device_udid in provisioned_devices
        ),
        "The Ad Hoc profile contains a malformed device UDID list.",
    )
    profile_device_udids = {
        device_udid.upper() for device_udid in provisioned_devices
    }
    require(
        len(profile_device_udids) == len(provisioned_devices),
        "The Ad Hoc profile contains duplicate device UDIDs.",
    )
    require(
        profile_device_udids == expected_device_udids,
        "The Ad Hoc profile device set does not exactly match the approved devices.",
    )
    return profile_device_udids


def main() -> None:
    args = parse_args()
    with args.profile_plist.open("rb") as source:
        profile = plistlib.load(source)

    team_ids = profile.get("TeamIdentifier")
    entitlements = profile.get("Entitlements")
    require(
        isinstance(team_ids, list) and team_ids == [args.team_id],
        "The provisioning profile Team ID does not match APPLE_TEAM_ID.",
    )
    require(
        isinstance(entitlements, dict)
        and entitlements.get("application-identifier")
        == f"{args.team_id}.{args.bundle_id}",
        "The provisioning profile does not match IOS_BUNDLE_ID.",
    )
    require(
        entitlements.get("get-task-allow") is False,
        "The provisioning profile permits development debugging.",
    )
    if args.distribution == "app-store":
        require(
            not args.device_udid_env,
            "Ad Hoc device UDIDs are not valid for App Store profiles.",
        )
        require(
            "ProvisionedDevices" not in profile
            and profile.get("ProvisionsAllDevices") is not True,
            "The provisioning profile is not for App Store distribution.",
        )
    else:
        require(
            len(args.device_udid_env) == 3,
            "Exactly three approved Ad Hoc device UDIDs are required.",
        )
        approved_device_udids: list[str] = []
        for environment_name in args.device_udid_env:
            require(
                re.fullmatch(r"IOS_AD_HOC_DEVICE_UDID_[1-9][0-9]*", environment_name)
                is not None,
                "An Ad Hoc device environment variable name is invalid.",
            )
            device_udid = os.environ.get(environment_name)
            require(
                isinstance(device_udid, str) and bool(device_udid),
                "An approved Ad Hoc device UDID is missing.",
            )
            approved_device_udids.append(device_udid)
        provisioned_devices = profile.get("ProvisionedDevices")
        validate_exact_ad_hoc_devices(
            approved_device_udids,
            provisioned_devices,
        )
        require(
            profile.get("ProvisionsAllDevices") is not True,
            "Enterprise provisioning is not permitted for Ad Hoc testing.",
        )
    require(
        "iOS" in profile.get("Platform", []),
        "The provisioning profile does not support iOS.",
    )

    expiration = profile.get("ExpirationDate")
    require(
        isinstance(expiration, datetime.datetime),
        "The provisioning profile expiration date is missing.",
    )
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=datetime.timezone.utc)
    require(
        expiration > datetime.datetime.now(datetime.timezone.utc),
        "The provisioning profile is expired.",
    )

    certificate_check = run_openssl(
        "x509",
        "-checkend",
        "0",
        "-noout",
        "-in",
        str(args.certificate_pem),
    )
    require(
        certificate_check.returncode == 0,
        "The Apple Distribution certificate is expired.",
    )

    subject_result = run_openssl(
        "x509",
        "-noout",
        "-subject",
        "-nameopt",
        "RFC2253",
        "-in",
        str(args.certificate_pem),
    )
    require(
        subject_result.returncode == 0,
        "The distribution certificate subject could not be read.",
    )
    subject = subject_result.stdout.decode("utf-8", errors="strict").strip()
    subject = subject.removeprefix("subject=")
    require(
        re.search(
            rf"(?:^|,)OU={re.escape(args.team_id)}(?:,|$)",
            subject,
        )
        is not None,
        "The distribution certificate Team ID does not match APPLE_TEAM_ID.",
    )
    require(
        re.search(r"(?:^|,)CN=Apple Distribution:", subject) is not None,
        "The certificate is not a modern Apple Distribution certificate.",
    )

    certificate_result = run_openssl(
        "x509",
        "-outform",
        "DER",
        "-in",
        str(args.certificate_pem),
    )
    require(
        certificate_result.returncode == 0,
        "The distribution certificate could not be decoded.",
    )
    certificate_fingerprint = hashlib.sha256(certificate_result.stdout).digest()
    profile_certificates = profile.get("DeveloperCertificates")
    require(
        isinstance(profile_certificates, list)
        and len(profile_certificates) > 0,
        "The provisioning profile has no distribution certificates.",
    )
    profile_fingerprints = {
        hashlib.sha256(bytes(certificate)).digest()
        for certificate in profile_certificates
    }
    require(
        certificate_fingerprint in profile_fingerprints,
        "The provisioning profile does not include the supplied certificate.",
    )

    print(
        "Apple signing certificate and "
        f"{args.distribution} provisioning profile are consistent."
    )


if __name__ == "__main__":
    main()
