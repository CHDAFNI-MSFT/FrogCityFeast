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
			),
		"Long-distance travel keeps loaded districts, buildings, and targets capped."
	)

	game.queue_free()
	await process_frame


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
