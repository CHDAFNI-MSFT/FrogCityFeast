class_name PrototypePursuitTrap
extends Node2D

signal removed(trap: PrototypePursuitTrap, triggered: bool)

const VARIANT_SNARE := "snare"
const VARIANT_MOTION_BEACON := "motion_beacon"
const VARIANT_STICKY_PATCH := "sticky_patch"
const RADIUS := 46.0
const ARM_DELAY := 0.75
const LIFETIME := 12.0
const STICKY_TONGUE_RECOVERY := 1.2
const BEACON_REVEAL_DURATION := 2.0

const VARIANT_CONFIGURATIONS := {
	VARIANT_SNARE: {
		"radius": 46.0,
		"arm_delay": 0.75,
		"lifetime": 12.0,
		"arming_label": "ARMING",
		"armed_label": "SNARE",
		"line_color": Color("e45543"),
		"arming_color": Color("f0bd4d"),
	},
	VARIANT_MOTION_BEACON: {
		"radius": 54.0,
		"arm_delay": 0.5,
		"lifetime": 10.0,
		"arming_label": "CALIBRATING",
		"armed_label": "MOTION BEACON",
		"line_color": Color("f0cf55"),
		"arming_color": Color("8bd0dc"),
	},
	VARIANT_STICKY_PATCH: {
		"radius": 42.0,
		"arm_delay": 1.0,
		"lifetime": 14.0,
		"arming_label": "SETTLING",
		"armed_label": "STICKY PATCH",
		"line_color": Color("a66a45"),
		"arming_color": Color("d7a766"),
	},
}

var variant_id := VARIANT_SNARE
var _age := 0.0
var _motion_scale := 1.0
var _removed := false


func configure_variant(value: String) -> void:
	if not VARIANT_CONFIGURATIONS.has(value):
		push_error("Unknown pursuit trap variant: %s." % value)
		variant_id = VARIANT_SNARE
		return
	variant_id = value


func _ready() -> void:
	z_index = 3
	queue_redraw()


func advance(delta: float) -> void:
	if _removed or delta <= 0.0:
		return
	var was_armed := is_armed()
	_age = minf(lifetime(), _age + delta)
	if was_armed != is_armed() or _motion_scale > 0.0:
		queue_redraw()


func is_armed() -> bool:
	return _age >= arm_delay()


func expired() -> bool:
	return _age >= lifetime()


func radius() -> float:
	return float(_configuration()["radius"])


static func radius_for_variant(value: String) -> float:
	if not VARIANT_CONFIGURATIONS.has(value):
		push_error("Unknown pursuit trap variant: %s." % value)
		return RADIUS
	return float(
		(VARIANT_CONFIGURATIONS[value] as Dictionary)["radius"]
	)


func arm_delay() -> float:
	return float(_configuration()["arm_delay"])


func lifetime() -> float:
	return float(_configuration()["lifetime"])


func elapsed() -> float:
	return _age


func causes_damage() -> bool:
	return variant_id == VARIANT_SNARE


func state_label() -> String:
	return str(
		_configuration()[
			"armed_label" if is_armed() else "arming_label"
		]
	)


func deployment_status(pursuer_name: String) -> String:
	match variant_id:
		VARIANT_MOTION_BEACON:
			return "%s placed a calibrating motion beacon!" % pursuer_name
		VARIANT_STICKY_PATCH:
			return "%s left a sticky scent patch!" % pursuer_name
		_:
			return "%s placed an arming snare nearby!" % pursuer_name


func _configuration() -> Dictionary:
	return VARIANT_CONFIGURATIONS[variant_id] as Dictionary


func dismiss(triggered: bool) -> void:
	if _removed:
		return
	_removed = true
	removed.emit(self, triggered)
	queue_free()


func set_presentation_motion_scale(value: float) -> void:
	_motion_scale = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var configuration := _configuration()
	var trap_radius := radius()
	var armed := is_armed()
	var pulse := (
		2.0 + sin(_age * 7.0) * 2.0 * _motion_scale
		if armed
		else 0.0
	)
	var fill_color := (
		Color(0.86, 0.28, 0.22, 0.22)
		if armed
		else Color(0.95, 0.74, 0.28, 0.18)
	)
	var line_color := (
		configuration["line_color"] as Color
		if armed
		else configuration["arming_color"] as Color
	)
	draw_circle(Vector2.ZERO, trap_radius + pulse, fill_color)
	draw_arc(
		Vector2.ZERO,
		trap_radius + pulse,
		0.0,
		TAU,
		32,
		line_color,
		5.0
	)
	match variant_id:
		VARIANT_MOTION_BEACON:
			draw_circle(Vector2.ZERO, 12.0, line_color)
			draw_arc(Vector2.ZERO, 28.0, -0.8, 0.8, 12, line_color, 4.0)
			draw_arc(Vector2.ZERO, 38.0, -0.8, 0.8, 12, line_color, 3.0)
		VARIANT_STICKY_PATCH:
			draw_circle(Vector2(-13, 5), 16.0, line_color)
			draw_circle(Vector2(12, -7), 18.0, line_color.darkened(0.12))
			draw_circle(Vector2(8, 17), 13.0, line_color.lightened(0.08))
		_:
			draw_line(
				Vector2(-28, -28),
				Vector2(28, 28),
				line_color,
				5.0
			)
			draw_line(
				Vector2(28, -28),
				Vector2(-28, 28),
				line_color,
				5.0
			)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-90, -trap_radius - 18),
		state_label(),
		HORIZONTAL_ALIGNMENT_CENTER,
		180,
		16,
		Color("fff3cf")
	)
