class_name PrototypeInteriorRoom
extends Node2D

const WALL_THICKNESS := 28.0
const CAMERA_FIXED := "fixed"
const CAMERA_FOLLOW := "follow"

@export var room_id := ""
@export var display_name := "Interior Room"
@export var room_size := Vector2(1100, 820)
@export var floor_color := Color("9b7357")
@export var return_label := "RETURN TO CITY"

var props: Array[Rect2] = []
var camera_mode := CAMERA_FIXED
var camera_zoom := Vector2(1.2, 1.2)
var camera_follow_distance := 160.0
var camera_rotation_limit := 0.0
var entries: Dictionary = {}
var portals: Array[Dictionary] = []
var _collision_body: StaticBody2D


func _ready() -> void:
	_build_collision()
	queue_redraw()


func footprint_rect() -> Rect2:
	return Rect2(global_position - room_size / 2.0, room_size)


func interior_rect() -> Rect2:
	return footprint_rect().grow(-WALL_THICKNESS - 8.0)


func entry_position(entry_id: String = "default") -> Vector2:
	var default_offset := Vector2(0, room_size.y * 0.31)
	return global_position + (
		entries.get(entry_id, entries.get("default", default_offset))
		as Vector2
	)


func set_entry(entry_id: String, local_position: Vector2) -> void:
	entries[entry_id] = local_position


func add_portal(
	portal_id: String,
	label: String,
	local_marker_position: Vector2,
	local_approach_position: Vector2,
	destination: String,
	destination_entry_id: String = "default",
	min_growth_tier: int = 0,
	requirement_text: String = "",
	required_discovery_id: String = "",
	required_building_id: String = "",
	required_removed_part: String = "",
	required_weakness: int = 0
) -> void:
	portals.append({
		"id": portal_id,
		"label": label,
		"marker_position": local_marker_position,
		"approach_position": local_approach_position,
		"destination": destination,
		"destination_entry_id": destination_entry_id,
		"min_growth_tier": min_growth_tier,
		"requirement_text": requirement_text,
		"required_discovery_id": required_discovery_id,
		"required_building_id": required_building_id,
		"required_removed_part": required_removed_part,
		"required_weakness": required_weakness,
		"visible": true,
	})
	queue_redraw()


func portal_by_id(portal_id: String) -> Dictionary:
	for portal_value in portals:
		var portal := portal_value as Dictionary
		if str(portal.get("id", "")) == portal_id:
			return portal
	return {}


func portal_to_destination(destination: String) -> Dictionary:
	for portal_value in portals:
		var portal := portal_value as Dictionary
		if str(portal.get("destination", "")) == destination:
			return portal
	return {}


func portal_at(world_position: Vector2) -> Dictionary:
	for portal_value in portals:
		var portal := portal_value as Dictionary
		if (
			bool(portal.get("visible", true))
			and portal_marker_position(portal).distance_to(world_position)
			<= 62.0
		):
			return portal
	return {}


func portal_marker_position(portal: Dictionary) -> Vector2:
	return global_position + (
		portal.get("marker_position", Vector2.ZERO) as Vector2
	)


func portal_approach_position(portal: Dictionary) -> Vector2:
	return global_position + (
		portal.get("approach_position", Vector2.ZERO) as Vector2
	)


func set_portal_visible(portal_id: String, visible: bool) -> void:
	for portal_value in portals:
		var portal := portal_value as Dictionary
		if str(portal.get("id", "")) == portal_id:
			portal["visible"] = visible
			queue_redraw()
			return


func set_portal_geometry(
	portal_id: String,
	local_marker_position: Vector2,
	local_approach_position: Vector2
) -> void:
	for portal_value in portals:
		var portal := portal_value as Dictionary
		if str(portal.get("id", "")) == portal_id:
			portal["marker_position"] = local_marker_position
			portal["approach_position"] = local_approach_position
			queue_redraw()
			return


func camera_follows_frog() -> bool:
	return camera_mode == CAMERA_FOLLOW


func exit_marker_position() -> Vector2:
	var portal := portal_to_destination("city")
	if not portal.is_empty():
		return portal_marker_position(portal)
	return global_position + Vector2(0, room_size.y * 0.4)


func exit_approach_position() -> Vector2:
	var portal := portal_to_destination("city")
	if not portal.is_empty():
		return portal_approach_position(portal)
	return global_position + Vector2(0, room_size.y * 0.3)


func exit_hit_test(world_position: Vector2) -> bool:
	var portal := portal_to_destination("city")
	return (
		not portal.is_empty()
		and bool(portal.get("visible", true))
		and portal_marker_position(portal).distance_to(world_position) <= 62.0
	)


func contains_world_point(world_position: Vector2) -> bool:
	return footprint_rect().has_point(world_position)


func navigation_obstacle_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if (
		not is_instance_valid(_collision_body)
		or _collision_body.collision_layer == 0
	):
		return result
	for child in _collision_body.get_children():
		var collision := child as CollisionShape2D
		if (
			not is_instance_valid(collision)
			or collision.disabled
			or not collision.shape is RectangleShape2D
		):
			continue
		var rectangle := collision.shape as RectangleShape2D
		var global_scale := collision.global_transform.get_scale().abs()
		var size := rectangle.size * global_scale
		result.append(Rect2(collision.global_position - size / 2.0, size))
	return result


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
	for portal_value in portals:
		var portal := portal_value as Dictionary
		if not bool(portal.get("visible", true)):
			continue
		var portal_position := portal.get(
			"marker_position",
			Vector2.ZERO
		) as Vector2
		draw_rect(
			Rect2(portal_position - Vector2(58, 28), Vector2(116, 56)),
			Color("4f6f72")
		)
		draw_rect(
			Rect2(portal_position - Vector2(48, 20), Vector2(96, 40)),
			Color("96bdaf"),
			false,
			4.0
		)
		draw_string(
			ThemeDB.fallback_font,
			portal_position + Vector2(-120, 56),
			str(portal.get("label", "EXIT")),
			HORIZONTAL_ALIGNMENT_CENTER,
			240,
			18,
			Color("f2f5e9")
		)
