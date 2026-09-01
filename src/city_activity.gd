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
const WIND_RIBBON_COUNT := 40
const WIND_LOOP_DURATION := 6.0
const WIND_TRAVEL_SPEED := 520.0
const WIND_RIBBON_VECTOR := Vector2(58, -9)
const FESTIVAL_SWAY_DURATION := 4.0
const KITE_FESTIVAL_SWAY_DURATION := 6.0
const CROWD_CENTER := Vector2(950, 430)
const CROWD_COVER_RADIUS := 145.0
const CROWD_MEMBER_OFFSETS := [
	Vector2(-70, -35),
	Vector2(-30, 50),
	Vector2(0, -55),
	Vector2(35, 38),
	Vector2(72, -10),
]
const CROWD_MEMBER_COLORS := [
	Color("765a8d"),
	Color("4d7f72"),
	Color("a36452"),
	Color("4f719d"),
	Color("98713f"),
]
const FESTIVAL_CENTER := Vector2(-480, 420)
const FESTIVAL_LANTERN_OFFSETS := [
	Vector2(-310, -160),
	Vector2(-310, 0),
	Vector2(-310, 160),
	Vector2(310, -160),
	Vector2(310, 0),
	Vector2(310, 160),
	Vector2(-150, -240),
	Vector2(150, -240),
	Vector2(-150, 240),
	Vector2(150, 240),
]
const FESTIVAL_LANTERN_COLORS := [
	Color("f2bf55"),
	Color("e77a68"),
	Color("8fc7a1"),
	Color("c18bd4"),
	Color("ef9d55"),
]
const KITE_FESTIVAL_CENTER := Vector2(950, 430)
const KITE_FESTIVAL_OFFSETS := [
	Vector2(-210, -190),
	Vector2(-140, -150),
	Vector2(-70, -220),
	Vector2(10, -165),
	Vector2(60, -290),
	Vector2(100, -235),
	Vector2(170, -130),
	Vector2(240, -210),
]
const KITE_FESTIVAL_COLORS := [
	Color("e76f51"),
	Color("2a9d8f"),
]
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
var wind_intensity := 0.0
var crowd_intensity := 0.0
var festival_intensity := 0.0
var kite_festival_intensity := 0.0
var crowd_hide_progress := 0.0
var crowd_cover_chase_active := false
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


func set_wind_intensity(value: float) -> void:
	var next_intensity := clampf(value, 0.0, 1.0)
	if is_equal_approx(wind_intensity, next_intensity):
		return
	wind_intensity = next_intensity
	queue_redraw()


func set_crowd_intensity(value: float) -> void:
	var next_intensity := clampf(value, 0.0, 1.0)
	if is_equal_approx(crowd_intensity, next_intensity):
		return
	crowd_intensity = next_intensity
	queue_redraw()


func set_festival_intensity(value: float) -> void:
	var next_intensity := clampf(value, 0.0, 1.0)
	if is_equal_approx(festival_intensity, next_intensity):
		return
	festival_intensity = next_intensity
	queue_redraw()


func set_kite_festival_intensity(value: float) -> void:
	var next_intensity := clampf(value, 0.0, 1.0)
	if is_equal_approx(kite_festival_intensity, next_intensity):
		return
	kite_festival_intensity = next_intensity
	queue_redraw()


func set_crowd_hide_progress(value: float) -> void:
	var next_progress := clampf(value, 0.0, 1.0)
	if is_equal_approx(crowd_hide_progress, next_progress):
		return
	crowd_hide_progress = next_progress
	queue_redraw()


func set_crowd_cover_chase_active(value: bool) -> void:
	if crowd_cover_chase_active == value:
		return
	crowd_cover_chase_active = value
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


func active_crowd_member_count() -> int:
	return CROWD_MEMBER_OFFSETS.size() if crowd_intensity >= 0.5 else 0


func visible_festival_lantern_count() -> int:
	return (
		FESTIVAL_LANTERN_OFFSETS.size()
		if festival_intensity > 0.01
		else 0
	)


func visible_kite_festival_count() -> int:
	return (
		KITE_FESTIVAL_OFFSETS.size()
		if kite_festival_intensity > 0.01
		else 0
	)


func crowd_cover_available() -> bool:
	return crowd_intensity >= 0.8


func crowd_cover_contains(world_position: Vector2) -> bool:
	return (
		crowd_cover_available()
		and world_position.distance_to(CROWD_CENTER) <= CROWD_COVER_RADIUS
	)


