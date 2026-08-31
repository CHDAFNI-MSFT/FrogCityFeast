class_name PrototypePursuitTrap
extends Node2D

signal removed(trap: PrototypePursuitTrap, triggered: bool)

const RADIUS := 46.0
const ARM_DELAY := 0.75
const LIFETIME := 12.0

var _age := 0.0
var _motion_scale := 1.0
var _removed := false


func _ready() -> void:
	z_index = 3
	queue_redraw()


func advance(delta: float) -> void:
	if _removed or delta <= 0.0:
		return
	var was_armed := is_armed()
	_age = minf(LIFETIME, _age + delta)
	if was_armed != is_armed() or _motion_scale > 0.0:
		queue_redraw()


func is_armed() -> bool:
	return _age >= ARM_DELAY


func expired() -> bool:
	return _age >= LIFETIME


func dismiss(triggered: bool) -> void:
	if _removed:
		return
	_removed = true
	removed.emit(self, triggered)
	queue_free()


func set_presentation_motion_scale(value: float) -> void:
	_motion_scale = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var armed := is_armed()
	var pulse := (
		2.0 + sin(_age * 7.0) * 2.0 * _motion_scale
		if armed
		else 0.0
	)
	var fill_color := (
		Color(0.86, 0.28, 0.22, 0.22)
		if armed
		else Color(0.95, 0.74, 0.28, 0.18)
	)
	var line_color := (
		Color("e45543")
		if armed
		else Color("f0bd4d")
	)
	draw_circle(Vector2.ZERO, RADIUS + pulse, fill_color)
	draw_arc(
		Vector2.ZERO,
		RADIUS + pulse,
		0.0,
		TAU,
		32,
		line_color,
		5.0
	)
	draw_line(
		Vector2(-28, -28),
		Vector2(28, 28),
		line_color,
		5.0
	)
	draw_line(
		Vector2(28, -28),
		Vector2(-28, 28),
		line_color,
		5.0
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-80, -RADIUS - 18),
		"SNARE" if armed else "ARMING",
		HORIZONTAL_ALIGNMENT_CENTER,
		160,
		16,
		Color("fff3cf")
	)
