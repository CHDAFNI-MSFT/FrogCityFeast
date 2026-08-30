extends SceneTree

const IOS_SMOKE_WORKFLOW := "res://.github/workflows/ios-smoke.yml"
const IOS_PREFLIGHT_SCRIPT := "res://scripts/ios-preflight.sh"
const IOS_EXPORT_SCRIPT := "res://scripts/export-ios.sh"
const IOS_BUILD_SCRIPT := "res://scripts/build-ios-unsigned.sh"
const SETUP_SCRIPT := "res://scripts/setup-unix.sh"
const PRESET_RENDERER := "res://scripts/render-export-presets.py"
const PRESET_TEMPLATE := "res://tools/export-presets.ios.cfg.template"
const TOOLCHAIN_MANIFEST := "res://tools/toolchain.json"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var workflow := _read(IOS_SMOKE_WORKFLOW)
	var preflight := _read(IOS_PREFLIGHT_SCRIPT)
	var export_script := _read(IOS_EXPORT_SCRIPT)
	var build_script := _read(IOS_BUILD_SCRIPT)
	var setup_script := _read(SETUP_SCRIPT)
	var preset_renderer := _read(PRESET_RENDERER)
	var template := _read(PRESET_TEMPLATE)
	var manifest_text := _read(TOOLCHAIN_MANIFEST)
	var parsed_manifest: Variant = JSON.parse_string(manifest_text)
	_check(parsed_manifest is Dictionary, "Toolchain manifest is valid JSON.")
	if not parsed_manifest is Dictionary:
		_finish()
		return
	var manifest := parsed_manifest as Dictionary
	var godot := manifest["godot"] as Dictionary
	var apple_build := manifest["appleBuild"] as Dictionary
	var downloads := godot["downloads"] as Dictionary
	var macos_download := downloads["macosUniversal"] as Dictionary
	var templates_download := downloads["exportTemplates"] as Dictionary

	_check(
		str(godot["version"]) == "4.7.2",
		"Unsigned iOS builds use the pinned Godot 4.7.2 version."
	)
	_check(
		str(apple_build["runnerLabel"]) == "macos-26"
			and str(apple_build["architecture"]) == "arm64"
			and str(apple_build["xcodeVersion"]) == "26.6"
			and str(apple_build["iosSdkVersion"]) == "26.5",
		"Apple runner, architecture, Xcode, and iOS SDK pins are complete."
	)
	_check(
		workflow.contains("on:\n  workflow_dispatch:")
			and not workflow.contains("\n  push:")
			and not workflow.contains("\n  pull_request:"),
		"Unsigned iOS verification is manual-only."
	)
	_check(
		workflow.contains("permissions:\n  contents: read")
			and workflow.contains("persist-credentials: false")
			and not workflow.contains("secrets.")
			and not workflow.contains("\n    environment:"),
		"Unsigned iOS verification is read-only and uses no secrets."
	)
	_check(
		workflow.contains('runs-on: %s' % apple_build["runnerLabel"])
			and workflow.contains(
				"sudo xcode-select --switch %s"
				% apple_build["xcodeDeveloperDir"]
			),
		"The workflow selects the manifest-pinned runner and Xcode."
	)
	_check(
		workflow.contains(str(macos_download["sha512"]))
			and workflow.contains(str(templates_download["sha512"]))
			and workflow.contains(str(macos_download["asset"]))
			and workflow.contains(str(templates_download["asset"])),
		"The workflow cache identity includes both pinned Godot downloads."
	)
	_check(
		setup_script.contains("download_verified()")
			and setup_script.contains('shasum -a 512 "$1"')
			and setup_script.contains('sha512sum "$1"')
			and setup_script.contains(
				"Checksum verification failed for $url."
			)
			and setup_script.contains(
				'godot.downloads.exportTemplates.sha512'
			),
		"Unix setup verifies editor and export-template SHA-512 checksums."
	)
	_check(
		_matches(
			workflow,
			"uses: actions/checkout@[0-9a-f]{40}"
		)
			and _matches(
				workflow,
				"uses: actions/cache@[0-9a-f]{40}"
			),
		"Third-party workflow actions are pinned to commit SHAs."
	)
	_check(
		workflow.contains('APPLE_TEAM_ID: "0000000000"')
			and workflow.contains(
				"IOS_BUNDLE_ID: com.example.samuelicecream"
			),
		"The unsigned workflow uses only synthetic Apple identity values."
	)
	_check(
		workflow.contains("--install-export-templates")
			and workflow.contains("bash scripts/ios-preflight.sh smoke")
			and workflow.contains("bash scripts/export-ios.sh")
			and workflow.contains("bash scripts/build-ios-unsigned.sh")
			and not workflow.contains("actions/upload-artifact"),
		"The workflow installs templates, exports, compiles, and uploads nothing."
	)

	_check(
		preflight.contains('if [[ "$mode" == "release" ]]')
			and not preflight.contains("APPLE_CERTIFICATE_BASE64")
			and not preflight.contains("APPLE_PROVISIONING_PROFILE_BASE64")
			and not preflight.contains("APP_STORE_CONNECT"),
		"Smoke preflight does not require signing or App Store credentials."
	)
	_check(
		export_script.contains("trap cleanup_generated_preset EXIT")
			and export_script.contains(
				'--export-release "iOS"'
			)
			and export_script.contains(
				'xcodebuild -list -project "$xcode_project" -json'
			)
			and export_script.contains(
				'Expected one Xcode scheme'
			),
		"Export creates a temporary preset and validates one Xcode scheme."
	)
	_check(
		build_script.contains('-destination "generic/platform=iOS"')
			and build_script.contains("CODE_SIGNING_ALLOWED=NO")
			and build_script.contains("CODE_SIGNING_REQUIRED=NO")
			and build_script.contains('CODE_SIGN_IDENTITY=""')
			and build_script.contains('DEVELOPMENT_TEAM=""')
			and not build_script.contains("archive"),
		"Generic-device compilation explicitly disables every signing path."
	)

	_check(
		template.contains("architectures/arm64=true")
			and template.contains("application/export_project_only=true")
			and template.contains("application/export_method_release=0")
			and template.contains(
				'application/code_sign_identity_debug=""'
			)
			and template.contains(
				'application/code_sign_identity_release=""'
			)
			and template.contains('export_filter="all_resources"'),
		"The generated iOS preset is arm64, project-only, and unsigned."
	)
	var rendered_template := template
	rendered_template = rendered_template.replace(
		"@APPLE_TEAM_ID@",
		"0000000000"
	)
	rendered_template = rendered_template.replace(
		"@IOS_BUNDLE_ID@",
		"com.example.samuelicecream"
	)
	rendered_template = rendered_template.replace(
		"@IOS_SHORT_VERSION@",
		"0.0.0"
	)
	rendered_template = rendered_template.replace(
		"@IOS_BUILD_NUMBER@",
		"1"
	)
	_check(
		not _matches(rendered_template, "@[A-Z0-9_]+@"),
		"The smoke preset resolves every generated placeholder."
	)
	_check(
		preset_renderer.contains("TEAM_ID_PATTERN")
			and preset_renderer.contains("BUNDLE_ID_PATTERN")
			and preset_renderer.contains("VERSION_PATTERN")
			and preset_renderer.contains("BUILD_PATTERN")
			and preset_renderer.contains(
				'"@APPLE_TEAM_ID@": args.team_id'
			)
			and preset_renderer.contains(
				'"@IOS_BUNDLE_ID@": args.bundle_id'
			)
			and preset_renderer.contains(
				'"@IOS_SHORT_VERSION@": args.short_version'
			)
			and preset_renderer.contains(
				'"@IOS_BUILD_NUMBER@": args.build_number'
			)
			and preset_renderer.contains(
				"The export preset template contains unresolved values."
			),
		"The preset renderer validates inputs and rejects unresolved values."
	)
	_check(
		not FileAccess.file_exists("res://export_presets.cfg"),
		"Generated export_presets.cfg is not left in the worktree."
	)
	_finish()


func _read(path: String) -> String:
	var content := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
	_check(not content.is_empty(), "%s is readable." % path)
	return content


func _matches(value: String, pattern: String) -> bool:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		_failures.append("Invalid smoke-test regex: %s" % pattern)
		return false
	return regex.search(value) != null


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("Unsigned iOS pipeline checks passed.")
		quit(0)
	else:
		print(
			"Unsigned iOS pipeline checks failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
