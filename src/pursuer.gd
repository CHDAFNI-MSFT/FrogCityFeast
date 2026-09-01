class_name PrototypePursuer
extends CharacterBody2D

signal caught(source_position: Vector2)
signal escaped
signal netted(source_position: Vector2)
signal attack_hit(source_position: Vector2, penalty: int, message: String)

const ARCHETYPE_ANIMAL_CONTROL := "animal_control"
const ARCHETYPE_SECURITY_GUARD := "security_guard"
const ARCHETYPE_WATCHDOG := "watchdog"

enum NetPhase {
	IDLE,
	WINDUP,
	FLYING,
}

enum LungePhase {
	IDLE,
	WINDUP,
	DASH,
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
const NAVIGATION_RADIUS := 28.0
const NAVIGATION_REPATH_INTERVAL := 0.35
const NAVIGATION_TARGET_MOVEMENT := 72.0
const NAVIGATION_WAYPOINT_TOLERANCE := 1.0
const NAVIGATION_STUCK_REPATH_TIME := 0.75
const NAVIGATION_STUCK_ESCAPE_TIME := 6.0
const SECURITY_DETECTION_RANGE := 760.0
const SECURITY_LOST_ESCAPE_TIME := 3.2
const SECURITY_MAX_CHASE_TIME := 26.0
const SECURITY_SPEED := 205.0
const SECURITY_NAVIGATION_RADIUS := 30.0
const SECURITY_NAVIGATION_REPATH_INTERVAL := 0.45
const SECURITY_FLASHLIGHT_INITIAL_COOLDOWN := 1.4
const SECURITY_FLASHLIGHT_RETRY_COOLDOWN := 4.5
const SECURITY_FLASHLIGHT_WINDUP_DURATION := 0.65
const SECURITY_FLASHLIGHT_MIN_DISTANCE := 140.0
const SECURITY_FLASHLIGHT_MAX_DISTANCE := 430.0
const SECURITY_FLASHLIGHT_RADIUS := 24.0
const SECURITY_PROTECTION_RADIUS := 260.0
const SECURITY_CROWD_ESCAPE_DURATION := 1.1
const SECURITY_CONTACT_PENALTY := 18
const SECURITY_FLASHLIGHT_PENALTY := 12
const SECURITY_PROTECTED_KINDS := [
	"object",
	"vehicle",
	"building_part",
	"building",
]
const WATCHDOG_DETECTION_RANGE := 860.0
const WATCHDOG_LOST_ESCAPE_TIME := 1.4
const WATCHDOG_MAX_CHASE_TIME := 22.0
const WATCHDOG_SPEED := 320.0
const WATCHDOG_NAVIGATION_RADIUS := 22.0
const WATCHDOG_NAVIGATION_REPATH_INTERVAL := 0.22
const WATCHDOG_NAVIGATION_TARGET_MOVEMENT := 48.0
const WATCHDOG_LUNGE_INITIAL_COOLDOWN := 1.0
const WATCHDOG_LUNGE_RETRY_COOLDOWN := 4.2
const WATCHDOG_LUNGE_WINDUP_DURATION := 0.45
const WATCHDOG_LUNGE_SPEED := 720.0
const WATCHDOG_LUNGE_TRAVEL := 220.0
const WATCHDOG_LUNGE_MIN_DISTANCE := 120.0
const WATCHDOG_LUNGE_MAX_DISTANCE := 360.0
const WATCHDOG_LUNGE_HIT_RADIUS := 22.0
const WATCHDOG_PROTECTION_RADIUS := 210.0
const WATCHDOG_CROWD_ESCAPE_DURATION := 0.8
const WATCHDOG_CONTACT_PENALTY := 14
const WATCHDOG_LUNGE_PENALTY := 16
const ANIMAL_CONTROL_TRAP_DEPLOY_DELAY := 6.0
const SECURITY_TRAP_DEPLOY_DELAY := 5.0
const WATCHDOG_TRAP_DEPLOY_DELAY := 4.0

var frog: PlayerFrog
var navigation: DeterministicNavigation2D
var archetype_id := ARCHETYPE_ANIMAL_CONTROL
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
var _navigation_path := PackedVector2Array()
var _navigation_path_index := 0
var _navigation_revision := -1
var _navigation_repath_left := 0.0
var _navigation_target_position := Vector2.INF
var _navigation_repath_count := 0
var _navigation_failure_count := 0
var _navigation_reaches_frog := false
var _frog_detected := true
var _last_detected_frog_position := Vector2.INF
var _flashlight_cooldown := SECURITY_FLASHLIGHT_INITIAL_COOLDOWN
var _flashlight_windup_left := 0.0
var _flashlight_target_position := Vector2.ZERO
var _lunge_phase := LungePhase.IDLE
var _lunge_cooldown := WATCHDOG_LUNGE_INITIAL_COOLDOWN
var _lunge_target_position := Vector2.ZERO
var _lunge_direction := Vector2.ZERO
var _lunge_travel := 0.0
var _lunge_windup_left := 0.0
var _forced_detection_left := 0.0


func _ready() -> void:
	z_index = 5
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = collision_radius()
	collision.shape = shape
	add_child(collision)
	_net_collision_shape.radius = NET_RADIUS
	_last_position = global_position
	if is_instance_valid(frog):
		_last_detected_frog_position = frog.global_position
	queue_redraw()


func configure_archetype(value: String) -> void:
	match value:
		ARCHETYPE_ANIMAL_CONTROL:
			archetype_id = value
			speed = 250.0
		ARCHETYPE_SECURITY_GUARD:
			archetype_id = value
			speed = SECURITY_SPEED
		ARCHETYPE_WATCHDOG:
			archetype_id = value
			speed = WATCHDOG_SPEED
		_:
			push_error("Unknown pursuer archetype: %s." % value)
			archetype_id = ARCHETYPE_ANIMAL_CONTROL
			speed = 250.0


static func display_name_for(value: String) -> String:
	match value:
		ARCHETYPE_SECURITY_GUARD:
			return "Security Guard"
		ARCHETYPE_WATCHDOG:
			return "Watchdog"
		_:
			return "Animal Control"


func display_name() -> String:
	return display_name_for(archetype_id)


func discovery_id() -> String:
	return archetype_id


func belly_data() -> Dictionary:
	if archetype_id == ARCHETYPE_SECURITY_GUARD:
		return {
			"id": ARCHETYPE_SECURITY_GUARD,
			"name": "Security Guard",
			"value": 88,
			"taps": 9,
			"color": Color("c69a63"),
		}
	if archetype_id == ARCHETYPE_WATCHDOG:
		return {
			"id": ARCHETYPE_WATCHDOG,
			"name": "Watchdog",
			"value": 82,
			"taps": 8,
			"color": Color("9a6844"),
		}
	return {
		"id": ARCHETYPE_ANIMAL_CONTROL,
		"name": "Animal Control Officer",
		"value": 95,
		"taps": 10,
		"color": Color("da7462"),
	}


func collision_radius() -> float:
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			return 30.0
		ARCHETYPE_WATCHDOG:
			return WATCHDOG_NAVIGATION_RADIUS
		_:
			return 28.0


func navigation_radius() -> float:
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			return SECURITY_NAVIGATION_RADIUS
		ARCHETYPE_WATCHDOG:
			return WATCHDOG_NAVIGATION_RADIUS
		_:
			return NAVIGATION_RADIUS


func crowd_escape_duration() -> float:
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			return SECURITY_CROWD_ESCAPE_DURATION
		ARCHETYPE_WATCHDOG:
			return WATCHDOG_CROWD_ESCAPE_DURATION
		_:
			return 1.75


func contact_penalty() -> int:
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			return SECURITY_CONTACT_PENALTY
		ARCHETYPE_WATCHDOG:
			return WATCHDOG_CONTACT_PENALTY
		_:
			return 25


func deploys_roadblock() -> bool:
	return archetype_id == ARCHETYPE_ANIMAL_CONTROL


func deploys_pursuit_trap() -> bool:
	return true


func pursuit_trap_variant() -> String:
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			return PrototypePursuitTrap.VARIANT_MOTION_BEACON
		ARCHETYPE_WATCHDOG:
			return PrototypePursuitTrap.VARIANT_STICKY_PATCH
		_:
			return PrototypePursuitTrap.VARIANT_SNARE


func pursuit_trap_deploy_delay() -> float:
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			return SECURITY_TRAP_DEPLOY_DELAY
		ARCHETYPE_WATCHDOG:
			return WATCHDOG_TRAP_DEPLOY_DELAY
		_:
			return ANIMAL_CONTROL_TRAP_DEPLOY_DELAY


func protects_target(target: EdibleTarget) -> bool:
	if archetype_id == ARCHETYPE_ANIMAL_CONTROL:
		return true
	if not is_instance_valid(target):
		return false
	if archetype_id == ARCHETYPE_SECURITY_GUARD:
		return (
			target.kind in SECURITY_PROTECTED_KINDS
			and target.global_position.distance_to(global_position)
				<= SECURITY_PROTECTION_RADIUS
		)
	if archetype_id == ARCHETYPE_WATCHDOG:
		return (
			target.kind == "living"
			and target.global_position.distance_to(global_position)
				<= WATCHDOG_PROTECTION_RADIUS
		)
	return false


func protection_status() -> String:
	if archetype_id == ARCHETYPE_ANIMAL_CONTROL:
		return "Animal Control deflected the tongue!"
	if archetype_id == ARCHETYPE_WATCHDOG:
		return "The Watchdog knocked the tongue aside!"
	return "%s blocked the tongue!" % display_name()


func frog_detected() -> bool:
	return _frog_detected


func flashlight_attack_active() -> bool:
	return _flashlight_windup_left > 0.0


func lunge_attack_active() -> bool:
	return _lunge_phase != LungePhase.IDLE


func reveal_frog(position: Vector2, duration: float) -> void:
	_last_detected_frog_position = position
	_forced_detection_left = maxf(
		_forced_detection_left,
		maxf(0.0, duration)
	)
	_far_time = 0.0
	_frog_detected = true
	invalidate_navigation()


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(frog):
		velocity = Vector2.ZERO
		return

	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)
	_net_cooldown = maxf(0.0, _net_cooldown - delta)
	_flashlight_cooldown = maxf(0.0, _flashlight_cooldown - delta)
	_lunge_cooldown = maxf(0.0, _lunge_cooldown - delta)
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
	_update_detection(delta)
	var offset := frog.global_position - global_position
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			if _frog_detected:
				_far_time = 0.0
			else:
				_far_time += delta
			if (
				_far_time >= SECURITY_LOST_ESCAPE_TIME
				or _chase_time >= SECURITY_MAX_CHASE_TIME
			):
				_escape()
				return
		ARCHETYPE_WATCHDOG:
			if _frog_detected:
				_far_time = 0.0
			else:
				_far_time += delta
			if (
				_far_time >= WATCHDOG_LOST_ESCAPE_TIME
				or _chase_time >= WATCHDOG_MAX_CHASE_TIME
			):
				_escape()
				return
		_:
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
	if flashlight_attack_active():
		_advance_flashlight_attack(delta)
		_last_position = global_position
		queue_redraw()
		return
	if lunge_attack_active():
		_advance_lunge_attack(delta)
		_last_position = global_position
		queue_redraw()
		return

	_navigation_repath_left = maxf(
		0.0,
		_navigation_repath_left - delta
	)
	if _navigation_needs_refresh():
		_refresh_navigation_path()
	var waypoint := _current_navigation_waypoint()
	while (
		waypoint != Vector2.INF
		and global_position.distance_to(waypoint)
		<= NAVIGATION_WAYPOINT_TOLERANCE
	):
		if _navigation_path_index < _navigation_path.size() - 1:
			_navigation_path_index += 1
			waypoint = _current_navigation_waypoint()
		else:
			_navigation_path = PackedVector2Array()
			_navigation_path_index = 0
			waypoint = Vector2.INF
	if waypoint != Vector2.INF:
		var waypoint_offset := waypoint - global_position
		velocity = waypoint_offset.normalized() * minf(
			speed,
			waypoint_offset.length() / maxf(delta, 0.0001)
		)
		rotation = velocity.angle() + PI / 2.0
		move_and_slide()
	else:
		velocity = Vector2.ZERO

	var was_stuck := (
		_no_progress_time >= NAVIGATION_STUCK_REPATH_TIME
	)
	if global_position.distance_to(_last_position) < 2.0:
		_no_progress_time += delta
	else:
		_no_progress_time = 0.0
	_last_position = global_position
	if (
		not was_stuck
		and _no_progress_time >= NAVIGATION_STUCK_REPATH_TIME
	):
		_navigation_path = PackedVector2Array()
		_navigation_path_index = 0
		_navigation_repath_left = 0.0
	if _no_progress_time >= NAVIGATION_STUCK_ESCAPE_TIME:
		_escape()
		return

	var catch_distance := collision_radius() + frog.collision_radius() + 6.0
	if (
		frog.growth_tier < 2
		and not frog.is_flying
		and _catch_cooldown <= 0.0
		and global_position.distance_to(frog.global_position) < catch_distance
	):
		_catch_cooldown = 2.0
		_net_cooldown = maxf(_net_cooldown, NET_RETRY_COOLDOWN)
		cancel_active_attack()
		caught.emit(global_position)
		return

	var distance_to_frog := global_position.distance_to(frog.global_position)
	if _can_start_net_attack(distance_to_frog):
		_begin_net_attack()
	elif _can_start_flashlight_attack(distance_to_frog):
		_begin_flashlight_attack()
	elif _can_start_lunge_attack(distance_to_frog):
		_begin_lunge_attack()


