extends SceneTree

const WORKFLOW := "res://.github/workflows/ios-ad-hoc.yml"
const SIGNING_SCRIPT := "res://scripts/prepare-ios-signing.sh"
const SIGNING_VALIDATOR := "res://scripts/validate-ios-signing-material.py"
const ARCHIVE_SCRIPT := "res://scripts/archive-and-export-ios-ad-hoc.sh"
const EXPORT_OPTIONS_SCRIPT := "res://scripts/create-export-options.py"
const CLEANUP_SCRIPT := "res://scripts/cleanup-ios-signing.sh"
const GUIDE := "res://docs/ios-ad-hoc-testing.md"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var workflow := _read(WORKFLOW)
	var signing_script := _read(SIGNING_SCRIPT)
	var signing_validator := _read(SIGNING_VALIDATOR)
	var archive_script := _read(ARCHIVE_SCRIPT)
	var export_options := _read(EXPORT_OPTIONS_SCRIPT)
	var cleanup_script := _read(CLEANUP_SCRIPT)
	var guide := _read(GUIDE)

	_check(
		workflow.contains("on:\n  workflow_dispatch:")
			and not workflow.contains("\n  push:")
			and not workflow.contains("\n  pull_request:"),
		"The Ad Hoc workflow is manual-only."
	)
	_check(
		workflow.contains("confirm_build:")
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
			and not workflow.contains("APP_STORE_CONNECT_PRIVATE_KEY_BASE64"),
		"The Ad Hoc workflow cannot publish a package or access upload keys."
	)
	for secret_name in [
		"APPLE_CERTIFICATE_BASE64",
		"APPLE_CERTIFICATE_PASSWORD",
		"APPLE_AD_HOC_PROVISIONING_PROFILE_BASE64",
		"IOS_AD_HOC_DEVICE_UDID_1",
		"IOS_AD_HOC_DEVICE_UDID_2",
		"IOS_AD_HOC_DEVICE_UDID_3",
	]:
		_check(
			workflow.contains("${{ secrets.%s }}" % secret_name),
			"The Ad Hoc workflow references protected secret %s."
				% secret_name
		)
	_check(
		workflow.contains("IOS_SIGNING_DISTRIBUTION: ad-hoc")
			and workflow.contains(
				"bash scripts/archive-and-export-ios-ad-hoc.sh"
			)
			and workflow.contains(
				"- name: Remove temporary signing material\n"
					+ "        if: always()"
			),
		"The Ad Hoc job selects device signing, validates the IPA, and cleans up."
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
			),
		"Signing preparation requires, masks, and validates the protected UDID."
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
			and archive_script.count("-print0") == 2
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
				"No signed package was uploaded or published."
			)
			and not archive_script.contains("-authenticationKeyPath")
			and not archive_script.contains("upload-artifact"),
		"The exported IPA is verified for the registered device and never uploaded."
	)
	_check(
		cleanup_script.contains("AdHocExportOptions.plist")
			and cleanup_script.contains("ios-ad-hoc-export")
			and cleanup_script.contains(
				"frogcityfeast-exported-profile.mobileprovision"
			),
		"Cleanup removes every temporary Ad Hoc export path."
	)
	_check(
		guide.contains("UDID")
			and guide.contains("IOS_AD_HOC_DEVICE_UDID_1")
			and guide.contains("IOS_AD_HOC_DEVICE_UDID_3")
			and guide.contains("exactly")
			and guide.contains("APPLE_AD_HOC_PROVISIONING_PROFILE_BASE64")
			and guide.contains("No signed IPA is retained")
			and guide.contains("explicit approval")
			and guide.contains("private HTTPS"),
		"The Ad Hoc guide records the blocked inputs and delivery boundary."
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
