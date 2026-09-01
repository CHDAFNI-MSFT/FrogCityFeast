extends SceneTree

const GAME_SCENE := preload("res://scenes/game.tscn")
const BUDGETS := preload("res://src/performance_budgets.gd")
const INSTRUMENTATION := preload(
	"res://src/performance_instrumentation.gd"
)

var _failures: Array[String] = []
var _measure := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_measure = OS.get_cmdline_user_args().has("--measure")
	if _measure and DisplayServer.get_name().to_lower() == "headless":
		_failures.append(
			"Rendered performance measurement cannot run in headless mode."
		)
		await _finish()
		return

	_check(
		BUDGETS.MAX_VISUAL_EFFECTS == FeelEffects.MAX_EFFECTS,
		"The visual-effect budget matches the implementation cap."
	)
	_check(
		BUDGETS.MAX_CITY_ACTORS
		== (
			CityActivity.PEDESTRIAN_ROUTES.size()
			+ CityActivity.VEHICLE_ROUTES.size()
			+ CityActivity.CROWD_MEMBER_OFFSETS.size()
		),
		"The city-actor budget matches the authored route count."
	)
	_check(
		BUDGETS.MAX_CROWD_MEMBERS
		== CityActivity.CROWD_MEMBER_OFFSETS.size(),
		"The River Park meetup budget matches its fixed crowd."
	)
	_check(
		BUDGETS.MAX_RAIN_STREAKS == CityActivity.RAIN_STREAK_COUNT,
		"The rain-streak budget matches the draw-only presentation cap."
	)
	_check(
		BUDGETS.MAX_FESTIVAL_LANTERNS
		== CityActivity.FESTIVAL_LANTERN_OFFSETS.size(),
		"The night-bazaar budget matches the fixed lantern count."
	)
	_check(
		BUDGETS.MAX_NET_PROJECTILES == 1,
		"The Animal Control projectile budget remains capped at one."
	)
	_check(
		BUDGETS.MAX_ROADBLOCKS == 1,
		"The Animal Control roadblock budget remains capped at one."
	)
	_check(
		BUDGETS.MAX_PURSUIT_TRAPS == 1,
		"The Animal Control snare budget remains capped at one."
	)
	_check(
		BUDGETS.MAX_INTERIOR_ROOMS == 9,
		"The authored separate-room budget matches all connected rooms."
	)
	_check(
		BUDGETS.MAX_NAVIGATION_OBSTACLES
			== DeterministicNavigation2D.MAX_OBSTACLES
			and BUDGETS.MAX_NAVIGATION_QUERY_CELLS
			== DeterministicNavigation2D.MAX_TOTAL_QUERY_CELLS
			and BUDGETS.MAX_NAVIGATION_PATH_POINTS
			== DeterministicNavigation2D.MAX_PATH_POINTS,
		"The navigation budgets match the deterministic router caps."
	)
	_check(
		BUDGETS.MAX_LOADED_GENERATED_DISTRICTS
			== DistrictGenerator.MAX_LOADED_GENERATED_DISTRICTS
			and BUDGETS.MAX_GENERATED_BUILDINGS
			== (
				BUDGETS.MAX_LOADED_GENERATED_DISTRICTS
				* DistrictGenerator.BUILDINGS_PER_DISTRICT
			)
			and BUDGETS.MAX_GENERATED_TARGETS
			== (
				BUDGETS.MAX_LOADED_GENERATED_DISTRICTS
				* (
					DistrictGenerator.LOOSE_TARGETS_PER_DISTRICT
					+ DistrictGenerator.BUILDINGS_PER_DISTRICT * 4
				)
			),
		"The generated district budgets match the streaming content caps."
	)
	_check(
		BUDGETS.FIELD_GUIDE_ROWS == DiscoveryCatalog.count(),
		"The Field Guide budget matches the catalog."
	)
	_check(
		BUDGETS.MAX_AUDIO_NODES == 1 + FrogAudioDirector.TOTAL_PLAYER_COUNT
			and BUDGETS.MAX_AUDIO_PLAYERS
			== FrogAudioDirector.TOTAL_PLAYER_COUNT
			and BUDGETS.MAX_AUDIO_EFFECT_VOICES
			== FrogAudioDirector.EFFECT_VOICE_LIMIT,
		"The global audio budgets match the fixed reusable player pool."
	)
	await _test_instrumentation_component()

	var scenarios := [
		{
			"name": "baseline",
			"setup": _setup_baseline,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "stockroom",
			"setup": _setup_stockroom,
			"preferences": {
				"reduce_motion": true,
				"larger_text_controls": false,
			},
			"discoveries": PackedStringArray(),
		},
		{
			"name": "upper_hall",
			"setup": _setup_upper_hall,
			"preferences": {
				"reduce_motion": true,
				"larger_text_controls": false,
			},
			"discoveries": PackedStringArray(),
		},
		{
			"name": "fire_escape",
			"setup": _setup_fire_escape,
			"preferences": {
				"reduce_motion": true,
				"larger_text_controls": false,
			},
			"discoveries": PackedStringArray(),
		},
		{
			"name": "sewer_tunnel",
			"setup": _setup_sewer_tunnel,
			"preferences": {
				"reduce_motion": true,
				"larger_text_controls": false,
			},
			"discoveries": PackedStringArray(),
		},
		{
			"name": "pond_boardwalk",
			"setup": _setup_pond_boardwalk,
			"preferences": {
				"reduce_motion": true,
				"larger_text_controls": false,
			},
			"discoveries": PackedStringArray(),
		},
		{
			"name": "crane_deck",
			"setup": _setup_crane_deck,
			"preferences": {
				"reduce_motion": true,
				"larger_text_controls": false,
			},
			"discoveries": PackedStringArray(),
		},
		{
			"name": "market_rooftop",
			"setup": _setup_market_rooftop,
			"preferences": {
				"reduce_motion": true,
				"larger_text_controls": false,
			},
			"discoveries": PackedStringArray(),
		},
		{
			"name": "oddities_cellar",
			"setup": _setup_oddities_cellar,
			"preferences": {
				"reduce_motion": true,
				"larger_text_controls": false,
			},
			"discoveries": PackedStringArray(),
		},
		{
			"name": "night_shop",
			"setup": _setup_night_shop,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "busy_daytime",
			"setup": _setup_busy_daytime,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "rainy_day",
			"setup": _setup_rainy_day,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "pursuit",
			"setup": _setup_pursuit,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "tongue_deflect",
			"setup": _setup_tongue_deflect,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "crowd_pursuit",
			"setup": _setup_crowd_pursuit,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "roadblock",
			"setup": _setup_roadblock,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "pursuit_trap",
			"setup": _setup_pursuit_trap,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "net_attack",
			"setup": _setup_net_attack,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "maximum_growth",
			"setup": _setup_maximum_growth,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "presentation_peak",
			"setup": _setup_presentation_peak,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "belly_overlay",
			"setup": _setup_belly_overlay,
			"preferences": _default_preferences(),
			"discoveries": PackedStringArray(),
		},
		{
			"name": "field_guide_overlay",
			"setup": _setup_field_guide_overlay,
			"preferences": _default_preferences(),
			"discoveries": DiscoveryCatalog.ids(),
		},
		{
			"name": "accessibility_options",
			"setup": _setup_accessibility_options,
			"preferences": {
				"reduce_motion": true,
				"larger_text_controls": true,
			},
			"discoveries": DiscoveryCatalog.ids(),
		},
		{
			"name": "gameplay_peak",
			"setup": _setup_gameplay_peak,
			"preferences": _default_preferences(),
			"discoveries": DiscoveryCatalog.ids(),
		},
		{
			"name": "generated_streaming",
			"setup": _setup_generated_streaming,
			"preferences": _default_preferences(),
			"discoveries": DiscoveryCatalog.ids(),
		},
	]

	if _measure:
		print(
			"Rendered measurements are advisory. "
			+ "A16 iPad acceptance still requires on-device profiling."
		)
	for scenario in scenarios:
		await _run_scenario(scenario)
	await _finish()


