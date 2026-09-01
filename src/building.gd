class_name PrototypeBuilding
extends Node2D

const ART := preload("res://src/production_art.gd")

signal navigation_changed

const PART_SIGN := "sign"
const PART_DOOR := "door"
const PART_COUNTER := "counter"
const ENTRANCE_PART_DOOR := "door"
const ENTRANCE_PART_AWNING := "awning"
const REQUIRED_WEAKNESS := 3
const WALL_THICKNESS := 24.0

@export var building_size := Vector2(460, 340)
@export var display_name := "Shop"
@export var floor_color := Color("cda878")
@export_enum("north", "south", "east", "west") var door_side := "south"
@export var door_width := 110.0
@export var building_id := ""
@export var destructible_parts := false
@export var counter_position := Vector2(0, 64)
@export var counter_size := Vector2(140, 52)
@export_enum("door", "awning") var entrance_part_style := ENTRANCE_PART_DOOR

var consumed := false
var interior_props: Array[Rect2] = []
var transition_door_position := Vector2.INF
var transition_door_approach_offset := Vector2.INF
var transition_door_label := ""
var transition_room_id := ""
var transition_min_growth_tier := 0
var transition_required_removed_part := ""
var transition_required_part_label := ""
var entrance_schedule_open_label := ""
var entrance_schedule_closed_label := ""
var entrance_part_temporarily_open := false
var _removed_parts := {
	PART_SIGN: false,
	PART_DOOR: false,
	PART_COUNTER: false,
}
var _structural_bodies: Array[StaticBody2D] = []
var _door_body: StaticBody2D
var _counter_body: StaticBody2D


func _ready() -> void:
	_build_collision_walls()
	if destructible_parts:
		match entrance_part_style:
			ENTRANCE_PART_DOOR:
				_door_body = _add_wall(
					_door_local_position(),
					_door_collision_size()
				)
			ENTRANCE_PART_AWNING:
				pass
			_:
				push_error(
					"Unknown entrance part style '%s' for %s."
					% [entrance_part_style, building_id]
				)
		_counter_body = _add_wall(counter_position, counter_size)
	for prop in interior_props:
		_add_wall(prop.get_center(), prop.size)
	queue_redraw()


func _draw() -> void:
	if consumed:
		return
	var room := Rect2(-building_size / 2.0, building_size)
	draw_rect(
		Rect2(room.position + Vector2(10, 12), room.size),
		Color(ART.INK, 0.2)
	)
	draw_rect(room, floor_color)
	draw_rect(room.grow(-20), ART.CREAM, false, 5.0)
	for stripe in range(
		roundi(room.position.y + 42.0),
		roundi(room.end.y - 30.0),
		52
	):
		draw_line(
			Vector2(room.position.x + 30.0, stripe),
			Vector2(room.end.x - 30.0, stripe),
			Color(ART.INK, 0.07),
			2.0
		)
	for prop in interior_props:
		draw_rect(prop, floor_color.darkened(0.34))
		draw_rect(
			prop.grow(-6),
			floor_color.lightened(0.18),
			false,
			3.0
		)

	var wall_color := ART.INK
	var half := building_size / 2.0
	draw_rect(Rect2(-half.x, -half.y, building_size.x, WALL_THICKNESS), wall_color)
	draw_rect(Rect2(-half.x, half.y - WALL_THICKNESS, building_size.x, WALL_THICKNESS), wall_color)
	draw_rect(Rect2(-half.x, -half.y, WALL_THICKNESS, building_size.y), wall_color)
	draw_rect(Rect2(half.x - WALL_THICKNESS, -half.y, WALL_THICKNESS, building_size.y), wall_color)
	_draw_door_opening()

	if not destructible_parts or not is_part_removed(PART_SIGN):
		var name_y := 4.0
		if not interior_props.is_empty():
			if door_side == "south":
				name_y = -building_size.y * 0.34
			elif door_side == "north":
				name_y = building_size.y * 0.4
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-building_size.x * 0.38, name_y),
			display_name,
			HORIZONTAL_ALIGNMENT_CENTER,
			building_size.x * 0.76,
			25,
			ART.INK
		)
	else:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-building_size.x * 0.3, 4),
			"WEAKENED %d/%d" % [weakness_count(), REQUIRED_WEAKNESS],
			HORIZONTAL_ALIGNMENT_CENTER,
			building_size.x * 0.6,
			18,
			ART.DANGER_CORAL.darkened(0.35)
		)
	if destructible_parts and not is_part_removed(PART_COUNTER):
		draw_rect(
			Rect2(counter_position - counter_size / 2.0, counter_size),
			floor_color.darkened(0.18)
		)
	if interior_props.is_empty():
		draw_rect(
			Rect2(
				-building_size.x * 0.32,
				-building_size.y * 0.25,
				74,
				48
			),
			floor_color.darkened(0.12)
		)
		draw_rect(
			Rect2(
				building_size.x * 0.19,
				-building_size.y * 0.25,
				74,
				48
			),
			floor_color.darkened(0.12)
		)
	if (
		destructible_parts
		and not is_part_removed(PART_DOOR)
		and not entrance_part_temporarily_open
	):
		_draw_entrance_part()
	_draw_entrance_schedule_status()
	_draw_transition_door()