func set_presentation_motion_scale(value: float) -> void:
	_presentation_motion_scale = clampf(value, 0.0, 1.0)
	queue_redraw()


func invalidate_navigation() -> void:
	_navigation_path = PackedVector2Array()
	_navigation_path_index = 0
	_navigation_revision = -1
	_navigation_repath_left = 0.0
	_navigation_target_position = Vector2.INF
	_navigation_reaches_frog = false
	velocity = Vector2.ZERO


func cancel_active_attack() -> void:
	cancel_net_attack()
	_flashlight_windup_left = 0.0
	_flashlight_target_position = Vector2.ZERO
	_lunge_phase = LungePhase.IDLE
	_lunge_target_position = Vector2.ZERO
	_lunge_direction = Vector2.ZERO
	_lunge_travel = 0.0
	_lunge_windup_left = 0.0
	velocity = Vector2.ZERO
	queue_redraw()


func active_navigation_point_count() -> int:
	return _navigation_path.size()


func navigation_repath_count() -> int:
	return _navigation_repath_count


func navigation_failure_count() -> int:
	return _navigation_failure_count


func navigation_reaches_frog() -> bool:
	return _navigation_reaches_frog


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


func _update_detection(delta: float = 0.0) -> void:
	if not is_instance_valid(frog):
		_frog_detected = false
		return
	_forced_detection_left = maxf(
		0.0,
		_forced_detection_left - maxf(0.0, delta)
	)
	if _forced_detection_left > 0.0 and not frog.is_flying:
		_frog_detected = true
		_last_detected_frog_position = frog.global_position
		return
	if archetype_id == ARCHETYPE_SECURITY_GUARD:
		_frog_detected = (
			not frog.is_flying
			and global_position.distance_to(frog.global_position)
				<= SECURITY_DETECTION_RANGE
			and _line_of_sight_clear(
				global_position,
				frog.global_position
			)
		)
	elif archetype_id == ARCHETYPE_WATCHDOG:
		_frog_detected = (
			not frog.is_flying
			and global_position.distance_to(frog.global_position)
				<= WATCHDOG_DETECTION_RANGE
		)
	else:
		_frog_detected = (
			global_position.distance_to(frog.global_position) <= 920.0
		)
	if _frog_detected:
		_last_detected_frog_position = frog.global_position


