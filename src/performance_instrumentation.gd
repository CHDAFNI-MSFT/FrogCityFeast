class_name PerformanceInstrumentation
extends CanvasLayer

const BUDGETS := preload("res://src/performance_budgets.gd")
const SAMPLE_INTERVAL := 0.25
const FRAME_HISTORY_LIMIT := 240
const ENABLE_ARGUMENT := "--perf-overlay"

var _game: Node
var _label: Label
var _sample_time := 0.0
var _frame_history: Array[float] = []


static func requested() -> bool:
	return OS.get_cmdline_user_args().has(ENABLE_ARGUMENT)


static func monitor_snapshot(
	include_rendering: bool = false,
	include_video_memory: bool = false
) -> Dictionary:
	var snapshot := {
		"fps": float(Performance.get_monitor(Performance.TIME_FPS)),
		"process_ms": (
			float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		),
		"physics_ms": (
			float(
				Performance.get_monitor(
					Performance.TIME_PHYSICS_PROCESS
				)
			) * 1000.0
		),
		"static_memory_bytes": int(
			Performance.get_monitor(Performance.MEMORY_STATIC)
		),
		"global_nodes": int(
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		),
		"resources": int(
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		),
		"orphan_nodes": int(
			Performance.get_monitor(
				Performance.OBJECT_ORPHAN_NODE_COUNT
			)
		),
		"physics_active_objects": int(
			Performance.get_monitor(
				Performance.PHYSICS_2D_ACTIVE_OBJECTS
			)
		),
		"physics_collision_pairs": int(
			Performance.get_monitor(
				Performance.PHYSICS_2D_COLLISION_PAIRS
			)
		),
		"physics_islands": int(
			Performance.get_monitor(
				Performance.PHYSICS_2D_ISLAND_COUNT
			)
		),
		"draw_calls": -1,
		"render_objects": -1,
		"render_primitives": -1,
		"video_memory_bytes": -1,
	}
	if (
		include_rendering
		and DisplayServer.get_name().to_lower() != "headless"
	):
		snapshot["draw_calls"] = int(
			Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
			)
		)
		snapshot["render_objects"] = int(
			Performance.get_monitor(
				Performance.RENDER_TOTAL_OBJECTS_IN_FRAME
			)
		)
		snapshot["render_primitives"] = int(
			Performance.get_monitor(
				Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME
			)
		)
		if include_video_memory:
			snapshot["video_memory_bytes"] = int(
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
			)
	return snapshot


func configure(game: Node) -> void:
	_game = game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	_build_overlay()
	_update_overlay()


func _process(delta: float) -> void:
	_frame_history.append(delta * 1000.0)
	if _frame_history.size() > FRAME_HISTORY_LIMIT:
		_frame_history.pop_front()
	_sample_time += delta
	if _sample_time < SAMPLE_INTERVAL:
		return
	_sample_time = 0.0
	_update_overlay()


func _build_overlay() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(842, 92)
	panel.custom_minimum_size = Vector2(426, 344)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.03, 0.035, 0.94)
	panel_style.border_color = Color(0.38, 0.9, 0.72, 0.92)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color("d9fff0"))
	margin.add_child(_label)
	add_child(panel)


func _update_overlay() -> void:
	if not is_instance_valid(_label):
		return
	var monitors := monitor_snapshot(false)
	var structure := {}
	if (
		is_instance_valid(_game)
		and _game.has_method("performance_structure_snapshot")
	):
		structure = _game.call("performance_structure_snapshot")
	var frame_average := BUDGETS.average(_frame_history)
	var frame_p95 := BUDGETS.percentile(_frame_history, 0.95)
	var rendering_text := "render counters: run the rendered measurement harness"
	if int(monitors["draw_calls"]) >= 0:
		rendering_text = "render: %d draws  %d objects  %d primitives" % [
			monitors["draw_calls"],
			monitors["render_objects"],
			monitors["render_primitives"],
		]
	_label.text = "\n".join([
		"PERFORMANCE - DEVELOPER ONLY",
		"fps: %.1f  frame avg/p95: %.2f / %.2f ms" % [
			monitors["fps"],
			frame_average,
			frame_p95,
		],
		"CPU process/physics: %.2f / %.2f ms" % [
			monitors["process_ms"],
			monitors["physics_ms"],
		],
		"memory: %.1f MiB  video: %s" % [
			float(monitors["static_memory_bytes"]) / 1048576.0,
			(
				"%.1f MiB"
				% (float(monitors["video_memory_bytes"]) / 1048576.0)
				if int(monitors["video_memory_bytes"]) >= 0
				else "n/a"
			),
		],
		rendering_text,
		"global: %d nodes  %d resources  %d orphans" % [
			monitors["global_nodes"],
			monitors["resources"],
			monitors["orphan_nodes"],
		],
		"physics: %d active  %d pairs  %d islands" % [
			monitors["physics_active_objects"],
			monitors["physics_collision_pairs"],
			monitors["physics_islands"],
		],
		"game: %d nodes  %d collision objects / %d shapes" % [
			structure.get("game_nodes", 0),
			structure.get("collision_objects", 0),
			structure.get("collision_shapes", 0),
		],
		"canvas: %d items  %d controls" % [
			structure.get("canvas_items", 0),
			structure.get("controls", 0),
		],
		"content: %d targets  %d buildings  %d pursuers" % [
			structure.get("targets", 0),
			structure.get("buildings", 0),
			structure.get("pursuers", 0),
		],
		"activity: %d actors  %d effects  %d touch cues" % [
			structure.get("active_city_actors", 0),
			structure.get("active_effects", 0),
			structure.get("touch_feedback", 0),
		],
		"audio: %d players  %d active effect voices" % [
			structure.get("audio_players", 0),
			structure.get("audio_active_effect_voices", 0),
		],
		"UI data: %d belly items  %d guide rows" % [
			structure.get("belly_items", 0),
			structure.get("guide_rows", 0),
		],
	])
