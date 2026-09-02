#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "scripts"
    / "validate-ios-signing-material.py"
)
SPEC = importlib.util.spec_from_file_location(
    "validate_ios_signing_material",
    MODULE_PATH,
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Could not load the iOS signing validator.")
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

MODERN_1 = "A1B2C3D4-00112233AABBCCDD"
MODERN_2 = "B2C3D4E5-11223344BBCCDDEE"
LEGACY = "AABBCCDDEEFF00112233445566778899AABBCCDD"


class AdHocDeviceSetTest(unittest.TestCase):
    def assert_rejected(
        self,
        approved_devices: list[str],
        profile_devices: object,
        expected_message: str,
    ) -> None:
        with self.assertRaisesRegex(SystemExit, expected_message):
            VALIDATOR.validate_exact_ad_hoc_devices(
                approved_devices,
                profile_devices,
            )

    def test_accepts_exact_case_insensitive_set(self) -> None:
        actual = VALIDATOR.validate_exact_ad_hoc_devices(
            [MODERN_1.lower(), MODERN_2, LEGACY],
            [LEGACY.upper(), MODERN_1, MODERN_2.lower()],
        )
        self.assertEqual(
            actual,
            {MODERN_1.upper(), MODERN_2.upper(), LEGACY.upper()},
        )

    def test_rejects_duplicate_approved_device(self) -> None:
        self.assert_rejected(
            [MODERN_1, MODERN_2, MODERN_1.lower()],
            [MODERN_1, MODERN_2, LEGACY],
            "approved Ad Hoc device UDIDs must be unique",
        )

    def test_rejects_duplicate_profile_device(self) -> None:
        self.assert_rejected(
            [MODERN_1, MODERN_2, LEGACY],
            [MODERN_1, MODERN_2, LEGACY, MODERN_1.lower()],
            "profile contains duplicate device UDIDs",
        )

    def test_rejects_missing_profile_device(self) -> None:
        self.assert_rejected(
            [MODERN_1, MODERN_2, LEGACY],
            [MODERN_1, MODERN_2],
            "does not exactly match the approved devices",
        )

    def test_rejects_extra_profile_device(self) -> None:
        extra_device = "C3D4E5F6-22334455CCDDEEFF"
        self.assert_rejected(
            [MODERN_1, MODERN_2, LEGACY],
            [MODERN_1, MODERN_2, LEGACY, extra_device],
            "does not exactly match the approved devices",
        )

    def test_rejects_malformed_profile_device(self) -> None:
        self.assert_rejected(
            [MODERN_1, MODERN_2, LEGACY],
            [MODERN_1, MODERN_2, "not-a-udid"],
            "malformed device UDID list",
        )


if __name__ == "__main__":
    unittest.main()
