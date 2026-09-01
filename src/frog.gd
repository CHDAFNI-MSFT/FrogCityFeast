class_name PlayerFrog
extends CharacterBody2D

signal move_reached(world_position: Vector2)

const TUNING := preload("res://src/gameplay_tuning.gd")
const ART := preload("res://src/production_art.gd")
const TIER_SCALES := TUNING.FROG_TIER_SCALES
const TIER_RADII := TUNING.FROG_TIER_RADII
const TIER_SPEEDS := TUNING.FROG_TIER_SPEEDS
const TIER_TONGUE_RANGES := TUNING.FROG_TIER_TONGUE_RANGES
const ENORMOUS_TIER := TUNING.ENORMOUS_TIER
const WAYPOINT_TOLERANCE := 1.0

var growth_tier := 0
var movement_enabled := true
var is_flying := false
var ground_speed_multiplier := 1.0
var tongue_range_multiplier := 1.0
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
var _swallow_celebration_time := 0.0
var _damage_feedback_time := 0.0
var _animation_time := 0.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_move_target = global_position
	queue_redraw()


func _process(delta: float) -> void:
	var should_redraw := false
	if (
		_presentation_motion_scale() > 0.0
		and (velocity.length_squared() > 1.0 or is_flying)
	):
		_animation_time = fmod(_animation_time + delta, TAU * 8.0)
		should_redraw = true
	if _growth_celebration_time > 0.0:
		_growth_celebration_time = maxf(
			0.0,
			_growth_celebration_time - delta
		)
		var progress := 1.0 - _growth_celebration_time / 0.5
		_visual_scale = (
			1.0
			+ sin(progress * PI)
			* 0.16
			* _growth_celebration_motion_scale
		)
		if _growth_celebration_time <= 0.0:
			_visual_scale = 1.0
		should_redraw = true
	if _swallow_celebration_time > 0.0:
		_swallow_celebration_time = maxf(
			0.0,
			_swallow_celebration_time - delta
		)
		should_redraw = true
	if _damage_feedback_time > 0.0:
		_damage_feedback_time = maxf(0.0, _damage_feedback_time - delta)
		should_redraw = true
	if should_redraw:
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
	var speed_multiplier := 1.45 if is_flying else ground_speed_multiplier
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
	_damage_feedback_time = 0.32
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


func celebrate_swallow() -> void:
	_swallow_celebration_time = 0.32
	queue_redraw()


func set_presentation_motion_scale(value: float) -> void:
	_growth_celebration_motion_scale = clampf(value, 0.0, 1.0)
	if _growth_celebration_motion_scale <= 0.0:
		_growth_celebration_time = 0.0
		_visual_scale = 1.0
	queue_redraw()


func _presentation_motion_scale() -> float:
	return _growth_celebration_motion_scale


func tongue_range() -> float:
	return TIER_TONGUE_RANGES[growth_tier] * tongue_range_multiplier


func collision_radius() -> float:
	return TIER_RADII[growth_tier]


func radius_for_tier(tier: int) -> float:
	return TIER_RADII[clampi(tier, 0, TIER_RADII.size() - 1)]


func set_flying(value: bool) -> void:
	is_flying = value
	collision_mask = 0 if is_flying else 1
	queue_redraw()


func set_ground_speed_multiplier(value: float) -> void:
	ground_speed_multiplier = maxf(0.0, value)


func set_tongue_range_multiplier(value: float) -> void:
	tongue_range_multiplier = maxf(0.0, value)


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
	var movement_amount := clampf(
		velocity.length() / maxf(TIER_SPEEDS[growth_tier], 1.0),
		0.0,
		1.0
	)
	var step_cycle := (
		sin(_animation_time * 8.0)
		* movement_amount
		* _presentation_motion_scale()
	)
	var flight_cycle := (
		sin(_animation_time * 11.0)
		* _presentation_motion_scale()
	)
	var swallow_progress := (
		1.0 - _swallow_celebration_time / 0.32
		if _swallow_celebration_time > 0.0
		else 1.0
	)
	var swallow_squash := (
		sin(swallow_progress * PI)
		* 0.13
		* _presentation_motion_scale()
		if _swallow_celebration_time > 0.0
		else 0.0
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_ellipse_shadow(Vector2(0, 34), Vector2(42, 15))
	if is_flying:
		var wing_rotation := -0.22 + flight_cycle * 0.16
		draw_set_transform(
			Vector2(-31, -3),
			-wing_rotation,
			Vector2(0.72, 0.72)
		)
		draw_texture_rect(
			ART.WING_TEXTURE,
			Rect2(-86, -35, 86, 70),
			false
		)
		draw_set_transform(
			Vector2(31, -3),
			wing_rotation,
			Vector2(-0.72, 0.72)
		)
		draw_texture_rect(
			ART.WING_TEXTURE,
			Rect2(-86, -35, 86, 70),
			false
		)
	draw_set_transform(
		Vector2(0, step_cycle * 2.5),
		step_cycle * 0.025,
		Vector2(
			1.0 + absf(step_cycle) * 0.045 + swallow_squash,
			1.0 - absf(step_cycle) * 0.035 - swallow_squash * 0.7
		) * _visual_scale
	)
	var frog_tint := (
		Color("ffd1c7")
		if _damage_feedback_time > 0.0
		else Color.WHITE
	)
	draw_texture_rect(
		ART.FROG_TEXTURE,
		Rect2(-64, -64, 128, 128),
		false,
		frog_tint
	)
	if _swallow_celebration_time > 0.0:
		var motion_scale := _presentation_motion_scale()
		var sparkle_alpha := (
			sin(swallow_progress * PI)
			if motion_scale > 0.0
			else 0.82
		)
		draw_arc(
			Vector2.ZERO,
			46.0 + swallow_progress * 4.0 * motion_scale,
			-0.3,
			PI + 0.3,
			20,
			Color(ART.MAGIC_AMBER, sparkle_alpha),
			4.0
		)


func draw_ellipse_shadow(center: Vector2, radii: Vector2) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(
		Vector2.ZERO,
		radii.x,
		Color(ART.INK, 0.2)
	)
