class_name TutorialMarker
extends Node2D

var active := false:
	set(value):
		active = value
		visible = value
		set_process(active and motion_scale > 0.0)
		queue_redraw()

var motion_scale := 1.0


func _ready() -> void:
	visible = active
	z_index = 3
	set_process(active and motion_scale > 0.0)


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func set_motion_scale(value: float) -> void:
	motion_scale = clampf(value, 0.0, 1.0)
	set_process(active and motion_scale > 0.0)
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var pulse := (
		8.0
		+ sin(Time.get_ticks_msec() * 0.007) * 5.0 * motion_scale
	)
	draw_circle(Vector2.ZERO, 25.0, Color(0.25, 1.0, 0.5, 0.25))
	draw_arc(
		Vector2.ZERO,
		32.0 + pulse,
		0.0,
		TAU,
		36,
		Color(0.35, 1.0, 0.55, 0.95),
		7.0
	)
