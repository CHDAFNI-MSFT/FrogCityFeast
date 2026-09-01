class_name ProfileStore
extends RefCounted

const SAVE_PATH := "user://frog_city_scores.cfg"
const SAVE_VERSION := 2
const DEFAULT_PROFILE_NAME := "Player 1"

var _config := ConfigFile.new()
var _save_path := SAVE_PATH
var _save_enabled := true
var _save_disabled_error_reported := false


func _init(save_path: String = SAVE_PATH) -> void:
	_save_path = save_path
	_load()
	if list_profiles().is_empty():
		ensure_profile(DEFAULT_PROFILE_NAME)


func list_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	if not _config.has_section("profiles"):
		return profiles

	for profile_id in _config.get_section_keys("profiles"):
		profiles.append({
			"id": profile_id,
			"name": str(_config.get_value("profiles", profile_id, DEFAULT_PROFILE_NAME)),
			"best": get_profile_best(profile_id),
		})
	profiles.sort_custom(_sort_profiles)
	return profiles


func ensure_profile(requested_name: String) -> String:
	var display_name := normalize_profile_name(requested_name)

	for profile in list_profiles():
		if str(profile["name"]).nocasecmp_to(display_name) == 0:
			return str(profile["id"])

	var normalized_name := display_name.to_lower()
	var profile_id := "player_%d" % abs(normalized_name.hash())
	var suffix := 2
	while _config.has_section_key("profiles", profile_id):
		profile_id = "player_%d_%d" % [abs(normalized_name.hash()), suffix]
		suffix += 1

	_config.set_value("profiles", profile_id, display_name)
	_config.set_value("scores", profile_id, 0)
	_save()
	return profile_id


func get_profile_name(profile_id: String) -> String:
	return str(_config.get_value("profiles", profile_id, DEFAULT_PROFILE_NAME))


func get_profile_best(profile_id: String) -> int:
	return int(_config.get_value("scores", profile_id, 0))


func get_device_best() -> int:
	return int(_config.get_value("device", "best_score", 0))


func get_profile_achievements(profile_id: String) -> PackedStringArray:
	return _stored_ids(
		"profile_achievements",
		profile_id,
		ProgressionCatalog.profile_achievement_ids()
	)


func get_device_achievements() -> PackedStringArray:
	return _stored_ids(
		"device_achievements",
		"unlocked",
		ProgressionCatalog.device_achievement_ids()
	)


func get_story_clues(profile_id: String) -> PackedStringArray:
	return _stored_ids(
		"story_clues",
		profile_id,
		ProgressionCatalog.story_clue_ids()
	)


func get_power_discoveries(profile_id: String) -> PackedStringArray:
	return _stored_ids(
		"power_discoveries",
		profile_id,
		ProgressionCatalog.power_ids()
	)


func get_secret_unlocks(profile_id: String) -> PackedStringArray:
	return _stored_ids(
		"secret_unlocks",
		profile_id,
		ProgressionCatalog.secret_unlock_ids()
	)


func mark_profile_achievement(
	profile_id: String,
	achievement_id: String
) -> bool:
	return _mark_profile_id(
		"profile_achievements",
		profile_id,
		achievement_id,
		ProgressionCatalog.profile_achievement_ids()
	)


func mark_device_achievement(achievement_id: String) -> bool:
	return _mark_id(
		"device_achievements",
		"unlocked",
		achievement_id,
		ProgressionCatalog.device_achievement_ids()
	)


func mark_story_clue(profile_id: String, clue_id: String) -> bool:
	return _mark_profile_id(
		"story_clues",
		profile_id,
		clue_id,
		ProgressionCatalog.story_clue_ids()
	)


func mark_power_discovered(profile_id: String, power_id: String) -> bool:
	return _mark_profile_id(
		"power_discoveries",
		profile_id,
		power_id,
		ProgressionCatalog.power_ids()
	)