func contains_world_point(world_point: Vector2) -> bool:
	return Rect2(global_position - building_size / 2.0, building_size).has_point(world_point)


func footprint_rect() -> Rect2:
	return Rect2(global_position - building_size / 2.0, building_size)


func interior_rect() -> Rect2:
	return footprint_rect().grow(-WALL_THICKNESS)


func transition_door_world_position() -> Vector2:
	if transition_door_position == Vector2.INF:
		return Vector2.INF
	return global_position + transition_door_position


func transition_door_approach_position() -> Vector2:
	if transition_door_position == Vector2.INF:
		return Vector2.INF
	if transition_door_approach_offset != Vector2.INF:
		return (
			global_position
			+ transition_door_position
			+ transition_door_approach_offset
		)
	var direction := (-transition_door_position).normalized()
	return global_position + transition_door_position + direction * 72.0


func transition_door_hit_test(world_position: Vector2) -> bool:
	return (
		not consumed
		and transition_door_unlocked()
		and transition_door_position != Vector2.INF
		and transition_door_world_position().distance_to(world_position) <= 56.0
	)


func transition_door_unlocked() -> bool:
	return (
		transition_required_removed_part.is_empty()
		or is_part_removed(transition_required_removed_part)
	)


func entrance_part_world_rect() -> Rect2:
	var size := _door_collision_size()
	return Rect2(
		global_position + _door_local_position() - size / 2.0,
		size
	)


func set_entrance_part_temporarily_open(value: bool) -> void:
	if entrance_part_temporarily_open == value:
		return
	entrance_part_temporarily_open = value
	if destructible_parts and entrance_part_style == ENTRANCE_PART_DOOR:
		_set_body_enabled(
			_door_body,
			not consumed
			and not value
			and not is_part_removed(PART_DOOR)
		)
		navigation_changed.emit()
	queue_redraw()


func part_world_position(part_id: String) -> Vector2:
	var half := building_size / 2.0
	match part_id:
		PART_SIGN:
			match door_side:
				"east":
					return global_position + Vector2(half.x + 38, -135)
				"west":
					return global_position + Vector2(-half.x - 38, -135)
				"north":
					return global_position + Vector2(-135, -half.y - 38)
				_:
					return global_position + Vector2(-135, half.y + 38)
		PART_DOOR:
			var outward_offset := (
				32.0
				if entrance_part_style == ENTRANCE_PART_AWNING
				else 22.0
			)
			return (
				global_position
				+ _door_local_position()
				+ _door_outward_direction() * outward_offset
			)
		PART_COUNTER:
			return global_position + counter_position
	return global_position


func remove_part(part_id: String) -> bool:
	if not _removed_parts.has(part_id) or is_part_removed(part_id):
		return false
	_removed_parts[part_id] = true
	match part_id:
		PART_DOOR:
			_set_body_enabled(_door_body, false)
			navigation_changed.emit()
		PART_COUNTER:
			_set_body_enabled(_counter_body, false)
			navigation_changed.emit()
	queue_redraw()
	return true


func is_part_removed(part_id: String) -> bool:
	return bool(_removed_parts.get(part_id, false))


func weakness_count() -> int:
	var total := 0
	for removed in _removed_parts.values():
		if bool(removed):
			total += 1
	return total


