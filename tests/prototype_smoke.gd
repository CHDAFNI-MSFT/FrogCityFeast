extends SceneTree

class BackupFailingProfileStore:
	extends ProfileStore

	func _init(save_path: String) -> void:
		super(save_path)

	func _backup_existing_save(_reason: String) -> bool:
		return false


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	_check(game_scene != null, "Game scene loads.")
	if game_scene == null:
		await _finish()
		return

	var game := game_scene.instantiate() as FrogGame
	game.configure("smoke_test", "Smoke Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	_check(
		game._targets.size() == 26,
		"Prototype targets, interiors, and all four destruction sequences are created."
	)
	_check(game._score == 0, "A new game starts at zero points.")
	_check(game._belly.is_empty(), "A new game starts with an empty belly.")

	var first_target := _find_target(game, "street_donut")
	var first_target_screen := (
		game.get_viewport().get_canvas_transform() * first_target.global_position
	)
	var target_touch := InputEventScreenTouch.new()
	target_touch.index = 0
	target_touch.position = first_target_screen
	target_touch.double_tap = true
	target_touch.pressed = true
	game._handle_screen_touch(target_touch)
	target_touch.pressed = false
	game._handle_screen_touch(target_touch)
	_check(game._belly.size() == 1, "Swallowing creates one belly record.")
	_check(game._score == 0, "Swallowing does not award points.")

	game._digest_item(0)
	_check(game._belly.is_empty(), "Digesting removes the belly record.")
	_check(game._score > 0, "Digesting awards points.")

	var second_target := _find_target(game, "market_apple")
	game._swallow_target(second_target, 0.75)
	var world_target_count := game._targets.size()
	game._spit_item(0)
	_check(game._belly.is_empty(), "Spitting removes the belly record.")
	_check(
		game._targets.size() == world_target_count + 1,
		"Spitting restores exactly one world target."
	)

	game._frog._has_move_target = false
	var rotation_before := game._camera.rotation
	var first_camera_touch := InputEventScreenTouch.new()
	first_camera_touch.index = 3
	first_camera_touch.position = Vector2(300, 400)
	first_camera_touch.pressed = true
	game._handle_screen_touch(first_camera_touch)
	var second_camera_touch := InputEventScreenTouch.new()
	second_camera_touch.index = 7
	second_camera_touch.position = Vector2(500, 400)
	second_camera_touch.pressed = true
	game._handle_screen_touch(second_camera_touch)
	var camera_drag := InputEventScreenDrag.new()
	camera_drag.index = 7
	camera_drag.position = Vector2(560, 400)
	camera_drag.screen_relative = Vector2(60, 0)
	game._handle_screen_drag(camera_drag)
	second_camera_touch.pressed = false
	game._handle_screen_touch(second_camera_touch)
	first_camera_touch.pressed = false
	game._handle_screen_touch(first_camera_touch)
	_check(game._camera.rotation != rotation_before, "A second touch rotates the camera.")
	_check(not game._frog._has_move_target, "A camera gesture does not issue a movement command.")

	var progression_steps := 0
	while game._growth_tier < 2 and progression_steps < 12:
		var eligible_target: EdibleTarget
		for target in game._targets:
			if (
				target.selectable
				and target.can_be_swallowed(game._growth_tier)
			):
				eligible_target = target
				break
		if eligible_target == null:
			break
		game._swallow_target(eligible_target, 1.0)
		game._digest_item(0)
		progression_steps += 1
	_check(game._growth_tier == 2, "Digesting enough value reaches the maximum prototype growth tier.")
	_check(game._frog.growth_tier == 2, "Frog presentation and abilities receive the growth tier.")
	if game._flight_time_left <= 0.0:
		var cake := _find_target(game, "golden_cake")
		_check(cake != null, "The rare golden cake remains available for its flight test.")
		if cake != null:
			game._swallow_target(cake, 1.0)
			game._digest_item(0)
	_check(game._flight_time_left > 0.0, "Digesting the rare golden cake activates flight.")
	_check(game._frog.is_flying, "Flight changes the frog's movement state.")

	var vehicle: EdibleTarget
	for target in game._targets:
		if target.target_id == "delivery_van":
			vehicle = target
			break
	_check(vehicle != null, "The traffic target exists.")
	if vehicle != null:
		_check(vehicle.can_be_swallowed(game._growth_tier), "Traffic becomes edible at maximum growth.")

	game._spawn_pursuer()
	_check(is_instance_valid(game._pursuer), "An escaped target can summon a pursuer.")

	game._score = 5
	game._damage_cooldown = 0.0
	game._apply_damage(game._frog.global_position + Vector2.LEFT, 25, "Test")
	_check(game._score == 0, "Damage cannot reduce the score below zero.")

	paused = false
	game.queue_free()
	await process_frame

	var building_game := game_scene.instantiate() as FrogGame
	building_game.configure("building_test", "Building Tester", false)
	root.add_child(building_game)
	await process_frame
	await physics_frame

	var hotdog := _find_target(building_game, "running_hotdog")
	var hotdog_item := hotdog.make_belly_item(0.8, true, false)
	var restored_hotdog := EdibleTarget.new()
	restored_hotdog.configure_from_belly(hotdog_item)
	_check(restored_hotdog.taps_required == hotdog.taps_required, "Belly records preserve struggle difficulty.")
	_check(restored_hotdog.velocity == hotdog.velocity, "Belly records preserve moving-target velocity.")
	_check(restored_hotdog.unpredictable == hotdog.unpredictable, "Belly records preserve movement behavior.")
	_check(not restored_hotdog.dangerous_location, "Capture danger does not become permanent target danger.")
	restored_hotdog.free()

	var first_spawn := building_game._allocate_target_spawn_position(28.0)
	_check(first_spawn != Vector2.INF, "The target spawn allocator finds a valid slot.")
	var allocation_blocker := EdibleTarget.new()
	allocation_blocker.position = first_spawn
	allocation_blocker.pick_radius = 28.0
	building_game._world.add_child(allocation_blocker)
	building_game._targets.append(allocation_blocker)
	var second_spawn := building_game._allocate_target_spawn_position(28.0)
	_check(
		second_spawn == Vector2.INF or second_spawn.distance_to(first_spawn) >= 116.0,
		"Successive target allocations do not stack targets."
	)
	building_game._targets.erase(allocation_blocker)
	allocation_blocker.queue_free()

	var market := (
		building_game._building_by_id.get("moonlight_market") as PrototypeBuilding
	)
	_check(is_instance_valid(market), "Moonlight Market is registered as a destructible building.")
	_check(market.weakness_count() == 0, "The market starts with no weakness.")
	_check(market._door_body.collision_layer == 1, "The market door initially blocks entry.")
	var locked_building_target := _find_target(
		building_game,
		"moonlight_market_building"
	)
	_check(not locked_building_target.selectable, "The whole market target is inactive before weakening.")
	_check(
		not locked_building_target.hit_test(market.global_position),
		"An inactive whole-building target does not intercept movement."
	)
	_check(
		not building_game._circle_position_clear(
			Vector2(building_game.WORLD_RECT.end.x, 0),
			44.0,
			true
		),
		"Full-circle clearance rejects positions extending beyond the world edge."
	)

	var cake_bounds := Rect2(430, -1250, 620, 430)
	var alternate_cake_spawn := building_game._allocate_target_spawn_position(
		36.0,
		cake_bounds
	)
	_check(
		alternate_cake_spawn != Vector2.INF and cake_bounds.has_point(alternate_cake_spawn),
		"Rare targets can allocate more than one valid position inside their region."
	)

	building_game._growth_tier = 0
	building_game._frog.set_growth_tier(0)
	building_game._pending_growth_tier = 1
	building_game._frog.global_position = Vector2(0, 420)
	building_game._retry_pending_growth()
	_check(
		building_game._growth_tier == 1 and building_game._pending_growth_tier == -1,
		"A blocked growth tier can apply later after the frog reaches open space."
	)

	var sign_target := _find_target(building_game, "moonlight_market_sign")
	building_game._swallow_target(sign_target, 1.0)
	_check(market.weakness_count() == 1, "Eating the sign weakens the market once.")
	_check(
		building_game._status_label.text.contains(
			"Moonlight Market is weakened to 1/3"
		),
		"Market weakness feedback names the correct building."
	)
	building_game._spit_item(0)
	var loose_sign := _find_target(building_game, "moonlight_market_sign")
	building_game._swallow_target(loose_sign, 1.0)
	_check(market.weakness_count() == 1, "Re-eating a removed sign cannot duplicate weakness.")
	building_game._digest_item(0)

	var door_target := _find_target(building_game, "moonlight_market_door")
	building_game._swallow_target(door_target, 1.0)
	_check(market.weakness_count() == 2, "Eating the door adds one weakness.")
	_check(market._door_body.collision_layer == 0, "Eating the door removes its collision.")
	building_game._digest_item(0)

	var counter_target := _find_target(building_game, "moonlight_market_counter")
	building_game._frog.global_position = Vector2(-300, 420)
	building_game._tongue_recovery = 0.0
	building_game._update_camera()
	await process_frame
	var counter_screen_position := (
		building_game.get_viewport().get_canvas_transform()
		* counter_target.global_position
	)
	building_game._try_tongue_at_screen(counter_screen_position)
	_check(
		building_game._struggle_target == counter_target,
		"The counter can be latched through the public tongue path."
	)
	for tap in counter_target.taps_required:
		building_game._register_struggle_tap()
	_check(market.weakness_count() == 3, "Eating the counter fully weakens the market.")
	_check(market.is_ready_to_swallow(), "The fully weakened market becomes swallowable.")
	_check(market._counter_body.collision_layer == 0, "Eating the counter removes its collision.")
	_check(locked_building_target.selectable, "The whole market target activates after full weakening.")
	building_game._digest_item(0)

	building_game._growth_tier = 2
	building_game._frog.set_growth_tier(2)
	building_game._frog.global_position = Vector2(-100, 420)
	_find_target(building_game, "market_apple").position = Vector2(980, 980)
	_find_target(building_game, "market_vendor").position = Vector2(1120, 980)
	var building_target := _find_target(building_game, "moonlight_market_building")
	building_game._tongue_recovery = 0.0
	building_game._update_camera()
	await process_frame
	var building_screen_position := (
		building_game.get_viewport().get_canvas_transform()
		* building_target.global_position
	)
	building_game._try_tongue_at_screen(building_screen_position)
	_check(
		building_game._struggle_target == building_target,
		"The weakened market can be latched through the public tongue path."
	)
	building_game._fail_struggle()
	_check(
		building_target.global_position == market.global_position
		and building_target.velocity == Vector2.ZERO
		and building_game._status_label.text.contains(
			"Moonlight Market shook the frog off"
		),
		"A failed whole-market struggle stays anchored with building feedback."
	)
	if is_instance_valid(building_game._pursuer):
		building_game._pursuer.queue_free()
		building_game._pursuer = null
		await process_frame
	building_game._tongue_recovery = 0.0
	building_game._try_tongue_at_screen(building_screen_position)
	for tap in building_target.taps_required:
		building_game._register_struggle_tap()
	_check(market.consumed, "Swallowing the market removes the building.")
	_check(
		building_game._building_footprint_clear(market),
		"A swallowed building leaves no structural collision."
	)
	_check(
		building_game._belly.size() == 1 and building_game._belly[0].kind == "building",
		"Swallowing the market creates exactly one building belly record."
	)

	var footprint_blocker := EdibleTarget.new()
	footprint_blocker.position = market.global_position
	footprint_blocker.pick_radius = 30.0
	building_game._world.add_child(footprint_blocker)
	building_game._targets.append(footprint_blocker)
	building_game._spit_item(0)
	_check(
		market.consumed and building_game._belly.size() == 1,
		"An occupied footprint prevents unsafe building restoration."
	)
	building_game._targets.erase(footprint_blocker)
	footprint_blocker.queue_free()
	building_game._spit_item(0)
	_check(not market.consumed, "Spitting the market restores the structure.")
	_check(market.weakness_count() == 3, "Restoring the market keeps removed parts absent.")
	_check(market._door_body.collision_layer == 0, "The restored market door remains removed.")
	_check(market._counter_body.collision_layer == 0, "The restored market counter remains removed.")

	building_target = _find_target(building_game, "moonlight_market_building")
	building_game._swallow_target(building_target, 1.0)
	var score_before_building := building_game._score
	building_game._digest_item(0)
	_check(building_game._score > score_before_building, "Digesting the market awards score once.")
	_check(market.consumed, "Digesting the market leaves it removed from the current city.")

	var safe_growth_position := building_game._find_safe_frog_position(
		building_game._frog.radius_for_tier(2)
	)
	_check(safe_growth_position != Vector2.INF, "A full-shape clearance search finds safe growth space.")
	if safe_growth_position != Vector2.INF:
		_check(
			building_game._circle_position_clear(
				safe_growth_position,
				building_game._frog.radius_for_tier(2),
				true
			),
			"Safe growth space clears the frog's full collision shape."
		)

	building_game.queue_free()
	await process_frame

	await _test_oddities_shop_sequence(game_scene)
	await _test_leap_cafe_sequence(game_scene)
	await _test_canal_apartments_sequence(game_scene)
	await _test_building_interiors(game_scene)
	await _test_city_activity(game_scene)
	await _test_accessibility(game_scene)
	await _test_game_feel(game_scene)
	await _test_feel_effects_component()
	await _test_discovery_collection(game_scene)
	await _test_session_challenges(game_scene)

	var save_path := "user://prototype_smoke_scores.cfg"
	var absolute_save_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_save_path)
	var store := ProfileStore.new(save_path)
	var first_profile := store.ensure_profile("Frog One")
	var second_profile := store.ensure_profile("Frog Two")
	store.update_high_scores(first_profile, 120)
	store.update_high_scores(second_profile, 80)
	store.set_accessibility_preferences(first_profile, true, false)
	store.set_accessibility_preferences(second_profile, false, true)
	_check(
		store.mark_discovered(first_profile, "street_donut"),
		"A new discovery is persisted once."
	)
	_check(
		not store.mark_discovered(first_profile, "street_donut"),
		"Persisting the same discovery is idempotent."
	)
	store._config.set_value(
		"discoveries",
		first_profile,
		PackedStringArray(["street_donut", "future_unknown_target"])
	)
	store._save()
	store.mark_tutorial_complete(first_profile)
	var reloaded_store := ProfileStore.new(save_path)
	_check(reloaded_store.get_profile_best(first_profile) == 120, "Profile high scores survive reload.")
	_check(reloaded_store.get_profile_best(second_profile) == 80, "Profiles keep independent high scores.")
	_check(reloaded_store.get_device_best() == 120, "Device high score tracks the highest profile.")
	_check(
		reloaded_store.get_discoveries(first_profile) == PackedStringArray(["street_donut"])
		and reloaded_store.get_discoveries(second_profile).is_empty(),
		"Discoveries survive reload and remain profile-specific."
	)
	_check(
		reloaded_store.get_accessibility_preferences(first_profile) == {
			"reduce_motion": true,
			"larger_text_controls": false,
		}
		and reloaded_store.get_accessibility_preferences(second_profile) == {
			"reduce_motion": false,
			"larger_text_controls": true,
		},
		"Accessibility preferences survive reload and remain profile-specific."
	)
	_check(
		reloaded_store.is_tutorial_complete(first_profile)
		and ProfileStore.SAVE_VERSION == 1,
		"Discovery persistence preserves tutorial state and save version 1."
	)
	var menu_scene := load("res://scenes/menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	menu.configure(reloaded_store, 0)
	var one_discovery_text := (
		"Field Guide: 1 / %d" % DiscoveryCatalog.count()
	)
	_check(
		menu._guide_label.text == one_discovery_text,
		"Main menu shows the selected profile's Field Guide progress."
	)
	_check(
		menu._reduce_motion_toggle.button_pressed
		and not menu._larger_ui_toggle.button_pressed,
		"Main menu loads accessibility choices for the selected profile."
	)
	menu._on_new_name_changed("frog one")
	_check(
		menu._guide_label.text == one_discovery_text
		and menu._start_button.text == "Start New Game",
		"Typing an existing profile name previews its real saved state."
	)
	menu._on_new_name_changed("frog two")
	_check(
		not menu._reduce_motion_toggle.button_pressed
		and menu._larger_ui_toggle.button_pressed,
		"Typing an existing name loads that profile's accessibility choices."
	)
	var profiles_before_draft := reloaded_store.list_profiles().size()
	menu._new_name.text = "Draft Frog"
	await process_frame
	menu._reduce_motion_toggle.button_pressed = true
	menu._larger_ui_toggle.button_pressed = true
	menu._on_accessibility_toggled(true)
	_check(
		reloaded_store.list_profiles().size() == profiles_before_draft,
		"Changing a new player's accessibility draft does not create a profile."
	)
	var started_profile := {"id": ""}
	menu.start_requested.connect(func(profile_id: String, _name: String) -> void:
		started_profile["id"] = profile_id
	)
	menu._on_start_pressed()
	_check(
		not str(started_profile["id"]).is_empty()
		and reloaded_store.get_accessibility_preferences(
			str(started_profile["id"])
		) == {
			"reduce_motion": true,
			"larger_text_controls": true,
		},
		"New-player accessibility choices are saved before gameplay starts."
	)
	var long_name := "Twenty Four Character Frogs Extra Text"
	var normalized_long_name := ProfileStore.normalize_profile_name(long_name)
	var long_profile := reloaded_store.ensure_profile(normalized_long_name)
	reloaded_store.update_high_scores(long_profile, 456)
	reloaded_store.mark_tutorial_complete(long_profile)
	menu.configure(reloaded_store, 0)
	menu._on_new_name_changed(long_name)
	_check(
		menu._best_label.text == "Player best: 456"
		and menu._start_button.text == "Start New Game",
		"Long typed names preview the same normalized profile that Start uses."
	)
	menu.queue_free()
	await process_frame
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_save_path)

	var legacy_path := "user://prototype_legacy_scores.cfg"
	var absolute_legacy_path := ProjectSettings.globalize_path(legacy_path)
	var legacy_config := ConfigFile.new()
	legacy_config.set_value("meta", "version", 1)
	legacy_config.set_value("profiles", "legacy_player", "Legacy Frog")
	legacy_config.set_value("scores", "legacy_player", 333)
	legacy_config.set_value("tutorial", "legacy_player", true)
	legacy_config.set_value("device", "best_score", 333)
	legacy_config.set_value(
		"accessibility",
		"legacy_player",
		{
			"reduce_motion": "true",
			"larger_text_controls": 1,
		}
	)
	legacy_config.save(legacy_path)
	var legacy_store := ProfileStore.new(legacy_path)
	_check(
		legacy_store.get_profile_best("legacy_player") == 333
		and legacy_store.is_tutorial_complete("legacy_player")
		and legacy_store.get_discoveries("legacy_player").is_empty()
		and legacy_store.get_accessibility_preferences("legacy_player") == {
			"reduce_motion": false,
			"larger_text_controls": false,
		},
		"Version 1 saves use deterministic defaults for missing or malformed optional data."
	)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(absolute_legacy_path)

	var unsupported_path := "user://prototype_unsupported_scores.cfg"
	var absolute_unsupported_path := ProjectSettings.globalize_path(
		unsupported_path
	)
	var unsupported_config := ConfigFile.new()
	unsupported_config.set_value("meta", "version", 99)
	unsupported_config.set_value("profiles", "old_player", "Old Frog")
	unsupported_config.set_value("scores", "old_player", 777)
	unsupported_config.save(unsupported_path)
	var unsupported_store := ProfileStore.new(unsupported_path)
	var backup_found := false
	for file_name in DirAccess.get_files_at("user://"):
		if str(file_name).begins_with(
			"prototype_unsupported_scores.cfg.unsupported-"
		):
			backup_found = true
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path("user://%s" % file_name)
			)
	_check(
		backup_found and not unsupported_store.list_profiles().is_empty(),
		"Unsupported saves are preserved before a fresh save is created."
	)
	if FileAccess.file_exists(unsupported_path):
		DirAccess.remove_absolute(absolute_unsupported_path)

	var unreadable_path := "user://prototype_unreadable_scores.cfg"
	var absolute_unreadable_path := ProjectSettings.globalize_path(unreadable_path)
	var unreadable_file := FileAccess.open(unreadable_path, FileAccess.WRITE)
	unreadable_file.store_string("[broken")
	unreadable_file.close()
	var unreadable_store := ProfileStore.new(unreadable_path)
	var unreadable_backup_found := false
	for file_name in DirAccess.get_files_at("user://"):
		if str(file_name).begins_with(
			"prototype_unreadable_scores.cfg.unreadable-"
		):
			unreadable_backup_found = true
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path("user://%s" % file_name)
			)
	_check(
		unreadable_backup_found and not unreadable_store.list_profiles().is_empty(),
		"Unreadable saves are preserved before a fresh save is created."
	)
	if FileAccess.file_exists(unreadable_path):
		DirAccess.remove_absolute(absolute_unreadable_path)

	var preservation_path := "user://prototype_preservation_failure.cfg"
	var absolute_preservation_path := ProjectSettings.globalize_path(
		preservation_path
	)
	var preservation_config := ConfigFile.new()
	preservation_config.set_value("meta", "version", 99)
	preservation_config.set_value("scores", "old_player", 999)
	preservation_config.save(preservation_path)
	var original_save_text := FileAccess.get_file_as_string(preservation_path)
	var failing_store := BackupFailingProfileStore.new(preservation_path)
	failing_store.update_high_scores(
		failing_store.list_profiles()[0]["id"],
		1000
	)
	_check(
		not failing_store._save_enabled
		and failing_store._save_disabled_error_reported
		and FileAccess.get_file_as_string(preservation_path) == original_save_text,
		"A failed backup disables later saves without clobbering the old file."
	)
	if FileAccess.file_exists(preservation_path):
		DirAccess.remove_absolute(absolute_preservation_path)

	await _finish()


