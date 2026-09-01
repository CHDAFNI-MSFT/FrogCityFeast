class_name CityBackdrop
extends Node2D

const ART := preload("res://src/production_art.gd")

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
		"position": Vector2(-1510, -1120),
		"label": "CRANE LIFT",
		"color": Color("c28a43"),
	},
	{
		"position": Vector2(520, 560),
		"label": "POND BOARDWALK",
		"color": Color("5d8c71"),
	},
	{
		"position": Vector2(1050, 550),
		"label": "SEWER HATCH",
		"color": Color("60747b"),
	},
]


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(WORLD_RECT, ART.PARK_TEAL.lightened(0.2))

	for road in ROAD_RECTS:
		draw_rect(road.grow(22.0), ART.PAPER.darkened(0.18))
		draw_rect(road, ART.NIGHT_NAVY.lightened(0.08))
		draw_rect(road.grow(-18), ART.CREAM.darkened(0.62), false, 4.0)

	for x in range(-1700, 1701, 130):
		draw_line(Vector2(x, 0), Vector2(x + 68, 0), ART.CITY_GOLD, 5.0)
	for y in range(-1300, 1301, 130):
		draw_line(Vector2(0, y), Vector2(0, y + 68), ART.CITY_GOLD, 5.0)

	draw_rect(Rect2(380, 290, 760, 330), ART.PARK_TEAL)
	for tree_position in [
		Vector2(540, 390),
		Vector2(600, 500),
		Vector2(940, 410),
		Vector2(1010, 520),
	]:
		draw_circle(tree_position + Vector2(7, 8), 45.0, Color(ART.INK, 0.16))
		draw_circle(tree_position, 45.0, ART.FROG_DARK)
		draw_circle(
			tree_position + Vector2(-12, -8),
			22.0,
			ART.FOCUS_MINT.darkened(0.18)
		)
	draw_circle(Vector2(760, 455), 92.0, ART.CANAL_TEAL)
	draw_circle(Vector2(760, 455), 68.0, ART.CREAM, false, 5.0)
	draw_rect(RIVER_RECT, ART.CANAL_TEAL)
	for y in range(-1240, -430, 90):
		draw_line(
			Vector2(1230, y),
			Vector2(1690, y + 28),
			Color(ART.CREAM, 0.3),
			4.0
		)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(420, 350),
		"RIVER PARK",
		HORIZONTAL_ALIGNMENT_LEFT,
		300,
		28,
		ART.CREAM
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
	draw_line(
		Vector2(-1580, -1240),
		Vector2(-1370, -1240),
		Color("e0a147"),
		18.0
	)
	draw_line(
		Vector2(-1470, -1240),
		Vector2(-1470, -980),
		Color("c77d37"),
		14.0
	)
