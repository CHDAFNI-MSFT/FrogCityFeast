class_name PrototypePursuer
extends CharacterBody2D

signal caught(source_position: Vector2)
signal escaped
signal netted(source_position: Vector2)

enum NetPhase {
	IDLE,
	WINDUP,
	FLYING,
}

const NET_INITIAL_COOLDOWN := 1.0
const NET_RETRY_COOLDOWN := 6.0
const NET_WINDUP_DURATION := 0.8
const NET_SPEED := 520.0
const NET_MAX_TRAVEL := 700.0
const NET_MIN_DISTANCE := 170.0
const NET_MAX_DISTANCE := 520.0
const NET_RADIUS := 26.0
const DEFLECT_FEEDBACK_DURATION := 0.28

var frog: PlayerFrog
var active := true
var speed := 250.0
var _catch_cooldown := 0.0
var _far_time := 0.0
var _chase_time := 0.0
var _no_progress_time := 0.0
var _last_position := Vector2.ZERO
var _net_phase := NetPhase.IDLE
var _net_cooldown := NET_INITIAL_COOLDOWN
var _net_windup_left := 0.0
var _net_target_position := Vector2.ZERO
var _net_position := Vector2.ZERO
var _net_velocity := Vector2.ZERO
var _net_travel := 0.0
var _frog_netted := false
var _net_tap_flash := 0.0
var _deflect_feedback_left := 0.0
var _presentation_motion_scale := 1.0
var _net_collision_shape := CircleShape2D.new()


func _ready() -> void:
	z_index = 5
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	collision.shape = shape
	add_child(collision)
	_net_collision_shape.radius = NET_RADIUS
	_last_position = global_position
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(frog):
		velocity = Vector2.ZERO
		return

	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)
	_net_cooldown = maxf(0.0, _net_cooldown - delta)
	_net_tap_flash = maxf(0.0, _net_tap_flash - delta * 4.0)
	if _deflect_feedback_left > 0.0:
		_deflect_feedback_left = maxf(
			0.0,
			_deflect_feedback_left - delta
		)
		queue_redraw()
	if _frog_netted:
		velocity = Vector2.ZERO
		queue_redraw()
		return

	_chase_time += delta
	var offset := frog.global_position - global_position
	if offset.length() > 920.0:
		_far_time += delta
	else:
		_far_time = maxf(0.0, _far_time - delta * 1.5)
	if _far_time >= 4.0 or _chase_time >= 32.0:
		_escape()
		return

	if _net_phase != NetPhase.IDLE:
		_advance_net_attack(delta)
		if _frog_netted:
			return
	if _net_phase == NetPhase.WINDUP:
		velocity = Vector2.ZERO
		_last_position = global_position
		queue_redraw()
		return

	if offset.length() > 4.0:
		velocity = offset.normalized() * speed
		rotation = velocity.angle() + PI / 2.0
		move_and_slide()

	if global_position.distance_to(_last_position) < 2.0:
		_no_progress_time += delta
	else:
		_no_progress_time = 0.0
	_last_position = global_position
	if _no_progress_time >= 2.5:
		_escape()
		return

	var catch_distance := 28.0 + frog.collision_radius() + 6.0
	if (
		frog.growth_tier < 2
		and _catch_cooldown <= 0.0
		and global_position.distance_to(frog.global_position) < catch_distance
	):
		_catch_cooldown = 2.0
		_net_cooldown = maxf(_net_cooldown, NET_RETRY_COOLDOWN)
		cancel_net_attack()
		caught.emit(global_position)
		return

	var distance_to_frog := global_position.distance_to(frog.global_position)
	if _can_start_net_attack(distance_to_frog):
		_begin_net_attack()


func set_presentation_motion_scale(value: float) -> void:
	_presentation_motion_scale = clampf(value, 0.0, 1.0)
	queue_redraw()


func active_net_projectile_count() -> int:
	return 1 if _net_phase == NetPhase.FLYING else 0


func net_attack_active() -> bool:
	return _net_phase != NetPhase.IDLE


func is_frog_netted() -> bool:
	return _frog_netted


