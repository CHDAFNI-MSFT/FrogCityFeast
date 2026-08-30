class_name SessionChallenges
extends RefCounted

signal challenge_completed(challenge_id: String)

const SHARP_AIM := "sharp_aim"
const HOLD_ON := "hold_on"
const CITY_TOUR := "city_tour"
const SHARP_AIM_ACCURACY := 0.9
const DEFINITIONS := [
	{
		"id": SHARP_AIM,
		"label": "90%+ Hits",
		"goal": 3,
	},
	{
		"id": HOLD_ON,
		"label": "Struggle Wins",
		"goal": 2,
	},
	{
		"id": CITY_TOUR,
		"label": "Target Types",
		"goal": 4,
	},
]

var active := false
var _progress: Dictionary = {}
var _completed: Dictionary = {}
var _distinct_targets: Dictionary = {}


func _init() -> void:
	_reset()


func begin() -> void:
	_reset()
	active = true


func record_swallow(target_id: String, accuracy: float) -> void:
	if not active:
		return
	var normalized_id := target_id.strip_edges()
	if normalized_id.is_empty():
		return
	if accuracy >= SHARP_AIM_ACCURACY:
		_advance(SHARP_AIM)
	if not _distinct_targets.has(normalized_id):
		_distinct_targets[normalized_id] = true
		_set_progress(CITY_TOUR, _distinct_targets.size())


func record_struggle_win() -> void:
	if active:
		_advance(HOLD_ON)


func progress(challenge_id: String) -> int:
	return int(_progress.get(challenge_id, 0))


func goal(challenge_id: String) -> int:
	var definition := definition_for(challenge_id)
	return int(definition.get("goal", 0))


func is_complete(challenge_id: String) -> bool:
	return bool(_completed.get(challenge_id, false))


func completed_count() -> int:
	return _completed.size()


static func definition_for(challenge_id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if str(definition["id"]) == challenge_id:
			return (definition as Dictionary).duplicate(true)
	return {}


func _reset() -> void:
	active = false
	_progress.clear()
	_completed.clear()
	_distinct_targets.clear()
	for definition in DEFINITIONS:
		_progress[str(definition["id"])] = 0


func _advance(challenge_id: String) -> void:
	_set_progress(challenge_id, progress(challenge_id) + 1)


func _set_progress(challenge_id: String, amount: int) -> void:
	var challenge_goal := goal(challenge_id)
	if challenge_goal <= 0:
		return
	_progress[challenge_id] = mini(amount, challenge_goal)
	if (
		int(_progress[challenge_id]) >= challenge_goal
		and not _completed.has(challenge_id)
	):
		_completed[challenge_id] = true
		challenge_completed.emit(challenge_id)
