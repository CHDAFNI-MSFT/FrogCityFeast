extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://progression_smoke.cfg"
	_remove_save_and_backups(save_path)

	var version_one := ConfigFile.new()
	version_one.set_value("meta", "version", 1)
	version_one.set_value("profiles", "frog_one", "Frog One")
	version_one.set_value("profiles", "frog_two", "Frog Two")
	version_one.set_value("scores", "frog_one", 777)
	version_one.set_value("scores", "frog_two", 123)
	version_one.set_value("device", "best_score", 777)
	version_one.set_value("tutorial", "frog_one", true)
	version_one.set_value(
		"discoveries",
		"frog_one",
		PackedStringArray(["street_donut"])
	)
	version_one.set_value(
		"accessibility",
		"frog_one",
		{
			"reduce_motion": true,
			"larger_text_controls": false,
		}
	)
	version_one.set_value(
		"audio",
		"frog_one",
		{
			"master": 0.7,
			"music": 0.4,
			"effects": 0.6,
		}
	)
	_check(version_one.save(save_path) == OK, "Version 1 fixture saves.")

	var store := ProfileStore.new(save_path)
	_check(
		ProfileStore.SAVE_VERSION == 3
		and int(store._config.get_value("meta", "version", 0)) == 3,
		"Version 1 saves migrate through version 3."
	)
	_check(
		store.get_profile_best("frog_one") == 777
		and store.get_profile_best("frog_two") == 123
		and store.get_device_best() == 777
		and store.is_tutorial_complete("frog_one")
		and store.get_discoveries("frog_one")
			== PackedStringArray(["street_donut"])
		and store.get_accessibility_preferences("frog_one") == {
			"reduce_motion": true,
			"larger_text_controls": false,
			"input_assist_mode": "standard",
			"camera_sensitivity": 1.0,
			"camera_auto_align": false,
			"haptics_enabled": false,
			"left_handed_hud": false,
		}
		and store.get_audio_preferences("frog_one") == {
			"master": 0.7,
			"music": 0.4,
			"effects": 0.6,
		},
		"Migration preserves every version 1 profile and device field."
	)
	_check(
		store.get_profile_achievements("frog_one").is_empty()
		and store.get_device_achievements().is_empty()
		and store.get_story_clues("frog_one").is_empty()
		and store.get_power_discoveries("frog_one").is_empty()
		and store.get_secret_unlocks("frog_one").is_empty(),
		"New progression fields default safely during migration."
	)
	_check(
		_find_backup(save_path, "migration-v1-to-v2"),
		"Migration preserves the original version 1 save as a backup."
	)

	_check(
		store.mark_profile_achievement("frog_one", "growth_spurt")
		and not store.mark_profile_achievement("frog_one", "growth_spurt")
		and not store.mark_profile_achievement("frog_one", "unknown"),
		"Profile achievements accept known IDs exactly once."
	)
	_check(
		store.mark_profile_achievement(
			"frog_two",
			"event_moonlight_bazaar",
			"moonlit_receipt"
		)
		and not store.mark_profile_achievement(
			"frog_two",
			"event_moonlight_bazaar",
			"moonlit_receipt"
		)
		and store.get_story_clues("frog_two")
			== PackedStringArray(["moonlit_receipt"]),
		"Mapped profile achievements and clues persist atomically."
	)
	_check(
		store.mark_device_achievement("device_secret_found")
		and not store.mark_device_achievement("device_secret_found")
		and not store.mark_device_achievement("unknown"),
		"Device achievements accept known IDs exactly once."
	)
	_check(
		store.mark_story_clue("frog_one", "golden_crumb")
		and not store.mark_story_clue("frog_one", "golden_crumb")
		and store.mark_power_discovered("frog_one", "flight")
		and not store.mark_power_discovered("frog_one", "flight")
		and store.mark_secret_unlocked(
			"frog_one",
			ProgressionCatalog.SECRET_FANTASY_DISTRICT
		)
		and not store.mark_secret_unlocked(
			"frog_one",
			ProgressionCatalog.SECRET_FANTASY_DISTRICT
		),
		"Clues, power discoveries, and secret unlocks are idempotent."
	)
	_check(
		not store.mark_story_clue("missing_profile", "golden_crumb"),
		"Profile progression cannot be written for an unknown profile."
	)

	var reloaded := ProfileStore.new(save_path)
	_check(
		reloaded.get_profile_achievements("frog_one")
			== PackedStringArray(["growth_spurt"])
		and reloaded.get_profile_achievements("frog_two")
			== PackedStringArray(["event_moonlight_bazaar"])
		and reloaded.get_device_achievements()
			== PackedStringArray(["device_secret_found"])
		and reloaded.get_story_clues("frog_one")
			== PackedStringArray(["golden_crumb"])
		and reloaded.get_story_clues("frog_two")
			== PackedStringArray(["moonlit_receipt"])
		and reloaded.get_power_discoveries("frog_one")
			== PackedStringArray(["flight"])
		and reloaded.get_secret_unlocks("frog_one")
			== PackedStringArray([
				ProgressionCatalog.SECRET_FANTASY_DISTRICT,
			]),
		"Version 3 progression survives reload with profile and device scope intact."
	)

	var version_two_path := "user://progression_smoke_v2.cfg"
	_remove_save_and_backups(version_two_path)
	var version_two := ConfigFile.new()
	version_two.set_value("meta", "version", 2)
	version_two.set_value("profiles", "frog_three", "Frog Three")
	version_two.set_value("scores", "frog_three", 456)
	version_two.set_value(
		"accessibility",
		"frog_three",
		{
			"reduce_motion": false,
			"larger_text_controls": true,
		}
	)
	_check(version_two.save(version_two_path) == OK, "Version 2 fixture saves.")
	var version_two_store := ProfileStore.new(version_two_path)
	_check(
		int(version_two_store._config.get_value("meta", "version", 0)) == 3
		and version_two_store.get_profile_best("frog_three") == 456
		and version_two_store.get_accessibility_preferences("frog_three") == {
			"reduce_motion": false,
			"larger_text_controls": true,
			"input_assist_mode": "standard",
			"camera_sensitivity": 1.0,
			"camera_auto_align": false,
			"haptics_enabled": false,
			"left_handed_hud": false,
		}
		and _find_backup(version_two_path, "migration-v2-to-v3"),
		"Version 2 migration preserves progress and seeds safe accessibility defaults."
	)
	_remove_save_and_backups(version_two_path)

	var reconciled_discoveries := PackedStringArray()
	for discovery_id in ProgressionCatalog.generated_archetype_discovery_ids():
		reconciled_discoveries.append(discovery_id)
	for discovery_id in [
		"river_hidden_pump_handle",
		"oddities_cellar_music_box",
		"construction_crane_toolbox",
		"leap_cafe_building",
		"golden_cake",
		"street_donut",
		"market_apple",
	]:
		reconciled_discoveries.append(discovery_id)
	reloaded._config.set_value("device", "best_score", 2500)
	reloaded._config.set_value(
		"discoveries",
		"frog_two",
		reconciled_discoveries
	)
	reloaded._config.set_value(
		"power_discoveries",
		"frog_two",
		ProgressionCatalog.power_ids()
	)
	reloaded._config.set_value(
		"profile_achievements",
		"frog_two",
		PackedStringArray([
			"building_banquet",
			"event_moonlight_bazaar",
			"event_kite_festival",
			"event_water_main",
			"event_wind_squall",
			"secret_finder",
		])
	)
	reloaded._save()

	var reconciled := ProfileStore.new(save_path)
	_check(
		reconciled.get_device_achievements().has("device_score_2500")
		and reconciled.get_device_achievements().has(
			"device_secret_found"
		)
		and reconciled.get_profile_achievements("frog_two").has(
			"city_gourmet"
		)
		and reconciled.get_profile_achievements("frog_two").has(
			"power_sampler"
		)
		and reconciled.get_profile_achievements("frog_two").has(
			"growth_spurt"
		)
		and reconciled.get_profile_achievements("frog_two").has(
			"building_banquet"
		)
		and reconciled.get_profile_achievements("frog_two").has(
			"event_explorer"
		)
		and reconciled.get_profile_achievements("frog_two").has(
			"clue_collector"
		)
		and reconciled.get_story_clues("frog_two").has("sewer_stamp")
		and reconciled.get_story_clues("frog_two").has("golden_crumb")
		and reconciled.get_story_clues("frog_two").has("giant_shadow")
		and reconciled.has_secret_unlocked(
			"frog_two",
			ProgressionCatalog.SECRET_FANTASY_DISTRICT
		),
		"Save loading repairs derived progression before the first menu."
	)

	_remove_save_and_backups(save_path)
	await _finish()


func _find_backup(save_path: String, reason: String) -> bool:
	var prefix := "%s.%s-" % [save_path.get_file(), reason]
	for file_name in DirAccess.get_files_at("user://"):
		if str(file_name).begins_with(prefix):
			return true
	return false


func _remove_save_and_backups(save_path: String) -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var prefix := "%s." % save_path.get_file()
	for file_name in DirAccess.get_files_at("user://"):
		if str(file_name).begins_with(prefix):
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path("user://%s" % file_name)
			)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Progression smoke tests passed.")
		quit(0)
	else:
		push_error(
			"Progression smoke tests failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