func crowd_member_position(index: int) -> Vector2:
	if index < 0 or index >= CROWD_MEMBER_OFFSETS.size():
		return Vector2.INF
	var phase := (
		_animation_time / 3.0
		+ float(index) / float(CROWD_MEMBER_OFFSETS.size())
	)
	return (
		CROWD_CENTER
		+ CROWD_MEMBER_OFFSETS[index]
		+ Vector2(0, sin(phase * TAU) * 2.0)
	)


func festival_lantern_position(index: int) -> Vector2:
	return festival_lantern_position_at(index, _animation_time)


func festival_lantern_position_at(
	index: int,
	animation_time: float
) -> Vector2:
	if index < 0 or index >= FESTIVAL_LANTERN_OFFSETS.size():
		return Vector2.INF
	var phase := (
		animation_time / FESTIVAL_SWAY_DURATION
		+ float(index) / float(FESTIVAL_LANTERN_OFFSETS.size())
	)
	return (
		FESTIVAL_CENTER
		+ FESTIVAL_LANTERN_OFFSETS[index]
		+ Vector2(0, sin(phase * TAU) * 2.5)
	)


func festival_signature() -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in FESTIVAL_LANTERN_OFFSETS.size():
		result.append(festival_lantern_position(index))
	return result


func kite_festival_position_at(
	index: int,
	animation_time: float
) -> Vector2:
	if index < 0 or index >= KITE_FESTIVAL_OFFSETS.size():
		return Vector2.INF
	var phase := (
		animation_time / KITE_FESTIVAL_SWAY_DURATION
		+ float(index) / float(KITE_FESTIVAL_OFFSETS.size())
	)
	return (
		KITE_FESTIVAL_CENTER
		+ KITE_FESTIVAL_OFFSETS[index]
		+ Vector2(sin(phase * TAU) * 5.0, cos(phase * TAU) * 3.0)
	)


func kite_festival_signature() -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in KITE_FESTIVAL_OFFSETS.size():
		result.append(
			kite_festival_position_at(index, _animation_time)
		)
	return result


func streetlight_intensity_for_daylight(value: float) -> float:
	var darkness := clampf((0.62 - value) / 0.42, 0.0, 1.0)
	return darkness * darkness * (3.0 - 2.0 * darkness)


func streetlight_intensity() -> float:
	return streetlight_intensity_for_daylight(daylight)


func visible_rain_streak_count() -> int:
	return RAIN_STREAK_COUNT if rain_intensity > 0.01 else 0


func visible_wind_ribbon_count() -> int:
	return WIND_RIBBON_COUNT if wind_intensity > 0.01 else 0


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


func wind_ribbon_position_at(
	index: int,
	animation_time: float
) -> Vector2:
	if index < 0 or index >= WIND_RIBBON_COUNT:
		return Vector2.INF
	var wind_time := fposmod(
		snappedf(animation_time, 0.0001),
		WIND_LOOP_DURATION
	)
	var x_offset := fposmod(
		float(index * 197) + wind_time * WIND_TRAVEL_SPEED,
		CityBackdrop.WORLD_RECT.size.x + 220.0
	) - 110.0
	var y_offset := fposmod(
		float(index * 113),
		CityBackdrop.WORLD_RECT.size.y + 160.0
	) - 80.0
	return CityBackdrop.WORLD_RECT.position + Vector2(
		x_offset,
		y_offset
	)


func wind_signature() -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in WIND_RIBBON_COUNT:
		result.append(
			wind_ribbon_position_at(index, _animation_time)
		)
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
	for index in CROWD_MEMBER_OFFSETS.size():
		result.append(crowd_member_position(index))
	for position in festival_signature():
		result.append(position)
	for position in kite_festival_signature():
		result.append(position)
	for position in wind_signature():
		result.append(position)
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
	_draw_night_bazaar()
	_draw_kite_festival()
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
	_draw_park_meetup()
	_draw_rain()
	_draw_wind_squall()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_night_bazaar() -> void:
	if festival_intensity <= 0.01:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for index in FESTIVAL_LANTERN_OFFSETS.size():
		var position := festival_lantern_position(index)
		var color: Color = FESTIVAL_LANTERN_COLORS[
			index % FESTIVAL_LANTERN_COLORS.size()
		]
		draw_circle(
			position,
			18.0,
			Color(color.r, color.g, color.b, 0.12 * festival_intensity)
		)
		draw_line(
			position + Vector2(0, -18),
			position + Vector2(0, -8),
			Color(0.16, 0.13, 0.2, 0.75 * festival_intensity),
			2.0
		)
		color.a = 0.92 * festival_intensity
		draw_circle(position, 7.0, color)
		draw_line(
			position + Vector2(-5, 0),
			position + Vector2(5, 0),
			Color(1.0, 0.9, 0.58, 0.8 * festival_intensity),
			2.0
		)
	draw_string(
		ThemeDB.fallback_font,
		FESTIVAL_CENTER + Vector2(-130, -270),
		"NIGHT BAZAAR",
		HORIZONTAL_ALIGNMENT_CENTER,
		260,
		20,
		Color(1.0, 0.88, 0.56, 0.94 * festival_intensity)
	)


