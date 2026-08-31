class_name DeterministicNavigation2D
extends RefCounted

const CELL_SIZE := 16.0
const FINE_CELL_SIZE := 4.0
const CLEARANCE := 0.0
const QUERY_MARGINS := [192.0, 384.0, 704.0]
const FINE_QUERY_MARGIN := 96.0
const FINE_QUERY_DISTANCE_LIMIT := 1200.0
const MAX_OBSTACLES := 160
const MAX_TOTAL_QUERY_CELLS := 70000
const MAX_PATH_POINTS := 512
const MIN_AGENT_RADIUS := 20.0
const ANCHOR_SEARCH_DISTANCE := 96.0
const FALLBACK_SEARCH_DISTANCE := 640.0
const POSITION_EPSILON := 0.01

var _bounds := Rect2()
var _obstacles: Array[Rect2] = []
var _revision := 0
var _geometry_valid := false
var _request_count := 0
var _success_count := 0
var _fallback_count := 0
var _failure_count := 0
var _budget_rejection_count := 0
var _last_request_usec := 0
var _max_request_usec := 0
var _last_query_cells := 0
var _max_query_cells := 0
var _last_path_points := 0
var _max_path_points := 0
var _last_raw_path_points := 0
var _max_raw_path_points := 0


func update_geometry(bounds: Rect2, obstacles: Array[Rect2]) -> bool:
	_revision += 1
	_bounds = bounds.abs()
	_obstacles.clear()
	_geometry_valid = (
		_bounds.size.x > CELL_SIZE * 2.0
		and _bounds.size.y > CELL_SIZE * 2.0
	)
	if not _geometry_valid:
		return false

	for obstacle in obstacles:
		var normalized := obstacle.abs()
		if (
			normalized.size == Vector2.ZERO
			or not normalized.intersects(_bounds)
		):
			continue
		if _obstacles.size() >= MAX_OBSTACLES:
			_geometry_valid = false
			_budget_rejection_count += 1
			_obstacles.clear()
			return false
		_obstacles.append(normalized)
	_obstacles.sort_custom(_rect_less)
	return true


func revision() -> int:
	return _revision


func obstacle_count() -> int:
	return _obstacles.size()


