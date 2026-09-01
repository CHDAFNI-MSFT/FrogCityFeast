class_name PerformanceBudgets
extends RefCounted

const DISTRICT_GENERATOR := preload("res://src/district_generator.gd")
const NAVIGATION := preload("res://src/deterministic_navigation.gd")

const TARGET_FPS := 60.0
const FRAME_TIME_BUDGET_MS := 1000.0 / TARGET_FPS
const FRAME_TIME_P95_BUDGET_MS := 18.0
# These percentile budgets require target-device profiler traces.
const PROCESS_TIME_P95_BUDGET_MS := 8.0
const PHYSICS_TIME_P95_BUDGET_MS := 2.0
const STATIC_MEMORY_BUDGET_BYTES := 192 * 1024 * 1024
const VIDEO_MEMORY_BUDGET_BYTES := 256 * 1024 * 1024
const DRAW_CALL_BUDGET := 450
const RENDER_OBJECT_BUDGET := 1800
const RENDER_PRIMITIVE_BUDGET := 50000

const MAX_TARGETS := 36
const MAX_BUILDINGS := 4
const MAX_INTERIOR_ROOMS := 10
const MAX_PURSUERS := 1
const MAX_VISUAL_EFFECTS := 24
const MAX_TOUCH_FEEDBACK := 3
const MAX_CROWD_MEMBERS := 5
const MAX_CITY_ACTORS := 20
const MAX_ROADBLOCKS := 1
const MAX_ROADBLOCK_SEGMENTS := PrototypeRoadblock.MAX_SEGMENTS
const MAX_PURSUIT_TRAPS := 1
const MAX_RAIN_STREAKS := 84
const MAX_WIND_RIBBONS := 40
const MAX_FESTIVAL_LANTERNS := 10
const MAX_NET_PROJECTILES := 1
const MAX_AUDIO_NODES := 7
const MAX_AUDIO_PLAYERS := 6
const MAX_AUDIO_EFFECT_VOICES := 4
const MAX_NAVIGATION_OBSTACLES := NAVIGATION.MAX_OBSTACLES
const MAX_NAVIGATION_QUERY_CELLS := NAVIGATION.MAX_TOTAL_QUERY_CELLS
const MAX_NAVIGATION_PATH_POINTS := NAVIGATION.MAX_PATH_POINTS
const FIELD_GUIDE_ROWS := 49
const MAX_LOADED_GENERATED_DISTRICTS := (
	DISTRICT_GENERATOR.MAX_LOADED_GENERATED_DISTRICTS
)
const MAX_GENERATED_BUILDINGS := (
	MAX_LOADED_GENERATED_DISTRICTS
	* DISTRICT_GENERATOR.BUILDINGS_PER_DISTRICT
)
const MAX_GENERATED_TARGETS := (
	MAX_LOADED_GENERATED_DISTRICTS
	* (
		DISTRICT_GENERATOR.LOOSE_TARGETS_PER_DISTRICT
		+ DISTRICT_GENERATOR.BUILDINGS_PER_DISTRICT * 4
	)
)
const BELLY_STRESS_ITEMS := 64
const STRESS_RANDOM_SEED := 0xF06C2026
const LOCAL_WARMUP_SECONDS := 1.25
const LOCAL_SAMPLE_SECONDS := 2.5
const TRANSIENT_SAMPLE_SECONDS := 0.75