func set_frog_netted(value: bool) -> void:
	_frog_netted = value
	if not value:
		_net_cooldown = maxf(_net_cooldown, NET_RETRY_COOLDOWN)
	queue_redraw()


func pulse_net() -> void:
	_net_tap_flash = 1.0
	queue_redraw()


func pulse_deflect() -> void:
	_deflect_feedback_left = DEFLECT_FEEDBACK_DURATION
	queue_redraw()


func deflect_feedback_active() -> bool:
	return _deflect_feedback_left > 0.0


func cancel_net_attack() -> void:
	_net_phase = NetPhase.IDLE
	_net_windup_left = 0.0
	_net_position = Vector2.ZERO
	_net_velocity = Vector2.ZERO
	_net_travel = 0.0
	queue_redraw()


func _can_start_net_attack(distance_to_frog: float) -> bool:
	return (
		_net_phase == NetPhase.IDLE
		and _net_cooldown <= 0.0
		and frog.growth_tier < 2
		and frog.movement_enabled
		and not frog.is_flying
		and distance_to_frog >= NET_MIN_DISTANCE
		and distance_to_frog <= NET_MAX_DISTANCE
		and _net_path_clear(global_position, frog.global_position)
	)


func _begin_net_attack() -> void:
	if not is_instance_valid(frog):
		return
	_net_phase = NetPhase.WINDUP
	_net_windup_left = NET_WINDUP_DURATION
	_net_target_position = frog.global_position
	velocity = Vector2.ZERO
	queue_redraw()


func _advance_net_attack(delta: float) -> void:
	if delta <= 0.0 or _net_phase == NetPhase.IDLE:
		return
	if (
		not is_instance_valid(frog)
		or frog.growth_tier >= 2
		or frog.is_flying
	):
		cancel_net_attack()
		return
	if _net_phase == NetPhase.WINDUP:
		_net_windup_left = maxf(0.0, _net_windup_left - delta)
		if _net_windup_left <= 0.0:
			var direction := (
				_net_target_position - global_position
			).normalized()
			if direction == Vector2.ZERO:
				cancel_net_attack()
				return
			_net_phase = NetPhase.FLYING
			_net_position = global_position
			_net_velocity = direction * NET_SPEED
			_net_travel = 0.0
			_net_cooldown = NET_RETRY_COOLDOWN
		queue_redraw()
		return

	var previous_position := _net_position
	var travel_step := _net_velocity * delta
	var remaining_travel := NET_MAX_TRAVEL - _net_travel
	if travel_step.length() > remaining_travel:
		travel_step = travel_step.normalized() * remaining_travel
	var next_position := previous_position + travel_step
	var closest_to_frog := Geometry2D.get_closest_point_to_segment(
		frog.global_position,
		previous_position,
		next_position
	)
	var hits_frog := (
		closest_to_frog.distance_to(frog.global_position)
		<= NET_RADIUS + frog.collision_radius()
	)
	var obstruction := _first_net_obstruction(
		previous_position,
		next_position
	)
	var obstruction_distance := (
		previous_position.distance_to(
			obstruction.get("position", previous_position) as Vector2
		)
		if not obstruction.is_empty()
		else INF
	)
	if (
		hits_frog
		and previous_position.distance_to(closest_to_frog)
		<= obstruction_distance
	):
		cancel_net_attack()
		_frog_netted = true
		netted.emit(global_position)
		queue_redraw()
		return
	if not obstruction.is_empty():
		cancel_net_attack()
		return

	_net_position = next_position
	_net_travel += travel_step.length()
	if _net_travel >= NET_MAX_TRAVEL:
		cancel_net_attack()
	else:
		queue_redraw()


func _net_path_clear(from: Vector2, to: Vector2) -> bool:
	return _first_net_obstruction(from, to).is_empty()


func _first_net_obstruction(from: Vector2, to: Vector2) -> Dictionary:
	if not is_inside_tree() or not is_instance_valid(frog):
		return {}
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _net_collision_shape
	query.transform = Transform2D(0.0, from)
	query.motion = to - from
	query.collision_mask = 1
	query.exclude = [get_rid(), frog.get_rid()]
	var collision_fractions := (
		get_world_2d().direct_space_state.cast_motion(query)
	)
	if (
		collision_fractions.is_empty()
		or collision_fractions[0] >= 1.0
	):
		return {}
	return {
		"position": from.lerp(to, float(collision_fractions[0])),
	}


