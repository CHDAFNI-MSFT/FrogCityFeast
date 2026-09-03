extends SceneTree

const WORKFLOW := "res://.github/workflows/ios-app-store.yml"
const TESTFLIGHT_WORKFLOW := "res://.github/workflows/ios-testflight.yml"
const METADATA_WORKFLOW := "res://.github/workflows/app-store-metadata.yml"
const METADATA_SYNC_SCRIPT := "res://scripts/sync-app-store-metadata.mjs"
const INSPECTION_WORKFLOW := (
	"res://.github/workflows/app-store-candidate-inspection.yml"
)
const INSPECTION_SCRIPT := "res://scripts/inspect-app-store-candidate.mjs"
const ARCHIVE_SCRIPT := "res://scripts/archive-and-upload-ios.sh"
const CLEANUP_SCRIPT := "res://scripts/cleanup-ios-signing.sh"
const EXPORT_OPTIONS_SCRIPT := "res://scripts/create-export-options.py"
const IOS_RELEASE_DOC := "res://docs/ios-release.md"
const METADATA_JSON := "res://tools/app-store-metadata.json"
const METADATA_DOC := "res://docs/app-store-metadata.md"
const PRIVACY_DOC := "res://docs/privacy-policy.md"
const SUPPORT_DOC := "res://docs/app-support.md"
const RELEASE_CHECKLIST := "res://docs/app-store-release-checklist.md"
const PUBLISHING_RUNBOOK := "res://docs/apple-app-publishing-runbook.md"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var workflow := _read(WORKFLOW)
	var testflight_workflow := _read(TESTFLIGHT_WORKFLOW)
	var metadata_workflow := _read(METADATA_WORKFLOW)
	var metadata_sync_script := _read(METADATA_SYNC_SCRIPT)
	var inspection_workflow := _read(INSPECTION_WORKFLOW)
	var inspection_script := _read(INSPECTION_SCRIPT)
	var archive_script := _read(ARCHIVE_SCRIPT)
	var cleanup_script := _read(CLEANUP_SCRIPT)
	var export_options := _read(EXPORT_OPTIONS_SCRIPT)
	var release_doc := _read(IOS_RELEASE_DOC)
	var metadata_json := _read(METADATA_JSON)
	var metadata_doc := _read(METADATA_DOC)
	var privacy_doc := _read(PRIVACY_DOC)
	var support_doc := _read(SUPPORT_DOC)
	var checklist := _read(RELEASE_CHECKLIST)
	var publishing_runbook := _read(PUBLISHING_RUNBOOK)

	_check(
		not publishing_runbook.is_empty()
			and release_doc.contains("apple-app-publishing-runbook.md"),
		"The reusable Apple publishing runbook is missing or unlinked."
	)

	_check(
		workflow.contains("on:\n  workflow_dispatch:")
			and not workflow.contains("\n  push:")
			and not workflow.contains("\n  pull_request:"),
		"The App Store candidate workflow is manual-only."
	)
	_check(
		workflow.contains("confirm_upload:")
			and workflow.contains(
				"  authorize:\n"
					+ "    name: Approve public App Store candidate"
			)
			and workflow.contains(
				"github.ref == 'refs/heads/main'"
			)
			and workflow.contains("inputs.confirm_upload")
			and workflow.count("inputs.version == '0.1.0'") == 2
			and workflow.contains(
				"    environment:\n      name: app-store"
			)
			and workflow.contains("    needs: authorize")
			and workflow.contains(
				"    environment:\n      name: testflight"
			)
			and workflow.contains(
				"needs.authorize.result == 'success'"
			),
		"The App Store upload requires main, explicit confirmation, public "
			+ "approval, and the existing protected signing environment."
	)
	_check(
		workflow.contains(
			'if [[ "$REQUESTED_VERSION" != "0.1.0" ]]; then'
		)
			and workflow.contains(
				"Only the explicitly authorized version 0.1.0 may upload."
			),
		"The candidate workflow is fail-closed to the authorized version 0.1.0."
	)
	_check(
		workflow.contains("permissions:\n  contents: read")
			and workflow.contains("persist-credentials: false")
			and not workflow.contains("actions/upload-artifact"),
		"The App Store workflow is read-only and publishes no build artifact."
	)
	_check(
		workflow.contains("IOS_DISTRIBUTION: app-store")
			and workflow.contains(
				"Archive and upload App Store candidate"
			)
			and not workflow.contains("testFlightInternalTestingOnly"),
		"The public workflow selects the normal App Store export mode."
	)
	_check(
		workflow.contains(
			"IOS_BUILD_NUMBER=$GITHUB_RUN_ID.$GITHUB_RUN_ATTEMPT"
		)
			and testflight_workflow.contains(
				"IOS_BUILD_NUMBER=$GITHUB_RUN_ID.$GITHUB_RUN_ATTEMPT"
			)
			and not workflow.contains("$GITHUB_RUN_NUMBER")
			and not testflight_workflow.contains("$GITHUB_RUN_NUMBER"),
		"Both upload workflows share collision-resistant build numbering."
	)
	_check(
		testflight_workflow.contains(
			"IOS_DISTRIBUTION: internal-testflight"
		),
		"The historical TestFlight workflow explicitly retains internal mode."
	)
	_check(
		metadata_workflow.contains("on:\n  workflow_dispatch:")
			and metadata_workflow.contains("confirm_sync:")
			and metadata_workflow.contains(
				"github.ref == 'refs/heads/main'"
			)
			and metadata_workflow.count(
				"inputs.version == '0.1.0'"
			) == 2
			and metadata_workflow.contains(
				"    environment:\n      name: app-store"
			)
			and metadata_workflow.contains("    needs: authorize")
			and metadata_workflow.contains(
				"    environment:\n      name: testflight"
			)
			and metadata_workflow.contains(
				"node scripts/sync-app-store-metadata.mjs --apply"
			),
		"The metadata workflow is manual, main-only, version-pinned, and "
			+ "double-gated."
	)
	_check(
		metadata_workflow.contains("permissions:\n  contents: read")
			and metadata_workflow.contains("persist-credentials: false")
			and not metadata_workflow.contains("archive-and-upload-ios")
			and not metadata_workflow.contains("actions/upload-artifact")
			and not metadata_sync_script.contains("reviewSubmissions")
			and not metadata_sync_script.contains(
				"appStoreVersionReleaseRequests"
			)
			and not metadata_sync_script.contains("relationships/build")
			and not metadata_sync_script.contains(
				"appStoreVersionSubmissions"
			),
		"The metadata workflow cannot upload a build, submit, release, or "
			+ "publish an artifact."
	)
	_check(
		metadata_sync_script.contains(
			'notAutomated: ['
		)
			and metadata_sync_script.contains('"build selection"')
			and metadata_sync_script.contains('"submission"')
			and metadata_sync_script.contains('"release"'),
		"The metadata sync explicitly reports every excluded publication step."
	)
	_check(
		metadata_sync_script.find(
			"const existingVersion = await findVersion"
		) < metadata_sync_script.find(
			"const existingAppInfoLocalization = await "
				+ "findAppInfoLocalization"
		)
			and metadata_sync_script.find(
				"const existingAppInfoLocalization = await "
					+ "findAppInfoLocalization"
			) < metadata_sync_script.find(
				"const existingVersionLocalization = await "
					+ "findVersionLocalization"
			)
			and metadata_sync_script.find(
				"const existingVersionLocalization = await "
					+ "findVersionLocalization"
			) < metadata_sync_script.find("await updateCategories")
			and metadata_sync_script.contains('"partial_failure"')
			and metadata_sync_script.contains("appliedResources"),
		"The metadata sync validates version editability before writes and "
			+ "reports partial application."
	)
	_check(
		not metadata_sync_script.contains('"filter[versionString]"')
			and metadata_sync_script.contains(
				"payload.data.length > 1"
			)
			and metadata_sync_script.contains(
				"return selectVersion(payload, metadata)"
			)
			and metadata_sync_script.contains(
				"version.attributes?.versionString !== metadata.version"
			)
			and metadata_sync_script.contains(
				"attributes.versionString = metadata.version"
			),
		"The metadata sync cannot safely adopt and rename the initial "
			+ "editable App Store version."
	)
	_check(
		metadata_sync_script.contains('whats_new: ""')
			and not metadata_sync_script.contains("attributes.whatsNew")
			and not metadata_sync_script.contains(
				"whatsNew: metadata.whats_new || null"
			),
		"The metadata sync attempts to write What's New for the first "
			+ "App Store version."
	)
	_check(
		metadata_sync_script.contains("attemptedResources")
			and metadata_sync_script.contains(
				"failedResource: currentResource"
			)
			and metadata_sync_script.contains("unattemptedResources"),
		"The metadata sync does not distinguish failed and unattempted writes."
	)
	_check(
		metadata_sync_script.contains(
			'fail("The created App Store version response is invalid.")'
		)
			and metadata_sync_script.contains(
				'recordResourceApplied("appStoreVersion");\n'
					+ "    return version.id;"
			),
		"A newly created App Store version is not validated or is "
			+ "redundantly patched."
	)
	_check(
		inspection_workflow.contains("on:\n  workflow_dispatch:")
			and inspection_workflow.contains("confirm_inspection:")
			and inspection_workflow.count(
				"inputs.version == '0.1.0'"
			) == 2
			and inspection_workflow.contains(
				"    environment:\n      name: app-store"
			)
			and inspection_workflow.contains(
				"    environment:\n      name: testflight"
			)
			and inspection_workflow.contains(
				"inspect-app-store-candidate.mjs --wait-for-processing"
			)
			and inspection_workflow.contains(
				"IOS_BUILD_NUMBER: 33770597608.1"
			)
			and not inspection_workflow.contains("inputs.build_number")
			and inspection_workflow.contains(
				"permissions:\n  contents: read"
			)
			and not inspection_workflow.contains("actions/upload-artifact"),
		"The candidate inspector is manual, version-pinned, double-gated, "
			+ "and publishes no artifact."
	)
	_check(
		inspection_script.contains('"filter[version]"')
			and inspection_script.contains('"filter[app]"')
			and inspection_script.contains("processingState")
			and inspection_script.contains("usesNonExemptEncryption")
			and inspection_script.contains(
				"relationships/appStoreReviewDetail"
			)
			and inspection_script.contains("appScreenshotSets")
			and inspection_script.contains("apiVisibleBlockers")
			and inspection_script.contains(
				'const EXPECTED_BUILD_NUMBER = "33770597608.1"'
			)
			and inspection_script.contains("failForBlockers(blockers);")
			and not inspection_script.contains(
				'apiRequest(token, "POST"'
			)
			and not inspection_script.contains(
				'apiRequest(token, "PATCH"'
			)
			and not inspection_script.contains(
				'apiRequest(token, "DELETE"'
			),
		"The candidate inspector is read-only and checks processing, review, "
			+ "and screenshot prerequisites."
	)

	for variable_name in ["APPLE_TEAM_ID", "IOS_BUNDLE_ID"]:
		_check(
			workflow.contains("${{ vars.%s }}" % variable_name),
			"The App Store workflow references environment variable %s."
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
			"The signed candidate job references protected secret %s."
				% secret_name
		)

	_check(
		archive_script.contains(
			'IOS_DISTRIBUTION must be internal-testflight or app-store.'
		)
			and archive_script.contains(
				'--distribution "$IOS_DISTRIBUTION"'
			)
			and archive_script.contains(
				"It was not submitted for App Review or released."
			),
		"The shared archive script validates distribution mode and distinguishes "
			+ "candidate upload from submission or release."
	)
	_check(
		export_options.contains(
			'choices=("internal-testflight", "app-store", "ad-hoc")'
		)
			and export_options.contains(
				'if args.distribution == "internal-testflight":'
			)
			and export_options.contains(
				'options["testFlightInternalTestingOnly"] = True'
			),
		"The export-options generator adds the TestFlight-only key only for "
			+ "the internal mode."
	)
	_check(
		cleanup_script.contains("TestFlightExportOptions.plist")
			and cleanup_script.contains("AppStoreExportOptions.plist")
			and cleanup_script.contains("app-store-connect")
			and cleanup_script.contains("ios-upload")
			and cleanup_script.contains("cleanup_failed=0")
			and cleanup_script.contains("exit 1")
			and not cleanup_script.contains("|| true"),
		"Cleanup verifies both export modes and all temporary upload material."
	)

	_check(
		release_doc.contains("normal public App Store")
			and release_doc.contains(
				"| Selected distribution | Normal public App Store release |"
			)
			and release_doc.contains("testFlightInternalTestingOnly")
			and release_doc.contains("under 13"),
		"The release guide records the public route and TestFlight restriction."
	)
	_validate_metadata(metadata_json)
	_check(
		metadata_doc.contains("Primary category: **Games**")
			and metadata_doc.contains(
				"Primary Games subcategory: **Casual**"
			)
			and metadata_doc.contains(
				"Secondary Games subcategory: **Adventure**"
			)
			and metadata_doc.contains("Cartoon or fantasy violence")
			and metadata_doc.contains(
				"No, we do not collect data from this app"
			),
		"The metadata template covers category, rating, and privacy inputs."
	)
	_check(
		privacy_doc.contains("does not collect")
			and privacy_doc.contains("only on the device")
			and privacy_doc.contains("Support communications"),
		"The privacy template separates local saves from external support."
	)
	_check(
		support_doc.contains("Delete the app and its app data")
			and support_doc.contains("no account")
			and support_doc.contains("public support issue form")
			and support_doc.contains("personal or sensitive data"),
		"The support page explains local-data deletion and safe public contact."
	)
	_check(
		checklist.contains("Physical A16 iPad acceptance")
			and checklist.contains("Explicit upload authorization")
			and checklist.contains("Explicit submission authorization")
			and checklist.contains("Explicit release authorization"),
		"The release checklist preserves every device and publication gate."
	)

	_finish()


