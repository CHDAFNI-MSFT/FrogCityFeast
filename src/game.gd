class_name FrogGame
extends Node2D

signal score_changed(score: int)
signal end_requested(final_score: int)
signal tutorial_finished(skipped: bool)
signal movement_reached(world_position: Vector2)
signal manual_camera_rotated(radians: float)
signal target_swallowed(target_id: String)
signal target_discovered(target_id: String)
signal item_digested(target_id: String)
signal growth_tier_applied(tier: int)
signal accessibility_changed(
	reduce_motion: bool,
	larger_text_controls: bool
)
signal audio_changed(preferences: Dictionary)

const EDIBLE_SCRIPT := preload("res://src/edible.gd")
const BUILDING_SCRIPT := preload("res://src/building.gd")
const PURSUER_SCRIPT := preload("res://src/pursuer.gd")
const PERFORMANCE_INSTRUMENTATION_SCRIPT := preload(
	"res://src/performance_instrumentation.gd"
)

enum TonguePhase {
	HIDDEN,
	EXTENDING,
	HOLDING,
	RETRACTING,
}

const WORLD_RECT := Rect2(-1760, -1360, 3520, 2720)
const GROWTH_THRESHOLDS := [60, 360]
const TONGUE_RECOVERY := 0.42
const TONGUE_EXTEND_DURATION := 0.09
const TONGUE_HOLD_DURATION := 0.06
const TONGUE_RETRACT_DURATION := 0.12
const TONGUE_COLOR := Color(0.96, 0.42, 0.56, 1.0)
const STRUGGLE_DURATION := 3.1
const DAMAGE_COOLDOWN := 1.4
const NIGHT_AUDIO_THRESHOLD := 0.38
const REWARD_DURATION := 1.15
const HUD_PULSE_DURATION := 0.34
const DISCOVERY_BANNER_DURATION := 2.2
const RESTOCK_POSITIONS := [
	Vector2(-1450, -1080),
	Vector2(-1120, -520),
	Vector2(-1420, 440),
	Vector2(-1420, 1110),
	Vector2(-650, -1040),
	Vector2(-420, 900),
	Vector2(360, -1050),
	Vector2(600, 430),
	Vector2(1050, 470),
	Vector2(1120, -980),
	Vector2(1420, -420),
	Vector2(1420, 1080),
	Vector2(430, 420),
	Vector2(720, 350),
	Vector2(900, -1060),
	Vector2(-1500, 80),
	Vector2(600, 80),
	Vector2(1500, 80),
]
const DESTRUCTIBLE_BUILDING_TARGETS := {
	"moonlight_market": {
		"parts": [
			{
				"part_id": "sign",
				"id": "moonlight_market_sign",
				"name": "Market Sign",
				"value": 32,
				"radius": 32.0,
				"color": Color("f0cb67"),
			},
			{
				"part_id": "door",
				"id": "moonlight_market_door",
				"name": "Market Door",
				"value": 62,
				"tier": 1,
				"radius": 34.0,
				"resistant": true,
				"taps": 6,
				"color": Color("704730"),
			},
			{
				"part_id": "counter",
				"id": "moonlight_market_counter",
				"name": "Market Counter",
				"value": 88,
				"tier": 1,
				"radius": 40.0,
				"resistant": true,
				"taps": 8,
				"color": Color("9a7447"),
			},
		],
		"whole": {
			"id": "moonlight_market_building",
			"name": "Moonlight Market",
			"value": 460,
			"radius": 155.0,
			"taps": 18,
			"color": Color("d6a65f"),
		},
	},
	"oddities_shop": {
		"parts": [
			{
				"part_id": "door",
				"id": "oddities_shop_door",
				"name": "Shop Shutter",
				"value": 44,
				"radius": 34.0,
				"color": Color("6b4f86"),
			},
			{
				"part_id": "counter",
				"id": "oddities_shop_counter",
				"name": "Curio Shelf",
				"value": 96,
				"tier": 1,
				"radius": 40.0,
				"resistant": true,
				"taps": 9,
				"color": Color("8a6ba8"),
			},
			{
				"part_id": "sign",
				"id": "oddities_shop_sign",
				"name": "Shop Banner",
				"value": 52,
				"tier": 1,
				"radius": 32.0,
				"color": Color("c58fd8"),
			},
		],
		"whole": {
			"id": "oddities_shop_building",
			"name": "Oddities Shop",
			"value": 420,
			"radius": 150.0,
			"taps": 14,
			"color": Color("a78bc4"),
		},
	},
}

@onready var _world: Node2D = $World
@onready var _city: CityBackdrop = $World/City
@onready var _city_activity: CityActivity = $World/CityActivity
@onready var _frog: PlayerFrog = $World/Frog
@onready var _camera: Camera2D = $World/Camera
@onready var _tongue: Line2D = $World/Tongue
@onready var _effects: FeelEffects = $World/Effects
@onready var _world_tint: CanvasModulate = $World/WorldTint
@onready var _top_background: ColorRect = $HUD/Root/TopBackground
@onready var _top_margin: MarginContainer = %TopMargin
@onready var _profile_label: Label = %ProfileLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _growth_label: Label = %GrowthLabel
@onready var _power_label: Label = %PowerLabel
@onready var _guide_button: Button = %GuideButton
@onready var _belly_button: Button = %BellyButton
@onready var _options_button: Button = %OptionsButton
@onready var _end_button: Button = %EndButton
@onready var _status_panel: PanelContainer = $HUD/Root/StatusPanel
@onready var _status_label: Label = %StatusLabel
@onready var _control_legend: PanelContainer = $HUD/Root/ControlLegendBackground
@onready var _instructions_label: Label = %Instructions
@onready var _touch_feedback: TouchFeedback = %TouchFeedback
@onready var _challenge_panel: PanelContainer = %ChallengePanel
@onready var _challenge_sharp_aim: Label = %ChallengeSharpAim
@onready var _challenge_hold_on: Label = %ChallengeHoldOn
@onready var _challenge_city_tour: Label = %ChallengeCityTour
@onready var _challenge_summary: Label = %ChallengeSummary
@onready var _struggle_panel: PanelContainer = %StrugglePanel
@onready var _struggle_progress: ProgressBar = %Progress
@onready var _belly_overlay: Control = %BellyOverlay
@onready var _belly_center: CenterContainer = $HUD/Root/BellyOverlay/Center
@onready var _belly_list: VBoxContainer = %BellyList
@onready var _digest_all_button: Button = %DigestAllButton
@onready var _end_game_belly_button: Button = %EndGameBellyButton
@onready var _close_belly_button: Button = %CloseBellyButton
@onready var _tutorial_marker: TutorialMarker = $World/TutorialMarker
@onready var _tutorial_panel: PanelContainer = %TutorialPanel
@onready var _tutorial_progress: Label = %TutorialProgress
@onready var _tutorial_title: Label = %TutorialTitle
@onready var _tutorial_instruction: Label = %TutorialInstruction
@onready var _skip_tutorial_button: Button = %SkipTutorialButton
@onready var _reward_label: Label = %RewardLabel
@onready var _guide_overlay: Control = %GuideOverlay
@onready var _guide_progress: Label = %GuideProgress
@onready var _guide_list: VBoxContainer = %GuideList
@onready var _end_game_guide_button: Button = %EndGameGuideButton
@onready var _close_guide_button: Button = %CloseGuideButton
@onready var _options_overlay: Control = %OptionsOverlay
@onready var _options_center: CenterContainer = $HUD/Root/OptionsOverlay/Center
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _larger_ui_toggle: CheckButton = %LargerUiToggle
@onready var _master_volume_label: Label = %MasterVolumeLabel
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _music_volume_label: Label = %MusicVolumeLabel
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _effects_volume_label: Label = %EffectsVolumeLabel
@onready var _effects_volume_slider: HSlider = %EffectsVolumeSlider
@onready var _end_game_options_button: Button = %EndGameOptionsButton
@onready var _close_options_button: Button = %CloseOptionsButton
@onready var _discovery_banner: PanelContainer = %DiscoveryBanner
@onready var _discovery_banner_label: Label = %DiscoveryBannerLabel

var _profile_id := ""
var _display_name := "Player"
var _configured := false
var _tutorial_required := false
var _score := 0
var _growth_points := 0
var _growth_tier := 0
var _belly: Array[BellyItem] = []
var _targets: Array[EdibleTarget] = []
var _buildings: Array[PrototypeBuilding] = []
var _building_by_id: Dictionary = {}
var _pursuer: PrototypePursuer

var _tongue_recovery := 0.0
var _tongue_phase := TonguePhase.HIDDEN
var _tongue_phase_time := 0.0
var _tongue_extension := 0.0
var _tongue_retract_start := 0.0
var _tongue_end := Vector2.ZERO
var _struggle_kick := 0.0
var _damage_cooldown := 0.0
var _status_time := 0.0
var _flight_time_left := 0.0
var _day_clock := 0.23
var _current_daylight := 0.0
var _last_safe_ground_position := Vector2.ZERO
var _rare_respawn_pending: Dictionary = {}
var _pending_growth_tier := -1

var _struggle_target: EdibleTarget
var _struggle_accuracy := 0.0
var _struggle_taps := 0
var _struggle_time_left := 0.0
var _struggle_hit_offset := Vector2.ZERO

var _pull_target: EdibleTarget
var _pull_time_left := 0.0
var _pull_hit_offset := Vector2.ZERO

var _active_touches: Dictionary = {}
var _camera_gesture := false
var _camera_driver_id := -1
var _mouse_rotating := false
var _ignore_mouse_until_msec := 0
var _tutorial: TutorialController
var _tutorial_original_target_states: Dictionary = {}
var _discoveries: Dictionary = {}
var _challenges := SessionChallenges.new()
var _motion_scale := 1.0
var _motion_scale_configured := false
var _camera_shake_amplitude := 0.0
var _camera_shake_duration := 0.0
var _camera_shake_time := 0.0
var _score_pulse_time := 0.0
var _growth_pulse_time := 0.0
var _reward_time := 0.0
var _pending_hud_pulse := false
var _discovery_banner_time := 0.0
var _challenge_pulse_times: Dictionary = {}
var _reduce_motion_enabled := false
var _larger_text_controls_enabled := false
var _accessibility_configured := false
var _refreshing_accessibility_controls := false
var _audio_preferences := AudioPreferences.defaults()
var _refreshing_audio_controls := false
var _audio_dragging := false
var _tutorial_panel_was_visible_before_options := false
var _performance_instrumentation: CanvasLayer