func _escape() -> void:
	active = false
	cancel_net_attack()
	escaped.emit()
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 31.0, Color("da7462"))
	draw_rect(Rect2(-20, -37, 40, 30), Color("416c9a"))
	draw_circle(Vector2(-11, -25), 4.0, Color.WHITE)
	draw_circle(Vector2(11, -25), 4.0, Color.WHITE)
	draw_circle(Vector2(-11, -25), 2.0, Color("1d2328"))
	draw_circle(Vector2(11, -25), 2.0, Color("1d2328"))
	draw_line(Vector2(-18, 30), Vector2(-25, 47), Color("263642"), 8.0)
	draw_line(Vector2(18, 30), Vector2(25, 47), Color("263642"), 8.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-55, -52),
		"Animal Control",
		HORIZONTAL_ALIGNMENT_CENTER,
		110,
		15,
		Color.WHITE
	)
	_draw_net_attack()
	_draw_deflect_feedback()


func _draw_deflect_feedback() -> void:
	if _deflect_feedback_left <= 0.0:
		return
	var strength := clampf(
		_deflect_feedback_left / DEFLECT_FEEDBACK_DURATION,
		0.0,
		1.0
	)
	var expansion := (
		(1.0 - strength) * 8.0 * _presentation_motion_scale
	)
	draw_arc(
		Vector2.ZERO,
		38.0 + expansion,
		-PI * 0.82,
		PI * 0.18,
		18,
		Color(0.96, 0.88, 0.48, 0.9 * strength),
		5.0
	)


func _draw_net_attack() -> void:
	if _net_phase == NetPhase.WINDUP:
		var target := to_local(_net_target_position)
		var progress := (
			1.0 - _net_windup_left / NET_WINDUP_DURATION
		)
		var pulse := (
			sin(progress * TAU * 2.0) * 5.0
			* _presentation_motion_scale
		)
		draw_line(
			Vector2.ZERO,
			target,
			Color(0.76, 0.9, 0.94, 0.45),
			3.0
		)
		draw_arc(
			target,
			NET_RADIUS + 12.0 + pulse,
			0.0,
			TAU,
			24,
			Color(0.82, 0.95, 1.0, 0.85),
			4.0
		)
	elif _net_phase == NetPhase.FLYING:
		_draw_net(
			to_local(_net_position),
			NET_RADIUS,
			_chase_time * 5.0 * _presentation_motion_scale,
			0.9
		)
	if _frog_netted and is_instance_valid(frog):
		var frog_position := to_local(frog.global_position)
		draw_line(
			Vector2.ZERO,
			frog_position,
			Color(0.68, 0.8, 0.82, 0.72),
			3.0
		)
		_draw_net(
			frog_position,
			_trapped_net_radius(),
			0.0,
			1.0
		)


func _trapped_net_radius() -> float:
	if not is_instance_valid(frog):
		return 0.0
	return (
		frog.collision_radius()
		+ 14.0
		+ _net_tap_flash * 5.0 * _presentation_motion_scale
	)


func _draw_net(
	center: Vector2,
	radius: float,
	angle: float,
	alpha: float
) -> void:
	var net_color := Color(0.82, 0.92, 0.92, alpha)
	var fill_color := Color(0.28, 0.42, 0.44, alpha * 0.24)
	draw_set_transform(center, angle, Vector2.ONE)
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, net_color, 3.0)
	for offset_index in range(-2, 3):
		var offset := float(offset_index) * radius * 0.34
		var span := sqrt(maxf(radius * radius - offset * offset, 0.0))
		draw_line(
			Vector2(offset, -span),
			Vector2(offset, span),
			net_color,
			2.0
		)
		draw_line(
			Vector2(-span, offset),
			Vector2(span, offset),
			net_color,
			2.0
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func hit_test(world_point: Vector2) -> bool:
	return global_position.distance_to(world_point) <= 40.0


func hit_accuracy(world_point: Vector2) -> float:
	return clampf(1.0 - global_position.distance_to(world_point) / 40.0, 0.0, 1.0)
