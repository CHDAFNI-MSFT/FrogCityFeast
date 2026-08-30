#!/usr/bin/env python3

import argparse
import datetime
import hashlib
import plistlib
import re
import subprocess
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate an Apple distribution certificate and profile."
    )
    parser.add_argument("--profile-plist", required=True, type=Path)
    parser.add_argument("--certificate-pem", required=True, type=Path)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--bundle-id", required=True)
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
        "The provisioning profile is not an App Store distribution profile.",
    )
    require(
        "ProvisionedDevices" not in profile
        and profile.get("ProvisionsAllDevices") is not True,
        "The provisioning profile is for device or enterprise distribution.",
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

    print("Apple signing certificate and provisioning profile are consistent.")


if __name__ == "__main__":
    main()
