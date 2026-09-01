class_name EdibleTarget
extends Node2D

const ART := preload("res://src/production_art.gd")

var target_id := ""
var display_name := "Snack"
var kind := "food"
var base_value := 10
var size_tier := 0
var rare := false
var resistant := false
var taps_required := 0
var pick_radius := 28.0
var target_color := Color("f5a84b")
var velocity := Vector2.ZERO
var move_bounds := Rect2()
var unpredictable := false
var dangerous_location := false
var is_vehicle := false
var latched := false
var restockable := true
var building_id := ""
var building_part_id := ""
var selectable := true
var highlighted := false
var world_instance_id := ""
var district_coordinate := Vector2i.ZERO
var motion_seed := 0
var world_state_dirty := false

var _turn_timer := 0.0
var _motion_rng: RandomNumberGenerator
var _presentation_scale := 1.0
var _feedback_time := 0.0
var _feedback_amount := 0.0
var _feedback_motion_scale := 1.0
var _presentation_motion_scale := 1.0
var _motion_time := 0.0


func _ready() -> void:
	if motion_seed != 0:
		_motion_rng = RandomNumberGenerator.new()
		_motion_rng.seed = motion_seed
	_turn_timer = _motion_randf_range(0.7, 1.8)
	z_index = 4
	queue_redraw()


func _process(delta: float) -> void:
	if (
		_presentation_motion_scale > 0.0
		and (
			velocity.length_squared() > 1.0
			or highlighted
			or _feedback_time > 0.0
		)
	):
		_motion_time = fmod(_motion_time + delta, TAU * 8.0)
		queue_redraw()
	if _feedback_time > 0.0:
		_feedback_time = maxf(0.0, _feedback_time - delta)
		var progress := 1.0 - _feedback_time / 0.16
		_feedback_amount = sin(progress * PI)
		queue_redraw()
	elif _feedback_amount != 0.0:
		_feedback_amount = 0.0
		queue_redraw()
	if highlighted:
		queue_redraw()
	if latched or velocity == Vector2.ZERO:
		return

	if unpredictable:
		_turn_timer -= delta
		if _turn_timer <= 0.0:
			velocity = velocity.rotated(_motion_randf_range(-1.1, 1.1))
			_turn_timer = _motion_randf_range(0.55, 1.5)

	position += velocity * delta
	if not world_instance_id.is_empty():
		world_state_dirty = true
	if move_bounds.size != Vector2.ZERO:
		if position.x < move_bounds.position.x:
			position.x = move_bounds.position.x
			velocity.x = absf(velocity.x)
		elif position.x > move_bounds.end.x:
			position.x = move_bounds.end.x
			velocity.x = -absf(velocity.x)
		if position.y < move_bounds.position.y:
			position.y = move_bounds.position.y
			velocity.y = absf(velocity.y)
		elif position.y > move_bounds.end.y:
			position.y = move_bounds.end.y
			velocity.y = -absf(velocity.y)


func hit_test(world_point: Vector2) -> bool:
	return (
		selectable
		and global_position.distance_to(world_point) <= pick_radius * _presentation_scale
	)


func hit_accuracy(world_point: Vector2) -> float:
	var distance := global_position.distance_to(world_point)
	return clampf(1.0 - distance / (pick_radius * _presentation_scale), 0.0, 1.0)


func can_be_swallowed(frog_tier: int) -> bool:
	return frog_tier >= size_tier


func set_latched(value: bool) -> void:
	latched = value


func pulse_feedback(motion_scale: float) -> void:
	_feedback_motion_scale = minf(
		clampf(motion_scale, 0.0, 1.0),
		_presentation_motion_scale
	)
	_feedback_time = 0.16
	_feedback_amount = 0.01
	queue_redraw()


func set_presentation_motion_scale(value: float) -> void:
	_presentation_motion_scale = clampf(value, 0.0, 1.0)
	_feedback_motion_scale = minf(
		_feedback_motion_scale,
		_presentation_motion_scale
	)
	queue_redraw()