func _validate_metadata(source: String) -> void:
	var parsed: Variant = JSON.parse_string(source)
	_check(parsed is Dictionary, "The App Store metadata JSON is valid.")
	if not parsed is Dictionary:
		return
	var metadata := parsed as Dictionary
	var limits := {
		"name": 30,
		"subtitle": 30,
		"promotional_text": 170,
		"description": 4000,
		"whats_new": 4000,
	}
	for field in limits:
		var value := str(metadata.get(field, ""))
		_check(
			value.length() <= int(limits[field]),
			"Metadata field %s stays within its character limit." % field
		)
	var keywords := str(metadata.get("keywords", ""))
	_check(
		keywords.to_utf8_buffer().size() <= 100,
		"Metadata keywords stay within Apple's 100-byte limit."
	)
	_check(
		str(metadata.get("primary_category", "")) == "Games"
			and str(metadata.get("primary_subcategory", "")) == "Casual"
			and str(metadata.get("secondary_subcategory", "")) == "Adventure",
		"The machine-readable category recommendation remains reviewed."
	)
	_check(
		int(metadata.get("schema_version", 0)) == 2
			and str(metadata.get("platform", "")) == "IOS"
			and str(metadata.get("release_type", "")) == "MANUAL"
			and str(metadata.get("primary_category_id", "")) == "GAMES"
			and str(metadata.get("primary_subcategory_one_id", ""))
				== "GAMES_CASUAL"
			and str(metadata.get("primary_subcategory_two_id", ""))
				== "GAMES_ADVENTURE",
		"The API metadata map preserves platform, release, and category IDs."
	)
	var age_rating := metadata.get("age_rating", {}) as Dictionary
	_check(
		str(metadata.get("content_rights_declaration", ""))
				== "DOES_NOT_USE_THIRD_PARTY_CONTENT"
			and str(metadata.get("app_privacy", "")) == "NO_DATA_COLLECTED"
			and str(age_rating.get("violenceCartoonOrFantasy", ""))
				== "FREQUENT"
			and str(age_rating.get("violenceRealistic", "")) == "NONE",
		"Content rights, privacy, and age-rating answers remain reviewed."
	)
	var combined_copy := (
		str(metadata.get("subtitle", ""))
		+ " "
		+ str(metadata.get("promotional_text", ""))
		+ " "
		+ str(metadata.get("description", ""))
	).to_lower()
	for inaccurate_claim in ["ice cream delivery", "pixel art", "retro"]:
		_check(
			not combined_copy.contains(inaccurate_claim),
			"Metadata excludes the inaccurate claim %s." % inaccurate_claim
		)
	for required_claim in [
		"no ads",
		"no in-app purchases",
		"no account",
		"no data collection",
	]:
		_check(
			combined_copy.contains(required_claim),
			"Metadata retains the reviewed claim %s." % required_claim
		)
	for field in ["support_url", "privacy_policy_url"]:
		var value := str(metadata.get(field, ""))
		_check(
			value.begins_with("https://")
				or value == "REQUIRED_BEFORE_SUBMISSION",
			"Metadata field %s is HTTPS or explicitly pending." % field
		)
	_check(
		str(metadata.get("version", "")) == "0.1.0"
		and str(metadata.get("copyright", "")) == "2026 Chase Dafnis"
		and str(metadata.get("pricing", "")) == "free"
		and str(metadata.get("storefronts", ""))
		== "all_except_china_mainland"
		and str(metadata.get("eu_dsa_status", "")) == "non-trader",
		"Owner-supplied listing choices remain exact and placeholder-free."
	)
	_check(
		str(metadata.get("support_url", ""))
		== "https://chdafni-msft.github.io/FrogCityFeast/support/"
		and str(metadata.get("privacy_policy_url", ""))
		== "https://chdafni-msft.github.io/FrogCityFeast/privacy/",
		"Public support and privacy URLs remain canonical."
	)


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
		print("Public App Store pipeline checks passed.")
		quit(0)
	else:
		print(
			"Public App Store pipeline checks failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