func _run_scenario(scenario: Dictionary) -> void:
	var game := await _create_game(
		scenario["preferences"],
		scenario["discoveries"]
	)
	(scenario["setup"] as Callable).call(game)
	await process_frame
	await process_frame
	var scenario_name := str(scenario["name"])
	var snapshot := game.performance_structure_snapshot()
	var violations := BUDGETS.structural_violations(
		scenario_name,
		snapshot
	)
	_check(
		violations.is_empty(),
		"%s stays within structural budgets%s"
		% [
			scenario_name,
			"" if violations.is_empty() else ": " + "; ".join(violations),
		]
	)
	_check_scenario_expectations(scenario_name, snapshot)
	if _measure:
		await _measure_scenario(scenario_name, game)
	await _dispose_game(game)


func _create_game(
	preferences: Dictionary,
	discoveries: PackedStringArray
) -> FrogGame:
	seed(BUDGETS.STRESS_RANDOM_SEED)
	var game := GAME_SCENE.instantiate() as FrogGame
	game.configure(
		"performance_smoke",
		"Performance Smoke",
		false,
		discoveries,
		preferences,
		{},
		BUDGETS.STRESS_RANDOM_SEED
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	return game


func _dispose_game(game: FrogGame) -> void:
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	await process_frame


func _default_preferences() -> Dictionary:
	return {
		"reduce_motion": false,
		"larger_text_controls": false,
	}


func _setup_baseline(_game: FrogGame) -> void:
	pass


func _setup_stockroom(game: FrogGame) -> void:
	var cafe := (
		game._building_by_id.get("leap_cafe") as PrototypeBuilding
	)
	game._frog.global_position = cafe.transition_door_approach_position()
	game._begin_interior_transition(FrogGame.STOCKROOM_ID)


func _setup_upper_hall(game: FrogGame) -> void:
	var apartments := (
		game._building_by_id.get("canal_apartments")
		as PrototypeBuilding
	)
	game._frog.global_position = apartments.transition_door_approach_position()
	game._begin_interior_transition(FrogGame.CANAL_UPPER_HALL_ID)


func _setup_fire_escape(game: FrogGame) -> void:
	var apartments := (
		game._building_by_id.get("canal_apartments")
		as PrototypeBuilding
	)
	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._frog.global_position = apartments.transition_door_approach_position()
	game._begin_interior_transition(FrogGame.CANAL_UPPER_HALL_ID)
	var upper_hall := (
		game._interior_rooms.get(FrogGame.CANAL_UPPER_HALL_ID)
		as PrototypeInteriorRoom
	)
	var portal := upper_hall.portal_by_id("fire_escape_door")
	game._frog.global_position = upper_hall.portal_approach_position(portal)
	game._begin_interior_transition(
		FrogGame.CANAL_FIRE_ESCAPE_ID,
		"fire_escape_door"
	)


func _setup_sewer_tunnel(game: FrogGame) -> void:
	var city_portal := game._city_portal_by_id("river_sewer_hatch")
	game._frog.global_position = city_portal["approach_position"] as Vector2
	game._begin_interior_transition(
		FrogGame.RIVER_SEWER_JUNCTION_ID,
		"river_sewer_hatch"
	)
	var junction := (
		game._interior_rooms.get(FrogGame.RIVER_SEWER_JUNCTION_ID)
		as PrototypeInteriorRoom
	)
	var portal := junction.portal_by_id("service_tunnel")
	game._frog.global_position = junction.portal_approach_position(portal)
	game._begin_interior_transition(
		FrogGame.RIVER_SUBWAY_TUNNEL_ID,
		"service_tunnel"
	)


func _setup_pond_boardwalk(game: FrogGame) -> void:
	var portal := game._city_portal_by_id("river_pond_boardwalk")
	game._frog.global_position = portal["approach_position"] as Vector2
	game._begin_interior_transition(
		FrogGame.RIVER_POND_BOARDWALK_ID,
		"river_pond_boardwalk"
	)


func _setup_crane_deck(game: FrogGame) -> void:
	var portal := game._city_portal_by_id("construction_crane_lift")
	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._frog.global_position = portal["approach_position"] as Vector2
	game._begin_interior_transition(
		FrogGame.CONSTRUCTION_CRANE_ID,
		"construction_crane_lift"
	)


func _setup_market_rooftop(game: FrogGame) -> void:
	var market := (
		game._building_by_id.get("moonlight_market")
		as PrototypeBuilding
	)
	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	game._frog.global_position = market.transition_door_approach_position()
	game._begin_interior_transition(FrogGame.MARKET_ROOFTOP_ID)


func _setup_oddities_cellar(game: FrogGame) -> void:
	var shop := (
		game._building_by_id.get("oddities_shop")
		as PrototypeBuilding
	)
	game._growth_tier = 1
	game._frog.set_growth_tier(1)
	shop.remove_part(PrototypeBuilding.PART_COUNTER)
	game._frog.global_position = shop.transition_door_approach_position()
	game._begin_interior_transition(FrogGame.ODDITIES_CELLAR_ID)


func _setup_night_shop(game: FrogGame) -> void:
	game._day_clock = 0.0
	game._update_day_night(0.0)


func _setup_busy_daytime(game: FrogGame) -> void:
	game._day_clock = 0.5
	game._update_day_night(0.0)


func _setup_rainy_day(game: FrogGame) -> void:
	game._day_clock = 0.68
	game._update_day_night(0.0)


func _setup_pursuit(game: FrogGame) -> void:
	game._spawn_pursuer()


func _setup_tongue_deflect(game: FrogGame) -> void:
	game._spawn_pursuer()
	game._pursuer.pulse_deflect()


func _setup_crowd_pursuit(game: FrogGame) -> void:
	game._day_clock = 0.5
	game._update_day_night(0.0)
	game._frog.global_position = CityActivity.CROWD_CENTER
	game._spawn_pursuer()
	game._pursuer.set_physics_process(false)
	game._update_crowd_hiding(FrogGame.CROWD_HIDE_DURATION * 0.5)


func _setup_roadblock(game: FrogGame) -> void:
	game._frog.global_position = Vector2(0, -520)
	game._spawn_pursuer()
	game._roadblock_deploy_time = 0.0
	game._update_pursuit_roadblock(0.1)


func _setup_pursuit_trap(game: FrogGame) -> void:
	game._frog.global_position = Vector2(0, -520)
	game._spawn_pursuer()
	game._pursuit_trap_deploy_time = 0.0
	game._update_pursuit_trap(0.1)


func _setup_net_attack(game: FrogGame) -> void:
	game._spawn_pursuer()
	game._pursuer._begin_net_attack()
	game._pursuer._advance_net_attack(
		PrototypePursuer.NET_WINDUP_DURATION
	)


func _setup_maximum_growth(game: FrogGame) -> void:
	game._apply_growth_tier(2)


func _setup_presentation_peak(game: FrogGame) -> void:
	game._apply_growth_tier(2)
	for index in BUDGETS.MAX_VISUAL_EFFECTS:
		if index % 3 == 0:
			game._effects.emit_damage(
				game._frog.global_position + Vector2(index * 3, 0)
			)
		else:
			game._effects.emit_swallow(
				game._frog.global_position + Vector2(index * 3, 0),
				Color("72dc78"),
				index % 4 == 0
			)
	for target in game._targets:
		target.pulse_feedback(1.0)
	game._frog.celebrate_growth(1.0)
	game._touch_feedback.show_move(game._frog.global_position)
	game._touch_feedback.show_tongue(Vector2(640, 480))
	game._touch_feedback.show_camera(Vector2(720, 480))
	game._trigger_camera_shake(8.0, 0.24)
	game._show_tongue(game._frog.global_position + Vector2(300, 0))


func _setup_belly_overlay(game: FrogGame) -> void:
	for index in BUDGETS.BELLY_STRESS_ITEMS:
		var source: EdibleTarget = game._targets[
			index % game._targets.size()
		]
		game._belly.append(
			source.make_belly_item(
				0.72 + float(index % 20) * 0.01,
				index % 5 == 0,
				index % 7 == 0
			)
		)
	game._open_belly()


func _setup_field_guide_overlay(game: FrogGame) -> void:
	game._open_guide()


func _setup_accessibility_options(game: FrogGame) -> void:
	game._open_options()


func _setup_gameplay_peak(game: FrogGame) -> void:
	_setup_busy_daytime(game)
	_setup_roadblock(game)
	game._pursuit_trap_deploy_time = 0.0
	game._update_pursuit_trap(0.1)
	_setup_presentation_peak(game)
	_exercise_navigation_detour(game, false)


func _setup_generated_streaming(game: FrogGame) -> void:
	game._frog.global_position = DistrictGenerator.bounds_for_coordinate(
		Vector2i(2, 2)
	).get_center()
	game._update_district_streaming()
	_exercise_navigation_detour(game, true)


func _exercise_navigation_detour(
	game: FrogGame,
	generated_only: bool
) -> void:
	game._update_navigation_paths()
	var selected_building: PrototypeBuilding
	for candidate in game._buildings:
		if not is_instance_valid(candidate) or candidate.consumed:
			continue
		var generated := candidate.has_meta("district_coordinate")
		if generated != generated_only:
			continue
		if (
			generated
			and candidate.get_meta("district_coordinate")
			!= game._current_district_coordinate
		):
			continue
		selected_building = candidate
		break
	_check(
		is_instance_valid(selected_building),
		"%s provides deterministic navigation geometry."
		% ("Generated streaming" if generated_only else "Gameplay peak")
	)
	if not is_instance_valid(selected_building):
		return
	var footprint := selected_building.footprint_rect()
	var offset := Vector2(
		footprint.size.x * 0.5 + 150.0,
		0.0
	)
	var route := game._navigation.find_path(
		footprint.get_center() - offset,
		footprint.get_center() + offset,
		PrototypePursuer.NAVIGATION_RADIUS
	)
	var points := route["points"] as PackedVector2Array
	_check(
		bool(route["reachable"])
			and not bool(route["fallback"])
			and points.size() >= 4
			and game._navigation.path_is_clear(
				points,
				PrototypePursuer.NAVIGATION_RADIUS
			),
		"%s creates a successful multi-corner navigation query."
		% ("Generated streaming" if generated_only else "Gameplay peak")
	)


func _check_scenario_expectations(
	scenario_name: String,
	snapshot: Dictionary
) -> void:
	match scenario_name:
		"baseline":
			_check(
				int(snapshot["targets"]) == BUDGETS.MAX_TARGETS
				and int(snapshot["buildings"]) == BUDGETS.MAX_BUILDINGS
				and int(snapshot["pursuers"]) == 0
				and int(snapshot["active_effects"]) == 0
				and int(snapshot["audio_nodes"])
				== BUDGETS.MAX_AUDIO_NODES
				and int(snapshot["audio_players"])
				== BUDGETS.MAX_AUDIO_PLAYERS
				and int(snapshot["audio_effect_voices"])
				== BUDGETS.MAX_AUDIO_EFFECT_VOICES
				and not bool(snapshot["performance_instrumentation"]),
				"Baseline contains the documented fixed gameplay and audio structure."
			)
		"stockroom":
			_check(
				str(snapshot["active_interior"]) == FrogGame.STOCKROOM_ID
					and int(snapshot["interior_rooms"])
					== BUDGETS.MAX_INTERIOR_ROOMS
					and int(snapshot["pursuers"]) == 0,
				"Stockroom stress activates one authored room without adding pursuit."
			)
		"upper_hall":
			_check(
				str(snapshot["active_interior"])
				== FrogGame.CANAL_UPPER_HALL_ID
				and int(snapshot["interior_rooms"])
				== BUDGETS.MAX_INTERIOR_ROOMS
				and int(snapshot["pursuers"]) == 0,
				"Upper-hall stress activates one authored room without adding pursuit."
			)
		"fire_escape":
			_check(
				str(snapshot["active_interior"])
				== FrogGame.CANAL_FIRE_ESCAPE_ID
				and int(snapshot["interior_rooms"])
				== BUDGETS.MAX_INTERIOR_ROOMS
				and int(snapshot["pursuers"]) == 0
				and int(snapshot["growth_tier"]) == 1,
				"Fire-escape stress activates the navigable room-chain destination."
			)
		"sewer_tunnel":
			_check(
				str(snapshot["active_interior"])
				== FrogGame.RIVER_SUBWAY_TUNNEL_ID
				and int(snapshot["interior_rooms"])
				== BUDGETS.MAX_INTERIOR_ROOMS
				and int(snapshot["pursuers"]) == 0,
				"Sewer stress activates the second navigable section of the chain."
			)
		"pond_boardwalk":
			_check(
				str(snapshot["active_interior"])
				== FrogGame.RIVER_POND_BOARDWALK_ID
				and int(snapshot["interior_rooms"])
				== BUDGETS.MAX_INTERIOR_ROOMS
				and int(snapshot["pursuers"]) == 0,
				"Pond stress activates the navigable River Park boardwalk."
			)
		"crane_deck":
			_check(
				str(snapshot["active_interior"])
				== FrogGame.CONSTRUCTION_CRANE_ID
				and int(snapshot["interior_rooms"])
				== BUDGETS.MAX_INTERIOR_ROOMS
				and int(snapshot["growth_tier"]) == 1
				and int(snapshot["pursuers"]) == 0,
				"Crane stress activates the growth-gated elevated deck."
			)
		"market_rooftop":
			_check(
				str(snapshot["active_interior"])
				== FrogGame.MARKET_ROOFTOP_ID
				and int(snapshot["interior_rooms"])
				== BUDGETS.MAX_INTERIOR_ROOMS
				and int(snapshot["pursuers"]) == 0
				and int(snapshot["growth_tier"]) == 1,
				"Rooftop stress activates the progression-gated separate room."
			)
		"oddities_cellar":
			_check(
				str(snapshot["active_interior"])
				== FrogGame.ODDITIES_CELLAR_ID
				and int(snapshot["interior_rooms"])
				== BUDGETS.MAX_INTERIOR_ROOMS
				and int(snapshot["pursuers"]) == 0
				and int(snapshot["growth_tier"]) == 1,
				"Cellar stress activates the fixture-gated separate room."
			)
		"night_shop":
			_check(
				bool(snapshot["oddities_shop_scheduled_open"])
				and is_equal_approx(
					float(snapshot["festival_intensity"]),
					1.0
				)
				and int(snapshot["festival_lanterns"])
				== BUDGETS.MAX_FESTIVAL_LANTERNS,
				"Night stress opens Oddities Shop and activates the bounded bazaar without adding structure."
			)
		"busy_daytime":
			_check(
				int(snapshot["active_city_actors"])
				== BUDGETS.MAX_CITY_ACTORS
				and int(snapshot["active_crowd_members"])
				== BUDGETS.MAX_CROWD_MEMBERS,
				"Busy daytime activates every route and the River Park meetup."
			)
		"rainy_day":
			_check(
				is_equal_approx(float(snapshot["rain_intensity"]), 1.0)
				and int(snapshot["rain_streaks"])
				== BUDGETS.MAX_RAIN_STREAKS
				and int(snapshot["active_pedestrians"]) == 4
				and int(snapshot["active_vehicles"]) == 3,
				"Peak rain uses bounded draw-only streaks and reduces ambient city activity."
			)
		"pursuit":
			_check(
				int(snapshot["pursuers"]) == BUDGETS.MAX_PURSUERS,
				"Pursuit stress contains one Animal Control pursuer."
			)
		"tongue_deflect":
			_check(
				int(snapshot["pursuers"]) == BUDGETS.MAX_PURSUERS
				and bool(snapshot["pursuer_deflecting"]),
				"Tongue-deflection stress uses draw-only pursuer feedback."
			)
		"crowd_pursuit":
			_check(
				int(snapshot["pursuers"]) == BUDGETS.MAX_PURSUERS
				and int(snapshot["active_crowd_members"])
				== BUDGETS.MAX_CROWD_MEMBERS
				and float(snapshot["crowd_hide_progress"]) > 0.0,
				"Crowd-pursuit stress exercises active cover before escape."
			)
		"roadblock":
			_check(
				int(snapshot["pursuers"]) == BUDGETS.MAX_PURSUERS
				and int(snapshot["roadblocks"])
				== BUDGETS.MAX_ROADBLOCKS,
				"Roadblock stress contains one pursuer and one physical barricade."
			)
		"pursuit_trap":
			_check(
				int(snapshot["pursuers"]) == BUDGETS.MAX_PURSUERS
				and int(snapshot["pursuit_traps"])
				== BUDGETS.MAX_PURSUIT_TRAPS,
				"Snare stress contains one pursuer and one draw-only trap."
			)
		"net_attack":
			_check(
				int(snapshot["pursuers"]) == BUDGETS.MAX_PURSUERS
				and int(snapshot["net_projectiles"])
				== BUDGETS.MAX_NET_PROJECTILES
				and not bool(snapshot["frog_netted"]),
				"Net-attack stress contains one draw-only projectile in flight."
			)
		"maximum_growth":
			_check(
				int(snapshot["growth_tier"]) == 2,
				"Maximum-growth stress uses the largest frog tier."
			)
		"presentation_peak":
			_check_presentation_peak(snapshot)
		"belly_overlay":
			_check(
				int(snapshot["belly_items"]) == BUDGETS.BELLY_STRESS_ITEMS
				and int(snapshot["belly_rows"])
				== BUDGETS.BELLY_STRESS_ITEMS
				and bool(snapshot["belly_overlay_visible"]),
				"Belly stress renders every row in the 64-item sample."
			)
		"field_guide_overlay":
			_check(
				int(snapshot["known_discoveries"])
				== BUDGETS.FIELD_GUIDE_ROWS
				and int(snapshot["guide_rows"]) == BUDGETS.FIELD_GUIDE_ROWS
				and bool(snapshot["guide_overlay_visible"]),
				"Field Guide stress renders the populated catalog."
			)
		"accessibility_options":
			_check(
				bool(snapshot["reduce_motion"])
				and bool(snapshot["larger_text_controls"])
				and bool(snapshot["options_overlay_visible"]),
				"Accessibility stress enables both presentation options."
			)
		"gameplay_peak":
			_check(
				int(snapshot["pursuers"]) == BUDGETS.MAX_PURSUERS
				and int(snapshot["roadblocks"])
				== BUDGETS.MAX_ROADBLOCKS
				and int(snapshot["pursuit_traps"])
				== BUDGETS.MAX_PURSUIT_TRAPS
				and int(snapshot["active_city_actors"])
				== BUDGETS.MAX_CITY_ACTORS,
				"Gameplay peak combines reachable pursuit and daytime activity."
			)
			_check_navigation_stress(snapshot, "Gameplay peak")
			_check_presentation_peak(snapshot)
		"generated_streaming":
			_check(
				int(snapshot["loaded_generated_districts"])
				== BUDGETS.MAX_LOADED_GENERATED_DISTRICTS
				and int(snapshot["generated_district_records"])
				== BUDGETS.MAX_LOADED_GENERATED_DISTRICTS
				and int(snapshot["district_state_records"]) == 0
				and int(snapshot["generated_buildings"])
				== BUDGETS.MAX_GENERATED_BUILDINGS
				and int(snapshot["generated_targets"])
				== BUDGETS.MAX_GENERATED_TARGETS,
				"Generated streaming reaches its bounded untouched 3x3 district ring."
			)
			_check_navigation_stress(snapshot, "Generated streaming")


func _check_presentation_peak(snapshot: Dictionary) -> void:
	_check(
		int(snapshot["active_effects"]) == BUDGETS.MAX_VISUAL_EFFECTS
			and int(snapshot["touch_feedback"])
			== BUDGETS.MAX_TOUCH_FEEDBACK
			and int(snapshot["tongue_points"]) == 2,
		"Presentation stress reaches the capped simultaneous feedback state."
	)


func _check_navigation_stress(
	snapshot: Dictionary,
	label: String
) -> void:
	_check(
		int(snapshot["navigation_requests"]) > 0
			and int(snapshot["navigation_successes"]) > 0
			and int(snapshot["navigation_fallbacks"]) == 0
			and int(snapshot["navigation_failures"]) == 0
			and int(snapshot["navigation_max_query_cells"]) > 0
			and int(snapshot["navigation_max_request_usec"]) > 0
			and int(snapshot["navigation_max_path_points"]) >= 4
			and int(snapshot["navigation_budget_rejections"]) == 0,
		"%s exercises bounded multi-corner navigation queries." % label
	)


func _measure_scenario(
	scenario_name: String,
	game: FrogGame
) -> void:
	var warmup_end := (
		Time.get_ticks_msec()
		+ roundi(BUDGETS.LOCAL_WARMUP_SECONDS * 1000.0)
	)
	while Time.get_ticks_msec() < warmup_end:
		await process_frame

	var frame_ms: Array[float] = []
	if scenario_name in ["presentation_peak", "gameplay_peak"]:
		_setup_presentation_peak(game)
	elif scenario_name == "net_attack":
		if game._net_escape_active:
			game._clear_net_escape()
		game._pursuer.cancel_net_attack()
		game._pursuer._begin_net_attack()
		game._pursuer._advance_net_attack(
			PrototypePursuer.NET_WINDUP_DURATION
		)
	elif scenario_name == "crowd_pursuit":
		game._day_clock = 0.5
		game._update_day_night(0.0)
		game._frog.global_position = CityActivity.CROWD_CENTER
		game._frog.clear_knockback()
		game._reset_crowd_hiding()
		if not is_instance_valid(game._pursuer):
			game._spawn_pursuer()
		game._pursuer.set_physics_process(false)
	var last_tick := Time.get_ticks_usec()
	var sample_seconds := (
		BUDGETS.TRANSIENT_SAMPLE_SECONDS
		if scenario_name in [
			"presentation_peak",
			"gameplay_peak",
			"net_attack",
			"crowd_pursuit",
		]
		else BUDGETS.LOCAL_SAMPLE_SECONDS
	)
	var sample_end := (
		Time.get_ticks_msec()
		+ roundi(sample_seconds * 1000.0)
	)
	while Time.get_ticks_msec() < sample_end:
		await process_frame
		var current_tick := Time.get_ticks_usec()
		frame_ms.append(float(current_tick - last_tick) / 1000.0)
		last_tick = current_tick

	var frame_p50 := BUDGETS.percentile(frame_ms, 0.50)
	var frame_p95 := BUDGETS.percentile(frame_ms, 0.95)
	var frame_max := BUDGETS.percentile(frame_ms, 1.0)
	if scenario_name in ["presentation_peak", "gameplay_peak"]:
		_setup_presentation_peak(game)
		await process_frame
		await process_frame
	var monitors := INSTRUMENTATION.monitor_snapshot(true, true)
	var within_reference_budgets := (
		frame_p95 <= BUDGETS.FRAME_TIME_P95_BUDGET_MS
		and int(monitors["static_memory_bytes"])
		<= BUDGETS.STATIC_MEMORY_BUDGET_BYTES
		and int(monitors["video_memory_bytes"])
		<= BUDGETS.VIDEO_MEMORY_BUDGET_BYTES
		and int(monitors["draw_calls"]) <= BUDGETS.DRAW_CALL_BUDGET
		and int(monitors["render_objects"])
		<= BUDGETS.RENDER_OBJECT_BUDGET
		and int(monitors["render_primitives"])
		<= BUDGETS.RENDER_PRIMITIVE_BUDGET
	)
	print((
		"MEASURE %s | median fps %.1f"
		+ " | frame p50 %.2f p95 %.2f max %.2f ms"
		+ " | engine process/physics snapshot %.2f / %.2f ms"
		+ " | memory %.1f MiB | video %.1f MiB"
		+ " | render %d draws %d objects %d primitives"
		+ " | frame/memory/render reference %s"
	) % [
			scenario_name,
			1000.0 / maxf(frame_p50, 0.001),
			frame_p50,
			frame_p95,
			frame_max,
			monitors["process_ms"],
			monitors["physics_ms"],
			float(monitors["static_memory_bytes"]) / 1048576.0,
			float(monitors["video_memory_bytes"]) / 1048576.0,
			monitors["draw_calls"],
			monitors["render_objects"],
			monitors["render_primitives"],
			"PASS" if within_reference_budgets else "REVIEW",
		]
	)
	var snapshot := game.performance_structure_snapshot()
	if scenario_name in ["gameplay_peak", "generated_streaming"]:
		_check_navigation_stress(
			snapshot,
			"%s rendered sample" % scenario_name.capitalize()
		)
	print("STRUCTURE %s | %s" % [scenario_name, JSON.stringify(snapshot)])


func _test_instrumentation_component() -> void:
	var instrumentation := INSTRUMENTATION.new()
	root.add_child(instrumentation)
	await process_frame
	_check(
		instrumentation.process_mode == Node.PROCESS_MODE_ALWAYS,
		"Developer instrumentation continues sampling while overlays pause."
	)
	_check(
		_all_controls_ignore_mouse(instrumentation),
		"Developer instrumentation cannot intercept gameplay input."
	)
	var headless_snapshot := INSTRUMENTATION.monitor_snapshot(false)
	_check(
		int(headless_snapshot["draw_calls"]) == -1
			and headless_snapshot.has("static_memory_bytes")
			and headless_snapshot.has("physics_collision_pairs"),
		"Headless-safe monitoring excludes render data but keeps core metrics."
	)
	instrumentation.queue_free()
	await process_frame


func _all_controls_ignore_mouse(node: Node) -> bool:
	if (
		node is Control
		and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE
	):
		return false
	for child in node.get_children():
		if not _all_controls_ignore_mouse(child):
			return false
	return true


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
		print("Performance structural checks passed.")
		quit(0)
	else:
		print(
			"Performance structural checks failed: %s"
			% ", ".join(_failures)
		)
		quit(1)