func _line_of_sight_clear(from: Vector2, to: Vector2) -> bool:
	if not is_inside_tree() or not is_instance_valid(frog):
		return false
	var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
	ray.exclude = [get_rid(), frog.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _chase_target_position() -> Vector2:
	if _frog_detected or _last_detected_frog_position == Vector2.INF:
		return frog.global_position
	return _last_detected_frog_position


func _navigation_needs_refresh() -> bool:
	if navigation == null or not is_instance_valid(frog):
		return false
	if _navigation_revision != navigation.revision():
		return true
	if _navigation_repath_left > 0.0:
		return false
	var chase_target := _chase_target_position()
	var target_movement := (
		WATCHDOG_NAVIGATION_TARGET_MOVEMENT
		if archetype_id == ARCHETYPE_WATCHDOG
		else NAVIGATION_TARGET_MOVEMENT
	)
	return (
		_navigation_path.is_empty()
		or _navigation_target_position.distance_to(chase_target)
			>= target_movement
	)


func _refresh_navigation_path() -> void:
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			_navigation_repath_left = SECURITY_NAVIGATION_REPATH_INTERVAL
		ARCHETYPE_WATCHDOG:
			_navigation_repath_left = WATCHDOG_NAVIGATION_REPATH_INTERVAL
		_:
			_navigation_repath_left = NAVIGATION_REPATH_INTERVAL
	_navigation_target_position = _chase_target_position()
	_navigation_repath_count += 1
	var route := navigation.find_path(
		global_position,
		_navigation_target_position,
		navigation_radius()
	)
	var points := route["points"] as PackedVector2Array
	_navigation_revision = int(route["revision"])
	_navigation_reaches_frog = bool(route["reachable"])
	if points.size() < 2:
		_navigation_path = PackedVector2Array()
		_navigation_path_index = 0
		_navigation_failure_count += 1
		return
	_navigation_path = points
	_navigation_path_index = 1


func _current_navigation_waypoint() -> Vector2:
	if (
		_navigation_path_index >= 0
		and _navigation_path_index < _navigation_path.size()
	):
		return _navigation_path[_navigation_path_index]
	return Vector2.INF


func _can_start_net_attack(distance_to_frog: float) -> bool:
	return (
		archetype_id == ARCHETYPE_ANIMAL_CONTROL
		and _net_phase == NetPhase.IDLE
		and _net_cooldown <= 0.0
		and _frog_detected
		and frog.growth_tier < 2
		and frog.movement_enabled
		and not frog.is_flying
		and distance_to_frog >= NET_MIN_DISTANCE
		and distance_to_frog <= NET_MAX_DISTANCE
		and _net_path_clear(global_position, frog.global_position)
	)


func _can_start_flashlight_attack(distance_to_frog: float) -> bool:
	return (
		archetype_id == ARCHETYPE_SECURITY_GUARD
		and not flashlight_attack_active()
		and _flashlight_cooldown <= 0.0
		and _frog_detected
		and frog.growth_tier < 2
		and frog.movement_enabled
		and not frog.is_flying
		and distance_to_frog >= SECURITY_FLASHLIGHT_MIN_DISTANCE
		and distance_to_frog <= SECURITY_FLASHLIGHT_MAX_DISTANCE
	)


func _can_start_lunge_attack(distance_to_frog: float) -> bool:
	return (
		archetype_id == ARCHETYPE_WATCHDOG
		and not lunge_attack_active()
		and _lunge_cooldown <= 0.0
		and _frog_detected
		and frog.growth_tier < 2
		and frog.movement_enabled
		and not frog.is_flying
		and distance_to_frog >= WATCHDOG_LUNGE_MIN_DISTANCE
		and distance_to_frog <= WATCHDOG_LUNGE_MAX_DISTANCE
	)


func _begin_net_attack() -> void:
	if (
		archetype_id != ARCHETYPE_ANIMAL_CONTROL
		or not is_instance_valid(frog)
	):
		return
	_net_phase = NetPhase.WINDUP
	_net_windup_left = NET_WINDUP_DURATION
	_net_target_position = frog.global_position
	velocity = Vector2.ZERO
	queue_redraw()


func _begin_flashlight_attack() -> void:
	if (
		archetype_id != ARCHETYPE_SECURITY_GUARD
		or not is_instance_valid(frog)
	):
		return
	_flashlight_windup_left = SECURITY_FLASHLIGHT_WINDUP_DURATION
	_flashlight_target_position = frog.global_position
	velocity = Vector2.ZERO
	queue_redraw()


func _advance_flashlight_attack(delta: float) -> void:
	if not flashlight_attack_active() or delta <= 0.0:
		return
	if (
		not is_instance_valid(frog)
		or frog.growth_tier >= 2
		or frog.is_flying
	):
		_flashlight_windup_left = 0.0
		_flashlight_target_position = Vector2.ZERO
		queue_redraw()
		return
	_flashlight_windup_left = maxf(
		0.0,
		_flashlight_windup_left - delta
	)
	if _flashlight_windup_left > 0.0:
		queue_redraw()
		return
	var closest_to_frog := Geometry2D.get_closest_point_to_segment(
		frog.global_position,
		global_position,
		_flashlight_target_position
	)
	var hits_frog := (
		closest_to_frog.distance_to(frog.global_position)
		<= SECURITY_FLASHLIGHT_RADIUS + frog.collision_radius()
		and _line_of_sight_clear(global_position, closest_to_frog)
	)
	_flashlight_target_position = Vector2.ZERO
	_flashlight_cooldown = SECURITY_FLASHLIGHT_RETRY_COOLDOWN
	if hits_frog:
		_catch_cooldown = maxf(_catch_cooldown, 1.0)
		attack_hit.emit(
			global_position,
			SECURITY_FLASHLIGHT_PENALTY,
			"A Security Guard's flashlight startled the frog!"
		)
	queue_redraw()


func _begin_lunge_attack() -> void:
	if (
		archetype_id != ARCHETYPE_WATCHDOG
		or not is_instance_valid(frog)
	):
		return
	_lunge_phase = LungePhase.WINDUP
	_lunge_windup_left = WATCHDOG_LUNGE_WINDUP_DURATION
	_lunge_target_position = frog.global_position
	_lunge_direction = Vector2.ZERO
	_lunge_travel = 0.0
	velocity = Vector2.ZERO
	queue_redraw()


func _advance_lunge_attack(delta: float) -> void:
	if not lunge_attack_active() or delta <= 0.0:
		return
	if (
		not is_instance_valid(frog)
		or frog.growth_tier >= 2
		or frog.is_flying
	):
		_finish_lunge_attack()
		return
	if _lunge_phase == LungePhase.WINDUP:
		_lunge_windup_left = maxf(
			0.0,
			_lunge_windup_left - delta
		)
		if _lunge_windup_left > 0.0:
			queue_redraw()
			return
		_lunge_direction = (
			_lunge_target_position - global_position
		).normalized()
		if _lunge_direction == Vector2.ZERO:
			_finish_lunge_attack()
			return
		_lunge_phase = LungePhase.DASH
		velocity = _lunge_direction * WATCHDOG_LUNGE_SPEED
		rotation = velocity.angle() + PI / 2.0
		queue_redraw()
		return

	var remaining := WATCHDOG_LUNGE_TRAVEL - _lunge_travel
	var step_distance := minf(
		WATCHDOG_LUNGE_SPEED * delta,
		remaining
	)
	var previous_position := global_position
	var collision := move_and_collide(
		_lunge_direction * step_distance
	)
	var actual_distance := previous_position.distance_to(global_position)
	_lunge_travel += actual_distance
	var closest_to_frog := Geometry2D.get_closest_point_to_segment(
		frog.global_position,
		previous_position,
		global_position
	)
	if (
		closest_to_frog.distance_to(frog.global_position)
		<= WATCHDOG_LUNGE_HIT_RADIUS + frog.collision_radius()
	):
		_catch_cooldown = maxf(_catch_cooldown, 1.0)
		attack_hit.emit(
			global_position,
			WATCHDOG_LUNGE_PENALTY,
			"The Watchdog's lunge knocked the frog back!"
		)
		_finish_lunge_attack()
		return
	if collision != null or _lunge_travel >= WATCHDOG_LUNGE_TRAVEL:
		_finish_lunge_attack()
	else:
		queue_redraw()


func _finish_lunge_attack() -> void:
	_lunge_phase = LungePhase.IDLE
	_lunge_cooldown = WATCHDOG_LUNGE_RETRY_COOLDOWN
	_lunge_target_position = Vector2.ZERO
	_lunge_direction = Vector2.ZERO
	_lunge_travel = 0.0
	_lunge_windup_left = 0.0
	velocity = Vector2.ZERO
	queue_redraw()


func _advance_net_attack(delta: float) -> void:
	if delta <= 0.0 or _net_phase == NetPhase.IDLE:
		return
	if archetype_id != ARCHETYPE_ANIMAL_CONTROL:
		cancel_net_attack()
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
	cancel_active_attack()
	escaped.emit()
	queue_free()


func _draw() -> void:
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			_draw_security_guard()
		ARCHETYPE_WATCHDOG:
			_draw_watchdog()
		_:
			_draw_animal_control()
	_draw_attack()
	_draw_deflect_feedback()


func _draw_animal_control() -> void:
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


func _draw_security_guard() -> void:
	draw_circle(Vector2.ZERO, 32.0, Color("c69a63"))
	draw_rect(Rect2(-21, -38, 42, 31), Color("3f435a"))
	draw_rect(Rect2(-25, -42, 50, 8), Color("292c3d"))
	draw_circle(Vector2(-11, -25), 4.0, Color.WHITE)
	draw_circle(Vector2(11, -25), 4.0, Color.WHITE)
	draw_circle(Vector2(-11, -25), 2.0, Color("1d2328"))
	draw_circle(Vector2(11, -25), 2.0, Color("1d2328"))
	draw_line(Vector2(-18, 30), Vector2(-25, 47), Color("282b39"), 8.0)
	draw_line(Vector2(18, 30), Vector2(25, 47), Color("282b39"), 8.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-55, -54),
		"Security Guard",
		HORIZONTAL_ALIGNMENT_CENTER,
		110,
		15,
		Color.WHITE
	)