func find_path(
	start: Vector2,
	requested_destination: Vector2,
	radius: float
) -> Dictionary:
	var started_usec := Time.get_ticks_usec()
	_request_count += 1
	_last_query_cells = 0
	_last_path_points = 0
	_last_raw_path_points = 0
	var result := _empty_result(start, requested_destination)
	if not _geometry_valid or radius < MIN_AGENT_RADIUS:
		return _finish_request(result, started_usec, true)

	var navigation_bounds := _bounds.grow(-radius - CLEARANCE)
	if (
		navigation_bounds.size.x <= 0.0
		or navigation_bounds.size.y <= 0.0
		or not navigation_bounds.grow(POSITION_EPSILON).has_point(start)
		or not _position_clear(start, radius)
	):
		return _finish_request(result, started_usec, true)

	var clamped_destination := _clamp_to_rect(
		requested_destination,
		navigation_bounds
	)
	var exact_destination := (
		requested_destination.distance_squared_to(clamped_destination)
		<= POSITION_EPSILON * POSITION_EPSILON
		and _position_clear(clamped_destination, radius)
	)
	if (
		_position_clear(clamped_destination, radius)
		and _segment_clear(start, clamped_destination, radius)
	):
		var direct_points := PackedVector2Array([start, clamped_destination])
		result["resolved_destination"] = clamped_destination
		result["reachable"] = exact_destination
		result["fallback"] = not exact_destination
		result["points"] = direct_points
		_last_path_points = direct_points.size()
		_max_path_points = maxi(_max_path_points, _last_path_points)
		if exact_destination:
			_success_count += 1
		else:
			_fallback_count += 1
		return _finish_request(result, started_usec, false)
	var best_partial := {}
	var total_query_cells := 0

	for margin in QUERY_MARGINS:
		var query_region := _query_region(
			start,
			clamped_destination,
			navigation_bounds,
			margin,
			CELL_SIZE
		)
		var query_cells := query_region.size.x * query_region.size.y
		if (
			query_cells <= 0
			or total_query_cells + query_cells > MAX_TOTAL_QUERY_CELLS
		):
			_budget_rejection_count += 1
			break
		total_query_cells += query_cells
		_last_query_cells = total_query_cells
		_max_query_cells = maxi(_max_query_cells, total_query_cells)

		var candidate := _attempt_route(
			start,
			clamped_destination,
			radius,
			query_region,
			CELL_SIZE,
			exact_destination
		)
		if candidate.is_empty():
			continue
		if bool(candidate["reached_anchor"]):
			result = candidate
			break
		if (
			best_partial.is_empty()
			or (
				(candidate["resolved_destination"] as Vector2)
				.distance_squared_to(clamped_destination)
				< (best_partial["resolved_destination"] as Vector2)
				.distance_squared_to(clamped_destination)
			)
		):
			best_partial = candidate

	if (
		exact_destination
		and (result.get("points", PackedVector2Array()) as PackedVector2Array)
			.is_empty()
		and start.distance_to(clamped_destination)
		<= FINE_QUERY_DISTANCE_LIMIT
	):
		var fine_region := _query_region(
			start,
			clamped_destination,
			navigation_bounds,
			FINE_QUERY_MARGIN,
			FINE_CELL_SIZE
		)
		var fine_cells := fine_region.size.x * fine_region.size.y
		if (
			fine_cells > 0
			and total_query_cells + fine_cells
			<= MAX_TOTAL_QUERY_CELLS
		):
			total_query_cells += fine_cells
			_last_query_cells = total_query_cells
			_max_query_cells = maxi(_max_query_cells, total_query_cells)
			var fine_candidate := _attempt_route(
				start,
				clamped_destination,
				radius,
				fine_region,
				FINE_CELL_SIZE,
				exact_destination
			)
			if (
				not fine_candidate.is_empty()
				and bool(fine_candidate["reached_anchor"])
			):
				result = fine_candidate
			elif (
				not fine_candidate.is_empty()
				and (
					best_partial.is_empty()
					or (
						(fine_candidate["resolved_destination"] as Vector2)
							.distance_squared_to(clamped_destination)
						< (best_partial["resolved_destination"] as Vector2)
							.distance_squared_to(clamped_destination)
					)
				)
			):
				best_partial = fine_candidate
		else:
			_budget_rejection_count += 1

	if bool(result.get("points", PackedVector2Array()).is_empty()):
		result = best_partial
	if result.is_empty():
		result = _empty_result(start, requested_destination)
		return _finish_request(result, started_usec, true)

	result["requested_destination"] = requested_destination
	result["reachable"] = (
		bool(result["reached_anchor"])
		and exact_destination
		and (result["resolved_destination"] as Vector2)
			.distance_squared_to(requested_destination)
			<= POSITION_EPSILON * POSITION_EPSILON
	)
	result["fallback"] = not bool(result["reachable"])
	result["revision"] = _revision
	result.erase("reached_anchor")
	_last_path_points = (result["points"] as PackedVector2Array).size()
	_max_path_points = maxi(_max_path_points, _last_path_points)
	if bool(result["reachable"]):
		_success_count += 1
	else:
		_fallback_count += 1
	return _finish_request(result, started_usec, false)


func metrics_snapshot() -> Dictionary:
	return {
		"navigation_revision": _revision,
		"navigation_obstacles": _obstacles.size(),
		"navigation_requests": _request_count,
		"navigation_successes": _success_count,
		"navigation_fallbacks": _fallback_count,
		"navigation_failures": _failure_count,
		"navigation_budget_rejections": _budget_rejection_count,
		"navigation_last_request_usec": _last_request_usec,
		"navigation_max_request_usec": _max_request_usec,
		"navigation_last_query_cells": _last_query_cells,
		"navigation_max_query_cells": _max_query_cells,
		"navigation_last_path_points": _last_path_points,
		"navigation_max_path_points": _max_path_points,
		"navigation_last_raw_path_points": _last_raw_path_points,
		"navigation_max_raw_path_points": _max_raw_path_points,
	}


func path_is_clear(points: PackedVector2Array, radius: float) -> bool:
	if points.size() < 2:
		return false
	for index in range(points.size() - 1):
		if not _segment_clear(points[index], points[index + 1], radius):
			return false
	return true


func position_is_clear(position: Vector2, radius: float) -> bool:
	return _position_clear(position, radius)


func _empty_result(start: Vector2, requested_destination: Vector2) -> Dictionary:
	return {
		"requested_destination": requested_destination,
		"resolved_destination": start,
		"reachable": false,
		"fallback": true,
		"revision": _revision,
		"points": PackedVector2Array(),
	}


func _finish_request(
	result: Dictionary,
	started_usec: int,
	failed: bool
) -> Dictionary:
	_last_request_usec = maxi(0, Time.get_ticks_usec() - started_usec)
	_max_request_usec = maxi(_max_request_usec, _last_request_usec)
	if failed:
		_failure_count += 1
	return result