func _ready() -> void:
	if not _configured:
		push_error("FrogGame must be configured before it enters the scene tree.")
		return
	_belly_button.pressed.connect(_open_belly)
	_guide_button.pressed.connect(_open_guide)
	_options_button.pressed.connect(_open_options)
	_end_button.pressed.connect(_end_game)
	_digest_all_button.pressed.connect(_digest_all)
	_end_game_belly_button.pressed.connect(_end_game)
	_close_belly_button.pressed.connect(_close_belly)
	_end_game_guide_button.pressed.connect(_end_game)
	_close_guide_button.pressed.connect(_close_guide)
	_reduce_motion_toggle.toggled.connect(_on_accessibility_toggled)
	_larger_ui_toggle.toggled.connect(_on_accessibility_toggled)
	for slider in _audio_sliders():
		slider.value_changed.connect(_on_audio_value_changed)
		slider.drag_started.connect(_on_audio_drag_started)
		slider.drag_ended.connect(_on_audio_drag_ended)
	_end_game_options_button.pressed.connect(_end_game)
	_close_options_button.pressed.connect(_close_options)
	_skip_tutorial_button.pressed.connect(_skip_tutorial)
	_frog.move_reached.connect(_on_frog_move_reached)
	_challenges.challenge_completed.connect(_on_challenge_completed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_build_prototype_city()
	_update_day_night(0.0)
	if not _accessibility_configured:
		_reduce_motion_enabled = (
			DisplayServer.get_name().to_lower() == "headless"
			or bool(
				ProjectSettings.get_setting(
					"frog_city/reduced_motion",
					false
				)
			)
		)
	if not _motion_scale_configured:
		_motion_scale = 0.0 if _reduce_motion_enabled else 1.0
	_apply_motion_scale(_motion_scale)
	_apply_accessibility_presentation()
	_apply_safe_area()
	_update_accessibility_controls()
	_update_audio_controls()
	_last_safe_ground_position = _frog.global_position
	_profile_label.text = _display_name
	_rebuild_guide()
	if _tutorial_required:
		_challenge_panel.visible = false
		_start_tutorial()
	else:
		_tutorial_panel.visible = false
		_tutorial_marker.active = false
		_begin_session_challenges()
	_update_hud()
	_enable_requested_performance_instrumentation()


func _exit_tree() -> void:
	AudioDirector.leave_context(self)


func configure(
	profile_id: String,
	display_name: String,
	tutorial_required: bool,
	discovered_ids: PackedStringArray = PackedStringArray(),
	accessibility_preferences: Dictionary = {},
	audio_preferences: Dictionary = {}
) -> void:
	_profile_id = profile_id
	_display_name = display_name
	_tutorial_required = tutorial_required
	_discoveries.clear()
	for target_id in discovered_ids:
		var normalized_id := str(target_id).strip_edges()
		if (
			not normalized_id.is_empty()
			and not DiscoveryCatalog.entry_for(normalized_id).is_empty()
		):
			_discoveries[normalized_id] = true
	if not accessibility_preferences.is_empty():
		var sanitized := AccessibilityPresentation.sanitize_preferences(
			accessibility_preferences
		)
		_reduce_motion_enabled = bool(sanitized["reduce_motion"])
		_larger_text_controls_enabled = bool(
			sanitized["larger_text_controls"]
		)
		_accessibility_configured = true
	if not audio_preferences.is_empty():
		_audio_preferences = AudioPreferences.sanitize_preferences(
			audio_preferences
		)
	_configured = true


func activate_audio_context() -> void:
	AudioDirector.enter_game(
		self,
		_audio_preferences,
		_current_daylight < NIGHT_AUDIO_THRESHOLD
	)


func _process(delta: float) -> void:
	_update_hud_feedback(delta)

	if _status_time > 0.0:
		_status_time -= delta
		if _status_time <= 0.0:
			_status_label.text = "Tap the ground to move. Double-tap a target to eat it."

	if get_tree().paused:
		_update_camera()
		_camera.offset = Vector2.ZERO
		return

	_tongue_recovery = maxf(0.0, _tongue_recovery - delta)
	_damage_cooldown = maxf(0.0, _damage_cooldown - delta)
	_update_flight(delta)
	_update_day_night(delta)
	_retry_pending_growth()

	if is_instance_valid(_struggle_target):
		_struggle_time_left -= delta
		if _struggle_time_left <= 0.0:
			_fail_struggle()

	if is_instance_valid(_pull_target):
		_pull_time_left -= delta
		var pull_end := _pull_target.global_position + _pull_hit_offset
		var obstruction := _first_tongue_obstruction(pull_end)
		if (
			_pull_time_left <= 0.0
			or _frog.global_position.distance_to(pull_end) <= 72.0
			or not obstruction.is_empty()
		):
			_cancel_pull()
		else:
			_frog.move_to(pull_end)

	_update_camera()
	_update_camera_feedback(delta)
	_update_tongue_visual(delta)
	_update_target_presentation()
	_check_vehicle_hazards()
	_frog.global_position = _clamp_circle_to_world(
		_frog.global_position,
		_frog.collision_radius()
	)
	if (
		not _frog.is_flying
		and _circle_position_clear(
			_frog.global_position,
			_frog.collision_radius(),
			true
		)
	):
		_last_safe_ground_position = _frog.global_position


func _unhandled_input(event: InputEvent) -> void:
	if _overlay_blocking():
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_rotating:
		_rotate_camera(event.relative.x, event.position)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_ignore_mouse_until_msec = Time.get_ticks_msec() + 180
		if _touch_over_hud_action(event.position):
			_active_touches[event.index] = {"blocked": true}
			return
		if is_instance_valid(_struggle_target):
			_register_struggle_tap()
			_active_touches[event.index] = {"blocked": true}
			return

		_active_touches[event.index] = {
			"position": event.position,
			"blocked": false,
		}
		if _active_touches.size() >= 2:
			_camera_gesture = true
			_camera_driver_id = event.index
			for touch_id in _active_touches:
				_active_touches[touch_id]["blocked"] = true
		elif event.double_tap:
			_active_touches[event.index]["blocked"] = true
			_try_tongue_at_screen(event.position)
		return

	var touch_data: Dictionary = _active_touches.get(event.index, {})
	if not touch_data.is_empty() and not bool(touch_data.get("blocked", true)) and not event.canceled:
		_handle_world_tap(event.position)
	_active_touches.erase(event.index)
	if _active_touches.size() < 2:
		_camera_gesture = false
		_camera_driver_id = -1


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if _active_touches.has(event.index):
		_active_touches[event.index]["position"] = event.position
	if _camera_gesture and event.index == _camera_driver_id:
		_rotate_camera(event.screen_relative.x, event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if Time.get_ticks_msec() < _ignore_mouse_until_msec:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_rotating = event.pressed
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	if is_instance_valid(_struggle_target):
		_register_struggle_tap()
	elif event.double_click:
		_try_tongue_at_screen(event.position)
	else:
		_handle_world_tap(event.position)


func _handle_world_tap(screen_position: Vector2) -> void:
	if is_instance_valid(_pull_target):
		_show_status("The tongue is pulling the frog right now.")
		return
	var world_position := _screen_to_world(screen_position)
	if _find_target_at(world_position) != null:
		_show_status("Double-tap that target to shoot your tongue.")
		return
	if (
		_tutorial != null
		and _tutorial.active
		and not _tutorial.allows_world_move(world_position)
	):
		_show_status(_tutorial.current_instruction())
		return
	var movement_destination := world_position
	if (
		_tutorial != null
		and _tutorial.active
		and _tutorial.step == TutorialController.Step.MOVE
	):
		movement_destination = _tutorial.marker_position
	var final_destination := _clamp_circle_to_world(
		movement_destination,
		_frog.collision_radius()
	)
	_frog.move_to(final_destination)
	_touch_feedback.show_move(final_destination)


func _try_tongue_at_screen(screen_position: Vector2) -> void:
	_touch_feedback.show_tongue(screen_position)
	if is_instance_valid(_pull_target):
		_show_status("Finish being pulled before shooting again.")
		return
	if _tongue_recovery > 0.0:
		_show_status("Your tongue needs a moment to recover.")
		return

	var world_position := _screen_to_world(screen_position)
	var pursuer_hit := (
		_pursuer
		if is_instance_valid(_pursuer) and _pursuer.hit_test(world_position)
		else null
	)
	var target := _find_target_at(world_position)
	if _tutorial != null and _tutorial.active:
		var attempted_target_id := target.target_id if target != null else ""
		if pursuer_hit != null or not _tutorial.allows_tongue_target(attempted_target_id):
			_show_status(_tutorial.current_instruction())
			return
	var entry_building := _building_requiring_entry(target)
	if entry_building != null:
		_show_status(
			"Enter %s before reaching for %s."
			% [entry_building.display_name, target.display_name]
		)
		return
	AudioDirector.play_effect(FrogAudioDirector.TONGUE_LAUNCH)
	var shot_offset := world_position - _frog.global_position
	if shot_offset.length() > _frog.tongue_range():
		var limited_end := (
			_frog.global_position
			+ shot_offset.normalized() * _frog.tongue_range()
		)
		var range_obstruction := _first_tongue_obstruction(limited_end)
		_show_tongue(
			range_obstruction.get("position", limited_end) as Vector2
			if not range_obstruction.is_empty()
			else limited_end
		)
		_tongue_recovery = TONGUE_RECOVERY
		AudioDirector.play_effect(FrogAudioDirector.TONGUE_MISS)
		_show_status("That spot is out of tongue range.")
		return

	var obstruction := _first_tongue_obstruction(
		world_position,
		pursuer_hit != null,
		target
	)
	if not obstruction.is_empty():
		_show_tongue(obstruction["position"] as Vector2)
		_tongue_recovery = TONGUE_RECOVERY
		AudioDirector.play_effect(FrogAudioDirector.TONGUE_MISS)
		_show_status("The tongue bounced off a wall.")
		return

	if pursuer_hit != null:
		AudioDirector.play_effect(FrogAudioDirector.TONGUE_HIT)
		if _growth_tier < 2:
			_show_tongue(world_position)
			_tongue_recovery = TONGUE_RECOVERY
			_show_status("Animal Control is too big to eat yet!")
		else:
			_show_tongue(world_position)
			_swallow_pursuer(pursuer_hit, pursuer_hit.hit_accuracy(world_position))
		return

	if target == null:
		_show_tongue(world_position)
		_tongue_recovery = TONGUE_RECOVERY
		AudioDirector.play_effect(FrogAudioDirector.TONGUE_MISS)
		_show_status("Miss! Aim directly at something you can eat.")
		return

	AudioDirector.play_effect(FrogAudioDirector.TONGUE_HIT)
	if target.kind == "building":
		var building := _building_by_id.get(target.building_id) as PrototypeBuilding
		if is_instance_valid(building) and (
			not building.is_ready_to_swallow() or _growth_tier < 2
		):
			_start_pull(target, world_position - target.global_position)
			if not building.is_ready_to_swallow():
				_show_status(
					"Remove %d more parts from %s before swallowing it."
					% [
						building.remaining_weakness(),
						building.display_name,
					]
				)
			else:
				_show_status(
					"%s is weak, but the frog must reach maximum growth."
					% building.display_name
				)
			return

	if not target.can_be_swallowed(_growth_tier):
		_start_pull(target, world_position - target.global_position)
		_show_status("%s is too big and pulls the frog forward!" % target.display_name)
		return

	var accuracy := target.hit_accuracy(world_position)
	_show_tongue(world_position)
	if target.resistant:
		_begin_struggle(target, accuracy, world_position - target.global_position)
	else:
		_swallow_target(target, accuracy)


func _begin_struggle(target: EdibleTarget, accuracy: float, hit_offset: Vector2) -> void:
	_struggle_target = target
	_struggle_target.set_latched(true)
	_struggle_target.pulse_feedback(_motion_scale)
	_struggle_accuracy = accuracy
	_struggle_hit_offset = hit_offset
	_struggle_taps = 0
	_struggle_time_left = STRUGGLE_DURATION
	_struggle_progress.max_value = target.taps_required
	_struggle_progress.value = 0
	_struggle_panel.visible = true
	_frog.movement_enabled = false
	if _tongue_phase == TonguePhase.HIDDEN:
		_show_tongue(target.global_position + hit_offset)
	_show_status("%s is fighting back!" % target.display_name)


func _register_struggle_tap() -> void:
	if not is_instance_valid(_struggle_target):
		return
	AudioDirector.play_effect(FrogAudioDirector.STRUGGLE_TAP)
	_struggle_taps += 1
	_struggle_kick = 1.0
	_struggle_target.pulse_feedback(_motion_scale)
	_struggle_progress.value = _struggle_taps
	if _struggle_taps >= _struggle_target.taps_required:
		var captured_target := _struggle_target
		var captured_accuracy := _struggle_accuracy
		_challenges.record_struggle_win()
		_update_challenge_hud()
		_clear_struggle()
		_swallow_target(captured_target, captured_accuracy)


func _fail_struggle() -> void:
	var escaped_target := _struggle_target
	_clear_struggle()
	if (
		_tutorial != null
		and _tutorial.suppresses_struggle_failure(escaped_target.target_id)
	):
		_reset_tutorial_target_after_failed_struggle(escaped_target)
		_tongue_recovery = TONGUE_RECOVERY
		_show_status("Almost! Try the highlighted target again and tap faster.")
		return
	var building_repelled := _reset_building_target_position(escaped_target)
	var fixture_reinstalled := false
	if not building_repelled:
		fixture_reinstalled = _reset_building_part_position(escaped_target)
	var interior_building: PrototypeBuilding
	if not building_repelled and not fixture_reinstalled:
		interior_building = _reset_interior_target_after_failed_struggle(
			escaped_target
		)
	if (
		not building_repelled
		and not fixture_reinstalled
		and interior_building == null
	):
		escaped_target.flee_from(_frog.global_position)
	_tongue_recovery = TONGUE_RECOVERY * 1.5
	if building_repelled:
		_show_status(
			"%s shook the frog off and called Animal Control!"
			% escaped_target.display_name
		)
	elif interior_building != null:
		_show_status(
			"%s hid inside %s and called Animal Control!"
			% [escaped_target.display_name, interior_building.display_name]
		)
	else:
		_show_status(
			"%s escaped and called Animal Control!"
			% escaped_target.display_name
		)
	_spawn_pursuer()


func _clear_struggle() -> void:
	if is_instance_valid(_struggle_target):
		_tongue_end = (
			_struggle_target.global_position + _struggle_hit_offset
		)
		_struggle_target.set_latched(false)
	_struggle_target = null
	_struggle_panel.visible = false
	_frog.movement_enabled = true
	_start_tongue_retract()


func _swallow_target(target: EdibleTarget, accuracy: float) -> void:
	var effect_position := target.global_position
	var effect_color := target.target_color
	var swallowed_building := target.kind == "building"
	var chased := _is_actively_chased()
	var item := target.make_belly_item(accuracy, target.dangerous_location, chased)
	_normalize_tutorial_belly_item(item)
	_record_discovery(item.target_id, item.display_name)
	_challenges.record_swallow(item.target_id, item.accuracy)
	_update_challenge_hud()
	var building := _building_by_id.get(target.building_id) as PrototypeBuilding
	var building_was_weakened := false
	if is_instance_valid(building):
		if not target.building_part_id.is_empty():
			building_was_weakened = building.remove_part(target.building_part_id)
			if building.is_ready_to_swallow():
				_activate_building_target(building.building_id)
		elif target.kind == "building":
			building.consume()
	_belly.append(item)
	_targets.erase(target)
	target.queue_free()
	AudioDirector.play_effect(FrogAudioDirector.SWALLOW)
	_effects.emit_swallow(effect_position, effect_color, swallowed_building)
	if swallowed_building:
		_trigger_camera_shake(6.0, 0.22)
	_tongue_recovery = TONGUE_RECOVERY
	if swallowed_building:
		_show_status("The whole %s is now inside the frog!" % item.display_name)
	elif building_was_weakened:
		_show_status(
			"Swallowed %s! %s is weakened to %d/%d."
			% [
				item.display_name,
				building.display_name,
				building.weakness_count(),
				PrototypeBuilding.REQUIRED_WEAKNESS,
			]
		)
	else:
		_show_status(
			"Swallowed %s! Open the belly to digest it. Accuracy: %d%%"
			% [item.display_name, roundi(item.accuracy * 100.0)]
		)
	_update_hud()
	target_swallowed.emit(item.target_id)


func _open_belly() -> void:
	if is_instance_valid(_struggle_target):
		_show_status("Finish the struggle before opening the belly.")
		return
	if is_instance_valid(_pull_target):
		_show_status("Finish being pulled before opening the belly.")
		return
	if _guide_overlay.visible or _options_overlay.visible:
		return
	if (
		_tutorial != null
		and _tutorial.active
		and not _tutorial.allows_belly_open()
	):
		_show_status(_tutorial.current_instruction())
		return
	_rebuild_belly_list()
	_reset_touch_input_state()
	_clear_camera_shake()
	_hide_discovery_banner()
	_belly_center.offset_bottom = (
		-220.0
		if _tutorial != null and _tutorial.active
		else 0.0
	)
	_belly_overlay.visible = true
	_sync_overlay_pause()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _close_belly() -> void:
	_belly_overlay.visible = false
	_belly_center.offset_bottom = 0.0
	_reset_touch_input_state()
	_sync_overlay_pause()
	if _pending_hud_pulse:
		_start_hud_pulse()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _open_guide() -> void:
	if _tutorial != null and _tutorial.active:
		_show_status("Finish or skip the tutorial before opening the Field Guide.")
		return
	if is_instance_valid(_struggle_target):
		_show_status("Finish the struggle before opening the Field Guide.")
		return
	if is_instance_valid(_pull_target):
		_show_status("Finish being pulled before opening the Field Guide.")
		return
	if _belly_overlay.visible or _options_overlay.visible:
		return
	_rebuild_guide()
	_reset_touch_input_state()
	_clear_camera_shake()
	_hide_discovery_banner()
	_guide_overlay.visible = true
	_sync_overlay_pause()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _close_guide() -> void:
	_guide_overlay.visible = false
	_reset_touch_input_state()
	_sync_overlay_pause()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _open_options() -> void:
	if _belly_overlay.visible or _guide_overlay.visible:
		return
	_update_accessibility_controls()
	_reset_touch_input_state()
	_clear_camera_shake()
	_hide_discovery_banner()
	_tutorial_panel_was_visible_before_options = _tutorial_panel.visible
	_tutorial_panel.visible = false
	_options_overlay.visible = true
	_sync_overlay_pause()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _close_options() -> void:
	_options_overlay.visible = false
	if (
		_tutorial_panel_was_visible_before_options
		and _tutorial != null
		and _tutorial.active
	):
		_tutorial_panel.visible = true
	_tutorial_panel_was_visible_before_options = false
	_reset_touch_input_state()
	_sync_overlay_pause()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _overlay_blocking() -> bool:
	return (
		_belly_overlay.visible
		or _guide_overlay.visible
		or _options_overlay.visible
	)


func _sync_overlay_pause() -> void:
	get_tree().paused = _overlay_blocking()


func _reset_touch_input_state() -> void:
	_active_touches.clear()
	_camera_gesture = false
	_camera_driver_id = -1
	_mouse_rotating = false


func _clear_camera_shake() -> void:
	_camera_shake_amplitude = 0.0
	_camera_shake_duration = 0.0
	_camera_shake_time = 0.0
	_camera.offset = Vector2.ZERO


func _hide_discovery_banner() -> void:
	_discovery_banner.visible = false
	_discovery_banner.modulate = Color.WHITE
	_discovery_banner_time = 0.0


func _rebuild_guide() -> void:
	for child in _guide_list.get_children():
		_guide_list.remove_child(child)
		child.queue_free()

	var discovered_count := _known_discovery_count()
	_guide_progress.text = "Discovered %d / %d" % [
		discovered_count,
		DiscoveryCatalog.count(),
	]
	for entry in DiscoveryCatalog.entries():
		var target_id := str(entry["id"])
		var discovered := _discoveries.has(target_id)
		var row := Label.new()
		row.custom_minimum_size = Vector2(0, 46)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 19)
		row.add_theme_color_override(
			"font_color",
			Color(0.62, 1.0, 0.68)
			if discovered
			else Color(0.76, 0.8, 0.82)
		)
		row.text = (
			"FOUND: %s - %s" % [entry["name"], entry["hint"]]
			if discovered
			else "UNKNOWN - Hint: %s" % entry["hint"]
		)
		_guide_list.add_child(row)
		AccessibilityPresentation.apply(
			row,
			_larger_text_controls_enabled
		)


func _known_discovery_count() -> int:
	var total := 0
	for target_id in DiscoveryCatalog.ids():
		if _discoveries.has(target_id):
			total += 1
	return total


func _begin_session_challenges() -> void:
	_challenges.begin()
	_challenge_pulse_times.clear()
	_challenge_panel.visible = true
	_update_challenge_hud()


func _update_challenge_hud() -> void:
	if not _challenges.active:
		_challenge_panel.visible = false
		return
	_challenge_panel.visible = true
	_update_challenge_row(
		_challenge_sharp_aim,
		SessionChallenges.SHARP_AIM
	)
	_update_challenge_row(
		_challenge_hold_on,
		SessionChallenges.HOLD_ON
	)
	_update_challenge_row(
		_challenge_city_tour,
		SessionChallenges.CITY_TOUR
	)
	_challenge_summary.visible = (
		_challenges.completed_count()
		== SessionChallenges.DEFINITIONS.size()
	)


func _update_challenge_row(label: Label, challenge_id: String) -> void:
	var definition := SessionChallenges.definition_for(challenge_id)
	var completed := _challenges.is_complete(challenge_id)
	label.text = "%s %s: %d / %d" % [
		"[DONE]" if completed else "[ ]",
		definition["label"],
		_challenges.progress(challenge_id),
		definition["goal"],
	]
	label.add_theme_color_override(
		"font_color",
		Color(0.55, 1.0, 0.58) if completed else Color(0.92, 0.96, 0.92)
	)


func _on_challenge_completed(_challenge_id: String) -> void:
	_challenge_pulse_times[_challenge_id] = HUD_PULSE_DURATION
	_update_challenge_hud()
	AudioDirector.play_effect(FrogAudioDirector.CHALLENGE_COMPLETE)


func _record_discovery(
	target_id: String,
	fallback_name: String = ""
) -> void:
	if target_id.is_empty() or _discoveries.has(target_id):
		return
	var entry := DiscoveryCatalog.entry_for(target_id)
	if entry.is_empty():
		return
	_discoveries[target_id] = true
	AudioDirector.play_effect(FrogAudioDirector.DISCOVERY)
	_rebuild_guide()
	_update_hud()
	target_discovered.emit(target_id)
	if _tutorial != null and _tutorial.active:
		return
	var display_name := str(entry.get("name", fallback_name))
	var discovered_count := _known_discovery_count()
	_discovery_banner_label.text = (
		"%s completes the Field Guide! (%d / %d)" % [
			display_name,
			discovered_count,
			DiscoveryCatalog.count(),
		]
		if discovered_count == DiscoveryCatalog.count()
		else "New Field Guide entry: %s (%d / %d)" % [
			display_name,
			discovered_count,
			DiscoveryCatalog.count(),
		]
	)
	_discovery_banner.visible = true
	_discovery_banner.modulate = Color.WHITE
	_discovery_banner_time = DISCOVERY_BANNER_DURATION


func _rebuild_belly_list() -> void:
	for child in _belly_list.get_children():
		child.queue_free()

	if _belly.is_empty():
		var empty_label := Label.new()
		empty_label.text = "The belly is empty. Go find something!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 22)
		_belly_list.add_child(empty_label)
		AccessibilityPresentation.apply(
			empty_label,
			_larger_text_controls_enabled
		)
		_digest_all_button.disabled = true
		return

	_digest_all_button.disabled = _tutorial != null and _tutorial.active
	for index in _belly.size():
		var item := _belly[index]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 56

		var label := Label.new()
		label.text = "%s  •  worth %d" % [item.display_name, item.score_value()]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 20)
		row.add_child(label)

		var digest_button := Button.new()
		digest_button.text = "Digest"
		digest_button.custom_minimum_size = Vector2(110, 48)
		digest_button.pressed.connect(_digest_item.bind(index))
		digest_button.disabled = (
			_tutorial != null
			and _tutorial.active
			and not _tutorial.allows_digest(item.target_id)
		)
		row.add_child(digest_button)

		var spit_button := Button.new()
		spit_button.text = "Spit Out"
		spit_button.custom_minimum_size = Vector2(110, 48)
		spit_button.pressed.connect(_spit_item.bind(index))
		spit_button.disabled = _tutorial != null and not _tutorial.allows_spit()
		row.add_child(spit_button)

		_belly_list.add_child(row)
		AccessibilityPresentation.apply(
			row,
			_larger_text_controls_enabled
		)


