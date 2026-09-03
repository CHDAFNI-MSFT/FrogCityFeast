#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "scripts"
    / "create-ios-ota-manifest.py"
)
SPEC = importlib.util.spec_from_file_location(
    "create_ios_ota_manifest",
    MODULE_PATH,
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Could not load the iOS OTA manifest helper.")
MANIFEST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MANIFEST)

PACKAGE_URL = (
    "https://synthetic.blob.core.windows.net/ios-delivery/"
    "frogcityfeast/0.1.0/123.1/FrogCityFeast.ipa"
    "?sv=2023-11-03&spr=https&si=device-install&sig=synthetic"
)


class IosOtaManifestTest(unittest.TestCase):
    def test_builds_apple_software_manifest(self) -> None:
        manifest = MANIFEST.build_manifest(
            PACKAGE_URL,
            "com.example.synthetic",
            "123.1",
            "Synthetic App",
        )
        item = manifest["items"][0]
        self.assertEqual(
            item["assets"],
            [{"kind": "software-package", "url": PACKAGE_URL}],
        )
        self.assertEqual(
            item["metadata"],
            {
                "bundle-identifier": "com.example.synthetic",
                "bundle-version": "123.1",
                "kind": "software",
                "title": "Synthetic App",
            },
        )

    def test_rejects_non_https_package_url(self) -> None:
        with self.assertRaisesRegex(ValueError, "must use HTTPS"):
            MANIFEST.validate_package_url(
                PACKAGE_URL.replace("https://", "http://"),
            )

    def test_rejects_wrong_access_policy(self) -> None:
        with self.assertRaisesRegex(ValueError, "device-install"):
            MANIFEST.validate_package_url(
                PACKAGE_URL.replace("si=device-install", "si=other"),
            )

    def test_rejects_missing_signature(self) -> None:
        with self.assertRaisesRegex(ValueError, "SAS signature"):
            MANIFEST.validate_package_url(
                PACKAGE_URL.replace("&sig=synthetic", ""),
            )


if __name__ == "__main__":
    unittest.main()