func mark_secret_unlocked(profile_id: String, secret_id: String) -> bool:
	return _mark_profile_id(
		"secret_unlocks",
		profile_id,
		secret_id,
		ProgressionCatalog.secret_unlock_ids()
	)


func has_secret_unlocked(profile_id: String, secret_id: String) -> bool:
	return get_secret_unlocks(profile_id).has(secret_id)


func get_accessibility_preferences(profile_id: String) -> Dictionary:
	return AccessibilityPresentation.sanitize_preferences(
		_config.get_value("accessibility", profile_id, {})
	)


func get_audio_preferences(profile_id: String) -> Dictionary:
	return AudioPreferences.sanitize_preferences(
		_config.get_value("audio", profile_id, {})
	)


func set_accessibility_preferences(
	profile_id: String,
	reduce_motion: bool,
	larger_text_controls: bool
) -> void:
	if not _config.has_section_key("profiles", profile_id):
		push_warning("Cannot save accessibility preferences for an unknown profile.")
		return
	var preferences := {
		"reduce_motion": reduce_motion,
		"larger_text_controls": larger_text_controls,
	}
	if get_accessibility_preferences(profile_id) == preferences:
		return
	_config.set_value("accessibility", profile_id, preferences)
	_save()


func set_audio_preferences(
	profile_id: String,
	preferences: Dictionary
) -> void:
	if not _config.has_section_key("profiles", profile_id):
		push_warning("Cannot save audio preferences for an unknown profile.")
		return
	var sanitized := AudioPreferences.sanitize_preferences(preferences)
	if get_audio_preferences(profile_id) == sanitized:
		return
	_config.set_value("audio", profile_id, sanitized)
	_save()


func is_tutorial_complete(profile_id: String) -> bool:
	return bool(_config.get_value("tutorial", profile_id, false))


func mark_tutorial_complete(profile_id: String) -> void:
	if is_tutorial_complete(profile_id):
		return
	_config.set_value("tutorial", profile_id, true)
	_save()


func get_discoveries(profile_id: String) -> PackedStringArray:
	var stored: Variant = _config.get_value(
		"discoveries",
		profile_id,
		PackedStringArray()
	)
	var unique := {}
	if stored is PackedStringArray or stored is Array:
		for target_id in stored:
			var normalized_id := str(target_id).strip_edges()
			if (
				not normalized_id.is_empty()
				and not DiscoveryCatalog.entry_for(normalized_id).is_empty()
			):
				unique[normalized_id] = true
	var discoveries := PackedStringArray()
	for target_id in unique:
		discoveries.append(str(target_id))
	discoveries.sort()
	return discoveries


func mark_discovered(profile_id: String, target_id: String) -> bool:
	var normalized_id := target_id.strip_edges()
	if (
		normalized_id.is_empty()
		or DiscoveryCatalog.entry_for(normalized_id).is_empty()
	):
		return false
	var discoveries := get_discoveries(profile_id)
	if discoveries.has(normalized_id):
		return false
	discoveries.append(normalized_id)
	discoveries.sort()
	_config.set_value("discoveries", profile_id, discoveries)
	_save()
	return true


func get_discovery_count(profile_id: String) -> int:
	var known_ids := {}
	for target_id in DiscoveryCatalog.ids():
		known_ids[target_id] = true
	var total := 0
	for target_id in get_discoveries(profile_id):
		if known_ids.has(target_id):
			total += 1
	return total


func update_high_scores(profile_id: String, score: int) -> void:
	var changed := false
	if score > get_profile_best(profile_id):
		_config.set_value("scores", profile_id, score)
		changed = true
	if score > get_device_best():
		_config.set_value("device", "best_score", score)
		changed = true
	if changed:
		_save()


func _load() -> void:
	var error := _config.load(_save_path)
	if error == OK:
		var version := int(_config.get_value("meta", "version", 1))
		if version == SAVE_VERSION:
			return
		if version > 0 and version < SAVE_VERSION:
			if _migrate_to_current(version):
				return
			return
		push_warning("Unsupported frog score save version; starting with fresh scores.")
		_save_enabled = _backup_existing_save("unsupported")
	elif error != ERR_FILE_NOT_FOUND:
		push_warning("Could not read frog score save; starting with fresh scores.")
		_save_enabled = _backup_existing_save("unreadable")

	_initialize_fresh_save()