func _digest_item(index: int) -> void:
	if index < 0 or index >= _belly.size():
		return
	_disable_belly_actions()
	var item := _belly[index]
	if (
		_tutorial != null
		and _tutorial.active
		and not _tutorial.allows_digest(item.target_id)
	):
		_show_status(_tutorial.current_instruction())
		_rebuild_belly_list()
		return
	var tutorial_digest := (
		_tutorial != null
		and _tutorial.active
		and _tutorial.allows_digest(item.target_id)
	)
	_belly.remove_at(index)
	AudioDirector.play_effect(FrogAudioDirector.DIGEST)
	var points := item.score_value()
	_score += points
	var growth_gain := maxi(1, item.base_value + (60 if item.rare else 0))
	_growth_points += growth_gain
	_apply_digest_effects(item)
	item_digested.emit(item.target_id)
	_apply_growth_thresholds()
	score_changed.emit(_score)
	_show_status("Digested %s for %d points!" % [item.display_name, points])
	_update_hud()
	_show_digest_reward(points, growth_gain)
	_rebuild_belly_list()
	if tutorial_digest:
		call_deferred("_close_belly_after_tutorial_digest")


func _digest_all() -> void:
	if _tutorial != null and _tutorial.active:
		_show_status(_tutorial.current_instruction())
		_rebuild_belly_list()
		return
	_disable_belly_actions()
	var had_items := not _belly.is_empty()
	var total_points := 0
	var total_growth := 0
	while not _belly.is_empty():
		var item: BellyItem = _belly.pop_back()
		var points := item.score_value()
		var growth_gain := maxi(1, item.base_value + (60 if item.rare else 0))
		total_points += points
		total_growth += growth_gain
		_score += points
		_growth_points += growth_gain
		_apply_digest_effects(item)
	_apply_growth_thresholds()
	score_changed.emit(_score)
	_show_status("Everything was digested. The frog feels bigger!")
	_update_hud()
	if total_points > 0:
		_show_digest_reward(total_points, total_growth)
	if had_items:
		AudioDirector.play_effect(FrogAudioDirector.DIGEST)
	_rebuild_belly_list()


