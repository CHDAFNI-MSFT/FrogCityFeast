class_name TemporaryPowerState
extends RefCounted

const FLIGHT := "flight"
const SPEED_BURST := "speed_burst"
const LONG_TONGUE := "long_tongue"
const CAMOUFLAGE := "camouflage"
const BUBBLE_SHIELD := "bubble_shield"

var _remaining: Dictionary = {}


func activate(power_id: String, duration: float = -1.0) -> bool:
	var entry := ProgressionCatalog.power_entry(power_id)
	if entry.is_empty():
		return false
	var standard_duration := float(entry["duration"])
	var requested_duration := (
		standard_duration
		if duration < 0.0
		else maxf(0.0, duration)
	)
	var next_remaining := maxf(remaining(power_id), requested_duration)
	if next_remaining <= remaining(power_id):
		return false
	_remaining[power_id] = next_remaining
	return true


func advance(delta: float, paused: bool = false) -> PackedStringArray:
	var expired := PackedStringArray()
	if paused or delta <= 0.0:
		return expired
	for power_id_value in _remaining.keys():
		var power_id := str(power_id_value)
		var next_remaining := maxf(
			0.0,
			remaining(power_id) - delta
		)
		if next_remaining <= 0.0:
			_remaining.erase(power_id)
			expired.append(power_id)
		else:
			_remaining[power_id] = next_remaining
	expired.sort()
	return expired


func consume(power_id: String) -> bool:
	if not is_active(power_id):
		return false
	_remaining.erase(power_id)
	return true


func set_remaining(power_id: String, duration: float) -> bool:
	if ProgressionCatalog.power_entry(power_id).is_empty():
		return false
	var clamped_duration := maxf(0.0, duration)
	if clamped_duration <= 0.0:
		_remaining.erase(power_id)
	else:
		_remaining[power_id] = clamped_duration
	return true


func is_active(power_id: String) -> bool:
	return remaining(power_id) > 0.0


func remaining(power_id: String) -> float:
	return maxf(0.0, float(_remaining.get(power_id, 0.0)))


func active_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for entry in ProgressionCatalog.power_entries():
		var power_id := str(entry["id"])
		if is_active(power_id):
			result.append(power_id)
	return result


func clear() -> void:
	_remaining.clear()
