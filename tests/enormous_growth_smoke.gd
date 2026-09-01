extends SceneTree

const GAME_SCENE := preload("res://scenes/game.tscn")
const TUNING := preload("res://src/gameplay_tuning.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tuning_catalog()
	await _test_growth_and_rooms()
	await _test_navigation_and_eligibility()
	await _finish()


func _test_tuning_catalog() -> void:
	var item := BellyItem.new()
	item.base_value = 100
	item.size_tier = 2
	item.accuracy = 0.8
	item.rare = true
	item.dangerous_location = true
	item.captured_while_chased = true
	_check(
		TUNING.GROWTH_THRESHOLDS == [100, 500, 1700]
			and TUNING.FROG_TIER_RADII == [28.0, 35.0, 44.0, 66.0]
			and TUNING.FROG_TIER_TONGUE_RANGES
			== [380.0, 500.0, 650.0, 900.0],
		"The four growth tiers use the exact deterministic values."
	)
	_check(
		item.score_value() == 361
			and TUNING.growth_value(100, 2, true) == 170,
		"Score and growth rewards use the rebalanced formulas."
	)
	_check(
		TUNING.struggle_taps_required(9, 1, 1) == 9
			and TUNING.struggle_taps_required(9, 1, 3) == 7
			and TUNING.struggle_taps_required(5, 0, 3) == 4,
		"Growth advantage reduces struggle taps without dropping below four."
	)
	_check(
		TUNING.VEHICLE_COLLISION_PENALTY == 10
			and TUNING.ANIMAL_CONTROL_CONTACT_PENALTY == 20
			and TUNING.ANIMAL_CONTROL_NET_PENALTY == 22
			and TUNING.ANIMAL_CONTROL_TRAP_PENALTY == 12
			and TUNING.SECURITY_CONTACT_PENALTY == 16
			and TUNING.SECURITY_FLASHLIGHT_PENALTY == 10
			and TUNING.WATCHDOG_CONTACT_PENALTY == 12
			and TUNING.WATCHDOG_LUNGE_PENALTY == 14,
		"Every rebalanced pursuit and traffic penalty is explicit."
	)


func _test_growth_and_rooms() -> void:
	var game := _new_game("enormous_growth", false)
	var profile_unlocks: Array[String] = []
	var device_unlocks: Array[String] = []
	game.profile_achievement_unlocked.connect(
		func(achievement_id: String, _clue_id: String) -> void:
			profile_unlocks.append(achievement_id)
	)
	game.device_achievement_unlocked.connect(
		func(achievement_id: String) -> void:
			device_unlocks.append(achievement_id)
	)
	root.add_child(game)
	await process_frame
	await physics_frame

	var baseline := game.performance_structure_snapshot()
	var outside_position := game._frog.global_position
	var stockroom := (
		game._interior_rooms.get(FrogGame.STOCKROOM_ID)
		as PrototypeInteriorRoom
	)
	game._growth_tier = TUNING.LARGE_TIER
	game._frog.set_growth_tier(TUNING.LARGE_TIER)
	game._active_interior_id = FrogGame.STOCKROOM_ID
	game._frog.global_position = stockroom.global_position
	game._growth_points = TUNING.GROWTH_THRESHOLDS[-1]
	game._apply_growth_thresholds()
	_check(
		game._growth_tier == TUNING.LARGE_TIER
			and game._pending_growth_tier == TUNING.ENORMOUS_TIER
			and game._status_label.text.contains("Return outdoors"),
		"Enormous growth waits while the frog is inside a separate room."
	)

	game._active_interior_id = ""
	game._frog.global_position = outside_position
	game._last_safe_ground_position = outside_position
	game._camera.rotation = 0.31
	game._retry_pending_growth()
	game._update_camera()
	var shape := game._frog._collision_shape.shape as CircleShape2D
	_check(
		game._growth_tier == TUNING.ENORMOUS_TIER
			and game._pending_growth_tier == -1
			and is_equal_approx(game._frog.collision_radius(), 66.0)
			and is_equal_approx(
				shape.radius * game._frog.scale.x,
				66.0
			),
		"Outdoor enormous growth updates visual and collision size together."
	)
	_check(
		game._camera.zoom == TUNING.city_camera_zoom(TUNING.ENORMOUS_TIER)
			and is_equal_approx(game._camera.rotation, 0.31)
			and is_equal_approx(
				game._camera.global_position.distance_to(
					game._frog.global_position
				),
				TUNING.city_camera_forward_offset(TUNING.ENORMOUS_TIER)
			),
		"Enormous camera framing zooms out without resetting rotation."
	)
	_check(
		profile_unlocks.count("enormous_appetite") == 1
			and device_unlocks.count("device_enormous_growth") == 1,
		"First enormous growth emits one profile and one device milestone."
	)
	var market := game._building_by_id.get(
		"moonlight_market"
	) as PrototypeBuilding
	_check(
		game._interior_transition_requirement(market).contains(
			"cannot fit"
		),
		"An enormous frog cannot enter compact authored rooms."
	)
	game._active_interior_id = FrogGame.STOCKROOM_ID
	var return_portal := stockroom.portal_to_destination("city")
	_check(
		game._interior_portal_requirement(return_portal).is_empty(),
		"Room exits remain usable if an enormous state is restored indoors."
	)
	game._active_interior_id = ""
	var enormous_snapshot := game.performance_structure_snapshot()
	_check(
		int(enormous_snapshot["game_nodes"])
			== int(baseline["game_nodes"])
			and int(enormous_snapshot["collision_objects"])
			== int(baseline["collision_objects"])
			and int(enormous_snapshot["collision_shapes"])
			== int(baseline["collision_shapes"])
			and int(enormous_snapshot["targets"])
			== int(baseline["targets"])
			and int(enormous_snapshot["buildings"])
			== int(baseline["buildings"]),
		"Enormous growth adds no structural nodes or collision objects."
	)

	game.queue_free()
	await process_frame


func _test_navigation_and_eligibility() -> void:
	var game := _new_game("enormous_navigation", true)
	root.add_child(game)
	await process_frame
	await physics_frame
	game._apply_growth_tier(TUNING.ENORMOUS_TIER)

	var vehicle := _find_target(game, "delivery_van")
	var whole_building: EdibleTarget
	for target in game._targets:
		if target.kind == "building":
			whole_building = target
			break
	_check(
		vehicle != null
			and vehicle.can_be_swallowed(TUNING.LARGE_TIER)
			and whole_building != null
			and whole_building.size_tier
			== TUNING.WHOLE_BUILDING_EDIBLE_TIER
			and game._can_swallow_pursuer(),
		"Vehicles and weakened buildings stay large-tier targets; pursuers require enormous growth."
	)
	game._growth_tier = TUNING.LARGE_TIER
	game._frog.set_growth_tier(TUNING.LARGE_TIER)
	_check(
		not game._can_swallow_pursuer(),
		"Large growth cannot swallow a pursuer before the enormous tier."
	)
	game._apply_growth_tier(TUNING.ENORMOUS_TIER)

	for coordinate in [
		Vector2i(1, 0),
		game._secret_district_coordinate,
	]:
		game._frog.global_position = (
			DistrictGenerator.bounds_for_coordinate(coordinate).get_center()
		)
		game._current_district_coordinate = coordinate
		game._update_district_streaming(true)
		await process_frame
		await physics_frame
		game._invalidate_navigation()
		game._refresh_navigation_geometry()
		_check(
			_enormous_route_around_district_building(game, coordinate),
			"Enormous navigation remains clear in district %d,%d."
			% [coordinate.x, coordinate.y]
		)

	game._spawn_pursuer()
	game._spawn_pursuit_trap()
	_check(
		is_instance_valid(game._pursuer)
			and is_instance_valid(game._pursuit_trap)
			and not game._pursuit_trap_can_trigger(),
		"Enormous growth leaves pursuers edible but disables their traps."
	)
	var score_before := game._score
	game._on_pursuer_caught(game._frog.global_position)
	_check(
		game._score == score_before,
		"Enormous growth is immune to pursuer contact damage."
	)

	game.queue_free()
	await process_frame


func _enormous_route_around_district_building(
	game: FrogGame,
	coordinate: Vector2i
) -> bool:
	var building: PrototypeBuilding
	for candidate in game._buildings:
		if (
			is_instance_valid(candidate)
			and candidate.has_meta("district_coordinate")
			and candidate.get_meta("district_coordinate") == coordinate
		):
			building = candidate
			break
	if not is_instance_valid(building):
		return false
	var footprint := building.footprint_rect()
	var offset := Vector2(footprint.size.x * 0.5 + 180.0, 0.0)
	var route := game._navigation.find_path(
		footprint.get_center() - offset,
		footprint.get_center() + offset,
		PlayerFrog.TIER_RADII[-1]
	)
	var points := route["points"] as PackedVector2Array
	return (
		bool(route["reachable"])
		and not bool(route["fallback"])
		and points.size() >= 4
		and game._navigation.path_is_clear(
			points,
			PlayerFrog.TIER_RADII[-1]
		)
	)


func _new_game(profile_id: String, secret_unlocked: bool) -> FrogGame:
	var game := GAME_SCENE.instantiate() as FrogGame
	game.configure(
		profile_id,
		"Enormous Tester",
		false,
		PackedStringArray(),
		{"reduce_motion": true, "larger_text_controls": false},
		{},
		0x454e4f52,
		PackedStringArray(),
		PackedStringArray(),
		PackedStringArray(),
		PackedStringArray(),
		PackedStringArray([
			ProgressionCatalog.SECRET_FANTASY_DISTRICT
		]) if secret_unlocked else PackedStringArray()
	)
	return game


func _find_target(game: FrogGame, target_id: String) -> EdibleTarget:
	for target in game._targets:
		if is_instance_valid(target) and target.target_id == target_id:
			return target
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Enormous growth smoke test passed.")
		quit(0)
		return
	print("Enormous growth smoke test failed:")
	for failure in _failures:
		print("- %s" % failure)
	quit(1)
