extends SceneTree

const GENERATOR := preload("res://src/district_generator.gd")
const DISTRICT_SCENE := preload("res://src/generated_district.gd")
const GAME_SCENE := preload("res://scenes/game.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_value := 0x51A7C17
	var coordinate := Vector2i(3, -2)
	var first := GENERATOR.generate(seed_value, coordinate)
	var second := GENERATOR.generate(seed_value, coordinate)
	var different := GENERATOR.generate(seed_value + 1, coordinate)
	_check(
		first.snapshot() == second.snapshot(),
		"District generation is reproducible for a session seed and coordinate."
	)
	_check(
		first.snapshot() != different.snapshot(),
		"Changing the session seed changes the generated district."
	)
	_check(
		GENERATOR.coordinate_for_position(
			GENERATOR.bounds_for_coordinate(coordinate).get_center()
		) == coordinate,
		"District coordinates and world bounds round-trip."
	)

	seed(20260831)
	var expected_random := randf()
	seed(20260831)
	for x in range(-4, 5):
		for y in range(-4, 5):
			if x == 0 and y == 0:
				continue
			GENERATOR.generate(seed_value, Vector2i(x, y))
	var actual_random := randf()
	_check(
		is_equal_approx(actual_random, expected_random),
		"District generation does not consume the gameplay random-number stream."
	)

	var archetypes := {}
	var all_layouts_safe := true
	for x in range(-6, 7):
		for y in range(-6, 7):
			if x == 0 and y == 0:
				continue
			var definition := GENERATOR.generate(
				seed_value,
				Vector2i(x, y)
			)
			archetypes[definition.archetype_id] = true
			if not GENERATOR.validation_errors(definition).is_empty():
				all_layouts_safe = false
	_check(
		archetypes.size() >= 4,
		"Generation exposes at least four distinct district archetypes."
	)
	_check(
		all_layouts_safe,
		"Generated streets, buildings, obstacles, and targets keep safe clearances."
	)
	_check(
		first.buildings.size() == GENERATOR.BUILDINGS_PER_DISTRICT
			and first.targets.size() == GENERATOR.LOOSE_TARGETS_PER_DISTRICT
			and first.restock_positions.size() >= 4,
		"Every generated district has bounded buildings, targets, and open restock areas."
	)

	var district := DISTRICT_SCENE.new() as GeneratedDistrict
	district.configure(first)
	root.add_child(district)
	await process_frame
	_check(
		district.get_child_count() <= 1,
		"District backdrop and environmental collision use a bounded node scaffold."
	)
	district.queue_free()
	await process_frame
	await _test_game_streaming(seed_value)
	await _test_transition_regressions(seed_value)
	await _finish()


func _test_game_streaming(seed_value: int) -> void:
	var game := GAME_SCENE.instantiate() as FrogGame
	game.configure(
		"district_streaming",
		"District Streaming",
		false,
		PackedStringArray(),
		{},
		{},
		seed_value
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	_check(
		game._loaded_districts.is_empty()
			and game._current_district_coordinate == Vector2i.ZERO,
		"The authored central district remains the unloaded-generation starting core."
	)
	var authored_target := game._find_target_by_id("street_donut")
	game._swallow_target(authored_target, 1.0)

	seed(20260831)
	var expected_random := randf()
	seed(20260831)
	game._frog.global_position = Vector2(
		FrogGame.WORLD_RECT.end.x - 120.0,
		0
	)
	game._update_district_streaming()
	await process_frame
	var actual_random := randf()
	_check(
		is_equal_approx(actual_random, expected_random),
		"Streaming generated nodes does not consume gameplay randomness."
	)
	_check(
		game._loaded_districts.has(Vector2i(1, 0))
			and game._loaded_districts.size() == 1,
		"Approaching the authored east boundary streams the neighboring district."
	)
	_check(
		game._active_navigation_rect().end.x
			== GENERATOR.bounds_for_coordinate(Vector2i(1, 0)).end.x,
		"Loaded neighbors extend movement and camera-follow navigation."
	)

	var district_coordinate := Vector2i(1, 0)
	game._frog.global_position = GENERATOR.bounds_for_coordinate(
		district_coordinate
	).get_center()
	game._update_district_streaming()
	await process_frame
	await physics_frame
	var authored_belly_index := -1
	for index in game._belly.size():
		if game._belly[index].target_id == "street_donut":
			authored_belly_index = index
			break
	game._spit_item(authored_belly_index)
	var relocated_authored := game._find_target_by_id("street_donut")
	var relocated_authored_instance_id := (
		relocated_authored.world_instance_id
	)
	_check(
		not relocated_authored_instance_id.is_empty()
			and relocated_authored.district_coordinate
			== district_coordinate,
		"Spitting an authored item in a generated district adopts bounded district tracking."
	)
	var building := _generated_building(game, district_coordinate)
	_check(
		is_instance_valid(building)
			and building.contains_world_point(
				building.global_position
				+ Vector2(0, building.building_size.y * 0.38)
			),
		"Generated buildings expose physical enterable shells."
	)
	var generated_definition := game._district_definition(
		district_coordinate
	)
	var generated_clearances_safe := true
	for restock_position in generated_definition.restock_positions:
		if not game._circle_position_clear(
			restock_position,
			game._frog.collision_radius(),
			true
		):
			generated_clearances_safe = false
	var entrance_position := _building_entrance_position(building)
	if not game._circle_position_clear(
		entrance_position,
		game._frog.collision_radius(),
		true
	):
		generated_clearances_safe = false
	_check(
		generated_clearances_safe,
		"Generated open areas and building entrances are clear in live physics."
	)
	var sign := _building_part_target(
		game,
		building.building_id,
		PrototypeBuilding.PART_SIGN
	)
	var sign_instance_id := sign.world_instance_id
	game._swallow_target(sign, 1.0)
	_check(
		building.is_part_removed(PrototypeBuilding.PART_SIGN)
			and _target_by_instance(game, sign_instance_id) == null,
		"Generated building destruction updates live district state."
	)

	var loose_target := _generated_loose_target(
		game,
		district_coordinate
	)
	var loose_instance_id := loose_target.world_instance_id
	loose_target.flee_from(game._frog.global_position)
	loose_target.velocity = Vector2.ZERO
	loose_target.global_position += Vector2(18, 12)
	var moved_position := loose_target.global_position

	game._frog.global_position = GENERATOR.bounds_for_coordinate(
		Vector2i(4, 0)
	).get_center()
	game._update_district_streaming()
	await process_frame
	await process_frame
	var far_snapshot := game.performance_structure_snapshot()
	_check(
		not game._loaded_districts.has(district_coordinate)
			and int(far_snapshot["loaded_generated_districts"])
			<= GENERATOR.MAX_LOADED_GENERATED_DISTRICTS
			and int(far_snapshot["generated_buildings"])
			<= GENERATOR.MAX_LOADED_GENERATED_DISTRICTS
			* GENERATOR.BUILDINGS_PER_DISTRICT,
		"Travel unloads distant districts while keeping generated nodes bounded."
	)

	game._frog.global_position = GENERATOR.bounds_for_coordinate(
		district_coordinate
	).get_center()
	game._update_district_streaming()
	await process_frame
	await physics_frame
	building = _generated_building(game, district_coordinate)
	var restored_loose := _target_by_instance(game, loose_instance_id)
	_check(
		is_instance_valid(building)
			and building.is_part_removed(PrototypeBuilding.PART_SIGN)
			and _target_by_instance(game, sign_instance_id) == null,
		"Revisiting restores removed generated building parts."
	)
	_check(
		is_instance_valid(restored_loose)
			and restored_loose.global_position.is_equal_approx(
				moved_position
			),
		"Revisiting restores generated target world state."
	)
	_check(
		is_instance_valid(
			_target_by_instance(
				game,
				relocated_authored_instance_id
			)
		),
		"Revisiting restores authored items relocated into generated districts."
	)

	for part_id in [
		PrototypeBuilding.PART_DOOR,
		PrototypeBuilding.PART_COUNTER,
	]:
		var part_target := _building_part_target(
			game,
			building.building_id,
			part_id
		)
		game._swallow_target(part_target, 1.0)
	var whole_target := _building_whole_target(
		game,
		building.building_id
	)
	var whole_instance_id := whole_target.world_instance_id
	game._swallow_target(whole_target, 1.0)
	_check(
		building.consumed,
		"Generated buildings can be fully swallowed after staged destruction."
	)

	game._frog.global_position = GENERATOR.bounds_for_coordinate(
		Vector2i(5, 0)
	).get_center()
	game._update_district_streaming()
	await process_frame
	game._frog.global_position = GENERATOR.bounds_for_coordinate(
		district_coordinate
	).get_center()
	game._update_district_streaming()
	await process_frame
	building = _generated_building(game, district_coordinate)
	_check(
		is_instance_valid(building)
			and building.consumed
			and _target_by_instance(game, whole_instance_id) == null,
		"Revisiting restores a swallowed generated building as consumed."
	)

	var whole_belly_index := -1
	for index in game._belly.size():
		if (
			game._belly[index].kind == "building"
			and game._belly[index].building_id == building.building_id
		):
			whole_belly_index = index
			break
	game._frog.global_position = GENERATOR.bounds_for_coordinate(
		district_coordinate
	).get_center()
	game._spit_item(whole_belly_index)
	_check(
		not building.consumed
			and building.weakness_count()
			== PrototypeBuilding.REQUIRED_WEAKNESS
			and is_instance_valid(
				_target_by_instance(game, whole_instance_id)
			),
		"Spitting restores a generated building with removed parts preserved."
	)

	var max_loaded := 0
	var max_generated_buildings := 0
	var max_generated_targets := 0
	var max_definition_records := 0
	var max_state_records := 0
	for x in range(2, 18):
		game._frog.global_position = GENERATOR.bounds_for_coordinate(
			Vector2i(x, 2)
		).get_center()
		game._update_district_streaming()
		await process_frame
		var snapshot := game.performance_structure_snapshot()
		max_loaded = maxi(
			max_loaded,
			int(snapshot["loaded_generated_districts"])
		)
		max_generated_buildings = maxi(
			max_generated_buildings,
			int(snapshot["generated_buildings"])
		)
		max_generated_targets = maxi(
			max_generated_targets,
			int(snapshot["generated_targets"])
		)
		max_definition_records = maxi(
			max_definition_records,
			int(snapshot["generated_district_records"])
		)
		max_state_records = maxi(
			max_state_records,
			int(snapshot["district_state_records"])
		)
	_check(
		max_loaded <= GENERATOR.MAX_LOADED_GENERATED_DISTRICTS
			and max_generated_buildings
			<= GENERATOR.MAX_LOADED_GENERATED_DISTRICTS
			* GENERATOR.BUILDINGS_PER_DISTRICT
			and max_generated_targets
			<= GENERATOR.MAX_LOADED_GENERATED_DISTRICTS
			* (
				GENERATOR.LOOSE_TARGETS_PER_DISTRICT
				+ GENERATOR.BUILDINGS_PER_DISTRICT * 4
			)
			and max_definition_records
			<= GENERATOR.MAX_LOADED_GENERATED_DISTRICTS
			and max_state_records == 1,
		"Long-distance travel caps loaded content and retains only changed district state."
	)

	var future_coordinate := Vector2i(40, 40)
	var future_key := game._district_key(future_coordinate)
	var unload_state := game._district_state(future_coordinate)
	var unchanged_building := PrototypeBuilding.new()
	unchanged_building.building_id = "future_unchanged"
	unchanged_building.set_meta(
		"district_coordinate",
		future_coordinate
	)
	var changed_building := PrototypeBuilding.new()
	changed_building.building_id = "future_changed"
	changed_building.set_meta(
		"district_coordinate",
		future_coordinate
	)
	changed_building.remove_part(PrototypeBuilding.PART_SIGN)
	game._capture_generated_building_state(unchanged_building)
	game._capture_generated_building_state(changed_building)
	if game._district_state_is_empty(unload_state):
		game._district_states.erase(future_key)
	var captured_state := game._district_states.get(
		future_key,
		{}
	) as Dictionary
	var captured_buildings := captured_state.get(
		"building_states",
		{}
	) as Dictionary
	_check(
		captured_buildings.has(changed_building.building_id),
		"Capturing an unchanged building cannot discard a later changed building."
	)
	unchanged_building.free()
	changed_building.free()
	game._district_states.erase(future_key)

	game.queue_free()
	await process_frame


func _test_transition_regressions(seed_value: int) -> void:
	var game := GAME_SCENE.instantiate() as FrogGame
	game.configure(
		"district_regressions",
		"District Regressions",
		false,
		PackedStringArray(),
		{},
		{},
		seed_value
	)
	root.add_child(game)
	await process_frame
	await physics_frame

	var living_target := game._find_target_by_id("market_vendor")
	game._swallow_target(living_target, 1.0)
	game._digest_item(0)
	game._frog.global_position = GENERATOR.bounds_for_coordinate(
		Vector2i(1, 0)
	).get_center()
	game._update_district_streaming()
	await create_timer(4.2).timeout
	_check(
		is_instance_valid(game._find_target_by_id("market_vendor")),
		"Authored Belly restocking completes while the frog explores another district."
	)

	game._spawn_pursuer()
	game._roadblock_deploy_time = 0.0
	game._update_pursuit_roadblock(0.1)
	game._pursuit_trap_deploy_time = 0.0
	game._update_pursuit_trap(0.1)
	var prior_roadblock := game._roadblock
	var prior_trap := game._pursuit_trap
	game._frog.global_position = GENERATOR.bounds_for_coordinate(
		Vector2i(2, 0)
	).get_center()
	game._update_district_streaming()
	_check(
		is_instance_valid(game._pursuer)
			and (
				not is_instance_valid(prior_roadblock)
				or prior_roadblock.is_queued_for_deletion()
			)
			and (
				not is_instance_valid(prior_trap)
				or prior_trap.is_queued_for_deletion()
			),
		"Crossing a district boundary preserves pursuit while clearing location-bound traps."
	)

	game._camera.rotation = 0.42
	game._update_camera()
	var expected_camera_position := (
		game._frog.global_position
		+ Vector2.UP.rotated(game._camera.rotation) * 220.0
	)
	_check(
		game._camera.global_position.is_equal_approx(
			expected_camera_position
		),
		"Camera follow behavior remains continuous in generated districts."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer._escape()
	await process_frame

	game._frog.global_position = Vector2.ZERO
	game._update_district_streaming()
	await process_frame
	var cafe := (
		game._building_by_id.get("leap_cafe") as PrototypeBuilding
	)
	game.set_motion_scale(0.0)
	game._frog.global_position = cafe.transition_door_approach_position()
	game._begin_interior_transition(FrogGame.STOCKROOM_ID)
	var loaded_before_room := game._loaded_districts.size()
	game._update_district_streaming()
	var stockroom := (
		game._interior_rooms.get(FrogGame.STOCKROOM_ID)
		as PrototypeInteriorRoom
	)
	_check(
		game._active_interior_id == FrogGame.STOCKROOM_ID
			and game._current_district_coordinate == Vector2i.ZERO
			and game._loaded_districts.size() == loaded_before_room
			and game._camera.global_position.is_equal_approx(
				stockroom.global_position
			),
		"Separate-room scoping and centered camera ignore procedural coordinates."
	)
	game._begin_interior_transition("city")
	_check(
		game._active_interior_id.is_empty()
			and game._frog.global_position.is_equal_approx(
				cafe.transition_door_approach_position()
			),
		"Returning from an authored room restores the city position after streaming."
	)

	var sewer_portal := game._city_portal_by_id("river_sewer_hatch")
	game._frog.global_position = (
		sewer_portal["approach_position"] as Vector2
	)
	game._begin_interior_transition(
		FrogGame.RIVER_SEWER_JUNCTION_ID,
		"river_sewer_hatch"
	)
	var junction := (
		game._interior_rooms.get(FrogGame.RIVER_SEWER_JUNCTION_ID)
		as PrototypeInteriorRoom
	)
	game._record_discovery("river_sewer_valve")
	var hidden_portal := junction.portal_by_id(
		"hidden_maintenance_hatch"
	)
	game._frog.global_position = junction.portal_approach_position(
		hidden_portal
	)
	game._begin_interior_transition(
		FrogGame.RIVER_HIDDEN_MAINTENANCE_ID,
		"hidden_maintenance_hatch"
	)
	var loaded_before_chain := game._loaded_districts.size()
	game._update_district_streaming()
	_check(
		game._active_interior_id
			== FrogGame.RIVER_HIDDEN_MAINTENANCE_ID
			and game._current_district_coordinate == Vector2i.ZERO
			and game._loaded_districts.size() == loaded_before_chain,
		"Hidden multi-stage exploration pauses generated-district unloading."
	)
	var hidden_room := (
		game._interior_rooms.get(FrogGame.RIVER_HIDDEN_MAINTENANCE_ID)
		as PrototypeInteriorRoom
	)
	game._frog.global_position = hidden_room.exit_approach_position()
	game._begin_interior_transition(
		FrogGame.RIVER_SEWER_JUNCTION_ID,
		"return"
	)
	game._frog.global_position = junction.exit_approach_position()
	game._begin_interior_transition("city", "return")
	_check(
		game._active_interior_id.is_empty()
			and game._frog.global_position.is_equal_approx(
				sewer_portal["approach_position"] as Vector2
			),
		"Returning from the hidden sewer branch restores a loaded River Park."
	)

	game.queue_free()
	await process_frame


func _building_entrance_position(
	building: PrototypeBuilding
) -> Vector2:
	var half := building.building_size / 2.0
	match building.door_side:
		"north":
			return building.global_position + Vector2(0, -half.y + 44.0)
		"south":
			return building.global_position + Vector2(0, half.y - 44.0)
		"east":
			return building.global_position + Vector2(half.x - 44.0, 0)
		_:
			return building.global_position + Vector2(-half.x + 44.0, 0)


func _generated_building(
	game: FrogGame,
	coordinate: Vector2i
) -> PrototypeBuilding:
	for building in game._buildings:
		if (
			is_instance_valid(building)
			and building.has_meta("district_coordinate")
			and building.get_meta("district_coordinate") == coordinate
		):
			return building
	return null


func _building_part_target(
	game: FrogGame,
	building_id: String,
	part_id: String
) -> EdibleTarget:
	for target in game._targets:
		if (
			is_instance_valid(target)
			and target.building_id == building_id
			and target.building_part_id == part_id
		):
			return target
	return null


func _building_whole_target(
	game: FrogGame,
	building_id: String
) -> EdibleTarget:
	for target in game._targets:
		if (
			is_instance_valid(target)
			and target.building_id == building_id
			and target.kind == "building"
		):
			return target
	return null


func _generated_loose_target(
	game: FrogGame,
	coordinate: Vector2i
) -> EdibleTarget:
	for target in game._targets:
		if (
			is_instance_valid(target)
			and target.district_coordinate == coordinate
			and target.building_id.is_empty()
		):
			return target
	return null


func _target_by_instance(
	game: FrogGame,
	instance_id: String
) -> EdibleTarget:
	for target in game._targets:
		if (
			is_instance_valid(target)
			and target.world_instance_id == instance_id
		):
			return target
	return null


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	AudioDirector.reset_for_tests()
	await create_timer(0.2).timeout
	AudioDirector.shutdown_for_tests()
	for _frame in 2:
		await process_frame
	if _failures.is_empty():
		print("District generation smoke tests passed.")
		quit(0)
	else:
		print(
			"District generation smoke tests failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