func _query_region(
	start: Vector2,
	destination: Vector2,
	navigation_bounds: Rect2,
	margin: float,
	cell_size: float
) -> Rect2i:
	var request_rect := Rect2(
		Vector2(
			minf(start.x, destination.x),
			minf(start.y, destination.y)
		),
		Vector2(
			absf(start.x - destination.x),
			absf(start.y - destination.y)
		)
	).grow(margin)
	request_rect = request_rect.intersection(navigation_bounds)
	var half_cell := cell_size * 0.5
	var minimum := Vector2i(
		ceili((request_rect.position.x - half_cell) / cell_size),
		ceili((request_rect.position.y - half_cell) / cell_size)
	)
	var maximum := Vector2i(
		floori((request_rect.end.x - half_cell) / cell_size),
		floori((request_rect.end.y - half_cell) / cell_size)
	)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _attempt_route(
	start: Vector2,
	destination: Vector2,
	radius: float,
	query_region: Rect2i,
	cell_size: float,
	exact_destination: bool
) -> Dictionary:
	var grid := _build_grid(query_region, radius, cell_size)
	var start_id := _nearest_anchor(
		grid,
		query_region,
		start,
		radius,
		ceili(ANCHOR_SEARCH_DISTANCE / cell_size),
		true,
		cell_size
	)
	if start_id == Vector2i(-1, -1):
		return {}
	var destination_clear := _position_clear(destination, radius)
	var target_id := _nearest_anchor(
		grid,
		query_region,
		destination,
		radius,
		ceili(
			(
				ANCHOR_SEARCH_DISTANCE
				if destination_clear
				else FALLBACK_SEARCH_DISTANCE
			) / cell_size
		),
		destination_clear,
		cell_size
	)
	if target_id == Vector2i(-1, -1):
		return {}
	var id_path: Array[Vector2i] = grid.get_id_path(
		start_id,
		target_id,
		true
	)
	_last_raw_path_points = id_path.size()
	_max_raw_path_points = maxi(
		_max_raw_path_points,
		_last_raw_path_points
	)
	if id_path.is_empty():
		return {}
	return _route_result(
		id_path,
		grid,
		start,
		destination,
		radius,
		id_path[-1] == target_id,
		exact_destination
	)


