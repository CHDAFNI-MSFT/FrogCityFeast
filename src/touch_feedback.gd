class_name TouchFeedback
extends Control

const DURATION := 0.42

var motion_scale := 1.0
var _feedback: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_motion_scale(value: float) -> void:
	motion_scale = clampf(value, 0.0, 1.0)
	for kind in _feedback:
		var item := _feedback[kind] as Dictionary
		item["motion_scale"] = motion_scale
		_feedback[kind] = item
	queue_redraw()


func show_move(world_position: Vector2) -> void:
	_show("move", Vector2.ZERO, world_position)


func show_tongue(screen_position: Vector2) -> void:
	_show("tongue", screen_position, Vector2.ZERO)


func show_camera(screen_position: Vector2) -> void:
	_show("camera", screen_position, Vector2.ZERO)


func active_feedback_count() -> int:
	return _feedback.size()


func feedback_snapshot(kind: String) -> Dictionary:
	return (_feedback.get(kind, {}) as Dictionary).duplicate(true)


func _show(
	kind: String,
	screen_position: Vector2,
	world_position: Vector2
) -> void:
	_feedback[kind] = {
		"age": 0.0,
		"screen_position": screen_position,
		"world_position": world_position,
		"motion_scale": motion_scale,
	}
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for kind in _feedback.keys():
		var item := _feedback[kind] as Dictionary
		item["age"] = float(item["age"]) + delta
		if float(item["age"]) >= DURATION:
			_feedback.erase(kind)
		else:
			_feedback[kind] = item
	if _feedback.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for kind in _feedback:
		var item := _feedback[kind] as Dictionary
		var progress := clampf(float(item["age"]) / DURATION, 0.0, 1.0)
		var alpha := 1.0 - progress
		var item_motion_scale := float(item["motion_scale"])
		var position := item["screen_position"] as Vector2
		if str(kind) == "move":
			position = (
				get_viewport().get_canvas_transform()
				* (item["world_position"] as Vector2)
			)
		match str(kind):
			"move":
				_draw_move(position, progress, alpha, item_motion_scale)
			"tongue":
				_draw_tongue(position, progress, alpha, item_motion_scale)
			"camera":
				_draw_camera(position, progress, alpha, item_motion_scale)


func _draw_move(
	position: Vector2,
	progress: float,
	alpha: float,
	item_motion_scale: float
) -> void:
	var radius := 20.0 + progress * 18.0 * item_motion_scale
	var color := Color(0.42, 1.0, 0.56, alpha)
	draw_arc(position, radius, 0.0, TAU, 28, color, 5.0)
	draw_circle(position, 5.0, Color(0.82, 1.0, 0.86, alpha))


func _draw_tongue(
	position: Vector2,
	progress: float,
	alpha: float,
	item_motion_scale: float
) -> void:
	var radius := 23.0 + progress * 11.0 * item_motion_scale
	var color := Color(1.0, 0.48, 0.68, alpha)
	draw_arc(position, radius, 0.0, TAU, 28, color, 4.0)
	draw_line(
		position + Vector2(-radius - 9.0, 0),
		position + Vector2(-radius + 5.0, 0),
		color,
		4.0
	)
	draw_line(
		position + Vector2(radius - 5.0, 0),
		position + Vector2(radius + 9.0, 0),
		color,
		4.0
	)
	draw_line(
		position + Vector2(0, -radius - 9.0),
		position + Vector2(0, -radius + 5.0),
		color,
		4.0
	)
	draw_line(
		position + Vector2(0, radius - 5.0),
		position + Vector2(0, radius + 9.0),
		color,
		4.0
	)


func _draw_camera(
	position: Vector2,
	progress: float,
	alpha: float,
	item_motion_scale: float
) -> void:
	var spread := 32.0 + progress * 12.0 * item_motion_scale
	var color := Color(0.48, 0.86, 1.0, alpha)
	draw_line(
		position + Vector2(-spread, 0),
		position + Vector2(spread, 0),
		color,
		5.0
	)
	draw_colored_polygon(
		PackedVector2Array([
			position + Vector2(-spread - 12.0, 0),
			position + Vector2(-spread, -9.0),
			position + Vector2(-spread, 9.0),
		]),
		color
	)
	draw_colored_polygon(
		PackedVector2Array([
			position + Vector2(spread + 12.0, 0),
			position + Vector2(spread, -9.0),
			position + Vector2(spread, 9.0),
		]),
		color
	)
