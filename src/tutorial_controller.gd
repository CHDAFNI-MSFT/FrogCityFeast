class_name TutorialController
extends RefCounted

signal step_changed(
	step_index: int,
	step_count: int,
	title: String,
	instruction: String,
	target_id: String,
	show_marker: bool
)
signal completed(skipped: bool)

enum Step {
	MOVE,
	EAT_DONUT,
	DIGEST_DONUT,
	ROTATE_CAMERA,
	EAT_HOTDOG,
	DIGEST_HOTDOG,
	EAT_SIGN,
	DIGEST_SIGN,
	WAIT_FOR_GROWTH,
	EAT_DOOR,
}

const STEP_COUNT := 10

var active := false
var step := Step.MOVE
var marker_position := Vector2.ZERO
var _camera_rotation_total := 0.0


func start(move_marker_position: Vector2) -> void:
	active = true
	step = Step.MOVE
	marker_position = move_marker_position
	_camera_rotation_total = 0.0
	_emit_step()


func skip() -> void:
	if not active:
		return
	active = false
	completed.emit(true)


func allows_world_move(destination: Vector2) -> bool:
	if not active:
		return true
	if step == Step.MOVE:
		return destination.distance_to(marker_position) <= 75.0
	return step != Step.DIGEST_DONUT and step != Step.DIGEST_HOTDOG and step != Step.DIGEST_SIGN


func allows_camera_rotation() -> bool:
	return not active or step >= Step.ROTATE_CAMERA


func allows_tongue_target(target_id: String) -> bool:
	if not active:
		return true
	return not target_id.is_empty() and target_id == expected_target_id()


func allows_belly_open() -> bool:
	return (
		not active
		or step == Step.DIGEST_DONUT
		or step == Step.DIGEST_HOTDOG
		or step == Step.DIGEST_SIGN
	)


func allows_digest(target_id: String) -> bool:
	if not active:
		return true
	return target_id == expected_digest_id()


func allows_spit() -> bool:
	return not active


func suppresses_struggle_failure(target_id: String) -> bool:
	return active and target_id == expected_target_id()


func on_move_reached(world_position: Vector2) -> void:
	if active and step == Step.MOVE and world_position.distance_to(marker_position) <= 24.0:
		_advance()


func on_camera_rotated(radians: float) -> void:
	if not active or step != Step.ROTATE_CAMERA:
		return
	_camera_rotation_total += absf(radians)
	if _camera_rotation_total >= 0.25:
		_advance()


func on_target_swallowed(target_id: String) -> void:
	if not active or target_id != expected_target_id():
		return
	match step:
		Step.EAT_DONUT:
			_set_step(Step.DIGEST_DONUT)
		Step.EAT_HOTDOG:
			_set_step(Step.DIGEST_HOTDOG)
		Step.EAT_SIGN:
			_set_step(Step.DIGEST_SIGN)
		Step.EAT_DOOR:
			active = false
			completed.emit(false)


func on_item_digested(target_id: String) -> void:
	if not active or target_id != expected_digest_id():
		return
	match step:
		Step.DIGEST_DONUT:
			_set_step(Step.ROTATE_CAMERA)
		Step.DIGEST_HOTDOG:
			_set_step(Step.EAT_SIGN)
		Step.DIGEST_SIGN:
			_set_step(Step.WAIT_FOR_GROWTH)


func on_growth_tier_applied(tier: int) -> void:
	if active and step == Step.WAIT_FOR_GROWTH and tier >= 1:
		_set_step(Step.EAT_DOOR)


func expected_target_id() -> String:
	match step:
		Step.EAT_DONUT:
			return "street_donut"
		Step.EAT_HOTDOG:
			return "running_hotdog"
		Step.EAT_SIGN:
			return "moonlight_market_sign"
		Step.EAT_DOOR:
			return "moonlight_market_door"
	return ""


func expected_digest_id() -> String:
	match step:
		Step.DIGEST_DONUT:
			return "street_donut"
		Step.DIGEST_HOTDOG:
			return "running_hotdog"
		Step.DIGEST_SIGN:
			return "moonlight_market_sign"
	return ""


func current_instruction() -> String:
	return _step_instruction()


func _advance() -> void:
	_set_step(step + 1)


func _set_step(next_step: Step) -> void:
	step = next_step
	_emit_step()


func _emit_step() -> void:
	step_changed.emit(
		step,
		STEP_COUNT,
		_step_title(),
		_step_instruction(),
		expected_target_id(),
		step == Step.MOVE or step == Step.WAIT_FOR_GROWTH
	)


func _step_title() -> String:
	match step:
		Step.MOVE:
			return "Move the frog"
		Step.EAT_DONUT:
			return "Aim the tongue"
		Step.DIGEST_DONUT:
			return "Digest for points"
		Step.ROTATE_CAMERA:
			return "Turn the camera"
		Step.EAT_HOTDOG:
			return "Catch a moving target"
		Step.DIGEST_HOTDOG:
			return "Digest the hot dog"
		Step.EAT_SIGN:
			return "Start eating the city"
		Step.DIGEST_SIGN:
			return "Grow larger"
		Step.WAIT_FOR_GROWTH:
			return "Make room to grow"
		Step.EAT_DOOR:
			return "Open the market"
	return "Tutorial"


func _step_instruction() -> String:
	match step:
		Step.MOVE:
			return "Tap the glowing circle and wait for the frog to reach it."
		Step.EAT_DONUT:
			return "Double-tap the highlighted Street Donut. Aim near its center."
		Step.DIGEST_DONUT:
			return "Open Belly, then tap Digest beside the Street Donut."
		Step.ROTATE_CAMERA:
			return "Hold one finger and drag a second finger sideways. On PC, right-drag."
		Step.EAT_HOTDOG:
			return "Double-tap the highlighted Hot Dog, then tap rapidly to win the struggle."
		Step.DIGEST_HOTDOG:
			return "Open Belly and digest the Runaway Hot Dog."
		Step.EAT_SIGN:
			return "Double-tap the highlighted Market Sign."
		Step.DIGEST_SIGN:
			return "Open Belly and digest the Market Sign to become larger."
		Step.WAIT_FOR_GROWTH:
			return "Move toward the glowing circle so the frog has room to grow."
		Step.EAT_DOOR:
			return "Double-tap the Market Door, then tap rapidly to pull it free."
	return ""
