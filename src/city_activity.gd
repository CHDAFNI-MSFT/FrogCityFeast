class_name CityActivity
extends Node2D

const LOOP_DURATION := 120.0
const ROUTE_CLEARANCE := 18.0
const FADE_WIDTH := 0.08
const RAIN_FADE_WIDTH := 0.12
const RAIN_STREAK_COUNT := 84
const RAIN_LOOP_DURATION := 4.0
const RAIN_FALL_SPEED := 745.0
const RAIN_SLANT := Vector2(-10, 26)
const WET_PATCHES := [
	Vector2(-1480, -70),
	Vector2(-690, 95),
	Vector2(520, -90),
	Vector2(1350, 100),
	Vector2(-1080, 810),
	Vector2(460, 865),
]
const PEDESTRIAN_RAIN_LIMITS := [
	1.25,
	1.25,
	1.25,
	1.25,
	0.9,
	0.82,
	0.74,
	0.66,
	0.58,
	0.5,
]
const VEHICLE_RAIN_LIMITS := [
	1.25,
	1.25,
	1.25,
	0.78,
	0.58,
]

const PEDESTRIAN_ROUTES := [
	{
		"start": Vector2(-820, -285),
		"end": Vector2(330, -285),
		"duration": 40.0,
		"phase": 0.08,
		"threshold": -1.0,
		"color": Color("486f87"),
	},
	{
		"start": Vector2(-1600, 260),
		"end": Vector2(-820, 260),
		"duration": 30.0,
		"phase": 0.42,
		"threshold": -1.0,
		"color": Color("9b5c72"),
	},
	{
		"start": Vector2(850, 260),
		"end": Vector2(1160, 260),
		"duration": 24.0,
		"phase": 0.2,
		"threshold": -1.0,
		"color": Color("5d8067"),
	},
	{
		"start": Vector2(260, 270),
		"end": Vector2(260, 650),
		"duration": 24.0,
		"phase": 0.62,
		"threshold": -1.0,
		"color": Color("a56d48"),
	},
	{
		"start": Vector2(-880, -1300),
		"end": Vector2(-880, 180),
		"duration": 60.0,
		"phase": 0.33,
		"threshold": 0.28,
		"color": Color("6f5c8e"),
	},
	{
		"start": Vector2(-1280, -1300),
		"end": Vector2(-1280, 650),
		"duration": 60.0,
		"phase": 0.72,
		"threshold": 0.38,
		"color": Color("507d7b"),
	},
	{
		"start": Vector2(-820, 650),
		"end": Vector2(-300, 650),
		"duration": 30.0,
		"phase": 0.15,
		"threshold": -1.0,
		"color": Color("aa6758"),
	},
	{
		"start": Vector2(-180, 650),
		"end": Vector2(340, 650),
		"duration": 30.0,
		"phase": 0.58,
		"threshold": 0.58,
		"color": Color("4f719d"),
	},
	{
		"start": Vector2(-1700, 1020),
		"end": Vector2(-900, 1020),
		"duration": 40.0,
		"phase": 0.87,
		"threshold": 0.68,
		"color": Color("99703f"),
	},
	{
		"start": Vector2(-300, 1020),
		"end": Vector2(300, 1020),
		"duration": 30.0,
		"phase": 0.47,
		"threshold": 0.78,
		"color": Color("786581"),
	},
]

const VEHICLE_ROUTES := [
	{
		"start": Vector2(-1760, 715),
		"end": Vector2(1760, 715),
		"duration": 24.0,
		"phase": 0.12,
		"threshold": -1.0,
		"color": Color("7893a0"),
	},
	{
		"start": Vector2(1760, 745),
		"end": Vector2(-1760, 745),
		"duration": 30.0,
		"phase": 0.56,
		"threshold": -1.0,
		"color": Color("b27768"),
	},
	{
		"start": Vector2(-1760, 775),
		"end": Vector2(1760, 775),
		"duration": 30.0,
		"phase": 0.74,
		"threshold": 0.28,
		"color": Color("728268"),
	},
	{
		"start": Vector2(1760, 805),
		"end": Vector2(-1760, 805),
		"duration": 40.0,
		"phase": 0.31,
		"threshold": 0.48,
		"color": Color("8e779b"),
	},
	{
		"start": Vector2(-1760, 835),
		"end": Vector2(1760, 835),
		"duration": 24.0,
		"phase": 0.9,
		"threshold": 0.68,
		"color": Color("a08b61"),
	},
]

