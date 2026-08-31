class_name CityBackdrop
extends Node2D

const WORLD_RECT := Rect2(-1800, -1400, 3600, 2800)
const RIVER_RECT := Rect2(1210, -1320, 500, 920)
const ROAD_RECTS := [
	Rect2(-1800, -220, 3600, 440),
	Rect2(-220, -1400, 440, 2800),
	Rect2(-1800, 690, 3600, 320),
	Rect2(-1240, -1400, 320, 2800),
]
const EXPLORATION_MARKERS := [
	{
		"position": Vector2(1050, 550),
		"label": "SEWER HATCH",
		"color": Color("60747b"),
	},
]


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(WORLD_RECT, Color("7f9c76"))

	for road in ROAD_RECTS:
		draw_rect(road, Color("39434b"))
		draw_rect(road.grow(-18), Color("414d56"), false, 4.0)

	for x in range(-1700, 1701, 130):
		draw_line(Vector2(x, 0), Vector2(x + 68, 0), Color("e5cb64"), 5.0)
	for y in range(-1300, 1301, 130):
		draw_line(Vector2(0, y), Vector2(0, y + 68), Color("e5cb64"), 5.0)

	draw_rect(Rect2(380, 290, 760, 330), Color("477d51"))
	draw_circle(Vector2(600, 430), 78.0, Color("2e6742"))
	draw_circle(Vector2(890, 470), 62.0, Color("2e6742"))
	draw_rect(RIVER_RECT, Color("4d91b5"))
	for y in range(-1240, -430, 90):
		draw_line(Vector2(1230, y), Vector2(1690, y + 28), Color(0.75, 0.9, 1.0, 0.35), 4.0)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(420, 350),
		"RIVER PARK",
		HORIZONTAL_ALIGNMENT_LEFT,
		300,
		28,
		Color("d8f4c6")
	)
	for marker_value in EXPLORATION_MARKERS:
		var marker := marker_value as Dictionary
		var marker_position := marker["position"] as Vector2
		var marker_color := marker["color"] as Color
		draw_circle(marker_position, 46.0, marker_color.darkened(0.35))
		draw_circle(
			marker_position,
			36.0,
			marker_color,
			false,
			6.0
		)
		draw_line(
			marker_position + Vector2(-24, 0),
			marker_position + Vector2(24, 0),
			marker_color.lightened(0.3),
			4.0
		)
		draw_string(
			ThemeDB.fallback_font,
			marker_position + Vector2(-100, 76),
			str(marker["label"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			200,
			17,
			Color("e7f0e9")
		)
