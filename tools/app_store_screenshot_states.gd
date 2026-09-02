class_name AppStoreScreenshotStates
extends RefCounted

const GAME_SCENE := preload("res://scenes/game.tscn")
const PURSUER_SCRIPT := preload("res://src/pursuer.gd")
const ROADBLOCK_SCRIPT := preload("res://src/roadblock.gd")
const PURSUIT_TRAP_SCRIPT := preload("res://src/pursuit_trap.gd")

const PROFILE_ID := "app_store_screenshot_profile"
const PROFILE_NAME := "Sam"
const SESSION_SEED := 20260901
const INVOCATION_FLAG := "--app-store-screenshot-harness"

const STATE_CITY_OVERVIEW := "city_overview"
const STATE_TONGUE_CATCH := "tongue_catch"
const STATE_ENORMOUS_PURSUIT := "enormous_pursuit"
const STATE_WEATHER_FESTIVAL := "weather_festival"
const STATE_BELLY := "belly"
const STATE_GUIDE_JOURNAL := "guide_journal"
const STATE_ACCESSIBILITY_OPTIONS := "accessibility_options"

const SPECS := [
	{
		"id": STATE_CITY_OVERVIEW,
		"filename": "01-city-overview.png",
	},
	{
		"id": STATE_TONGUE_CATCH,
		"filename": "02-tongue-catch.png",
	},
	{
		"id": STATE_ENORMOUS_PURSUIT,
		"filename": "03-enormous-pursuit.png",
	},
	{
		"id": STATE_WEATHER_FESTIVAL,
		"filename": "04-weather-festival.png",
	},
	{
		"id": STATE_BELLY,
		"filename": "05-belly.png",
	},
	{
		"id": STATE_GUIDE_JOURNAL,
		"filename": "06-guide-journal.png",
	},
	{
		"id": STATE_ACCESSIBILITY_OPTIONS,
		"filename": "07-accessibility-options.png",
	},
]


static func screenshot_specs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec in SPECS:
		result.append((spec as Dictionary).duplicate(true))
	return result


static func instantiate_game(state_id: String) -> FrogGame:
	if not harness_invoked():
		push_error(
			"App Store screenshot states require the dedicated harness flag."
		)
		return null
	if not _state_ids().has(state_id):
		push_error("Unknown App Store screenshot state: %s." % state_id)
		return null
	var preferences := AccessibilityPresentation.defaults()
	preferences["reduce_motion"] = true
	if state_id == STATE_ACCESSIBILITY_OPTIONS:
		preferences["larger_text_controls"] = true
		preferences["input_assist_mode"] = (
			AccessibilityPresentation.INPUT_ASSIST_RELAXED
		)
		preferences["camera_sensitivity"] = 1.15
		preferences["camera_auto_align"] = true
		preferences["haptics_enabled"] = true
		preferences["left_handed_hud"] = true

	var discoveries := PackedStringArray([
		"street_donut",
		"market_apple",
		"running_hotdog",
		"park_chair",
		"market_vendor",
		"market_rooftop_beehive",
	])
	var powers := PackedStringArray()
	var profile_achievements := PackedStringArray()
	var device_achievements := PackedStringArray()
	var story_clues := PackedStringArray()
	var secret_unlocks := PackedStringArray()
	if state_id == STATE_GUIDE_JOURNAL:
		discoveries = DiscoveryCatalog.ids()
		powers = ProgressionCatalog.power_ids()
		profile_achievements = (
			ProgressionCatalog.profile_achievement_ids()
		)
		device_achievements = ProgressionCatalog.device_achievement_ids()
		story_clues = ProgressionCatalog.story_clue_ids()
		secret_unlocks = ProgressionCatalog.secret_unlock_ids()

	var game := GAME_SCENE.instantiate() as FrogGame
	game.configure(
		PROFILE_ID,
		PROFILE_NAME,
		false,
		discoveries,
		preferences,
		AudioPreferences.defaults(),
		SESSION_SEED,
		powers,
		profile_achievements,
		device_achievements,
		story_clues,
		secret_unlocks
	)
	return game


static func author_state(game: FrogGame, state_id: String) -> bool:
	if not harness_invoked():
		push_error(
			"App Store screenshot authoring requires the dedicated harness flag."
		)
		return false
	if not is_instance_valid(game) or not game.is_inside_tree():
		push_error("Screenshot states require a live FrogGame.")
		return false
	if not _state_ids().has(state_id):
		push_error("Unknown App Store screenshot state: %s." % state_id)
		return false

	game.get_tree().paused = false
	_prepare_common_state(game)
	var authored := false
	match state_id:
		STATE_CITY_OVERVIEW:
			authored = _author_city_overview(game)
		STATE_TONGUE_CATCH:
			authored = _author_tongue_catch(game)
		STATE_ENORMOUS_PURSUIT:
			authored = _author_enormous_pursuit(game)
		STATE_WEATHER_FESTIVAL:
			authored = _author_weather_festival(game)
		STATE_BELLY:
			authored = _author_belly(game)
		STATE_GUIDE_JOURNAL:
			authored = _author_guide_journal(game)
		STATE_ACCESSIBILITY_OPTIONS:
			authored = _author_accessibility_options(game)
	if not authored:
		return false

	game._update_target_presentation()
	game._update_hud()
	game._update_camera()
	game._camera.reset_smoothing()
	return true


