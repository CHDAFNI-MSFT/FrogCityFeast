class_name FeelEffects
extends Node2D

const MAX_EFFECTS := 24

var motion_scale := 1.0
var _effects: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0xF06C17
	set_process(false)


func set_motion_scale(value: float) -> void:
	motion_scale = clampf(value, 0.0, 1.0)


func emit_swallow(
	world_position: Vector2,
	color: Color,
	large: bool = false
) -> void:
	_add_effect(
		"swallow",
		world_position,
		color,
		0.42 if large else 0.3,
		140.0 if large else 56.0,
		12 if large else 8
	)


func emit_growth(world_position: Vector2) -> void:
	_add_effect(
		"growth",
		world_position,
		Color(0.48, 1.0, 0.58, 1.0),
		0.65,
		118.0,
		3
	)


func emit_damage(world_position: Vector2) -> void:
	_add_effect(
		"damage",
		world_position,
		Color(1.0, 0.34, 0.28, 1.0),
		0.34,
		68.0,
		9
	)


func active_effect_count() -> int:
	return _effects.size()


func _add_effect(
	kind: String,
	world_position: Vector2,
	color: Color,
	duration: float,
	radius: float,
	direction_count: int
) -> void:
	var directions := PackedVector2Array()
	for index in direction_count:
		var angle := (
			TAU * float(index) / float(maxi(1, direction_count))
			+ _rng.randf_range(-0.16, 0.16)
		)
		directions.append(Vector2.RIGHT.rotated(angle))
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()
	_effects.append({
		"kind": kind,
		"position": world_position,
		"color": color,
		"age": 0.0,
		"duration": duration,
		"radius": radius,
		"directions": directions,
	})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for index in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[index]
		effect["age"] = float(effect["age"]) + delta
		if float(effect["age"]) >= float(effect["duration"]):
			_effects.remove_at(index)
		else:
			_effects[index] = effect
	if _effects.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for effect in _effects:
		var duration := float(effect["duration"])
		var progress := clampf(float(effect["age"]) / duration, 0.0, 1.0)
		match str(effect["kind"]):
			"growth":
				_draw_growth(effect, progress)
			"damage":
				_draw_burst(effect, progress, false)
			_:
				_draw_burst(effect, progress, true)


func _draw_burst(
	effect: Dictionary,
	progress: float,
	inward: bool
) -> void:
	var position := effect["position"] as Vector2
	var color := effect["color"] as Color
	var max_radius := float(effect["radius"])
	var directions := effect["directions"] as PackedVector2Array
	var alpha := 1.0 - progress
	var travel_progress := progress * motion_scale
	var radius := (
		max_radius * (1.0 - travel_progress * 0.78)
		if inward
		else max_radius * (0.24 + travel_progress * 0.76)
	)
	var ring_color := color
	ring_color.a *= alpha * 0.9
	draw_arc(position, radius, 0.0, TAU, 32, ring_color, 5.0)
	for direction in directions:
		var particle_position := position + direction * radius
		draw_circle(
			particle_position,
			lerpf(8.0, 2.0, progress),
			Color(color, alpha)
		)


func _draw_growth(effect: Dictionary, progress: float) -> void:
	var position := effect["position"] as Vector2
	var color := effect["color"] as Color
	var max_radius := float(effect["radius"])
	var alpha := 1.0 - progress
	for ring_index in 3:
		var delayed_progress := clampf(
			progress * 1.35 - float(ring_index) * 0.18,
			0.0,
			1.0
		)
		var ring_radius := max_radius * (
			0.28 + delayed_progress * 0.72 * motion_scale
		)
		var ring_color := color
		ring_color.a *= alpha * (1.0 - float(ring_index) * 0.2)
		draw_arc(position, ring_radius, 0.0, TAU, 40, ring_color, 6.0)