func flee_from(source_position: Vector2) -> void:
	var direction := (global_position - source_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	velocity = direction * 310.0
	unpredictable = true
	world_state_dirty = true


func set_presentation_scale(value: float) -> void:
	_presentation_scale = value
	scale = Vector2.ONE * value


func make_belly_item(
	accuracy: float,
	captured_in_danger: bool,
	captured_while_chased: bool
) -> BellyItem:
	var item := BellyItem.new()
	item.target_id = target_id
	item.display_name = display_name
	item.kind = kind
	item.base_value = base_value
	item.size_tier = size_tier
	item.rare = rare
	item.resistant = resistant
	item.taps_required = taps_required
	item.pick_radius = pick_radius
	item.accuracy = accuracy
	item.dangerous_location = captured_in_danger or dangerous_location
	item.captured_while_chased = captured_while_chased
	item.target_color = target_color
	item.movement_velocity = velocity
	item.movement_bounds = move_bounds
	item.unpredictable = unpredictable
	item.intrinsic_dangerous_location = dangerous_location
	item.restockable = restockable
	item.building_id = building_id
	item.building_part_id = building_part_id
	item.selectable = selectable
	item.world_instance_id = world_instance_id
	item.district_coordinate = district_coordinate
	item.motion_seed = motion_seed
	return item


func configure_from_belly(item: BellyItem) -> void:
	target_id = item.target_id
	display_name = item.display_name
	kind = item.kind
	base_value = item.base_value
	size_tier = item.size_tier
	rare = item.rare
	resistant = item.resistant
	taps_required = item.taps_required
	target_color = item.target_color
	pick_radius = item.pick_radius
	velocity = item.movement_velocity
	move_bounds = item.movement_bounds
	unpredictable = item.unpredictable
	dangerous_location = item.intrinsic_dangerous_location
	is_vehicle = kind == "vehicle"
	restockable = item.restockable
	building_id = item.building_id
	building_part_id = item.building_part_id
	selectable = item.selectable
	world_instance_id = item.world_instance_id
	district_coordinate = item.district_coordinate
	motion_seed = item.motion_seed
	queue_redraw()


func _motion_randf_range(from: float, to: float) -> float:
	if _motion_rng != null:
		return _motion_rng.randf_range(from, to)
	return randf_range(from, to)


func _draw() -> void:
	var wobble := _feedback_amount * _feedback_motion_scale
	var moving := velocity.length_squared() > 1.0
	var step_cycle := (
		sin(_motion_time * 8.0)
		* _presentation_motion_scale
		if moving
		else 0.0
	)
	var bob := step_cycle * (3.5 if unpredictable else 2.0)
	var lean := (
		step_cycle * 0.045
		+ sin(_feedback_amount * TAU)
		* 0.045
		* _feedback_motion_scale
	)
	draw_set_transform(Vector2(0, pick_radius * 0.48), 0.0, Vector2(1.0, 0.35))
	draw_circle(
		Vector2.ZERO,
		pick_radius * 0.72,
		Color(ART.INK, 0.18)
	)
	draw_set_transform(
		Vector2(0, bob),
		lean,
		Vector2(1.0 + wobble * 0.1, 1.0 - wobble * 0.07)
	)
	var visual_size := ART.target_visual_size(kind, pick_radius)
	draw_texture_rect(
		ART.target_texture(kind),
		Rect2(-visual_size / 2.0, visual_size),
		false,
		target_color
	)

	if rare:
		draw_arc(Vector2.ZERO, pick_radius + 8.0, 0.0, TAU, 28, Color("ffe56b"), 5.0)
		var star := PackedVector2Array()
		for index in 10:
			var radius := 8.0 if index % 2 == 0 else 3.5
			star.append(
				Vector2.UP.rotated(TAU * float(index) / 10.0) * radius
				+ Vector2(0, -pick_radius - 18.0)
			)
		draw_colored_polygon(star, ART.MAGIC_AMBER)
		var star_outline := star.duplicate()
		star_outline.append(star[0])
		draw_polyline(star_outline, ART.INK, 2.0)
	if resistant:
		var chevron_color := Color(ART.CREAM, 0.95)
		draw_polyline(
			PackedVector2Array([
				Vector2(-pick_radius - 10.0, -8.0),
				Vector2(-pick_radius - 3.0, 0.0),
				Vector2(-pick_radius - 10.0, 8.0),
			]),
			chevron_color,
			4.0
		)
		draw_polyline(
			PackedVector2Array([
				Vector2(pick_radius + 10.0, -8.0),
				Vector2(pick_radius + 3.0, 0.0),
				Vector2(pick_radius + 10.0, 8.0),
			]),
			chevron_color,
			4.0
		)
	if dangerous_location:
		var warning_center := Vector2(0, pick_radius + 15.0)
		draw_colored_polygon(
			PackedVector2Array([
				warning_center + Vector2(0, -8),
				warning_center + Vector2(8, 7),
				warning_center + Vector2(-8, 7),
			]),
			ART.DANGER_CORAL
		)
		draw_line(
			warning_center + Vector2(0, -3),
			warning_center + Vector2(0, 3),
			ART.CREAM,
			2.0
		)
	if highlighted:
		var pulse := (
			5.0
			+ sin(_motion_time * 6.0)
			* 3.0
			* _presentation_motion_scale
		)
		draw_arc(
			Vector2.ZERO,
			pick_radius + 13.0 + pulse,
			0.0,
			TAU,
			32,
			Color(0.35, 1.0, 0.55, 0.95),
			6.0
		)
	if _feedback_amount > 0.0:
		draw_arc(
			Vector2.ZERO,
			pick_radius + 8.0,
			0.0,
			TAU,
			24,
			Color(1.0, 1.0, 1.0, _feedback_amount * 0.8),
			4.0
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var label_y := -pick_radius - 13.0
	if (
		kind == "building_part"
		and building_part_id == PrototypeBuilding.PART_COUNTER
	):
		label_y = pick_radius + 30.0
	var label_position := Vector2(-pick_radius * 2.5, label_y)
	draw_string(
		ThemeDB.fallback_font,
		label_position + Vector2(2, 2),
		display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		pick_radius * 5.0,
		15,
		Color(0.08, 0.1, 0.12, 0.85)
	)
	draw_string(
		ThemeDB.fallback_font,
		label_position,
		display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		pick_radius * 5.0,
		15,
		Color.WHITE
	)
