extends SceneTree

const NAVIGATION := preload("res://src/deterministic_navigation.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_multi_corner_route()
	_test_narrow_door_route()
	_test_unreachable_fallback()
	_test_loaded_bounds()
	_test_dynamic_geometry_revision()
	await _finish()


func _test_multi_corner_route() -> void:
	var navigation: RefCounted = NAVIGATION.new()
	var obstacles: Array[Rect2] = [
		Rect2(250, 0, 100, 430),
		Rect2(500, 270, 100, 430),
	]
	navigation.update_geometry(Rect2(0, 0, 900, 700), obstacles)
	var first: Dictionary = navigation.find_path(
		Vector2(80, 350),
		Vector2(820, 350),
		20.0
	)
	var second: Dictionary = navigation.find_path(
		Vector2(80, 350),
		Vector2(820, 350),
		20.0
	)
	var points := first["points"] as PackedVector2Array
	_check(
		bool(first["reachable"])
			and points.size() >= 4
			and points == second["points"],
		"Navigation deterministically routes around two successive obstacles."
	)
	_check(
		navigation.path_is_clear(points, 20.0),
		"Every segment of the multi-corner route stays outside collision."
	)
	_check(
		(first["resolved_destination"] as Vector2)
			.is_equal_approx(Vector2(820, 350)),
		"A reachable route preserves the exact requested destination."
	)


func _test_narrow_door_route() -> void:
	var navigation: RefCounted = NAVIGATION.new()
	var obstacles: Array[Rect2] = [
		Rect2(0, 238, 195, 24),
		Rect2(305, 238, 195, 24),
	]
	navigation.update_geometry(Rect2(0, 0, 500, 500), obstacles)
	var route: Dictionary = navigation.find_path(
		Vector2(250, 410),
		Vector2(250, 90),
		44.0
	)
	_check(
		bool(route["reachable"])
			and navigation.path_is_clear(
				route["points"] as PackedVector2Array,
				44.0
			),
		"Maximum-growth routing remains possible through a 110-pixel doorway."
	)


func _test_unreachable_fallback() -> void:
	var navigation: RefCounted = NAVIGATION.new()
	var obstacle := Rect2(300, 180, 260, 280)
	navigation.update_geometry(
		Rect2(0, 0, 900, 700),
		[obstacle] as Array[Rect2]
	)
	var requested := obstacle.get_center()
	var route: Dictionary = navigation.find_path(
		Vector2(100, 350),
		requested,
		28.0
	)
	var resolved := route["resolved_destination"] as Vector2
	_check(
		not bool(route["reachable"])
			and bool(route["fallback"])
			and not (route["points"] as PackedVector2Array).is_empty()
			and navigation.position_is_clear(resolved, 28.0),
		"An obstructed tap resolves to a safe reachable fallback."
	)
	_check(
		resolved.distance_to(requested) <= 180.0,
		"The fallback remains near the blocked requested destination."
	)


func _test_loaded_bounds() -> void:
	var navigation: RefCounted = NAVIGATION.new()
	var bounds := Rect2(0, 0, 640, 480)
	var obstacles: Array[Rect2] = []
	navigation.update_geometry(bounds, obstacles)
	var route: Dictionary = navigation.find_path(
		Vector2(120, 240),
		Vector2(900, 240),
		28.0
	)
	var points := route["points"] as PackedVector2Array
	var points_inside := true
	for point in points:
		if not bounds.grow(-30.0).grow(0.01).has_point(point):
			points_inside = false
	_check(
		not bool(route["reachable"])
			and bool(route["fallback"])
			and not points.is_empty()
			and points_inside
			and navigation.path_is_clear(points, 28.0)
			and points[-1].is_equal_approx(
				route["resolved_destination"] as Vector2
			)
			and is_equal_approx(
				(route["resolved_destination"] as Vector2).x,
				bounds.end.x - 30.0
			),
		"Routes stop at loaded navigation bounds instead of entering unloaded space."
	)


func _test_dynamic_geometry_revision() -> void:
	var navigation: RefCounted = NAVIGATION.new()
	var bounds := Rect2(0, 0, 700, 500)
	var obstacle := Rect2(290, 80, 120, 340)
	navigation.update_geometry(bounds, [obstacle] as Array[Rect2])
	var blocked_route: Dictionary = navigation.find_path(
		Vector2(100, 250),
		Vector2(600, 250),
		24.0
	)
	var blocked_revision: int = navigation.revision()
	var open_obstacles: Array[Rect2] = []
	navigation.update_geometry(bounds, open_obstacles)
	var open_route: Dictionary = navigation.find_path(
		Vector2(100, 250),
		Vector2(600, 250),
		24.0
	)
	_check(
		navigation.revision() == blocked_revision + 1
			and (blocked_route["points"] as PackedVector2Array).size()
			> (open_route["points"] as PackedVector2Array).size()
			and (open_route["points"] as PackedVector2Array).size() == 2,
		"Updating dynamic geometry invalidates the prior route topology."
	)
	var metrics: Dictionary = navigation.metrics_snapshot()
	_check(
		int(metrics["navigation_requests"]) == 2
			and int(metrics["navigation_max_query_cells"])
			<= NAVIGATION.MAX_TOTAL_QUERY_CELLS
			and int(metrics["navigation_max_path_points"])
			<= NAVIGATION.MAX_PATH_POINTS,
		"Navigation request allocations stay within explicit structural caps."
	)

	var wide_navigation: RefCounted = NAVIGATION.new()
	var wide_obstacles: Array[Rect2] = []
	wide_navigation.update_geometry(
		Rect2(0, 0, 10000, 500),
		wide_obstacles
	)
	var wide_route: Dictionary = wide_navigation.find_path(
		Vector2(104, 248),
		Vector2(9000, 248),
		28.0
	)
	_check(
		bool(wide_route["reachable"])
			and (wide_route["points"] as PackedVector2Array).size() == 2,
		"Long clear routes use the bounded direct-path fast path."
	)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("Navigation smoke tests passed.")
		quit(0)
	else:
		print(
			"Navigation smoke tests failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