func _migrate_to_current(version: int) -> bool:
	var next_version := version
	while next_version < SAVE_VERSION:
		match next_version:
			1:
				if not _backup_existing_save("migration-v1-to-v2"):
					_save_enabled = false
					return false
				next_version = 2
				_config.set_value("meta", "version", next_version)
			_:
				push_warning(
					"Unsupported frog score save migration from version %d."
					% next_version
				)
				_save_enabled = false
				return false
	_save()
	return true


func _initialize_fresh_save() -> void:
	_config = ConfigFile.new()
	_config.set_value("meta", "version", SAVE_VERSION)
	_config.set_value("device", "best_score", 0)
	if _save_enabled:
		_save()


func _save() -> void:
	if not _save_enabled:
		if not _save_disabled_error_reported:
			push_error(
				"Frog score saving is disabled because the previous save could not be preserved."
			)
			_save_disabled_error_reported = true
		return
	var error := _config.save(_save_path)
	if error != OK:
		push_error("Could not save frog score data: error %d" % error)


func _backup_existing_save(reason: String) -> bool:
	if not FileAccess.file_exists(_save_path):
		return true
	var absolute_path := ProjectSettings.globalize_path(_save_path)
	var timestamp := int(Time.get_unix_time_from_system())
	var backup_path := "%s.%s-%d.bak" % [
		absolute_path,
		reason,
		timestamp,
	]
	var suffix := 2
	while FileAccess.file_exists(backup_path):
		backup_path = "%s.%s-%d-%d.bak" % [
			absolute_path,
			reason,
			timestamp,
			suffix,
		]
		suffix += 1
	var error := DirAccess.rename_absolute(absolute_path, backup_path)
	if error != OK:
		push_error(
			"Could not preserve the previous frog score save: error %d"
			% error
		)
		return false
	push_warning("Preserved the previous frog score save at %s." % backup_path)
	return true


func _mark_profile_id(
	section: String,
	profile_id: String,
	entry_id: String,
	allowed_ids: PackedStringArray
) -> bool:
	if not _config.has_section_key("profiles", profile_id):
		push_warning("Cannot save progression for an unknown profile.")
		return false
	return _mark_id(section, profile_id, entry_id, allowed_ids)


func _mark_id(
	section: String,
	key: String,
	entry_id: String,
	allowed_ids: PackedStringArray
) -> bool:
	var normalized_id := entry_id.strip_edges()
	if normalized_id.is_empty() or not allowed_ids.has(normalized_id):
		return false
	var stored := _stored_ids(section, key, allowed_ids)
	if stored.has(normalized_id):
		return false
	stored.append(normalized_id)
	stored.sort()
	_config.set_value(section, key, stored)
	_save()
	return true


func _stored_ids(
	section: String,
	key: String,
	allowed_ids: PackedStringArray
) -> PackedStringArray:
	var stored: Variant = _config.get_value(
		section,
		key,
		PackedStringArray()
	)
	var unique := {}
	if stored is PackedStringArray or stored is Array:
		for entry_id in stored:
			var normalized_id := str(entry_id).strip_edges()
			if (
				not normalized_id.is_empty()
				and allowed_ids.has(normalized_id)
			):
				unique[normalized_id] = true
	var result := PackedStringArray()
	for entry_id in unique:
		result.append(str(entry_id))
	result.sort()
	return result


func _sort_profiles(left: Dictionary, right: Dictionary) -> bool:
	return str(left["name"]).naturalnocasecmp_to(str(right["name"])) < 0


static func normalize_profile_name(requested_name: String) -> String:
	var display_name := requested_name.strip_edges()
	if display_name.is_empty():
		display_name = DEFAULT_PROFILE_NAME
	return display_name.left(24)
