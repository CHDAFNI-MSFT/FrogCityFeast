class_name GeneratedDistrict
extends Node2D

var definition: DistrictDefinition
var _environment_body: StaticBody2D


func configure(value: DistrictDefinition) -> void:
	definition = value
	name = "GeneratedDistrict_%d_%d" % [
		definition.coordinate.x,
		definition.coordinate.y,
	]


func _ready() -> void:
	if definition == null:
		push_error("GeneratedDistrict requires a definition before entering the tree.")
		return
	z_index = -10
	_build_environment_collision()
	queue_redraw()


func _build_environment_collision() -> void:
	if definition.obstacles.is_empty():
		return
	_environment_body = StaticBody2D.new()
	_environment_body.collision_layer = 1
	_environment_body.collision_mask = 1
	for obstacle in definition.obstacles:
		var shape := RectangleShape2D.new()
		shape.size = obstacle.size
		var collision := CollisionShape2D.new()
		collision.position = obstacle.get_center()
		collision.shape = shape
		_environment_body.add_child(collision)
	add_child(_environment_body)


func navigation_obstacle_rects() -> Array[Rect2]:
	if definition == null:
		return []
	return definition.obstacles.duplicate()


func _draw() -> void:
	if definition == null:
		return
	draw_rect(definition.bounds, definition.ground_color)
	for road in definition.roads:
		draw_rect(road, definition.road_color)
		draw_rect(
			road.grow(-18.0),
			definition.road_color.lightened(0.1),
			false,
			4.0
		)
	for building_value in definition.buildings:
		var building := building_value as Dictionary
		var footprint := Rect2(
			building["position"] as Vector2
			- (building["size"] as Vector2) / 2.0,
			building["size"] as Vector2
		)
		draw_rect(footprint.grow(54.0), definition.lot_color)
	for obstacle in definition.obstacles:
		var obstacle_color := (
			Color("4d94b7")
			if definition.archetype_id == "waterfront"
			else definition.accent_color.darkened(0.28)
		)
		draw_rect(obstacle, obstacle_color)
		draw_rect(
			obstacle.grow(-10.0),
			obstacle_color.lightened(0.14),
			false,
			4.0
		)
	_draw_street_markings()
	_draw_archetype_details()
	draw_string(
		ThemeDB.fallback_font,
		definition.bounds.position + Vector2(90, 110),
		definition.display_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT,
		720,
		30,
		definition.accent_color.lightened(0.2)
	)


func _draw_street_markings() -> void:
	var center := definition.bounds.get_center()
	for x in range(
		roundi(definition.bounds.position.x + 80),
		roundi(definition.bounds.end.x - 80),
		140
	):
		draw_line(
			Vector2(x, center.y),
			Vector2(x + 72, center.y),
			definition.accent_color,
			5.0
		)
	for y in range(
		roundi(definition.bounds.position.y + 80),
		roundi(definition.bounds.end.y - 80),
		140
	):
		draw_line(
			Vector2(center.x, y),
			Vector2(center.x, y + 72),
			definition.accent_color,
			5.0
		)


func _draw_archetype_details() -> void:
	var center := definition.bounds.get_center()
	match definition.archetype_id:
		"downtown":
			for offset in [-1240.0, 1240.0]:
				for line in 5:
					var x: float = (
						center.x + float(offset) + float(line) * 34.0
					)
					draw_line(
						Vector2(x, center.y - 920),
						Vector2(x, center.y - 720),
						definition.accent_color,
						4.0
					)
		"residential":
			for offset in [
				Vector2(-1250, -900),
				Vector2(1250, 900),
			]:
				draw_circle(
					center + offset,
					82.0,
					definition.lot_color.lightened(0.18)
				)
		"industrial":
			for step in 6:
				var start := center + Vector2(-1450 + step * 90, 1030)
				draw_line(
					start,
					start + Vector2(60, -60),
					definition.accent_color,
					8.0
				)
		"waterfront":
			draw_string(
				ThemeDB.fallback_font,
				center + Vector2(1160, -20),
				"CANAL BRIDGE",
				HORIZONTAL_ALIGNMENT_CENTER,
				430,
				20,
				Color("e5f5fb")
			)
		"shopping":
			draw_rect(
				Rect2(center + Vector2(-1120, -300), Vector2(500, 600)),
				definition.lot_color.lightened(0.15),
				false,
				7.0
			)
		"parks":
			for offset in [
				Vector2(-1180, 820),
				Vector2(-980, 980),
				Vector2(780, 760),
			]:
				draw_circle(
					center + offset,
					64.0,
					definition.accent_color.darkened(0.32)
				)
