extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_controller_sequence()
	_test_profile_persistence()
	await _test_game_integration()
	await _test_skip_and_early_end()
	await _finish()


func _test_controller_sequence() -> void:
	var controller := TutorialController.new()
	var completion := {"count": 0, "skipped": false}
	controller.completed.connect(func(skipped: bool) -> void:
		completion["count"] = int(completion["count"]) + 1
		completion["skipped"] = skipped
	)
	var marker := Vector2(120, 220)
	controller.start(marker)
	_check(controller.step == TutorialController.Step.MOVE, "Tutorial starts at the movement step.")
	controller.on_target_swallowed("street_donut")
	_check(controller.step == TutorialController.Step.MOVE, "Out-of-order target events are ignored.")
	controller.on_move_reached(marker + Vector2(80, 0))
	_check(controller.step == TutorialController.Step.MOVE, "Missing the move marker does not advance.")
	controller.on_move_reached(marker)
	_check(controller.step == TutorialController.Step.EAT_DONUT, "Reaching the marker advances to tongue aiming.")
	_check(not controller.allows_tongue_target("moonlight_market_sign"), "Wrong tutorial targets are rejected.")
	controller.on_target_swallowed("street_donut")
	_check(controller.step == TutorialController.Step.DIGEST_DONUT, "Eating the donut advances to digestion.")
	controller.on_item_digested("running_hotdog")
	_check(controller.step == TutorialController.Step.DIGEST_DONUT, "Wrong digestion events are ignored.")
	controller.on_item_digested("street_donut")
	_check(controller.step == TutorialController.Step.ROTATE_CAMERA, "Digesting the donut advances to camera practice.")
	controller.on_camera_rotated(0.1)
	_check(controller.step == TutorialController.Step.ROTATE_CAMERA, "Small camera movement does not finish practice.")
	controller.on_camera_rotated(0.16)
	_check(controller.step == TutorialController.Step.EAT_HOTDOG, "Meaningful camera rotation advances the tutorial.")
	controller.on_target_swallowed("running_hotdog")
	controller.on_item_digested("running_hotdog")
	_check(controller.step == TutorialController.Step.EAT_SIGN, "Hot-dog digestion advances to the market sign.")
	controller.on_target_swallowed("moonlight_market_sign")
	controller.on_item_digested("moonlight_market_sign")
	_check(controller.step == TutorialController.Step.WAIT_FOR_GROWTH, "Sign digestion waits for actual growth.")
	controller.on_growth_tier_applied(0)
	_check(controller.step == TutorialController.Step.WAIT_FOR_GROWTH, "Insufficient growth cannot unlock the door step.")
	controller.on_growth_tier_applied(1)
	_check(controller.step == TutorialController.Step.EAT_DOOR, "Applied growth unlocks the door lesson.")
	controller.on_target_swallowed("moonlight_market_door")
	_check(not controller.active, "Eating the market door completes the tutorial.")
	_check(int(completion["count"]) == 1 and not bool(completion["skipped"]), "Completion emits exactly once.")


func _test_profile_persistence() -> void:
	var save_path := "user://tutorial_smoke_scores.cfg"
	var absolute_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)
	var store := ProfileStore.new(save_path)
	var first_profile := store.ensure_profile("Tutorial Frog")
	var second_profile := store.ensure_profile("Other Frog")
	store.update_high_scores(first_profile, 245)
	store.mark_tutorial_complete(first_profile)
	store.mark_discovered(first_profile, "street_donut")
	var reloaded := ProfileStore.new(save_path)
	_check(reloaded.is_tutorial_complete(first_profile), "Tutorial completion survives reload.")
	_check(not reloaded.is_tutorial_complete(second_profile), "Tutorial completion is profile-specific.")
	_check(reloaded.get_profile_best(first_profile) == 245, "Adding tutorial state preserves existing scores.")
	_check(
		reloaded.get_discoveries(first_profile) == PackedStringArray(["street_donut"])
		and reloaded.get_discoveries(second_profile).is_empty(),
		"Tutorial and discovery progress remain profile-specific together."
	)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)