func _build_grid(
	region: Rect2i,
	radius: float,
	cell_size: float
) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = region
	grid.cell_size = Vector2.ONE * cell_size
	grid.offset = Vector2.ONE * (cell_size * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()

	for obstacle in _obstacles:
		var expanded := obstacle.grow(radius + CLEARANCE)
		var minimum := Vector2i(
			ceili(
				(expanded.position.x - cell_size * 0.5)
				/ cell_size
			),
			ceili(
				(expanded.position.y - cell_size * 0.5)
				/ cell_size
			)
		)
		var maximum := Vector2i(
			floori(
				(expanded.end.x - cell_size * 0.5)
				/ cell_size
			),
			floori(
				(expanded.end.y - cell_size * 0.5)
				/ cell_size
			)
		)
		minimum.x = maxi(minimum.x, region.position.x)
		minimum.y = maxi(minimum.y, region.position.y)
		maximum.x = mini(maximum.x, region.end.x - 1)
		maximum.y = mini(maximum.y, region.end.y - 1)
		if minimum.x > maximum.x or minimum.y > maximum.y:
			continue
		for x in range(minimum.x, maximum.x + 1):
			for y in range(minimum.y, maximum.y + 1):
				var point_id := Vector2i(x, y)
				if expanded.has_point(grid.get_point_position(point_id)):
					grid.set_point_solid(point_id, true)
	return grid


func _nearest_anchor(
	grid: AStarGrid2D,
	region: Rect2i,
	world_position: Vector2,
	radius: float,
	max_rings: int,
	require_visible: bool,
	cell_size: float
) -> Vector2i:
	var origin := _world_to_cell(world_position, cell_size)
	for ring in range(max_rings + 1):
		var candidates: Array[Vector2i] = []
		for x_offset in range(-ring, ring + 1):
			for y_offset in range(-ring, ring + 1):
				if maxi(absi(x_offset), absi(y_offset)) != ring:
					continue
				var candidate := origin + Vector2i(x_offset, y_offset)
				if (
					not region.has_point(candidate)
					or grid.is_point_solid(candidate)
				):
					continue
				candidates.append(candidate)
		candidates.sort_custom(
			func(left: Vector2i, right: Vector2i) -> bool:
				var left_position := grid.get_point_position(left)
				var right_position := grid.get_point_position(right)
				var left_distance := left_position.distance_squared_to(
					world_position
				)
				var right_distance := right_position.distance_squared_to(
					world_position
				)
				if not is_equal_approx(left_distance, right_distance):
					return left_distance < right_distance
				if left.y != right.y:
					return left.y < right.y
				return left.x < right.x
		)
		for candidate in candidates:
			if (
				not require_visible
				or _segment_clear(
					world_position,
					grid.get_point_position(candidate),
					radius
				)
			):
				return candidate
	return Vector2i(-1, -1)


func _route_result(
	id_path: Array[Vector2i],
	grid: AStarGrid2D,
	start: Vector2,
	destination: Vector2,
	radius: float,
	reached_anchor: bool,
	exact_destination: bool
) -> Dictionary:
	var raw_points := PackedVector2Array([start])
	for point_id in id_path:
		var point := grid.get_point_position(point_id)
		if raw_points[-1].distance_squared_to(point) > POSITION_EPSILON:
			raw_points.append(point)
	var resolved_destination := raw_points[-1]
	if reached_anchor:
		if _segment_clear(resolved_destination, destination, radius):
			resolved_destination = destination
			if (
				raw_points[-1].distance_squared_to(destination)
				> POSITION_EPSILON
			):
				raw_points.append(destination)
	elif not exact_destination:
		resolved_destination = _furthest_clear_point(
			resolved_destination,
			destination,
			radius
		)
		if (
			raw_points[-1].distance_squared_to(resolved_destination)
			> POSITION_EPSILON
		):
			raw_points.append(resolved_destination)

	var smoothed := _smooth_path(raw_points, radius)
	if (
		smoothed.size() < 2
		or smoothed.size() > MAX_PATH_POINTS
		or not path_is_clear(smoothed, radius)
	):
		return {}
	return {
		"resolved_destination": resolved_destination,
		"points": smoothed,
		"reached_anchor": reached_anchor,
	}


func _smooth_path(
	raw_points: PackedVector2Array,
	radius: float
) -> PackedVector2Array:
	if raw_points.size() <= 2:
		return raw_points
	var result := PackedVector2Array([raw_points[0]])
	var current_index := 0
	while current_index < raw_points.size() - 1:
		var next_index := current_index + 1
		for candidate_index in range(
			raw_points.size() - 1,
			current_index,
			-1
		):
			if _segment_clear(
				raw_points[current_index],
				raw_points[candidate_index],
				radius
			):
				next_index = candidate_index
				break
		if next_index <= current_index:
			return PackedVector2Array()
		result.append(raw_points[next_index])
		current_index = next_index
	return result


func _furthest_clear_point(
	start: Vector2,
	destination: Vector2,
	radius: float
) -> Vector2:
	if _segment_clear(start, destination, radius):
		return destination
	var lower := 0.0
	var upper := 1.0
	for _step in 10:
		var middle := (lower + upper) * 0.5
		if _segment_clear(start, start.lerp(destination, middle), radius):
			lower = middle
		else:
			upper = middle
	return start.lerp(destination, lower)


func _position_clear(position: Vector2, radius: float) -> bool:
	var navigation_bounds := _bounds.grow(-radius - CLEARANCE)
	if not navigation_bounds.grow(POSITION_EPSILON).has_point(position):
		return false
	for obstacle in _obstacles:
		if obstacle.grow(radius + CLEARANCE).has_point(position):
			return false
	return true


func _segment_clear(from: Vector2, to: Vector2, radius: float) -> bool:
	var navigation_bounds := _bounds.grow(-radius - CLEARANCE)
	if (
		not navigation_bounds.grow(POSITION_EPSILON).has_point(from)
		or not navigation_bounds.grow(POSITION_EPSILON).has_point(to)
	):
		return false
	for obstacle in _obstacles:
		if _rect_intersects_segment(
			obstacle.grow(radius + CLEARANCE),
			from,
			to
		):
			return false
	return true


func _world_to_cell(position: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(
		floori(position.x / cell_size),
		floori(position.y / cell_size)
	)


func _clamp_to_rect(position: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clampf(position.x, rect.position.x, rect.end.x),
		clampf(position.y, rect.position.y, rect.end.y)
	)


static func _rect_less(left: Rect2, right: Rect2) -> bool:
	if not is_equal_approx(left.position.y, right.position.y):
		return left.position.y < right.position.y
	if not is_equal_approx(left.position.x, right.position.x):
		return left.position.x < right.position.x
	if not is_equal_approx(left.size.y, right.size.y):
		return left.size.y < right.size.y
	return left.size.x < right.size.x


static func _rect_intersects_segment(
	rect: Rect2,
	from: Vector2,
	to: Vector2
) -> bool:
	if rect.has_point(from) or rect.has_point(to):
		return true
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right := rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	return (
		Geometry2D.segment_intersects_segment(
			from,
			to,
			top_left,
			top_right
		) != null
		or Geometry2D.segment_intersects_segment(
			from,
			to,
			top_right,
			bottom_right
		) != null
		or Geometry2D.segment_intersects_segment(
			from,
			to,
			bottom_right,
			bottom_left
		) != null
		or Geometry2D.segment_intersects_segment(
			from,
			to,
			bottom_left,
			top_left
		) != null
	)