func _test_accessibility(game_scene: PackedScene) -> void:
	_check(
		AccessibilityPresentation.sanitize_preferences({
			"reduce_motion": "true",
			"larger_text_controls": 1,
		}) == {
			"reduce_motion": false,
			"larger_text_controls": false,
		},
		"Accessibility settings accept only explicit boolean save values."
	)
	var safe_insets := AccessibilityPresentation.safe_area_insets(
		Rect2(124, 88, 1232, 920),
		Rect2(100, 70, 1280, 960),
		Vector2(1280, 960)
	)
	_check(
		safe_insets == Vector4(24, 18, 24, 22)
		and AccessibilityPresentation.safe_area_insets(
			Rect2(100, 70, 1280, 960),
			Rect2(100, 70, 1280, 960),
			Vector2(1280, 960)
		) == Vector4.ZERO,
		"Safe-area conversion is deterministic and leaves containing desktop areas unchanged."
	)

	var game := game_scene.instantiate() as FrogGame
	game.configure(
		"accessibility_test",
		"WWWWWWWWWWWWWWWWWWWWWWWW",
		false,
		PackedStringArray(),
		{
			"reduce_motion": false,
			"larger_text_controls": false,
		}
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	_check(
		game._motion_scale == 1.0
		and game._effects.motion_scale == 1.0
		and game._city_activity.motion_scale == 1.0
		and game._touch_feedback.motion_scale == 1.0,
		"An explicit player preference overrides the headless reduced-motion fallback."
	)
	_check(
		_all_interactive_controls_at_least(
			game.get_node("HUD/Root"),
			AccessibilityPresentation.NORMAL_TOUCH_HEIGHT
		),
		"Normal presentation keeps every interface action at least 56 pixels tall."
	)

	var move_world := game._frog.global_position + Vector2(-90, 0)
	var move_screen := (
		game.get_viewport().get_canvas_transform() * move_world
	)
	game._handle_world_tap(move_screen)
	game._try_tongue_at_screen(Vector2(96, 250))
	var rotation_before := game._camera.rotation
	game._rotate_camera(18.0, Vector2(640, 420))
	_check(
		game._frog._has_move_target
		and (
			game._touch_feedback.feedback_snapshot("move")["world_position"]
			as Vector2
		).distance_to(game._frog._move_target) < 0.01,
		"Accepted movement produces draw-only feedback at the final destination."
	)
	_check(
		game._camera.rotation != rotation_before
		and game._touch_feedback.active_feedback_count() == 3
		and not _contains_collision_object(game._touch_feedback),
		"Move, tongue, and camera cues are capped draw-only observers of input."
	)

	var baseline_score_font := game._score_label.get_theme_font_size("font_size")
	game._frog.celebrate_growth(1.0)
	game._frog._process(0.2)
	var pulsing_target := _find_target(game, "running_hotdog")
	pulsing_target.pulse_feedback(1.0)
	game._show_tongue(
		game._frog.global_position + Vector2.RIGHT * 160.0
	)
	game._trigger_camera_shake(8.0, 0.24)
	game._update_camera_feedback(0.016)
	var accessibility_events: Array[Dictionary] = []
	game.accessibility_changed.connect(
		func(reduce_motion: bool, larger_text_controls: bool) -> void:
			accessibility_events.append({
				"reduce_motion": reduce_motion,
				"larger_text_controls": larger_text_controls,
			})
	)
	game._refreshing_accessibility_controls = true
	game._reduce_motion_toggle.button_pressed = true
	game._larger_ui_toggle.button_pressed = true
	game._refreshing_accessibility_controls = false
	game._on_accessibility_toggled(true)
	var large_score_font := game._score_label.get_theme_font_size("font_size")
	game._apply_accessibility_presentation()
	_check(
		game._motion_scale == 0.0
		and game._camera_shake_time == 0.0
		and game._frog._growth_celebration_time == 0.0
		and is_equal_approx(game._frog._visual_scale, 1.0)
		and pulsing_target._presentation_motion_scale == 0.0
		and game._tongue_phase == FrogGame.TonguePhase.HOLDING
		and is_equal_approx(game._tongue_extension, 1.0)
		and game._city_activity.motion_scale == 0.0,
		"Turning on Reduce motion immediately settles active presentation movement."
	)
	var feedback_is_static := true
	for kind in ["move", "tongue", "camera"]:
		if (
			float(
				game._touch_feedback.feedback_snapshot(kind).get(
					"motion_scale",
					-1.0
				)
			)
			!= 0.0
		):
			feedback_is_static = false
	_check(
		feedback_is_static
		and accessibility_events == [{
			"reduce_motion": true,
			"larger_text_controls": true,
		}],
		"Accessibility changes retain static touch information and emit one exact save event."
	)
	game._struggle_kick = 1.0
	game._apply_tongue_visual()
	_check(
		is_equal_approx(game._tongue.width, 12.0)
		and game._tongue.default_color != FrogGame.TONGUE_COLOR,
		"Reduced motion removes struggle width pulses while preserving its color flash."
	)
	_check(
		_all_interactive_controls_at_least(
			game.get_node("HUD/Root"),
			AccessibilityPresentation.LARGE_TOUCH_HEIGHT
		)
		and large_score_font > baseline_score_font
		and game._score_label.get_theme_font_size("font_size")
		== large_score_font,
		"Larger text and controls is idempotent and enforces 64-pixel actions."
	)

	game._score = 99999
	game._growth_tier = 1
	game._growth_points = 350
	game._flight_time_left = 60.0
	game._update_hud()
	game._update_power_label()
	game.apply_safe_area_insets(safe_insets)
	await process_frame
	var safe_rect := Rect2(24, 18, 1232, 920)
	var top_bar_controls: Array[Control] = [
		game._profile_label,
		game._score_label,
		game._growth_label,
		game._power_label,
		game._guide_button,
		game._belly_button,
		game._options_button,
		game._end_button,
	]
	_check(
		not _controls_overlap(top_bar_controls)
		and safe_rect.encloses(game._control_legend.get_global_rect())
		and game._profile_label.get_global_rect().position.x >= safe_rect.position.x
		and game._end_button.get_global_rect().end.x <= safe_rect.end.x,
		"Large worst-case top-bar and control legend fit the inset 1280x960 safe area."
	)

	game._begin_struggle(pulsing_target, 0.8, Vector2.ZERO)
	var struggle_time := game._struggle_time_left
	game._open_options()
	var options_panel := game.get_node(
		"HUD/Root/OptionsOverlay/Center/Panel"
	) as Control
	game._open_belly()
	await process_frame
	_check(
		game._options_overlay.visible
		and not game._belly_overlay.visible
		and paused
		and game._struggle_target == pulsing_target
		and is_equal_approx(game._struggle_time_left, struggle_time),
		"Accessibility options pause in-progress play without stacking or resetting it."
	)
	_check(
		safe_rect.encloses(options_panel.get_global_rect()),
		"Accessibility options remain inside the inset 4:3 safe area."
	)
	game._close_options()
	_check(
		not paused
		and game._struggle_target == pulsing_target,
		"Closing Accessibility resumes the exact in-progress gameplay state."
	)
	game._clear_struggle()
	game.queue_free()
	await process_frame

	var menu_save_path := "user://accessibility_menu_smoke.cfg"
	var absolute_menu_save_path := ProjectSettings.globalize_path(
		menu_save_path
	)
	if FileAccess.file_exists(menu_save_path):
		DirAccess.remove_absolute(absolute_menu_save_path)
	var menu_store := ProfileStore.new(menu_save_path)
	var menu_profile := menu_store.ensure_profile("Accessible Frog")
	menu_store.set_accessibility_preferences(menu_profile, true, true)
	var menu := (
		load("res://scenes/menu.tscn") as PackedScene
	).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	menu.configure(menu_store, 0)
	menu.apply_safe_area_insets(safe_insets)
	await process_frame
	var menu_panel := menu.get_node("Center/Panel") as Control
	_check(
		menu._reduce_motion_toggle.button_pressed
		and menu._larger_ui_toggle.button_pressed,
		"Menu loads both saved accessibility choices."
	)
	_check(
		_all_interactive_controls_at_least(
			menu,
			AccessibilityPresentation.LARGE_TOUCH_HEIGHT
		),
		"Menu large mode enforces 64-pixel interactive controls."
	)
	_check(
		safe_rect.encloses(menu_panel.get_global_rect()),
		"Menu large mode fits the inset 1280x960 safe area."
	)
	var profile_count_before_selection := menu_store.list_profiles().size()
	menu._new_name.text = "Uncreated Draft Frog"
	await process_frame
	var menu_profile_index := -1
	for index in menu._profile_select.item_count:
		if (
			str(menu._profile_select.get_item_metadata(index))
			== menu_profile
		):
			menu_profile_index = index
			break
	menu._profile_select.select(menu_profile_index)
	menu._on_profile_selected(menu_profile_index)
	menu._reduce_motion_toggle.button_pressed = false
	menu._on_accessibility_toggled(false)
	var selected_start := {"id": ""}
	menu.start_requested.connect(
		func(profile_id: String, _name: String) -> void:
			selected_start["id"] = profile_id
	)
	menu._on_start_pressed()
	_check(
		menu._new_name.text.is_empty()
		and str(selected_start["id"]) == menu_profile
		and menu_store.list_profiles().size() == profile_count_before_selection
		and menu_store.get_accessibility_preferences(menu_profile) == {
			"reduce_motion": false,
			"larger_text_controls": true,
		},
		"Choosing a dropdown profile clears a typed draft and keeps Start and settings on that profile."
	)
	menu.queue_free()
	await process_frame
	if FileAccess.file_exists(menu_save_path):
		DirAccess.remove_absolute(absolute_menu_save_path)


func _test_game_feel(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	_check(
		game._motion_scale == 1.0,
		"Motion preference can be configured before the game enters the scene tree."
	)
	game.configure(
		"feel_test",
		"WWWWWWWWWWWWWWWWWWWWWWWW",
		false
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	_check(
		game._motion_scale == 1.0
		and game._effects.motion_scale == 1.0
		and game._city_activity.motion_scale == 1.0,
		"Pre-entry motion preference overrides the headless default after scene entry."
	)

	var target := _find_target(game, "street_donut")
	var accuracy_point := (
		target.global_position
		+ Vector2.RIGHT * target.pick_radius * target._presentation_scale * 0.5
	)
	var hit_before := target.hit_test(accuracy_point)
	var accuracy_before := target.hit_accuracy(accuracy_point)
	target.pulse_feedback(1.0)
	_check(
		target.hit_test(accuracy_point) == hit_before
		and is_equal_approx(target.hit_accuracy(accuracy_point), accuracy_before),
		"Target feedback cannot change tongue hit testing or accuracy."
	)

	var score_before_swallow := game._score
	var growth_before_swallow := game._growth_points
	var belly_before_swallow := game._belly.size()
	var target_screen := (
		game.get_viewport().get_canvas_transform() * target.global_position
	)
	game._try_tongue_at_screen(target_screen)
	_check(
		game._belly.size() == belly_before_swallow + 1
		and game._tongue_phase == FrogGame.TonguePhase.EXTENDING,
		"Tongue animation begins after the swallow resolves synchronously."
	)
	_check(
		game._score == score_before_swallow
		and game._growth_points == growth_before_swallow,
		"Swallow effects do not award score or growth early."
	)
	_check(
		game._effects.active_effect_count() > 0,
		"Swallowing emits a draw-only world effect."
	)

	game._trigger_camera_shake(8.0, 0.24)
	game._update_camera_feedback(0.016)
	game._open_belly()
	_check(
		game._camera_shake_time == 0.0
		and game._camera.offset == Vector2.ZERO,
		"Opening the belly clears shake instead of replaying it later."
	)
	game._digest_item(0)
	await process_frame
	_check(game._reward_label.visible, "Digesting shows an immediate HUD reward.")
	_check(
		game._reward_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Digest feedback cannot consume gameplay touches."
	)
	var belly_title := (
		game.get_node(
			"HUD/Root/BellyOverlay/Center/Panel/Margin/Content/Title"
		) as Control
	)
	var status_panel := game.get_node("HUD/Root/StatusPanel") as Control
	_check(
		not game._reward_label.get_global_rect()
		.intersection(belly_title.get_global_rect()).has_area()
		and not game._reward_label.get_global_rect()
		.intersection(status_panel.get_global_rect()).has_area(),
		"Digest reward has a dedicated lane clear of status and belly titles."
	)
	_check(
		game._pending_hud_pulse
		and game._score_pulse_time == 0.0
		and game._growth_pulse_time == 0.0,
		"Covered top-bar feedback waits until the belly closes."
	)
	game._tongue_recovery = 0.4
	game._damage_cooldown = 0.8
	game._process(0.5)
	_check(
		is_equal_approx(game._tongue_recovery, 0.4)
		and is_equal_approx(game._damage_cooldown, 0.8),
		"Opening the belly pauses tongue recovery and damage protection."
	)
	game._close_belly()
	_check(
		not game._pending_hud_pulse
		and game._score_pulse_time > 0.0
		and game._growth_pulse_time > 0.0,
		"Closing the belly starts the visible score and growth flash."
	)
	game._update_hud_feedback(0.17)
	var base_score_color := (
		game._score_label.get_theme_color("font_color")
	)
	var flashed_score_color := (
		base_score_color * game._score_label.modulate
	)
	_check(
		game._score_label.scale == Vector2.ONE
		and game._growth_label.scale == Vector2.ONE
		and flashed_score_color.g - base_score_color.g > 0.12,
		"Top-bar reward feedback visibly brightens without scaling its layout."
	)
	game._tongue_recovery = 0.0
	game._damage_cooldown = 0.0
	game._score = 99999
	game._growth_tier = 1
	game._growth_points = 350
	game._flight_time_left = 60.0
	game._update_hud()
	game._update_power_label()
	await process_frame
	var top_bar_controls: Array[Control] = [
		game._profile_label,
		game._score_label,
		game._growth_label,
		game._power_label,
		game._guide_button,
		game._belly_button,
		game._options_button,
		game._end_button,
	]
	var top_bar_overlaps := false
	for first_index in top_bar_controls.size():
		for second_index in range(
			first_index + 1,
			top_bar_controls.size()
		):
			if (
				top_bar_controls[first_index]
				.get_global_rect()
				.intersection(
					top_bar_controls[second_index].get_global_rect()
				)
				.has_area()
			):
				top_bar_overlaps = true
	_check(
		not top_bar_overlaps
		and game._end_button.get_global_rect().end.x
		<= game.get_viewport().get_visible_rect().end.x,
		"Wide score, growth, power, and action labels fit the 4:3 top bar."
	)

	var physical_scale := game._frog.scale
	game._frog.celebrate_growth(1.0)
	game._frog._process(0.2)
	_check(
		game._frog.scale == physical_scale
		and is_equal_approx(
			game._frog.collision_radius(),
			PlayerFrog.TIER_RADII[game._frog.growth_tier]
		),
		"Growth celebration cannot change the frog's physical size."
	)
	_check(
		game._frog._visual_scale > 1.0,
		"Full-motion growth celebration visibly pulses the frog."
	)

	var aiming_target := _find_target(game, "moonlight_market_sign")
	game._update_camera()
	game._trigger_camera_shake(8.0, 0.24)
	var maximum_shake := 0.0
	var aiming_preserved := true
	for frame in 15:
		game._update_camera_feedback(1.0 / 60.0)
		maximum_shake = maxf(
			maximum_shake,
			game._camera.offset.length()
		)
		var shaken_screen_position := (
			game.get_viewport().get_canvas_transform()
			* aiming_target.global_position
		)
		var shaken_round_trip := game._screen_to_world(
			shaken_screen_position
		)
		if (
			shaken_round_trip.distance_to(aiming_target.global_position) >= 0.01
			or game._find_target_at(shaken_round_trip) != aiming_target
		):
			aiming_preserved = false
	_check(
		maximum_shake > 0.0 and maximum_shake <= 8.01,
		"Camera shake remains within its comfort cap across the full effect."
	)
	_check(
		aiming_preserved,
		"Camera shake preserves exact screen-to-world tongue aiming."
	)

	var hotdog := _find_target(game, "running_hotdog")
	game._begin_struggle(hotdog, 0.8, Vector2.ZERO)
	game._register_struggle_tap()
	_check(
		game._struggle_kick == 1.0 and hotdog._feedback_time > 0.0,
		"Each struggle tap produces allocation-free tongue and target feedback."
	)
	game._trigger_camera_shake(8.0, 0.24)
	game._update_camera_feedback(0.016)
	_check(
		game._camera.offset == Vector2.ZERO,
		"Camera shake is suppressed during rapid-tap struggles."
	)
	game._clear_struggle()

	game.set_motion_scale(0.0)
	game._frog.celebrate_growth(0.0)
	game._frog._process(0.2)
	_check(
		is_equal_approx(game._frog._visual_scale, 1.0),
		"Reduced motion removes frog scale movement."
	)
	game._show_tongue(game._frog.global_position + Vector2.RIGHT * 120.0)
	_check(
		game._tongue_phase == FrogGame.TonguePhase.HOLDING
		and is_equal_approx(game._tongue_extension, 1.0),
		"Reduced motion keeps tongue information but removes extension movement."
	)
	game._hide_tongue()
	_check(
		game._city_activity.motion_scale == 0.0
		and not game._city_activity.is_processing(),
		"Reduced motion freezes decorative city movement."
	)

	_check(
		not _contains_collision_object(game._effects),
		"World feedback contains no physics objects."
	)
	game.queue_free()
	await process_frame


func _test_city_activity(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("city_activity_test", "City Activity Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	var activity := game._city_activity
	_check(
		is_instance_valid(activity)
		and activity.get_child_count() == 0
		and not _contains_collision_object(activity),
		"City activity and rain share one draw-only layer with no physics bodies."
	)
	_check(
		game._targets.size() == 26 and DiscoveryCatalog.count() == 27,
		"Ambient city life does not add gameplay targets or Field Guide entries."
	)
	var expected_daylight := (
		sin(game._day_clock * TAU - PI / 2.0) + 1.0
	) * 0.5
	_check(
		is_equal_approx(activity.daylight, expected_daylight),
		"The game forwards its initial day-night value to city activity."
	)
	_check(
		is_zero_approx(FrogGame.rain_intensity_for_clock(0.57))
		and is_zero_approx(FrogGame.rain_intensity_for_clock(0.58))
		and is_equal_approx(
			FrogGame.rain_intensity_for_clock(0.60),
			0.5
		)
		and is_equal_approx(
			FrogGame.rain_intensity_for_clock(0.62),
			1.0
		)
		and is_equal_approx(
			FrogGame.rain_intensity_for_clock(0.74),
			1.0
		)
		and is_equal_approx(
			FrogGame.rain_intensity_for_clock(0.76),
			0.5
		)
		and is_zero_approx(FrogGame.rain_intensity_for_clock(0.78))
		and is_zero_approx(FrogGame.rain_intensity_for_clock(1.57)),
		"Rain follows one bounded deterministic shower with smooth fades per day-night cycle."
	)

	game._day_clock = 0.5
	game._update_day_night(0.0)
	var day_pedestrians := activity.active_pedestrian_count()
	var day_vehicles := activity.active_vehicle_count()
	var day_lights := activity.streetlight_intensity()
	game._day_clock = 0.0
	game._update_day_night(0.0)
	var night_pedestrians := activity.active_pedestrian_count()
	var night_vehicles := activity.active_vehicle_count()
	var night_lights := activity.streetlight_intensity()
	_check(
		day_pedestrians == CityActivity.PEDESTRIAN_ROUTES.size()
		and night_pedestrians == 5
		and day_pedestrians > night_pedestrians,
		"Daylight deterministically changes the visible pedestrian crowd."
	)
	_check(
		day_vehicles == CityActivity.VEHICLE_ROUTES.size()
		and night_vehicles == 2
		and day_vehicles > night_vehicles,
		"Daylight deterministically changes secondary traffic levels."
	)
	_check(
		is_zero_approx(day_lights) and night_lights > 0.99,
		"Streetlights switch on at night without changing the world tint."
	)
	game._day_clock = 0.68
	game._update_day_night(0.0)
	var rainy_snapshot := game.performance_structure_snapshot()
	_check(
		is_equal_approx(activity.rain_intensity, 1.0)
		and activity.active_pedestrian_count() == 4
		and activity.active_vehicle_count() == 3
		and activity.visible_rain_streak_count()
		== CityActivity.RAIN_STREAK_COUNT,
		"Peak rain reduces the decorative crowd and traffic while retaining a bounded visual shower."
	)
	_check(
		int(rainy_snapshot["targets"]) == 26
		and int(rainy_snapshot["buildings"]) == 4
		and int(rainy_snapshot["collision_objects"]) == 31
		and int(rainy_snapshot["collision_shapes"]) == 31,
		"Rain does not add targets, buildings, or collision objects."
	)

	var single_step := CityActivity.new()
	var many_steps := CityActivity.new()
	single_step.set_motion_scale(1.0)
	many_steps.set_motion_scale(1.0)
	single_step.set_rain_intensity(1.0)
	many_steps.set_rain_intensity(1.0)
	single_step._advance_animation(12.0)
	for step in 120:
		many_steps._advance_animation(0.1)
	var single_signature := single_step.activity_signature()
	var many_signature := many_steps.activity_signature()
	var deterministic_positions := single_signature.size() == many_signature.size()
	for index in single_signature.size():
		if single_signature[index].distance_to(many_signature[index]) > 0.001:
			deterministic_positions = false
			break
	var single_rain_signature := single_step.rain_signature()
	var many_rain_signature := many_steps.rain_signature()
	for index in single_rain_signature.size():
		if (
			single_rain_signature[index].distance_to(
				many_rain_signature[index]
			)
			> 0.001
		):
			deterministic_positions = false
			break
	_check(
		deterministic_positions,
		"City actors and rain depend on absolute deterministic time, not frame size."
	)

	var frozen_position := single_step.pedestrian_position(0)
	var frozen_rain := single_step.rain_signature()
	single_step.set_motion_scale(0.0)
	single_step._advance_animation(8.0)
	single_step.set_daylight(0.0)
	_check(
		single_step.pedestrian_position(0) == frozen_position
		and single_step.rain_signature() == frozen_rain
		and single_step.active_pedestrian_count() == 4
		and single_step.active_vehicle_count() == 2
		and single_step.visible_rain_streak_count()
		== CityActivity.RAIN_STREAK_COUNT
		and single_step.streetlight_intensity() > 0.99,
		"Reduced motion freezes actors and rain while weather density and lighting still update."
	)
	seed(20260830)
	var expected_random := randf()
	seed(20260830)
	single_step.set_rain_intensity(0.5)
	single_step.rain_signature()
	var actual_random := randf()
	_check(
		is_equal_approx(actual_random, expected_random),
		"Rain presentation does not consume the gameplay random-number stream."
	)

	var loop_is_seamless := true
	for route in (
		CityActivity.PEDESTRIAN_ROUTES
		+ CityActivity.VEHICLE_ROUTES
	):
		if not is_zero_approx(
			fmod(CityActivity.LOOP_DURATION, float(route["duration"]))
		):
			loop_is_seamless = false
	for index in CityActivity.PEDESTRIAN_ROUTES.size():
		if (
			single_step.pedestrian_position_at(index, 17.25)
			.distance_to(
				single_step.pedestrian_position_at(
					index,
					17.25 + CityActivity.LOOP_DURATION
				)
			)
			> 0.001
		):
			loop_is_seamless = false
	for index in CityActivity.VEHICLE_ROUTES.size():
		if (
			single_step.vehicle_position_at(index, 17.25)
			.distance_to(
				single_step.vehicle_position_at(
					index,
					17.25 + CityActivity.LOOP_DURATION
				)
			)
			> 0.001
		):
			loop_is_seamless = false
	for index in CityActivity.RAIN_STREAK_COUNT:
		if (
			single_step.rain_streak_position_at(index, 17.25)
			.distance_to(
				single_step.rain_streak_position_at(
					index,
					17.25 + CityActivity.RAIN_LOOP_DURATION
				)
			)
			> 0.001
		):
			loop_is_seamless = false
	_check(
		loop_is_seamless,
		"Every authored activity route and rain streak loops seamlessly."
	)

	var forbidden_areas: Array[Rect2] = [
		CityBackdrop.RIVER_RECT,
	]
	for building in game._buildings:
		forbidden_areas.append(building.footprint_rect())
	var routes_are_clear := true
	for sample in 481:
		var sample_time := float(sample) * 0.25
		for index in CityActivity.PEDESTRIAN_ROUTES.size():
			var pedestrian_position := (
				single_step.pedestrian_position_at(index, sample_time)
			)
			for area in forbidden_areas:
				if (area as Rect2).grow(CityActivity.ROUTE_CLEARANCE).has_point(
					pedestrian_position
				):
					routes_are_clear = false
		for index in CityActivity.VEHICLE_ROUTES.size():
			var vehicle_position := (
				single_step.vehicle_position_at(index, sample_time)
			)
			for area in forbidden_areas:
				if (area as Rect2).grow(CityActivity.ROUTE_CLEARANCE).has_point(
					vehicle_position
				):
					routes_are_clear = false
		for restock_position in FrogGame.RESTOCK_POSITIONS:
			for index in CityActivity.VEHICLE_ROUTES.size():
				if (
					single_step.vehicle_position_at(index, sample_time)
					.distance_to(restock_position)
					< 64.0
				):
					routes_are_clear = false
		for target in game._targets:
			if not is_instance_valid(target):
				continue
			for index in CityActivity.VEHICLE_ROUTES.size():
				if (
					single_step.vehicle_position_at(index, sample_time)
					.distance_to(target.global_position)
					< target.pick_radius + 22.0
				):
					routes_are_clear = false
	_check(
		routes_are_clear,
		"Routes avoid structures and water; traffic avoids targets and restock points."
	)

	single_step.free()
	many_steps.free()
	game.queue_free()
	await process_frame


func _test_discovery_collection(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.configure(
		"discovery_test",
		"Discovery Tester",
		false,
		PackedStringArray(["market_apple", "future_unknown_target"])
	)
	root.add_child(game)
	await process_frame
	await physics_frame

	var startup_ids := {}
	for target in game._targets:
		startup_ids[target.target_id] = true
	startup_ids["animal_control"] = true
	var catalog_ids := {}
	for target_id in DiscoveryCatalog.ids():
		catalog_ids[target_id] = true
	var catalog_matches_targets := (
		catalog_ids.size() == startup_ids.size()
		and catalog_ids.size() == DiscoveryCatalog.count()
	)
	for target_id in startup_ids:
		if not catalog_ids.has(target_id):
			catalog_matches_targets = false
	_check(
		catalog_matches_targets and DiscoveryCatalog.count() == 27,
		"Field Guide catalog exactly matches every swallowable prototype target."
	)
	_check(
		game._known_discovery_count() == 1
		and game._discoveries.has("market_apple")
		and not game._discoveries.has("future_unknown_target"),
		"Only known saved discoveries are injected before gameplay."
	)

	var discovery_events: Array[String] = []
	game.target_discovered.connect(func(target_id: String) -> void:
		discovery_events.append(target_id)
	)
	var score_before := game._score
	var growth_before := game._growth_points
	var donut := _find_target(game, "street_donut")
	game._swallow_target(donut, 1.0)
	_check(
		discovery_events == ["street_donut"]
		and game._known_discovery_count() == 2,
		"A first swallow records and emits exactly one discovery."
	)
	_check(
		game._score == score_before
		and game._growth_points == growth_before,
		"Discovery credit does not award score or growth."
	)
	_check(
		game._discovery_banner.visible
		and game._status_label.text.contains("Swallowed Street Donut"),
		"First-discovery feedback does not replace swallow instructions."
	)

	game._spit_item(0)
	var returned_donut := _find_target(game, "street_donut")
	game._swallow_target(returned_donut, 1.0)
	_check(
		discovery_events == ["street_donut"]
		and game._known_discovery_count() == 2,
		"Returning and swallowing a known target cannot duplicate discovery credit."
	)
	game._record_discovery("future_unknown_target", "Future Target")
	_check(
		discovery_events == ["street_donut"]
		and not game._discoveries.has("future_unknown_target"),
		"Unknown target IDs cannot pollute Field Guide progress or saves."
	)

	var pending_touch := InputEventScreenTouch.new()
	pending_touch.index = 9
	pending_touch.position = Vector2(120, 300)
	pending_touch.pressed = true
	game._handle_screen_touch(pending_touch)
	_check(
		game._active_touches.has(9),
		"The overlay regression test starts with a held world touch."
	)
	game._mouse_rotating = true
	game._open_guide()
	_check(
		game._guide_overlay.visible
		and paused
		and game._active_touches.is_empty()
		and not game._camera_gesture
		and not game._mouse_rotating,
		"Opening the Field Guide pauses gameplay and clears held input gestures."
	)
	var discovered_row := game._guide_list.get_child(0) as Label
	var unknown_row := game._guide_list.get_child(2) as Label
	_check(
		discovered_row.text.contains("Street Donut")
		and not unknown_row.text.contains("Runaway Hot Dog")
		and unknown_row.text.contains("Hint:"),
		"Guide rows reveal found names while unknown entries show only useful hints."
	)
	var hotdog := _find_target(game, "running_hotdog")
	var belly_size_before_touch := game._belly.size()
	var blocked_touch := InputEventScreenTouch.new()
	blocked_touch.index = 8
	blocked_touch.position = (
		game.get_viewport().get_canvas_transform()
		* hotdog.global_position
	)
	blocked_touch.double_tap = true
	blocked_touch.pressed = true
	game._handle_screen_touch(blocked_touch)
	blocked_touch.pressed = false
	game._handle_screen_touch(blocked_touch)
	_check(
		game._belly.size() == belly_size_before_touch,
		"Field Guide consumes iPad touches instead of firing through to the world."
	)
	game._open_belly()
	_check(
		game._guide_overlay.visible
		and not game._belly_overlay.visible
		and paused,
		"Field Guide and belly overlays remain mutually exclusive."
	)
	game._close_guide()
	_check(not paused, "Closing the Field Guide resumes gameplay.")
	var move_destination := game._frog.global_position + Vector2(0, 120)
	var move_screen := (
		game.get_viewport().get_canvas_transform() * move_destination
	)
	var move_touch := InputEventScreenTouch.new()
	move_touch.index = 0
	move_touch.position = move_screen
	move_touch.pressed = true
	game._handle_screen_touch(move_touch)
	move_touch.pressed = false
	game._handle_screen_touch(move_touch)
	_check(
		game._frog._has_move_target
		and game._frog._move_target.distance_to(move_destination) < 0.01,
		"A single iPad tap still moves the frog after closing the Field Guide."
	)

	game._open_belly()
	game._open_guide()
	_check(
		game._belly_overlay.visible
		and not game._guide_overlay.visible
		and paused,
		"An open belly prevents a second pausing overlay."
	)
	game._close_belly()

	game._begin_struggle(hotdog, 0.8, Vector2.ZERO)
	game._open_guide()
	_check(
		not game._guide_overlay.visible and not paused,
		"Field Guide cannot pause an active struggle."
	)
	game._clear_struggle()

	game._growth_tier = 2
	game._frog.set_growth_tier(2)
	game._spawn_pursuer()
	_check(
		is_instance_valid(game._pursuer),
		"Animal Control is available for its Field Guide entry."
	)
	if is_instance_valid(game._pursuer):
		game._swallow_pursuer(game._pursuer, 1.0)
	_check(
		game._discoveries.has("animal_control")
		and discovery_events == ["street_donut", "animal_control"],
		"Animal Control records through its dedicated swallow path."
	)
	var animal_control_item := game._belly.back() as BellyItem
	_check(
		animal_control_item.target_id == "animal_control"
		and not animal_control_item.restockable,
		"Digested Animal Control cannot become an endlessly farmable target."
	)
	for target_id in DiscoveryCatalog.ids():
		if target_id != "moonlight_market_building":
			game._record_discovery(target_id)
	game._record_discovery("moonlight_market_building")
	_check(
		game._discovery_banner_label.text.contains("Moonlight Market")
		and game._discovery_banner_label.text.contains(
			"completes the Field Guide"
		),
		"The final discovery banner names the entry that completes the Guide."
	)

	game.queue_free()
	paused = false
	await process_frame


func _test_session_challenges(game_scene: PackedScene) -> void:
	var challenges := SessionChallenges.new()
	var completion_events: Array[String] = []
	challenges.challenge_completed.connect(func(challenge_id: String) -> void:
		completion_events.append(challenge_id)
	)
	challenges.begin()
	challenges.record_swallow("street_donut", 0.89)
	challenges.record_swallow("street_donut", 0.9)
	_check(
		challenges.progress(SessionChallenges.SHARP_AIM) == 1
		and challenges.progress(SessionChallenges.CITY_TOUR) == 1,
		"Challenge thresholds are inclusive and repeated IDs count once for City Tour."
	)
	challenges.record_swallow("street_donut", 1.0)
	challenges.record_swallow("street_donut", 1.0)
	challenges.record_swallow("market_apple", 0.0)
	challenges.record_swallow("running_hotdog", 0.0)
	challenges.record_swallow("shop_phone", 0.0)
	challenges.record_struggle_win()
	challenges.record_struggle_win()
	challenges.record_struggle_win()
	_check(
		challenges.completed_count() == 3
		and completion_events.size() == 3,
		"Each fixed challenge completes and emits exactly once per session."
	)

	var game := game_scene.instantiate() as FrogGame
	game.configure(
		"challenge_test",
		"Challenge Tester",
		false,
		DiscoveryCatalog.ids()
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	_check(
		game._challenge_panel.visible
		and game._challenges.active
		and game._challenges.completed_count() == 0,
		"Normal sessions start fresh challenges independently of Field Guide progress."
	)
	var panel_rect := game._challenge_panel.get_global_rect()
	var status_panel := game.get_node("HUD/Root/StatusPanel") as Control
	var discovery_banner := game._discovery_banner as Control
	var instructions := game.get_node("HUD/Root/Instructions") as Control
	var layout_clear := (
		not panel_rect.intersection(game._top_margin.get_global_rect()).has_area()
		and not panel_rect.intersection(status_panel.get_global_rect()).has_area()
		and not panel_rect.intersection(
			discovery_banner.get_global_rect()
		).has_area()
		and not panel_rect.intersection(instructions.get_global_rect()).has_area()
		and game.get_viewport().get_visible_rect().encloses(panel_rect)
	)
	_check(
		layout_clear
		and game._challenge_panel.get_index()
		< game._belly_overlay.get_index(),
		"The passive challenge panel has a clear 4:3 lane below pause overlays."
	)
	var pass_through_point := panel_rect.get_center()
	_check(
		game._find_target_at(
			game._screen_to_world(pass_through_point)
		) == null,
		"The challenge touch test uses clear world space behind the panel."
	)
	game._frog._has_move_target = false
	_push_mouse_click(game.get_viewport(), pass_through_point)
	await process_frame
	_check(
		game._frog._has_move_target,
		"The passive challenge panel does not create an iPad touch dead zone."
	)

	var score_before := game._score
	var growth_before := game._growth_points
	var donut := _find_target(game, "street_donut")
	game._swallow_target(donut, 0.89)
	_check(
		game._challenges.progress(SessionChallenges.SHARP_AIM) == 0
		and game._challenges.progress(SessionChallenges.CITY_TOUR) == 1
		and game._status_label.text.contains("Swallowed Street Donut")
		and not game._discovery_banner.visible,
		"Challenge progress preserves swallow and discovery feedback lanes."
	)
	var hotdog := _find_target(game, "running_hotdog")
	game._swallow_target(hotdog, 0.95)
	_check(
		game._challenges.progress(SessionChallenges.HOLD_ON) == 0,
		"Directly swallowing a resistant target does not count as a struggle win."
	)
	game._growth_tier = 2
	game._frog.set_growth_tier(2)
	game._spawn_pursuer()
	game._swallow_pursuer(game._pursuer, 1.0)
	_check(
		game._challenges.progress(SessionChallenges.HOLD_ON) == 0,
		"Swallowing Animal Control does not count as a struggle win."
	)
	var vendor := _find_target(game, "market_vendor")
	game._begin_struggle(vendor, 0.95, Vector2.ZERO)
	for _tap in vendor.taps_required:
		game._register_struggle_tap()
	var door := _find_target(game, "moonlight_market_door")
	game._begin_struggle(door, 0.95, Vector2.ZERO)
	for _tap in door.taps_required:
		game._register_struggle_tap()
	_check(
		game._challenges.completed_count() == 3
		and game._challenge_summary.visible
		and game._challenge_summary.text == "All tasks complete!",
		"Completing all three tasks produces clear presentation-only feedback."
	)
	game._update_hud_feedback(FrogGame.HUD_PULSE_DURATION * 0.5)
	_check(
		game._challenge_sharp_aim.text.contains("90%+ Hits")
		and game._challenge_hold_on.text.contains("Struggle Wins")
		and game._challenge_city_tour.text.contains("Target Types")
		and game._challenge_hold_on.modulate != Color.WHITE
		and game._challenge_hold_on.scale == Vector2.ONE,
		"Challenge requirements are explicit and completion pulses without motion."
	)
	_check(
		game._score == score_before
		and game._growth_points == growth_before,
		"Challenge completion cannot award score or alter growth gating."
	)

	game.queue_free()
	await process_frame


func _test_oddities_shop_sequence(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.configure("oddities_test", "Oddities Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	var shop := (
		game._building_by_id.get("oddities_shop") as PrototypeBuilding
	)
	var market := (
		game._building_by_id.get("moonlight_market") as PrototypeBuilding
	)
	_check(
		is_instance_valid(shop)
		and shop.weakness_count() == 0
		and shop._door_body.collision_layer == 1,
		"Oddities Shop starts intact with its shutter blocking entry."
	)
	var building_target := _find_target(game, "oddities_shop_building")
	_check(
		not building_target.selectable
		and not building_target.hit_test(shop.global_position),
		"The whole Oddities Shop stays inactive before all parts are removed."
	)

	var shutter := _find_target(game, "oddities_shop_door")
	game._frog.global_position = Vector2(610, 900)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* shutter.global_position
	)
	_check(
		shop.weakness_count() == 1
		and shop._door_body.collision_layer == 0,
		"The Shop Shutter is reachable at starting size and opens the entrance."
	)
	_check(
		game._status_label.text.contains(
			"Oddities Shop is weakened to 1/3"
		)
		and not game._status_label.text.contains("Moonlight Market"),
		"Shop weakness feedback names the correct building."
	)
	game._digest_item(0)

	var shelf := _find_target(game, "oddities_shop_counter")
	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._frog.global_position = Vector2(500, 900)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* shelf.global_position
	)
	_check(
		not is_instance_valid(game._struggle_target)
		and game._status_label.text.contains(
			"Enter Oddities Shop before reaching for Curio Shelf"
		),
		"The Curio Shelf explicitly requires the frog to enter the shop."
	)

	game._growth_tier = 0
	game._frog.set_growth_tier(0)
	game._frog.global_position = Vector2(610, 1200)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* shelf.global_position
	)
	_check(
		game._pull_target == shelf
		and game._status_label.text.contains("is too big and pulls"),
		"The Curio Shelf requires the first growth tier after entering the shop."
	)
	game._cancel_pull()

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* shelf.global_position
	)
	_check(
		game._struggle_target == shelf,
		"The Curio Shelf starts a real struggle inside the open shop."
	)
	game._fail_struggle()
	_check(
		shelf.global_position
		== shop.part_world_position(PrototypeBuilding.PART_COUNTER)
		and shelf.velocity == Vector2.ZERO
		and not shelf.unpredictable,
		"A failed building-part struggle returns the shelf to its fixture."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer.queue_free()
		game._pursuer = null

	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* shelf.global_position
	)
	for _tap in shelf.taps_required:
		game._register_struggle_tap()
	_check(
		shop.weakness_count() == 2
		and shop._counter_body.collision_layer == 0,
		"Winning the shelf struggle removes its collision and adds one weakness."
	)
	game._frog.global_position = Vector2(610, 900)
	game._spit_item(0)
	var loose_shelf := _find_target(game, "oddities_shop_counter")
	game._begin_struggle(loose_shelf, 1.0, Vector2.ZERO)
	game._fail_struggle()
	_check(
		loose_shelf.global_position
		!= shop.part_world_position(PrototypeBuilding.PART_COUNTER)
		and loose_shelf.velocity != Vector2.ZERO
		and loose_shelf.building_id.is_empty()
		and loose_shelf.building_part_id.is_empty(),
		"A spat-out fixture becomes a normal loose target instead of returning to the shop."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer.queue_free()
		game._pursuer = null
	game._swallow_target(loose_shelf, 1.0)
	game._digest_item(0)

	var banner := _find_target(game, "oddities_shop_sign")
	game._swallow_target(banner, 1.0)
	_check(
		shop.weakness_count() == 3
		and shop.is_ready_to_swallow()
		and building_target.selectable,
		"Removing the Shop Banner fully weakens and activates the Oddities Shop."
	)
	game._digest_item(0)
	_check(
		market.weakness_count() == 0,
		"Oddities Shop damage does not weaken Moonlight Market."
	)

	game._growth_tier = 2
	game._frog.set_growth_tier(2)
	game._frog.global_position = Vector2(610, 900)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* building_target.global_position
	)
	_check(
		game._struggle_target == building_target,
		"The weakened shop can be targeted through its removed shutter."
	)
	game._fail_struggle()
	_check(
		building_target.global_position == shop.global_position
		and building_target.velocity == Vector2.ZERO
		and not building_target.unpredictable
		and not shop.consumed
		and game._status_label.text.contains(
			"Oddities Shop shook the frog off"
		),
		"A failed whole-shop struggle stays anchored and uses building feedback."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer.queue_free()
		game._pursuer = null
		await process_frame
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* building_target.global_position
	)
	for _tap in building_target.taps_required:
		game._register_struggle_tap()
	_check(
		shop.consumed
		and game._building_footprint_clear(shop)
		and game._belly.size() == 1
		and game._belly[0].kind == "building",
		"Swallowing the Oddities Shop removes its structure and creates one belly record."
	)
	_check(
		game._status_label.text.contains(
			"The whole Oddities Shop is now inside the frog"
		),
		"Whole-building feedback names the Oddities Shop."
	)

	game._spit_item(0)
	var restored_shop_target := _find_target(
		game,
		"oddities_shop_building"
	)
	_check(
		not shop.consumed
		and shop.weakness_count() == 3
		and shop._door_body.collision_layer == 0
		and shop._counter_body.collision_layer == 0
		and restored_shop_target.velocity == Vector2.ZERO
		and not restored_shop_target.visible
		and restored_shop_target.selectable,
		"Restoring the shop keeps every removed part absent."
	)
	_check(
		game._status_label.text.contains("Oddities Shop was restored"),
		"Restoration feedback names the Oddities Shop."
	)

	building_target = _find_target(game, "oddities_shop_building")
	game._swallow_target(building_target, 1.0)
	var score_before := game._score
	game._digest_item(0)
	_check(
		game._score > score_before and shop.consumed,
		"Digesting the Oddities Shop awards score once and leaves it removed."
	)

	game.queue_free()
	await process_frame


func _test_leap_cafe_sequence(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.configure("leap_cafe_test", "Leap Cafe Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	var cafe := (
		game._building_by_id.get("leap_cafe") as PrototypeBuilding
	)
	var menu_board := _find_target(game, "leap_cafe_menu_board")
	var espresso_counter := _find_target(
		game,
		"leap_cafe_espresso_counter"
	)
	var awning := _find_target(game, "leap_cafe_awning")
	var building_target := _find_target(game, "leap_cafe_building")
	_check(
		is_instance_valid(cafe)
		and cafe.destructible_parts
		and cafe.weakness_count() == 0
		and cafe.entrance_part_style
		== PrototypeBuilding.ENTRANCE_PART_AWNING
		and not is_instance_valid(cafe._door_body)
		and game._circle_position_clear(
			Vector2(610, -450),
			44.0,
			true
		),
		"Leap Cafe starts intact, destructible, and enterable at maximum size."
	)
	_check(
		menu_board.visible
		and menu_board.selectable
		and not espresso_counter.visible
		and not espresso_counter.selectable
		and not awning.visible
		and not awning.selectable
		and not building_target.selectable,
		"Only the Sidewalk Menu Board is active at the start of the ordered sequence."
	)

	game._frog.global_position = Vector2(475, -280)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* menu_board.global_position
	)
	_check(
		cafe.weakness_count() == 1
		and espresso_counter.visible
		and espresso_counter.selectable
		and not awning.visible
		and game._status_label.text.contains(
			"Leap Café is weakened to 1/3"
		),
		"Removing the menu board adds one weakness and unlocks only the Rear Espresso Counter."
	)
	game._digest_item(0)

	game._frog.global_position = Vector2(610, -330)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* espresso_counter.global_position
	)
	_check(
		not is_instance_valid(game._struggle_target)
		and game._status_label.text.contains(
			"Enter Leap Café before reaching for Rear Espresso Counter"
		),
		"The Rear Espresso Counter explicitly requires entering the cafe."
	)

	game._growth_tier = 0
	game._frog.set_growth_tier(0)
	game._frog.global_position = Vector2(610, -535)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* espresso_counter.global_position
	)
	_check(
		game._pull_target == espresso_counter
		and game._status_label.text.contains("is too big and pulls"),
		"The interior counter requires the first growth tier."
	)
	game._cancel_pull()

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* espresso_counter.global_position
	)
	_check(
		game._struggle_target == espresso_counter,
		"The grown frog starts a rapid-tap struggle with the Rear Espresso Counter."
	)
	game._fail_struggle()
	_check(
		espresso_counter.global_position
		== cafe.part_world_position(PrototypeBuilding.PART_COUNTER)
		and espresso_counter.velocity == Vector2.ZERO
		and not espresso_counter.unpredictable,
		"A failed counter struggle returns the fixture to the rear of the cafe."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer.queue_free()
		game._pursuer = null
		await process_frame

	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* espresso_counter.global_position
	)
	for _tap in espresso_counter.taps_required:
		game._register_struggle_tap()
	_check(
		cafe.weakness_count() == 2
		and cafe._counter_body.collision_layer == 0
		and awning.visible
		and awning.selectable
		and not building_target.selectable,
		"Winning the counter struggle removes its collision and unlocks only the Front Awning."
	)
	game._digest_item(0)

	var phone := _find_target(game, "shop_phone")
	game._frog.global_position = Vector2(566, -620)
	game._swallow_target(phone, 1.0)
	game._digest_item(0)

	game._frog.global_position = Vector2(610, -290)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* awning.global_position
	)
	_check(
		cafe.weakness_count() == 3
		and cafe.is_ready_to_swallow()
		and building_target.selectable
		and game._circle_position_clear(
			Vector2(610, -450),
			44.0,
			true
		),
		"Removing the awning fully weakens the cafe without ever blocking its entrance."
	)
	game._digest_item(0)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* building_target.global_position
	)
	_check(
		game._pull_target == building_target
		and game._status_label.text.contains(
			"Leap Café is weak, but the frog must reach maximum growth"
		),
		"The fully weakened cafe still requires maximum growth."
	)
	game._cancel_pull()

	game._growth_tier = 2
	game._frog.set_growth_tier(2)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* building_target.global_position
	)
	_check(
		game._struggle_target == building_target,
		"The maximum-size frog starts the whole-cafe struggle through the open entrance."
	)
	game._fail_struggle()
	_check(
		building_target.global_position == cafe.global_position
		and not cafe.consumed
		and game._status_label.text.contains(
			"Leap Cafe shook the frog off"
		),
		"A failed whole-cafe struggle stays anchored and summons pursuit."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer.queue_free()
		game._pursuer = null
		await process_frame

	var score_before_capture := game._score
	var growth_before_capture := game._growth_points
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* building_target.global_position
	)
	for _tap in building_target.taps_required:
		game._register_struggle_tap()
	_check(
		cafe.consumed
		and game._building_footprint_clear(cafe)
		and game._belly.size() == 1
		and game._belly[0].target_id == "leap_cafe_building"
		and game._score == score_before_capture
		and game._growth_points == growth_before_capture,
		"Swallowing the whole cafe creates one Belly item without immediate score or growth."
	)
	_check(
		game._discoveries.has("leap_cafe_menu_board")
		and game._discoveries.has("leap_cafe_espresso_counter")
		and game._discoveries.has("leap_cafe_awning")
		and game._discoveries.has("leap_cafe_building"),
		"Every Leap Cafe part and the whole building records its first discovery."
	)

	var footprint_blocker := EdibleTarget.new()
	footprint_blocker.position = cafe.global_position
	footprint_blocker.pick_radius = 30.0
	game._world.add_child(footprint_blocker)
	game._targets.append(footprint_blocker)
	game._spit_item(0)
	_check(
		cafe.consumed and game._belly.size() == 1,
		"An occupied Leap Cafe footprint prevents unsafe restoration."
	)
	game._targets.erase(footprint_blocker)
	footprint_blocker.queue_free()
	game._spit_item(0)
	var restored_building_target := _find_target(
		game,
		"leap_cafe_building"
	)
	_check(
		not cafe.consumed
		and cafe.weakness_count() == 3
		and cafe._counter_body.collision_layer == 0
		and not is_instance_valid(cafe._door_body)
		and restored_building_target.selectable
		and game._circle_position_clear(
			Vector2(610, -450),
			44.0,
			true
		)
		and not game._circle_position_clear(
			Vector2(469, -535),
			24.0,
			true
		),
		"Restoration keeps all three parts absent while preserving the doorway and Loose Phone bar."
	)

	var restored_target_count := 0
	for target in game._targets:
		if target.target_id == "leap_cafe_building":
			restored_target_count += 1
	_check(
		restored_target_count == 1,
		"Restoring the cafe creates exactly one whole-building target."
	)

	game._swallow_target(restored_building_target, 1.0)
	var score_before_digest := game._score
	game._digest_item(0)
	_check(
		game._score > score_before_digest and cafe.consumed,
		"Digesting the restored cafe awards score once and leaves its geometry consumed."
	)

	await create_timer(9.2, false).timeout
	var restocked_phone := _find_target(game, "shop_phone")
	_check(
		is_instance_valid(restocked_phone)
		and cafe.interior_rect().has_point(restocked_phone.global_position)
		and cafe.consumed
		and game._circle_position_clear(
			Vector2(469, -535),
			24.0,
			true
		),
		"An ordinary cafe target restocks safely without recreating consumed building geometry."
	)

	game.queue_free()
	await process_frame