func _draw_kite_festival() -> void:
	if kite_festival_intensity <= 0.01:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for color_index in KITE_FESTIVAL_COLORS.size():
		var segments := PackedVector2Array()
		var kite_index := color_index
		while kite_index < KITE_FESTIVAL_OFFSETS.size():
			var center := kite_festival_position_at(
				kite_index,
				_animation_time
			)
			var points := [
				center + Vector2(0, -14),
				center + Vector2(11, 0),
				center + Vector2(0, 14),
				center + Vector2(-11, 0),
			]
			for point_index in points.size():
				segments.append(points[point_index])
				segments.append(
					points[(point_index + 1) % points.size()]
				)
			segments.append(center + Vector2(0, 14))
			segments.append(center + Vector2(-8, 28))
			segments.append(center + Vector2(-8, 28))
			segments.append(center + Vector2(3, 39))
			kite_index += KITE_FESTIVAL_COLORS.size()
		draw_multiline(
			segments,
			Color(
				KITE_FESTIVAL_COLORS[color_index],
				0.9 * kite_festival_intensity
			),
			3.0
		)
	draw_string(
		ThemeDB.fallback_font,
		KITE_FESTIVAL_CENTER + Vector2(-140, -320),
		"CANAL KITE FESTIVAL",
		HORIZONTAL_ALIGNMENT_CENTER,
		280,
		18,
		Color(0.16, 0.25, 0.3, 0.9 * kite_festival_intensity)
	)


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


func _draw_park_meetup() -> void:
	if crowd_intensity <= 0.01:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cover_color := Color(0.54, 0.88, 0.68, 0.16 * crowd_intensity)
	draw_circle(CROWD_CENTER, CROWD_COVER_RADIUS, cover_color)
	draw_arc(
		CROWD_CENTER,
		CROWD_COVER_RADIUS,
		0.0,
		TAU,
		48,
		Color(0.64, 0.96, 0.76, 0.72 * crowd_intensity),
		4.0
	)
	if crowd_hide_progress > 0.0:
		draw_arc(
			CROWD_CENTER,
			CROWD_COVER_RADIUS - 9.0,
			-PI / 2.0,
			-PI / 2.0 + TAU * crowd_hide_progress,
			48,
			Color(1.0, 0.9, 0.42, 0.92),
			7.0
		)
	draw_string(
		ThemeDB.fallback_font,
		CROWD_CENTER + Vector2(-120, -CROWD_COVER_RADIUS - 18),
		"HIDE HERE" if crowd_cover_chase_active else "PARK MEETUP",
		HORIZONTAL_ALIGNMENT_CENTER,
		240,
		20,
		Color(0.94, 1.0, 0.9, 0.92 * crowd_intensity)
	)
	for index in CROWD_MEMBER_OFFSETS.size():
		var position := crowd_member_position(index)
		var color: Color = CROWD_MEMBER_COLORS[index]
		color.a = 0.9 * crowd_intensity
		draw_set_transform(
			position,
			PI if index % 2 == 0 else 0.0,
			Vector2.ONE
		)
		draw_circle(
			Vector2(3, 5),
			12.0,
			Color(0.04, 0.06, 0.07, 0.18 * crowd_intensity)
		)
		draw_line(
			Vector2(-7, 7),
			Vector2(-12, 15),
			Color(0.16, 0.2, 0.21, crowd_intensity),
			4.0
		)
		draw_line(
			Vector2(7, 7),
			Vector2(12, 15),
			Color(0.16, 0.2, 0.21, crowd_intensity),
			4.0
		)
		draw_circle(Vector2(0, 3), 9.0, color)
		var head_color := color.lightened(0.22)
		head_color.a = 0.94 * crowd_intensity
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


func _draw_wind_squall() -> void:
	if wind_intensity <= 0.01:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var segments := PackedVector2Array()
	for index in WIND_RIBBON_COUNT:
		var start := wind_ribbon_position_at(index, _animation_time)
		var length_scale := 0.55 + float(index % 4) * 0.15
		segments.append(start)
		segments.append(start + WIND_RIBBON_VECTOR * length_scale)
	draw_multiline(
		segments,
		Color(0.82, 0.9, 0.92, 0.5 * wind_intensity),
		3.0
	)


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