func _test_game_integration() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	var game := game_scene.instantiate() as FrogGame
	game.configure("tutorial_integration", "Tutorial Tester", true)
	root.add_child(game)
	await process_frame
	await physics_frame

	_check(game._tutorial != null and game._tutorial.active, "Tutorial mode starts only after configured game entry.")
	_check(game._tutorial_panel.visible, "Tutorial instructions are visible.")
	_check(game._guide_button.disabled, "Field Guide stays disabled during the guided tutorial.")
	_check(
		not game._challenge_panel.visible
		and not game._challenges.active,
		"Session challenges stay hidden and inactive during the tutorial."
	)
	_check(
		game._tutorial_panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"Tutorial instructions block touches from reaching hidden controls."
	)
	_check(
		game._tutorial_marker.motion_scale == 0.0
		and not game._tutorial_marker.is_processing(),
		"Reduced motion freezes the continuous tutorial marker pulse."
	)
	var tutorial_step_before_options := game._tutorial.step
	game._open_options()
	_check(
		game._options_overlay.visible
		and not game._tutorial_panel.visible
		and paused
		and game._tutorial.step == tutorial_step_before_options,
		"Accessibility options remain available during the tutorial without advancing it."
	)
	game._close_options()
	_check(
		not paused
		and game._tutorial.active
		and game._tutorial_panel.visible
		and game._tutorial.step == tutorial_step_before_options,
		"Closing Accessibility returns to the same tutorial step."
	)
	var hotdog := game._find_target_by_id("running_hotdog")
	_check(hotdog.velocity == Vector2.ZERO, "The moving tutorial target waits for its lesson.")

	var sign := game._find_target_by_id("moonlight_market_sign")
	var sign_screen := game.get_viewport().get_canvas_transform() * sign.global_position
	game._try_tongue_at_screen(sign_screen)
	_check(game._belly.is_empty(), "Wrong-target tongue input has no gameplay side effect.")
	_check(game._tongue_recovery == 0.0, "Wrong tutorial input does not cause tongue recovery.")

	var marker_edge := game._tutorial.marker_position + Vector2(60, 0)
	var marker_edge_screen := (
		game.get_viewport().get_canvas_transform() * marker_edge
	)
	_check(
		not game._tutorial_panel.get_global_rect().has_point(marker_edge_screen),
		"The visible movement-marker edge stays clear of the tutorial card."
	)
	game._handle_world_tap(
		marker_edge_screen
	)
	_check(
		game._frog._move_target == game._tutorial.marker_position,
		"An accepted marker-edge tap moves to the marker center."
	)
	for frame in 120:
		await physics_frame
		if game._tutorial.step != TutorialController.Step.MOVE:
			break
	_check(game._tutorial.step == TutorialController.Step.EAT_DONUT, "Reaching the world marker advances integration.")
	var tutorial_card_position := game._tutorial_panel.get_global_rect().get_center()
	var covered_world_position := game._screen_to_world(tutorial_card_position)
	_check(
		game._find_target_at(covered_world_position) == null
		and not game._position_inside_building(covered_world_position),
		"The touch-through test uses unobstructed world space behind the tutorial card."
	)
	var move_target_before_card_touch := game._frog._move_target
	_push_mouse_click(game.get_viewport(), tutorial_card_position)
	await process_frame
	_check(
		game._frog._move_target == move_target_before_card_touch,
		"Touching the tutorial card cannot issue an otherwise-valid world movement command."
	)

	var donut := game._find_target_by_id("street_donut")
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform() * donut.global_position
	)
	_check(game._tutorial.step == TutorialController.Step.DIGEST_DONUT, "Real tongue capture advances the donut step.")
	_check(
		game._discoveries.has("street_donut")
		and game._status_label.text.contains("Swallowed Street Donut"),
		"Tutorial swallows record discoveries without replacing lesson feedback."
	)
	game._open_belly()
	var tutorial_rect := game._tutorial_panel.get_global_rect()
	var belly_actions_clear := true
	for button in [
		game._digest_all_button,
		game._end_game_belly_button,
		game._close_belly_button,
	]:
		if tutorial_rect.intersection(button.get_global_rect()).has_area():
			belly_actions_clear = false
	_check(
		belly_actions_clear,
		"Tutorial instructions leave every visible belly action unobstructed."
	)
	game._digest_item(0)
	await process_frame
	_check(game._tutorial.step == TutorialController.Step.ROTATE_CAMERA, "Real digestion advances the tutorial.")
	_check(not game._belly_overlay.visible and not paused, "Tutorial digestion automatically returns to the city.")
	_check(game._growth_points == 16, "Donut digestion contributes normal live-session growth.")

	game._rotate_camera(50.0)
	_check(game._tutorial.step == TutorialController.Step.EAT_HOTDOG, "Real camera rotation advances the tutorial.")
	hotdog = game._find_target_by_id("running_hotdog")
	game._begin_struggle(hotdog, 0.8, Vector2.ZERO)
	game._fail_struggle()
	_check(game._tutorial.step == TutorialController.Step.EAT_HOTDOG, "Failed guided struggle remains on the same step.")
	_check(not is_instance_valid(game._pursuer), "Failed guided struggle does not summon pursuit.")
	_check(
		hotdog.move_bounds.has_point(hotdog.position),
		"Failed guided struggle rebuilds movement bounds around the retry position."
	)

	hotdog.velocity = Vector2.ZERO
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform() * hotdog.global_position
	)
	_check(game._struggle_target == hotdog, "The highlighted hot dog starts a real struggle.")
	var struggle_taps_before_card_touch := game._struggle_taps
	_push_screen_touch(
		game.get_viewport(),
		game._tutorial_panel.get_global_rect().get_center()
	)
	await process_frame
	_check(
		game._struggle_taps == struggle_taps_before_card_touch,
		"An iPad touch on tutorial text cannot count as a hidden struggle tap."
	)
	for tap in hotdog.taps_required:
		game._register_struggle_tap()
	_check(game._tutorial.step == TutorialController.Step.DIGEST_HOTDOG, "Winning the struggle advances to digestion.")
	_check(
		game._challenges.completed_count() == 0,
		"Tutorial struggle wins do not pre-complete session challenges."
	)
	var original_hotdog_state: Dictionary = (
		game._tutorial_original_target_states["running_hotdog"]
	)
	_check(
		game._belly[0].movement_velocity == original_hotdog_state["velocity"],
		"Captured tutorial targets keep their normal free-play velocity."
	)
	_check(
		game._belly[0].movement_bounds == original_hotdog_state["move_bounds"],
		"Captured tutorial targets keep their normal free-play movement bounds."
	)
	game._open_belly()
	game._digest_item(0)
	await process_frame
	_check(game._tutorial.step == TutorialController.Step.EAT_SIGN, "Hot-dog digestion advances to city eating.")
	_check(game._growth_points == 46, "Hot-dog digestion preserves the designed growth economy.")

	sign = game._find_target_by_id("moonlight_market_sign")
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform() * sign.global_position
	)
	_check(game._tutorial.step == TutorialController.Step.DIGEST_SIGN, "The real sign capture advances the tutorial.")
	game._open_belly()
	game._digest_item(0)
	await process_frame
	_check(game._growth_points == 78, "Sign digestion reaches the intended growth total.")
	_check(game._growth_tier == 1, "The first growth tier is actually applied before the door step.")
	_check(game._tutorial.step == TutorialController.Step.EAT_DOOR, "Growth advances to the market door.")

	var door := game._find_target_by_id("moonlight_market_door")
	var door_position := door.position
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform() * door.global_position
	)
	_check(game._struggle_target == door, "The door lesson starts a real struggle.")
	game._fail_struggle()
	_check(door.position == door_position, "Failed guided door struggle leaves the door anchored.")
	_check(not is_instance_valid(game._pursuer), "Failed door struggle does not summon Animal Control.")

	var completion := {"count": 0, "skipped": false}
	game.tutorial_finished.connect(func(skipped: bool) -> void:
		completion["count"] = int(completion["count"]) + 1
		completion["skipped"] = skipped
	)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform() * door.global_position
	)
	for tap in door.taps_required:
		game._register_struggle_tap()
	_check(not game._tutorial.active and not game._tutorial_panel.visible, "Door capture completes and hides the tutorial.")
	_check(not game._guide_button.disabled, "Completing the tutorial enables the Field Guide.")
	_check(
		game._challenge_panel.visible
		and game._challenges.active
		and game._challenges.completed_count() == 0,
		"Completing the tutorial starts fresh session challenges."
	)
	_check(int(completion["count"]) == 1 and not bool(completion["skipped"]), "Game completion emits once.")
	_check(game._building_by_id["moonlight_market"].weakness_count() == 2, "Tutorial leaves the market ready for its counter lesson in free play.")
	_check(
		game._building_by_id["oddities_shop"].weakness_count() == 0,
		"Tutorial completion leaves the Oddities Shop untouched."
	)
	_check(
		game._building_by_id["leap_cafe"].weakness_count() == 0
		and game._find_target_by_id(
			"leap_cafe_menu_board"
		).selectable
		and not game._find_target_by_id(
			"leap_cafe_espresso_counter"
		).selectable,
		"Tutorial completion leaves the ordered Leap Cafe sequence untouched."
	)

	game.queue_free()
	await process_frame


