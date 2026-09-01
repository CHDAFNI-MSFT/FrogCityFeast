class_name TutorialCardArt
extends Control

const ART := preload("res://src/production_art.gd")

var _step_index := 0
var _motion_scale := 1.0
var _animation_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _motion_scale <= 0.0:
		return
	_animation_time = fmod(_animation_time + delta, TAU * 4.0)
	queue_redraw()


func set_step(step_index: int) -> void:
	_step_index = maxi(0, step_index)
	queue_redraw()


func set_motion_scale(value: float) -> void:
	_motion_scale = clampf(value, 0.0, 1.0)
	set_process(_motion_scale > 0.0)
	queue_redraw()


func _draw() -> void:
	var card_rect := Rect2(Vector2.ZERO, size)
	draw_rect(card_rect, Color(ART.CREAM, 0.08))
	draw_line(
		Vector2(0, size.y - 3),
		Vector2(size.x, size.y - 3),
		Color(ART.MAGIC_AMBER, 0.72),
		3.0
	)
	var bob := sin(_animation_time * 2.0) * 2.0 * _motion_scale
	draw_texture_rect(
		ART.FROG_TEXTURE,
		Rect2(Vector2(12, 4 + bob), Vector2(72, 72)),
		false
	)
	var cue_center := Vector2(size.x - 52, size.y * 0.5)
	var cue_colors: Array[Color] = [
		ART.FOCUS_MINT,
		ART.CITY_CORAL,
		ART.MAGIC_AMBER,
		ART.CANAL_TEAL,
	]
	var cue_color: Color = cue_colors[_step_index % cue_colors.size()]
	match _step_index:
		TutorialController.Step.MOVE:
			draw_circle(cue_center, 22.0, Color(cue_color, 0.28))
			draw_arc(cue_center, 25.0, 0.0, TAU, 24, cue_color, 5.0)
			draw_line(
				cue_center + Vector2(-8, 0),
				cue_center + Vector2(8, 0),
				ART.CREAM,
				4.0
			)
		TutorialController.Step.ROTATE_CAMERA:
			draw_arc(
				cue_center,
				24.0,
				-2.5,
				1.4,
				24,
				cue_color,
				6.0
			)
			draw_colored_polygon(
				PackedVector2Array([
					cue_center + Vector2(20, -17),
					cue_center + Vector2(31, -14),
					cue_center + Vector2(24, -5),
				]),
				cue_color
			)
		_:
			draw_circle(cue_center, 24.0, Color(cue_color, 0.32))
			draw_line(
				cue_center + Vector2(-22, 14),
				cue_center + Vector2(18, -12),
				ART.CITY_CORAL,
				7.0,
				true
			)
			draw_circle(cue_center + Vector2(20, -13), 8.0, ART.CREAM)
