extends SceneTree

const STATES := preload("res://tools/app_store_screenshot_states.gd")
const MANIFEST_PATH := "res://tools/app-store-screenshot-manifest.json"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var specs := STATES.screenshot_specs()
	_check(specs.size() == 7, "The final package contains seven screenshots.")
	_check_manifest(specs)

	for spec in specs:
		paused = false
		var state_id := str(spec["id"])
		var game := STATES.instantiate_game(state_id)
		_check(
			is_instance_valid(game),
			"State '%s' instantiates a configured game." % state_id
		)
		if not is_instance_valid(game):
			continue
		root.add_child(game)
		_check(
			STATES.author_state(game, state_id),
			"State '%s' authors successfully." % state_id
		)
		await process_frame
		_check_common_release_presentation(game, state_id)
		_check_state(game, state_id)
		paused = false
		game._belly.clear()
		game.queue_free()
		await process_frame
		AudioDirector.reset_for_tests()
		await process_frame

	await _finish()


func _check_manifest(specs: Array[Dictionary]) -> void:
	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest_value: Variant = JSON.parse_string(manifest_text)
	_check(manifest_value is Dictionary, "Screenshot manifest is valid JSON.")
	if not manifest_value is Dictionary:
		return
	var manifest := manifest_value as Dictionary
	var target := manifest.get("target", {}) as Dictionary
	_check(
		int(target.get("width", 0)) == 2752
		and int(target.get("height", 0)) == 2064,
		"Manifest pins the 13-inch iPad landscape dimensions."
	)
	_check(
		str(target.get("format", "")) == "PNG"
		and str(target.get("colorMode", "")) == "RGB"
		and not bool(target.get("transparent", true)),
		"Manifest requires opaque RGB PNG output."
	)
	var manifest_screenshots := manifest.get("screenshots", []) as Array
	_check(
		manifest_screenshots.size() == specs.size(),
		"Manifest and authored screenshot state counts match."
	)
	for index in mini(manifest_screenshots.size(), specs.size()):
		var manifest_entry := manifest_screenshots[index] as Dictionary
		_check(
			str(manifest_entry.get("id", "")) == str(specs[index]["id"])
			and str(manifest_entry.get("filename", ""))
				== str(specs[index]["filename"]),
			"Manifest entry %d matches its authored state." % (index + 1)
		)


func _check_common_release_presentation(
	game: FrogGame,
	state_id: String
) -> void:
	_check(
		game._display_name == "Sam",
		"State '%s' uses the safe demo name Sam." % state_id
	)
	_check(
		not is_instance_valid(game._performance_instrumentation),
		"State '%s' has no performance overlay." % state_id
	)
	_check(
		not game._tutorial_panel.visible
		and not game._discovery_banner.visible
		and game._save_warning_message.is_empty(),
		"State '%s' has no tutorial, transient banner, or save warning."
		% state_id
	)


func _check_state(game: FrogGame, state_id: String) -> void:
	match state_id:
		STATES.STATE_CITY_OVERVIEW:
			_check(
				game._growth_tier == 1
				and not game._belly_overlay.visible
				and game._status_label.text.contains("River Park"),
				"City overview shows a progressed outdoor release state."
			)
		STATES.STATE_TONGUE_CATCH:
			_check(
				game._tongue.points.size() >= 2
				and game._struggle_panel.visible
				and game._struggle_title.text.contains("96%")
				and game._struggle_hint.text.contains("text"),
				"Tongue catch includes the tongue and non-color feedback."
			)
		STATES.STATE_ENORMOUS_PURSUIT:
			_check(
				game._growth_tier == GameplayTuning.ENORMOUS_TIER
				and is_instance_valid(game._pursuer)
				and is_instance_valid(game._roadblock)
				and is_instance_valid(game._pursuit_trap),
				"Enormous pursuit includes the frog, pursuer, barrier, and trap."
			)
		STATES.STATE_WEATHER_FESTIVAL:
			_check(
				game._active_interior_id.is_empty()
				and game._current_kite_festival_intensity >= 0.99
				and game._city_activity.visible_kite_festival_count() > 0
				and game._status_label.text.contains("Kite Festival"),
				"Festival view uses the deterministic peak kite activity."
			)
		STATES.STATE_BELLY:
			_check(
				game._belly_overlay.visible
				and game._belly.size() == 4
				and game._belly_list.get_child_count() == 4,
				"Belly view contains four authored release items."
			)
		STATES.STATE_GUIDE_JOURNAL:
			var guide_text := ""
			if game._guide_list.get_child_count() > 0:
				guide_text = str(game._guide_list.get_child(0).text)
			_check(
				game._guide_overlay.visible
				and game._guide_progress.text.contains("49 / 49")
				and guide_text.contains("POSTCARD")
				and guide_text.contains("[STAMPED]"),
				"Guide view shows complete progress and stamped journal pages."
			)
		STATES.STATE_ACCESSIBILITY_OPTIONS:
			_check(
				game._options_overlay.visible
				and game._reduce_motion_toggle.button_pressed
				and game._larger_ui_toggle.button_pressed
				and game._camera_auto_align_toggle.button_pressed
				and game._haptics_toggle.button_pressed
				and game._left_handed_toggle.button_pressed
				and game._input_assist_option.get_item_text(
					game._input_assist_option.selected
				).contains("Relaxed"),
				"Options view demonstrates every requested accessibility area."
			)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("App Store screenshot smoke tests passed.")
		quit(0)
		return
	push_error(
		"App Store screenshot smoke tests failed: %s"
		% ", ".join(_failures)
	)
	quit(1)