func _draw_watchdog() -> void:
	draw_circle(Vector2(0, 5), 24.0, Color("9a6844"))
	draw_circle(Vector2(0, -18), 19.0, Color("b47b4e"))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-17, -29),
			Vector2(-30, -43),
			Vector2(-23, -18),
		]),
		Color("70452f")
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(17, -29),
			Vector2(30, -43),
			Vector2(23, -18),
		]),
		Color("70452f")
	)
	draw_circle(Vector2(-7, -20), 3.0, Color("1d2328"))
	draw_circle(Vector2(7, -20), 3.0, Color("1d2328"))
	draw_circle(Vector2(0, -10), 4.0, Color("33251f"))
	draw_line(Vector2(-15, 24), Vector2(-20, 38), Color("70452f"), 7.0)
	draw_line(Vector2(15, 24), Vector2(20, 38), Color("70452f"), 7.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-55, -52),
		"Watchdog",
		HORIZONTAL_ALIGNMENT_CENTER,
		110,
		15,
		Color.WHITE
	)


func _draw_attack() -> void:
	match archetype_id:
		ARCHETYPE_SECURITY_GUARD:
			_draw_flashlight_attack()
		ARCHETYPE_WATCHDOG:
			_draw_lunge_attack()
		_:
			_draw_net_attack()


