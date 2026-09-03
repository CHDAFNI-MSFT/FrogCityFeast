#!/usr/bin/env python3

import base64
import datetime
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT_PATH = (
    Path(__file__).resolve().parents[1]
    / "scripts"
    / "convert-ios-profile-plist.py"
)


class IosProfilePlistJsonTest(unittest.TestCase):
    def test_converts_profile_dates_and_certificate_data(self) -> None:
        certificate = b"synthetic-certificate"
        expiration = datetime.datetime(
            2030,
            1,
            2,
            3,
            4,
            5,
            tzinfo=datetime.timezone.utc,
        )
        profile = {
            "DeveloperCertificates": [certificate],
            "ExpirationDate": expiration,
            "Entitlements": {"get-task-allow": False},
            "ProvisionedDevices": ["A1B2C3D4-00112233AABBCCDD"],
        }

        with tempfile.TemporaryDirectory() as temporary_directory:
            profile_path = Path(temporary_directory) / "profile.plist"
            with profile_path.open("wb") as destination:
                plistlib.dump(profile, destination)
            result = subprocess.run(
                [sys.executable, str(SCRIPT_PATH), str(profile_path)],
                check=True,
                capture_output=True,
                text=True,
            )

        converted = json.loads(result.stdout)
        self.assertEqual(
            converted["DeveloperCertificates"],
            [base64.b64encode(certificate).decode("ascii")],
        )
        self.assertEqual(
            converted["ExpirationDate"],
            "2030-01-02T03:04:05Z",
        )
        self.assertIs(
            converted["Entitlements"]["get-task-allow"],
            False,
        )


if __name__ == "__main__":
    unittest.main()