func _spit_item(index: int) -> void:
	if index < 0 or index >= _belly.size():
		return
	if _tutorial != null and _tutorial.active and not _tutorial.allows_spit():
		_show_status("Tutorial items need to be digested so the lesson can continue.")
		_rebuild_belly_list()
		return
	_disable_belly_actions()
	var item := _belly[index]
	if item.kind == "building":
		if not _restore_building_from_belly(item):
			_show_status(
				"Clear the %s footprint before restoring it."
				% item.display_name
			)
			_rebuild_belly_list()
			return
		_belly.remove_at(index)
		AudioDirector.play_effect(FrogAudioDirector.SPIT)
		_show_status(
			"%s was restored with its removed parts still missing."
			% item.display_name
		)
		_update_hud()
		_rebuild_belly_list()
		return

	var spawn_position := _find_safe_spit_position(item.pick_radius)
	if spawn_position == Vector2.INF:
		_show_status("There is no safe space nearby to return that yet.")
		_rebuild_belly_list()
		return
	_belly.remove_at(index)
	var target := EDIBLE_SCRIPT.new() as EdibleTarget
	target.configure_from_belly(item)
	if target.kind == "building_part":
		target.building_id = ""
		target.building_part_id = ""
	target.position = spawn_position
	target.dangerous_location = false
	if target.velocity != Vector2.ZERO and not target.is_vehicle:
		target.move_bounds = Rect2(
			spawn_position - Vector2(360, 260),
			Vector2(720, 520)
		).intersection(WORLD_RECT.grow(-80))
	_world.add_child(target)
	_targets.append(target)
	AudioDirector.play_effect(FrogAudioDirector.SPIT)
	_show_status("%s was returned safely." % item.display_name)
	_update_hud()
	_rebuild_belly_list()


func _apply_growth_thresholds() -> void:
	var next_tier := 0
	for threshold in GROWTH_THRESHOLDS:
		if _growth_points >= threshold:
			next_tier += 1
	if next_tier == _growth_tier:
		_pending_growth_tier = -1
		return
	if not _frog.is_flying:
		var safe_position := _find_safe_frog_position(_frog.radius_for_tier(next_tier))
		if safe_position == Vector2.INF:
			_pending_growth_tier = next_tier
			_show_status("Move into an open area so the frog has room to grow.")
			return
		_frog.global_position = safe_position
	_apply_growth_tier(next_tier)


func _retry_pending_growth() -> void:
	if _pending_growth_tier <= _growth_tier or _frog.is_flying:
		return
	var safe_position := _find_safe_frog_position(
		_frog.radius_for_tier(_pending_growth_tier)
	)
	if safe_position == Vector2.INF:
		return
	_frog.global_position = safe_position
	_apply_growth_tier(_pending_growth_tier)


func _apply_growth_tier(tier: int) -> void:
	_growth_tier = tier
	_pending_growth_tier = -1
	_frog.set_growth_tier(_growth_tier)
	_frog.celebrate_growth(_motion_scale)
	_effects.emit_growth(_frog.global_position)
	AudioDirector.play_effect(FrogAudioDirector.GROWTH)
	_show_status("Growth tier %d! The frog and tongue are larger." % (_growth_tier + 1))
	growth_tier_applied.emit(_growth_tier)


func _update_hud() -> void:
	_score_label.text = "Score: %d" % _score
	_guide_button.disabled = _tutorial != null and _tutorial.active
	_belly_button.text = "Belly (%d)" % _belly.size()
	if _growth_tier >= GROWTH_THRESHOLDS.size():
		_growth_label.text = "Growth: MAX"
	else:
		_growth_label.text = "Growth: %d / %d" % [
			_growth_points,
			GROWTH_THRESHOLDS[_growth_tier],
		]


func set_motion_scale(value: float) -> void:
	_motion_scale_configured = true
	_motion_scale = clampf(value, 0.0, 1.0)
	_apply_motion_scale(_motion_scale)


func performance_structure_snapshot() -> Dictionary:
	var counts := {
		"game_nodes": 0,
		"canvas_items": 0,
		"controls": 0,
		"collision_objects": 0,
		"collision_shapes": 0,
		"processing_nodes": 0,
		"physics_processing_nodes": 0,
	}
	_count_performance_nodes(self, counts)
	var active_pedestrians := 0
	var active_vehicles := 0
	if is_instance_valid(_city_activity):
		active_pedestrians = _city_activity.active_pedestrian_count()
		active_vehicles = _city_activity.active_vehicle_count()
	var audio_structure := AudioDirector.structure_snapshot()
	return {
		"game_nodes": counts["game_nodes"],
		"canvas_items": counts["canvas_items"],
		"controls": counts["controls"],
		"collision_objects": counts["collision_objects"],
		"collision_shapes": counts["collision_shapes"],
		"processing_nodes": counts["processing_nodes"],
		"physics_processing_nodes": counts["physics_processing_nodes"],
		"targets": _targets.size(),
		"buildings": _buildings.size(),
		"pursuers": 1 if is_instance_valid(_pursuer) else 0,
		"belly_items": _belly.size(),
		"belly_rows": _belly_list.get_child_count(),
		"guide_rows": _guide_list.get_child_count(),
		"known_discoveries": _known_discovery_count(),
		"active_pedestrians": active_pedestrians,
		"active_vehicles": active_vehicles,
		"active_city_actors": active_pedestrians + active_vehicles,
		"active_effects": (
			_effects.active_effect_count()
			if is_instance_valid(_effects)
			else 0
		),
		"touch_feedback": (
			_touch_feedback.active_feedback_count()
			if is_instance_valid(_touch_feedback)
			else 0
		),
		"growth_tier": _growth_tier,
		"tongue_points": _tongue.points.size(),
		"belly_overlay_visible": _belly_overlay.visible,
		"guide_overlay_visible": _guide_overlay.visible,
		"options_overlay_visible": _options_overlay.visible,
		"reduce_motion": _reduce_motion_enabled,
		"larger_text_controls": _larger_text_controls_enabled,
		"performance_instrumentation": is_instance_valid(
			_performance_instrumentation
		),
		"audio_nodes": audio_structure["audio_nodes"],
		"audio_players": audio_structure["audio_players"],
		"audio_effect_voices": audio_structure["audio_effect_voices"],
		"audio_active_effect_voices": audio_structure[
			"audio_active_effect_voices"
		],
	}


func _apply_motion_scale(value: float) -> void:
	_motion_scale = clampf(value, 0.0, 1.0)
	if is_instance_valid(_effects):
		_effects.set_motion_scale(_motion_scale)
	if is_instance_valid(_city_activity):
		_city_activity.set_motion_scale(_motion_scale)
	if is_instance_valid(_frog):
		_frog.set_presentation_motion_scale(_motion_scale)
	for target in _targets:
		if is_instance_valid(target):
			target.set_presentation_motion_scale(_motion_scale)
	if is_instance_valid(_touch_feedback):
		_touch_feedback.set_motion_scale(_motion_scale)
	if is_instance_valid(_tutorial_marker):
		_tutorial_marker.set_motion_scale(_motion_scale)
	if _motion_scale <= 0.0:
		_clear_camera_shake()
		_tongue.width = 12.0
		if _tongue_phase == TonguePhase.RETRACTING:
			_hide_tongue()
		elif _tongue_phase != TonguePhase.HIDDEN:
			_tongue_phase = TonguePhase.HOLDING
			_tongue_phase_time = 0.0
			_tongue_extension = 1.0
			_apply_tongue_visual()


func _count_performance_nodes(node: Node, counts: Dictionary) -> void:
	counts["game_nodes"] = int(counts["game_nodes"]) + 1
	if node is CanvasItem:
		counts["canvas_items"] = int(counts["canvas_items"]) + 1
	if node is Control:
		counts["controls"] = int(counts["controls"]) + 1
	if node is CollisionObject2D:
		counts["collision_objects"] = int(counts["collision_objects"]) + 1
	if node is CollisionShape2D:
		counts["collision_shapes"] = int(counts["collision_shapes"]) + 1
	if node.is_processing():
		counts["processing_nodes"] = int(counts["processing_nodes"]) + 1
	if node.is_physics_processing():
		counts["physics_processing_nodes"] = (
			int(counts["physics_processing_nodes"]) + 1
		)
	for child in node.get_children():
		_count_performance_nodes(child, counts)


func _enable_requested_performance_instrumentation() -> void:
	if not PERFORMANCE_INSTRUMENTATION_SCRIPT.requested():
		return
	_performance_instrumentation = PERFORMANCE_INSTRUMENTATION_SCRIPT.new()
	_performance_instrumentation.configure(self)
	add_child(_performance_instrumentation)


func _show_digest_reward(points: int, growth_gain: int) -> void:
	_reward_label.text = "+%d points    +%d growth" % [
		points,
		growth_gain,
	]
	_reward_label.visible = true
	_reward_label.modulate = Color.WHITE
	_reward_label.scale = Vector2.ONE
	_reward_time = REWARD_DURATION
	if _belly_overlay.visible:
		_pending_hud_pulse = true
	else:
		_start_hud_pulse()


