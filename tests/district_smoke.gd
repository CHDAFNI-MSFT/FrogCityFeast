extends SceneTree

const GENERATOR := preload("res://src/district_generator.gd")
const DISTRICT_SCENE := preload("res://src/generated_district.gd")

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
	await _finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("District generation smoke tests passed.")
		quit(0)
	else:
		print(
			"District generation smoke tests failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