func _test_skip_and_early_end() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	var skip_game := game_scene.instantiate() as FrogGame
	skip_game.configure("tutorial_skip", "Skip Tester", true)
	root.add_child(skip_game)
	await process_frame
	var skip_state := {"count": 0, "skipped": false}
	skip_game.tutorial_finished.connect(func(skipped: bool) -> void:
		skip_state["count"] = int(skip_state["count"]) + 1
		skip_state["skipped"] = skipped
	)
	skip_game._tutorial.on_move_reached(skip_game._tutorial.marker_position)
	var skip_donut := skip_game._find_target_by_id("street_donut")
	skip_game._swallow_target(skip_donut, 1.0)
	skip_game._open_belly()
	_push_mouse_click(
		skip_game.get_viewport(),
		skip_game._skip_tutorial_button.get_global_rect().get_center()
	)
	await process_frame
	_check(not skip_game._tutorial.active, "Skip releases tutorial restrictions.")
	_check(not skip_game._guide_button.disabled, "Skipping enables the Field Guide.")
	_check(
		skip_game._challenge_panel.visible
		and skip_game._challenges.active
		and skip_game._challenges.completed_count() == 0,
		"Skipping starts fresh session challenges without tutorial credit."
	)
	_check(int(skip_state["count"]) == 1 and bool(skip_state["skipped"]), "Skip emits a persisted completion event once.")
	_check(not skip_game._belly_overlay.visible and not paused, "Skip remains usable and closes the belly.")
	skip_game.queue_free()
	await process_frame

	var struggle_skip_game := game_scene.instantiate() as FrogGame
	struggle_skip_game.configure("tutorial_struggle_skip", "Struggle Skip Tester", true)
	root.add_child(struggle_skip_game)
	await process_frame
	struggle_skip_game._tutorial.on_move_reached(
		struggle_skip_game._tutorial.marker_position
	)
	struggle_skip_game._tutorial.on_target_swallowed("street_donut")
	struggle_skip_game._tutorial.on_item_digested("street_donut")
	struggle_skip_game._tutorial.on_camera_rotated(0.3)
	var guided_hotdog := struggle_skip_game._find_target_by_id("running_hotdog")
	struggle_skip_game._begin_struggle(guided_hotdog, 0.8, Vector2.ZERO)
	struggle_skip_game._skip_tutorial()
	_check(not is_instance_valid(struggle_skip_game._struggle_target), "Skip clears a hot-dog struggle.")
	_check(struggle_skip_game._frog.movement_enabled, "Skip restores movement after a struggle.")
	_check(not is_instance_valid(struggle_skip_game._pursuer), "Skip cannot turn a guided failure into pursuit.")
	_check(not struggle_skip_game._struggle_panel.visible, "Skip hides the struggle panel.")
	struggle_skip_game.queue_free()
	await process_frame

	var door_skip_game := game_scene.instantiate() as FrogGame
	door_skip_game.configure("tutorial_door_skip", "Door Skip Tester", true)
	root.add_child(door_skip_game)
	await process_frame
	door_skip_game._tutorial.on_move_reached(door_skip_game._tutorial.marker_position)
	door_skip_game._tutorial.on_target_swallowed("street_donut")
	door_skip_game._tutorial.on_item_digested("street_donut")
	door_skip_game._tutorial.on_camera_rotated(0.3)
	door_skip_game._tutorial.on_target_swallowed("running_hotdog")
	door_skip_game._tutorial.on_item_digested("running_hotdog")
	door_skip_game._tutorial.on_target_swallowed("moonlight_market_sign")
	door_skip_game._tutorial.on_item_digested("moonlight_market_sign")
	door_skip_game._tutorial.on_growth_tier_applied(1)
	var guided_door := door_skip_game._find_target_by_id("moonlight_market_door")
	door_skip_game._begin_struggle(guided_door, 0.8, Vector2.ZERO)
	door_skip_game._skip_tutorial()
	_check(not is_instance_valid(door_skip_game._struggle_target), "Skip clears a guided door struggle.")
	_check(guided_door.velocity == Vector2.ZERO, "Skip leaves the guided door anchored.")
	_check(not is_instance_valid(door_skip_game._pursuer), "Skipping the door cannot summon pursuit.")
	door_skip_game.queue_free()
	await process_frame

	var end_game := game_scene.instantiate() as FrogGame
	end_game.configure("tutorial_end", "End Tester", true)
	root.add_child(end_game)
	await process_frame
	var early_completion := {"count": 0}
	end_game.tutorial_finished.connect(func(_skipped: bool) -> void:
		early_completion["count"] = int(early_completion["count"]) + 1
	)
	end_game._end_game()
	_check(int(early_completion["count"]) == 0, "Ending early does not mark the tutorial complete.")
	end_game.queue_free()
	await process_frame


func _push_mouse_click(viewport: Viewport, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.global_position = position
	press.pressed = true
	viewport.push_input(press, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.global_position = position
	release.pressed = false
	viewport.push_input(release, true)


func _push_screen_touch(viewport: Viewport, position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = position
	press.pressed = true
	viewport.push_input(press, true)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = position
	release.pressed = false
	viewport.push_input(release, true)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	paused = false
	AudioDirector.reset_for_tests()
	await create_timer(0.2).timeout
	AudioDirector.shutdown_for_tests()
	for _frame in 2:
		await process_frame
	if _failures.is_empty():
		print("Tutorial smoke tests passed.")
		quit(0)
	else:
		print("Tutorial smoke tests failed: %s" % ", ".join(_failures))
		quit(1)