func _start_hud_pulse() -> void:
	_pending_hud_pulse = false
	_score_pulse_time = HUD_PULSE_DURATION
	_growth_pulse_time = HUD_PULSE_DURATION


func _update_hud_feedback(delta: float) -> void:
	_score_pulse_time = maxf(0.0, _score_pulse_time - delta)
	_growth_pulse_time = maxf(0.0, _growth_pulse_time - delta)
	_reward_time = maxf(0.0, _reward_time - delta)
	_discovery_banner_time = maxf(
		0.0,
		_discovery_banner_time - delta
	)
	_update_label_pulse(_score_label, _score_pulse_time)
	_update_label_pulse(_growth_label, _growth_pulse_time)
	_update_challenge_pulses(delta)
	if _discovery_banner_time <= 0.0:
		_discovery_banner.visible = false
		_discovery_banner.modulate = Color.WHITE
	else:
		_discovery_banner.modulate.a = clampf(
			_discovery_banner_time * 3.0,
			0.0,
			1.0
		)

	if _reward_time <= 0.0:
		_reward_label.visible = false
		_reward_label.modulate = Color.WHITE
		_reward_label.scale = Vector2.ONE
		return
	var reward_progress := 1.0 - _reward_time / REWARD_DURATION
	_reward_label.pivot_offset = _reward_label.size / 2.0
	_reward_label.scale = Vector2.ONE * (
		1.0 + sin(reward_progress * PI) * 0.1 * _motion_scale
	)
	_reward_label.modulate.a = clampf(_reward_time * 4.0, 0.0, 1.0)


func _update_challenge_pulses(delta: float) -> void:
	for challenge_id in _challenge_pulse_times.keys():
		var time_left := maxf(
			0.0,
			float(_challenge_pulse_times[challenge_id]) - delta
		)
		var label := _challenge_label_for(str(challenge_id))
		if is_instance_valid(label):
			_update_label_pulse(label, time_left)
		if time_left <= 0.0:
			_challenge_pulse_times.erase(challenge_id)
		else:
			_challenge_pulse_times[challenge_id] = time_left


func _challenge_label_for(challenge_id: String) -> Label:
	match challenge_id:
		SessionChallenges.SHARP_AIM:
			return _challenge_sharp_aim
		SessionChallenges.HOLD_ON:
			return _challenge_hold_on
		SessionChallenges.CITY_TOUR:
			return _challenge_city_tour
	return null


func _update_label_pulse(label: Label, time_left: float) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE
	if time_left <= 0.0:
		label.modulate = Color.WHITE
		return
	var progress := 1.0 - time_left / HUD_PULSE_DURATION
	label.modulate = Color.WHITE.lerp(
		Color(1.45, 1.35, 1.2, 1.0),
		sin(progress * PI) * 0.55
	)


func _show_tongue(end_position: Vector2) -> void:
	_tongue_end = end_position
	_tongue_phase = (
		TonguePhase.HOLDING
		if _motion_scale <= 0.0
		else TonguePhase.EXTENDING
	)
	_tongue_phase_time = 0.0
	_tongue_extension = 1.0 if _motion_scale <= 0.0 else 0.0
	_tongue_retract_start = 0.0
	_apply_tongue_visual()


func _start_tongue_retract() -> void:
	if _tongue_phase == TonguePhase.HIDDEN or _tongue_extension <= 0.01:
		_hide_tongue()
		return
	if _motion_scale <= 0.0:
		_hide_tongue()
		return
	_tongue_phase = TonguePhase.RETRACTING
	_tongue_phase_time = 0.0
	_tongue_retract_start = _tongue_extension


func _update_tongue_visual(delta: float) -> void:
	if _tongue_phase == TonguePhase.HIDDEN:
		return
	_struggle_kick = move_toward(_struggle_kick, 0.0, delta * 6.5)
	if is_instance_valid(_struggle_target):
		_tongue_end = (
			_struggle_target.global_position + _struggle_hit_offset
		)
	elif is_instance_valid(_pull_target):
		_tongue_end = _pull_target.global_position + _pull_hit_offset

	var attached := (
		is_instance_valid(_struggle_target)
		or is_instance_valid(_pull_target)
	)
	match _tongue_phase:
		TonguePhase.EXTENDING:
			_tongue_phase_time += delta
			var progress := clampf(
				_tongue_phase_time / TONGUE_EXTEND_DURATION,
				0.0,
				1.0
			)
			_tongue_extension = 1.0 - pow(1.0 - progress, 3.0)
			if progress >= 1.0:
				_tongue_phase = TonguePhase.HOLDING
				_tongue_phase_time = 0.0
		TonguePhase.HOLDING:
			_tongue_extension = 1.0
			if not attached:
				_tongue_phase_time += delta
				if _tongue_phase_time >= TONGUE_HOLD_DURATION:
					_start_tongue_retract()
		TonguePhase.RETRACTING:
			_tongue_phase_time += delta
			var progress := clampf(
				_tongue_phase_time / TONGUE_RETRACT_DURATION,
				0.0,
				1.0
			)
			_tongue_extension = (
				_tongue_retract_start
				* (1.0 - (1.0 - pow(1.0 - progress, 2.0)))
			)
			if progress >= 1.0:
				_hide_tongue()
				return
	_apply_tongue_visual()


func _apply_tongue_visual() -> void:
	var start := _frog.global_position
	var visible_end := start.lerp(_tongue_end, _tongue_extension)
	_tongue.points = PackedVector2Array([start, visible_end])
	_tongue.width = 12.0 + _struggle_kick * 5.0 * _motion_scale
	_tongue.default_color = TONGUE_COLOR.lerp(
		Color.WHITE,
		_struggle_kick * 0.38
	)


func _hide_tongue() -> void:
	_tongue_phase = TonguePhase.HIDDEN
	_tongue_phase_time = 0.0
	_tongue_extension = 0.0
	_tongue_retract_start = 0.0
	_struggle_kick = 0.0
	_tongue.width = 12.0
	_tongue.default_color = TONGUE_COLOR
	_tongue.clear_points()


func _show_status(message: String) -> void:
	_status_label.text = message
	_status_time = 3.0


func _find_target_at(world_position: Vector2) -> EdibleTarget:
	var nearest: EdibleTarget
	var nearest_distance := INF
	for target in _targets:
		if not is_instance_valid(target) or target.latched:
			continue
		if target.hit_test(world_position):
			var distance := target.global_position.distance_to(world_position)
			if distance < nearest_distance:
				nearest = target
				nearest_distance = distance
	return nearest


func _building_requiring_entry(
	target: EdibleTarget
) -> PrototypeBuilding:
	if (
		target == null
		or target.kind == "building"
		or target.building_id.is_empty()
	):
		return null
	var building := (
		_building_by_id.get(target.building_id) as PrototypeBuilding
	)
	if (
		not is_instance_valid(building)
		or building.consumed
		or not building.contains_world_point(target.global_position)
		or building.contains_world_point(_frog.global_position)
	):
		return null
	return building


func _first_tongue_obstruction(
	end_position: Vector2,
	exclude_pursuer: bool = false,
	selected_target: EdibleTarget = null
) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(
		_frog.global_position,
		end_position,
		1
	)
	var excluded_rids: Array[RID] = [_frog.get_rid()]
	if exclude_pursuer and is_instance_valid(_pursuer):
		excluded_rids.append(_pursuer.get_rid())
	if (
		is_instance_valid(selected_target)
		and not selected_target.building_part_id.is_empty()
	):
		var building := (
			_building_by_id.get(selected_target.building_id) as PrototypeBuilding
		)
		if is_instance_valid(building):
			var part_rid := building.part_body_rid(selected_target.building_part_id)
			if part_rid.is_valid():
				excluded_rids.append(part_rid)
	query.exclude = excluded_rids
	return get_world_2d().direct_space_state.intersect_ray(query)


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _clamp_to_world(world_position: Vector2) -> Vector2:
	return Vector2(
		clampf(world_position.x, WORLD_RECT.position.x, WORLD_RECT.end.x),
		clampf(world_position.y, WORLD_RECT.position.y, WORLD_RECT.end.y)
	)


func _rotate_camera(
	screen_delta_x: float,
	screen_position: Vector2 = Vector2.INF
) -> void:
	if (
		_tutorial != null
		and _tutorial.active
		and not _tutorial.allows_camera_rotation()
	):
		return
	var radians := screen_delta_x * 0.006
	if is_zero_approx(radians):
		return
	_camera.rotation -= radians
	manual_camera_rotated.emit(absf(radians))
	_touch_feedback.show_camera(
		get_viewport_rect().size / 2.0
		if screen_position == Vector2.INF
		else screen_position
	)


func _update_camera() -> void:
	var forward := Vector2.UP.rotated(_camera.rotation)
	_camera.global_position = _frog.global_position + forward * 220.0


func _trigger_camera_shake(amplitude: float, duration: float) -> void:
	_camera_shake_amplitude = maxf(_camera_shake_amplitude, amplitude)
	_camera_shake_duration = maxf(_camera_shake_duration, duration)
	_camera_shake_time = maxf(_camera_shake_time, duration)


func _update_camera_feedback(delta: float) -> void:
	if _camera_shake_time <= 0.0:
		_camera.offset = Vector2.ZERO
		_camera_shake_amplitude = 0.0
		_camera_shake_duration = 0.0
		return
	_camera_shake_time = maxf(0.0, _camera_shake_time - delta)
	if (
		_motion_scale <= 0.0
		or _camera_gesture
		or is_instance_valid(_struggle_target)
	):
		_camera.offset = Vector2.ZERO
		return
	var elapsed := _camera_shake_duration - _camera_shake_time
	var decay := (
		_camera_shake_time / maxf(_camera_shake_duration, 0.001)
	)
	var amplitude := _camera_shake_amplitude * decay * _motion_scale
	var shake_direction := Vector2(
		sin(elapsed * 71.0),
		cos(elapsed * 89.0)
	).limit_length(1.0)
	_camera.offset = shake_direction * amplitude


func _update_target_presentation() -> void:
	for target in _targets:
		if not is_instance_valid(target):
			continue
		var distance := target.global_position.distance_to(_frog.global_position)
		var target_scale := clampf(1.08 - distance / 5200.0, 0.74, 1.08)
		target.set_presentation_scale(target_scale)


func _check_vehicle_hazards() -> void:
	if _damage_cooldown > 0.0:
		return
	for target in _targets:
		if (
			is_instance_valid(target)
			and target.is_vehicle
			and not target.can_be_swallowed(_growth_tier)
			and target.global_position.distance_to(_frog.global_position)
			< target.pick_radius + _frog.collision_radius()
		):
			_apply_damage(target.global_position, 12, "A delivery van knocked the frog back!")
			return


func _apply_damage(source_position: Vector2, penalty: int, message: String) -> void:
	if _damage_cooldown > 0.0:
		return
	_damage_cooldown = DAMAGE_COOLDOWN
	_score = maxi(0, _score - penalty)
	_frog.knock_back_from(source_position)
	_effects.emit_damage(_frog.global_position)
	_trigger_camera_shake(8.0, 0.24)
	AudioDirector.play_effect(FrogAudioDirector.DAMAGE)
	score_changed.emit(_score)
	_update_hud()
	_show_status(message)


func _spawn_pursuer() -> void:
	if is_instance_valid(_pursuer):
		return
	var spawn_position := _find_pursuer_spawn_position()
	if spawn_position == Vector2.INF:
		_show_status("Animal Control was called, but could not reach this area.")
		return
	_pursuer = PURSUER_SCRIPT.new() as PrototypePursuer
	_pursuer.frog = _frog
	_pursuer.position = spawn_position
	_pursuer.caught.connect(_on_pursuer_caught)
	_pursuer.escaped.connect(_on_pursuer_escaped)
	_world.add_child(_pursuer)


