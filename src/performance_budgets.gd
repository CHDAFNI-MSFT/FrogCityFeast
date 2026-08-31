class_name PerformanceBudgets
extends RefCounted

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

const MAX_TARGETS := 27
const MAX_BUILDINGS := 4
const MAX_INTERIOR_ROOMS := 1
const MAX_PURSUERS := 1
const MAX_VISUAL_EFFECTS := 24
const MAX_TOUCH_FEEDBACK := 3
const MAX_CROWD_MEMBERS := 5
const MAX_CITY_ACTORS := 20
const MAX_ROADBLOCKS := 1
const MAX_RAIN_STREAKS := 84
const MAX_NET_PROJECTILES := 1
const MAX_AUDIO_NODES := 7
const MAX_AUDIO_PLAYERS := 6
const MAX_AUDIO_EFFECT_VOICES := 4
const FIELD_GUIDE_ROWS := 28
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
		"game_nodes": 249,
		"collision_objects": 32,
		"collision_shapes": 39,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
		"active_effects": 0,
	},
	"stockroom": {
		"game_nodes": 249,
		"collision_objects": 32,
		"collision_shapes": 39,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": 0,
	},
	"busy_daytime": {
		"game_nodes": 249,
		"collision_objects": 32,
		"collision_shapes": 39,
		"targets": MAX_TARGETS,
		"active_city_actors": MAX_CITY_ACTORS,
	},
	"rainy_day": {
		"game_nodes": 249,
		"collision_objects": 32,
		"collision_shapes": 39,
		"targets": MAX_TARGETS,
		"rain_streaks": MAX_RAIN_STREAKS,
	},
	"pursuit": {
		"game_nodes": 251,
		"collision_objects": 33,
		"collision_shapes": 40,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
	},
	"crowd_pursuit": {
		"game_nodes": 251,
		"collision_objects": 33,
		"collision_shapes": 40,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"active_city_actors": MAX_CITY_ACTORS,
		"active_crowd_members": MAX_CROWD_MEMBERS,
	},
	"roadblock": {
		"game_nodes": 253,
		"collision_objects": 34,
		"collision_shapes": 41,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"roadblocks": MAX_ROADBLOCKS,
	},
	"net_attack": {
		"game_nodes": 251,
		"collision_objects": 33,
		"collision_shapes": 40,
		"targets": MAX_TARGETS,
		"pursuers": MAX_PURSUERS,
		"net_projectiles": MAX_NET_PROJECTILES,
	},
	"maximum_growth": {
		"game_nodes": 249,
		"collision_objects": 32,
		"collision_shapes": 39,
		"targets": MAX_TARGETS,
		"active_effects": MAX_VISUAL_EFFECTS,
	},
	"presentation_peak": {
		"game_nodes": 249,
		"collision_objects": 32,
		"collision_shapes": 39,
		"targets": MAX_TARGETS,
		"active_effects": MAX_VISUAL_EFFECTS,
		"touch_feedback": MAX_TOUCH_FEEDBACK,
	},
	"belly_overlay": {
		"game_nodes": 505,
		"collision_objects": 32,
		"collision_shapes": 39,
		"targets": MAX_TARGETS,
		"belly_items": BELLY_STRESS_ITEMS,
		"belly_rows": BELLY_STRESS_ITEMS,
	},
	"field_guide_overlay": {
		"game_nodes": 249,
		"collision_objects": 32,
		"collision_shapes": 39,
		"targets": MAX_TARGETS,
		"guide_rows": FIELD_GUIDE_ROWS,
	},
	"accessibility_options": {
		"game_nodes": 249,
		"collision_objects": 32,
		"collision_shapes": 39,
		"targets": MAX_TARGETS,
		"guide_rows": FIELD_GUIDE_ROWS,
	},
	"gameplay_peak": {
		"game_nodes": 253,
		"collision_objects": 34,
		"collision_shapes": 41,
		"targets": MAX_TARGETS,
		"buildings": MAX_BUILDINGS,
		"pursuers": MAX_PURSUERS,
		"roadblocks": MAX_ROADBLOCKS,
		"active_city_actors": MAX_CITY_ACTORS,
		"active_effects": MAX_VISUAL_EFFECTS,
		"touch_feedback": MAX_TOUCH_FEEDBACK,
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
