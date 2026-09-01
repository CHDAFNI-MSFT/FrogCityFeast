class_name MenuBackdrop
extends Control

const ART := preload("res://src/production_art.gd")

var _motion_scale := 1.0
var _animation_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _motion_scale <= 0.0:
		return
	_animation_time = fmod(_animation_time + delta, TAU * 8.0)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func set_motion_scale(value: float) -> void:
	_motion_scale = clampf(value, 0.0, 1.0)
	set_process(_motion_scale > 0.0)
	queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	var horizon := height * 0.56
	var drift := sin(_animation_time * 0.7) * 5.0 * _motion_scale
	draw_rect(Rect2(Vector2.ZERO, size), ART.NIGHT_NAVY)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2.ZERO,
			Vector2(width, 0),
			Vector2(width, horizon + 35),
			Vector2(0, horizon - 20),
		]),
		ART.NIGHT_VIOLET
	)
	draw_circle(
		Vector2(width * 0.79 + drift, height * 0.19),
		height * 0.078,
		Color(ART.MAGIC_AMBER, 0.72)
	)
	for index in 13:
		var building_width := width * (0.045 + float(index % 3) * 0.009)
		var building_height := height * (0.12 + float((index * 5) % 7) * 0.025)
		var x := width * 0.02 + float(index) * width * 0.078
		var rect := Rect2(
			x,
			horizon - building_height,
			building_width,
			building_height
		)
		var paper_color := (
			ART.CITY_CORAL.darkened(0.38)
			if index % 2 == 0
			else ART.CITY_GOLD.darkened(0.48)
		)
		draw_rect(
			Rect2(rect.position + Vector2(7, 7), rect.size),
			Color(ART.INK, 0.28)
		)
		draw_rect(rect, paper_color)
		draw_line(
			Vector2(rect.position.x, rect.position.y),
			Vector2(rect.end.x, rect.position.y),
			paper_color.lightened(0.18),
			4.0
		)
		for window_index in 3:
			draw_rect(
				Rect2(
					x + 10.0 + float(window_index) * 16.0,
					rect.position.y + 18.0,
					7.0,
					10.0
				),
				Color(ART.MAGIC_AMBER, 0.42)
			)
	draw_rect(
		Rect2(0, horizon, width, height - horizon),
		ART.PARK_TEAL.darkened(0.28)
	)
	draw_rect(
		Rect2(0, height * 0.79, width, height * 0.21),
		ART.CANAL_TEAL.darkened(0.35)
	)
	for stripe in 9:
		var stripe_y := height * 0.81 + float(stripe) * height * 0.022
		draw_line(
			Vector2(0, stripe_y),
			Vector2(width, stripe_y + drift * 0.18),
			Color(ART.CREAM, 0.08),
			3.0
		)
	for index in 7:
		var lily_position := Vector2(
			width * (0.08 + float(index) * 0.145),
			height * (0.84 + float(index % 2) * 0.07)
			+ sin(_animation_time + float(index)) * 3.0 * _motion_scale
		)
		draw_circle(lily_position + Vector2(4, 4), 28.0, Color(ART.INK, 0.18))
		draw_circle(lily_position, 28.0, Color(ART.FROG_DARK, 0.82))
		draw_colored_polygon(
			PackedVector2Array([
				lily_position,
				lily_position + Vector2(30, -8),
				lily_position + Vector2(27, 10),
			]),
			ART.CANAL_TEAL.darkened(0.35)
		)
	var frog_position := Vector2(width * 0.14, height * 0.72)
	var frog_bob := sin(_animation_time * 1.8) * 4.0 * _motion_scale
	draw_texture_rect(
		ART.FROG_TEXTURE,
		Rect2(
			frog_position + Vector2(-76, -76 + frog_bob),
			Vector2(152, 152)
		),
		false,
		Color(1.0, 1.0, 1.0, 0.68)
	)