func _find_pursuer_spawn_position() -> Vector2:
	var directions := [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(1, 1).normalized(),
		Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(),
		Vector2(-1, -1).normalized(),
	]
	var fallback := Vector2.INF
	for distance in [520.0, 700.0, 860.0]:
		for direction in directions:
			var candidate := _clamp_to_world(
				_frog.global_position + direction.rotated(_camera.rotation) * distance
			)
			candidate = _clamp_circle_to_world(candidate, 28.0)
			if _position_inside_building(candidate):
				continue
			if not _circle_position_clear(candidate, 28.0, false):
				continue
			if fallback == Vector2.INF:
				fallback = candidate
			var ray := PhysicsRayQueryParameters2D.create(
				candidate,
				_frog.global_position,
				1
			)
			ray.exclude = [_frog.get_rid()]
			if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				return candidate
	return fallback


func _position_inside_building(position: Vector2) -> bool:
	for building in _buildings:
		if is_instance_valid(building) and not building.consumed and building.contains_world_point(position):
			return true
	return false


func _activate_building_target(building_id: String) -> void:
	for target in _targets:
		if (
			is_instance_valid(target)
			and target.kind == "building"
			and target.building_id == building_id
		):
			target.selectable = true
			return


func _on_pursuer_caught(source_position: Vector2) -> void:
	_apply_damage(source_position, 25, "Animal Control caught you! You lost some points.")


func _on_pursuer_escaped() -> void:
	_pursuer = null
	_show_status("You escaped Animal Control!")


func _is_actively_chased() -> bool:
	return (
		is_instance_valid(_pursuer)
		and _pursuer.active
		and _pursuer.global_position.distance_to(_frog.global_position) < 920.0
	)


func _swallow_pursuer(pursuer: PrototypePursuer, accuracy: float) -> void:
	var effect_position := pursuer.global_position
	var item := BellyItem.new()
	item.target_id = "animal_control"
	item.display_name = "Animal Control Officer"
	item.kind = "living"
	item.base_value = 95
	item.size_tier = 2
	item.resistant = true
	item.taps_required = 10
	item.pick_radius = 40.0
	item.accuracy = accuracy
	item.captured_while_chased = true
	item.target_color = Color("da7462")
	item.movement_bounds = WORLD_RECT.grow(-100)
	item.restockable = false
	_record_discovery(item.target_id, item.display_name)
	_challenges.record_swallow(item.target_id, item.accuracy)
	_update_challenge_hud()
	_belly.append(item)
	pursuer.active = false
	pursuer.queue_free()
	_pursuer = null
	AudioDirector.play_effect(FrogAudioDirector.SWALLOW)
	_effects.emit_swallow(effect_position, item.target_color)
	_tongue_recovery = TONGUE_RECOVERY
	_update_hud()
	_show_status("You swallowed Animal Control! Digest or return them safely.")


func _start_pull(target: EdibleTarget, hit_offset: Vector2) -> void:
	_pull_target = target
	_pull_time_left = 1.8
	_pull_hit_offset = hit_offset
	_frog.movement_enabled = true
	target.pulse_feedback(_motion_scale)
	_show_tongue(target.global_position + _pull_hit_offset)


func _cancel_pull() -> void:
	if is_instance_valid(_pull_target):
		_tongue_end = _pull_target.global_position + _pull_hit_offset
	_pull_target = null
	_pull_time_left = 0.0
	_pull_hit_offset = Vector2.ZERO
	_frog.stop_moving()
	_start_tongue_retract()
	_tongue_recovery = TONGUE_RECOVERY


func _queue_living_respawn(item: BellyItem) -> void:
	if not item.restockable:
		return
	if item.kind == "living":
		_respawn_living_later(item)
	else:
		_restock_target_later(item)


func _apply_digest_effects(item: BellyItem) -> void:
	_queue_living_respawn(item)
	if item.target_id == "golden_cake":
		_activate_flight(60.0)


func _respawn_living_later(item: BellyItem) -> void:
	await get_tree().create_timer(4.0, false).timeout
	if not is_inside_tree():
		return
	var spawn_position := await _wait_for_target_spawn_position(
		item.pick_radius,
		item.movement_bounds
	)
	if spawn_position == Vector2.INF:
		return
	var target := EDIBLE_SCRIPT.new() as EdibleTarget
	target.configure_from_belly(item)
	target.position = spawn_position
	target.dangerous_location = false
	if target.building_id.is_empty():
		if target.velocity.length() < 60.0:
			target.velocity = Vector2(100, 70)
		target.unpredictable = true
	_world.add_child(target)
	_targets.append(target)


func _restock_target_later(item: BellyItem) -> void:
	if item.rare and _rare_respawn_pending.has(item.target_id):
		return
	if item.rare:
		_rare_respawn_pending[item.target_id] = true
	var delay := randf_range(90.0, 180.0) if item.rare else 9.0
	await get_tree().create_timer(delay, false).timeout
	if not is_inside_tree():
		return
	if item.rare and _has_live_target_id(item.target_id):
		_rare_respawn_pending.erase(item.target_id)
		return
	var preferred_bounds := item.movement_bounds
	if item.kind == "vehicle":
		preferred_bounds = Rect2(-1650, 80, 3300, 1)
	var spawn_position := await _wait_for_target_spawn_position(
		item.pick_radius,
		preferred_bounds,
		-1
	)
	if spawn_position == Vector2.INF:
		return
	if item.rare and _has_live_target_id(item.target_id):
		_rare_respawn_pending.erase(item.target_id)
		return
	var target := EDIBLE_SCRIPT.new() as EdibleTarget
	target.configure_from_belly(item)
	target.position = spawn_position
	target.dangerous_location = false
	_world.add_child(target)
	_targets.append(target)
	_rare_respawn_pending.erase(item.target_id)


func _wait_for_target_spawn_position(
	radius: float,
	preferred_bounds: Rect2,
	attempt_limit: int = 6
) -> Vector2:
	var attempt := 0
	while attempt_limit < 0 or attempt < attempt_limit:
		var position := _allocate_target_spawn_position(radius, preferred_bounds)
		if position != Vector2.INF:
			return position
		attempt += 1
		var retry_delay := minf(10.0, 2.0 + float(attempt))
		await get_tree().create_timer(retry_delay, false).timeout
		if not is_inside_tree():
			return Vector2.INF
	return Vector2.INF


func _allocate_target_spawn_position(
	radius: float,
	preferred_bounds: Rect2 = Rect2()
) -> Vector2:
	var best_position := Vector2.INF
	var best_distance := -1.0
	var candidates: Array[Vector2] = []
	for position in RESTOCK_POSITIONS:
		candidates.append(position)
	if preferred_bounds.size != Vector2.ZERO:
		if preferred_bounds.size.y <= 2.0:
			for x_step in 9:
				var x_ratio := float(x_step + 1) / 10.0
				candidates.append(Vector2(
					lerpf(preferred_bounds.position.x, preferred_bounds.end.x, x_ratio),
					preferred_bounds.get_center().y
				))
		else:
			for x_step in 5:
				for y_step in 4:
					var x_ratio := float(x_step + 1) / 6.0
					var y_ratio := float(y_step + 1) / 5.0
					candidates.append(Vector2(
						lerpf(preferred_bounds.position.x, preferred_bounds.end.x, x_ratio),
						lerpf(preferred_bounds.position.y, preferred_bounds.end.y, y_ratio)
					))
	for candidate in candidates:
		if preferred_bounds.size != Vector2.ZERO and not preferred_bounds.grow(1.0).has_point(candidate):
			continue
		if not _circle_position_clear(candidate, radius, false):
			continue
		var overlaps_target := false
		for target in _targets:
			if (
				is_instance_valid(target)
				and target.global_position.distance_to(candidate)
				< target.pick_radius + radius + 60.0
			):
				overlaps_target = true
				break
		if overlaps_target:
			continue
		var frog_distance := _frog.global_position.distance_to(candidate)
		if frog_distance > best_distance:
			best_position = candidate
			best_distance = frog_distance
	return best_position


func _has_live_target_id(target_id: String) -> bool:
	for target in _targets:
		if is_instance_valid(target) and target.target_id == target_id:
			return true
	return false


func _activate_flight(duration: float) -> void:
	_flight_time_left = maxf(_flight_time_left, duration)
	_frog.set_flying(true)
	_show_status("Flight power! The frog can fly over walls for one minute.")
	_update_power_label()


func _update_flight(delta: float) -> void:
	if _flight_time_left <= 0.0:
		return
	_flight_time_left = maxf(0.0, _flight_time_left - delta)
	if _flight_time_left <= 0.0:
		if not _land_frog_safely():
			_flight_time_left = 0.5
			_show_status("Fly to an open area so the frog can land safely.")
			_update_power_label()
			return
		_frog.set_flying(false)
		_show_status("The flight power wore off.")
	_update_power_label()


func _land_frog_safely() -> bool:
	var safe_position := _find_safe_frog_position(_frog.collision_radius())
	if safe_position != Vector2.INF:
		_frog.global_position = safe_position
		return true
	elif _circle_position_clear(
		_last_safe_ground_position,
		_frog.collision_radius(),
		true
	):
		_frog.global_position = _last_safe_ground_position
		return true
	return false


func _update_power_label() -> void:
	_power_label.text = (
		"FLY %ds" % ceili(_flight_time_left)
		if _flight_time_left > 0.0
		else ""
	)


func _update_day_night(delta: float) -> void:
	_day_clock = fmod(_day_clock + delta / 180.0, 1.0)
	var daylight := (sin(_day_clock * TAU - PI / 2.0) + 1.0) * 0.5
	_current_daylight = daylight
	var night_color := Color(0.44, 0.56, 0.78)
	_world_tint.color = night_color.lerp(Color.WHITE, 0.38 + daylight * 0.62)
	if is_instance_valid(_city_activity):
		_city_activity.set_daylight(daylight)
	AudioDirector.set_game_ambience(
		self,
		daylight < NIGHT_AUDIO_THRESHOLD
	)


func _disable_belly_actions() -> void:
	_digest_all_button.disabled = true
	for row in _belly_list.get_children():
		for child in row.get_children():
			if child is Button:
				(child as Button).disabled = true


func _touch_over_hud_action(screen_position: Vector2) -> bool:
	if _overlay_blocking():
		return true
	if (
		_tutorial != null
		and _tutorial.active
		and _skip_tutorial_button.get_global_rect().has_point(screen_position)
	):
		return true
	return _top_margin.get_global_rect().has_point(screen_position)


func _on_accessibility_toggled(_pressed: bool) -> void:
	if _refreshing_accessibility_controls:
		return
	_reduce_motion_enabled = _reduce_motion_toggle.button_pressed
	_larger_text_controls_enabled = _larger_ui_toggle.button_pressed
	_apply_motion_scale(0.0 if _reduce_motion_enabled else 1.0)
	_apply_accessibility_presentation()
	_update_accessibility_controls()
	accessibility_changed.emit(
		_reduce_motion_enabled,
		_larger_text_controls_enabled
	)
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _update_accessibility_controls() -> void:
	_refreshing_accessibility_controls = true
	_reduce_motion_toggle.button_pressed = _reduce_motion_enabled
	_larger_ui_toggle.button_pressed = _larger_text_controls_enabled
	_reduce_motion_toggle.text = "Reduce motion: %s" % (
		"On" if _reduce_motion_enabled else "Off"
	)
	_larger_ui_toggle.text = "Larger text & controls: %s" % (
		"On" if _larger_text_controls_enabled else "Off"
	)
	_refreshing_accessibility_controls = false


func _on_audio_drag_started() -> void:
	_audio_dragging = true