static func harness_invoked() -> bool:
	return OS.get_cmdline_user_args().has(INVOCATION_FLAG)


static func _state_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for spec in SPECS:
		result.append(str(spec["id"]))
	return result


static func _prepare_common_state(game: FrogGame) -> void:
	game.set_motion_scale(0.0)
	game._frog.stop_moving()
	game._frog.movement_enabled = false
	game._frog.clear_knockback()
	game._frog.set_process(false)
	game._frog.set_physics_process(false)
	game._camera.position_smoothing_enabled = false
	game._camera.rotation = 0.0
	game._camera.offset = Vector2.ZERO
	game._city_camera_rotation = 0.0
	game._challenge_panel.visible = false
	game._tutorial_panel.visible = false
	game._tutorial_marker.active = false
	game._belly_overlay.visible = false
	game._guide_overlay.visible = false
	game._options_overlay.visible = false
	game._struggle_panel.visible = false
	game._reward_label.visible = false
	game._discovery_banner.visible = false
	game._touch_feedback._feedback.clear()
	game._touch_feedback.set_process(false)
	game._touch_feedback.queue_redraw()
	game._hide_tongue()
	game._struggle_target = null
	game._pull_target = null
	game._net_escape_active = false
	game._clear_camera_shake()
	game._save_warning_message = ""
	game._clear_save_warning()
	for target in game._targets:
		if not is_instance_valid(target):
			continue
		target.velocity = Vector2.ZERO
		target.unpredictable = false
		target.highlighted = false
		target.set_latched(false)
		target.set_process(false)
	game._sync_overlay_pause()


static func _author_city_overview(game: FrogGame) -> bool:
	_set_progress(game, 860, 420, 1)
	game._frog.global_position = Vector2(-40, 510)
	game._frog.rotation = 0.0
	game._camera.zoom = Vector2(0.76, 0.76)
	game._city_camera_zoom = game._camera.zoom
	_set_city_clock(game, 0.23)
	_set_status(
		game,
		"Explore Moonlight Market, River Park, rooftops, and the city beyond."
	)
	return true


static func _author_tongue_catch(game: FrogGame) -> bool:
	_set_progress(game, 240, 74, 0)
	game._frog.global_position = Vector2(20, 500)
	game._frog.rotation = -0.2
	game._camera.zoom = GameplayTuning.city_camera_zoom(0)
	game._city_camera_zoom = game._camera.zoom
	_set_city_clock(game, 0.34)
	var target := _find_target(game, "running_hotdog")
	if not is_instance_valid(target):
		push_error("Tongue screenshot target is missing.")
		return false
	target.global_position = Vector2(325, 255)
	target.target_color = Color("e8974f")
	target.resistant = true
	target.taps_required = 7
	target.highlighted = true
	target.set_latched(true)
	target.queue_redraw()
	game._struggle_target = target
	game._struggle_accuracy = 0.96
	game._struggle_taps = 5
	game._struggle_required_taps = 7
	game._struggle_time_left = 2.4
	game._struggle_progress.max_value = 7
	game._struggle_progress.value = 5
	game._struggle_title.text = "Great aim — 96% accuracy!"
	game._struggle_hint.text = (
		"Ring, chevrons, progress, and text confirm the catch."
	)
	game._struggle_panel.visible = true
	game._show_tongue(target.global_position)
	_set_status(
		game,
		"Accuracy: 96% — centered hit confirmed without relying on color."
	)
	return true


static func _author_enormous_pursuit(game: FrogGame) -> bool:
	_set_progress(game, 2840, 2200, GameplayTuning.ENORMOUS_TIER)
	game._frog.global_position = Vector2(-120, 520)
	game._frog.rotation = -0.35
	game._camera.zoom = GameplayTuning.city_camera_zoom(
		GameplayTuning.ENORMOUS_TIER
	)
	game._city_camera_zoom = game._camera.zoom
	_set_city_clock(game, 0.84)

	var pursuer := PURSUER_SCRIPT.new() as PrototypePursuer
	pursuer.configure_archetype(PrototypePursuer.ARCHETYPE_ANIMAL_CONTROL)
	pursuer.frog = game._frog
	pursuer.navigation = game._navigation
	pursuer.position = Vector2(465, 330)
	pursuer.rotation = 0.45
	pursuer.active = false
	pursuer.set_presentation_motion_scale(0.0)
	game._world.add_child(pursuer)
	pursuer.set_physics_process(false)
	game._pursuer = pursuer

	var roadblock := ROADBLOCK_SCRIPT.new() as PrototypeRoadblock
	roadblock.position = Vector2(0, 430)
	roadblock.configure_layout(
		PrototypeRoadblock.LAYOUT_STAGGERED,
		Vector2(360, 52)
	)
	game._world.add_child(roadblock)
	roadblock.set_process(false)
	game._roadblock = roadblock

	var trap := PURSUIT_TRAP_SCRIPT.new() as PrototypePursuitTrap
	trap.configure_variant(PrototypePursuitTrap.VARIANT_SNARE)
	trap.position = Vector2(350, -285)
	trap.set_presentation_motion_scale(0.0)
	game._world.add_child(trap)
	trap.advance(1.0)
	game._pursuit_trap = trap

	game._show_tongue(pursuer.global_position)
	_set_status(
		game,
		"Enormous! Pursuers are edible — turn the whole chase around."
	)
	return true


