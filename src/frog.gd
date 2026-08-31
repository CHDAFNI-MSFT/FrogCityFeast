class_name PlayerFrog
extends CharacterBody2D

signal move_reached(world_position: Vector2)

const TIER_SCALES := [1.0, 1.28, 1.62]
const TIER_RADII := [28.0, 35.0, 44.0]
const TIER_SPEEDS := [330.0, 350.0, 365.0]
const TIER_TONGUE_RANGES := [390.0, 540.0, 720.0]
const WAYPOINT_TOLERANCE := 1.0

var growth_tier := 0
var movement_enabled := true
var is_flying := false
var _move_target := Vector2.ZERO
var _has_move_target := false
var _move_path := PackedVector2Array()
var _move_path_index := 0
var _move_path_revision := -1
var _knockback_velocity := Vector2.ZERO
var _knockback_time := 0.0
var _visual_scale := 1.0
var _growth_celebration_time := 0.0
var _growth_celebration_motion_scale := 1.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_move_target = global_position
	queue_redraw()


func _process(delta: float) -> void:
	if _growth_celebration_time <= 0.0:
		return
	_growth_celebration_time = maxf(0.0, _growth_celebration_time - delta)
	var progress := 1.0 - _growth_celebration_time / 0.5
	_visual_scale = (
		1.0
		+ sin(progress * PI) * 0.16 * _growth_celebration_motion_scale
	)
	if _growth_celebration_time <= 0.0:
		_visual_scale = 1.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _knockback_time > 0.0:
		_knockback_time -= delta
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return

	if not movement_enabled or not _has_move_target:
		velocity = Vector2.ZERO
		return

	var waypoint := _current_waypoint()
	while global_position.distance_to(waypoint) <= WAYPOINT_TOLERANCE:
		if _move_path_index < _move_path.size() - 1:
			_move_path_index += 1
			waypoint = _current_waypoint()
			continue
		_finish_move()
		return

	var offset := waypoint - global_position
	var speed_multiplier := 1.45 if is_flying else 1.0
	var movement_speed: float = (
		TIER_SPEEDS[growth_tier] * speed_multiplier
	)
	velocity = offset.normalized() * minf(
		movement_speed,
		offset.length() / maxf(delta, 0.0001)
	)
	rotation = velocity.angle() + PI / 2.0
	move_and_slide()


func move_to(world_position: Vector2) -> void:
	if not movement_enabled:
		return
	_move_path = PackedVector2Array()
	_move_path_index = 0
	_move_path_revision = -1
	_move_target = world_position
	_has_move_target = true


func follow_path(points: PackedVector2Array, revision: int) -> bool:
	if (
		not movement_enabled
		or is_flying
		or knockback_active()
		or points.size() < 2
	):
		return false
	_move_path = points.duplicate()
	_move_path_index = 1
	_move_path_revision = revision
	_move_target = _move_path[-1]
	_has_move_target = true
	return true


func stop_moving() -> void:
	_has_move_target = false
	_move_path = PackedVector2Array()
	_move_path_index = 0
	_move_path_revision = -1
	velocity = Vector2.ZERO


func has_active_path() -> bool:
	return _has_move_target and not _move_path.is_empty()


func active_path_revision() -> int:
	return _move_path_revision


func active_path_point_count() -> int:
	return _move_path.size()


func clear_knockback() -> void:
	_knockback_velocity = Vector2.ZERO
	_knockback_time = 0.0
	velocity = Vector2.ZERO


func knockback_active() -> bool:
	return _knockback_time > 0.0


func knock_back_from(source_position: Vector2) -> void:
	var direction := (global_position - source_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	_knockback_velocity = direction * 620.0
	_knockback_time = 0.32
	stop_moving()


func set_growth_tier(next_tier: int) -> void:
	growth_tier = clampi(next_tier, 0, TIER_SCALES.size() - 1)
	scale = Vector2.ONE * TIER_SCALES[growth_tier]
	var circle := _collision_shape.shape as CircleShape2D
	circle.radius = TIER_RADII[growth_tier] / TIER_SCALES[growth_tier]
	queue_redraw()


func celebrate_growth(motion_scale: float) -> void:
	_growth_celebration_motion_scale = clampf(motion_scale, 0.0, 1.0)
	_growth_celebration_time = 0.5
	_visual_scale = 1.0
	queue_redraw()


func set_presentation_motion_scale(value: float) -> void:
	_growth_celebration_motion_scale = clampf(value, 0.0, 1.0)
	if _growth_celebration_motion_scale <= 0.0:
		_growth_celebration_time = 0.0
		_visual_scale = 1.0
	queue_redraw()


func tongue_range() -> float:
	return TIER_TONGUE_RANGES[growth_tier]


func collision_radius() -> float:
	return TIER_RADII[growth_tier]


func radius_for_tier(tier: int) -> float:
	return TIER_RADII[clampi(tier, 0, TIER_RADII.size() - 1)]


func set_flying(value: bool) -> void:
	is_flying = value
	collision_mask = 0 if is_flying else 1
	queue_redraw()


func _current_waypoint() -> Vector2:
	if (
		not _move_path.is_empty()
		and _move_path_index >= 0
		and _move_path_index < _move_path.size()
	):
		return _move_path[_move_path_index]
	return _move_target


func _finish_move() -> void:
	var reached_position := _move_target
	stop_moving()
	move_reached.emit(reached_position)


func _draw() -> void:
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE * _visual_scale
	)
	if is_flying:
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-22, -2),
				Vector2(-58, -30),
				Vector2(-47, 15),
				Vector2(-20, 25),
			]),
			Color(0.72, 0.94, 1.0, 0.85)
		)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(22, -2),
				Vector2(58, -30),
				Vector2(47, 15),
				Vector2(20, 25),
			]),
			Color(0.72, 0.94, 1.0, 0.85)
		)
	draw_circle(Vector2.ZERO, 28.0, Color("4fbd55"))
	draw_circle(Vector2(-18, -17), 12.0, Color("64dc68"))
	draw_circle(Vector2(18, -17), 12.0, Color("64dc68"))
	draw_circle(Vector2(-18, -19), 5.5, Color.WHITE)
	draw_circle(Vector2(18, -19), 5.5, Color.WHITE)
	draw_circle(Vector2(-18, -20), 2.7, Color("17211c"))
	draw_circle(Vector2(18, -20), 2.7, Color("17211c"))
	draw_arc(Vector2(0, 4), 12.0, 0.15, PI - 0.15, 18, Color("17351f"), 3.0)
	draw_circle(Vector2(-25, 17), 9.0, Color("3f9f49"))
	draw_circle(Vector2(25, 17), 9.0, Color("3f9f49"))
