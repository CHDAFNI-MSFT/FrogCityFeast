class_name EdibleTarget
extends Node2D

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

var _turn_timer := 0.0
var _presentation_scale := 1.0
var _feedback_time := 0.0
var _feedback_amount := 0.0
var _feedback_motion_scale := 1.0


func _ready() -> void:
	_turn_timer = randf_range(0.7, 1.8)
	z_index = 4
	queue_redraw()


func _process(delta: float) -> void:
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
			velocity = velocity.rotated(randf_range(-1.1, 1.1))
			_turn_timer = randf_range(0.55, 1.5)

	position += velocity * delta
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
	_feedback_motion_scale = clampf(motion_scale, 0.0, 1.0)
	_feedback_time = 0.16
	_feedback_amount = 0.01
	queue_redraw()


func flee_from(source_position: Vector2) -> void:
	var direction := (global_position - source_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	velocity = direction * 310.0
	unpredictable = true


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
	queue_redraw()


func _draw() -> void:
	var wobble := _feedback_amount * _feedback_motion_scale
	draw_set_transform(
		Vector2.ZERO,
		sin(_feedback_amount * TAU) * 0.045 * _feedback_motion_scale,
		Vector2(1.0 + wobble * 0.1, 1.0 - wobble * 0.07)
	)
	match kind:
		"vehicle":
			draw_rect(Rect2(-43, -22, 86, 44), target_color)
			draw_rect(Rect2(-21, -34, 42, 18), target_color.lightened(0.2))
			draw_circle(Vector2(-27, 24), 9.0, Color("20252b"))
			draw_circle(Vector2(27, 24), 9.0, Color("20252b"))
		"living":
			draw_circle(Vector2.ZERO, pick_radius * 0.78, target_color)
			draw_circle(Vector2(-8, -7), 3.5, Color("1e2922"))
			draw_circle(Vector2(8, -7), 3.5, Color("1e2922"))
			draw_arc(Vector2(0, 4), 8.0, 0.1, PI - 0.1, 12, Color("1e2922"), 2.0)
		"object":
			draw_rect(Rect2(-pick_radius * 0.72, -pick_radius * 0.72, pick_radius * 1.44, pick_radius * 1.44), target_color)
			draw_rect(Rect2(-pick_radius * 0.55, -pick_radius * 0.55, pick_radius * 1.1, pick_radius * 1.1), target_color.lightened(0.16), false, 3.0)
		"building_part":
			draw_rect(Rect2(-pick_radius, -pick_radius * 0.58, pick_radius * 2.0, pick_radius * 1.16), target_color)
			draw_line(Vector2(-pick_radius * 0.72, 0), Vector2(pick_radius * 0.72, 0), target_color.lightened(0.25), 4.0)
		_:
			draw_circle(Vector2.ZERO, pick_radius * 0.78, target_color)
			draw_circle(Vector2(-pick_radius * 0.2, -pick_radius * 0.2), pick_radius * 0.18, target_color.lightened(0.3))

	if rare:
		draw_arc(Vector2.ZERO, pick_radius + 8.0, 0.0, TAU, 28, Color("ffe56b"), 5.0)
	if highlighted:
		var pulse := 5.0 + sin(Time.get_ticks_msec() * 0.008) * 3.0
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
