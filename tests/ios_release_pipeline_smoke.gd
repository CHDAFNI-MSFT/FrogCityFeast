extends SceneTree

const RELEASE_WORKFLOW := "res://.github/workflows/ios-testflight.yml"
const EXPORT_SCRIPT := "res://scripts/export-ios.sh"
const GENERATED_PROJECT_VALIDATOR := \
	"res://scripts/validate-ios-generated-project.py"
const SIGNING_SCRIPT := "res://scripts/prepare-ios-signing.sh"
const SIGNING_VALIDATOR := "res://scripts/validate-ios-signing-material.py"
const ARCHIVE_SCRIPT := "res://scripts/archive-and-upload-ios.sh"
const CLEANUP_SCRIPT := "res://scripts/cleanup-ios-signing.sh"
const EXPORT_OPTIONS_SCRIPT := "res://scripts/create-export-options.py"
const PRESET_TEMPLATE := "res://tools/export-presets.ios.cfg.template"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var workflow := _read(RELEASE_WORKFLOW)
	var export_script := _read(EXPORT_SCRIPT)
	var project_validator := _read(GENERATED_PROJECT_VALIDATOR)
	var signing_script := _read(SIGNING_SCRIPT)
	var signing_validator := _read(SIGNING_VALIDATOR)
	var archive_script := _read(ARCHIVE_SCRIPT)
	var cleanup_script := _read(CLEANUP_SCRIPT)
	var export_options := _read(EXPORT_OPTIONS_SCRIPT)
	var template := _read(PRESET_TEMPLATE)

	_check(
		workflow.contains("on:\n  workflow_dispatch:")
			and workflow.contains('\n  push:\n    tags:\n      - "v*"')
			and not workflow.contains("\n  pull_request:"),
		"TestFlight releases are manual or v* tag-driven, never pull-request "
			+ "triggered."
	)
	_check(
		workflow.contains("permissions:\n  contents: read")
			and workflow.contains("persist-credentials: false")
			and not workflow.contains("actions/upload-artifact"),
		"The release workflow is read-only, persists no Git credential, and "
			+ "uploads no signing or build artifact."
	)
	_check(
		workflow.contains(
			"if: github.event_name == 'push' || "
				+ "github.ref == 'refs/heads/main'"
		)
			and workflow.contains(
				"    environment:\n      name: testflight"
			),
		"Manual releases are limited to main and use the protected testflight "
			+ "environment."
	)

	for variable_name in ["APPLE_TEAM_ID", "IOS_BUNDLE_ID"]:
		_check(
			workflow.contains("${{ vars.%s }}" % variable_name),
			"The release workflow references environment variable %s."
				% variable_name
		)
	for secret_name in [
		"APPLE_CERTIFICATE_BASE64",
		"APPLE_CERTIFICATE_PASSWORD",
		"APPLE_PROVISIONING_PROFILE_BASE64",
		"APP_STORE_CONNECT_KEY_ID",
		"APP_STORE_CONNECT_ISSUER_ID",
		"APP_STORE_CONNECT_PRIVATE_KEY_BASE64",
	]:
		_check(
			workflow.contains("${{ secrets.%s }}" % secret_name),
			"The release workflow references environment secret %s."
				% secret_name
		)

	_check(
		workflow.contains(
			"- name: Remove temporary signing material\n"
				+ "        if: always()\n"
				+ "        run: bash scripts/cleanup-ios-signing.sh"
		),
		"Signing cleanup runs even after an earlier release failure."
	)
	_check(
		workflow.contains("IOS_DISTRIBUTION: internal-testflight"),
		"The TestFlight workflow explicitly selects internal-only distribution."
	)
	_check(
		workflow.contains(
			"IOS_BUILD_NUMBER=$GITHUB_RUN_ID.$GITHUB_RUN_ATTEMPT"
		)
			and not workflow.contains("$GITHUB_RUN_NUMBER"),
		"The TestFlight workflow uses a repository-wide unique build number."
	)
	_check(
		export_script.contains("validate-ios-generated-project.py")
			and export_script.contains('--team-id "$APPLE_TEAM_ID"')
			and export_script.contains('--bundle-id "$IOS_BUNDLE_ID"')
			and export_script.contains(
				'--display-name "$ios_display_name"'
			)
			and export_script.contains('--short-version "$IOS_SHORT_VERSION"')
			and export_script.contains('--build-number "$IOS_BUILD_NUMBER"'),
		"Every generated Xcode project is sanitized and validated before use."
	)
	_check(
		project_validator.contains("UNUSED_PRIVACY_KEYS")
			and project_validator.contains(
				"ITSAppUsesNonExemptEncryption"
			)
			and project_validator.contains('"DEVELOPMENT_TEAM"')
			and project_validator.contains(
				'"INFOPLIST_KEY_CFBundleDisplayName"'
			)
			and project_validator.contains("TARGETED_DEVICE_FAMILY")
			and project_validator.contains("PrivacyInfo.xcprivacy")
			and project_validator.contains(
				"ASSETCATALOG_COMPILER_APPICON_NAME"
			),
		"Generated privacy metadata, encryption status, and AppIcon wiring are "
			+ "validated."
	)
	_check(
		signing_script.contains("validate-ios-signing-material.py")
			and signing_script.contains(
				"-passin env:APPLE_CERTIFICATE_PASSWORD"
			)
			and signing_script.contains(
				"-S apple-tool:,apple:,codesign:"
			)
			and signing_script.contains("\n  -s \\\n")
			and signing_script.contains(
				"security find-identity -v -p codesigning"
			),
		"Signing preparation validates the profile, certificate, and imported "
			+ "identity."
	)
	_check(
		signing_validator.contains('"get-task-allow"')
			and signing_validator.contains('"ProvisionedDevices"')
			and signing_validator.contains('"ProvisionsAllDevices"')
			and signing_validator.contains('"ExpirationDate"')
			and signing_validator.contains('"DeveloperCertificates"')
			and signing_validator.contains("Apple Distribution"),
		"The release rejects development, device, enterprise, expired, or "
			+ "mismatched signing material."
	)
	_check(
		archive_script.contains('CODE_SIGN_STYLE=Manual')
			and archive_script.contains(
				'CODE_SIGN_IDENTITY="Apple Distribution"'
			)
			and archive_script.contains(
				'PROVISIONING_PROFILE_SPECIFIER='
			)
			and archive_script.contains(
				'-derivedDataPath "$repo_root/build/ios/DerivedData"'
			)
			and archive_script.contains("-authenticationKeyPath")
			and archive_script.contains(
				'--distribution "$IOS_DISTRIBUTION"'
			)
			and not archive_script.contains("-allowProvisioningUpdates"),
		"Archiving uses the reviewed manual identity and cannot modify signing "
			+ "assets in the Apple portal."
	)
	_check(
		cleanup_script.contains("frogcityfeast-signing.keychain-db")
			and cleanup_script.contains(
				"frogcityfeast-distribution.p12"
			)
			and cleanup_script.contains(
				"frogcityfeast-distribution.pem"
			)
			and cleanup_script.contains(
				"frogcityfeast-app-store.mobileprovision"
			)
			and cleanup_script.contains("app-store-connect")
			and cleanup_script.contains("ios-upload")
			and cleanup_script.contains("cleanup_failed=0")
			and cleanup_script.contains("exit 1")
			and not cleanup_script.contains("|| true"),
		"Cleanup verifies every temporary signing and upload path."
	)
	_check(
		export_options.contains('"destination": "upload"')
			and export_options.contains('"method": "app-store-connect"')
			and export_options.contains('"signingStyle": "manual"')
			and export_options.contains(
				'if args.distribution == "internal-testflight":'
			)
			and export_options.contains(
				'options["testFlightInternalTestingOnly"] = True'
			)
			and export_options.contains(
				'"signingCertificate": "Apple Distribution"'
			),
		"Export options submit an internal-only TestFlight build with explicit "
			+ "manual signing."
	)
	_check(
		template.contains(
			'icons/icon_1024x1024="res://assets/icon.svg"'
		)
			and template.contains("application/targeted_device_family=1")
			and template.contains("modules/camera=false")
			and template.contains(
				"privacy/file_timestamp_access_reasons=2"
			)
			and template.contains(
				"privacy/system_boot_time_access_reasons=1"
			)
			and template.contains(
				"privacy/disk_space_access_reasons=1"
			)
			and template.contains("privacy/tracking_enabled=false"),
		"The release preset explicitly pins its icon, disabled camera module, "
			+ "and reviewed privacy-manifest declarations."
	)

	_finish()


func _read(path: String) -> String:
	var content := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
	_check(not content.is_empty(), "%s is readable." % path)
	return content


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("TestFlight release pipeline checks passed.")
		quit(0)
	else:
		print(
			"TestFlight release pipeline checks failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
