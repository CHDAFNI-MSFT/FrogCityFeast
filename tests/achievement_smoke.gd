extends SceneTree

const ACHIEVEMENT_MODEL_SCRIPT := preload("res://src/achievement_model.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_scoped_model()
	await _test_game_progression()
	await _finish()


func _test_scoped_model() -> void:
	var model := ACHIEVEMENT_MODEL_SCRIPT.new()
	model.configure(
		PackedStringArray(["growth_spurt", "unknown"]),
		PackedStringArray(["device_score_2500", "unknown"])
	)
	_check(
		model.is_unlocked(
			ProgressionCatalog.SCOPE_PROFILE,
			"growth_spurt"
		)
		and model.is_unlocked(
			ProgressionCatalog.SCOPE_DEVICE,
			"device_score_2500"
		)
		and model.unlocked_count(ProgressionCatalog.SCOPE_PROFILE) == 1
		and model.unlocked_count(ProgressionCatalog.SCOPE_DEVICE) == 1,
		"Configured profile and device achievements remain in separate scopes."
	)
	_check(
		model.unlock_session("sharp_aim")
		and not model.unlock_session("sharp_aim")
		and not model.unlock_session("unknown")
		and model.unlocked_ids(ProgressionCatalog.SCOPE_SESSION)
			== PackedStringArray(["sharp_aim"]),
		"Session goals accept known IDs once and reject farming or unknown IDs."
	)
	model.reset_session()
	_check(
		model.unlocked_count(ProgressionCatalog.SCOPE_SESSION) == 0
		and model.unlocked_count(ProgressionCatalog.SCOPE_PROFILE) == 1
		and model.unlocked_count(ProgressionCatalog.SCOPE_DEVICE) == 1,
		"Resetting a session cannot erase profile or device progress."
	)


func _test_game_progression() -> void:
	var scene := load("res://scenes/game.tscn") as PackedScene
	var game := scene.instantiate() as FrogGame
	var generated_ids := ProgressionCatalog.generated_archetype_discovery_ids()
	var starting_discoveries := PackedStringArray()
	for index in 5:
		starting_discoveries.append(generated_ids[index])
	game.configure(
		"achievement_test",
		"Achievement Tester",
		false,
		starting_discoveries,
		{},
		{},
		0x41434856,
		PackedStringArray([
			TemporaryPowerState.FLIGHT,
			TemporaryPowerState.SPEED_BURST,
			TemporaryPowerState.LONG_TONGUE,
			TemporaryPowerState.CAMOUFLAGE,
		]),
		PackedStringArray(["growth_spurt"]),
		PackedStringArray(),
		PackedStringArray([
			"golden_crumb",
			"sewer_stamp",
			"kite_thread",
			"oddities_label",
			"crane_map",
		]),
		PackedStringArray()
	)

	var profile_unlocks: Array[String] = []
	var device_unlocks: Array[String] = []
	var clue_unlocks: Array[String] = []
	var secret_unlocks: Array[String] = []
	var power_unlocks: Array[String] = []
	game.profile_achievement_unlocked.connect(
		func(achievement_id: String, _derived_clue_id: String) -> void:
			profile_unlocks.append(achievement_id)
	)
	game.device_achievement_unlocked.connect(
		func(achievement_id: String) -> void:
			device_unlocks.append(achievement_id)
	)
	game.story_clue_found.connect(
		func(clue_id: String) -> void:
			clue_unlocks.append(clue_id)
	)
	game.secret_unlocked.connect(
		func(secret_id: String) -> void:
			secret_unlocks.append(secret_id)
	)
	game.power_discovered.connect(
		func(power_id: String) -> void:
			power_unlocks.append(power_id)
	)
	root.add_child(game)
	await process_frame
	await physics_frame

	game._on_challenge_completed("sharp_aim")
	game._on_challenge_completed("sharp_aim")
	_check(
		game._achievement_model.unlocked_ids(
			ProgressionCatalog.SCOPE_SESSION
		) == PackedStringArray(["sharp_aim"]),
		"Repeated challenge completion cannot farm session-goal progress."
	)

	game._record_story_clue("repair_blueprint")
	game._record_story_clue("repair_blueprint")
	_check(
		clue_unlocks.count("repair_blueprint") == 1
		and profile_unlocks.count("clue_collector") == 1
		and secret_unlocks == [
			ProgressionCatalog.SECRET_FANTASY_DISTRICT,
		],
		"The sixth unique clue unlocks the profile achievement and secret path once."
	)

	game._activate_power(TemporaryPowerState.BUBBLE_SHIELD)
	game._activate_power(TemporaryPowerState.BUBBLE_SHIELD)
	_check(
		power_unlocks == [
			TemporaryPowerState.BUBBLE_SHIELD,
		]
		and profile_unlocks.count("power_sampler") == 1,
		"Power Sampler depends on unique discoveries and cannot be farmed by recollection."
	)

	game._record_discovery(generated_ids[5], "Park Find")
	_check(
		clue_unlocks.count("district_glyph") == 1,
		"Discovering all six normal generated archetypes records the district glyph once."
	)

	game._unlock_profile_achievement("building_banquet")
	game._unlock_profile_achievement("building_banquet")
	_check(
		profile_unlocks.count("building_banquet") == 1
		and clue_unlocks.count("giant_shadow") == 1,
		"Repeatable whole-building actions unlock one achievement and one clue."
	)

	game._day_clock = 0.36
	game._spawn_pursuer()
	_check(
		is_instance_valid(game._pursuer),
		"The event-goal test creates a pursuer swallow target."
	)
	if is_instance_valid(game._pursuer):
		game._swallow_pursuer(game._pursuer, 1.0)
	_check(
		profile_unlocks.count("event_wind_squall") == 1,
		"Swallowing a pursuer counts as a successful event-goal swallow."
	)

	for clock_value in [0.84, 0.50]:
		game._day_clock = clock_value
		game._record_event_goals_for_swallow()
	game._day_clock = 0.65
	game._record_event_goals_for_swallow()
	_check(
		profile_unlocks.count("event_water_main") == 0,
		"The water-main goal stays locked when the scheduled repair is absent."
	)
	_check(
		game._spawn_city_detour(),
		"The event-goal test creates a visible water-main repair."
	)
	game._record_event_goals_for_swallow()
	game._day_clock = 0.36
	game._record_event_goals_for_swallow()
	game._day_clock = 0.84
	game._record_event_goals_for_swallow()
	_check(
		profile_unlocks.count("event_moonlight_bazaar") == 1
		and profile_unlocks.count("event_kite_festival") == 1
		and profile_unlocks.count("event_water_main") == 1
		and profile_unlocks.count("event_wind_squall") == 1
		and profile_unlocks.count("event_explorer") == 1
		and clue_unlocks.count("moonlit_receipt") == 1,
		"Event goals unlock once in deterministic windows and complete Event Explorer."
	)

	game._score = ProgressionCatalog.DEVICE_SCORE_MILESTONE_THRESHOLD
	game._evaluate_device_achievements()
	game._evaluate_device_achievements()
	_check(
		device_unlocks == ["device_score_2500"],
		"Device score progress unlocks once and remains device-scoped."
	)

	game._rebuild_guide()
	var first_row := game._guide_list.get_child(0) as Label
	_check(
		first_row.text.contains("SESSION GOALS")
		and first_row.text.contains("PROFILE ACHIEVEMENTS")
		and first_row.text.contains("DEVICE MILESTONES")
		and first_row.text.contains("STORY CLUES")
		and first_row.text.contains("Folded Blueprint")
		and first_row.text.contains("Secret path revealed")
		and game._guide_progress.text.contains("Story clues"),
		"The Guide journal visibly separates scopes and presents found story clues."
	)

	game.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Achievement smoke tests passed.")
		quit(0)
	else:
		push_error(
			"Achievement smoke tests failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
