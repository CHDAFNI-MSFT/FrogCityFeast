extends SceneTree

const WORKFLOW := "res://.github/workflows/ios-ad-hoc.yml"
const PROVISIONING_SCRIPT := "res://scripts/provision-ios-ad-hoc.mjs"
const SIGNING_SCRIPT := "res://scripts/prepare-ios-signing.sh"
const SIGNING_VALIDATOR := "res://scripts/validate-ios-signing-material.py"
const ARCHIVE_SCRIPT := "res://scripts/archive-and-export-ios-ad-hoc.sh"
const OTA_UPLOAD_SCRIPT := "res://scripts/upload-ios-ad-hoc-ota.sh"
const OTA_MANIFEST_SCRIPT := "res://scripts/create-ios-ota-manifest.py"
const EXPORT_OPTIONS_SCRIPT := "res://scripts/create-export-options.py"
const CLEANUP_SCRIPT := "res://scripts/cleanup-ios-signing.sh"
const CHECK_SCRIPT := "res://scripts/check-project.sh"
const GUIDE := "res://docs/ios-ad-hoc-testing.md"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var workflow := _read(WORKFLOW)
	var provisioning_script := _read(PROVISIONING_SCRIPT)
	var signing_script := _read(SIGNING_SCRIPT)
	var signing_validator := _read(SIGNING_VALIDATOR)
	var archive_script := _read(ARCHIVE_SCRIPT)
	var ota_upload_script := _read(OTA_UPLOAD_SCRIPT)
	var ota_manifest_script := _read(OTA_MANIFEST_SCRIPT)
	var export_options := _read(EXPORT_OPTIONS_SCRIPT)
	var cleanup_script := _read(CLEANUP_SCRIPT)
	var check_script := _read(CHECK_SCRIPT)
	var guide := _read(GUIDE)

	_check(
		workflow.contains("on:\n  workflow_dispatch:")
			and not workflow.contains("\n  push:")
			and not workflow.contains("\n  pull_request:"),
		"The Ad Hoc workflow is manual-only."
	)
	_check(
		workflow.contains("confirm_build:")
			and workflow.contains("publish_private_ota:")
			and workflow.contains("confirm_private_ota:")
			and workflow.contains("UPLOAD_PRIVATE_OTA")
			and workflow.count("inputs.version == '0.1.0'") == 2
			and workflow.contains("github.ref == 'refs/heads/main'")
			and workflow.contains(
				"    environment:\n      name: ad-hoc"
			)
			and workflow.contains("    needs: authorize")
			and workflow.contains(
				"    environment:\n      name: testflight"
			),
		"The Ad Hoc workflow is main-only, version-pinned, and double-gated."
	)
	_check(
		workflow.contains("permissions:\n  contents: read")
			and workflow.contains("persist-credentials: false")
			and not workflow.contains("actions/upload-artifact")
			and not workflow.contains("archive-and-upload-ios")
			and not workflow.contains("APP_STORE_CONNECT_KEY_ID")
			and not workflow.contains("APP_STORE_CONNECT_PRIVATE_KEY_BASE64")
			and not workflow.contains("actions/upload-artifact")
			and not workflow.contains("upload-artifact"),
		"The Ad Hoc workflow cannot publish a GitHub artifact or access App Store upload keys."
	)
	for secret_name in [
		"APPLE_CERTIFICATE_BASE64",
		"APPLE_CERTIFICATE_PASSWORD",
		"APPLE_PROVISIONING_KEY_ID",
		"APPLE_PROVISIONING_PRIVATE_KEY_BASE64",
		"APP_STORE_CONNECT_ISSUER_ID",
		"IOS_AD_HOC_DEVICE_UDID_1",
		"IOS_AD_HOC_DEVICE_UDID_2",
		"IOS_AD_HOC_DEVICE_UDID_3",
		"AZURE_OTA_UPLOAD_SAS",
		"AZURE_OTA_INSTALL_SAS",
	]:
		_check(
			workflow.contains("${{ secrets.%s }}" % secret_name),
			"The Ad Hoc workflow references protected secret %s."
				% secret_name
		)
	_check(
		workflow.contains("node scripts/provision-ios-ad-hoc.mjs --apply")
			and workflow.find("Provision protected Ad Hoc profile")
				< workflow.find("Prepare protected Ad Hoc signing")
			and workflow.count(
				"${{ secrets.APPLE_PROVISIONING_KEY_ID }}"
			) == 1
			and workflow.count(
				"${{ secrets.APPLE_PROVISIONING_PRIVATE_KEY_BASE64 }}"
			) == 1
			and not workflow.contains(
				"APPLE_AD_HOC_PROVISIONING_PROFILE_BASE64"
			)
			and not workflow.contains(
				"APPLE_PROVISIONING_PROFILE_BASE64:"
			),
		"The Admin key is provisioning-only and no Ad Hoc profile secret is required."
	)
	_check(
		workflow.contains("IOS_SIGNING_DISTRIBUTION: ad-hoc")
			and workflow.contains(
				"bash scripts/archive-and-export-ios-ad-hoc.sh"
			)
			and workflow.contains(
				"- name: Remove temporary signing material\n"
					+ "        if: always()"
			)
			and workflow.contains(
				"bash scripts/upload-ios-ad-hoc-ota.sh"
			)
			and workflow.find("Archive and validate Ad Hoc package")
				< workflow.find("Upload protected private OTA package")
			and workflow.find("Upload protected private OTA package")
				< workflow.find("Remove temporary signing material"),
		"The Ad Hoc job validates before optional private upload and always cleans up."
	)
	_check(
		provisioning_script.contains(
			'APPLE_PROVISIONING_KEY_ID'
		)
			and provisioning_script.contains(
				'APPLE_PROVISIONING_PRIVATE_KEY_BASE64'
			)
			and provisioning_script.contains(
				'APP_STORE_CONNECT_ISSUER_ID'
			)
			and provisioning_script.contains(
				'profileType: PROFILE_TYPE'
			)
			and provisioning_script.contains(
				'certificateType]": "DISTRIBUTION"'
			)
			and not provisioning_script.contains("activated")
			and provisioning_script.contains(
				"convert-ios-profile-plist.py"
			)
			and provisioning_script.contains(
				"requireCompleteCollection"
			)
			and provisioning_script.contains(
				'"profile download"'
			)
			and provisioning_script.contains(
				'APPLE_PROVISIONING_PROFILE_PATH='
			)
			and provisioning_script.contains(
				'new Set(actualDevices).size !== 3'
			)
			and not provisioning_script.contains('"PATCH"')
			and not provisioning_script.contains('"DELETE"')
			and not provisioning_script.contains("/v1/apps")
			and not provisioning_script.contains("upload"),
		"API provisioning is fail-closed, exact, and cannot modify unrelated Apple resources."
	)
	_check(
		signing_script.contains(
			'IOS_AD_HOC_DEVICE_UDID_1'
		)
			and signing_script.contains(
				'IOS_AD_HOC_DEVICE_UDID_2'
			)
			and signing_script.contains(
				'IOS_AD_HOC_DEVICE_UDID_3'
			)
			and signing_script.contains(
				'echo "::add-mask::$device_udid"'
			)
			and signing_script.contains(
				'--device-udid-env "$device_env_name"'
			)
			and signing_script.contains(
				"The protected Ad Hoc device UDIDs must be unique."
			)
			and signing_script.contains(
				'IOS_SIGNING_DISTRIBUTION must be app-store or ad-hoc.'
			)
			and signing_script.contains(
				'APPLE_PROVISIONING_PROFILE_PATH is not permitted for App Store signing.'
			)
			and signing_script.contains(
				'Ad Hoc signing requires exactly one provisioning profile Base64 value or path.'
			)
			and signing_script.contains(
				'frogcityfeast-api-provisioning.mobileprovision'
			)
			and signing_script.contains(
				"normalized_device_count > 0"
			)
			and signing_script.contains(
				'! -f "$APPLE_PROVISIONING_PROFILE_PATH"'
			)
			and signing_script.contains(
				'profile_source_directory'
			)
			and signing_script.contains(
				'runner_temp_directory'
			)
			and signing_script.contains(
				'-passin env:APPLE_CERTIFICATE_PASSWORD'
			)
			and signing_script.contains(
				'-f pemseq'
			)
			and not signing_script.contains(
				'-P "$APPLE_CERTIFICATE_PASSWORD"'
			),
		"Signing preparation preserves App Store input rules and constrains API profile handoff."
	)
	_check(
		signing_validator.contains('choices=("app-store", "ad-hoc")')
			and signing_validator.contains('"ProvisionedDevices"')
			and signing_validator.contains(
				"profile_device_udids == expected_device_udids"
			)
			and signing_validator.contains(
				"len(profile_device_udids) == len(provisioned_devices)"
			)
			and signing_validator.contains(
				'"--device-udid-env"'
			)
			and signing_validator.contains(
				"Enterprise provisioning is not permitted"
			),
		"The profile validator distinguishes App Store and Ad Hoc profiles."
	)
	_check(
		export_options.contains(
			'choices=("internal-testflight", "app-store", "ad-hoc")'
		)
			and export_options.contains(
				'options["method"] = "release-testing"'
			)
			and export_options.contains(
				'options["destination"] = "export"'
			),
		"Ad Hoc export uses Xcode's current release-testing method."
	)
	_check(
		archive_script.contains("codesign --verify --deep --strict")
			and not archive_script.contains("mapfile")
			and archive_script.count("-print0") == 3
			and archive_script.contains(
				"ios-ad-hoc-ipa-validation"
			)
			and archive_script.contains(
				'codesign --verify --deep --strict "$exported_app_path"'
			)
			and archive_script.contains(
				"embedded.mobileprovision"
			)
			and archive_script.contains(
				"profile_devices != expected_devices"
			)
			and archive_script.contains(
				"len(profile_devices) != len(devices)"
			)
			and not archive_script.contains(
				'"$IOS_AD_HOC_DEVICE_UDID_'
			)
			and archive_script.contains(
				"IOS_AD_HOC_IPA_PATH="
			)
			and not archive_script.contains("-authenticationKeyPath")
			and not archive_script.contains("upload-artifact"),
		"The exported IPA is verified and handed only to the protected delivery step."
	)
	_check(
		ota_upload_script.contains("::add-mask::")
			and ota_upload_script.contains("si=workflow-upload")
			and ota_upload_script.contains("si=device-install")
			and ota_upload_script.contains("spr=https")
			and ota_upload_script.contains("If-None-Match: *")
			and ota_upload_script.contains("Content-MD5:")
			and ota_upload_script.contains("blob.core.windows.net")
			and ota_upload_script.contains(
				"rollback_incomplete_upload"
			)
			and ota_upload_script.contains(
				"x-ms-meta-frogcityfeast_build"
			)
			and ota_upload_script.contains(
				"require_blob_absent"
			)
			and ota_upload_script.contains(
				"verify_anonymous_access_denied"
			)
			and ota_upload_script.contains(
				"A private OTA blob is accessible without authorization."
			)
			and ota_upload_script.contains(
				"PublicAccessNotPermitted"
			)
			and ota_upload_script.contains(
				"Incomplete private OTA blobs were removed."
			)
			and ota_upload_script.contains(
				"create-ios-ota-manifest.py"
			)
			and ota_upload_script.contains(
				"The signed installation URL was not printed or committed."
			)
			and not ota_upload_script.contains("set -x")
			and not ota_upload_script.contains("upload-artifact")
			and ota_manifest_script.contains("device-install")
			and ota_manifest_script.contains("software-package")
			and ota_manifest_script.contains("plistlib.FMT_XML"),
		"Private OTA upload is policy-bound, integrity-checked, and does not expose its URL."
	)
	_check(
		cleanup_script.contains("AdHocExportOptions.plist")
			and cleanup_script.contains("ios-ad-hoc-export")
			and cleanup_script.contains(
				"frogcityfeast-exported-profile.mobileprovision"
			)
			and cleanup_script.contains(
				"frogcityfeast-api-distribution.p12"
			)
			and cleanup_script.contains(
				"frogcityfeast-api-distribution.pem"
			)
			and cleanup_script.contains(
				"frogcityfeast-api-provisioning.mobileprovision"
			)
			and cleanup_script.contains(
				"frogcityfeast-api-profile.plist"
			)
			and cleanup_script.contains(
				"frogcityfeast-signing-identity.pem"
			)
			and cleanup_script.contains(
				"frogcityfeast-ota-manifest.plist"
			)
			and cleanup_script.contains(
				"ios-ad-hoc-ipa-validation"
			),
		"Cleanup removes every temporary Ad Hoc API and export path."
	)
	_check(
		check_script.contains(
			'node "$repo_root/tests/ios_ad_hoc_provisioning_test.mjs"'
		)
			and check_script.contains(
				'python3 "$repo_root/tests/ios_ota_manifest_test.py"'
		),
		"The normal project check runs provisioning and OTA regression tests."
	)
	_check(
		guide.contains("UDID")
			and guide.contains("IOS_AD_HOC_DEVICE_UDID_1")
			and guide.contains("IOS_AD_HOC_DEVICE_UDID_3")
			and guide.contains("exactly")
			and guide.contains("APPLE_PROVISIONING_KEY_ID")
			and guide.contains("automatically")
			and not guide.contains("APPLE_AD_HOC_PROVISIONING_PROFILE_BASE64")
			and guide.contains("publish_private_ota")
			and guide.contains("UPLOAD_PRIVATE_OTA")
			and guide.contains("SecurityControl=Ignore")
			and guide.contains("resource group has no exclusion tag")
			and guide.contains("Anonymous access remains disabled")
			and guide.contains("private HTTPS"),
		"The Ad Hoc guide records the protected inputs and private delivery boundary."
	)

	_finish()


func _read(path: String) -> String:
	var content := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
	_check(not content.is_empty(), "%s is readable." % path)
	return content


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("iOS Ad Hoc pipeline checks passed.")
		quit(0)
	else:
		quit(1)
