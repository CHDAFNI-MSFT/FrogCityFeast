class_name AchievementModel
extends RefCounted

var _unlocked := {
	ProgressionCatalog.SCOPE_SESSION: {},
	ProgressionCatalog.SCOPE_PROFILE: {},
	ProgressionCatalog.SCOPE_DEVICE: {},
}


func configure(
	profile_achievement_ids: PackedStringArray = PackedStringArray(),
	device_achievement_ids: PackedStringArray = PackedStringArray()
) -> void:
	reset_session()
	_load_scope(
		ProgressionCatalog.SCOPE_PROFILE,
		profile_achievement_ids
	)
	_load_scope(
		ProgressionCatalog.SCOPE_DEVICE,
		device_achievement_ids
	)


func reset_session() -> void:
	_unlocked[ProgressionCatalog.SCOPE_SESSION] = {}


func unlock_session(goal_id: String) -> bool:
	return unlock(ProgressionCatalog.SCOPE_SESSION, goal_id)


func unlock_profile(achievement_id: String) -> bool:
	return unlock(ProgressionCatalog.SCOPE_PROFILE, achievement_id)


func unlock_device(achievement_id: String) -> bool:
	return unlock(ProgressionCatalog.SCOPE_DEVICE, achievement_id)


func unlock(scope: String, achievement_id: String) -> bool:
	var normalized_id := achievement_id.strip_edges()
	if normalized_id.is_empty() or _entry_for(scope, normalized_id).is_empty():
		return false
	var scope_state := _scope_state(scope)
	if scope_state.has(normalized_id):
		return false
	scope_state[normalized_id] = true
	return true


func is_unlocked(scope: String, achievement_id: String) -> bool:
	return _scope_state(scope).has(achievement_id)


func unlocked_count(scope: String) -> int:
	return unlocked_ids(scope).size()


func unlocked_ids(scope: String) -> PackedStringArray:
	var result := PackedStringArray()
	var scope_state := _scope_state(scope)
	for achievement_id in _ids_for_scope(scope):
		if scope_state.has(achievement_id):
			result.append(achievement_id)
	return result


func _load_scope(scope: String, achievement_ids: PackedStringArray) -> void:
	_unlocked[scope] = {}
	for achievement_id in achievement_ids:
		unlock(scope, str(achievement_id))


func _scope_state(scope: String) -> Dictionary:
	return _unlocked.get(scope, {}) as Dictionary


func _ids_for_scope(scope: String) -> PackedStringArray:
	match scope:
		ProgressionCatalog.SCOPE_SESSION:
			return ProgressionCatalog.session_goal_ids()
		ProgressionCatalog.SCOPE_PROFILE:
			return ProgressionCatalog.profile_achievement_ids()
		ProgressionCatalog.SCOPE_DEVICE:
			return ProgressionCatalog.device_achievement_ids()
	return PackedStringArray()


func _entry_for(scope: String, achievement_id: String) -> Dictionary:
	match scope:
		ProgressionCatalog.SCOPE_SESSION:
			return ProgressionCatalog.session_goal_entry(achievement_id)
		ProgressionCatalog.SCOPE_PROFILE:
			return ProgressionCatalog.profile_achievement_entry(achievement_id)
		ProgressionCatalog.SCOPE_DEVICE:
			return ProgressionCatalog.device_achievement_entry(achievement_id)
	return {}