const STREETLIGHT_POSITIONS := [
	Vector2(-840, -270),
	Vector2(350, -270),
	Vector2(1160, -270),
	Vector2(-790, 300),
	Vector2(320, 270),
	Vector2(1190, 300),
	Vector2(-1300, 650),
	Vector2(-860, 650),
	Vector2(-250, 650),
	Vector2(360, 650),
	Vector2(1180, 650),
	Vector2(-1360, 1060),
	Vector2(330, 1025),
	Vector2(900, 1025),
]

var daylight := 0.5
var rain_intensity := 0.0
var motion_scale := 1.0
var _animation_time := 0.0


func _ready() -> void:
	set_process(motion_scale > 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	_advance_animation(delta)


func set_daylight(value: float) -> void:
	var next_daylight := clampf(value, 0.0, 1.0)
	if is_equal_approx(daylight, next_daylight):
		return
	daylight = next_daylight
	queue_redraw()


func set_rain_intensity(value: float) -> void:
	var next_intensity := clampf(value, 0.0, 1.0)
	if is_equal_approx(rain_intensity, next_intensity):
		return
	rain_intensity = next_intensity
	queue_redraw()


func set_motion_scale(value: float) -> void:
	motion_scale = clampf(value, 0.0, 1.0)
	set_process(motion_scale > 0.0)


func pedestrian_count_for_daylight(value: float) -> int:
	return pedestrian_count_for_conditions(value, 0.0)


func vehicle_count_for_daylight(value: float) -> int:
	return vehicle_count_for_conditions(value, 0.0)


func pedestrian_count_for_conditions(
	daylight_value: float,
	rain_value: float
) -> int:
	return _active_count(
		PEDESTRIAN_ROUTES,
		daylight_value,
		rain_value,
		PEDESTRIAN_RAIN_LIMITS
	)


func vehicle_count_for_conditions(
	daylight_value: float,
	rain_value: float
) -> int:
	return _active_count(
		VEHICLE_ROUTES,
		daylight_value,
		rain_value,
		VEHICLE_RAIN_LIMITS
	)


func active_pedestrian_count() -> int:
	return pedestrian_count_for_conditions(daylight, rain_intensity)


func active_vehicle_count() -> int:
	return vehicle_count_for_conditions(daylight, rain_intensity)


func streetlight_intensity_for_daylight(value: float) -> float:
	var darkness := clampf((0.62 - value) / 0.42, 0.0, 1.0)
	return darkness * darkness * (3.0 - 2.0 * darkness)


func streetlight_intensity() -> float:
	return streetlight_intensity_for_daylight(daylight)


func visible_rain_streak_count() -> int:
	return RAIN_STREAK_COUNT if rain_intensity > 0.01 else 0


func rain_streak_position_at(index: int, animation_time: float) -> Vector2:
	if index < 0 or index >= RAIN_STREAK_COUNT:
		return Vector2.INF
	var rain_time := fposmod(
		snappedf(animation_time, 0.0001),
		RAIN_LOOP_DURATION
	)
	var x_offset := fposmod(
		float(index * 211),
		CityBackdrop.WORLD_RECT.size.x + 160.0
	) - 80.0
	var y_offset := fposmod(
		float(index * 137) + rain_time * RAIN_FALL_SPEED,
		CityBackdrop.WORLD_RECT.size.y + 180.0
	) - 90.0
	return CityBackdrop.WORLD_RECT.position + Vector2(x_offset, y_offset)


func rain_signature() -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in RAIN_STREAK_COUNT:
		result.append(rain_streak_position_at(index, _animation_time))
	return result


func pedestrian_position(index: int) -> Vector2:
	return pedestrian_position_at(index, _animation_time)


func pedestrian_position_at(index: int, animation_time: float) -> Vector2:
	if index < 0 or index >= PEDESTRIAN_ROUTES.size():
		return Vector2.INF
	return _route_position(PEDESTRIAN_ROUTES[index], animation_time, true)


func vehicle_position(index: int) -> Vector2:
	return vehicle_position_at(index, _animation_time)


func vehicle_position_at(index: int, animation_time: float) -> Vector2:
	if index < 0 or index >= VEHICLE_ROUTES.size():
		return Vector2.INF
	return _route_position(VEHICLE_ROUTES[index], animation_time, false)


func activity_signature() -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in PEDESTRIAN_ROUTES.size():
		result.append(pedestrian_position(index))
	for index in VEHICLE_ROUTES.size():
		result.append(vehicle_position(index))
	return result


func _advance_animation(delta: float) -> void:
	if delta <= 0.0 or motion_scale <= 0.0:
		return
	_animation_time = fmod(
		_animation_time + delta * motion_scale,
		LOOP_DURATION
	)
	queue_redraw()


func _draw() -> void:
	_draw_streetlights()
	for index in VEHICLE_ROUTES.size():
		var alpha := (
			_actor_alpha(
				daylight,
				float(VEHICLE_ROUTES[index]["threshold"])
			)
			* _rain_route_alpha(
				index,
				rain_intensity,
				VEHICLE_RAIN_LIMITS
			)
		)
		if alpha > 0.01:
			_draw_vehicle(index, alpha)
	for index in PEDESTRIAN_ROUTES.size():
		var alpha := (
			_actor_alpha(
				daylight,
				float(PEDESTRIAN_ROUTES[index]["threshold"])
			)
			* _rain_route_alpha(
				index,
				rain_intensity,
				PEDESTRIAN_RAIN_LIMITS
			)
		)
		if alpha > 0.01:
			_draw_pedestrian(index, alpha)
	_draw_rain()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_streetlights() -> void:
	var intensity := streetlight_intensity()
	for lamp_position in STREETLIGHT_POSITIONS:
		if intensity > 0.01:
			draw_circle(
				lamp_position,
				34.0,
				Color(1.0, 0.82, 0.35, 0.12 * intensity)
			)
			draw_circle(
				lamp_position,
				18.0,
				Color(1.0, 0.9, 0.54, 0.18 * intensity)
			)
		draw_circle(lamp_position, 5.0, Color("313b3d"))
		draw_circle(
			lamp_position,
			3.0,
			Color(1.0, 0.86, 0.42).lerp(Color("899394"), daylight)
		)


func _draw_vehicle(index: int, alpha: float) -> void:
	var route: Dictionary = VEHICLE_ROUTES[index]
	var position := vehicle_position(index)
	var direction := (
		(route["end"] as Vector2) - (route["start"] as Vector2)
	).normalized()
	var color: Color = route["color"]
	color.a = alpha * 0.82
	draw_set_transform(position, direction.angle(), Vector2.ONE)
	draw_rect(
		Rect2(-30, -15, 60, 30),
		Color(0.05, 0.08, 0.1, 0.2 * alpha)
	)
	draw_rect(Rect2(-27, -13, 54, 26), color)
	var window_color := Color(0.58, 0.72, 0.78, alpha * 0.75)
	draw_rect(Rect2(-12, -10, 24, 20), window_color)
	draw_rect(Rect2(-22, -16, 12, 4), Color(0.1, 0.12, 0.14, alpha))
	draw_rect(Rect2(10, -16, 12, 4), Color(0.1, 0.12, 0.14, alpha))
	draw_rect(Rect2(-22, 12, 12, 4), Color(0.1, 0.12, 0.14, alpha))
	draw_rect(Rect2(10, 12, 12, 4), Color(0.1, 0.12, 0.14, alpha))


func _draw_pedestrian(index: int, alpha: float) -> void:
	var route: Dictionary = PEDESTRIAN_ROUTES[index]
	var direction := _pedestrian_direction(index)
	var position := pedestrian_position(index)
	var cycle := _route_cycle(route, _animation_time)
	var bob := sin(cycle * TAU * 2.0) * 1.5
	var color: Color = route["color"]
	color.a = alpha * 0.88
	draw_set_transform(position, direction.angle() + PI / 2.0, Vector2.ONE)
	draw_circle(Vector2(3, 5), 12.0, Color(0.04, 0.06, 0.07, 0.18 * alpha))
	draw_line(
		Vector2(-7, 7 + bob),
		Vector2(-12, 15 - bob),
		Color(0.16, 0.2, 0.21, alpha),
		4.0
	)
	draw_line(
		Vector2(7, 7 - bob),
		Vector2(12, 15 + bob),
		Color(0.16, 0.2, 0.21, alpha),
		4.0
	)
	draw_circle(Vector2(0, 3), 9.0, color)
	var head_color := color.lightened(0.22)
	head_color.a = alpha * 0.92
	draw_circle(Vector2(0, -7), 6.5, head_color)


func _draw_rain() -> void:
	if rain_intensity <= 0.01:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(
		CityBackdrop.WORLD_RECT,
		Color(0.16, 0.28, 0.38, 0.08 * rain_intensity)
	)
	for road in CityBackdrop.ROAD_RECTS:
		draw_rect(
			(road as Rect2).grow(-22.0),
			Color(0.48, 0.65, 0.72, 0.08 * rain_intensity)
		)
	for patch_position in WET_PATCHES:
		draw_set_transform(
			patch_position,
			-0.08,
			Vector2(1.8, 0.45)
		)
		draw_circle(
			Vector2.ZERO,
			34.0,
			Color(0.62, 0.78, 0.84, 0.14 * rain_intensity)
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var rain_color := Color(0.72, 0.88, 1.0, 0.5 * rain_intensity)
	for index in RAIN_STREAK_COUNT:
		var start := rain_streak_position_at(index, _animation_time)
		draw_line(start, start + RAIN_SLANT, rain_color, 2.0)


func _pedestrian_direction(index: int) -> Vector2:
	var route: Dictionary = PEDESTRIAN_ROUTES[index]
	var direction := (
		(route["end"] as Vector2) - (route["start"] as Vector2)
	).normalized()
	return -direction if _route_cycle(route, _animation_time) >= 0.5 else direction


func _active_count(
	routes: Array,
	daylight_value: float,
	rain_value: float,
	rain_limits: Array
) -> int:
	var total := 0
	for index in routes.size():
		var route := routes[index] as Dictionary
		var alpha := (
			_actor_alpha(
				daylight_value,
				float(route["threshold"])
			)
			* _rain_route_alpha(index, rain_value, rain_limits)
		)
		if alpha >= 0.5:
			total += 1
	return total


func _actor_alpha(value: float, threshold: float) -> float:
	if threshold < 0.0:
		return 1.0
	return smoothstep(
		threshold - FADE_WIDTH,
		threshold + FADE_WIDTH,
		clampf(value, 0.0, 1.0)
	)


func _rain_route_alpha(
	index: int,
	value: float,
	rain_limits: Array
) -> float:
	if index < 0 or index >= rain_limits.size():
		return 0.0
	var limit := float(rain_limits[index])
	return 1.0 - smoothstep(
		limit - RAIN_FADE_WIDTH,
		limit + RAIN_FADE_WIDTH,
		clampf(value, 0.0, 1.0)
	)


func _route_position(
	route: Dictionary,
	animation_time: float,
	ping_pong: bool
) -> Vector2:
	var start: Vector2 = route["start"]
	var end: Vector2 = route["end"]
	var cycle := _route_cycle(route, animation_time)
	var progress := 1.0 - absf(cycle * 2.0 - 1.0) if ping_pong else cycle
	return start.lerp(end, progress)


func _route_cycle(route: Dictionary, animation_time: float) -> float:
	var duration := float(route["duration"])
	var phase := float(route["phase"])
	return fposmod(animation_time / duration + phase, 1.0)
