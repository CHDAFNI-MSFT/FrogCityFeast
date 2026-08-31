class_name PrototypeInteriorRoom
extends Node2D

const WALL_THICKNESS := 28.0

@export var room_id := ""
@export var display_name := "Interior Room"
@export var room_size := Vector2(1100, 820)
@export var floor_color := Color("9b7357")
@export var return_label := "RETURN TO CITY"

var props: Array[Rect2] = []
var _collision_body: StaticBody2D


func _ready() -> void:
	_build_collision()
	queue_redraw()


func footprint_rect() -> Rect2:
	return Rect2(global_position - room_size / 2.0, room_size)


func interior_rect() -> Rect2:
	return footprint_rect().grow(-WALL_THICKNESS - 8.0)


func entry_position() -> Vector2:
	return global_position + Vector2(0, room_size.y * 0.31)


func exit_marker_position() -> Vector2:
	return global_position + Vector2(0, room_size.y * 0.4)


func exit_approach_position() -> Vector2:
	return global_position + Vector2(0, room_size.y * 0.3)


func exit_hit_test(world_position: Vector2) -> bool:
	return exit_marker_position().distance_to(world_position) <= 62.0


func contains_world_point(world_position: Vector2) -> bool:
	return footprint_rect().has_point(world_position)


func _build_collision() -> void:
	_collision_body = StaticBody2D.new()
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 1
	var room := Rect2(-room_size / 2.0, room_size)
	_add_rect_collision(
		Rect2(room.position, Vector2(room.size.x, WALL_THICKNESS))
	)
	_add_rect_collision(
		Rect2(
			Vector2(room.position.x, room.end.y - WALL_THICKNESS),
			Vector2(room.size.x, WALL_THICKNESS)
		)
	)
	_add_rect_collision(
		Rect2(room.position, Vector2(WALL_THICKNESS, room.size.y))
	)
	_add_rect_collision(
		Rect2(
			Vector2(room.end.x - WALL_THICKNESS, room.position.y),
			Vector2(WALL_THICKNESS, room.size.y)
		)
	)
	for prop in props:
		_add_rect_collision(prop)
	add_child(_collision_body)


func _add_rect_collision(rect: Rect2) -> void:
	var collision := CollisionShape2D.new()
	collision.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	_collision_body.add_child(collision)


func _draw() -> void:
	var room := Rect2(-room_size / 2.0, room_size)
	draw_rect(room, floor_color)
	draw_rect(
		room.grow(-WALL_THICKNESS),
		floor_color.lightened(0.12),
		false,
		6.0
	)
	var wall_color := floor_color.darkened(0.46)
	draw_rect(
		Rect2(room.position, Vector2(room.size.x, WALL_THICKNESS)),
		wall_color
	)
	draw_rect(
		Rect2(
			Vector2(room.position.x, room.end.y - WALL_THICKNESS),
			Vector2(room.size.x, WALL_THICKNESS)
		),
		wall_color
	)
	draw_rect(
		Rect2(room.position, Vector2(WALL_THICKNESS, room.size.y)),
		wall_color
	)
	draw_rect(
		Rect2(
			Vector2(room.end.x - WALL_THICKNESS, room.position.y),
			Vector2(WALL_THICKNESS, room.size.y)
		),
		wall_color
	)
	for prop in props:
		draw_rect(prop, floor_color.darkened(0.36))
		draw_rect(
			prop.grow(-7.0),
			floor_color.lightened(0.2),
			false,
			4.0
		)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-room_size.x * 0.3, -room_size.y * 0.36),
		display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		room_size.x * 0.6,
		32,
		Color("30241e")
	)
	var exit_position := to_local(exit_marker_position())
	draw_rect(
		Rect2(exit_position - Vector2(58, 28), Vector2(116, 56)),
		Color("4f6f72")
	)
	draw_rect(
		Rect2(exit_position - Vector2(48, 20), Vector2(96, 40)),
		Color("96bdaf"),
		false,
		4.0
	)
	draw_string(
		ThemeDB.fallback_font,
		exit_position + Vector2(-120, 56),
		return_label,
		HORIZONTAL_ALIGNMENT_CENTER,
		240,
		18,
		Color("f2f5e9")
	)