func _on_audio_drag_ended(value_changed: bool) -> void:
	_audio_dragging = false
	if not value_changed:
		return
	_emit_audio_preferences()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _on_audio_value_changed(_value: float) -> void:
	if _refreshing_audio_controls:
		return
	_audio_preferences = _audio_preferences_from_controls()
	_update_audio_labels()
	AudioDirector.apply_preferences(_audio_preferences)
	if not _audio_dragging:
		_emit_audio_preferences()
		AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _emit_audio_preferences() -> void:
	audio_changed.emit(_audio_preferences.duplicate())


func _update_audio_controls() -> void:
	_audio_preferences = AudioPreferences.sanitize_preferences(
		_audio_preferences
	)
	_refreshing_audio_controls = true
	_master_volume_slider.value = (
		float(_audio_preferences["master"]) * 100.0
	)
	_music_volume_slider.value = (
		float(_audio_preferences["music"]) * 100.0
	)
	_effects_volume_slider.value = (
		float(_audio_preferences["effects"]) * 100.0
	)
	_refreshing_audio_controls = false
	_update_audio_labels()
	AudioDirector.apply_preferences(_audio_preferences)


func _audio_preferences_from_controls() -> Dictionary:
	return AudioPreferences.sanitize_preferences({
		"master": _master_volume_slider.value / 100.0,
		"music": _music_volume_slider.value / 100.0,
		"effects": _effects_volume_slider.value / 100.0,
	})


func _audio_sliders() -> Array[HSlider]:
	return [
		_master_volume_slider,
		_music_volume_slider,
		_effects_volume_slider,
	]


func _update_audio_labels() -> void:
	_master_volume_label.text = "Master volume: %d%%" % roundi(
		_master_volume_slider.value
	)
	_music_volume_label.text = "Music & ambience: %d%%" % roundi(
		_music_volume_slider.value
	)
	_effects_volume_label.text = "Effects volume: %d%%" % roundi(
		_effects_volume_slider.value
	)


func _apply_accessibility_presentation() -> void:
	AccessibilityPresentation.apply(
		$HUD/Root,
		_larger_text_controls_enabled
	)


func _apply_safe_area() -> void:
	apply_safe_area_insets(
		AccessibilityPresentation.current_safe_area_insets(
			get_viewport_rect().size
		)
	)


func apply_safe_area_insets(insets: Vector4) -> void:
	var left := maxf(0.0, insets.x)
	var top := maxf(0.0, insets.y)
	var right := maxf(0.0, insets.z)
	var bottom := maxf(0.0, insets.w)

	_top_background.offset_bottom = 82.0 + top
	_top_margin.offset_bottom = 82.0 + top
	_top_margin.add_theme_constant_override(
		"margin_left",
		roundi(18.0 + left)
	)
	_top_margin.add_theme_constant_override(
		"margin_top",
		roundi(12.0 + top)
	)
	_top_margin.add_theme_constant_override(
		"margin_right",
		roundi(18.0 + right)
	)

	_status_panel.offset_top = 92.0 + top
	_status_panel.offset_bottom = 150.0 + top
	_challenge_panel.offset_left = 22.0 + left
	_challenge_panel.offset_top = 94.0 + top
	_challenge_panel.offset_right = 300.0 + left
	_challenge_panel.offset_bottom = 286.0 + top
	_discovery_banner.offset_top = 162.0 + top
	_discovery_banner.offset_bottom = 222.0 + top

	_control_legend.offset_left = -500.0 - right
	_control_legend.offset_top = -104.0 - bottom
	_control_legend.offset_right = -22.0 - right
	_control_legend.offset_bottom = -18.0 - bottom
	_instructions_label.offset_left = -488.0 - right
	_instructions_label.offset_top = -96.0 - bottom
	_instructions_label.offset_right = -34.0 - right
	_instructions_label.offset_bottom = -26.0 - bottom
	_tutorial_panel.offset_left = -610.0 - right
	_tutorial_panel.offset_top = -258.0 - bottom
	_tutorial_panel.offset_right = -24.0 - right
	_tutorial_panel.offset_bottom = -24.0 - bottom

	var safe_centers: Array[CenterContainer] = [
		_belly_center,
		$HUD/Root/GuideOverlay/Center,
		_options_center,
	]
	for center in safe_centers:
		center.offset_left = left
		center.offset_top = top
		center.offset_right = -right
		center.offset_bottom = -bottom


func _find_safe_spit_position(radius: float) -> Vector2:
	var directions := [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(1, 1).normalized(),
		Vector2(-1, 1).normalized(),
	]
	for direction in directions:
		var distance := _frog.collision_radius() + radius + 50.0
		var candidate := _clamp_circle_to_world(
			_frog.global_position + direction * distance,
			radius
		)
		if (
			_circle_position_clear(candidate, radius, false)
			and not _position_overlaps_target(candidate, radius)
		):
			return candidate
	return Vector2.INF


func _find_safe_frog_position(radius: float) -> Vector2:
	var candidates := [_frog.global_position, _last_safe_ground_position]
	for distance in [60.0, 110.0, 170.0, 240.0]:
		for step in 12:
			var angle := TAU * float(step) / 12.0
			candidates.append(_frog.global_position + Vector2.RIGHT.rotated(angle) * distance)
	for candidate in candidates:
		var clamped_candidate := _clamp_circle_to_world(candidate, radius)
		if (
			_circle_position_clear(clamped_candidate, radius, true)
			and _frog_relocation_path_clear(clamped_candidate)
		):
			return clamped_candidate
	return Vector2.INF


func _frog_relocation_path_clear(end_position: Vector2) -> bool:
	if _frog.global_position.is_equal_approx(end_position):
		return true
	var query := PhysicsRayQueryParameters2D.create(
		_frog.global_position,
		end_position,
		1
	)
	query.exclude = [_frog.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _circle_position_clear(
	position: Vector2,
	radius: float,
	exclude_frog: bool
) -> bool:
	if not WORLD_RECT.grow(-radius).has_point(position):
		return false
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = 1
	if exclude_frog:
		query.exclude = [_frog.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 8).is_empty()


func _clamp_circle_to_world(position: Vector2, radius: float) -> Vector2:
	var inset := WORLD_RECT.grow(-radius)
	return Vector2(
		clampf(position.x, inset.position.x, inset.end.x),
		clampf(position.y, inset.position.y, inset.end.y)
	)


func _position_overlaps_target(position: Vector2, radius: float) -> bool:
	for target in _targets:
		if (
			is_instance_valid(target)
			and target.global_position.distance_to(position)
			< target.pick_radius + radius + 12.0
		):
			return true
	return false


func _restore_building_from_belly(item: BellyItem) -> bool:
	var building := _building_by_id.get(item.building_id) as PrototypeBuilding
	if not is_instance_valid(building) or not building.consumed:
		return false
	if not _building_footprint_clear(building):
		return false
	building.restore()
	var target := EDIBLE_SCRIPT.new() as EdibleTarget
	target.configure_from_belly(item)
	target.position = building.global_position
	target.visible = false
	target.dangerous_location = false
	target.velocity = Vector2.ZERO
	target.move_bounds = Rect2()
	target.unpredictable = false
	_world.add_child(target)
	_targets.append(target)
	return true


func _building_footprint_clear(building: PrototypeBuilding) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = building.building_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, building.global_position)
	query.collision_mask = 1
	if not get_world_2d().direct_space_state.intersect_shape(query, 16).is_empty():
		return false
	var footprint := building.footprint_rect()
	for target in _targets:
		if (
			is_instance_valid(target)
			and _circle_overlaps_rect(
				target.global_position,
				target.pick_radius,
				footprint
			)
		):
			return false
	return true


func _circle_overlaps_rect(
	center: Vector2,
	radius: float,
	rect: Rect2
) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	return center.distance_squared_to(closest) < radius * radius


func _start_tutorial() -> void:
	_tutorial = TutorialController.new()
	_tutorial.step_changed.connect(_on_tutorial_step_changed)
	_tutorial.completed.connect(_on_tutorial_completed)
	movement_reached.connect(_tutorial.on_move_reached)
	manual_camera_rotated.connect(_tutorial.on_camera_rotated)
	target_swallowed.connect(_tutorial.on_target_swallowed)
	item_digested.connect(_tutorial.on_item_digested)
	growth_tier_applied.connect(_tutorial.on_growth_tier_applied)
	_store_tutorial_target_states()
	var move_marker := _clamp_circle_to_world(Vector2(-90, 570), 35.0)
	_tutorial.start(move_marker)


func _store_tutorial_target_states() -> void:
	for target_id in [
		"street_donut",
		"running_hotdog",
		"moonlight_market_sign",
		"moonlight_market_door",
	]:
		var target := _find_target_by_id(target_id)
		if target == null:
			continue
		_tutorial_original_target_states[target_id] = {
			"position": target.position,
			"velocity": target.velocity,
			"unpredictable": target.unpredictable,
			"move_bounds": target.move_bounds,
		}
	var hotdog := _find_target_by_id("running_hotdog")
	if hotdog != null:
		hotdog.velocity = Vector2.ZERO
		hotdog.unpredictable = false


func _on_tutorial_step_changed(
	step_index: int,
	step_count: int,
	title: String,
	instruction: String,
	target_id: String,
	show_marker: bool
) -> void:
	_tutorial_panel.visible = true
	_tutorial_progress.text = "Tutorial %d / %d" % [step_index + 1, step_count]
	_tutorial_title.text = title
	_tutorial_instruction.text = instruction
	_set_tutorial_highlight(target_id)

	if step_index == TutorialController.Step.EAT_HOTDOG:
		var hotdog := _find_target_by_id("running_hotdog")
		if hotdog != null:
			hotdog.position = _find_tutorial_target_position(hotdog)
			_set_tutorial_hotdog_motion(hotdog, Vector2(68, 24))

	if step_index == TutorialController.Step.WAIT_FOR_GROWTH:
		var safe_position := _find_safe_frog_position(_frog.radius_for_tier(1))
		if safe_position != Vector2.INF:
			_tutorial.marker_position = safe_position

	_tutorial_marker.position = _tutorial.marker_position
	_tutorial_marker.active = show_marker


func _set_tutorial_highlight(target_id: String) -> void:
	for target in _targets:
		if not is_instance_valid(target):
			continue
		target.highlighted = not target_id.is_empty() and target.target_id == target_id
		target.queue_redraw()


func _find_tutorial_target_position(target: EdibleTarget) -> Vector2:
	var directions := [
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.LEFT,
		Vector2.DOWN,
		Vector2(1, -1).normalized(),
		Vector2(1, 1).normalized(),
	]
	for direction in directions:
		var candidate := _clamp_circle_to_world(
			_frog.global_position + direction.rotated(_camera.rotation) * 245.0,
			target.pick_radius
		)
		if _position_inside_building(candidate):
			continue
		if not _circle_position_clear(candidate, target.pick_radius, false):
			continue
		var overlaps_other := false
		for other_target in _targets:
			if (
				other_target != target
				and is_instance_valid(other_target)
				and other_target.global_position.distance_to(candidate)
				< other_target.pick_radius + target.pick_radius + 30.0
			):
				overlaps_other = true
				break
		if not overlaps_other:
			return candidate
	return target.position


func _reset_tutorial_target_after_failed_struggle(target: EdibleTarget) -> void:
	target.set_latched(false)
	if _reset_building_part_position(target):
		return
	if target.target_id == "running_hotdog":
		target.position = _find_tutorial_target_position(target)
		_set_tutorial_hotdog_motion(target, Vector2(58, 18))