func _test_canal_apartments_sequence(
	game_scene: PackedScene
) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.configure(
		"canal_apartments_test",
		"Canal Apartments Tester",
		false
	)
	root.add_child(game)
	await process_frame
	await physics_frame

	var apartments := (
		game._building_by_id.get("canal_apartments")
		as PrototypeBuilding
	)
	var address_plaque := _find_target(
		game,
		"canal_apartments_address_plaque"
	)
	var lobby_bench := _find_target(
		game,
		"canal_apartments_lobby_bench"
	)
	var entry_canopy := _find_target(
		game,
		"canal_apartments_entry_canopy"
	)
	var building_target := _find_target(
		game,
		"canal_apartments_building"
	)
	_check(
		is_instance_valid(apartments)
		and apartments.destructible_parts
		and apartments.weakness_count() == 0
		and apartments.entrance_part_style
		== PrototypeBuilding.ENTRANCE_PART_AWNING
		and apartments.counter_position == Vector2(188, 100)
		and apartments.counter_size == Vector2(86, 60)
		and apartments.interior_props.size() == 2
		and not is_instance_valid(apartments._door_body)
		and game._circle_position_clear(
			Vector2(-610, 1120),
			44.0,
			true
		),
		"Canal Apartments starts intact, furnished, and enterable at maximum size."
	)
	_check(
		address_plaque.visible
		and address_plaque.selectable
		and not lobby_bench.visible
		and not lobby_bench.selectable
		and not entry_canopy.visible
		and not entry_canopy.selectable
		and not building_target.selectable,
		"Only the Address Plaque is active at the start of the ordered apartment sequence."
	)

	game._frog.global_position = Vector2(-745, 900)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* address_plaque.global_position
	)
	_check(
		apartments.weakness_count() == 1
		and lobby_bench.visible
		and lobby_bench.selectable
		and not entry_canopy.visible
		and game._status_label.text.contains(
			"Canal Apartments is weakened to 1/3"
		),
		"Removing the plaque adds one weakness and unlocks only the Lobby Bench."
	)
	game._digest_item(0)

	game._frog.global_position = Vector2(-610, 960)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* lobby_bench.global_position
	)
	_check(
		not is_instance_valid(game._struggle_target)
		and game._status_label.text.contains(
			"Enter Canal Apartments before reaching for Lobby Bench"
		),
		"The Lobby Bench explicitly requires entering the apartment lobby."
	)

	game._growth_tier = 0
	game._frog.set_growth_tier(0)
	game._frog.global_position = Vector2(-610, 1210)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* lobby_bench.global_position
	)
	_check(
		game._pull_target == lobby_bench
		and game._status_label.text.contains("is too big and pulls"),
		"The interior bench requires the first growth tier."
	)
	game._cancel_pull()

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* lobby_bench.global_position
	)
	_check(
		game._struggle_target == lobby_bench,
		"The grown frog starts a rapid-tap struggle with the Lobby Bench."
	)
	game._fail_struggle()
	_check(
		lobby_bench.global_position
		== apartments.part_world_position(
			PrototypeBuilding.PART_COUNTER
		)
		and lobby_bench.velocity == Vector2.ZERO
		and not lobby_bench.unpredictable,
		"A failed bench struggle returns the fixture to the right-rear wall."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer.queue_free()
		game._pursuer = null
		await process_frame

	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* lobby_bench.global_position
	)
	for _tap in lobby_bench.taps_required:
		game._register_struggle_tap()
	_check(
		apartments.weakness_count() == 2
		and apartments._counter_body.collision_layer == 0
		and entry_canopy.visible
		and entry_canopy.selectable
		and not building_target.selectable,
		"Winning the bench struggle removes its collision and unlocks only the Entry Canopy."
	)
	game._digest_item(0)

	var lamp := _find_target(game, "canal_lobby_lamp")
	var cat := _find_target(game, "canal_tenant_cat")
	game._swallow_target(lamp, 1.0)
	game._digest_item(0)
	game._swallow_target(cat, 1.0)
	game._digest_item(0)

	game._frog.global_position = Vector2(-610, 900)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* entry_canopy.global_position
	)
	_check(
		apartments.weakness_count() == 3
		and apartments.is_ready_to_swallow()
		and building_target.selectable
		and game._circle_position_clear(
			Vector2(-610, 1120),
			44.0,
			true
		),
		"Removing the canopy fully weakens the apartments without blocking the entrance."
	)
	game._digest_item(0)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* building_target.global_position
	)
	_check(
		game._pull_target == building_target
		and game._status_label.text.contains(
			"Canal Apartments is weak, but the frog must reach maximum growth"
		),
		"The fully weakened apartments still require maximum growth."
	)
	game._cancel_pull()

	game._growth_tier = 2
	game._frog.set_growth_tier(2)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* building_target.global_position
	)
	_check(
		game._struggle_target == building_target,
		"The maximum-size frog starts the whole-apartments struggle through the open entrance."
	)
	game._fail_struggle()
	_check(
		building_target.global_position == apartments.global_position
		and not apartments.consumed
		and game._status_label.text.contains(
			"Canal Apartments shook the frog off"
		),
		"A failed whole-apartments struggle stays anchored and summons pursuit."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer.queue_free()
		game._pursuer = null
		await process_frame

	var score_before_capture := game._score
	var growth_before_capture := game._growth_points
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* building_target.global_position
	)
	for _tap in building_target.taps_required:
		game._register_struggle_tap()
	_check(
		apartments.consumed
		and game._building_footprint_clear(apartments)
		and game._belly.size() == 1
		and game._belly[0].target_id
		== "canal_apartments_building"
		and game._score == score_before_capture
		and game._growth_points == growth_before_capture,
		"Swallowing the apartments creates one Belly item without immediate score or growth."
	)
	_check(
		game._discoveries.has(
			"canal_apartments_address_plaque"
		)
		and game._discoveries.has(
			"canal_apartments_lobby_bench"
		)
		and game._discoveries.has(
			"canal_apartments_entry_canopy"
		)
		and game._discoveries.has(
			"canal_apartments_building"
		),
		"Every apartment part and the whole building records its first discovery."
	)

	var footprint_blocker := EdibleTarget.new()
	footprint_blocker.position = apartments.global_position
	footprint_blocker.pick_radius = 30.0
	game._world.add_child(footprint_blocker)
	game._targets.append(footprint_blocker)
	game._spit_item(0)
	_check(
		apartments.consumed and game._belly.size() == 1,
		"An occupied Canal Apartments footprint prevents unsafe restoration."
	)
	game._targets.erase(footprint_blocker)
	footprint_blocker.queue_free()
	game._spit_item(0)
	var restored_building_target := _find_target(
		game,
		"canal_apartments_building"
	)
	_check(
		not apartments.consumed
		and apartments.weakness_count() == 3
		and apartments._counter_body.collision_layer == 0
		and not is_instance_valid(apartments._door_body)
		and restored_building_target.selectable
		and game._circle_position_clear(
			Vector2(-610, 1120),
			44.0,
			true
		)
		and not game._circle_position_clear(
			Vector2(-798, 1246),
			24.0,
			true
		),
		"Restoration keeps all parts absent while preserving the lobby aisle and remaining furniture."
	)

	var restored_target_count := 0
	for target in game._targets:
		if target.target_id == "canal_apartments_building":
			restored_target_count += 1
	_check(
		restored_target_count == 1,
		"Restoring Canal Apartments creates exactly one whole-building target."
	)

	game._swallow_target(restored_building_target, 1.0)
	var score_before_digest := game._score
	game._digest_item(0)
	_check(
		game._score > score_before_digest
		and apartments.consumed,
		"Digesting the restored apartments awards score once and removes their geometry."
	)

	await create_timer(9.2, false).timeout
	var restocked_lamp := _find_target(game, "canal_lobby_lamp")
	var restocked_cat := _find_target(game, "canal_tenant_cat")
	var lamp_count := 0
	var cat_count := 0
	for target in game._targets:
		if target.target_id == "canal_lobby_lamp":
			lamp_count += 1
		elif target.target_id == "canal_tenant_cat":
			cat_count += 1
	_check(
		is_instance_valid(restocked_lamp)
		and is_instance_valid(restocked_cat)
		and apartments.interior_rect().has_point(
			restocked_lamp.global_position
		)
		and apartments.interior_rect().has_point(
			restocked_cat.global_position
		)
		and apartments.consumed
		and lamp_count == 1
		and cat_count == 1
		and game._circle_position_clear(
			Vector2(-798, 1246),
			24.0,
			true
		),
		"Apartment targets restock once inside the consumed footprint without recreating geometry."
	)

	game.queue_free()
	await process_frame


