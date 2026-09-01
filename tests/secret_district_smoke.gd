extends SceneTree

const GENERATOR := preload("res://src/district_generator.gd")
const GAME_SCENE := preload("res://scenes/game.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_value := 0x5EC7E7
	_test_secret_generation(seed_value)
	await _test_locked_path(seed_value)
	await _test_unlock_during_swallow(seed_value + 2)
	await _test_unlocked_path(seed_value)
	await _finish()


func _test_secret_generation(seed_value: int) -> void:
	var coordinate := GENERATOR.secret_coordinate(seed_value)
	var repeated := GENERATOR.secret_coordinate(seed_value)
	var next_city := GENERATOR.secret_coordinate(seed_value + 1)
	var distance := maxi(absi(coordinate.x), absi(coordinate.y))
	_check(
		coordinate == repeated
		and coordinate != next_city
		and distance >= GENERATOR.SECRET_MIN_DISTANCE
		and distance <= GENERATOR.SECRET_MAX_DISTANCE,
		"Each session seed chooses one deterministic, distant secret coordinate."
	)

	var first := GENERATOR.generate_secret(seed_value, coordinate)
	var second := GENERATOR.generate_secret(seed_value, coordinate)
	var ordinary := GENERATOR.generate(seed_value, coordinate)
	var target_ids := {}
	for target_value in first.targets:
		var target := target_value as Dictionary
		target_ids[str(target["id"])] = true
	_check(
		first.snapshot() == second.snapshot()
		and first.archetype_id == "secret_fantasy"
		and first.display_name == "Starfall Quarter"
		and first.district_id.begins_with("secret_district_")
		and ordinary.archetype_id != "secret_fantasy"
		and target_ids == {"generated_park_picnic": true},
		"Secret content is deterministic, distinct, and reuses finite Field Guide IDs."
	)
	_check(
		GENERATOR.validation_errors(first).is_empty(),
		"Secret streets, building, obstacles, targets, and portal lane keep safe clearances."
	)
	var max_environment_bodies := 0
	var max_obstacle_shapes := 0
	for sample_seed in range(1, 257):
		var center_coordinate := GENERATOR.secret_coordinate(sample_seed)
		var environment_bodies := 0
		var obstacle_shapes := 0
		for x_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				var sample_coordinate := (
					center_coordinate + Vector2i(x_offset, y_offset)
				)
				var definition := (
					GENERATOR.generate_secret(
						sample_seed,
						sample_coordinate
					)
					if sample_coordinate == center_coordinate
					else GENERATOR.generate(
						sample_seed,
						sample_coordinate
					)
				)
				if not definition.obstacles.is_empty():
					environment_bodies += 1
					obstacle_shapes += definition.obstacles.size()
		max_environment_bodies = maxi(
			max_environment_bodies,
			environment_bodies
		)
		max_obstacle_shapes = maxi(max_obstacle_shapes, obstacle_shapes)
	_check(
		max_environment_bodies
			<= PerformanceBudgets.MAX_SECRET_RING_ENVIRONMENT_BODIES
		and max_obstacle_shapes
			<= PerformanceBudgets.MAX_SECRET_RING_OBSTACLE_SHAPES,
		"Representative secret rings stay below the theoretical obstacle maxima."
	)


func _test_locked_path(seed_value: int) -> void:
	var game := _new_game(
		"secret_locked",
		seed_value,
		PackedStringArray()
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	var hidden := (
		game._interior_rooms.get(FrogGame.RIVER_HIDDEN_MAINTENANCE_ID)
		as PrototypeInteriorRoom
	)
	var portal := hidden.portal_by_id("secret_star_path")
	_check(
		not bool(portal.get("visible", true))
		and game._district_definition(
			game._secret_district_coordinate
		).archetype_id != "secret_fantasy",
		"Profiles without the clue unlock see no path or secret generator override."
	)
	game._active_interior_id = FrogGame.RIVER_HIDDEN_MAINTENANCE_ID
	game._frog.global_position = hidden.portal_approach_position(portal)
	game._begin_interior_transition(
		FrogGame.SECRET_DISTRICT_DESTINATION,
		"secret_star_path"
	)
	_check(
		game._active_interior_id
			== FrogGame.RIVER_HIDDEN_MAINTENANCE_ID
		and game._loaded_districts.is_empty(),
		"A hidden path cannot be entered by calling the transition directly."
	)
	var reserved_coordinate := game._secret_district_coordinate
	game._active_interior_id = ""
	game._frog.global_position = GENERATOR.secret_entry_position(
		reserved_coordinate
	)
	game._update_district_streaming()
	await process_frame
	var reserved_building_id := _generated_building_id(
		game,
		reserved_coordinate
	)
	var reserved_target := _reserved_loose_target(
		game,
		reserved_coordinate
	)
	var reserved_target_id := (
		reserved_target.world_instance_id
		if is_instance_valid(reserved_target)
		else ""
	)
	if is_instance_valid(reserved_target):
		game._swallow_target(reserved_target, 1.0)
	game._unlock_secret_path()
	await process_frame
	await process_frame
	_check(
		game._district_definition(
			reserved_coordinate
		).archetype_id == "secret_fantasy"
		and _generated_building_id(
			game,
			reserved_coordinate
		) == reserved_building_id
		and not reserved_target_id.is_empty()
		and _target_by_instance(game, reserved_target_id) == null,
		"Runtime reveal preserves reserved building IDs and existing district deltas."
	)
	game.queue_free()
	await process_frame


func _test_unlocked_path(seed_value: int) -> void:
	var game := _new_game(
		"secret_unlocked",
		seed_value,
		PackedStringArray([
			ProgressionCatalog.SECRET_FANTASY_DISTRICT,
		])
	)
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

	var hidden := (
		game._interior_rooms.get(FrogGame.RIVER_HIDDEN_MAINTENANCE_ID)
		as PrototypeInteriorRoom
	)
	var portal := hidden.portal_by_id("secret_star_path")
	var preserved_city_return := Vector2(980, 550)
	game._city_return_position = preserved_city_return
	game._active_interior_id = FrogGame.RIVER_HIDDEN_MAINTENANCE_ID
	game._frog.global_position = hidden.portal_approach_position(portal)
	game._begin_interior_transition(
		FrogGame.SECRET_DISTRICT_DESTINATION,
		"secret_star_path"
	)

	var secret_coordinate := game._secret_district_coordinate
	var secret_definition := game._district_definition(secret_coordinate)
	_check(
		bool(portal.get("visible", false))
		and game._active_interior_id.is_empty()
		and game._current_district_coordinate == secret_coordinate
		and game._frog.global_position.is_equal_approx(
			GENERATOR.secret_entry_position(secret_coordinate)
		)
		and game._loaded_districts.size()
			== GENERATOR.MAX_LOADED_GENERATED_DISTRICTS
		and secret_definition.archetype_id == "secret_fantasy",
		"The revealed path enters a bounded 3x3 ring centered on Starfall Quarter."
	)
	_check(
		profile_unlocks.count("secret_finder") == 1
		and device_unlocks.count("device_secret_found") == 1,
		"First entry records separate profile and device achievements once."
	)
	var structure := game.performance_structure_snapshot()
	var obstacle_counts := _loaded_obstacle_counts(game)
	var theoretical_nodes := (
		int(structure["game_nodes"])
		- int(obstacle_counts["bodies"])
		- int(obstacle_counts["shapes"])
		+ PerformanceBudgets.MAX_SECRET_RING_ENVIRONMENT_BODIES
		+ PerformanceBudgets.MAX_SECRET_RING_OBSTACLE_SHAPES
	)
	var theoretical_collision_objects := (
		int(structure["collision_objects"])
		- int(obstacle_counts["bodies"])
		+ PerformanceBudgets.MAX_SECRET_RING_ENVIRONMENT_BODIES
	)
	var theoretical_collision_shapes := (
		int(structure["collision_shapes"])
		- int(obstacle_counts["shapes"])
		+ PerformanceBudgets.MAX_SECRET_RING_OBSTACLE_SHAPES
	)
	_check(
		theoretical_nodes
			<= PerformanceBudgets.MAX_SECRET_DISTRICT_NODES
		and theoretical_collision_objects
			<= PerformanceBudgets.MAX_SECRET_DISTRICT_COLLISION_OBJECTS
		and theoretical_collision_shapes
			<= PerformanceBudgets.MAX_SECRET_DISTRICT_COLLISION_SHAPES,
		"Secret structural ceilings cover theoretical worst-case obstacle composition."
	)
	_check(
		PerformanceBudgets.structural_violations(
			"secret_district",
			structure
		).is_empty(),
		"Secret streaming stays inside its explicit structural budget."
	)

	var secret_target := _secret_loose_target(game, secret_coordinate)
	var target_instance_id := (
		secret_target.world_instance_id
		if is_instance_valid(secret_target)
		else ""
	)
	var route := (
		game._request_frog_navigation(
			secret_target.global_position,
			false,
			false
		)
		if is_instance_valid(secret_target)
		else {}
	)
	_check(
		is_instance_valid(secret_target)
		and bool(route.get("reachable", false)),
		"Secret targets remain eligible and reachable through deterministic navigation."
	)
	if is_instance_valid(secret_target):
		game._swallow_target(secret_target, 1.0)

	game._frog.global_position = GENERATOR.bounds_for_coordinate(
		secret_coordinate + Vector2i(4, 0)
	).get_center()
	game._update_district_streaming()
	await process_frame
	game._frog.global_position = GENERATOR.secret_entry_position(
		secret_coordinate
	)
	game._update_district_streaming()
	await process_frame
	_check(
		not target_instance_id.is_empty()
		and _target_by_instance(game, target_instance_id) == null,
		"Secret target removal survives unload and revisit within the session."
	)

	var return_portal := game._city_portal_by_id(
		FrogGame.SECRET_DISTRICT_RETURN_PORTAL_ID
	)
	game._frog.global_position = (
		return_portal["approach_position"] as Vector2
	)
	game._begin_interior_transition(
		FrogGame.RIVER_HIDDEN_MAINTENANCE_ID,
		FrogGame.SECRET_DISTRICT_RETURN_PORTAL_ID
	)
	_check(
		game._active_interior_id
			== FrogGame.RIVER_HIDDEN_MAINTENANCE_ID
		and game._city_return_position == preserved_city_return,
		"The star-path return reaches Hidden Maintenance without replacing the core-city return."
	)

	game._frog.global_position = hidden.portal_approach_position(portal)
	game._begin_interior_transition(
		FrogGame.SECRET_DISTRICT_DESTINATION,
		"secret_star_path"
	)
	_check(
		game._current_district_coordinate == secret_coordinate
		and profile_unlocks.count("secret_finder") == 1
		and device_unlocks.count("device_secret_found") == 1,
		"Re-entering the secret district cannot farm profile or device progress."
	)

	var fresh_game := _new_game(
		"secret_unlocked",
		seed_value + 1,
		PackedStringArray([
			ProgressionCatalog.SECRET_FANTASY_DISTRICT,
		])
	)
	root.add_child(fresh_game)
	await process_frame
	_check(
		fresh_game._secret_district_coordinate != secret_coordinate
		and fresh_game._district_states.is_empty(),
		"A new game keeps the profile unlock but chooses fresh city placement and empty deltas."
	)
	fresh_game.queue_free()
	game.queue_free()
	await process_frame


func _test_unlock_during_swallow(seed_value: int) -> void:
	var game := _new_game(
		"secret_swallow_unlock",
		seed_value,
		PackedStringArray(),
		PackedStringArray([
			"golden_crumb",
			"sewer_stamp",
			"moonlit_receipt",
			"kite_thread",
			"repair_blueprint",
		])
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	game._growth_tier = 2
	game._frog.set_growth_tier(2)
	var coordinate := game._secret_district_coordinate
	game._frog.global_position = GENERATOR.secret_entry_position(coordinate)
	game._update_district_streaming()
	await process_frame
	var building_id := _generated_building_id(game, coordinate)
	for part_id in [
		PrototypeBuilding.PART_SIGN,
		PrototypeBuilding.PART_DOOR,
		PrototypeBuilding.PART_COUNTER,
	]:
		var part_target := _building_target(
			game,
			building_id,
			part_id,
			false
		)
		if is_instance_valid(part_target):
			game._swallow_target(part_target, 1.0)
	var whole_target := _building_target(
		game,
		building_id,
		"",
		true
	)
	var original_building := (
		game._building_by_id.get(building_id) as PrototypeBuilding
	)
	if is_instance_valid(whole_target):
		game._swallow_target(whole_target, 1.0)
	_check(
		is_instance_valid(original_building)
		and original_building.consumed
		and game._secret_unlocks.has(
			ProgressionCatalog.SECRET_FANTASY_DISTRICT
		),
		"A sixth clue during a whole-building swallow completes that transaction before replacement."
	)
	await process_frame
	await process_frame
	var revealed_building := (
		game._building_by_id.get(building_id) as PrototypeBuilding
	)
	_check(
		is_instance_valid(revealed_building)
		and revealed_building.consumed
		and game._district_definition(coordinate).archetype_id
			== "secret_fantasy",
		"Deferred reveal carries the completed building state into Starfall Quarter."
	)
	var building_belly_index := -1
	for index in game._belly.size():
		if (
			game._belly[index].kind == "building"
			and game._belly[index].building_id == building_id
		):
			building_belly_index = index
			break
	if building_belly_index >= 0:
		game._frog.global_position = GENERATOR.secret_entry_position(
			coordinate
		)
		game._spit_item(building_belly_index)
	_check(
		building_belly_index >= 0
		and not revealed_building.consumed
		and revealed_building.weakness_count()
			== PrototypeBuilding.REQUIRED_WEAKNESS,
		"Stable reserved IDs let Belly building references restore after reveal."
	)
	game.queue_free()
	await process_frame


func _new_game(
	profile_id: String,
	seed_value: int,
	secret_unlocks: PackedStringArray,
	story_clues: PackedStringArray = PackedStringArray()
) -> FrogGame:
	var game := GAME_SCENE.instantiate() as FrogGame
	game.configure(
		profile_id,
		"Secret Tester",
		false,
		PackedStringArray(),
		{
			"reduce_motion": true,
			"larger_text_controls": false,
		},
		{},
		seed_value,
		PackedStringArray(),
		PackedStringArray(),
		PackedStringArray(),
		story_clues,
		secret_unlocks
	)
	return game


func _secret_loose_target(
	game: FrogGame,
	coordinate: Vector2i
) -> EdibleTarget:
	for target in game._targets:
		if (
			is_instance_valid(target)
			and target.district_coordinate == coordinate
			and target.world_instance_id.begins_with("secret_district_")
			and target.target_id == "generated_park_picnic"
		):
			return target
	return null


func _reserved_loose_target(
	game: FrogGame,
	coordinate: Vector2i
) -> EdibleTarget:
	for target in game._targets:
		if (
			is_instance_valid(target)
			and target.district_coordinate == coordinate
			and target.world_instance_id.begins_with("secret_district_")
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


func _generated_building_id(
	game: FrogGame,
	coordinate: Vector2i
) -> String:
	for building in game._buildings:
		if (
			is_instance_valid(building)
			and building.has_meta("district_coordinate")
			and building.get_meta("district_coordinate") == coordinate
		):
			return building.building_id
	return ""


func _building_target(
	game: FrogGame,
	building_id: String,
	part_id: String,
	whole: bool
) -> EdibleTarget:
	for target in game._targets:
		if (
			is_instance_valid(target)
			and target.building_id == building_id
			and (
				target.kind == "building"
				if whole
				else target.building_part_id == part_id
			)
		):
			return target
	return null


func _loaded_obstacle_counts(game: FrogGame) -> Dictionary:
	var bodies := 0
	var shapes := 0
	for coordinate_value in game._loaded_districts:
		var coordinate := coordinate_value as Vector2i
		var definition := game._district_definition(coordinate)
		if not definition.obstacles.is_empty():
			bodies += 1
			shapes += definition.obstacles.size()
	return {
		"bodies": bodies,
		"shapes": shapes,
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Secret district smoke tests passed.")
		quit(0)
	else:
		push_error(
			"Secret district smoke tests failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
