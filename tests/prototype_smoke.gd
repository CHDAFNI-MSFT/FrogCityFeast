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
		game._targets.size() == 36,
		"Prototype targets, connected spaces, and all four destruction sequences are created."
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
	_check(game._growth_tier == 2, "Digesting enough value reaches the large growth tier.")
	_check(game._frog.growth_tier == 2, "Frog presentation and abilities receive the growth tier.")
	if not game._power_state.is_active(TemporaryPowerState.FLIGHT):
		var cake := _find_target(game, "golden_cake")
		_check(cake != null, "The rare golden cake remains available for its flight test.")
		if cake != null:
			game._swallow_target(cake, 1.0)
			game._digest_item(0)
	_check(
		game._power_state.is_active(TemporaryPowerState.FLIGHT),
		"Digesting the rare golden cake activates flight."
	)
	_check(game._frog.is_flying, "Flight changes the frog's movement state.")

	var vehicle: EdibleTarget
	for target in game._targets:
		if target.target_id == "delivery_van":
			vehicle = target
			break
	_check(vehicle != null, "The traffic target exists.")
	if vehicle != null:
		_check(vehicle.can_be_swallowed(game._growth_tier), "Traffic becomes edible at large growth.")

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
	await physics_frame
	await process_frame
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
	await physics_frame
	await process_frame
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
	await _test_oddities_shop_hours(game_scene)
	await _test_moonlight_market_hours(game_scene)
	await _test_oddities_cellar(game_scene)
	await _test_leap_cafe_sequence(game_scene)
	await _test_canal_apartments_sequence(game_scene)
	await _test_building_interiors(game_scene)
	await _test_market_rooftop(game_scene)
	await _test_canal_upper_hall(game_scene)
	await _test_canal_fire_escape(game_scene)
	await _test_river_sewer_chain(game_scene)
	await _test_hidden_sewer_maintenance(game_scene)
	await _test_river_pond_boardwalk(game_scene)
	await _test_construction_crane(game_scene)
	await _test_cafe_stockroom(game_scene)
	await _test_city_activity(game_scene)
	await _test_crowd_pursuit_escape(game_scene)
	await _test_pursuer_tongue_deflection(game_scene)
	await _test_security_guard_pursuer(game_scene)
	await _test_watchdog_pursuer(game_scene)
	await _test_pursuer_roadblock(game_scene)
	await _test_city_detour(game_scene)
	await _test_pursuer_snare(game_scene)
	await _test_pursuer_net_escape(game_scene)
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
	store.set_accessibility_preferences(first_profile, {
		"reduce_motion": true,
		"larger_text_controls": false,
	})
	store.set_accessibility_preferences(second_profile, {
		"reduce_motion": false,
		"larger_text_controls": true,
	})
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
			"input_assist_mode": "standard",
			"camera_sensitivity": 1.0,
			"camera_auto_align": false,
			"haptics_enabled": false,
			"left_handed_hud": false,
		}
		and reloaded_store.get_accessibility_preferences(second_profile) == {
			"reduce_motion": false,
			"larger_text_controls": true,
			"input_assist_mode": "standard",
			"camera_sensitivity": 1.0,
			"camera_auto_align": false,
			"haptics_enabled": false,
			"left_handed_hud": false,
		},
		"Accessibility preferences survive reload and remain profile-specific."
	)
	_check(
		reloaded_store.is_tutorial_complete(first_profile)
		and ProfileStore.SAVE_VERSION == 3,
		"Discovery persistence preserves tutorial state in save version 3."
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
		menu._guide_label.text.begins_with(one_discovery_text)
		and menu._guide_label.text.contains(
			"Profile: 0 / %d achievements"
			% ProgressionCatalog.profile_achievement_ids().size()
		)
		and menu._guide_label.text.contains(
			"Device: 0 / %d milestones"
			% ProgressionCatalog.device_achievement_ids().size()
		),
		"Main menu separates Field Guide, profile, and device progress."
	)
	_check(
		menu._reduce_motion_toggle.button_pressed
		and not menu._larger_ui_toggle.button_pressed,
		"Main menu loads accessibility choices for the selected profile."
	)
	menu._on_new_name_changed("frog one")
	_check(
		menu._guide_label.text.begins_with(one_discovery_text)
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
	menu.start_requested.connect(func(
		profile_id: String,
		_name: String,
		_force_tutorial: bool
	) -> void:
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
			"input_assist_mode": "standard",
			"camera_sensitivity": 1.0,
			"camera_auto_align": false,
			"haptics_enabled": false,
			"left_handed_hud": false,
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
			"input_assist_mode": "standard",
			"camera_sensitivity": 1.0,
			"camera_auto_align": false,
			"haptics_enabled": false,
			"left_handed_hud": false,
		},
		"Version 1 saves use deterministic defaults for missing or malformed optional data."
	)
	for file_name in DirAccess.get_files_at("user://"):
		if str(file_name).begins_with(
			"prototype_legacy_scores.cfg.migration-v1-to-v2-"
		):
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path("user://%s" % file_name)
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
		backup_found
		and not unsupported_store.list_profiles().is_empty()
		and unsupported_store.last_save_error().contains(
			"unsupported version"
		),
		"Unsupported saves are preserved and expose a player-facing warning."
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
		unreadable_backup_found
		and not unreadable_store.list_profiles().is_empty()
		and unreadable_store.last_save_error().contains(
			"could not be read"
		),
		"Unreadable saves are preserved and expose a player-facing warning."
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
		and not failing_store.last_save_error().is_empty()
		and FileAccess.get_file_as_string(preservation_path) == original_save_text,
		"A failed backup disables saves, warns the player, and preserves the file."
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
			"input_assist_mode": "standard",
			"camera_sensitivity": 1.0,
			"camera_auto_align": false,
			"haptics_enabled": false,
			"left_handed_hud": false,
		},
		"Accessibility settings reject malformed values and use safe defaults."
	)
	_check(
		AccessibilityPresentation.sanitize_preferences({
			"input_assist_mode": "hold",
			"camera_sensitivity": 2.0,
			"camera_auto_align": true,
			"haptics_enabled": true,
			"left_handed_hud": true,
		}) == {
			"reduce_motion": false,
			"larger_text_controls": false,
			"input_assist_mode": "hold",
			"camera_sensitivity": 1.5,
			"camera_auto_align": true,
			"haptics_enabled": true,
			"left_handed_hud": true,
		}
		and AccessibilityPresentation.assisted_struggle_taps(10, "relaxed")
		== 8
		and AccessibilityPresentation.assisted_struggle_taps(10, "hold")
		== 8,
		"Input, camera, haptic, and handedness settings sanitize deterministically."
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
	game.show_save_error("Progress could not be saved.")
	_check(
		is_instance_valid(game._save_warning_panel)
		and game._save_warning_label.text.contains("SAVE WARNING"),
		"Gameplay surfaces save failures in a dedicated readable warning."
	)
	game._show_status("Digested Street Donut for 12 points!")
	await process_frame
	_check(
		game._save_warning_label.text.contains("SAVE WARNING")
		and game._status_label.text.contains("Digested Street Donut"),
		"Gameplay feedback cannot overwrite the persistent save warning."
	)
	game._open_options()
	_check(
		game._options_overlay.visible
		and not game._save_warning_panel.visible
		and game._options_summary.text.contains("SAVE WARNING"),
		"Paused Options surfaces the warning without a floating modal overlap."
	)
	game._close_options()
	_check(
		game._save_warning_panel.visible,
		"Closing Options restores the dedicated gameplay warning."
	)
	game._open_belly()
	_check(
		game._belly_overlay.visible
		and not game._save_warning_panel.visible,
		"The Belly hides the floating warning instead of covering its summary."
	)
	game._close_belly()
	game._open_guide()
	_check(
		game._guide_overlay.visible
		and not game._save_warning_panel.visible,
		"The Guide hides the floating warning instead of covering its progress."
	)
	game._close_guide()
	_check(
		game._save_warning_panel.visible,
		"Closing paused overlays restores the dedicated gameplay warning."
	)
	game.show_save_error("")
	await process_frame
	_check(
		not is_instance_valid(game._save_warning_panel),
		"A successful save clears the gameplay warning."
	)
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
		func(preferences: Dictionary) -> void:
			accessibility_events.append(preferences)
	)
	game._refreshing_accessibility_controls = true
	game._reduce_motion_toggle.button_pressed = true
	game._larger_ui_toggle.button_pressed = true
	game._select_input_assist_mode("hold")
	game._camera_sensitivity_slider.value = 135.0
	game._camera_auto_align_toggle.button_pressed = true
	game._haptics_toggle.button_pressed = true
	game._left_handed_toggle.button_pressed = true
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
			"input_assist_mode": "hold",
			"camera_sensitivity": 1.35,
			"camera_auto_align": true,
			"haptics_enabled": true,
			"left_handed_hud": true,
		}],
		"Accessibility changes apply together and emit one exact save event."
	)
	var rotation_before_sensitivity := game._camera.rotation
	game._rotate_camera(10.0)
	var high_sensitivity_delta := absf(
		game._camera.rotation - rotation_before_sensitivity
	)
	game._camera.rotation = 1.0
	game._city_camera_rotation = 1.0
	game._camera_manual_override_time = 0.0
	game._frog.velocity = Vector2.UP * 100.0
	game._update_camera_assistance(0.25)
	_check(
		is_equal_approx(high_sensitivity_delta, 0.081)
		and game._camera.rotation < 1.0
		and game._top_bar.get_child(0) == game._guide_button,
		"Camera sensitivity, delayed auto-align, and left-handed HUD apply immediately."
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
	game._power_state.activate(TemporaryPowerState.FLIGHT)
	game._start_flight()
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
		and game._control_legend.get_global_rect().position.x
		< safe_rect.get_center().x
		and game._profile_label.get_global_rect().position.x >= safe_rect.position.x
		and game._end_button.get_global_rect().end.x <= safe_rect.end.x,
		"Large left-handed top bar and control legend fit the inset safe area."
	)

	var pulsing_target_screen := (
		game.get_viewport().get_canvas_transform()
		* pulsing_target.global_position
	)
	game._input_assist_mode = AccessibilityPresentation.INPUT_ASSIST_RELAXED
	var relaxed_target := _find_target(game, "market_apple")
	var relaxed_target_screen := (
		game.get_viewport().get_canvas_transform()
		* relaxed_target.global_position
	)
	var relaxed_click := InputEventMouseButton.new()
	relaxed_click.button_index = MOUSE_BUTTON_LEFT
	relaxed_click.pressed = true
	relaxed_click.position = relaxed_target_screen
	game._ignore_mouse_until_msec = 0
	game._tongue_recovery = 0.0
	game._handle_mouse_button(relaxed_click)
	var relaxed_second_click := InputEventMouseButton.new()
	relaxed_second_click.button_index = MOUSE_BUTTON_LEFT
	relaxed_second_click.pressed = true
	relaxed_second_click.position = relaxed_target_screen
	game._handle_mouse_button(relaxed_second_click)
	_check(
		game._last_assisted_tap_msec == -1000
		and game._last_assisted_tap_position == Vector2.INF,
		"Relaxed timing uses its wider activation window for mouse controls."
	)
	game._input_assist_mode = AccessibilityPresentation.INPUT_ASSIST_HOLD
	game._begin_struggle(pulsing_target, 0.8, Vector2.ZERO)
	var expected_assisted_taps := (
		AccessibilityPresentation.assisted_struggle_taps(
			GameplayTuning.struggle_taps_required(
				pulsing_target.taps_required,
				pulsing_target.size_tier,
				game._growth_tier
			),
			AccessibilityPresentation.INPUT_ASSIST_HOLD
		)
	)
	var struggle_taps_before_hold := game._struggle_taps
	game._begin_assisted_hold(11)
	var unrelated_release := InputEventScreenTouch.new()
	unrelated_release.index = 12
	unrelated_release.pressed = false
	unrelated_release.position = pulsing_target_screen
	game._handle_screen_touch(unrelated_release)
	game._update_input_assistance(
		AccessibilityPresentation.HOLD_REPEAT_INTERVAL
	)
	_check(
		game._struggle_required_taps == expected_assisted_taps
		and game._struggle_taps == struggle_taps_before_hold + 1
		and game._assist_hold_pointer_id == 11,
		"Hold assistance keeps its owner through unrelated touch releases."
	)
	var struggle_time := game._struggle_time_left
	game.show_save_error(
		"Progress saving is unavailable because the previous save "
		+ "could not be preserved."
	)
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
		safe_rect.encloses(options_panel.get_global_rect())
		and game._options_summary.text.contains("SAVE WARNING")
		and game._options_summary.autowrap_mode
		== TextServer.AUTOWRAP_WORD_SMART
		and not game._save_warning_panel.visible,
		(
			"Long save warnings keep enlarged Options inside the inset safe area: "
			+ "panel %s in %s, summary %s, wrap %d, banner visible %s."
		) % [
			options_panel.get_global_rect(),
			safe_rect,
			game._options_summary.get_global_rect(),
			game._options_summary.autowrap_mode,
			game._save_warning_panel.visible,
		]
	)
	game._select_input_assist_mode(
		AccessibilityPresentation.INPUT_ASSIST_STANDARD
	)
	game._on_accessibility_option_selected(0)
	_check(
		game._struggle_required_taps
		== GameplayTuning.struggle_taps_required(
			pulsing_target.taps_required,
			pulsing_target.size_tier,
			game._growth_tier
		)
		and game._struggle_hint.text == FrogGame.TARGET_STRUGGLE_HINT,
		"Changing timing mode during a struggle refreshes its demand and hint."
	)
	game._close_options()
	_check(
		not paused
		and game._struggle_target == pulsing_target
		and game._save_warning_panel.visible,
		"Closing Accessibility resumes the exact in-progress gameplay state."
	)
	game.show_save_error("")
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
	menu_store.set_accessibility_preferences(menu_profile, {
		"reduce_motion": true,
		"larger_text_controls": true,
		"input_assist_mode": "relaxed",
		"camera_sensitivity": 0.75,
		"camera_auto_align": true,
		"haptics_enabled": true,
		"left_handed_hud": true,
	})
	var menu := (
		load("res://scenes/menu.tscn") as PackedScene
	).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	menu.configure(menu_store, 0)
	menu.apply_safe_area_insets(safe_insets)
	menu.show_save_error("Progress could not be saved.")
	await process_frame
	var menu_panel := menu.get_node("Center/Panel") as Control
	_check(
		menu._reduce_motion_toggle.button_pressed
		and menu._larger_ui_toggle.button_pressed
		and str(
			menu._input_assist_option.get_item_metadata(
				menu._input_assist_option.selected
			)
		) == "relaxed"
		and is_equal_approx(menu._camera_sensitivity_slider.value, 75.0)
		and menu._camera_auto_align_toggle.button_pressed
		and menu._haptics_toggle.button_pressed
		and menu._left_handed_toggle.button_pressed,
		"Menu loads every saved accessibility choice."
	)
	_check(
		menu._save_warning.visible
		and menu._save_warning_label.text.contains("SAVE WARNING"),
		"The title screen surfaces save failures without hiding profile controls."
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
		(
			"Menu large mode fits the inset 1280x960 safe area: %s in %s; "
			+ "profile %s, accessibility %s, audio %s."
		) % [
			menu_panel.get_global_rect(),
			safe_rect,
			(menu.get_node(
				"Center/Panel/Margin/Content/Columns/ProfileColumn"
			) as Control).size,
			(menu.get_node(
				"Center/Panel/Margin/Content/Columns/AccessibilityColumn"
			) as Control).size,
			(menu.get_node(
				"Center/Panel/Margin/Content/Columns/AudioColumn"
			) as Control).size,
		]
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
		func(
			profile_id: String,
			_name: String,
			_force_tutorial: bool
		) -> void:
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
			"input_assist_mode": "relaxed",
			"camera_sensitivity": 0.75,
			"camera_auto_align": true,
			"haptics_enabled": true,
			"left_handed_hud": true,
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
	game._power_state.activate(TemporaryPowerState.FLIGHT)
	game._start_flight()
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
		"City activity, the park meetup, rain, and the night bazaar share one draw-only layer."
	)
	_check(
		game._targets.size() == 36
			and DiscoveryCatalog.count()
			== 39 + DistrictGenerator.discovery_ids().size(),
		"Ambient city life adds no targets; procedural discoveries stay finitely cataloged."
	)
	var expected_daylight := (
		sin(game._day_clock * TAU - PI / 2.0) + 1.0
	) * 0.5
	_check(
		is_equal_approx(activity.daylight, expected_daylight),
		"The game forwards its initial day-night value to city activity."
	)
	_check(
		is_equal_approx(
			activity.crowd_intensity,
			FrogGame.crowd_intensity_for_clock(game._day_clock)
		),
		"The game forwards the initial meetup intensity to city activity."
	)
	_check(
		is_equal_approx(
			activity.wind_intensity,
			FrogGame.wind_squall_intensity_for_clock(game._day_clock)
		),
		"The game forwards the initial wind-squall intensity to city activity."
	)
	_check(
		is_equal_approx(
			activity.festival_intensity,
			FrogGame.festival_intensity_for_clock(game._day_clock)
		),
		"The game forwards the initial night-bazaar intensity to city activity."
	)
	_check(
		is_equal_approx(
			activity.kite_festival_intensity,
			FrogGame.kite_festival_intensity_for_clock(game._day_clock)
		),
		"The game forwards the initial kite-festival intensity to city activity."
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
	_check(
		is_zero_approx(
			FrogGame.wind_squall_intensity_for_clock(0.29)
		)
		and is_zero_approx(
			FrogGame.wind_squall_intensity_for_clock(0.30)
		)
		and is_equal_approx(
			FrogGame.wind_squall_intensity_for_clock(0.32),
			0.5
		)
		and is_equal_approx(
			FrogGame.wind_squall_intensity_for_clock(0.34),
			1.0
		)
		and is_equal_approx(
			FrogGame.wind_squall_intensity_for_clock(0.42),
			1.0
		)
		and is_equal_approx(
			FrogGame.wind_squall_intensity_for_clock(0.44),
			0.5
		)
		and is_zero_approx(
			FrogGame.wind_squall_intensity_for_clock(0.46)
		)
		and is_equal_approx(
			FrogGame.wind_squall_intensity_for_clock(1.32),
			0.5
		),
		"The wind squall follows one bounded deterministic daytime window with smooth fades."
	)
	_check(
		is_zero_approx(
			FrogGame.kite_festival_intensity_for_clock(0.45)
		)
		and is_zero_approx(
			FrogGame.kite_festival_intensity_for_clock(0.46)
		)
		and is_equal_approx(
			FrogGame.kite_festival_intensity_for_clock(0.47),
			0.5
		)
		and is_equal_approx(
			FrogGame.kite_festival_intensity_for_clock(0.48),
			1.0
		)
		and is_equal_approx(
			FrogGame.kite_festival_intensity_for_clock(0.54),
			1.0
		)
		and is_equal_approx(
			FrogGame.kite_festival_intensity_for_clock(0.55),
			0.5
		)
		and is_zero_approx(
			FrogGame.kite_festival_intensity_for_clock(0.56)
		)
		and is_equal_approx(
			FrogGame.kite_festival_intensity_for_clock(1.47),
			0.5
		),
		"The Canal Kite Festival follows one bounded deterministic daytime window with smooth fades."
	)
	_check(
		is_zero_approx(FrogGame.crowd_intensity_for_clock(0.17))
		and is_zero_approx(
			FrogGame.crowd_intensity_for_clock(0.18)
		)
		and is_equal_approx(
			FrogGame.crowd_intensity_for_clock(0.20),
			0.5
		)
		and is_equal_approx(
			FrogGame.crowd_intensity_for_clock(0.22),
			1.0
		)
		and is_equal_approx(
			FrogGame.crowd_intensity_for_clock(0.50),
			1.0
		)
		and is_equal_approx(
			FrogGame.crowd_intensity_for_clock(0.53),
			0.5
		)
		and is_zero_approx(
			FrogGame.crowd_intensity_for_clock(0.56)
		)
		and is_equal_approx(
			FrogGame.crowd_intensity_for_clock(1.20),
			0.5
		)
		and is_zero_approx(FrogGame.rain_intensity_for_clock(0.56)),
		"The River Park meetup has deterministic fades and disperses before rain."
	)
	_check(
		is_zero_approx(FrogGame.festival_intensity_for_clock(0.77))
		and is_zero_approx(
			FrogGame.festival_intensity_for_clock(0.78)
		)
		and is_equal_approx(
			FrogGame.festival_intensity_for_clock(0.80),
			0.5
		)
		and is_equal_approx(
			FrogGame.festival_intensity_for_clock(0.82),
			1.0
		)
		and is_equal_approx(
			FrogGame.festival_intensity_for_clock(0.12),
			1.0
		)
		and is_equal_approx(
			FrogGame.festival_intensity_for_clock(0.14),
			0.5
		)
		and is_zero_approx(
			FrogGame.festival_intensity_for_clock(0.16)
		)
		and is_equal_approx(
			FrogGame.festival_intensity_for_clock(1.80),
			0.5
		),
		"The Moonlight Market bazaar follows one wrapped deterministic night window with smooth fades."
	)
	_check(
		is_zero_approx(FrogGame.wind_squall_intensity_for_clock(0.46))
			and is_zero_approx(
				FrogGame.kite_festival_intensity_for_clock(0.46)
			)
			and is_zero_approx(
				FrogGame.kite_festival_intensity_for_clock(0.56)
			)
			and is_zero_approx(FrogGame.crowd_intensity_for_clock(0.56))
			and not FrogGame.moonlight_market_open_for_clock(0.58)
			and is_zero_approx(FrogGame.rain_intensity_for_clock(0.58))
			and not FrogGame.city_detour_active_for_clock(0.58)
			and is_equal_approx(
				FrogGame.rain_intensity_for_clock(0.62),
				1.0
			)
			and FrogGame.city_detour_active_for_clock(0.62)
			and is_equal_approx(
				FrogGame.rain_intensity_for_clock(0.74),
				1.0
			)
			and not FrogGame.city_detour_active_for_clock(0.74)
			and is_zero_approx(FrogGame.rain_intensity_for_clock(0.78))
			and FrogGame.oddities_shop_open_for_clock(0.78)
			and is_zero_approx(
				FrogGame.festival_intensity_for_clock(0.78)
			),
		"Shared dynamic-city boundaries preserve every schedule handoff without overlap or drift."
	)

	game._day_clock = 0.5
	game._update_day_night(0.0)
	var day_pedestrians := activity.active_pedestrian_count()
	var day_vehicles := activity.active_vehicle_count()
	var day_crowd_members := activity.active_crowd_member_count()
	var day_lights := activity.streetlight_intensity()
	var day_lanterns := activity.visible_festival_lantern_count()
	var day_kites := activity.visible_kite_festival_count()
	game._day_clock = 0.0
	game._update_day_night(0.0)
	var night_pedestrians := activity.active_pedestrian_count()
	var night_vehicles := activity.active_vehicle_count()
	var night_crowd_members := activity.active_crowd_member_count()
	var night_lights := activity.streetlight_intensity()
	var night_lanterns := activity.visible_festival_lantern_count()
	var night_kites := activity.visible_kite_festival_count()
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
		day_crowd_members == CityActivity.CROWD_MEMBER_OFFSETS.size()
		and night_crowd_members == 0
		and activity.crowd_cover_contains(CityActivity.CROWD_CENTER)
		== false,
		"The River Park meetup gathers only during its authored daytime window."
	)
	_check(
		is_zero_approx(day_lights) and night_lights > 0.99,
		"Streetlights switch on at night without changing the world tint."
	)
	_check(
		day_lanterns == 0
		and night_lanterns
		== CityActivity.FESTIVAL_LANTERN_OFFSETS.size()
		and is_equal_approx(activity.festival_intensity, 1.0),
		"The fixed Moonlight Market lantern set appears only during the night bazaar."
	)
	_check(
		day_kites == CityActivity.KITE_FESTIVAL_OFFSETS.size()
		and night_kites == 0,
		"The Canal Kite Festival is distinct from the Moonlight Market night bazaar."
	)
	game._day_clock = 0.68
	game._update_day_night(0.0)
	var rainy_snapshot := game.performance_structure_snapshot()
	_check(
		is_equal_approx(activity.rain_intensity, 1.0)
		and activity.active_pedestrian_count() == 4
		and activity.active_vehicle_count() == 3
		and activity.active_crowd_member_count() == 0
		and activity.visible_festival_lantern_count() == 0
		and activity.visible_kite_festival_count() == 0
		and activity.visible_rain_streak_count()
		== CityActivity.RAIN_STREAK_COUNT,
		"Peak rain reduces the decorative crowd and traffic while retaining a bounded visual shower."
	)
	_check(
		int(rainy_snapshot["targets"]) == 36
		and int(rainy_snapshot["buildings"]) == 4
		and int(rainy_snapshot["collision_objects"]) == 41
		and int(rainy_snapshot["collision_shapes"]) == 111,
		"Rain does not add targets, buildings, or collision objects."
	)
	var score_before_wind := game._score
	var growth_before_wind := game._growth_points
	var belly_before_wind := game._belly.size()
	var discoveries_before_wind := game._known_discovery_count()
	var challenge_progress_before_wind := [
		game._challenges.progress(SessionChallenges.SHARP_AIM),
		game._challenges.progress(SessionChallenges.HOLD_ON),
		game._challenges.progress(SessionChallenges.CITY_TOUR),
		game._challenges.completed_count(),
	]
	game._day_clock = 0.38
	game._update_day_night(0.0)
	var wind_snapshot := game.performance_structure_snapshot()
	_check(
		is_equal_approx(activity.wind_intensity, 1.0)
		and is_zero_approx(activity.rain_intensity)
		and activity.active_pedestrian_count()
		== CityActivity.PEDESTRIAN_ROUTES.size()
		and activity.active_vehicle_count()
		== CityActivity.VEHICLE_ROUTES.size()
		and activity.active_crowd_member_count()
		== CityActivity.CROWD_MEMBER_OFFSETS.size()
		and activity.visible_wind_ribbon_count()
		== CityActivity.WIND_RIBBON_COUNT
		and activity.visible_kite_festival_count() == 0
		and int(wind_snapshot["targets"]) == 36
		and int(wind_snapshot["buildings"]) == 4
		and int(wind_snapshot["collision_objects"]) == 41
		and int(wind_snapshot["collision_shapes"]) == 111,
		"Peak wind overlaps full daytime activity with one bounded draw-only ribbon set."
	)
	_check(
		game._score == score_before_wind
		and game._growth_points == growth_before_wind
		and game._belly.size() == belly_before_wind
		and game._known_discovery_count() == discoveries_before_wind
		and challenge_progress_before_wind == [
			game._challenges.progress(SessionChallenges.SHARP_AIM),
			game._challenges.progress(SessionChallenges.HOLD_ON),
			game._challenges.progress(SessionChallenges.CITY_TOUR),
			game._challenges.completed_count(),
		],
		"Wind event boundaries do not change score, growth, Belly, discoveries, or challenges."
	)
	game._day_clock = 0.5
	game._update_day_night(0.0)
	var kite_snapshot := game.performance_structure_snapshot()
	_check(
		is_equal_approx(activity.kite_festival_intensity, 1.0)
		and activity.visible_kite_festival_count()
		== CityActivity.KITE_FESTIVAL_OFFSETS.size()
		and is_zero_approx(activity.wind_intensity)
		and is_zero_approx(activity.rain_intensity)
		and int(kite_snapshot["targets"]) == 36
		and int(kite_snapshot["buildings"]) == 4
		and int(kite_snapshot["collision_objects"]) == 41
		and int(kite_snapshot["collision_shapes"]) == 111
		and game._score == score_before_wind
		and game._growth_points == growth_before_wind
		and game._belly.size() == belly_before_wind
		and game._known_discovery_count() == discoveries_before_wind
		and challenge_progress_before_wind == [
			game._challenges.progress(SessionChallenges.SHARP_AIM),
			game._challenges.progress(SessionChallenges.HOLD_ON),
			game._challenges.progress(SessionChallenges.CITY_TOUR),
			game._challenges.completed_count(),
		],
		"The kite festival adds no gameplay structure or progression side effects."
	)

	var single_step := CityActivity.new()
	var many_steps := CityActivity.new()
	single_step.set_motion_scale(1.0)
	many_steps.set_motion_scale(1.0)
	single_step.set_rain_intensity(1.0)
	many_steps.set_rain_intensity(1.0)
	single_step.set_wind_intensity(1.0)
	many_steps.set_wind_intensity(1.0)
	single_step.set_festival_intensity(1.0)
	many_steps.set_festival_intensity(1.0)
	single_step.set_kite_festival_intensity(1.0)
	many_steps.set_kite_festival_intensity(1.0)
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
	var single_wind_signature := single_step.wind_signature()
	var many_wind_signature := many_steps.wind_signature()
	for index in single_wind_signature.size():
		if (
			single_wind_signature[index].distance_to(
				many_wind_signature[index]
			)
			> 0.001
		):
			deterministic_positions = false
			break
	var single_kite_signature := single_step.kite_festival_signature()
	var many_kite_signature := many_steps.kite_festival_signature()
	for index in single_kite_signature.size():
		if (
			single_kite_signature[index].distance_to(
				many_kite_signature[index]
			)
			> 0.001
		):
			deterministic_positions = false
			break
	_check(
		deterministic_positions,
		"City actors, weather, and festivals depend on absolute deterministic time, not frame size."
	)

	var frozen_position := single_step.pedestrian_position(0)
	var frozen_rain := single_step.rain_signature()
	var frozen_wind := single_step.wind_signature()
	var frozen_festival := single_step.festival_signature()
	var frozen_kites := single_step.kite_festival_signature()
	single_step.set_crowd_intensity(1.0)
	var frozen_crowd_member := single_step.crowd_member_position(0)
	single_step.set_motion_scale(0.0)
	single_step._advance_animation(8.0)
	single_step.set_daylight(0.0)
	_check(
		single_step.pedestrian_position(0) == frozen_position
		and single_step.rain_signature() == frozen_rain
		and single_step.wind_signature() == frozen_wind
		and single_step.festival_signature() == frozen_festival
		and single_step.kite_festival_signature() == frozen_kites
		and single_step.crowd_member_position(0) == frozen_crowd_member
		and single_step.active_pedestrian_count() == 4
		and single_step.active_vehicle_count() == 2
		and single_step.visible_rain_streak_count()
		== CityActivity.RAIN_STREAK_COUNT
		and single_step.visible_wind_ribbon_count()
		== CityActivity.WIND_RIBBON_COUNT
		and single_step.visible_festival_lantern_count()
		== CityActivity.FESTIVAL_LANTERN_OFFSETS.size()
		and single_step.visible_kite_festival_count()
		== CityActivity.KITE_FESTIVAL_OFFSETS.size()
		and single_step.streetlight_intensity() > 0.99,
		"Reduced motion freezes actors, weather, lanterns, and kites while event timing and lighting still update."
	)
	seed(20260830)
	var expected_random := randf()
	seed(20260830)
	single_step.set_rain_intensity(0.5)
	single_step.set_wind_intensity(0.5)
	single_step.set_crowd_intensity(0.5)
	single_step.set_festival_intensity(0.5)
	single_step.set_kite_festival_intensity(0.5)
	single_step.rain_signature()
	single_step.wind_signature()
	single_step.festival_signature()
	single_step.kite_festival_signature()
	single_step.activity_signature()
	var actual_random := randf()
	_check(
		is_equal_approx(actual_random, expected_random),
		"Weather and festival presentation do not consume the gameplay random-number stream."
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
	for index in CityActivity.WIND_RIBBON_COUNT:
		if (
			single_step.wind_ribbon_position_at(index, 17.25)
			.distance_to(
				single_step.wind_ribbon_position_at(
					index,
					17.25 + CityActivity.WIND_LOOP_DURATION
				)
			)
			> 0.001
		):
			loop_is_seamless = false
	for index in CityActivity.CROWD_MEMBER_OFFSETS.size():
		if (
			single_step.crowd_member_position(index)
			.distance_to(
				many_steps.crowd_member_position(index)
			)
			> 0.001
		):
			loop_is_seamless = false
	for index in CityActivity.FESTIVAL_LANTERN_OFFSETS.size():
		if (
			single_step.festival_lantern_position_at(index, 17.25)
			.distance_to(
				single_step.festival_lantern_position_at(
					index,
					17.25 + CityActivity.LOOP_DURATION
				)
			)
			> 0.001
		):
			loop_is_seamless = false
	for index in CityActivity.KITE_FESTIVAL_OFFSETS.size():
		if (
			single_step.kite_festival_position_at(index, 17.25)
			.distance_to(
				single_step.kite_festival_position_at(
					index,
					17.25 + CityActivity.LOOP_DURATION
				)
			)
			> 0.001
		):
			loop_is_seamless = false
	_check(
		loop_is_seamless,
		"Every authored activity route, weather mark, and lantern loops seamlessly."
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
	game.set_motion_scale(0.0)
	game._day_clock = 0.38
	game._update_day_night(0.0)
	var city_activity_instance_id := activity.get_instance_id()
	var cafe := (
		game._building_by_id.get("leap_cafe") as PrototypeBuilding
	)
	game._frog.global_position = cafe.transition_door_approach_position()
	game._begin_interior_transition(FrogGame.STOCKROOM_ID)
	var wind_survived_room_entry := (
		game._active_interior_id == FrogGame.STOCKROOM_ID
		and game._city_activity.get_instance_id()
		== city_activity_instance_id
		and game._city_activity.visible_wind_ribbon_count()
		== CityActivity.WIND_RIBBON_COUNT
	)
	game._begin_interior_transition("city")
	game._day_clock = 0.5
	game._update_day_night(0.0)
	var kites_survived_room_exit := (
		game._city_activity.visible_kite_festival_count()
		== CityActivity.KITE_FESTIVAL_OFFSETS.size()
	)
	game._frog.global_position = DistrictGenerator.bounds_for_coordinate(
		Vector2i(2, 2)
	).get_center()
	game._update_district_streaming()
	_check(
		wind_survived_room_entry
		and kites_survived_room_exit
		and game._active_interior_id.is_empty()
		and game._city_activity.get_instance_id()
		== city_activity_instance_id
		and game.find_children("*", "CityActivity", true, false).size()
		== 1
		and game._city_activity.visible_wind_ribbon_count()
		== 0
		and game._city_activity.visible_kite_festival_count()
		== CityActivity.KITE_FESTIVAL_OFFSETS.size(),
		"Room travel and district streaming retain one global weather-and-festival layer without duplication."
	)

	single_step.free()
	many_steps.free()
	game.queue_free()
	await process_frame


func _test_crowd_pursuit_escape(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("crowd_escape_test", "Crowd Escape Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	game._day_clock = 0.5
	game._update_day_night(0.0)
	game._frog.global_position = CityActivity.CROWD_CENTER
	game._spawn_pursuer()
	var pursuer := game._pursuer
	_check(
		is_instance_valid(pursuer)
		and game._city_activity.crowd_cover_available()
		and game._city_activity.active_crowd_member_count() == 5
		and game._circle_position_clear(
			CityActivity.CROWD_CENTER,
			44.0,
			true
		),
		"The daytime River Park meetup provides collision-free crowd cover."
	)
	if not is_instance_valid(pursuer):
		game.queue_free()
		await process_frame
		return
	pursuer.set_physics_process(false)

	var score_before := game._score
	var growth_before := game._growth_points
	var targets_before := game._targets.size()
	var discoveries_before := game._known_discovery_count()
	game._update_crowd_hiding(FrogGame.CROWD_HIDE_DURATION * 0.5)
	_check(
		is_instance_valid(game._pursuer)
		and is_equal_approx(
			game._crowd_hide_time,
			FrogGame.CROWD_HIDE_DURATION * 0.5
		)
		and is_equal_approx(
			game._city_activity.crowd_hide_progress,
			0.5
		)
		and game._city_activity.crowd_cover_chase_active,
		"Staying inside the meetup advances visible pursuit-cover progress."
	)

	game._frog.global_position = (
		CityActivity.CROWD_CENTER
		+ Vector2.RIGHT * (CityActivity.CROWD_COVER_RADIUS + 1.0)
	)
	game._update_crowd_hiding(0.1)
	_check(
		is_zero_approx(game._crowd_hide_time)
		and is_zero_approx(
			game._city_activity.crowd_hide_progress
		)
		and game._city_activity.crowd_cover_chase_active,
		"Leaving the meetup resets progress while keeping the cover cue visible."
	)

	game._frog.global_position = CityActivity.CROWD_CENTER
	game._growth_tier = 2
	game._frog.set_growth_tier(2)
	game._update_crowd_hiding(FrogGame.CROWD_HIDE_DURATION)
	var large_growth_blocked := is_zero_approx(game._crowd_hide_time)
	game._growth_tier = 0
	game._frog.set_growth_tier(0)
	game._frog.set_flying(true)
	game._update_crowd_hiding(FrogGame.CROWD_HIDE_DURATION)
	var flight_blocked := is_zero_approx(game._crowd_hide_time)
	game._frog.set_flying(false)
	game._frog.knock_back_from(pursuer.global_position)
	game._update_crowd_hiding(FrogGame.CROWD_HIDE_DURATION)
	var knockback_blocked := is_zero_approx(game._crowd_hide_time)
	game._frog.clear_knockback()
	game._net_escape_active = true
	game._update_crowd_hiding(FrogGame.CROWD_HIDE_DURATION)
	var net_blocked := is_zero_approx(game._crowd_hide_time)
	game._net_escape_active = false
	var blocker_target := _find_target(game, "street_donut")
	game._struggle_target = blocker_target
	game._update_crowd_hiding(FrogGame.CROWD_HIDE_DURATION)
	var struggle_blocked := is_zero_approx(game._crowd_hide_time)
	game._struggle_target = null
	game._pull_target = blocker_target
	game._update_crowd_hiding(FrogGame.CROWD_HIDE_DURATION)
	var pull_blocked := is_zero_approx(game._crowd_hide_time)
	game._pull_target = null
	_check(
		large_growth_blocked
		and flight_blocked
		and knockback_blocked
		and net_blocked
		and struggle_blocked
		and pull_blocked
		and is_instance_valid(game._pursuer),
		"Growth, flight, knockback, netting, struggles, and pulls block crowd hiding."
	)

	game.set_motion_scale(0.0)
	var frozen_member := game._city_activity.crowd_member_position(0)
	seed(20260830)
	var expected_random := randf()
	seed(20260830)
	game._update_crowd_hiding(FrogGame.CROWD_HIDE_DURATION)
	var actual_random := randf()
	_check(
		not is_instance_valid(game._pursuer)
		and game._status_label.text.contains("lost you")
		and game._city_activity.crowd_member_position(0) == frozen_member
		and is_equal_approx(actual_random, expected_random)
		and game._score == score_before
		and game._growth_points == growth_before
		and game._targets.size() == targets_before
		and game._known_discovery_count() == discoveries_before,
		"Crowd cover escapes pursuit under Reduce motion without progression or RNG changes."
	)

	game.queue_free()
	await process_frame


func _test_pursuer_net_escape(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("net_escape_test", "Net Escape Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	game._spawn_pursuer()
	var pursuer := game._pursuer
	_check(
		is_instance_valid(pursuer)
		and game._frog.movement_enabled,
		"Ordinary Animal Control pursuit leaves frog movement enabled."
	)
	if not is_instance_valid(pursuer):
		game.queue_free()
		await process_frame
		return
	pursuer.set_physics_process(false)
	game._input_assist_mode = AccessibilityPresentation.INPUT_ASSIST_HOLD
	_check(
		game._pursuit_start_guidance(
			PrototypePursuer.ARCHETYPE_ANIMAL_CONTROL
		).contains("press and hold"),
		"Animal Control pursuit guidance honors Hold Assist."
	)
	game._input_assist_mode = AccessibilityPresentation.INPUT_ASSIST_STANDARD

	var launch_position := pursuer.global_position
	var original_frog_position := game._frog.global_position
	var launch_distance := launch_position.distance_to(original_frog_position)
	_check(
		PrototypePursuer.NET_INITIAL_COOLDOWN * pursuer.speed
		< (
			PrototypePursuer.NET_MAX_DISTANCE
			- PrototypePursuer.NET_MIN_DISTANCE
		),
		"The initial cooldown leaves time to throw before Animal Control reaches catch range."
	)
	pursuer._net_cooldown = 0.0
	_check(
		pursuer._can_start_net_attack(launch_distance),
		"Animal Control only readies a net in its bounded range with a clear path."
	)
	var blocker := StaticBody2D.new()
	blocker.position = launch_position.lerp(original_frog_position, 0.5)
	blocker.collision_layer = 1
	var blocker_collision := CollisionShape2D.new()
	var blocker_shape := CircleShape2D.new()
	blocker_shape.radius = 38.0
	blocker_collision.shape = blocker_shape
	blocker.add_child(blocker_collision)
	game._world.add_child(blocker)
	await physics_frame
	_check(
		not pursuer._net_path_clear(
			launch_position,
			original_frog_position
		),
		"The net's full radius cannot pass through blocking geometry."
	)
	blocker.queue_free()
	await physics_frame
	pursuer._begin_net_attack()
	_check(
		pursuer._net_phase == PrototypePursuer.NetPhase.WINDUP
		and pursuer.active_net_projectile_count() == 0,
		"The net attack begins with a visible windup before creating a projectile."
	)
	pursuer._advance_net_attack(PrototypePursuer.NET_WINDUP_DURATION)
	var net_snapshot := game.performance_structure_snapshot()
	_check(
		pursuer._net_phase == PrototypePursuer.NetPhase.FLYING
		and pursuer.active_net_projectile_count() == 1
		and int(net_snapshot["net_projectiles"]) == 1
		and int(net_snapshot["game_nodes"])
		== PerformanceBudgets.BASE_GAME_NODES + 2
		and int(net_snapshot["collision_objects"]) == 42,
		"The flying net is a bounded draw-only state with no added scene or physics nodes."
	)

	game._frog.global_position = (
		original_frog_position
		+ (original_frog_position - launch_position).orthogonal().normalized()
		* 180.0
	)
	for _step in 30:
		pursuer._advance_net_attack(0.05)
		if not pursuer.net_attack_active():
			break
	_check(
		not pursuer.net_attack_active()
		and not game._net_escape_active,
		"Moving out of the telegraphed path dodges the net."
	)

	game._frog.global_position = original_frog_position
	pursuer._begin_net_attack()
	pursuer._advance_net_attack(PrototypePursuer.NET_WINDUP_DURATION)
	for _step in 30:
		pursuer._advance_net_attack(0.05)
		if game._net_escape_active:
			break
	_check(
		game._net_escape_active
		and pursuer.is_frog_netted()
		and not game._frog.movement_enabled
		and game._struggle_panel.visible
		and game._struggle_title.text.contains("Animal Control")
		and game._struggle_hint.text.contains("Movement locked")
		and game._struggle_hint.text.contains("Left-click/tap rapidly")
		and game._struggle_progress.max_value == FrogGame.NET_ESCAPE_TAPS,
		"A net hit clearly explains the temporary movement lock and escape input."
	)

	game._frog._has_move_target = false
	game._handle_world_tap(Vector2(640, 480))
	game._try_tongue_at_screen(Vector2(640, 480))
	game._open_belly()
	game._open_guide()
	_check(
		not game._frog._has_move_target
		and game._belly_overlay.visible == false
		and game._guide_overlay.visible == false,
		"A netted frog cannot move, use the tongue, or open gameplay overlays."
	)

	var escape_score := game._score
	for _tap in FrogGame.NET_ESCAPE_TAPS:
		game._register_net_escape_tap()
	_check(
		not game._net_escape_active
		and not pursuer.is_frog_netted()
		and game._frog.movement_enabled
		and not game._struggle_panel.visible
		and game._score == escape_score
		and game._status_label.text.contains("tore through"),
		"Six rapid taps break the net without changing score or progression."
	)

	var resistant_target := _find_target(game, "running_hotdog")
	game._begin_struggle(resistant_target, 1.0, Vector2.ZERO)
	pursuer.set_frog_netted(true)
	game._on_pursuer_netted(pursuer.global_position)
	_check(
		not is_instance_valid(game._struggle_target)
		and game._net_escape_active,
		"A net hit interrupts an in-progress tongue struggle before trapping the frog."
	)
	game.set_motion_scale(0.0)
	pursuer.pulse_net()
	_check(
		pursuer._presentation_motion_scale == 0.0
		and is_equal_approx(
			pursuer._trapped_net_radius(),
			game._frog.collision_radius() + 14.0
		)
		and game._net_escape_active,
		"Reduce motion removes the net pulse without removing the escape challenge."
	)
	for _tap in FrogGame.NET_ESCAPE_TAPS:
		game._register_net_escape_tap()

	game.set_motion_scale(1.0)
	game._score = 40
	game._damage_cooldown = 0.0
	pursuer.set_frog_netted(true)
	game._on_pursuer_netted(pursuer.global_position)
	game._update_net_escape(FrogGame.NET_ESCAPE_DURATION)
	_check(
		not game._net_escape_active
		and game._score
		== 40 - GameplayTuning.ANIMAL_CONTROL_NET_PENALTY
		and game._frog._knockback_time > 0.0
		and game._frog.movement_enabled
		and game._status_label.text.contains("tightened the net"),
		"Failing the escape uses the existing capped score-loss and knockback path."
	)

	game._frog.set_flying(true)
	pursuer._begin_net_attack()
	pursuer._advance_net_attack(PrototypePursuer.NET_WINDUP_DURATION)
	var flying_cancels_net := not pursuer.net_attack_active()
	game._frog.set_flying(false)
	game._growth_tier = GameplayTuning.ENORMOUS_TIER
	game._frog.set_growth_tier(GameplayTuning.ENORMOUS_TIER)
	pursuer._begin_net_attack()
	pursuer._advance_net_attack(PrototypePursuer.NET_WINDUP_DURATION)
	_check(
		flying_cancels_net and not pursuer.net_attack_active(),
		"Flight and enormous growth prevent Animal Control nets from trapping the frog."
	)

	game._frog.set_growth_tier(0)
	seed(20260830)
	var expected_random := randf()
	seed(20260830)
	pursuer._begin_net_attack()
	pursuer._advance_net_attack(PrototypePursuer.NET_WINDUP_DURATION)
	pursuer.cancel_net_attack()
	var actual_random := randf()
	_check(
		is_equal_approx(actual_random, expected_random),
		"Animal Control net attacks do not consume the gameplay random-number stream."
	)

	game.queue_free()
	await process_frame


func _test_pursuer_tongue_deflection(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("deflect_test", "Deflect Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	game._frog.global_position = Vector2(0, 320)
	game._spawn_pursuer()
	var pursuer := game._pursuer
	var donut := _find_target(game, "street_donut")
	_check(
		is_instance_valid(pursuer) and is_instance_valid(donut),
		"Animal Control and a protected target are available for deflection."
	)
	if not is_instance_valid(pursuer) or not is_instance_valid(donut):
		game.queue_free()
		await process_frame
		return
	pursuer.set_physics_process(false)
	pursuer.global_position = Vector2(90, 320)
	await physics_frame

	var score_before := game._score
	var target_count_before := game._targets.size()
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* donut.global_position
	)
	_check(
		is_instance_valid(_find_target(game, "street_donut"))
		and game._belly.is_empty()
		and game._score == score_before
		and game._targets.size() == target_count_before
		and game._tongue_recovery > 0.0
		and game._tongue_end.distance_to(pursuer.global_position) < 32.0
		and pursuer.deflect_feedback_active()
		and game._status_label.text.contains("deflected"),
		"Animal Control intercepts a small frog's tongue before it reaches a protected target."
	)

	game._tongue_recovery = 0.0
	pursuer._deflect_feedback_left = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* pursuer.global_position
	)
	_check(
		pursuer.deflect_feedback_active()
		and game._belly.is_empty()
		and game._status_label.text.contains("deflected"),
		"A direct tongue shot at Animal Control receives the same clear deflection."
	)

	game.set_motion_scale(0.0)
	game._tongue_recovery = 0.0
	pursuer._deflect_feedback_left = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* pursuer.global_position
	)
	_check(
		pursuer.deflect_feedback_active()
		and is_zero_approx(pursuer._presentation_motion_scale),
		"Reduce motion keeps static deflection feedback without its expansion."
	)

	game._growth_tier = GameplayTuning.ENORMOUS_TIER
	game._frog.set_growth_tier(GameplayTuning.ENORMOUS_TIER)
	game._tongue_recovery = 0.0
	pursuer._deflect_feedback_left = 0.0
	game._frog.global_position = Vector2(0, 0)
	pursuer.global_position = Vector2(90, 0)
	await physics_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* Vector2(1000, 0)
	)
	_check(
		not pursuer.deflect_feedback_active()
		and game._status_label.text.contains("out of tongue range")
		and is_equal_approx(
			game._tongue_end.distance_to(game._frog.global_position),
			game._frog.tongue_range()
		),
		"Enormous growth ignores an officer inside an out-of-range shot while retaining the range limit."
	)

	game._tongue_recovery = 0.0
	game._frog.global_position = Vector2(0, 320)
	pursuer.global_position = Vector2(90, 320)
	await physics_frame
	donut = _find_target(game, "street_donut")
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* donut.global_position
	)
	_check(
		not is_instance_valid(_find_target(game, "street_donut"))
		and game._belly.size() == 1
		and game._belly[0].target_id == "street_donut"
		and is_instance_valid(game._pursuer)
		and not pursuer.deflect_feedback_active(),
		"Enormous growth shoots through Animal Control's block to swallow the intended target."
	)

	game.queue_free()
	await process_frame


func _test_security_guard_pursuer(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("security_test", "Security Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	game._frog.global_position = Vector2(0, 320)
	game._spawn_pursuer(PrototypePursuer.ARCHETYPE_SECURITY_GUARD)
	var guard := game._pursuer
	_check(
		is_instance_valid(guard)
			and guard.archetype_id
			== PrototypePursuer.ARCHETYPE_SECURITY_GUARD
			and is_equal_approx(
				guard.speed,
				PrototypePursuer.SECURITY_SPEED
			)
			and is_equal_approx(
				guard.navigation_radius(),
				PrototypePursuer.SECURITY_NAVIGATION_RADIUS
			)
			and not guard.deploys_roadblock()
			and guard.deploys_pursuit_trap()
			and guard.pursuit_trap_variant() == (
				PrototypePursuitTrap.VARIANT_MOTION_BEACON
			)
			and is_equal_approx(
				game._pursuit_trap_deploy_time,
				PrototypePursuer.SECURITY_TRAP_DEPLOY_DELAY
			)
			and game._roadblock_deployed
			and not game._pursuit_trap_deployed,
		"Security Guard uses its slower search profile and one delayed motion beacon."
	)
	if not is_instance_valid(guard):
		game.queue_free()
		await process_frame
		return
	guard.set_physics_process(false)
	guard.global_position = Vector2(100, 320)
	await physics_frame

	var park_chair := _find_target(game, "park_chair")
	var donut := _find_target(game, "street_donut")
	park_chair.global_position = Vector2(220, 320)
	donut.global_position = Vector2(520, 320)
	guard._update_detection()
	_check(
		guard.frog_detected()
			and guard.protects_target(park_chair)
			and not guard.protects_target(donut)
			and game._pursuer_archetype_for_escape(park_chair)
			== PrototypePursuer.ARCHETYPE_SECURITY_GUARD
			and game._pursuer_archetype_for_escape(donut)
			== PrototypePursuer.ARCHETYPE_ANIMAL_CONTROL,
		"Security uses line-of-sight detection and protects valuables rather than every target."
	)

	var score_before := game._score
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* park_chair.global_position
	)
	_check(
		is_instance_valid(_find_target(game, "park_chair"))
			and game._belly.is_empty()
			and game._score == score_before
			and guard.deflect_feedback_active()
			and game._status_label.text.contains("Security Guard"),
		"Security Guard intercepts a tongue only for a nearby protected valuable."
	)

	game._tongue_recovery = 0.0
	guard._deflect_feedback_left = 0.0
	park_chair.global_position = Vector2(520, 320)
	donut.global_position = Vector2(220, 320)
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* donut.global_position
	)
	_check(
		not is_instance_valid(_find_target(game, "street_donut"))
			and game._belly.size() == 1
			and game._belly[0].target_id == "street_donut"
			and not guard.deflect_feedback_active(),
		"Security Guard does not provide Animal Control's universal tongue shield."
	)

	var blocker := StaticBody2D.new()
	blocker.position = Vector2(50, 320)
	blocker.collision_layer = 1
	var blocker_collision := CollisionShape2D.new()
	var blocker_shape := CircleShape2D.new()
	blocker_shape.radius = 34.0
	blocker_collision.shape = blocker_shape
	blocker.add_child(blocker_collision)
	game._world.add_child(blocker)
	await physics_frame
	guard._update_detection()
	_check(
		not guard.frog_detected(),
		"Solid city geometry breaks the Security Guard's line-of-sight detection."
	)
	blocker.queue_free()
	await physics_frame

	game._frog.global_position = Vector2(300, 320)
	guard.global_position = Vector2(0, 320)
	guard._update_detection()
	guard._flashlight_cooldown = 0.0
	var attack_nodes_before := int(
		game.performance_structure_snapshot()["game_nodes"]
	)
	guard._begin_flashlight_attack()
	game._frog.global_position += Vector2(0, 150)
	guard._advance_flashlight_attack(
		PrototypePursuer.SECURITY_FLASHLIGHT_WINDUP_DURATION
	)
	_check(
		not guard.flashlight_attack_active()
			and game._score == score_before
			and int(
				game.performance_structure_snapshot()["game_nodes"]
			) == attack_nodes_before,
		"The telegraphed flashlight strike is draw-only and can be dodged."
	)

	game._frog.global_position = Vector2(300, 320)
	guard._update_detection()
	guard._flashlight_cooldown = 0.0
	game._score = 30
	game._damage_cooldown = 0.0
	guard._begin_flashlight_attack()
	guard._advance_flashlight_attack(
		PrototypePursuer.SECURITY_FLASHLIGHT_WINDUP_DURATION
	)
	_check(
		game._score
		== 30 - GameplayTuning.SECURITY_FLASHLIGHT_PENALTY
			and game._frog.knockback_active()
			and game._status_label.text.contains("flashlight")
			and not game._net_escape_active,
		"Security Guard's flashlight applies one capped knockback hit without a net escape loop."
	)

	game.set_motion_scale(0.0)
	game._frog._knockback_time = 0.0
	game._frog.movement_enabled = true
	game._damage_cooldown = 0.0
	guard._flashlight_cooldown = 0.0
	guard._begin_flashlight_attack()
	var reduced_motion_time := guard._flashlight_windup_left
	guard._advance_flashlight_attack(reduced_motion_time * 0.5)
	_check(
		guard.flashlight_attack_active()
			and is_zero_approx(guard._presentation_motion_scale)
			and is_equal_approx(
				guard._flashlight_windup_left,
				reduced_motion_time * 0.5
			),
		"Reduce motion freezes flashlight decoration without changing attack timing."
	)
	guard._flashlight_windup_left = 0.0
	guard._flashlight_target_position = Vector2.ZERO

	game.set_motion_scale(1.0)
	game._growth_tier = GameplayTuning.ENORMOUS_TIER
	game._frog.set_growth_tier(GameplayTuning.ENORMOUS_TIER)
	game._frog.global_position = Vector2(0, 320)
	guard.global_position = Vector2(90, 320)
	game._tongue_recovery = 0.0
	await physics_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* guard.global_position
	)
	_check(
		not is_instance_valid(game._pursuer)
			and game._belly.size() == 2
			and game._belly[1].target_id
			== PrototypePursuer.ARCHETYPE_SECURITY_GUARD
			and game._discoveries.has(
				PrototypePursuer.ARCHETYPE_SECURITY_GUARD
			),
		"Enormous growth can swallow Security Guard into the Belly and Field Guide."
	)

	game._growth_tier = 0
	game._frog.set_growth_tier(0)
	game._frog.global_position = Vector2(0, 320)
	game._spawn_pursuer(PrototypePursuer.ARCHETYPE_SECURITY_GUARD)
	guard = game._pursuer
	if is_instance_valid(guard):
		guard.set_physics_process(false)
		game._frog.set_flying(true)
		guard._physics_process(
			PrototypePursuer.SECURITY_LOST_ESCAPE_TIME
		)
		await process_frame
	_check(
		not is_instance_valid(game._pursuer)
			and not is_instance_valid(game._roadblock)
			and not is_instance_valid(game._pursuit_trap),
		"Flight breaks Security Guard detection and bounded cleanup ends the pursuit."
	)

	game.queue_free()
	await process_frame


func _test_watchdog_pursuer(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("watchdog_test", "Watchdog Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	game._frog.global_position = Vector2(0, 320)
	game._spawn_pursuer(PrototypePursuer.ARCHETYPE_WATCHDOG)
	var watchdog := game._pursuer
	_check(
		is_instance_valid(watchdog)
			and watchdog.archetype_id
			== PrototypePursuer.ARCHETYPE_WATCHDOG
			and is_equal_approx(
				watchdog.speed,
				PrototypePursuer.WATCHDOG_SPEED
			)
			and is_equal_approx(
				watchdog.navigation_radius(),
				PrototypePursuer.WATCHDOG_NAVIGATION_RADIUS
			)
			and is_equal_approx(
				watchdog.crowd_escape_duration(),
				PrototypePursuer.WATCHDOG_CROWD_ESCAPE_DURATION
			)
			and not watchdog.deploys_roadblock()
			and watchdog.deploys_pursuit_trap()
			and watchdog.pursuit_trap_variant() == (
				PrototypePursuitTrap.VARIANT_STICKY_PATCH
			)
			and is_equal_approx(
				game._pursuit_trap_deploy_time,
				PrototypePursuer.WATCHDOG_TRAP_DEPLOY_DELAY
			),
		"Watchdog uses the fastest small-radius profile and one delayed sticky patch."
	)
	if not is_instance_valid(watchdog):
		game.queue_free()
		await process_frame
		return
	watchdog.set_physics_process(false)
	watchdog.global_position = Vector2(100, 320)

	var protected_living := EdibleTarget.new()
	protected_living.target_id = "watchdog_test_living"
	protected_living.display_name = "Test Pedestrian"
	protected_living.kind = "living"
	protected_living.pick_radius = 28.0
	protected_living.position = Vector2(220, 320)
	game._world.add_child(protected_living)
	game._targets.append(protected_living)
	var donut := _find_target(game, "street_donut")
	donut.global_position = Vector2(520, 320)

	var scent_blocker := StaticBody2D.new()
	scent_blocker.position = Vector2(50, 320)
	scent_blocker.collision_layer = 1
	var blocker_collision := CollisionShape2D.new()
	var blocker_shape := CircleShape2D.new()
	blocker_shape.radius = 34.0
	blocker_collision.shape = blocker_shape
	scent_blocker.add_child(blocker_collision)
	game._world.add_child(scent_blocker)
	await physics_frame
	watchdog._update_detection()
	_check(
		watchdog.frog_detected()
			and watchdog.protects_target(protected_living)
			and not watchdog.protects_target(donut)
			and game._pursuer_archetype_for_escape(protected_living)
			== PrototypePursuer.ARCHETYPE_WATCHDOG,
		"Watchdog scent crosses walls and its protection is limited to nearby living targets."
	)

	scent_blocker.position = Vector2(500, 320)
	await physics_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* protected_living.global_position
	)
	_check(
		game._belly.is_empty()
			and is_instance_valid(protected_living)
			and watchdog.deflect_feedback_active()
			and game._status_label.text.contains("Watchdog"),
		"Watchdog intercepts the tongue for a living target in its guarded radius."
	)

	game._tongue_recovery = 0.0
	watchdog._deflect_feedback_left = 0.0
	protected_living.global_position = Vector2(520, 320)
	donut.global_position = Vector2(220, 320)
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* donut.global_position
	)
	_check(
		not is_instance_valid(_find_target(game, "street_donut"))
			and game._belly.size() == 1
			and not watchdog.deflect_feedback_active(),
		"Watchdog does not protect food with its living-target interception profile."
	)

	game._frog.global_position = Vector2(300, 320)
	watchdog.global_position = Vector2(0, 320)
	scent_blocker.position = Vector2(150, 320)
	await physics_frame
	watchdog._update_detection()
	watchdog._lunge_cooldown = 0.0
	var score_before := game._score
	watchdog._begin_lunge_attack()
	watchdog._advance_lunge_attack(
		PrototypePursuer.WATCHDOG_LUNGE_WINDUP_DURATION
	)
	watchdog._advance_lunge_attack(0.5)
	_check(
		not watchdog.lunge_attack_active()
			and watchdog.global_position.x < scent_blocker.global_position.x
			and game._score == score_before,
		"Solid city geometry stops the Watchdog's physical lunge before damage."
	)

	scent_blocker.queue_free()
	await physics_frame
	watchdog.global_position = Vector2(0, 320)
	game._frog.global_position = Vector2(300, 320)
	watchdog._lunge_cooldown = 0.0
	watchdog._begin_lunge_attack()
	game._frog.global_position += Vector2(0, 160)
	watchdog._advance_lunge_attack(
		PrototypePursuer.WATCHDOG_LUNGE_WINDUP_DURATION
	)
	for _step in 8:
		watchdog._advance_lunge_attack(0.05)
		if not watchdog.lunge_attack_active():
			break
	_check(
		not watchdog.lunge_attack_active()
			and game._score == score_before,
		"Moving out of the locked lunge path dodges the Watchdog."
	)

	watchdog.global_position = Vector2(0, 320)
	game._frog.global_position = Vector2(180, 320)
	game._score = 30
	game._damage_cooldown = 0.0
	watchdog._lunge_cooldown = 0.0
	watchdog._begin_lunge_attack()
	watchdog._advance_lunge_attack(
		PrototypePursuer.WATCHDOG_LUNGE_WINDUP_DURATION
	)
	watchdog._advance_lunge_attack(0.25)
	_check(
		game._score
		== 30 - GameplayTuning.WATCHDOG_LUNGE_PENALTY
			and game._frog.knockback_active()
			and not watchdog.lunge_attack_active()
			and game._status_label.text.contains("lunge")
			and not game._net_escape_active,
		"Watchdog lunge applies one capped knockback hit without a repeated damage loop."
	)

	game.set_motion_scale(0.0)
	game._frog._knockback_time = 0.0
	game._frog.movement_enabled = true
	game._damage_cooldown = 0.0
	watchdog.global_position = Vector2(0, 320)
	game._frog.global_position = Vector2(180, 320)
	watchdog._lunge_cooldown = 0.0
	watchdog._begin_lunge_attack()
	var reduced_motion_time := watchdog._lunge_windup_left
	watchdog._advance_lunge_attack(reduced_motion_time * 0.5)
	_check(
		watchdog.lunge_attack_active()
			and is_zero_approx(watchdog._presentation_motion_scale)
			and is_equal_approx(
				watchdog._lunge_windup_left,
				reduced_motion_time * 0.5
			),
		"Reduce motion suppresses lunge decoration without changing warning timing."
	)
	watchdog.cancel_active_attack()

	game.set_motion_scale(1.0)
	game._growth_tier = GameplayTuning.ENORMOUS_TIER
	game._frog.set_growth_tier(GameplayTuning.ENORMOUS_TIER)
	game._frog.global_position = Vector2(0, 320)
	watchdog.global_position = Vector2(90, 320)
	game._tongue_recovery = 0.0
	await physics_frame
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* watchdog.global_position
	)
	_check(
		not is_instance_valid(game._pursuer)
			and game._belly.size() == 2
			and game._belly[1].target_id
			== PrototypePursuer.ARCHETYPE_WATCHDOG
			and game._discoveries.has(
				PrototypePursuer.ARCHETYPE_WATCHDOG
			),
		"Enormous growth can swallow Watchdog into the Belly and Field Guide."
	)

	game._growth_tier = 0
	game._frog.set_growth_tier(0)
	game._frog.global_position = Vector2(0, 320)
	game._spawn_pursuer(PrototypePursuer.ARCHETYPE_WATCHDOG)
	watchdog = game._pursuer
	if is_instance_valid(watchdog):
		watchdog.set_physics_process(false)
		game._frog.set_flying(true)
		watchdog._physics_process(
			PrototypePursuer.WATCHDOG_LOST_ESCAPE_TIME
		)
		await process_frame
	_check(
		not is_instance_valid(game._pursuer)
			and not is_instance_valid(game._roadblock)
			and not is_instance_valid(game._pursuit_trap),
		"Flight breaks Watchdog scent and its short lost-scent timer cleans up pursuit."
	)

	game.queue_free()
	await process_frame


func _test_pursuer_roadblock(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("roadblock_test", "Roadblock Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	game._frog.global_position = Vector2(1500, -500)
	game._spawn_pursuer()
	var pursuer := game._pursuer
	_check(
		is_instance_valid(pursuer)
		and not is_instance_valid(game._roadblock)
		and is_equal_approx(
			game._roadblock_deploy_time,
			FrogGame.ROADBLOCK_DEPLOY_DELAY
		),
		"Animal Control begins pursuit before deploying one delayed roadblock."
	)
	if not is_instance_valid(pursuer):
		game.queue_free()
		await process_frame
		return
	pursuer.set_physics_process(false)

	game._frog.movement_enabled = false
	game._roadblock_deploy_time = 0.0
	game._update_pursuit_roadblock(0.1)
	var blocked_while_rooted := not is_instance_valid(game._roadblock)
	game._frog.movement_enabled = true
	seed(20260830)
	var expected_random := randf()
	seed(20260830)
	game._update_pursuit_roadblock(0.1)
	var waits_for_safe_anchor := (
		not is_instance_valid(game._roadblock)
		and not game._roadblock_deployed
	)
	game._frog.global_position = Vector2(0, -520)
	game._update_pursuit_roadblock(0.0)
	var actual_random := randf()
	await physics_frame
	var roadblock := game._roadblock
	var score_before := game._score
	var growth_before := game._growth_points
	var target_count_before := game._targets.size()
	var discovery_count_before := game._known_discovery_count()
	_check(
		blocked_while_rooted
		and waits_for_safe_anchor
		and is_instance_valid(roadblock)
		and roadblock.global_position == Vector2(0, -900)
		and roadblock.barrier_size == Vector2(360, 52)
		and roadblock.layout_id == PrototypeRoadblock.LAYOUT_STRAIGHT
		and roadblock.collision_shape_count() == 1
		and roadblock.remaining_hits()
		== PrototypeRoadblock.REQUIRED_HITS
		and is_equal_approx(actual_random, expected_random),
		"The roadblock retries until the nearest safe authored anchor is available without gameplay RNG."
	)
	if not is_instance_valid(roadblock):
		game.queue_free()
		await process_frame
		return
	var roadblock_rect := Rect2(
		roadblock.global_position - roadblock.barrier_size / 2.0,
		roadblock.barrier_size
	)
	var avoids_targets := true
	for target in game._targets:
		if (
			is_instance_valid(target)
			and target.kind != "building"
			and game._circle_overlaps_rect(
				target.global_position,
				target.pick_radius,
				roadblock_rect
			)
		):
			avoids_targets = false
	_check(
		not game._circle_position_clear(
			roadblock.global_position,
			28.0,
			true
		)
		and avoids_targets
		and not game._position_inside_building(
			roadblock.global_position
		),
		"The deployed barricade blocks ground movement without covering targets or buildings."
	)
	var initial_snapshot := game.performance_structure_snapshot()
	game._update_pursuit_roadblock(100.0)
	_check(
		game._roadblock == roadblock
		and int(initial_snapshot["roadblocks"]) == 1,
		"One pursuit can deploy at most one roadblock."
	)

	game._frog.global_position = (
		roadblock.global_position + Vector2(0, 180)
	)
	game._camera.rotation = 0.0
	game._update_camera()
	await process_frame
	var aim_position := (
		roadblock.global_position - Vector2(0, 180)
	)
	for expected_remaining in [2, 1]:
		game._tongue_recovery = 0.0
		game._try_tongue_at_screen(
			game.get_viewport().get_canvas_transform()
			* aim_position
		)
		_check(
			game._roadblock == roadblock
			and roadblock.remaining_hits() == expected_remaining
			and game._status_label.text.contains("Roadblock hit"),
			"Each obstructed tongue shot visibly damages the roadblock."
		)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* aim_position
	)
	await process_frame
	await physics_frame
	_check(
		not is_instance_valid(game._roadblock)
		and game._circle_position_clear(
			roadblock_rect.get_center(),
			28.0,
			true
		)
		and game._status_label.text.contains("broke apart")
		and game._score == score_before
		and game._growth_points == growth_before
		and game._targets.size() == target_count_before
		and game._known_discovery_count() == discovery_count_before,
		"Three tongue hits remove the barricade without rewards or progression changes."
	)
	game._update_pursuit_roadblock(PrototypeRoadblock.LIFETIME)
	_check(
		not is_instance_valid(game._roadblock),
		"A broken roadblock cannot redeploy during the same pursuit."
	)

	game._roadblock_deployed = false
	game._roadblock_deploy_time = 0.0
	game._update_pursuit_roadblock(0.1)
	var expiring_roadblock := game._roadblock
	if is_instance_valid(expiring_roadblock):
		expiring_roadblock._process(PrototypeRoadblock.LIFETIME)
	await process_frame
	_check(
		not is_instance_valid(game._roadblock)
		and is_instance_valid(game._pursuer),
		"An unbroken roadblock expires after its bounded lifetime without ending pursuit."
	)

	game._roadblock_deployed = false
	game._roadblock_deploy_time = 0.0
	game._update_pursuit_roadblock(0.1)
	var escape_roadblock := game._roadblock
	pursuer._escape()
	await process_frame
	_check(
		not is_instance_valid(game._pursuer)
		and not is_instance_valid(game._roadblock)
		and (
			not is_instance_valid(escape_roadblock)
			or escape_roadblock.collision_layer == 0
		),
		"Ending pursuit immediately clears its temporary roadblock."
	)

	game.queue_free()
	await process_frame

	var staggered_game := game_scene.instantiate() as FrogGame
	staggered_game.configure(
		"staggered_roadblock_test",
		"Staggered Roadblock Tester",
		false
	)
	root.add_child(staggered_game)
	await process_frame
	await physics_frame
	staggered_game.set_process(false)
	staggered_game._frog.set_physics_process(false)
	staggered_game._frog.global_position = Vector2(-1080, -300)
	staggered_game._spawn_pursuer()
	if is_instance_valid(staggered_game._pursuer):
		staggered_game._pursuer.set_physics_process(false)
	staggered_game._roadblock_deploy_time = 0.0
	seed(20260902)
	var expected_staggered_random := randf()
	seed(20260902)
	staggered_game._update_pursuit_roadblock(0.1)
	var actual_staggered_random := randf()
	await physics_frame
	var staggered := staggered_game._roadblock
	_check(
		is_instance_valid(staggered)
			and staggered.global_position == Vector2(-1080, -650)
			and staggered.layout_id
			== PrototypeRoadblock.LAYOUT_STAGGERED
			and staggered.collision_shape_count() == 2
			and staggered.navigation_obstacle_rects().size() == 2
			and is_equal_approx(
				actual_staggered_random,
				expected_staggered_random
			)
			and staggered_game._status_label.text.contains(
				"staggered chicane"
			),
		"The nearest authored staggered anchor deploys two capped segments without gameplay RNG."
	)
	if is_instance_valid(staggered):
		var segment_rects := staggered.navigation_obstacle_rects()
		var segments_safe := not segment_rects[0].intersects(
			segment_rects[1]
		)
		for segment in segment_rects:
			for target in staggered_game._targets:
				if (
					is_instance_valid(target)
					and target.kind != "building"
					and staggered_game._circle_overlaps_rect(
						target.global_position,
						target.pick_radius,
						segment
					)
				):
					segments_safe = false
			for building in staggered_game._buildings:
				if (
					is_instance_valid(building)
					and not building.consumed
					and segment.intersects(
						building.footprint_rect()
					)
				):
					segments_safe = false
		staggered_game._update_navigation_paths()
		var maximum_radius := (
			staggered_game._frog.radius_for_tier(
				GameplayTuning.ENORMOUS_TIER
			)
		)
		var route := staggered_game._navigation.find_path(
			staggered.global_position + Vector2(0, -220),
			staggered.global_position + Vector2(0, 220),
			maximum_radius
		)
		var route_points := route["points"] as PackedVector2Array
		var first_segment := segment_rects[0]
		var crossing_start := (
			first_segment.get_center() + Vector2(0, -120)
		)
		var crossing_destination := (
			first_segment.get_center() + Vector2(0, 120)
		)
		staggered_game._frog.global_position = crossing_start
		staggered_game._frog.set_physics_process(true)
		staggered_game._frog.move_to(crossing_destination)
		for _frame in 120:
			await physics_frame
		var ground_blocked := (
			staggered_game._frog.global_position.distance_to(
				crossing_destination
			) > 60.0
		)
		staggered_game._frog.stop_moving()
		staggered_game._frog.global_position = crossing_start
		staggered_game._frog.set_flying(true)
		staggered_game._frog.move_to(crossing_destination)
		for _frame in 120:
			await physics_frame
			if not staggered_game._frog._has_move_target:
				break
		var flight_crossed := (
			staggered_game._frog.global_position.distance_to(
				crossing_destination
			) <= PlayerFrog.WAYPOINT_TOLERANCE
		)
		staggered_game._frog.set_flying(false)
		staggered_game._frog.set_physics_process(false)
		_check(
			segments_safe,
			"The staggered layout avoids authored targets and buildings."
		)
		_check(
			bool(route["reachable"])
				and not bool(route["fallback"])
				and route_points.size() >= 2
				and staggered_game._navigation.path_is_clear(
					route_points,
					maximum_radius
				),
			"The staggered layout preserves an enormous-growth escape lane."
		)
		_check(
			ground_blocked,
			"The staggered layout blocks direct ground crossing through a segment."
		)
		_check(
			flight_crossed,
			"Flight crosses a staggered roadblock without collision."
		)
	staggered_game.queue_free()
	await process_frame

	var district_game := game_scene.instantiate() as FrogGame
	district_game.configure(
		"roadblock_district_test",
		"Roadblock District Tester",
		false
	)
	root.add_child(district_game)
	await process_frame
	await physics_frame
	district_game.set_process(false)
	district_game._frog.set_physics_process(false)
	var first_coordinate := Vector2i(2, 2)
	var first_bounds := DistrictGenerator.bounds_for_coordinate(
		first_coordinate
	)
	district_game._frog.global_position = (
		first_bounds.get_center() + Vector2(400, 0)
	)
	district_game._update_district_streaming()
	district_game._spawn_pursuer()
	if is_instance_valid(district_game._pursuer):
		district_game._pursuer.set_physics_process(false)
	district_game._roadblock_deploy_time = 0.0
	district_game._update_pursuit_roadblock(0.1)
	var district_roadblock := district_game._roadblock
	var district_layout := (
		district_roadblock.layout_id
		if is_instance_valid(district_roadblock)
		else ""
	)
	var first_loaded_count := district_game._loaded_districts.size()
	district_game._frog.global_position = (
		DistrictGenerator.bounds_for_coordinate(
			Vector2i(4, 2)
		).get_center()
	)
	district_game._update_district_streaming()
	await process_frame
	_check(
		first_loaded_count
			== DistrictGenerator.MAX_LOADED_GENERATED_DISTRICTS
			and district_layout in [
				PrototypeRoadblock.LAYOUT_STRAIGHT,
				PrototypeRoadblock.LAYOUT_STAGGERED,
			]
			and is_instance_valid(district_game._pursuer)
			and not is_instance_valid(district_game._roadblock)
			and (
				not is_instance_valid(district_roadblock)
				or district_roadblock.collision_layer == 0
			)
			and not district_game._loaded_districts.has(
				first_coordinate + Vector2i(-1, -1)
			),
		"Unloading a generated ring clears its roadblock without ending pursuit."
	)
	district_game.queue_free()
	await process_frame


func _test_city_detour(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("city_detour_test", "City Detour Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	_check(
		not FrogGame.city_detour_active_for_clock(0.6199)
		and FrogGame.city_detour_active_for_clock(0.62)
		and FrogGame.city_detour_active_for_clock(0.7399)
		and not FrogGame.city_detour_active_for_clock(0.74)
		and FrogGame.city_detour_active_for_clock(1.62),
		"The water-main detour uses one deterministic bounded rain-window schedule."
	)

	var blockers: Array[StaticBody2D] = []
	for configuration_value in FrogGame.CITY_DETOUR_ANCHORS:
		var configuration := configuration_value as Dictionary
		var blocker := StaticBody2D.new()
		blocker.position = configuration["position"] as Vector2
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = configuration["size"] as Vector2
		collision.shape = shape
		blocker.add_child(collision)
		game._world.add_child(blocker)
		blockers.append(blocker)
	await physics_frame

	var score_before := game._score
	var growth_before := game._growth_points
	var belly_before := game._belly.size()
	var targets_before := game._targets.size()
	var discoveries_before := game._known_discovery_count()
	var challenge_progress_before := [
		game._challenges.progress(SessionChallenges.SHARP_AIM),
		game._challenges.progress(SessionChallenges.HOLD_ON),
		game._challenges.progress(SessionChallenges.CITY_TOUR),
		game._challenges.completed_count(),
	]
	game._day_clock = 0.62
	game._update_day_night(0.0)
	seed(20260901)
	var expected_random := randf()
	seed(20260901)
	game._update_city_detour(0.0)
	var actual_random := randf()
	_check(
		not is_instance_valid(game._city_detour)
		and game._city_detour_window_active
		and is_equal_approx(
			game._city_detour_retry_time,
			FrogGame.CITY_DETOUR_RETRY_DELAY
		)
		and is_equal_approx(actual_random, expected_random),
		"Blocked authored anchors schedule one deterministic retry without consuming gameplay RNG."
	)
	game._update_city_detour(FrogGame.CITY_DETOUR_RETRY_DELAY * 0.5)
	blockers[0].queue_free()
	await physics_frame
	game._update_city_detour(FrogGame.CITY_DETOUR_RETRY_DELAY * 0.5)
	var detour := game._city_detour
	for blocker in blockers:
		if is_instance_valid(blocker):
			blocker.queue_free()
	await physics_frame
	_check(
		is_instance_valid(detour)
		and detour.global_position
		== FrogGame.CITY_DETOUR_ANCHORS[0]["position"]
		and detour.barrier_size
		== FrogGame.CITY_DETOUR_ANCHORS[0]["size"]
		and detour.collision_layer == 1
		and detour.get_child_count() == 1
		and detour.get_child(0) is CollisionShape2D,
		"The detour retries into the first clear authored anchor with one capped physical segment."
	)
	if not is_instance_valid(detour):
		game.queue_free()
		await process_frame
		return

	game._refresh_navigation_geometry()
	var detour_snapshot := game.performance_structure_snapshot()
	var maximum_radius := game._frog.radius_for_tier(
		GameplayTuning.ENORMOUS_TIER
	)
	var route := game._navigation.find_path(
		detour.global_position + Vector2(0, -180),
		detour.global_position + Vector2(0, 180),
		maximum_radius
	)
	var route_points := route["points"] as PackedVector2Array
	_check(
		int(detour_snapshot["game_nodes"])
		== PerformanceBudgets.BASE_GAME_NODES + 2
		and int(detour_snapshot["collision_objects"]) == 42
		and int(detour_snapshot["collision_shapes"]) == 112
		and int(detour_snapshot["city_detours"]) == 1
		and int(detour_snapshot["navigation_obstacles"]) == 31
		and bool(route["reachable"])
		and not bool(route["fallback"])
		and route_points.size() >= 4
		and game._navigation.path_is_clear(route_points, maximum_radius),
		"The enormous-growth navigation route safely detours around the one-segment repair."
	)

	var crossing_start := detour.global_position + Vector2(0, -150)
	var crossing_destination := detour.global_position + Vector2(0, 150)
	game._frog.global_position = crossing_start
	game._frog.set_physics_process(true)
	game._frog.move_to(crossing_destination)
	for _frame in 120:
		await physics_frame
	var ground_blocked := (
		game._frog.global_position.distance_to(crossing_destination)
		> 60.0
	)
	game._frog.stop_moving()
	game._frog.global_position = crossing_start
	game._frog.set_flying(true)
	game._frog.move_to(crossing_destination)
	for _frame in 120:
		await physics_frame
		if not game._frog._has_move_target:
			break
	var flight_crossed := (
		game._frog.global_position.distance_to(crossing_destination)
		<= PlayerFrog.WAYPOINT_TOLERANCE
	)
	game._frog.set_flying(false)
	game._frog.set_physics_process(false)
	_check(
		ground_blocked and flight_crossed,
		"The repair blocks direct ground crossing while flight preserves a clear escape."
	)

	game._frog.global_position = Vector2(0, -520)
	game._spawn_pursuer()
	if is_instance_valid(game._pursuer):
		game._pursuer.set_physics_process(false)
	game._roadblock_deploy_time = 0.0
	game._update_pursuit_roadblock(0.1)
	game._pursuit_trap_deploy_time = 0.0
	game._update_pursuit_trap(0.1)
	_check(
		is_instance_valid(game._pursuer)
		and is_instance_valid(game._city_detour)
		and not is_instance_valid(game._roadblock)
		and is_instance_valid(game._pursuit_trap)
		and game._pursuit_trap.variant_id
		== PrototypePursuitTrap.VARIANT_SNARE,
		"The detour can coexist with one draw-only trap but suppresses a stacking pursuit roadblock."
	)
	if is_instance_valid(game._pursuer):
		game._pursuer._escape()
		await process_frame

	game.set_motion_scale(0.0)
	var cafe := (
		game._building_by_id.get("leap_cafe") as PrototypeBuilding
	)
	game._frog.global_position = cafe.transition_door_approach_position()
	game._begin_interior_transition(FrogGame.STOCKROOM_ID)
	var transition_cleared := (
		game._active_interior_id == FrogGame.STOCKROOM_ID
		and not is_instance_valid(game._city_detour)
	)
	game._begin_interior_transition("city")
	game._update_city_detour(0.0)
	var return_retried := is_instance_valid(game._city_detour)
	game._frog.global_position = DistrictGenerator.bounds_for_coordinate(
		Vector2i(2, 2)
	).get_center()
	game._update_district_streaming()
	game._update_city_detour(0.0)
	var district_cleared := (
		not is_instance_valid(game._city_detour)
		and game._current_district_coordinate == Vector2i(2, 2)
	)
	game._spawn_pursuer()
	if is_instance_valid(game._pursuer):
		game._pursuer.set_physics_process(false)
	game._roadblock_deploy_time = 0.0
	game._update_pursuit_roadblock(0.1)
	var generated_roadblock_allowed := is_instance_valid(game._roadblock)
	if is_instance_valid(game._pursuer):
		game._pursuer._escape()
		await process_frame
	game._frog.global_position = Vector2.ZERO
	game._update_district_streaming()
	game._update_city_detour(0.0)
	_check(
		transition_cleared
		and return_retried
		and district_cleared
		and generated_roadblock_allowed
		and is_instance_valid(game._city_detour),
		"District departure clears the repair without suppressing generated roadblocks, then core return retries it."
	)

	game._day_clock = 0.74
	game._update_day_night(0.0)
	game._update_city_detour(0.0)
	_check(
		not game._city_detour_window_active
		and not is_instance_valid(game._city_detour)
		and game._score == score_before
		and game._growth_points == growth_before
		and game._belly.size() == belly_before
		and game._targets.size() == targets_before
		and game._known_discovery_count() == discoveries_before
		and challenge_progress_before == [
			game._challenges.progress(SessionChallenges.SHARP_AIM),
			game._challenges.progress(SessionChallenges.HOLD_ON),
			game._challenges.progress(SessionChallenges.CITY_TOUR),
			game._challenges.completed_count(),
		],
		"Expiry clears the repair without score, growth, Belly, target, discovery, or challenge changes."
	)

	game._day_clock = 0.60
	game._update_day_night(0.0)
	game._frog.global_position = Vector2(0, -520)
	game._spawn_pursuer()
	if is_instance_valid(game._pursuer):
		game._pursuer.set_physics_process(false)
	game._roadblock_deploy_time = 0.0
	game._update_pursuit_roadblock(0.1)
	var existing_roadblock := game._roadblock
	game._day_clock = 0.62
	game._update_day_night(0.0)
	game._update_city_detour(0.0)
	var roadblock_took_priority := (
		is_instance_valid(existing_roadblock)
		and not is_instance_valid(game._city_detour)
	)
	if is_instance_valid(existing_roadblock):
		existing_roadblock._process(PrototypeRoadblock.LIFETIME)
	await process_frame
	game._update_city_detour(0.0)
	_check(
		roadblock_took_priority
		and not is_instance_valid(game._roadblock)
		and is_instance_valid(game._city_detour),
		"An existing pursuit roadblock finishes first, then the repair deploys without overlap."
	)

	game.queue_free()
	await process_frame


func _test_pursuer_snare(game_scene: PackedScene) -> void:
	var trap_profiles := [
		{
			"variant": PrototypePursuitTrap.VARIANT_SNARE,
			"radius": 46.0,
			"arm_delay": 0.75,
			"lifetime": 12.0,
			"damaging": true,
			"arming_label": "ARMING",
			"armed_label": "SNARE",
		},
		{
			"variant": PrototypePursuitTrap.VARIANT_MOTION_BEACON,
			"radius": 54.0,
			"arm_delay": 0.5,
			"lifetime": 10.0,
			"damaging": false,
			"arming_label": "CALIBRATING",
			"armed_label": "MOTION BEACON",
		},
		{
			"variant": PrototypePursuitTrap.VARIANT_STICKY_PATCH,
			"radius": 42.0,
			"arm_delay": 1.0,
			"lifetime": 14.0,
			"damaging": false,
			"arming_label": "SETTLING",
			"armed_label": "STICKY PATCH",
		},
	]
	for profile in trap_profiles:
		var one_step := PrototypePursuitTrap.new()
		var split_step := PrototypePursuitTrap.new()
		var variant_id := str(profile["variant"])
		one_step.configure_variant(variant_id)
		split_step.configure_variant(variant_id)
		one_step.set_presentation_motion_scale(0.0)
		var arm_delay := float(profile["arm_delay"])
		var warning_label := one_step.state_label()
		one_step.advance(arm_delay)
		split_step.advance(arm_delay * 0.5)
		split_step.advance(arm_delay * 0.5)
		_check(
			one_step.variant_id == variant_id
				and is_equal_approx(
					one_step.radius(),
					float(profile["radius"])
				)
				and is_equal_approx(one_step.arm_delay(), arm_delay)
				and is_equal_approx(
					one_step.lifetime(),
					float(profile["lifetime"])
				)
				and one_step.causes_damage()
				== bool(profile["damaging"])
				and warning_label == str(profile["arming_label"])
				and one_step.state_label()
				== str(profile["armed_label"])
				and one_step.is_armed()
				and split_step.is_armed()
				and is_equal_approx(
					one_step.elapsed(),
					split_step.elapsed()
				)
				and is_zero_approx(one_step._motion_scale),
			"%s uses fixed, frame-step-independent timing while reduced motion freezes decoration."
			% variant_id
		)
		one_step.advance(float(profile["lifetime"]) - arm_delay)
		_check(
			one_step.expired(),
			"%s expires at its exact bounded lifetime." % variant_id
		)
		one_step.free()
		split_step.free()

	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("snare_test", "Snare Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	game._frog.global_position = Vector2(0, -520)
	game._spawn_pursuer()
	var pursuer := game._pursuer
	_check(
		is_instance_valid(pursuer)
		and not is_instance_valid(game._pursuit_trap)
		and is_equal_approx(
			game._pursuit_trap_deploy_time,
			FrogGame.PURSUIT_TRAP_DEPLOY_DELAY
		),
		"Animal Control begins pursuit before deploying one delayed snare."
	)
	if not is_instance_valid(pursuer):
		game.queue_free()
		await process_frame
		return
	pursuer.set_physics_process(false)

	game._update_navigation_paths()
	var navigation_revision_before := game._navigation.revision()
	game._frog.movement_enabled = false
	game._pursuit_trap_deploy_time = 0.0
	game._update_pursuit_trap(0.1)
	var blocked_while_rooted := not is_instance_valid(game._pursuit_trap)
	game._frog.movement_enabled = true
	game._frog.global_position = Vector2(2000, 2000)
	game._update_pursuit_trap(0.1)
	var retried_unsafe_anchor := (
		not is_instance_valid(game._pursuit_trap)
		and not game._pursuit_trap_deployed
		and is_zero_approx(game._pursuit_trap_deploy_time)
	)
	game._frog.global_position = Vector2(0, -520)
	seed(20260830)
	var expected_random := randf()
	seed(20260830)
	game._update_pursuit_trap(0.1)
	var actual_random := randf()
	var pursuit_trap := game._pursuit_trap
	_check(
		blocked_while_rooted
		and retried_unsafe_anchor
		and is_instance_valid(pursuit_trap)
		and pursuit_trap.global_position == Vector2(350, -285)
		and not pursuit_trap.is_armed()
		and is_equal_approx(actual_random, expected_random)
		and game._pursuit_trap_deployed
		and game._navigation.revision() == navigation_revision_before,
		"The snare retries unsafe anchors, then deploys deterministically without consuming RNG or changing navigation."
	)
	if not is_instance_valid(pursuit_trap):
		game.queue_free()
		await process_frame
		return
	var avoids_targets := true
	for target in game._targets:
		if (
			is_instance_valid(target)
			and target.kind != "building"
			and target.global_position.distance_to(
				pursuit_trap.global_position
			) < target.pick_radius + pursuit_trap.radius()
		):
			avoids_targets = false
	_check(
		avoids_targets
		and not game._position_inside_building(
			pursuit_trap.global_position
		)
		and game._circle_position_clear(
			pursuit_trap.global_position,
			pursuit_trap.radius(),
			true
		),
		"The draw-only snare avoids targets, buildings, and physical collision."
	)

	var score_before := 10
	game._score = score_before
	var growth_before := game._growth_points
	var target_count_before := game._targets.size()
	var discovery_count_before := game._known_discovery_count()
	game._frog.global_position = pursuit_trap.global_position
	game._update_pursuit_trap(
		PrototypePursuitTrap.ARM_DELAY * 0.5
	)
	_check(
		is_instance_valid(game._pursuit_trap)
		and not pursuit_trap.is_armed()
		and game._score == score_before,
		"The warning interval cannot trigger the snare before it arms."
	)
	game._frog.set_flying(true)
	game._update_pursuit_trap(
		PrototypePursuitTrap.ARM_DELAY * 0.5
	)
	_check(
		is_instance_valid(game._pursuit_trap)
		and pursuit_trap.is_armed()
		and game._score == score_before,
		"Flight safely crosses an armed snare."
	)
	game._frog.set_flying(false)
	game._frog.movement_enabled = false
	game._update_pursuit_trap(0.0)
	var movement_disabled_blocked := is_instance_valid(
		game._pursuit_trap
	)
	game._frog.movement_enabled = true
	game._frog.knock_back_from(
		game._frog.global_position + Vector2.LEFT
	)
	game._update_pursuit_trap(0.0)
	var knockback_blocked := is_instance_valid(game._pursuit_trap)
	game._frog.clear_knockback()
	game._net_escape_active = true
	game._update_pursuit_trap(0.0)
	var net_blocked := is_instance_valid(game._pursuit_trap)
	game._net_escape_active = false
	var immunity_target := _find_target(game, "park_chair")
	game._struggle_target = immunity_target
	game._update_pursuit_trap(0.0)
	var struggle_blocked := is_instance_valid(game._pursuit_trap)
	game._struggle_target = null
	game._pull_target = immunity_target
	game._update_pursuit_trap(0.0)
	var pull_blocked := is_instance_valid(game._pursuit_trap)
	game._pull_target = null
	game._growth_tier = GameplayTuning.ENORMOUS_TIER
	game._frog.set_growth_tier(GameplayTuning.ENORMOUS_TIER)
	game._update_pursuit_trap(0.0)
	_check(
		is_instance_valid(game._pursuit_trap)
		and movement_disabled_blocked
		and knockback_blocked
		and net_blocked
		and struggle_blocked
		and pull_blocked
		and game._score == score_before,
		"Disabled movement, knockback, netting, struggles, pulls, and enormous growth are immune to traps."
	)
	game._growth_tier = 0
	game._frog.set_growth_tier(0)
	game._damage_cooldown = 0.5
	game._update_pursuit_trap(0.0)
	var cooldown_prevented_stack := (
		is_instance_valid(game._pursuit_trap)
		and game._score == score_before
	)
	game._damage_cooldown = 0.0
	pursuer._begin_net_attack()
	pursuer._advance_net_attack(
		PrototypePursuer.NET_WINDUP_DURATION
	)
	var net_overlapped_snare := pursuer.net_attack_active()
	game._update_pursuit_trap(0.0)
	await process_frame
	_check(
		cooldown_prevented_stack
		and net_overlapped_snare
		and not pursuer.net_attack_active()
		and not is_instance_valid(game._pursuit_trap)
		and game._score == 0
		and game._growth_points == growth_before
		and game._targets.size() == target_count_before
		and game._known_discovery_count() == discovery_count_before
		and game._frog.knockback_active()
		and game._status_label.text.contains("snare"),
		"An eligible frog takes one bounded penalty and its snare cancels an overlapping net instead of stacking capture."
	)
	game._update_pursuit_trap(PrototypePursuitTrap.LIFETIME)
	_check(
		not is_instance_valid(game._pursuit_trap),
		"A triggered snare cannot redeploy during the same pursuit."
	)
	game.queue_free()
	await process_frame

	var expiry_game := game_scene.instantiate() as FrogGame
	expiry_game.configure("snare_expiry_test", "Snare Expiry Tester", false)
	root.add_child(expiry_game)
	await process_frame
	await physics_frame
	expiry_game.set_motion_scale(0.0)
	expiry_game.set_process(false)
	expiry_game._frog.set_physics_process(false)
	expiry_game._frog.global_position = Vector2(0, -520)
	expiry_game._spawn_pursuer()
	if is_instance_valid(expiry_game._pursuer):
		expiry_game._pursuer.set_physics_process(false)
	expiry_game._pursuit_trap_deploy_time = 0.0
	expiry_game._update_pursuit_trap(0.1)
	var expiring_trap := expiry_game._pursuit_trap
	_check(
		is_instance_valid(expiring_trap)
		and is_instance_valid(expiry_game._pursuer),
		"A pursuit can deploy a snare while reduced motion is enabled."
	)
	expiry_game._frog.global_position = Vector2(-300, -520)
	expiry_game._update_pursuit_trap(PrototypePursuitTrap.ARM_DELAY)
	_check(
		is_instance_valid(expiring_trap)
		and expiring_trap.is_armed(),
		"Reduced motion preserves the snare's static armed-state transition."
	)
	expiry_game._update_pursuit_trap(
		PrototypePursuitTrap.LIFETIME - PrototypePursuitTrap.ARM_DELAY
	)
	_check(
		is_instance_valid(expiry_game._pursuer)
		and not is_instance_valid(expiry_game._pursuit_trap)
		and (
			not is_instance_valid(expiring_trap)
			or expiring_trap.is_queued_for_deletion()
		),
		"An untouched snare expires on schedule even with reduced motion."
	)
	await process_frame
	expiry_game.queue_free()
	await process_frame

	var cleanup_game := game_scene.instantiate() as FrogGame
	cleanup_game.configure("snare_cleanup_test", "Snare Cleanup Tester", false)
	root.add_child(cleanup_game)
	await process_frame
	await physics_frame
	cleanup_game.set_process(false)
	cleanup_game._frog.set_physics_process(false)
	cleanup_game._frog.global_position = Vector2(0, -520)
	cleanup_game._spawn_pursuer()
	var cleanup_pursuer := cleanup_game._pursuer
	if is_instance_valid(cleanup_pursuer):
		cleanup_pursuer.set_physics_process(false)
	cleanup_game._pursuit_trap_deploy_time = 0.0
	cleanup_game._update_pursuit_trap(0.1)
	var escape_trap := cleanup_game._pursuit_trap
	if is_instance_valid(cleanup_pursuer):
		cleanup_pursuer._escape()
	await process_frame
	_check(
		not is_instance_valid(cleanup_game._pursuer)
		and not is_instance_valid(cleanup_game._pursuit_trap)
		and (
			not is_instance_valid(escape_trap)
			or escape_trap.is_queued_for_deletion()
		),
		"Ending pursuit immediately clears its temporary snare."
	)

	cleanup_game.queue_free()
	await process_frame

	var beacon_game := game_scene.instantiate() as FrogGame
	beacon_game.configure(
		"beacon_test",
		"Beacon Tester",
		false
	)
	root.add_child(beacon_game)
	await process_frame
	await physics_frame
	beacon_game.set_process(false)
	beacon_game._frog.set_physics_process(false)
	beacon_game._frog.global_position = Vector2(0, -520)
	beacon_game._spawn_pursuer(
		PrototypePursuer.ARCHETYPE_SECURITY_GUARD
	)
	var guard := beacon_game._pursuer
	if is_instance_valid(guard):
		guard.set_physics_process(false)
	beacon_game._pursuit_trap_deploy_time = 0.0
	seed(20260831)
	var expected_beacon_random := randf()
	seed(20260831)
	beacon_game._update_pursuit_trap(0.1)
	var actual_beacon_random := randf()
	var beacon := beacon_game._pursuit_trap
	_check(
		is_instance_valid(guard)
			and is_instance_valid(beacon)
			and beacon.variant_id
			== PrototypePursuitTrap.VARIANT_MOTION_BEACON
			and is_equal_approx(
				beacon_game._pursuit_trap_deploy_time,
				0.0
			)
			and is_equal_approx(
				actual_beacon_random,
				expected_beacon_random
			)
			and beacon_game._status_label.text.contains(
				"motion beacon"
			),
		"Security deploys one deterministic motion beacon with explicit warning text."
	)
	if is_instance_valid(guard) and is_instance_valid(beacon):
		var beacon_score_before := beacon_game._score
		var beacon_growth_before := beacon_game._growth_points
		var beacon_belly_before := beacon_game._belly.size()
		var beacon_targets_before := beacon_game._targets.size()
		var beacon_discoveries_before := (
			beacon_game._known_discovery_count()
		)
		var beacon_challenges_before := [
			beacon_game._challenges.progress(
				SessionChallenges.SHARP_AIM
			),
			beacon_game._challenges.progress(
				SessionChallenges.HOLD_ON
			),
			beacon_game._challenges.progress(
				SessionChallenges.CITY_TOUR
			),
			beacon_game._challenges.completed_count(),
		]
		var beacon_progression_events: Array[String] = []
		beacon_game.score_changed.connect(
			func(_score: int) -> void:
				beacon_progression_events.append("score")
		)
		beacon_game.target_discovered.connect(
			func(_target_id: String) -> void:
				beacon_progression_events.append("discovery")
		)
		beacon_game.target_swallowed.connect(
			func(_target_id: String) -> void:
				beacon_progression_events.append("swallow")
		)
		beacon_game.item_digested.connect(
			func(_target_id: String) -> void:
				beacon_progression_events.append("digest")
		)
		beacon_game.growth_tier_applied.connect(
			func(_tier: int) -> void:
				beacon_progression_events.append("growth")
		)
		beacon_game._crowd_hide_time = 0.8
		beacon_game._city_activity.crowd_hide_progress = 0.5
		beacon_game._damage_cooldown = 0.8
		beacon.global_position = beacon_game._frog.global_position
		guard._begin_flashlight_attack()
		beacon_game._update_pursuit_trap(beacon.arm_delay())
		_check(
			not is_instance_valid(beacon_game._pursuit_trap)
				and guard.flashlight_attack_active()
				and guard.frog_detected()
				and is_equal_approx(
					guard._forced_detection_left,
					PrototypePursuitTrap.BEACON_REVEAL_DURATION
				)
				and is_zero_approx(beacon_game._crowd_hide_time)
				and is_zero_approx(
					beacon_game._city_activity.crowd_hide_progress
				)
				and beacon_game._score == beacon_score_before
				and beacon_game._growth_points
				== beacon_growth_before
				and beacon_game._belly.size()
				== beacon_belly_before
				and beacon_game._targets.size()
				== beacon_targets_before
				and beacon_game._known_discovery_count()
				== beacon_discoveries_before
				and [
					beacon_game._challenges.progress(
						SessionChallenges.SHARP_AIM
					),
					beacon_game._challenges.progress(
						SessionChallenges.HOLD_ON
					),
					beacon_game._challenges.progress(
						SessionChallenges.CITY_TOUR
					),
					beacon_game._challenges.completed_count(),
				] == beacon_challenges_before
				and beacon_progression_events.is_empty()
				and not beacon_game._frog.knockback_active()
				and not beacon_game._net_escape_active,
			"The beacon can overlap a flashlight warning but only reveals the frog and clears crowd cover."
		)

		guard.global_position = Vector2(0, 320)
		beacon_game._frog.global_position = Vector2(100, 320)
		var sight_blocker := StaticBody2D.new()
		sight_blocker.position = Vector2(50, 320)
		sight_blocker.collision_layer = 1
		var sight_collision := CollisionShape2D.new()
		var sight_shape := CircleShape2D.new()
		sight_shape.radius = 34.0
		sight_collision.shape = sight_shape
		sight_blocker.add_child(sight_collision)
		beacon_game._world.add_child(sight_blocker)
		await physics_frame
		guard._update_detection(
			PrototypePursuitTrap.BEACON_REVEAL_DURATION * 0.5
		)
		var reveal_active := guard.frog_detected()
		guard._update_detection(
			PrototypePursuitTrap.BEACON_REVEAL_DURATION * 0.5
		)
		_check(
			reveal_active
				and not guard.frog_detected()
				and is_zero_approx(guard._forced_detection_left),
			"Beacon detection crosses walls only for its exact two-second reveal window."
		)
		sight_blocker.queue_free()
		beacon_game._update_pursuit_trap(
			PrototypePursuitTrap.BEACON_REVEAL_DURATION
		)
		_check(
			not is_instance_valid(beacon_game._pursuit_trap),
			"A triggered beacon cannot redeploy during the same pursuit."
		)
	beacon_game.queue_free()
	await process_frame

	var sticky_game := game_scene.instantiate() as FrogGame
	sticky_game.configure(
		"sticky_test",
		"Sticky Tester",
		false
	)
	root.add_child(sticky_game)
	await process_frame
	await physics_frame
	sticky_game.set_process(false)
	sticky_game._frog.set_physics_process(false)
	sticky_game._frog.global_position = Vector2(0, -520)
	sticky_game._spawn_pursuer(PrototypePursuer.ARCHETYPE_WATCHDOG)
	var watchdog := sticky_game._pursuer
	if is_instance_valid(watchdog):
		watchdog.set_physics_process(false)
	sticky_game._pursuit_trap_deploy_time = 0.0
	seed(20260901)
	var expected_sticky_random := randf()
	seed(20260901)
	sticky_game._update_pursuit_trap(0.1)
	var actual_sticky_random := randf()
	var sticky_patch := sticky_game._pursuit_trap
	_check(
		is_instance_valid(watchdog)
			and is_instance_valid(sticky_patch)
			and sticky_patch.variant_id
			== PrototypePursuitTrap.VARIANT_STICKY_PATCH
			and is_equal_approx(
				actual_sticky_random,
				expected_sticky_random
			)
			and sticky_game._status_label.text.contains(
				"sticky scent patch"
			),
		"Watchdog deploys one deterministic sticky patch with explicit warning text."
	)
	if is_instance_valid(watchdog) and is_instance_valid(sticky_patch):
		var sticky_score_before := sticky_game._score
		var sticky_growth_before := sticky_game._growth_points
		var sticky_belly_before := sticky_game._belly.size()
		var sticky_targets_before := sticky_game._targets.size()
		var sticky_discoveries_before := (
			sticky_game._known_discovery_count()
		)
		var sticky_challenges_before := [
			sticky_game._challenges.progress(
				SessionChallenges.SHARP_AIM
			),
			sticky_game._challenges.progress(
				SessionChallenges.HOLD_ON
			),
			sticky_game._challenges.progress(
				SessionChallenges.CITY_TOUR
			),
			sticky_game._challenges.completed_count(),
		]
		sticky_game._damage_cooldown = 0.8
		sticky_patch.global_position = (
			sticky_game._frog.global_position
		)
		watchdog._begin_lunge_attack()
		sticky_game._update_pursuit_trap(
			sticky_patch.arm_delay()
		)
		_check(
			not is_instance_valid(sticky_game._pursuit_trap)
				and watchdog.lunge_attack_active()
				and is_equal_approx(
					sticky_game._tongue_recovery,
					PrototypePursuitTrap.STICKY_TONGUE_RECOVERY
				)
				and sticky_game._frog.movement_enabled
				and not sticky_game._frog.knockback_active()
				and not sticky_game._net_escape_active
				and sticky_game._score == sticky_score_before
				and sticky_game._growth_points
				== sticky_growth_before
				and sticky_game._belly.size()
				== sticky_belly_before
				and sticky_game._targets.size()
				== sticky_targets_before
				and sticky_game._known_discovery_count()
				== sticky_discoveries_before
				and [
					sticky_game._challenges.progress(
						SessionChallenges.SHARP_AIM
					),
					sticky_game._challenges.progress(
						SessionChallenges.HOLD_ON
					),
					sticky_game._challenges.progress(
						SessionChallenges.CITY_TOUR
					),
					sticky_game._challenges.completed_count(),
				] == sticky_challenges_before,
			"The sticky patch can overlap a lunge warning but only delays the tongue while movement stays available."
		)
		sticky_game._process(
			PrototypePursuitTrap.STICKY_TONGUE_RECOVERY * 0.5
		)
		var sticky_half_time := sticky_game._tongue_recovery
		sticky_game._process(
			PrototypePursuitTrap.STICKY_TONGUE_RECOVERY * 0.5
		)
		_check(
			is_equal_approx(
				sticky_half_time,
				PrototypePursuitTrap.STICKY_TONGUE_RECOVERY
				* 0.5
			)
				and is_zero_approx(sticky_game._tongue_recovery)
				and sticky_game._frog.movement_enabled,
			"Sticky tongue recovery expires exactly without immobilizing the frog."
		)
		sticky_game._update_pursuit_trap(
			PrototypePursuitTrap.STICKY_TONGUE_RECOVERY
		)
		_check(
			not is_instance_valid(sticky_game._pursuit_trap),
			"A triggered sticky patch cannot redeploy during the same pursuit."
		)
	sticky_game.queue_free()
	await process_frame

	var district_game := game_scene.instantiate() as FrogGame
	district_game.configure(
		"trap_district_test",
		"Trap District Tester",
		false
	)
	root.add_child(district_game)
	await process_frame
	await physics_frame
	district_game.set_process(false)
	district_game._frog.set_physics_process(false)
	var first_coordinate := Vector2i(2, 2)
	district_game._frog.global_position = (
		DistrictGenerator.bounds_for_coordinate(
			first_coordinate
		).get_center()
	)
	district_game._update_district_streaming()
	district_game._spawn_pursuer(
		PrototypePursuer.ARCHETYPE_SECURITY_GUARD
	)
	if is_instance_valid(district_game._pursuer):
		district_game._pursuer.set_physics_process(false)
	district_game._pursuit_trap_deploy_time = 0.0
	district_game._update_pursuit_trap(0.1)
	var district_trap := district_game._pursuit_trap
	var first_loaded_count := district_game._loaded_districts.size()
	district_game._frog.global_position = (
		DistrictGenerator.bounds_for_coordinate(
			Vector2i(4, 2)
		).get_center()
	)
	district_game._update_district_streaming()
	await process_frame
	_check(
		first_loaded_count
			== DistrictGenerator.MAX_LOADED_GENERATED_DISTRICTS
			and is_instance_valid(district_game._pursuer)
			and not is_instance_valid(district_game._pursuit_trap)
			and (
				not is_instance_valid(district_trap)
				or district_trap.is_queued_for_deletion()
			)
			and not district_game._loaded_districts.has(
				first_coordinate + Vector2i(-1, -1)
			),
		"Changing generated-district rings unloads old content and clears its temporary trap without ending pursuit."
	)
	district_game.queue_free()
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
	startup_ids["security_guard"] = true
	startup_ids["watchdog"] = true
	for target_id in DistrictGenerator.discovery_ids():
		startup_ids[target_id] = true
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
		catalog_matches_targets,
		"Field Guide catalog exactly matches authored and generated target types."
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
	var guide_pages := game._guide_pages()
	for page_index in guide_pages.size():
		if str(guide_pages[page_index]["title"]) == "FIELD GUIDE":
			game._guide_page_index = page_index
			break
	game._rebuild_guide()
	var guide_row := game._guide_list.get_child(0) as Label
	_check(
		game._guide_list.get_child_count() == 1
		and guide_row.text.contains("Street Donut")
		and not guide_row.text.contains("Runaway Hot Dog")
		and guide_row.text.contains("Hint:")
		and not game._previous_guide_page_button.disabled
		and not game._next_guide_page_button.disabled,
		"Guide pages reveal found names, protect unknown names, and keep one bounded text row."
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

	game._growth_tier = GameplayTuning.ENORMOUS_TIER
	game._frog.set_growth_tier(GameplayTuning.ENORMOUS_TIER)
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
	game._growth_tier = GameplayTuning.ENORMOUS_TIER
	game._frog.set_growth_tier(GameplayTuning.ENORMOUS_TIER)
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
	await physics_frame
	await process_frame
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


func _test_oddities_shop_hours(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.configure("shop_hours_test", "Shop Hours Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var shop := (
		game._building_by_id.get("oddities_shop") as PrototypeBuilding
	)
	var shutter := _find_target(game, "oddities_shop_door")
	_check(
		FrogGame.oddities_shop_open_for_clock(0.0)
		and FrogGame.oddities_shop_open_for_clock(0.18)
		and not FrogGame.oddities_shop_open_for_clock(0.1801)
		and not FrogGame.oddities_shop_open_for_clock(0.5)
		and not FrogGame.oddities_shop_open_for_clock(0.7799)
		and FrogGame.oddities_shop_open_for_clock(0.78)
		and FrogGame.oddities_shop_open_for_clock(1.0),
		"Oddities Shop hours use one deterministic night window with explicit boundaries."
	)
	_check(
		is_instance_valid(shop)
		and is_instance_valid(shutter)
		and not game._oddities_shop_scheduled_open
		and not shop.entrance_part_temporarily_open
		and shop._door_body.collision_layer == 1
		and shutter.visible
		and shutter.selectable,
		"Oddities Shop starts closed during its authored daytime phase."
	)

	var daytime_snapshot := game.performance_structure_snapshot()
	var score_before := game._score
	var growth_before := game._growth_points
	var target_count_before := game._targets.size()
	var discovery_count_before := game._known_discovery_count()
	seed(20260830)
	var expected_random := randf()
	seed(20260830)
	game._day_clock = 0.0
	game._update_day_night(0.0)
	var actual_random := randf()
	await physics_frame
	var night_snapshot := game.performance_structure_snapshot()
	_check(
		game._oddities_shop_scheduled_open
		and shop.entrance_part_temporarily_open
		and shop._door_body.collision_layer == 0
		and not shutter.visible
		and not shutter.selectable
		and shop.weakness_count() == 0
		and is_equal_approx(actual_random, expected_random),
		"The intact shutter raises at night without weakening the shop or using gameplay RNG."
	)
	_check(
		int(night_snapshot["game_nodes"])
		== int(daytime_snapshot["game_nodes"])
		and int(night_snapshot["collision_objects"])
		== int(daytime_snapshot["collision_objects"])
		and int(night_snapshot["collision_shapes"])
		== int(daytime_snapshot["collision_shapes"])
		and game._score == score_before
		and game._growth_points == growth_before
		and game._targets.size() == target_count_before
		and game._known_discovery_count() == discovery_count_before,
		"Scheduled opening changes no structure, rewards, targets, or progression."
	)

	game._frog.global_position = shop.global_position
	game._day_clock = 0.5
	game._update_day_night(0.0)
	_check(
		game._oddities_shop_scheduled_open
		and shop._door_body.collision_layer == 0
		and not shutter.visible,
		"Daytime closure waits while the frog remains inside Oddities Shop."
	)
	game._frog.global_position = shop.global_position + Vector2(0, -260)
	game._spawn_pursuer()
	var pursuer := game._pursuer
	if is_instance_valid(pursuer):
		pursuer.set_physics_process(false)
		pursuer.global_position = shop.global_position
	game._update_day_night(0.0)
	_check(
		is_instance_valid(pursuer)
		and game._oddities_shop_scheduled_open
		and shop._door_body.collision_layer == 0,
		"Daytime closure also waits while Animal Control occupies the shop."
	)
	if is_instance_valid(pursuer):
		pursuer.global_position = shop.global_position + Vector2(0, -360)
	game._update_day_night(0.0)
	await physics_frame
	_check(
		not game._oddities_shop_scheduled_open
		and not shop.entrance_part_temporarily_open
		and shop._door_body.collision_layer == 1
		and shutter.visible
		and shutter.selectable,
		"The shutter lowers once the shop and doorway are clear."
	)
	if is_instance_valid(pursuer):
		pursuer._escape()
		await process_frame

	game._frog.global_position = shop.global_position + Vector2(0, -310)
	game._swallow_target(shutter, 1.0)
	game._day_clock = 0.0
	game._update_day_night(0.0)
	game._day_clock = 0.5
	game._update_day_night(0.0)
	_check(
		shop.weakness_count() == 1
		and shop.is_part_removed(PrototypeBuilding.PART_DOOR)
		and shop._door_body.collision_layer == 0
		and not is_instance_valid(
			game._find_target_by_id("oddities_shop_door")
		),
		"Eating the shutter permanently overrides later opening and closing times."
	)

	game.queue_free()
	await process_frame


func _test_moonlight_market_hours(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.configure("market_hours_test", "Market Hours Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var market := (
		game._building_by_id.get("moonlight_market")
		as PrototypeBuilding
	)
	var market_door := _find_target(game, "moonlight_market_door")
	_check(
		not FrogGame.moonlight_market_open_for_clock(0.2999)
		and FrogGame.moonlight_market_open_for_clock(0.30)
		and FrogGame.moonlight_market_open_for_clock(0.5799)
		and not FrogGame.moonlight_market_open_for_clock(0.58)
		and not FrogGame.moonlight_market_open_for_clock(0.9)
		and FrogGame.moonlight_market_open_for_clock(1.30),
		"Moonlight Market uses one deterministic daytime schedule with explicit boundaries."
	)
	_check(
		is_instance_valid(market)
		and is_instance_valid(market_door)
		and not game._moonlight_market_scheduled_open
		and not market.entrance_part_temporarily_open
		and market._door_body.collision_layer == 1
		and market_door.visible
		and market_door.selectable,
		"Moonlight Market starts closed before its authored daytime hours."
	)

	var closed_snapshot := game.performance_structure_snapshot()
	var score_before := game._score
	var growth_before := game._growth_points
	var belly_before := game._belly.size()
	var target_count_before := game._targets.size()
	var discovery_count_before := game._known_discovery_count()
	var challenge_progress_before := [
		game._challenges.progress(SessionChallenges.SHARP_AIM),
		game._challenges.progress(SessionChallenges.HOLD_ON),
		game._challenges.progress(SessionChallenges.CITY_TOUR),
		game._challenges.completed_count(),
	]
	seed(20260901)
	var expected_random := randf()
	seed(20260901)
	game._day_clock = 0.57
	game._update_day_night(0.0)
	var actual_random := randf()
	await physics_frame
	var open_snapshot := game.performance_structure_snapshot()
	_check(
		game._moonlight_market_scheduled_open
		and market.entrance_part_temporarily_open
		and market._door_body.collision_layer == 0
		and not market_door.visible
		and not market_door.selectable
		and market.weakness_count() == 0
		and is_equal_approx(actual_random, expected_random),
		"Moonlight Market opens during the day without weakening its removable door or consuming gameplay RNG."
	)
	_check(
		int(open_snapshot["game_nodes"])
		== int(closed_snapshot["game_nodes"])
		and int(open_snapshot["collision_objects"])
		== int(closed_snapshot["collision_objects"])
		and int(open_snapshot["collision_shapes"])
		== int(closed_snapshot["collision_shapes"])
		and game._score == score_before
		and game._growth_points == growth_before
		and game._belly.size() == belly_before
		and game._targets.size() == target_count_before
		and game._known_discovery_count() == discovery_count_before
		and challenge_progress_before == [
			game._challenges.progress(SessionChallenges.SHARP_AIM),
			game._challenges.progress(SessionChallenges.HOLD_ON),
			game._challenges.progress(SessionChallenges.CITY_TOUR),
			game._challenges.completed_count(),
		],
		"Daytime market hours change no structure, rewards, targets, Belly state, discoveries, or challenges."
	)

	game._frog.global_position = market.global_position
	game._day_clock = 0.58
	game._update_day_night(0.0)
	_check(
		game._moonlight_market_scheduled_open
		and market._door_body.collision_layer == 0,
		"Rain-boundary closure waits while the frog remains inside Moonlight Market."
	)
	game._frog.global_position = market.global_position + Vector2(0, 330)
	game._spawn_pursuer(PrototypePursuer.ARCHETYPE_WATCHDOG)
	var watchdog := game._pursuer
	if is_instance_valid(watchdog):
		watchdog.set_physics_process(false)
		watchdog.global_position = market.global_position
	game._update_day_night(0.0)
	_check(
		is_instance_valid(watchdog)
		and game._moonlight_market_scheduled_open
		and market._door_body.collision_layer == 0,
		"Rain-boundary closure waits while a Watchdog occupies the market."
	)
	if is_instance_valid(watchdog):
		watchdog.global_position = market.global_position + Vector2(0, 380)
	game._active_interior_id = FrogGame.MARKET_ROOFTOP_ID
	game._update_day_night(0.0)
	_check(
		game._moonlight_market_scheduled_open
		and market._door_body.collision_layer == 0,
		"Market closure waits while the frog uses the connected rooftop."
	)
	game._active_interior_id = ""
	game._update_day_night(0.0)
	await physics_frame
	_check(
		not game._moonlight_market_scheduled_open
		and not market.entrance_part_temporarily_open
		and market._door_body.collision_layer == 1
		and market_door.visible
		and market_door.selectable,
		"Moonlight Market closes once its hall, doorway, pursuer, and connected room are clear."
	)
	if is_instance_valid(watchdog):
		watchdog._escape()
		await process_frame

	game._frog.global_position = market.global_position + Vector2(0, 330)
	game._swallow_target(market_door, 1.0)
	game._day_clock = 0.57
	game._update_day_night(0.0)
	game._day_clock = 0.7
	game._update_day_night(0.0)
	_check(
		market.weakness_count() == 1
		and market.is_part_removed(PrototypeBuilding.PART_DOOR)
		and market._door_body.collision_layer == 0
		and not game._moonlight_market_scheduled_open
		and not is_instance_valid(
			game._find_target_by_id("moonlight_market_door")
		),
		"Eating the market door permanently overrides all later opening and closing times."
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
			"Leap Café is weak, but the frog must reach large growth"
		),
		"The fully weakened cafe still requires large growth."
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
	await physics_frame
	await process_frame
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
	await physics_frame
	await process_frame
	game._spit_item(0)
	await physics_frame
	await process_frame
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
			"Canal Apartments is weak, but the frog must reach large growth"
		),
		"The fully weakened apartments still require large growth."
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
	await physics_frame
	await process_frame
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
	await physics_frame
	await process_frame
	game._spit_item(0)
	await physics_frame
	await process_frame
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
	apartments.consume()
	await process_frame
	_check(
		game._circle_position_clear(
			Vector2(-798, 1246),
			24.0,
			true
		),
		"Consuming a furnished building disables its interior prop collision."
	)
	apartments.restore()
	await physics_frame
	await process_frame
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


func _test_cafe_stockroom(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("stockroom_test", "Stockroom Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var cafe := (
		game._building_by_id.get("leap_cafe") as PrototypeBuilding
	)
	var stockroom := (
		game._interior_rooms.get(FrogGame.STOCKROOM_ID)
		as PrototypeInteriorRoom
	)
	var coffee_tin := _find_target(
		game,
		"cafe_stockroom_coffee_tin"
	)
	_check(
		is_instance_valid(cafe)
		and is_instance_valid(stockroom)
		and is_instance_valid(coffee_tin)
		and game._interior_rooms.size() == 10
		and stockroom.room_size == Vector2(1100, 820)
		and stockroom.exit_marker_position()
		== stockroom.global_position + Vector2(0, 300)
		and stockroom.entry_position().distance_to(
			stockroom.exit_marker_position()
		) > 62.0
		and stockroom._collision_body.get_child_count() == 8
		and coffee_tin.building_id == FrogGame.STOCKROOM_ID
		and coffee_tin.move_bounds == stockroom.interior_rect(),
		"Leap Cafe creates one solid stockroom and its room-scoped Coffee Tin."
	)
	_check(
		cafe.transition_door_hit_test(
			cafe.transition_door_world_position()
		)
		and game._circle_position_clear(
			cafe.transition_door_approach_position(),
			44.0,
			true
		),
		"The marked cafe door has a maximum-size-safe approach point."
	)
	_check(
		not game._circle_position_clear(
			stockroom.global_position + stockroom.props[0].get_center(),
			28.0,
			true
		)
		and game._circle_position_clear(
			stockroom.global_position,
			44.0,
			true
		),
		"Stockroom shelving is solid while the central aisle admits the maximum frog."
	)

	game._frog.global_position = cafe.global_position
	var city_camera_rotation := 0.35
	game._camera.rotation = city_camera_rotation
	var handled_entry := game._try_handle_interior_transition_tap(
		cafe.transition_door_world_position()
	)
	_check(
		handled_entry
		and game._pending_interior_transition == FrogGame.STOCKROOM_ID
		and game._frog._has_move_target
		and game._frog._move_target
		== cafe.transition_door_approach_position(),
		"A stockroom tap walks the frog to the cafe door when needed."
	)
	game._frog.global_position = cafe.transition_door_approach_position()
	game._frog.knock_back_from(cafe.global_position + Vector2.LEFT)
	game._on_frog_move_reached(game._frog.global_position)
	game._update_interior_transition(
		FrogGame.INTERIOR_TRANSITION_DURATION * 0.5
	)
	_check(
		game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.FADE_OUT
		and game._interior_transition_fade.visible
		and is_equal_approx(
			game._interior_transition_fade.color.a,
			0.5
		)
		and is_zero_approx(game._frog._knockback_time)
		and game._frog._knockback_velocity == Vector2.ZERO
		and paused
		and not game._frog.movement_enabled,
		"Full-motion entry pauses play behind a short opaque fade."
	)
	game._update_interior_transition(
		FrogGame.INTERIOR_TRANSITION_DURATION * 0.5
	)
	_check(
		game._active_interior_id == FrogGame.STOCKROOM_ID
		and game._frog.global_position == stockroom.entry_position()
		and game._camera.global_position == stockroom.global_position
		and game._camera.zoom == FrogGame.STOCKROOM_CAMERA_ZOOM
		and is_zero_approx(game._camera.rotation)
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.FADE_IN,
		"The fade midpoint transfers the frog and switches to the room camera."
	)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		not paused
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE
		and not game._interior_transition_fade.visible
		and game._frog.movement_enabled
		and game._active_navigation_rect() == stockroom.interior_rect()
		and game._end_button.text == "Exit Room"
		and not game._end_button.disabled
		and game._end_button.custom_minimum_size.y >= 48.0
		and game._status_label.text.contains("Exit Room")
		and game._close_belly_button.text == "Back to Game"
		and game._close_guide_button.text == "Back to Game"
		and game._close_options_button.text == "Back to Game",
		"Completing entry exposes a production-sized room exit and honest overlay labels."
	)
	game._input_assist_mode = AccessibilityPresentation.INPUT_ASSIST_HOLD
	_check(
		game._default_status_text().contains("hold targets to eat")
		and game._default_status_text().contains("Exit Room"),
		"Interior status preserves the selected eating assistance."
	)
	game._input_assist_mode = AccessibilityPresentation.INPUT_ASSIST_STANDARD
	game._rotate_camera(180.0, Vector2(640, 480))
	_check(
		is_zero_approx(game._camera.rotation),
		"Camera gestures cannot rotate the tightly framed stockroom."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._pending_growth_tier = 2
	game._frog.global_position = stockroom.global_position
	game._last_safe_ground_position = stockroom.global_position
	game._retry_pending_growth()
	_check(
		game._growth_tier == 2
		and game._pending_growth_tier == -1
		and stockroom.interior_rect().has_point(
			game._frog.global_position
		),
		"The stockroom central aisle supports maximum-size growth."
	)
	game._spawn_pursuer()
	_check(
		not is_instance_valid(game._pursuer)
		and game._status_label.text.contains("cannot find"),
		"Animal Control cannot spawn remotely inside the stockroom."
	)

	game._frog.global_position = coffee_tin.global_position + Vector2(0, 100)
	game._swallow_target(coffee_tin, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id
		== "cafe_stockroom_coffee_tin"
		and game._belly[0].movement_bounds
		== stockroom.interior_rect(),
		"Swallowing the Coffee Tin preserves its stockroom restock bounds."
	)
	game._spit_item(0)
	var spat_tin := _find_target(
		game,
		"cafe_stockroom_coffee_tin"
	)
	_check(
		game._belly.is_empty()
		and is_instance_valid(spat_tin)
		and stockroom.interior_rect().has_point(spat_tin.global_position),
		"Spitting the Coffee Tin while inside returns it within the stockroom."
	)
	game._swallow_target(spat_tin, 1.0)

	game._frog.global_position = stockroom.global_position
	game._on_context_action_pressed()
	_check(
		game._pending_interior_transition == "city"
		and game._pending_interior_portal_id == "return"
		and game._frog._has_move_target
		and game._status_label.text.contains("RETURN TO CAFE"),
		"The Exit Room action routes toward the labelled stockroom return door."
	)
	game._frog.global_position = stockroom.exit_approach_position()
	game._on_frog_move_reached(game._frog.global_position)
	_check(
		game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.FADE_OUT,
		"Reaching the routed stockroom exit starts the bounded transition."
	)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		game._active_interior_id.is_empty()
		and game._frog.global_position
		== cafe.transition_door_approach_position()
		and game._camera.zoom == game._city_camera_zoom
		and is_equal_approx(
			game._camera.rotation,
			city_camera_rotation
		)
		and game._active_navigation_rect() == FrogGame.WORLD_RECT
		and game._end_button.text == "End Game"
		and game._end_button.disabled,
		"Exiting restores the city state while keeping End Game briefly guarded."
	)
	game._on_context_action_pressed()
	_check(
		not is_instance_valid(game._score_epilogue),
		"An extra room-exit press cannot immediately end the game."
	)
	game._process(FrogGame.CONTEXT_ACTION_GRACE_DURATION)
	_check(
		not game._end_button.disabled,
		"End Game becomes available after the room-exit grace period."
	)
	game._spit_item(0)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id
		== "cafe_stockroom_coffee_tin"
		and game._status_label.text.contains("stockroom"),
		"A Coffee Tin carried outside cannot be spat into the city."
	)
	game._digest_item(0)

	game._frog.global_position = Vector2(0, -520)
	game._spawn_pursuer()
	var pursuing_before_entry := is_instance_valid(game._pursuer)
	if pursuing_before_entry:
		game._pursuer.set_physics_process(false)
	game._roadblock_deploy_time = 0.0
	game._update_pursuit_roadblock(0.1)
	var transition_roadblock := game._roadblock
	game._pursuit_trap_deploy_time = 0.0
	game._update_pursuit_trap(0.1)
	var transition_trap := game._pursuit_trap
	game._frog.global_position = cafe.transition_door_approach_position()
	game._begin_interior_transition(FrogGame.STOCKROOM_ID)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		pursuing_before_entry
		and not is_instance_valid(game._pursuer)
		and not is_instance_valid(game._roadblock)
		and (
			not is_instance_valid(transition_roadblock)
			or transition_roadblock.collision_layer == 0
		)
		and not is_instance_valid(game._pursuit_trap)
		and (
			not is_instance_valid(transition_trap)
			or transition_trap.is_queued_for_deletion()
		)
		and game._active_interior_id == FrogGame.STOCKROOM_ID,
		"Entering the stockroom clears Animal Control, its roadblock, and its trap."
	)

	game.set_motion_scale(0.0)
	game._begin_interior_transition("city")
	_check(
		game._active_interior_id.is_empty()
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE
		and not game._interior_transition_fade.visible
		and not paused,
		"Reduce motion changes stockroom travel to an immediate cut."
	)

	cafe.consume()
	game._frog.global_position = cafe.global_position
	_check(
		not cafe.transition_door_hit_test(
			cafe.transition_door_world_position()
		)
		and not game._try_handle_interior_transition_tap(
			cafe.transition_door_world_position()
		),
		"Consuming Leap Cafe hides and disables stockroom entry."
	)
	cafe.restore()
	_check(
		cafe.transition_door_hit_test(
			cafe.transition_door_world_position()
		),
		"Restoring Leap Cafe restores stockroom access."
	)

	await create_timer(9.2, false).timeout
	var restocked_tin := _find_target(
		game,
		"cafe_stockroom_coffee_tin"
	)
	_check(
		is_instance_valid(restocked_tin)
		and stockroom.interior_rect().has_point(
			restocked_tin.global_position
		)
		and game._active_interior_id.is_empty(),
		"Digesting the Coffee Tin restocks it inside the room after returning to the city."
	)

	paused = false
	game.queue_free()
	await process_frame


func _test_oddities_cellar(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("cellar_test", "Cellar Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var shop := (
		game._building_by_id.get("oddities_shop")
		as PrototypeBuilding
	)
	var cellar := (
		game._interior_rooms.get(FrogGame.ODDITIES_CELLAR_ID)
		as PrototypeInteriorRoom
	)
	var shelf := _find_target(game, "oddities_shop_counter")
	var music_box := _find_target(game, "oddities_cellar_music_box")
	_check(
		is_instance_valid(shop)
		and is_instance_valid(cellar)
		and is_instance_valid(shelf)
		and is_instance_valid(music_box)
		and game._interior_rooms.size() == 10
		and shop.transition_room_id == FrogGame.ODDITIES_CELLAR_ID
		and shop.transition_required_removed_part
		== PrototypeBuilding.PART_COUNTER
		and shop.transition_required_part_label == "Curio Shelf"
		and cellar.return_label == "RETURN TO SHOP"
		and cellar._collision_body.get_child_count() == 8
		and music_box.size_tier == 1
		and music_box.resistant
		and music_box.building_id == FrogGame.ODDITIES_CELLAR_ID
		and music_box.move_bounds == cellar.interior_rect(),
		"Oddities Shop creates one fixture-gated cellar and its room-scoped Music Box."
	)
	_check(
		not shop.transition_door_hit_test(
			shop.transition_door_world_position()
		)
		and game._circle_position_clear(
			shop.transition_door_approach_position(),
			44.0,
			true
		)
		and not game._circle_position_clear(
			cellar.global_position + cellar.props[0].get_center(),
			28.0,
			true
		)
		and game._circle_position_clear(
			cellar.global_position,
			44.0,
			true
		),
		"The covered trapdoor has a safe approach and the cellar retains maximum-size-safe clear space."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._frog.global_position = shop.global_position + Vector2(-150, 100)
	game._begin_interior_transition(FrogGame.ODDITIES_CELLAR_ID)
	_check(
		game._active_interior_id.is_empty()
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE
		and game._frog.movement_enabled,
		"Direct transition calls cannot bypass the cellar's shelf prerequisite."
	)

	game._swallow_target(shelf, 1.0)
	game._digest_item(0)
	game._day_clock = 0.0
	game._update_oddities_shop_schedule()
	var city_camera_rotation := -0.24
	game._camera.rotation = city_camera_rotation
	var handled_entry := game._try_handle_interior_transition_tap(
		shop.transition_door_world_position()
	)
	_check(
		handled_entry
		and shop.is_part_removed(PrototypeBuilding.PART_COUNTER)
		and shop.transition_door_hit_test(
			shop.transition_door_world_position()
		)
		and game._pending_interior_transition
		== FrogGame.ODDITIES_CELLAR_ID
		and game._frog._move_target
		== shop.transition_door_approach_position(),
		"Removing the Curio Shelf unlocks a walk to the cellar trapdoor."
	)
	game._frog.global_position = shop.transition_door_approach_position()
	game._spawn_pursuer()
	var pursuit_started := is_instance_valid(game._pursuer)
	if pursuit_started:
		game._pursuer.set_physics_process(false)
	game._on_frog_move_reached(game._frog.global_position)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		pursuit_started
		and not is_instance_valid(game._pursuer)
		and game._active_interior_id == FrogGame.ODDITIES_CELLAR_ID
		and game._frog.global_position == cellar.entry_position()
		and game._camera.global_position == cellar.global_position
		and game._camera.zoom == FrogGame.STOCKROOM_CAMERA_ZOOM
		and is_zero_approx(game._camera.rotation)
		and game._active_navigation_rect() == cellar.interior_rect(),
		"Entering the cellar uses the fixed room camera and ends active pursuit."
	)
	game._spawn_pursuer()
	_check(
		not is_instance_valid(game._pursuer)
		and game._status_label.text.contains("cannot find"),
		"Animal Control cannot spawn remotely in the cellar."
	)
	game._day_clock = 0.5
	game._update_oddities_shop_schedule()
	_check(
		game._oddities_shop_scheduled_open
		and shop.entrance_part_temporarily_open
		and shop._door_body.collision_layer == 0,
		"Daytime closure waits while the frog explores the connected cellar."
	)

	game._pending_growth_tier = 2
	game._frog.global_position = cellar.global_position
	game._last_safe_ground_position = cellar.global_position
	game._retry_pending_growth()
	_check(
		game._growth_tier == 2
		and game._pending_growth_tier == -1
		and cellar.interior_rect().has_point(game._frog.global_position),
		"The cellar aisle supports maximum-size growth."
	)

	game._frog.global_position = music_box.global_position + Vector2(0, 110)
	game._swallow_target(music_box, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id == "oddities_cellar_music_box"
		and game._belly[0].movement_bounds == cellar.interior_rect(),
		"Swallowing the Music Box preserves its cellar restock bounds."
	)
	game._spit_item(0)
	var spat_music_box := _find_target(
		game,
		"oddities_cellar_music_box"
	)
	_check(
		game._belly.is_empty()
		and is_instance_valid(spat_music_box)
		and cellar.interior_rect().has_point(
			spat_music_box.global_position
		),
		"Spitting the Music Box in the cellar returns it within the room."
	)
	game._swallow_target(spat_music_box, 1.0)

	game.set_motion_scale(0.0)
	game._frog.global_position = cellar.exit_approach_position()
	var handled_exit := game._try_handle_interior_transition_tap(
		cellar.exit_marker_position()
	)
	_check(
		handled_exit
		and game._active_interior_id.is_empty()
		and game._frog.global_position
		== shop.transition_door_approach_position()
		and is_equal_approx(game._camera.rotation, city_camera_rotation),
		"The cellar trapdoor returns to the shop immediately with Reduce motion."
	)
	game._spit_item(0)
	_check(
		game._belly.size() == 1
		and game._status_label.text.contains("curio cellar"),
		"A Music Box carried upstairs cannot be spat into the shop."
	)
	game._digest_item(0)
	game._frog.global_position = shop.global_position + Vector2(0, -310)
	game._update_oddities_shop_schedule()
	_check(
		not game._oddities_shop_scheduled_open
		and not shop.entrance_part_temporarily_open
		and shop._door_body.collision_layer == 1,
		"The shutter closes only after the frog leaves the cellar and shop."
	)

	shop.consume()
	_check(
		not shop.transition_door_hit_test(
			shop.transition_door_world_position()
		),
		"Consuming Oddities Shop disables cellar access."
	)
	shop.restore()
	_check(
		shop.is_part_removed(PrototypeBuilding.PART_COUNTER)
		and shop.transition_door_hit_test(
			shop.transition_door_world_position()
		),
		"Restoring the shop preserves the removed shelf and cellar access."
	)

	paused = false
	game.queue_free()
	await process_frame


func _test_market_rooftop(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("rooftop_test", "Rooftop Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var market := (
		game._building_by_id.get("moonlight_market") as PrototypeBuilding
	)
	var rooftop := (
		game._interior_rooms.get(FrogGame.MARKET_ROOFTOP_ID)
		as PrototypeInteriorRoom
	)
	var beehive := _find_target(game, "market_rooftop_beehive")
	_check(
		is_instance_valid(market)
		and is_instance_valid(rooftop)
		and is_instance_valid(beehive)
		and game._interior_rooms.size() == 10
		and market.transition_room_id == FrogGame.MARKET_ROOFTOP_ID
		and market.transition_min_growth_tier == 1
		and rooftop.return_label == "RETURN TO MARKET"
		and rooftop._collision_body.get_child_count() == 8
		and beehive.size_tier == 1
		and beehive.resistant
		and beehive.building_id == FrogGame.MARKET_ROOFTOP_ID
		and beehive.move_bounds == rooftop.interior_rect(),
		"Moonlight Market creates one progression-gated rooftop and its room-scoped Beehive."
	)
	_check(
		market.transition_door_hit_test(
			market.transition_door_world_position()
		)
		and game._circle_position_clear(
			market.transition_door_approach_position(),
			44.0,
			true
		)
		and not game._circle_position_clear(
			rooftop.global_position + rooftop.props[0].get_center(),
			28.0,
			true
		)
		and game._circle_position_clear(
			rooftop.global_position,
			44.0,
			true
		),
		"The market ladder and rooftop garden retain maximum-size-safe clear space."
	)

	game._frog.global_position = market.global_position + Vector2(180, 120)
	var handled_locked := game._try_handle_interior_transition_tap(
		market.transition_door_world_position()
	)
	_check(
		handled_locked
		and game._pending_interior_transition.is_empty()
		and not game._frog._has_move_target
		and game._status_label.text.contains("Grow once"),
		"The rooftop ladder refuses a starting-size frog without moving it."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	var city_camera_rotation := 0.31
	game._camera.rotation = city_camera_rotation
	var handled_entry := game._try_handle_interior_transition_tap(
		market.transition_door_world_position()
	)
	_check(
		handled_entry
		and game._pending_interior_transition
		== FrogGame.MARKET_ROOFTOP_ID
		and game._frog._move_target
		== market.transition_door_approach_position(),
		"A grown frog walks to the market's rooftop ladder."
	)
	game._frog.global_position = market.transition_door_approach_position()
	game._spawn_pursuer()
	var pursuit_started := is_instance_valid(game._pursuer)
	if pursuit_started:
		game._pursuer.set_physics_process(false)
	game._on_frog_move_reached(game._frog.global_position)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		pursuit_started
		and not is_instance_valid(game._pursuer)
		and game._active_interior_id == FrogGame.MARKET_ROOFTOP_ID
		and game._frog.global_position == rooftop.entry_position()
		and game._camera.global_position == rooftop.global_position
		and game._camera.zoom == FrogGame.STOCKROOM_CAMERA_ZOOM
		and is_zero_approx(game._camera.rotation)
		and game._active_navigation_rect() == rooftop.interior_rect(),
		"Entering the rooftop uses the fixed room camera and ends active pursuit."
	)
	game._spawn_pursuer()
	_check(
		not is_instance_valid(game._pursuer)
		and game._status_label.text.contains("cannot find"),
		"Animal Control cannot spawn remotely on the rooftop."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._pending_growth_tier = 2
	game._frog.global_position = rooftop.global_position
	game._last_safe_ground_position = rooftop.global_position
	game._retry_pending_growth()
	_check(
		game._growth_tier == 2
		and game._pending_growth_tier == -1
		and rooftop.interior_rect().has_point(game._frog.global_position),
		"The rooftop garden aisle supports maximum-size growth."
	)

	game._frog.global_position = beehive.global_position + Vector2(0, 110)
	game._swallow_target(beehive, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id == "market_rooftop_beehive"
		and game._belly[0].movement_bounds == rooftop.interior_rect(),
		"Swallowing the Beehive preserves its rooftop restock bounds."
	)
	game._spit_item(0)
	var spat_beehive := _find_target(game, "market_rooftop_beehive")
	_check(
		game._belly.is_empty()
		and is_instance_valid(spat_beehive)
		and rooftop.interior_rect().has_point(spat_beehive.global_position),
		"Spitting the Beehive on the rooftop returns it within the garden."
	)
	game._swallow_target(spat_beehive, 1.0)

	game.set_motion_scale(0.0)
	game._frog.global_position = rooftop.exit_approach_position()
	var handled_exit := game._try_handle_interior_transition_tap(
		rooftop.exit_marker_position()
	)
	_check(
		handled_exit
		and game._active_interior_id.is_empty()
		and game._frog.global_position
		== market.transition_door_approach_position()
		and is_equal_approx(game._camera.rotation, city_camera_rotation),
		"The rooftop ladder returns to the market immediately with Reduce motion."
	)
	game._spit_item(0)
	_check(
		game._belly.size() == 1
		and game._status_label.text.contains("rooftop garden"),
		"A Beehive carried downstairs cannot be spat into the market."
	)
	game._digest_item(0)

	market.consume()
	_check(
		not market.transition_door_hit_test(
			market.transition_door_world_position()
		),
		"Consuming Moonlight Market disables rooftop access."
	)
	market.restore()
	_check(
		market.transition_door_hit_test(
			market.transition_door_world_position()
		),
		"Restoring Moonlight Market restores its rooftop ladder."
	)

	paused = false
	game.queue_free()
	await process_frame


func _test_canal_upper_hall(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("upper_hall_test", "Upper Hall Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var apartments := (
		game._building_by_id.get("canal_apartments") as PrototypeBuilding
	)
	var upper_hall := (
		game._interior_rooms.get(FrogGame.CANAL_UPPER_HALL_ID)
		as PrototypeInteriorRoom
	)
	var vacuum := _find_target(game, "canal_upper_hall_vacuum")
	_check(
		is_instance_valid(apartments)
		and is_instance_valid(upper_hall)
		and is_instance_valid(vacuum)
		and game._interior_rooms.size() == 10
		and apartments.transition_room_id
		== FrogGame.CANAL_UPPER_HALL_ID
		and upper_hall.return_label == "RETURN TO LOBBY"
		and upper_hall._collision_body.get_child_count() == 8
		and vacuum.building_id == FrogGame.CANAL_UPPER_HALL_ID
		and vacuum.move_bounds == upper_hall.interior_rect(),
		"Canal Apartments creates one solid upper hall and its room-scoped Hallway Vacuum."
	)
	_check(
		apartments.transition_door_hit_test(
			apartments.transition_door_world_position()
		)
		and game._circle_position_clear(
			apartments.transition_door_approach_position(),
			44.0,
			true
		)
		and not game._circle_position_clear(
			upper_hall.global_position
			+ upper_hall.props[0].get_center(),
			28.0,
			true
		)
		and game._circle_position_clear(
			upper_hall.global_position,
			44.0,
			true
		),
		"The marked lobby stairs and upper-hall aisle remain safe at maximum frog size."
	)

	game._frog.global_position = apartments.global_position + Vector2(0, 80)
	var city_camera_rotation := -0.28
	game._camera.rotation = city_camera_rotation
	var handled_entry := game._try_handle_interior_transition_tap(
		apartments.transition_door_world_position()
	)
	_check(
		handled_entry
		and game._pending_interior_transition
		== FrogGame.CANAL_UPPER_HALL_ID
		and game._frog._move_target
		== apartments.transition_door_approach_position(),
		"Tapping the lobby stairs walks the frog to the upper-hall entrance."
	)
	game._frog.global_position = apartments.transition_door_approach_position()
	game._spawn_pursuer()
	var pursuit_started := is_instance_valid(game._pursuer)
	if pursuit_started:
		game._pursuer.set_physics_process(false)
	game._on_frog_move_reached(game._frog.global_position)
	game._update_interior_transition(
		FrogGame.INTERIOR_TRANSITION_DURATION
	)
	game._update_interior_transition(
		FrogGame.INTERIOR_TRANSITION_DURATION
	)
	_check(
		pursuit_started
		and not is_instance_valid(game._pursuer)
		and game._active_interior_id
		== FrogGame.CANAL_UPPER_HALL_ID
		and game._frog.global_position == upper_hall.entry_position()
		and game._camera.global_position == upper_hall.global_position
		and game._camera.zoom == FrogGame.STOCKROOM_CAMERA_ZOOM
		and is_zero_approx(game._camera.rotation)
		and game._active_navigation_rect()
		== upper_hall.interior_rect(),
		"Entering the upper hall uses the fixed room camera and ends active pursuit."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._frog.global_position = vacuum.global_position + Vector2(0, 110)
	game._swallow_target(vacuum, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id == "canal_upper_hall_vacuum"
		and game._belly[0].movement_bounds
		== upper_hall.interior_rect(),
		"Swallowing the Hallway Vacuum preserves its upper-hall restock bounds."
	)
	game._spit_item(0)
	var spat_vacuum := _find_target(game, "canal_upper_hall_vacuum")
	_check(
		game._belly.is_empty()
		and is_instance_valid(spat_vacuum)
		and upper_hall.interior_rect().has_point(
			spat_vacuum.global_position
		),
		"Spitting the Hallway Vacuum inside returns it within the upper hall."
	)
	game._swallow_target(spat_vacuum, 1.0)

	game.set_motion_scale(0.0)
	game._frog.global_position = upper_hall.exit_approach_position()
	var handled_exit := game._try_handle_interior_transition_tap(
		upper_hall.exit_marker_position()
	)
	_check(
		handled_exit
		and game._active_interior_id.is_empty()
		and game._frog.global_position
		== apartments.transition_door_approach_position()
		and is_equal_approx(
			game._camera.rotation,
			city_camera_rotation
		),
		"The upper-hall return marker restores the apartment lobby immediately with Reduce motion."
	)
	game._spit_item(0)
	_check(
		game._belly.size() == 1
		and game._status_label.text.contains("upper hall"),
		"A Hallway Vacuum carried outside cannot be spat into the city."
	)
	game._digest_item(0)

	apartments.consume()
	_check(
		not apartments.transition_door_hit_test(
			apartments.transition_door_world_position()
		),
		"Consuming Canal Apartments disables its upper-hall entrance."
	)
	apartments.restore()
	_check(
		apartments.transition_door_hit_test(
			apartments.transition_door_world_position()
		),
		"Restoring Canal Apartments restores its upper-hall entrance."
	)

	paused = false
	game.queue_free()
	await process_frame


func _test_canal_fire_escape(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("fire_escape_test", "Fire Escape Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var apartments := (
		game._building_by_id.get("canal_apartments") as PrototypeBuilding
	)
	var upper_hall := (
		game._interior_rooms.get(FrogGame.CANAL_UPPER_HALL_ID)
		as PrototypeInteriorRoom
	)
	var fire_escape := (
		game._interior_rooms.get(FrogGame.CANAL_FIRE_ESCAPE_ID)
		as PrototypeInteriorRoom
	)
	var laundry := _find_target(game, "canal_fire_escape_laundry")
	var outward_portal := upper_hall.portal_by_id("fire_escape_door")
	var return_portal := fire_escape.portal_by_id("return")
	_check(
		is_instance_valid(apartments)
		and is_instance_valid(upper_hall)
		and is_instance_valid(fire_escape)
		and is_instance_valid(laundry)
		and game._interior_rooms.size() == 10
		and str(outward_portal["destination"])
		== FrogGame.CANAL_FIRE_ESCAPE_ID
		and str(return_portal["destination"])
		== FrogGame.CANAL_UPPER_HALL_ID
		and fire_escape.camera_follows_frog()
		and fire_escape.room_size == Vector2(1700, 1200)
		and fire_escape._collision_body.get_child_count() == 8
		and laundry.building_id == FrogGame.CANAL_FIRE_ESCAPE_ID
		and laundry.move_bounds == fire_escape.interior_rect(),
		"The apartment fire escape is a two-way room-chain destination with its own target."
	)
	_check(
		game._circle_position_clear(
			upper_hall.portal_approach_position(outward_portal),
			44.0,
			true
		)
		and game._circle_position_clear(
			upper_hall.entry_position("from_fire_escape"),
			44.0,
			true
		)
		and game._circle_position_clear(
			fire_escape.portal_approach_position(return_portal),
			44.0,
			true
		)
		and game._circle_position_clear(
			fire_escape.global_position,
			44.0,
			true
		),
		"The authored fire-escape entrances and central platform admit the maximum frog."
	)

	var city_camera_rotation := 0.27
	game._camera.rotation = city_camera_rotation
	game._frog.global_position = apartments.transition_door_approach_position()
	game._spawn_pursuer()
	var pursuit_started := is_instance_valid(game._pursuer)
	if pursuit_started:
		game._pursuer.set_physics_process(false)
	game._begin_interior_transition(FrogGame.CANAL_UPPER_HALL_ID)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		pursuit_started
		and not is_instance_valid(game._pursuer)
		and game._active_interior_id == FrogGame.CANAL_UPPER_HALL_ID,
		"Entering the apartment room chain clears active pursuit."
	)

	game._frog.global_position = upper_hall.portal_approach_position(
		outward_portal
	)
	game._begin_interior_transition(
		FrogGame.CANAL_FIRE_ESCAPE_ID,
		"fire_escape_door"
	)
	_check(
		game._active_interior_id == FrogGame.CANAL_UPPER_HALL_ID
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE
		and game._status_label.text.contains("Grow once"),
		"Direct transition calls cannot bypass the fire escape growth gate."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	var handled_outward := game._try_handle_interior_transition_tap(
		upper_hall.portal_marker_position(outward_portal)
	)
	_check(
		handled_outward
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.FADE_OUT,
		"The upper-hall fire door starts the outward room-to-room transition."
	)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		game._active_interior_id == FrogGame.CANAL_FIRE_ESCAPE_ID
		and game._frog.global_position
		== fire_escape.entry_position("from_upper_hall")
		and game._camera.zoom == fire_escape.camera_zoom
		and game._active_navigation_rect() == fire_escape.interior_rect(),
		"The fire escape uses its authored arrival and navigation bounds."
	)
	game._spawn_pursuer()
	_check(
		not is_instance_valid(game._pursuer)
		and game._status_label.text.contains("cannot find"),
		"Animal Control cannot spawn remotely on the fire escape."
	)

	game._frog.global_position = fire_escape.global_position
	game._update_camera()
	var camera_before_rotation := game._camera.global_position
	game._rotate_camera(40.0, Vector2(640, 480))
	game._update_camera()
	game._camera.force_update_scroll()
	var half_view := (
		game.get_viewport().get_visible_rect().size
		/ (game._camera.zoom * 2.0)
	)
	var cosine := absf(cos(game._camera.rotation))
	var sine := absf(sin(game._camera.rotation))
	var rotated_half_view := Vector2(
		cosine * half_view.x + sine * half_view.y,
		sine * half_view.x + cosine * half_view.y
	)
	_check(
		not is_zero_approx(game._camera.rotation)
		and absf(game._camera.rotation)
		<= fire_escape.camera_rotation_limit
		and not game._camera.position_smoothing_enabled
		and game._camera.global_position != fire_escape.global_position
		and game._camera.global_position != camera_before_rotation,
		"The large fire escape uses a navigable follow camera."
	)
	_check(
		fire_escape.interior_rect().encloses(
			Rect2(
				game._camera.global_position - rotated_half_view,
				rotated_half_view * 2.0
			)
		),
		"The unsmoothed fire-escape camera stays inside the authored room."
	)

	game._pending_growth_tier = 2
	game._frog.global_position = fire_escape.global_position
	game._last_safe_ground_position = fire_escape.global_position
	game._retry_pending_growth()
	_check(
		game._growth_tier == 2
		and game._pending_growth_tier == -1
		and fire_escape.interior_rect().has_point(
			game._frog.global_position
		),
		"The fire escape keeps safe central space for maximum growth."
	)

	game._frog.global_position = laundry.global_position + Vector2(0, 110)
	game._swallow_target(laundry, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id
		== "canal_fire_escape_laundry"
		and game._belly[0].movement_bounds
		== fire_escape.interior_rect(),
		"Swallowing the Laundry Basket preserves fire-escape restock bounds."
	)

	game.set_motion_scale(0.0)
	game._frog.global_position = fire_escape.portal_approach_position(
		return_portal
	)
	var handled_return := game._try_handle_interior_transition_tap(
		fire_escape.portal_marker_position(return_portal)
	)
	_check(
		handled_return
		and game._active_interior_id == FrogGame.CANAL_UPPER_HALL_ID
		and game._frog.global_position
		== upper_hall.entry_position("from_fire_escape")
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE,
		"Reduce motion returns from the fire escape to the authored upper-hall landing."
	)
	game._spit_item(0)
	_check(
		game._belly.size() == 1
		and game._status_label.text.contains("fire escape"),
		"A fire-escape target cannot be spat into the upper hall."
	)

	game._frog.global_position = upper_hall.exit_approach_position()
	game._begin_interior_transition("city", "return")
	_check(
		game._active_interior_id.is_empty()
		and game._frog.global_position
		== apartments.transition_door_approach_position()
		and is_equal_approx(game._camera.rotation, city_camera_rotation),
		"Leaving the room chain restores the original city camera and lobby position."
	)
	game._digest_item(0)
	apartments.consume()
	_check(
		not apartments.transition_door_hit_test(
			apartments.transition_door_world_position()
		),
		"Consuming Canal Apartments disables the whole upper-room chain."
	)
	apartments.restore()
	_check(
		apartments.transition_door_hit_test(
			apartments.transition_door_world_position()
		),
		"Restoring Canal Apartments restores the fire-escape route."
	)

	await create_timer(9.2, false).timeout
	var restocked_laundry := _find_target(
		game,
		"canal_fire_escape_laundry"
	)
	_check(
		is_instance_valid(restocked_laundry)
		and fire_escape.interior_rect().has_point(
			restocked_laundry.global_position
		)
		and game._active_interior_id.is_empty(),
		"Digesting the Laundry Basket restocks it on the fire escape."
	)

	paused = false
	game.queue_free()
	await process_frame


func _test_river_sewer_chain(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("sewer_test", "Sewer Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var city_portal := game._city_portal_by_id("river_sewer_hatch")
	var junction := (
		game._interior_rooms.get(FrogGame.RIVER_SEWER_JUNCTION_ID)
		as PrototypeInteriorRoom
	)
	var tunnel := (
		game._interior_rooms.get(FrogGame.RIVER_SUBWAY_TUNNEL_ID)
		as PrototypeInteriorRoom
	)
	var tunnel_portal := junction.portal_by_id("service_tunnel")
	var tunnel_return := tunnel.portal_by_id("return")
	var valve := _find_target(game, "river_sewer_valve")
	var signal_lamp := _find_target(game, "river_subway_signal")
	_check(
		not city_portal.is_empty()
		and is_instance_valid(junction)
		and is_instance_valid(tunnel)
		and is_instance_valid(valve)
		and is_instance_valid(signal_lamp)
		and game._interior_rooms.size() == 10
		and str(tunnel_portal["destination"])
		== FrogGame.RIVER_SUBWAY_TUNNEL_ID
		and str(tunnel_return["destination"])
		== FrogGame.RIVER_SEWER_JUNCTION_ID
		and junction.camera_follows_frog()
		and tunnel.camera_follows_frog()
		and valve.building_id == FrogGame.RIVER_SEWER_JUNCTION_ID
		and signal_lamp.building_id
		== FrogGame.RIVER_SUBWAY_TUNNEL_ID,
		"River Park creates a two-section sewer and subway chain with scoped targets."
	)
	_check(
		game._circle_position_clear(
			city_portal["approach_position"] as Vector2,
			44.0,
			true
		)
		and game._circle_position_clear(
			junction.entry_position("from_city"),
			44.0,
			true
		)
		and game._circle_position_clear(
			junction.entry_position("from_tunnel"),
			44.0,
			true
		)
		and game._circle_position_clear(
			tunnel.entry_position("from_junction"),
			44.0,
			true
		)
		and game._circle_position_clear(
			junction.global_position,
			44.0,
			true
		)
		and game._circle_position_clear(
			tunnel.global_position,
			44.0,
			true
		),
		"Every sewer landing and both central routes are safe at maximum size."
	)

	game._begin_interior_transition(FrogGame.RIVER_SEWER_JUNCTION_ID)
	_check(
		game._active_interior_id.is_empty()
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE,
		"Direct transition calls cannot bypass the River Park hatch."
	)

	var city_camera_rotation := -0.19
	game._camera.rotation = city_camera_rotation
	game._frog.global_position = Vector2(780, 550)
	var handled_hatch := game._try_handle_interior_transition_tap(
		city_portal["marker_position"] as Vector2
	)
	_check(
		handled_hatch
		and game._pending_interior_transition
		== FrogGame.RIVER_SEWER_JUNCTION_ID
		and game._pending_interior_portal_id == "river_sewer_hatch",
		"The River Park hatch routes the frog to its authored approach."
	)
	game._frog.global_position = city_portal["approach_position"] as Vector2
	game._spawn_pursuer()
	var pursuit_started := is_instance_valid(game._pursuer)
	if pursuit_started:
		game._pursuer.set_physics_process(false)
	game._on_frog_move_reached(game._frog.global_position)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		pursuit_started
		and not is_instance_valid(game._pursuer)
		and game._active_interior_id
		== FrogGame.RIVER_SEWER_JUNCTION_ID
		and game._frog.global_position
		== junction.entry_position("from_city"),
		"Entering the sewer uses its safe landing and clears active pursuit."
	)
	game._spawn_pursuer()
	_check(
		not is_instance_valid(game._pursuer),
		"Remote pursuit stays blocked throughout the sewer chain."
	)

	game._frog.global_position = valve.global_position + Vector2(0, 100)
	game._swallow_target(valve, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].movement_bounds == junction.interior_rect(),
		"Swallowing the Valve Wheel preserves sewer-junction bounds."
	)
	game._spit_item(0)
	var spat_valve := _find_target(game, "river_sewer_valve")
	_check(
		game._belly.is_empty()
		and is_instance_valid(spat_valve)
		and junction.interior_rect().has_point(spat_valve.global_position),
		"Spitting the Valve Wheel returns it inside the sewer junction."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._pending_growth_tier = 2
	game._frog.global_position = junction.global_position
	game._last_safe_ground_position = junction.global_position
	game._retry_pending_growth()
	_check(
		game._growth_tier == 2
		and game._pending_growth_tier == -1,
		"The sewer junction supports safe maximum-size growth."
	)

	game._frog.global_position = junction.portal_approach_position(
		tunnel_portal
	)
	game._begin_interior_transition(
		FrogGame.RIVER_SUBWAY_TUNNEL_ID,
		"service_tunnel"
	)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		game._active_interior_id
		== FrogGame.RIVER_SUBWAY_TUNNEL_ID
		and game._frog.global_position
		== tunnel.entry_position("from_junction")
		and game._camera.zoom == tunnel.camera_zoom,
		"The sewer junction connects forward to the subway service tunnel."
	)
	game._frog.global_position = tunnel.global_position
	game._last_safe_ground_position = tunnel.global_position
	_check(
		game._find_safe_frog_position(44.0) != Vector2.INF,
		"The subway tunnel retains navigable maximum-size central space."
	)

	game._frog.global_position = (
		signal_lamp.global_position + Vector2(0, 110)
	)
	game._swallow_target(signal_lamp, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id == "river_subway_signal"
		and game._belly[0].movement_bounds == tunnel.interior_rect(),
		"Swallowing the Signal Lamp preserves service-tunnel bounds."
	)

	game.set_motion_scale(0.0)
	game._frog.global_position = tunnel.portal_approach_position(
		tunnel_return
	)
	game._begin_interior_transition(
		FrogGame.RIVER_SEWER_JUNCTION_ID,
		"return"
	)
	_check(
		game._active_interior_id == FrogGame.RIVER_SEWER_JUNCTION_ID
		and game._frog.global_position
		== junction.entry_position("from_tunnel")
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE,
		"Reduce motion returns immediately from the tunnel to the junction."
	)
	game._spit_item(0)
	_check(
		game._belly.size() == 1
		and game._status_label.text.contains("service tunnel"),
		"A subway target cannot be spat into the sewer junction."
	)

	game._frog.global_position = junction.portal_approach_position(
		tunnel_portal
	)
	game._begin_interior_transition(
		FrogGame.RIVER_SUBWAY_TUNNEL_ID,
		"service_tunnel"
	)
	game._digest_item(0)
	game._frog.global_position = tunnel.portal_approach_position(
		tunnel_return
	)
	game._begin_interior_transition(
		FrogGame.RIVER_SEWER_JUNCTION_ID,
		"return"
	)
	game._frog.global_position = junction.exit_approach_position()
	game._begin_interior_transition("city", "return")
	_check(
		game._active_interior_id.is_empty()
		and game._frog.global_position
		== (city_portal["approach_position"] as Vector2)
		and is_equal_approx(game._camera.rotation, city_camera_rotation)
		and game._camera.position_smoothing_enabled,
		"Leaving both sewer sections restores the River Park position and city camera."
	)

	await create_timer(9.2, false).timeout
	var restocked_signal := _find_target(game, "river_subway_signal")
	_check(
		is_instance_valid(restocked_signal)
		and tunnel.interior_rect().has_point(
			restocked_signal.global_position
		),
		"Digesting the Signal Lamp restocks it in the subway tunnel."
	)

	paused = false
	game.queue_free()
	await process_frame


func _test_hidden_sewer_maintenance(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("hidden_sewer_test", "Hidden Sewer Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var city_portal := game._city_portal_by_id("river_sewer_hatch")
	var junction := (
		game._interior_rooms.get(FrogGame.RIVER_SEWER_JUNCTION_ID)
		as PrototypeInteriorRoom
	)
	var hidden_room := (
		game._interior_rooms.get(
			FrogGame.RIVER_HIDDEN_MAINTENANCE_ID
		)
		as PrototypeInteriorRoom
	)
	var hidden_portal := junction.portal_by_id(
		"hidden_maintenance_hatch"
	)
	var return_portal := hidden_room.portal_by_id("return")
	var valve := _find_target(game, "river_sewer_valve")
	var pump_handle := _find_target(game, "river_hidden_pump_handle")
	var hidden_camera_half_view := (
		game.get_viewport().get_visible_rect().size
		/ (hidden_room.camera_zoom * 2.0)
	)
	var hidden_camera_rect := Rect2(
		hidden_room.global_position - hidden_camera_half_view,
		hidden_camera_half_view * 2.0
	)
	_check(
		is_instance_valid(junction)
		and is_instance_valid(hidden_room)
		and is_instance_valid(valve)
		and is_instance_valid(pump_handle)
		and game._interior_rooms.size() == 10
		and str(hidden_portal["destination"])
		== FrogGame.RIVER_HIDDEN_MAINTENANCE_ID
		and str(return_portal["destination"])
		== FrogGame.RIVER_SEWER_JUNCTION_ID
		and not bool(hidden_portal["visible"])
		and not hidden_room.camera_follows_frog()
		and hidden_room.room_size == Vector2(1300, 900)
		and hidden_room._collision_body.get_child_count() == 8
		and pump_handle.size_tier == 1
		and pump_handle.resistant
		and pump_handle.dangerous_location
		and pump_handle.building_id
		== FrogGame.RIVER_HIDDEN_MAINTENANCE_ID
		and pump_handle.move_bounds == hidden_room.interior_rect(),
		"The undiscovered sewer pocket starts hidden with one scoped maintenance target."
	)
	_check(
		game._circle_position_clear(
			junction.entry_position("from_maintenance"),
			44.0,
			true
		)
		and game._circle_position_clear(
			junction.portal_approach_position(hidden_portal),
			44.0,
			true
		)
		and game._circle_position_clear(
			hidden_room.entry_position("from_junction"),
			44.0,
			true
		)
		and game._circle_position_clear(
			hidden_room.portal_approach_position(return_portal),
			44.0,
			true
		)
		and game._circle_position_clear(
			hidden_room.global_position,
			44.0,
			true
		)
		and hidden_camera_rect.has_point(
			hidden_room.portal_marker_position(return_portal)
		),
		"The hidden hatch, both safe landings, center, and fixed-camera return marker remain usable."
	)

	var city_camera_rotation := 0.23
	game._camera.rotation = city_camera_rotation
	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._frog.global_position = city_portal["approach_position"] as Vector2
	game._spawn_pursuer()
	var pursuit_started := is_instance_valid(game._pursuer)
	if pursuit_started:
		game._pursuer.set_physics_process(false)
	game._begin_interior_transition(
		FrogGame.RIVER_SEWER_JUNCTION_ID,
		"river_sewer_hatch"
	)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		pursuit_started
		and not is_instance_valid(game._pursuer)
		and game._active_interior_id
		== FrogGame.RIVER_SEWER_JUNCTION_ID,
		"Entering the sewer chain clears pursuit before hidden exploration."
	)

	game._frog.global_position = junction.portal_approach_position(
		hidden_portal
	)
	var hidden_tap_before_discovery := (
		game._try_handle_interior_transition_tap(
			junction.portal_marker_position(hidden_portal)
		)
	)
	game._begin_interior_transition(
		FrogGame.RIVER_HIDDEN_MAINTENANCE_ID,
		"hidden_maintenance_hatch"
	)
	_check(
		not hidden_tap_before_discovery
		and game._active_interior_id
		== FrogGame.RIVER_SEWER_JUNCTION_ID
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE
		and game._status_label.text.contains("not accessible"),
		"An invisible maintenance hatch cannot be tapped or entered by a direct bypass."
	)

	game._frog.global_position = valve.global_position + Vector2(0, 100)
	game._swallow_target(valve, 1.0)
	_check(
		game._discoveries.has("river_sewer_valve")
		and bool(hidden_portal["visible"])
		and game._belly.size() == 1,
		"Discovering the Sewer Valve Wheel reveals the maintenance hatch."
	)
	game._spit_item(0)
	_check(
		game._belly.is_empty()
		and bool(hidden_portal["visible"]),
		"The revealed hatch remains available after returning the Valve Wheel."
	)

	game._frog.global_position = junction.portal_approach_position(
		hidden_portal
	)
	var handled_hidden_entry := (
		game._try_handle_interior_transition_tap(
			junction.portal_marker_position(hidden_portal)
		)
	)
	_check(
		handled_hidden_entry
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.FADE_OUT,
		"The revealed hatch starts the forward transition from the junction."
	)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		game._active_interior_id
		== FrogGame.RIVER_HIDDEN_MAINTENANCE_ID
		and game._frog.global_position
		== hidden_room.entry_position("from_junction")
		and game._camera.global_position == hidden_room.global_position
		and game._camera.zoom == hidden_room.camera_zoom
		and is_zero_approx(game._camera.rotation)
		and game._active_navigation_rect()
		== hidden_room.interior_rect(),
		"The hidden pocket uses its fixed camera, safe landing, and navigation bounds."
	)
	game._spawn_pursuer()
	_check(
		not is_instance_valid(game._pursuer)
		and game._status_label.text.contains("cannot find"),
		"Animal Control cannot spawn remotely in the hidden maintenance pocket."
	)

	game._pending_growth_tier = 2
	game._frog.global_position = hidden_room.global_position
	game._last_safe_ground_position = hidden_room.global_position
	game._retry_pending_growth()
	_check(
		game._growth_tier == 2
		and game._pending_growth_tier == -1
		and game._find_safe_frog_position(44.0) != Vector2.INF,
		"The hidden maintenance pocket supports maximum-size growth and navigation."
	)

	game._frog.global_position = (
		pump_handle.global_position + Vector2(0, 110)
	)
	game._swallow_target(pump_handle, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id == "river_hidden_pump_handle"
		and game._belly[0].movement_bounds
		== hidden_room.interior_rect(),
		"Swallowing the Pump Handle preserves hidden-room restock bounds."
	)
	game._spit_item(0)
	var spat_handle := _find_target(game, "river_hidden_pump_handle")
	_check(
		game._belly.is_empty()
		and is_instance_valid(spat_handle)
		and spat_handle.dangerous_location
		and hidden_room.interior_rect().has_point(
			spat_handle.global_position
		),
		"Spitting the Pump Handle keeps it in the dangerous hidden pocket."
	)
	game._swallow_target(spat_handle, 1.0)

	game.set_motion_scale(0.0)
	game._frog.global_position = hidden_room.portal_approach_position(
		return_portal
	)
	var handled_hidden_return := (
		game._try_handle_interior_transition_tap(
			hidden_room.portal_marker_position(return_portal)
		)
	)
	_check(
		handled_hidden_return
		and game._active_interior_id
		== FrogGame.RIVER_SEWER_JUNCTION_ID
		and game._frog.global_position
		== junction.entry_position("from_maintenance")
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE,
		"Reduce motion returns immediately from the hidden pocket to the junction."
	)
	game._spit_item(0)
	_check(
		game._belly.size() == 1
		and game._status_label.text.contains(
			"hidden sewer maintenance pocket"
		),
		"A hidden-room target cannot be spat into the sewer junction."
	)
	game._digest_item(0)

	game._frog.global_position = junction.exit_approach_position()
	game._begin_interior_transition("city", "return")
	_check(
		game._active_interior_id.is_empty()
		and game._frog.global_position
		== (city_portal["approach_position"] as Vector2)
		and is_equal_approx(game._camera.rotation, city_camera_rotation)
		and game._camera.position_smoothing_enabled,
		"Leaving the hidden branch restores the River Park position and city camera."
	)

	await create_timer(9.2, false).timeout
	var restocked_handle := _find_target(
		game,
		"river_hidden_pump_handle"
	)
	_check(
		is_instance_valid(restocked_handle)
		and restocked_handle.dangerous_location
		and hidden_room.interior_rect().has_point(
			restocked_handle.global_position
		),
		"Digesting the Pump Handle restocks it inside the hidden pocket."
	)

	paused = false
	game.queue_free()
	await process_frame


func _test_river_pond_boardwalk(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("pond_test", "Pond Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var city_portal := game._city_portal_by_id("river_pond_boardwalk")
	var boardwalk := (
		game._interior_rooms.get(FrogGame.RIVER_POND_BOARDWALK_ID)
		as PrototypeInteriorRoom
	)
	var planter := _find_target(game, "river_pond_lily_planter")
	_check(
		not city_portal.is_empty()
		and is_instance_valid(boardwalk)
		and is_instance_valid(planter)
		and game._interior_rooms.size() == 10
		and boardwalk.camera_follows_frog()
		and boardwalk.room_size == Vector2(1900, 1200)
		and planter.building_id == FrogGame.RIVER_POND_BOARDWALK_ID
		and planter.move_bounds == boardwalk.interior_rect(),
		"River Park exposes a navigable pond boardwalk with its own target."
	)
	_check(
		game._circle_position_clear(
			city_portal["approach_position"] as Vector2,
			44.0,
			true
		)
		and game._circle_position_clear(
			boardwalk.entry_position("from_park"),
			44.0,
			true
		)
		and game._circle_position_clear(
			boardwalk.global_position,
			44.0,
			true
		),
		"The park entrance, boardwalk landing, and center are maximum-size safe."
	)

	var city_camera_rotation := 0.17
	game._camera.rotation = city_camera_rotation
	game._frog.global_position = city_portal["approach_position"] as Vector2
	game._spawn_pursuer()
	var pursuit_started := is_instance_valid(game._pursuer)
	if pursuit_started:
		game._pursuer.set_physics_process(false)
	game._begin_interior_transition(
		FrogGame.RIVER_POND_BOARDWALK_ID,
		"river_pond_boardwalk"
	)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		pursuit_started
		and not is_instance_valid(game._pursuer)
		and game._active_interior_id
		== FrogGame.RIVER_POND_BOARDWALK_ID
		and game._frog.global_position
		== boardwalk.entry_position("from_park")
		and game._active_navigation_rect() == boardwalk.interior_rect(),
		"Entering the pond boardwalk uses the authored landing and ends pursuit."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._pending_growth_tier = 2
	game._frog.global_position = boardwalk.global_position
	game._last_safe_ground_position = boardwalk.global_position
	game._retry_pending_growth()
	_check(
		game._growth_tier == 2
		and game._pending_growth_tier == -1,
		"The pond boardwalk supports maximum-size growth and navigation."
	)

	game._frog.global_position = planter.global_position + Vector2(0, 120)
	game._swallow_target(planter, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].movement_bounds == boardwalk.interior_rect(),
		"Swallowing the Lily Pad Planter preserves pond restock bounds."
	)
	game._spit_item(0)
	var spat_planter := _find_target(game, "river_pond_lily_planter")
	_check(
		game._belly.is_empty()
		and is_instance_valid(spat_planter)
		and boardwalk.interior_rect().has_point(
			spat_planter.global_position
		),
		"Spitting the Lily Pad Planter returns it to the pond boardwalk."
	)
	game._swallow_target(spat_planter, 1.0)

	game.set_motion_scale(0.0)
	game._frog.global_position = boardwalk.exit_approach_position()
	game._begin_interior_transition("city", "return")
	_check(
		game._active_interior_id.is_empty()
		and game._frog.global_position
		== (city_portal["approach_position"] as Vector2)
		and is_equal_approx(game._camera.rotation, city_camera_rotation)
		and game._camera.position_smoothing_enabled,
		"Reduce motion returns immediately to River Park and restores its camera."
	)
	game._spit_item(0)
	_check(
		game._belly.size() == 1
		and game._status_label.text.contains("lily pond boardwalk"),
		"A pond target cannot be spat into River Park."
	)
	game._digest_item(0)

	await create_timer(9.2, false).timeout
	var restocked_planter := _find_target(
		game,
		"river_pond_lily_planter"
	)
	_check(
		is_instance_valid(restocked_planter)
		and boardwalk.interior_rect().has_point(
			restocked_planter.global_position
		),
		"Digesting the Lily Pad Planter restocks it on the boardwalk."
	)

	paused = false
	game.queue_free()
	await process_frame


func _test_construction_crane(game_scene: PackedScene) -> void:
	var game := game_scene.instantiate() as FrogGame
	game.set_motion_scale(1.0)
	game.configure("crane_test", "Crane Tester", false)
	root.add_child(game)
	await process_frame
	await physics_frame

	game.set_process(false)
	game._frog.set_physics_process(false)
	var city_portal := game._city_portal_by_id(
		"construction_crane_lift"
	)
	var crane := (
		game._interior_rooms.get(FrogGame.CONSTRUCTION_CRANE_ID)
		as PrototypeInteriorRoom
	)
	var return_portal := crane.portal_by_id("return")
	var toolbox := _find_target(game, "construction_crane_toolbox")
	_check(
		not city_portal.is_empty()
		and is_instance_valid(crane)
		and is_instance_valid(toolbox)
		and game._interior_rooms.size() == 10
		and crane.camera_follows_frog()
		and crane.room_size == Vector2(2100, 1300)
		and crane._collision_body.get_child_count() == 8
		and str(return_portal["destination"]) == "city"
		and toolbox.size_tier == 1
		and toolbox.resistant
		and toolbox.dangerous_location
		and toolbox.building_id == FrogGame.CONSTRUCTION_CRANE_ID
		and toolbox.move_bounds == crane.interior_rect(),
		"The construction lift reaches one elevated deck with a scoped dangerous target."
	)
	_check(
		game._circle_position_clear(
			city_portal["approach_position"] as Vector2,
			44.0,
			true
		)
		and game._circle_position_clear(
			crane.entry_position("from_lift"),
			44.0,
			true
		)
		and game._circle_position_clear(
			crane.exit_approach_position(),
			44.0,
			true
		)
		and game._circle_position_clear(
			crane.global_position,
			44.0,
			true
		),
		"The lift approach, deck landings, and center are safe at maximum size."
	)

	game._frog.global_position = city_portal["approach_position"] as Vector2
	var handled_locked := game._try_handle_interior_transition_tap(
		city_portal["marker_position"] as Vector2
	)
	_check(
		handled_locked
		and game._active_interior_id.is_empty()
		and game._pending_interior_transition.is_empty()
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE
		and game._status_label.text.contains("Grow once"),
		"Starting-size frogs cannot operate the construction lift."
	)

	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._begin_interior_transition(FrogGame.CONSTRUCTION_CRANE_ID)
	_check(
		game._active_interior_id.is_empty()
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE
		and game._status_label.text.contains("not accessible"),
		"Direct transition calls cannot bypass the marked construction lift."
	)

	var city_camera_rotation := -0.21
	game._camera.rotation = city_camera_rotation
	game._spawn_pursuer()
	var pursuit_started := is_instance_valid(game._pursuer)
	if pursuit_started:
		game._pursuer.set_physics_process(false)
	game._begin_interior_transition(
		FrogGame.CONSTRUCTION_CRANE_ID,
		"construction_crane_lift"
	)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	game._update_interior_transition(FrogGame.INTERIOR_TRANSITION_DURATION)
	_check(
		pursuit_started
		and not is_instance_valid(game._pursuer)
		and game._active_interior_id
		== FrogGame.CONSTRUCTION_CRANE_ID
		and game._frog.global_position
		== crane.entry_position("from_lift")
		and game._camera.zoom == crane.camera_zoom
		and game._active_navigation_rect() == crane.interior_rect(),
		"Riding the lift uses its authored landing and ends active pursuit."
	)
	game._spawn_pursuer()
	_check(
		not is_instance_valid(game._pursuer)
		and game._status_label.text.contains("cannot find"),
		"Animal Control cannot spawn remotely on the crane deck."
	)

	game._frog.global_position = (
		crane.global_position + Vector2(720, 0)
	)
	game._update_camera()
	var camera_before_rotation := game._camera.global_position
	game._rotate_camera(40.0, Vector2(640, 480))
	game._update_camera()
	game._camera.force_update_scroll()
	var half_view := (
		game.get_viewport().get_visible_rect().size
		/ (game._camera.zoom * 2.0)
	)
	var cosine := absf(cos(game._camera.rotation))
	var sine := absf(sin(game._camera.rotation))
	var rotated_half_view := Vector2(
		cosine * half_view.x + sine * half_view.y,
		sine * half_view.x + cosine * half_view.y
	)
	_check(
		not is_zero_approx(game._camera.rotation)
		and absf(game._camera.rotation)
		<= crane.camera_rotation_limit
		and not game._camera.position_smoothing_enabled
		and game._camera.global_position != crane.global_position
		and game._camera.global_position != camera_before_rotation
		and crane.interior_rect().grow(0.1).encloses(
			Rect2(
				game._camera.global_position - rotated_half_view,
				rotated_half_view * 2.0
			)
		),
		"The elevated deck camera follows movement without revealing adjacent rooms."
	)

	game._pending_growth_tier = 2
	game._frog.global_position = crane.global_position
	game._last_safe_ground_position = crane.global_position
	game._retry_pending_growth()
	_check(
		game._growth_tier == 2
		and game._pending_growth_tier == -1
		and game._find_safe_frog_position(44.0) != Vector2.INF,
		"The crane deck retains safe central navigation at maximum size."
	)

	game._frog.global_position = toolbox.global_position + Vector2(0, 120)
	game._swallow_target(toolbox, 1.0)
	_check(
		game._belly.size() == 1
		and game._belly[0].target_id
		== "construction_crane_toolbox"
		and game._belly[0].movement_bounds == crane.interior_rect(),
		"Swallowing the toolbox preserves its crane-deck restock bounds."
	)
	game._spit_item(0)
	var spat_toolbox := _find_target(
		game,
		"construction_crane_toolbox"
	)
	_check(
		game._belly.is_empty()
		and is_instance_valid(spat_toolbox)
		and spat_toolbox.dangerous_location
		and crane.interior_rect().has_point(
			spat_toolbox.global_position
		),
		"Spitting the toolbox on the deck preserves its dangerous elevated location."
	)
	game._swallow_target(spat_toolbox, 1.0)

	game.set_motion_scale(0.0)
	game._frog.global_position = crane.exit_approach_position()
	var handled_return := game._try_handle_interior_transition_tap(
		crane.exit_marker_position()
	)
	_check(
		handled_return
		and game._active_interior_id.is_empty()
		and game._frog.global_position
		== (city_portal["approach_position"] as Vector2)
		and game._interior_transition_phase
		== FrogGame.InteriorTransitionPhase.NONE
		and is_equal_approx(game._camera.rotation, city_camera_rotation)
		and game._camera.position_smoothing_enabled
		and game._active_navigation_rect() == FrogGame.WORLD_RECT,
		"Reduce motion returns immediately to the lift and restores the city camera."
	)
	game._spit_item(0)
	_check(
		game._belly.size() == 1
		and game._status_label.text.contains(
			"construction crane high deck"
		),
		"A crane-deck target cannot be spat into the city."
	)
	game._digest_item(0)

	await create_timer(9.2, false).timeout
	var restocked_toolbox := _find_target(
		game,
		"construction_crane_toolbox"
	)
	_check(
		is_instance_valid(restocked_toolbox)
		and restocked_toolbox.dangerous_location
		and crane.interior_rect().has_point(
			restocked_toolbox.global_position
		)
		and game._active_interior_id.is_empty(),
		"Digesting the toolbox restocks it on the crane deck."
	)

	paused = false
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
