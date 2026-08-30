class_name AudioPreferences
extends RefCounted

const DEFAULT_MASTER := 0.8
const DEFAULT_MUSIC := 0.45
const DEFAULT_EFFECTS := 0.8


static func defaults() -> Dictionary:
	return {
		"master": DEFAULT_MASTER,
		"music": DEFAULT_MUSIC,
		"effects": DEFAULT_EFFECTS,
	}


static func sanitize_preferences(value: Variant) -> Dictionary:
	var preferences := defaults()
	if value is not Dictionary:
		return preferences
	var stored := value as Dictionary
	for key in preferences:
		var candidate: Variant = stored.get(key)
		if candidate is int or candidate is float:
			var volume := float(candidate)
			if is_finite(volume):
				preferences[key] = clampf(volume, 0.0, 1.0)
	return preferences


static func volume_to_db(value: float) -> float:
	var volume := clampf(value, 0.0, 1.0)
	if volume <= 0.0:
		return -80.0
	return 20.0 * log(volume) / log(10.0)