const GLOBAL_STRUCTURAL_LIMITS := {
	"audio_nodes": MAX_AUDIO_NODES,
	"audio_players": MAX_AUDIO_PLAYERS,
	"audio_effect_voices": MAX_AUDIO_EFFECT_VOICES,
	"audio_active_effect_voices": MAX_AUDIO_EFFECT_VOICES,
	"interior_rooms": MAX_INTERIOR_ROOMS,
}
const STRUCTURAL_LIMITS := {
	"baseline": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
		"active_effects": 0,
	},
	"stockroom": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"upper_hall": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"fire_escape": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"sewer_tunnel": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"pond_boardwalk": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"crane_deck": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"hidden_maintenance": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"market_rooftop": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"oddities_cellar": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"night_shop": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
		"festival_lanterns": MAX_FESTIVAL_LANTERNS,
	},
	"busy_daytime": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"active_city_actors": MAX_CITY_ACTORS,
	},
	"rainy_day": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"rain_streaks": MAX_RAIN_STREAKS,
	},
	"wind_squall": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"active_city_actors": MAX_CITY_ACTORS,
		"wind_ribbons": MAX_WIND_RIBBONS,
	},
	"wind_security_peak": {
		"game_nodes": 372,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"pursuit_traps": MAX_PURSUIT_TRAPS,
		"active_city_actors": MAX_CITY_ACTORS,
		"wind_ribbons": MAX_WIND_RIBBONS,
		"active_effects": MAX_VISUAL_EFFECTS,
	},
	"wind_watchdog_peak": {
		"game_nodes": 372,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"pursuit_traps": MAX_PURSUIT_TRAPS,
		"active_city_actors": MAX_CITY_ACTORS,
		"wind_ribbons": MAX_WIND_RIBBONS,
		"active_effects": MAX_VISUAL_EFFECTS,
	},
	"pursuit": {
		"game_nodes": 371,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
	},
	"security_pursuit": {
		"game_nodes": 371,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
	},
	"security_flashlight": {
		"game_nodes": 371,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
	},
	"watchdog_pursuit": {
		"game_nodes": 371,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
	},
	"watchdog_lunge": {
		"game_nodes": 371,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
	},
	"tongue_deflect": {
		"game_nodes": 371,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
	},
	"crowd_pursuit": {
		"game_nodes": 371,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"active_city_actors": MAX_CITY_ACTORS,
		"active_crowd_members": MAX_CROWD_MEMBERS,
	},
	"roadblock": {
		"game_nodes": 373,
		"collision_objects": 43,
		"collision_shapes": 113,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"roadblocks": MAX_ROADBLOCKS,
	},
	"roadblock_staggered": {
		"game_nodes": 374,
		"collision_objects": 43,
		"collision_shapes": 114,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"roadblocks": MAX_ROADBLOCKS,
	},
	"animal_control_snare": {
		"game_nodes": 372,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"pursuit_traps": MAX_PURSUIT_TRAPS,
	},
	"security_motion_beacon": {
		"game_nodes": 372,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"pursuit_traps": MAX_PURSUIT_TRAPS,
	},
	"watchdog_sticky_patch": {
		"game_nodes": 372,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"pursuit_traps": MAX_PURSUIT_TRAPS,
	},
	"net_attack": {
		"game_nodes": 371,
		"collision_objects": 42,
		"collision_shapes": 112,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"net_projectiles": MAX_NET_PROJECTILES,
	},
	"maximum_growth": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"active_effects": MAX_VISUAL_EFFECTS,
	},
	"presentation_peak": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"active_effects": MAX_VISUAL_EFFECTS,
		"touch_feedback": MAX_TOUCH_FEEDBACK,
	},
	"belly_overlay": {
		"game_nodes": 625,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"belly_items": BELLY_STRESS_ITEMS,
		"belly_rows": BELLY_STRESS_ITEMS,
	},
	"field_guide_overlay": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"guide_rows": FIELD_GUIDE_ROWS,
	},
	"accessibility_options": {
		"game_nodes": 369,
		"collision_objects": 41,
		"collision_shapes": 111,
		"targets": MAX_TARGETS,
		"guide_rows": FIELD_GUIDE_ROWS,
	},
	"gameplay_peak": {
		"game_nodes": 375,
		"collision_objects": 43,
		"collision_shapes": 114,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": MAX_PURSUERS,
		"roadblocks": MAX_ROADBLOCKS,
		"pursuit_traps": MAX_PURSUIT_TRAPS,
		"active_city_actors": MAX_CITY_ACTORS,
		"active_effects": MAX_VISUAL_EFFECTS,
		"touch_feedback": MAX_TOUCH_FEEDBACK,
	},
	"generated_streaming": {
		"game_nodes": 579,
		"collision_objects": 100,
		"collision_shapes": 172,
		"targets": MAX_TARGETS + MAX_GENERATED_TARGETS,
		"buildings": MAX_BUILDINGS + MAX_GENERATED_BUILDINGS,
		"loaded_generated_districts": MAX_LOADED_GENERATED_DISTRICTS,
		"generated_district_records": MAX_LOADED_GENERATED_DISTRICTS,
		"district_state_records": 0,
		"generated_targets": MAX_GENERATED_TARGETS,
		"generated_buildings": MAX_GENERATED_BUILDINGS,
	},
}


static func structural_violations(
	scenario_name: String,
	snapshot: Dictionary
) -> PackedStringArray:
	var violations := PackedStringArray()
	var limits := STRUCTURAL_LIMITS.get(scenario_name, {}) as Dictionary
	if limits.is_empty():
		violations.append("No structural budget exists for %s." % scenario_name)
		return violations
	for metric in limits:
		var actual := int(snapshot.get(metric, 0))
		var maximum := int(limits[metric])
		if actual > maximum:
			violations.append(
				"%s is %d; budget is %d." % [metric, actual, maximum]
			)
	for metric in GLOBAL_STRUCTURAL_LIMITS:
		var actual := int(snapshot.get(metric, 0))
		var maximum := int(GLOBAL_STRUCTURAL_LIMITS[metric])
		if actual > maximum:
			violations.append(
				"%s is %d; budget is %d." % [metric, actual, maximum]
			)
	return violations


static func percentile(values: Array[float], proportion: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var index := clampi(
		ceili(clampf(proportion, 0.0, 1.0) * sorted_values.size()) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]


static func average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())