func is_ready_to_swallow() -> bool:
	return destructible_parts and weakness_count() >= REQUIRED_WEAKNESS


func remaining_weakness() -> int:
	return maxi(0, REQUIRED_WEAKNESS - weakness_count())


func part_body_rid(part_id: String) -> RID:
	match part_id:
		PART_DOOR:
			return _door_body.get_rid() if is_instance_valid(_door_body) else RID()
		PART_COUNTER:
			return _counter_body.get_rid() if is_instance_valid(_counter_body) else RID()
	return RID()


func consume() -> void:
	if consumed:
		return
	consumed = true
	visible = false
	for body in _structural_bodies:
		_set_body_enabled(body, false)
	navigation_changed.emit()


func restore() -> void:
	if not consumed:
		return
	consumed = false
	visible = true
	for body in _structural_bodies:
		_set_body_enabled(body, true)
	if destructible_parts:
		_set_body_enabled(
			_door_body,
			not is_part_removed(PART_DOOR)
			and not entrance_part_temporarily_open
		)
		_set_body_enabled(_counter_body, not is_part_removed(PART_COUNTER))
	navigation_changed.emit()
	queue_redraw()


func navigation_obstacle_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for body in _structural_bodies:
		if (
			not is_instance_valid(body)
			or body.collision_layer == 0
			or body.is_queued_for_deletion()
		):
			continue
		for child in body.get_children():
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


func _draw_entrance_schedule_status() -> void:
	if (
		not destructible_parts
		or is_part_removed(PART_DOOR)
		or (
			entrance_schedule_open_label.is_empty()
			and entrance_schedule_closed_label.is_empty()
		)
	):
		return
	var label := (
		entrance_schedule_open_label
		if entrance_part_temporarily_open
		else entrance_schedule_closed_label
	)
	if label.is_empty():
		return
	var label_position := (
		_door_local_position() - _door_outward_direction() * 58.0
	)
	draw_string(
		ThemeDB.fallback_font,
		label_position + Vector2(-100, 6),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		200,
		16,
		Color("f5e8bd") if entrance_part_temporarily_open else Color("4b334f")
	)


func _draw_transition_door() -> void:
	if (
		transition_door_position == Vector2.INF
		or not transition_door_unlocked()
	):
		return
	draw_rect(
		Rect2(
			transition_door_position - Vector2(48, 24),
			Vector2(96, 48)
		),
		floor_color.darkened(0.48)
	)
	draw_rect(
		Rect2(
			transition_door_position - Vector2(40, 17),
			Vector2(80, 34)
		),
		floor_color.lightened(0.3),
		false,
		4.0
	)
	if not transition_door_label.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			transition_door_position + Vector2(-70, 48),
			transition_door_label,
			HORIZONTAL_ALIGNMENT_CENTER,
			140,
			16,
			Color("2f2822")
		)


func _draw_door_opening() -> void:
	var half := building_size / 2.0
	var opening_color := floor_color
	match door_side:
		"north":
			draw_rect(Rect2(-door_width / 2.0, -half.y - 2, door_width, WALL_THICKNESS + 4), opening_color)
		"south":
			draw_rect(Rect2(-door_width / 2.0, half.y - WALL_THICKNESS - 2, door_width, WALL_THICKNESS + 4), opening_color)
		"east":
			draw_rect(Rect2(half.x - WALL_THICKNESS - 2, -door_width / 2.0, WALL_THICKNESS + 4, door_width), opening_color)
		"west":
			draw_rect(Rect2(-half.x - 2, -door_width / 2.0, WALL_THICKNESS + 4, door_width), opening_color)


func _draw_entrance_part() -> void:
	if entrance_part_style == ENTRANCE_PART_AWNING:
		var outward := _door_outward_direction()
		var awning_center := _door_local_position() + outward * 32.0
		var awning_size := (
			Vector2(door_width + 28.0, 34.0)
			if door_side == "north" or door_side == "south"
			else Vector2(34.0, door_width + 28.0)
		)
		var awning_color := floor_color.lightened(0.24)
		draw_rect(
			Rect2(awning_center - awning_size / 2.0, awning_size),
			awning_color
		)
		var stripe_offset := (
			Vector2(awning_size.x * 0.22, 0)
			if door_side == "north" or door_side == "south"
			else Vector2(0, awning_size.y * 0.22)
		)
		draw_line(
			awning_center - stripe_offset,
			awning_center + stripe_offset,
			floor_color.darkened(0.18),
			6.0
		)
		return

	var door_size := _door_collision_size()
	draw_rect(
		Rect2(_door_local_position() - door_size / 2.0, door_size),
		floor_color.darkened(0.42)
	)