func _test_building_interiors(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.configure("interior_test", "Interior Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	var cafe := game._building_by_id["leap_cafe"] as PrototypeBuilding
	var apartments := (
		game._building_by_id["canal_apartments"] as PrototypeBuilding
	)
	var market := (
		game._building_by_id["moonlight_market"] as PrototypeBuilding
	)
	var shop := (
		game._building_by_id["oddities_shop"] as PrototypeBuilding
	)
	_check(
		not game._circle_position_clear(Vector2(469, -535), 24.0, true)
		and not game._circle_position_clear(
			Vector2(-798, 1246),
			24.0,
			true
		),
		"Café and apartment furniture creates real interior collision."
	)
	_check(
		game._circle_position_clear(Vector2(610, -535), 44.0, true)
		and game._circle_position_clear(
			Vector2(-610, 1210),
			44.0,
			true
		),
		"Both furnished interiors retain a max-size central aisle."
	)
	_check(
		game._circle_position_clear(Vector2(610, -450), 44.0, true)
		and game._circle_position_clear(
			Vector2(-610, 1120),
			44.0,
			true
		),
		"Both furnished doorways still admit a maximum-size frog."
	)
	_check(
		cafe.interior_props.size() == 2
		and apartments.interior_props.size() == 2
		and market.interior_props.is_empty()
		and shop.interior_props.is_empty(),
		"Authored furniture stays limited to Leap Cafe and Canal Apartments."
	)

	var phone := _find_target(game, "shop_phone")
	var lamp := _find_target(game, "canal_lobby_lamp")
	var cat := _find_target(game, "canal_tenant_cat")
	_check(
		phone.building_id == cafe.building_id
		and phone.move_bounds == cafe.interior_rect()
		and lamp.building_id == apartments.building_id
		and lamp.move_bounds == apartments.interior_rect()
		and cat.building_id == apartments.building_id
		and cat.move_bounds == apartments.interior_rect()
		and cat.restockable,
		"Interior targets stay associated with and restock inside their rooms."
	)
	game._frog.global_position = Vector2(-610, 980)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* lamp.global_position
	)
	_check(
		game._belly.is_empty()
		and game._status_label.text.contains("Enter Canal Apartments"),
		"Apartment targets cannot be swallowed from the street."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._frog.global_position = Vector2(610, -430)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	var phone_screen := (
		game.get_viewport().get_canvas_transform()
		* phone.global_position
	)
	game._try_tongue_at_screen(phone_screen)
	_check(
		game._belly.is_empty()
		and game._status_label.text.contains("bounced off a wall"),
		"The café bar blocks a doorway shot at the Loose Phone."
	)
	game._frog.global_position = Vector2(566, -620)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* phone.global_position
	)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id == "shop_phone",
		"Walking past the café bar opens a clear shot at the Loose Phone."
	)

	game._growth_tier = 0
	game._frog.set_growth_tier(0)
	game._frog.global_position = Vector2(-660, 1150)
	game._tongue_recovery = 0.0
	game._update_camera()
	await process_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* cat.global_position
	)
	_check(
		game._pull_target == cat,
		"The Tenant's Cat requires the first growth tier."
	)
	game._cancel_pull()
	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* cat.global_position
	)
	_check(
		game._struggle_target == cat,
		"The grown frog can start the apartment cat struggle."
	)
	game._fail_struggle()
	_check(
		cat.velocity == Vector2.ZERO
		and not cat.unpredictable
		and apartments.contains_world_point(cat.global_position),
		"A failed apartment struggle keeps the cat safely inside the lobby."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer.queue_free()
		game._pursuer = null
		await process_frame
		await physics_frame

	game._frog.global_position = Vector2(-610, 1210)
	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._pending_growth_tier = 2
	game._retry_pending_growth()
	_check(
		game._growth_tier == 2
		and game._pending_growth_tier == -1,
		"Canal Apartments has enough clear space for indoor growth."
	)
	var interior_spawn := game._allocate_target_spawn_position(
		30.0,
		apartments.interior_rect()
	)
	_check(
		interior_spawn != Vector2.INF
		and apartments.interior_rect().has_point(interior_spawn),
		"The furnished apartment lobby retains collision-safe restock space."
	)
	game._frog.global_position = Vector2(610, -570)
	_check(
		not game._frog_relocation_path_clear(Vector2(350, -570)),
		"Growth relocation cannot jump through a café wall."
	)

	apartments.consume()
	_check(
		game._circle_position_clear(
			Vector2(-798, 1246),
			24.0,
			true
		),
		"Consuming a furnished building disables its interior prop collision."
	)
	apartments.restore()
	_check(
		not game._circle_position_clear(
			Vector2(-798, 1246),
			24.0,
			true
		),
		"Restoring a furnished building restores its interior prop collision."
	)

	game.queue_free()
	await process_frame


func _test_feel_effects_component() -> void:
	seed(20260830)
	var expected_random := randf()
	seed(20260830)
	var effects := FeelEffects.new()
	root.add_child(effects)
	await process_frame
	effects.set_motion_scale(1.0)
	for index in 200:
		effects.emit_swallow(
			Vector2(index, index),
			Color("72dc78"),
			index % 5 == 0
		)
	var actual_random := randf()
	_check(
		is_equal_approx(actual_random, expected_random),
		"Visual effects do not consume the gameplay random-number stream."
	)
	_check(
		effects.active_effect_count() <= FeelEffects.MAX_EFFECTS,
		"World feedback respects its active-effect cap."
	)
	effects._process(2.0)
	_check(
		effects.active_effect_count() == 0 and not effects.is_processing(),
		"Expired world feedback releases all active processing."
	)
	effects.set_motion_scale(0.0)
	effects.emit_growth(Vector2.ZERO)
	_check(
		effects.active_effect_count() == 1,
		"Reduced motion preserves non-gameplay growth information."
	)
	effects.queue_free()
	await process_frame


func _contains_collision_object(node: Node) -> bool:
	if node is CollisionObject2D:
		return true
	for child in node.get_children():
		if _contains_collision_object(child):
			return true
	return false


func _all_interactive_controls_at_least(
	node: Node,
	minimum_height: float
) -> bool:
	if (
		(node is BaseButton or node is LineEdit or node is Slider)
		and (node as Control).custom_minimum_size.y < minimum_height
	):
		return false
	for child in node.get_children():
		if not _all_interactive_controls_at_least(child, minimum_height):
			return false
	return true


func _controls_overlap(controls: Array[Control]) -> bool:
	for first_index in controls.size():
		for second_index in range(first_index + 1, controls.size()):
			if (
				controls[first_index].get_global_rect().intersection(
					controls[second_index].get_global_rect()
				).has_area()
			):
				return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _find_target(game: FrogGame, target_id: String) -> EdibleTarget:
	for target in game._targets:
		if target.target_id == target_id:
			return target
	return null


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


func _finish() -> void:
	paused = false
	AudioDirector.reset_for_tests()
	await create_timer(0.2).timeout
	AudioDirector.shutdown_for_tests()
	for _frame in 2:
		await process_frame
	if _failures.is_empty():
		print("Prototype smoke tests passed.")
		quit(0)
	else:
		print("Prototype smoke tests failed: %s" % ", ".join(_failures))
		quit(1)