static func _author_weather_festival(game: FrogGame) -> bool:
	_set_progress(game, 1280, 760, 2)
	game._frog.global_position = Vector2(720, 690)
	game._frog.rotation = 0.15
	game._camera.zoom = Vector2(0.74, 0.74)
	game._city_camera_zoom = game._camera.zoom
	_set_city_clock(game, 0.50)
	var chair := _find_target(game, "park_chair")
	if is_instance_valid(chair):
		chair.highlighted = true
		chair.queue_redraw()
	_set_status(
		game,
		"Canal Kite Festival — city activity changes with time and weather."
	)
	return true


static func _author_belly(game: FrogGame) -> bool:
	_set_progress(game, 1460, 920, 2)
	game._frog.global_position = Vector2(-40, 510)
	game._belly.clear()
	game._belly.append(
		_make_belly_item(
			"market_apple",
			"Market Apple",
			"food",
			18,
			0,
			0.96
		)
	)
	game._belly.append(
		_make_belly_item(
			"running_hotdog",
			"Runaway Hot Dog",
			"living",
			30,
			0,
			0.91,
			false,
			true
		)
	)
	game._belly.append(
		_make_belly_item(
			"market_rooftop_beehive",
			"Rooftop Beehive",
			"object",
			72,
			1,
			0.94,
			true
		)
	)
	game._belly.append(
		_make_belly_item(
			"delivery_van",
			"Delivery Van",
			"vehicle",
			170,
			2,
			0.88,
			true,
			true
		)
	)
	game._rebuild_belly_list()
	game._belly_center.offset_bottom = 0.0
	game._belly_overlay.visible = true
	game._update_save_warning_surfaces()
	game._sync_overlay_pause()
	return game._belly_overlay.visible


static func _author_guide_journal(game: FrogGame) -> bool:
	_set_progress(game, 3820, 2400, GameplayTuning.ENORMOUS_TIER)
	var pages := game._guide_pages()
	for index in pages.size():
		if str(pages[index]["title"]) == "STORY CLUES":
			game._guide_page_index = index
			game._rebuild_guide()
			game._guide_overlay.visible = true
			game._update_save_warning_surfaces()
			game._sync_overlay_pause()
			return game._guide_overlay.visible
	push_error("Guide screenshot could not find the story-clue pages.")
	return false


static func _author_accessibility_options(game: FrogGame) -> bool:
	_set_progress(game, 860, 420, 1)
	game._update_accessibility_controls()
	game._tutorial_panel.visible = false
	game._options_overlay.visible = true
	game._update_save_warning_surfaces()
	game._sync_overlay_pause()
	return game._options_overlay.visible


static func _set_progress(
	game: FrogGame,
	score: int,
	growth_points: int,
	growth_tier: int
) -> void:
	game._score = score
	game._growth_points = growth_points
	game._growth_tier = growth_tier
	game._pending_growth_tier = -1
	game._frog.set_growth_tier(growth_tier)
	game._city_camera_zoom = GameplayTuning.city_camera_zoom(growth_tier)
	game._camera.zoom = game._city_camera_zoom
	game._update_hud()


static func _set_city_clock(game: FrogGame, clock: float) -> void:
	game._day_clock = fposmod(clock, 1.0)
	game._update_day_night(0.0)


static func _set_status(game: FrogGame, message: String) -> void:
	game._status_label.text = message
	game._status_time = 0.0


static func _find_target(
	game: FrogGame,
	target_id: String
) -> EdibleTarget:
	for target in game._targets:
		if is_instance_valid(target) and target.target_id == target_id:
			return target
	return null


static func _make_belly_item(
	target_id: String,
	display_name: String,
	kind: String,
	base_value: int,
	size_tier: int,
	accuracy: float,
	dangerous: bool = false,
	chased: bool = false
) -> BellyItem:
	var item := BellyItem.new()
	item.target_id = target_id
	item.display_name = display_name
	item.kind = kind
	item.base_value = base_value
	item.size_tier = size_tier
	item.accuracy = accuracy
	item.dangerous_location = dangerous
	item.captured_while_chased = chased
	item.restockable = false
	return item