func _draw_flashlight_attack() -> void:
	if not flashlight_attack_active():
		return
	var target := to_local(_flashlight_target_position)
	var progress := (
		1.0
		- _flashlight_windup_left
			/ SECURITY_FLASHLIGHT_WINDUP_DURATION
	)
	var pulse := (
		sin(progress * TAU * 2.0)
		* 5.0
		* _presentation_motion_scale
	)
	var direction := target.normalized()
	var perpendicular := direction.orthogonal()
	var beam_half_width := SECURITY_FLASHLIGHT_RADIUS + 6.0 + pulse
	var beam_color := Color(1.0, 0.92, 0.52, 0.18)
	var beam_points := PackedVector2Array([
		perpendicular * 8.0,
		target + perpendicular * beam_half_width,
		target - perpendicular * beam_half_width,
		-perpendicular * 8.0,
	])
	draw_colored_polygon(beam_points, beam_color)
	draw_line(
		Vector2.ZERO,
		target,
		Color(1.0, 0.94, 0.68, 0.72),
		3.0
	)
	draw_arc(
		target,
		SECURITY_FLASHLIGHT_RADIUS + 10.0 + pulse,
		0.0,
		TAU,
		24,
		Color(1.0, 0.9, 0.42, 0.9),
		4.0
	)


func _draw_lunge_attack() -> void:
	if not lunge_attack_active():
		return
	if _lunge_phase == LungePhase.WINDUP:
		var target := to_local(_lunge_target_position)
		var progress := (
			1.0
			- _lunge_windup_left / WATCHDOG_LUNGE_WINDUP_DURATION
		)
		var pulse := (
			sin(progress * TAU * 2.0)
			* 4.0
			* _presentation_motion_scale
		)
		draw_line(
			Vector2.ZERO,
			target,
			Color(0.96, 0.48, 0.3, 0.66),
			4.0
		)
		draw_arc(
			target,
			WATCHDOG_LUNGE_HIT_RADIUS + 12.0 + pulse,
			0.0,
			TAU,
			24,
			Color(1.0, 0.68, 0.38, 0.9),
			4.0
		)
	elif _presentation_motion_scale > 0.0:
		draw_line(
			Vector2.ZERO,
			-_lunge_direction * 38.0,
			Color(0.92, 0.7, 0.48, 0.55),
			8.0
		)


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