func _reset_building_part_position(target: EdibleTarget) -> bool:
	if target.building_id.is_empty() or target.building_part_id.is_empty():
		return false
	var building := (
		_building_by_id.get(target.building_id) as PrototypeBuilding
	)
	if not is_instance_valid(building):
		return false
	if building.is_part_removed(target.building_part_id):
		return false
	target.global_position = building.part_world_position(
		target.building_part_id
	)
	target.velocity = Vector2.ZERO
	target.unpredictable = false
	return true


func _reset_building_target_position(target: EdibleTarget) -> bool:
	if target.kind != "building" or target.building_id.is_empty():
		return false
	var building := (
		_building_by_id.get(target.building_id) as PrototypeBuilding
	)
	if not is_instance_valid(building):
		return false
	target.global_position = building.global_position
	target.velocity = Vector2.ZERO
	target.move_bounds = Rect2()
	target.unpredictable = false
	return true


func _reset_interior_target_after_failed_struggle(
	target: EdibleTarget
) -> PrototypeBuilding:
	if (
		target.kind == "building"
		or target.kind == "building_part"
		or target.building_id.is_empty()
	):
		return null
	var building := (
		_building_by_id.get(target.building_id) as PrototypeBuilding
	)
	if (
		not is_instance_valid(building)
		or building.consumed
		or not building.contains_world_point(target.global_position)
	):
		return null
	target.velocity = Vector2.ZERO
	target.unpredictable = false
	return building


func _set_tutorial_hotdog_motion(
	target: EdibleTarget,
	velocity: Vector2
) -> void:
	target.velocity = velocity
	target.unpredictable = true
	target.move_bounds = Rect2(
		target.position - Vector2(260, 190),
		Vector2(520, 380)
	).intersection(WORLD_RECT.grow(-80))


func _skip_tutorial() -> void:
	if _tutorial != null:
		AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)
		if is_instance_valid(_struggle_target):
			_clear_struggle()
		if is_instance_valid(_pull_target):
			_cancel_pull()
		_tutorial.skip()


func _on_tutorial_completed(skipped: bool) -> void:
	_tutorial_panel.visible = false
	_tutorial_marker.active = false
	_set_tutorial_highlight("")
	_restore_tutorial_target_states()
	if _belly_overlay.visible:
		_close_belly()
	_begin_session_challenges()
	_show_status(
		"Tutorial skipped. Explore and build your score!"
		if skipped
		else "Tutorial complete! Keep eating, growing, and exploring."
	)
	_update_hud()
	tutorial_finished.emit(skipped)


func _restore_tutorial_target_states() -> void:
	for target_id in _tutorial_original_target_states:
		var target := _find_target_by_id(str(target_id))
		if target == null:
			continue
		var state: Dictionary = _tutorial_original_target_states[target_id]
		target.position = state["position"]
		target.velocity = state["velocity"]
		target.unpredictable = bool(state["unpredictable"])
		target.move_bounds = state["move_bounds"]
	_tutorial_original_target_states.clear()


func _normalize_tutorial_belly_item(item: BellyItem) -> void:
	if (
		_tutorial == null
		or not _tutorial.active
		or not _tutorial_original_target_states.has(item.target_id)
	):
		return
	var state: Dictionary = _tutorial_original_target_states[item.target_id]
	item.movement_velocity = state["velocity"]
	item.unpredictable = bool(state["unpredictable"])
	item.movement_bounds = state["move_bounds"]


func _close_belly_after_tutorial_digest() -> void:
	if _belly_overlay.visible:
		_close_belly()


func _on_frog_move_reached(world_position: Vector2) -> void:
	movement_reached.emit(world_position)


func _find_target_by_id(target_id: String) -> EdibleTarget:
	for target in _targets:
		if is_instance_valid(target) and target.target_id == target_id:
			return target
	return null


func _end_game() -> void:
	if is_instance_valid(_struggle_target):
		_clear_struggle()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)
	get_tree().paused = false
	end_requested.emit(_score)


func _build_prototype_city() -> void:
	var cafe_props: Array[Rect2] = [
		Rect2(-196, -18, 110, 106),
		Rect2(86, -18, 110, 106),
	]
	var apartment_props: Array[Rect2] = [
		Rect2(-231, -28, 86, 128),
		Rect2(145, -28, 86, 56),
		Rect2(145, 70, 86, 60),
	]
	var market := _spawn_building(
		Vector2(-480, 420),
		Vector2(500, 390),
		"Moonlight Market",
		"east",
		Color("d6a65f"),
		"moonlight_market",
		true
	)
	var cafe := _spawn_building(
		Vector2(610, -570),
		Vector2(440, 360),
		"Leap Café",
		"south",
		Color("ca8d77"),
		"leap_cafe",
		false,
		Vector2(0, -120),
		cafe_props
	)
	var apartments := _spawn_building(
		Vector2(-610, 1210),
		Vector2(510, 330),
		"Canal Apartments",
		"north",
		Color("8aa6ce"),
		"canal_apartments",
		false,
		Vector2(0, 105),
		apartment_props
	)
	var cafe_bounds := cafe.interior_rect()
	var apartment_bounds := apartments.interior_rect()
	var oddities_shop := _spawn_building(
		Vector2(610, 1210),
		Vector2(500, 330),
		"Oddities Shop",
		"north",
		Color("a78bc4"),
		"oddities_shop",
		true,
		Vector2(150, 64)
	)
	_spawn_destruction_targets(market)

	_spawn_target({
		"id": "street_donut",
		"name": "Street Donut",
		"position": Vector2(180, 320),
		"value": 16,
		"color": Color("e59b78"),
	})
	_spawn_target({
		"id": "market_apple",
		"name": "Market Apple",
		"position": Vector2(-480, 340),
		"value": 18,
		"color": Color("db4d4d"),
	})
	_spawn_target({
		"id": "running_hotdog",
		"name": "Runaway Hot Dog",
		"position": Vector2(430, 420),
		"value": 30,
		"resistant": true,
		"taps": 7,
		"velocity": Vector2(120, 45),
		"unpredictable": true,
		"bounds": Rect2(250, 260, 720, 330),
		"kind": "living",
		"color": Color("e8974f"),
	})
	_spawn_target({
		"id": "shop_phone",
		"name": "Loose Phone",
		"position": Vector2(469, -630),
		"value": 38,
		"tier": 1,
		"kind": "object",
		"bounds": cafe_bounds,
		"building_id": cafe.building_id,
		"color": Color("4b8fc4"),
	})
	_spawn_target({
		"id": "park_chair",
		"name": "Park Chair",
		"position": Vector2(780, 470),
		"value": 48,
		"tier": 1,
		"kind": "object",
		"radius": 38.0,
		"color": Color("a96f3e"),
	})
	_spawn_target({
		"id": "golden_cake",
		"name": "Flying Golden Cake",
		"position": Vector2(920, -1050),
		"value": 115,
		"tier": 1,
		"rare": true,
		"resistant": true,
		"taps": 10,
		"velocity": Vector2(-100, 80),
		"unpredictable": true,
		"bounds": Rect2(430, -1250, 620, 430),
		"dangerous": true,
		"color": Color("f2ce43"),
	})
	_spawn_target({
		"id": "delivery_van",
		"name": "Delivery Van",
		"position": Vector2(-1550, 80),
		"value": 170,
		"tier": 2,
		"kind": "vehicle",
		"radius": 48.0,
		"velocity": Vector2(245, 0),
		"bounds": Rect2(-1650, 80, 3300, 1),
		"color": Color("e9e7d0"),
	})
	_spawn_target({
		"id": "market_vendor",
		"name": "Market Vendor",
		"position": Vector2(-480, 510),
		"value": 70,
		"tier": 1,
		"resistant": true,
		"taps": 9,
		"kind": "living",
		"color": Color("7867b8"),
	})
	_spawn_destruction_targets(oddities_shop)
	_spawn_target({
		"id": "canal_lobby_lamp",
		"name": "Lobby Lamp",
		"position": Vector2(-715, 1310),
		"value": 26,
		"kind": "object",
		"radius": 30.0,
		"bounds": apartment_bounds,
		"building_id": apartments.building_id,
		"color": Color("efd08a"),
	})
	_spawn_target({
		"id": "canal_tenant_cat",
		"name": "Tenant's Cat",
		"position": Vector2(-710, 1115),
		"value": 62,
		"tier": 1,
		"kind": "living",
		"radius": 30.0,
		"resistant": true,
		"taps": 6,
		"bounds": apartment_bounds,
		"building_id": apartments.building_id,
		"color": Color("8c8f9c"),
	})


func _spawn_building(
	building_position: Vector2,
	building_size: Vector2,
	building_name: String,
	door_side: String,
	color: Color,
	building_id: String,
	destructible_parts: bool = false,
	counter_position: Vector2 = Vector2(0, 64),
	interior_props: Array[Rect2] = []
) -> PrototypeBuilding:
	var building := BUILDING_SCRIPT.new() as PrototypeBuilding
	building.position = building_position
	building.building_size = building_size
	building.display_name = building_name
	building.door_side = door_side
	building.floor_color = color
	building.building_id = building_id
	building.destructible_parts = destructible_parts
	building.counter_position = counter_position
	building.interior_props = interior_props.duplicate()
	_world.add_child(building)
	_buildings.append(building)
	_building_by_id[building_id] = building
	return building


func _spawn_destruction_targets(building: PrototypeBuilding) -> void:
	var configuration := (
		DESTRUCTIBLE_BUILDING_TARGETS.get(building.building_id, {}) as Dictionary
	)
	if configuration.is_empty():
		push_error(
			"No destruction target configuration exists for %s."
			% building.building_id
		)
		return
	for part_configuration in configuration.get("parts", []):
		var target_data := (part_configuration as Dictionary).duplicate(true)
		var part_id := str(target_data.get("part_id", ""))
		target_data.erase("part_id")
		target_data["position"] = building.part_world_position(part_id)
		target_data["kind"] = "building_part"
		target_data["restockable"] = false
		target_data["building_id"] = building.building_id
		target_data["building_part_id"] = part_id
		_spawn_target(target_data)

	var whole_data := (
		(configuration.get("whole", {}) as Dictionary).duplicate(true)
	)
	whole_data["position"] = building.global_position
	whole_data["tier"] = 2
	whole_data["kind"] = "building"
	whole_data["resistant"] = true
	whole_data["restockable"] = false
	whole_data["building_id"] = building.building_id
	whole_data["hidden"] = true
	whole_data["selectable"] = false
	_spawn_target(whole_data)


func _spawn_target(data: Dictionary) -> EdibleTarget:
	var target := EDIBLE_SCRIPT.new() as EdibleTarget
	target.target_id = str(data.get("id", "target"))
	target.display_name = str(data.get("name", "Target"))
	target.position = data.get("position", Vector2.ZERO)
	target.base_value = int(data.get("value", 10))
	target.size_tier = int(data.get("tier", 0))
	target.kind = str(data.get("kind", "food"))
	target.rare = bool(data.get("rare", false))
	target.resistant = bool(data.get("resistant", false))
	target.taps_required = int(data.get("taps", 0))
	target.pick_radius = float(data.get("radius", 28.0))
	target.velocity = data.get("velocity", Vector2.ZERO)
	target.unpredictable = bool(data.get("unpredictable", false))
	target.move_bounds = data.get("bounds", WORLD_RECT.grow(-100))
	target.dangerous_location = bool(data.get("dangerous", false))
	target.target_color = data.get("color", Color("f5a84b"))
	target.is_vehicle = target.kind == "vehicle"
	target.restockable = bool(data.get("restockable", true))
	target.building_id = str(data.get("building_id", ""))
	target.building_part_id = str(data.get("building_part_id", ""))
	target.selectable = bool(data.get("selectable", true))
	target.visible = not bool(data.get("hidden", false))
	target.set_presentation_motion_scale(_motion_scale)
	_world.add_child(target)
	_targets.append(target)
	return target
