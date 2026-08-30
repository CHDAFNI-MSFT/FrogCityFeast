class_name MenuBackdrop
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var width := size.x
	var height := size.y
	var horizon := height * 0.58
	draw_circle(
		Vector2(width * 0.79, height * 0.2),
		height * 0.075,
		Color(1.0, 0.88, 0.48, 0.17)
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
		draw_rect(rect, Color(0.025, 0.095, 0.11, 0.52))
		for window_index in 3:
			draw_rect(
				Rect2(
					x + 10.0 + float(window_index) * 16.0,
					rect.position.y + 18.0,
					7.0,
					10.0
				),
				Color(0.92, 0.78, 0.38, 0.2)
			)
	draw_rect(
		Rect2(0, horizon, width, height - horizon),
		Color(0.055, 0.22, 0.2, 0.58)
	)
	draw_rect(
		Rect2(0, height * 0.79, width, height * 0.21),
		Color(0.04, 0.17, 0.24, 0.7)
	)
	for index in 7:
		var lily_position := Vector2(
			width * (0.08 + float(index) * 0.145),
			height * (0.84 + float(index % 2) * 0.07)
		)
		draw_circle(lily_position, 28.0, Color(0.23, 0.55, 0.3, 0.5))
		draw_colored_polygon(
			PackedVector2Array([
				lily_position,
				lily_position + Vector2(30, -8),
				lily_position + Vector2(27, 10),
			]),
			Color(0.04, 0.17, 0.24, 0.7)
		)
	var frog_position := Vector2(width * 0.14, height * 0.72)
	draw_circle(frog_position, 54.0, Color(0.31, 0.74, 0.34, 0.26))
	draw_circle(frog_position + Vector2(-36, -38), 22.0, Color(0.38, 0.84, 0.4, 0.3))
	draw_circle(frog_position + Vector2(36, -38), 22.0, Color(0.38, 0.84, 0.4, 0.3))
	draw_circle(frog_position + Vector2(-36, -41), 7.0, Color(0.94, 1.0, 0.94, 0.5))
	draw_circle(frog_position + Vector2(36, -41), 7.0, Color(0.94, 1.0, 0.94, 0.5))