func _build_collision_walls() -> void:
	var half := building_size / 2.0
	if door_side == "north" or door_side == "south":
		var segment_width := (building_size.x - door_width) / 2.0
		var left_x := -half.x + segment_width / 2.0
		var right_x := half.x - segment_width / 2.0
		var north_y := -half.y + WALL_THICKNESS / 2.0
		var south_y := half.y - WALL_THICKNESS / 2.0
		if door_side == "north":
			_add_wall(Vector2(left_x, north_y), Vector2(segment_width, WALL_THICKNESS))
			_add_wall(Vector2(right_x, north_y), Vector2(segment_width, WALL_THICKNESS))
		else:
			_add_wall(Vector2(0, north_y), Vector2(building_size.x, WALL_THICKNESS))
		if door_side == "south":
			_add_wall(Vector2(left_x, south_y), Vector2(segment_width, WALL_THICKNESS))
			_add_wall(Vector2(right_x, south_y), Vector2(segment_width, WALL_THICKNESS))
		else:
			_add_wall(Vector2(0, south_y), Vector2(building_size.x, WALL_THICKNESS))
		_add_wall(Vector2(-half.x + WALL_THICKNESS / 2.0, 0), Vector2(WALL_THICKNESS, building_size.y))
		_add_wall(Vector2(half.x - WALL_THICKNESS / 2.0, 0), Vector2(WALL_THICKNESS, building_size.y))
	else:
		var segment_height := (building_size.y - door_width) / 2.0
		var top_y := -half.y + segment_height / 2.0
		var bottom_y := half.y - segment_height / 2.0
		var west_x := -half.x + WALL_THICKNESS / 2.0
		var east_x := half.x - WALL_THICKNESS / 2.0
		if door_side == "west":
			_add_wall(Vector2(west_x, top_y), Vector2(WALL_THICKNESS, segment_height))
			_add_wall(Vector2(west_x, bottom_y), Vector2(WALL_THICKNESS, segment_height))
		else:
			_add_wall(Vector2(west_x, 0), Vector2(WALL_THICKNESS, building_size.y))
		if door_side == "east":
			_add_wall(Vector2(east_x, top_y), Vector2(WALL_THICKNESS, segment_height))
			_add_wall(Vector2(east_x, bottom_y), Vector2(WALL_THICKNESS, segment_height))
		else:
			_add_wall(Vector2(east_x, 0), Vector2(WALL_THICKNESS, building_size.y))
		_add_wall(Vector2(0, -half.y + WALL_THICKNESS / 2.0), Vector2(building_size.x, WALL_THICKNESS))
		_add_wall(Vector2(0, half.y - WALL_THICKNESS / 2.0), Vector2(building_size.x, WALL_THICKNESS))


func _door_local_position() -> Vector2:
	var half := building_size / 2.0
	match door_side:
		"north":
			return Vector2(0, -half.y + WALL_THICKNESS / 2.0)
		"south":
			return Vector2(0, half.y - WALL_THICKNESS / 2.0)
		"east":
			return Vector2(half.x - WALL_THICKNESS / 2.0, 0)
		_:
			return Vector2(-half.x + WALL_THICKNESS / 2.0, 0)


func _door_collision_size() -> Vector2:
	if door_side == "north" or door_side == "south":
		return Vector2(door_width, WALL_THICKNESS)
	return Vector2(WALL_THICKNESS, door_width)


func _door_outward_direction() -> Vector2:
	match door_side:
		"north":
			return Vector2.UP
		"south":
			return Vector2.DOWN
		"east":
			return Vector2.RIGHT
		_:
			return Vector2.LEFT


func _add_wall(wall_position: Vector2, wall_size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = wall_position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = wall_size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_structural_bodies.append(body)
	return body


func _set_body_enabled(body: StaticBody2D, enabled: bool) -> void:
	if not is_instance_valid(body):
		return
	body.collision_layer = 1 if enabled else 0
	body.collision_mask = 1 if enabled else 0
