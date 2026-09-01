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
signal power_discovered(power_id: String)
signal profile_achievement_unlocked(
	achievement_id: String,
	derived_clue_id: String
)
signal device_achievement_unlocked(achievement_id: String)
signal story_clue_found(clue_id: String)
signal secret_unlocked(secret_id: String)
signal accessibility_changed(preferences: Dictionary)
signal audio_changed(preferences: Dictionary)

const EDIBLE_SCRIPT := preload("res://src/edible.gd")
const BUILDING_SCRIPT := preload("res://src/building.gd")
const INTERIOR_ROOM_SCRIPT := preload("res://src/interior_room.gd")
const DISTRICT_GENERATOR_SCRIPT := preload("res://src/district_generator.gd")
const GENERATED_DISTRICT_SCRIPT := preload("res://src/generated_district.gd")
const PURSUER_SCRIPT := preload("res://src/pursuer.gd")
const ROADBLOCK_SCRIPT := preload("res://src/roadblock.gd")
const PURSUIT_TRAP_SCRIPT := preload("res://src/pursuit_trap.gd")
const CITY_DETOUR_SCRIPT := preload("res://src/city_detour.gd")
const NAVIGATION_SCRIPT := preload("res://src/deterministic_navigation.gd")
const POWER_STATE_SCRIPT := preload("res://src/temporary_power_state.gd")
const ACHIEVEMENT_MODEL_SCRIPT := preload("res://src/achievement_model.gd")
const GAMEPLAY_TUNING_SCRIPT := preload("res://src/gameplay_tuning.gd")
const SCORE_EPILOGUE_SCENE := preload("res://scenes/score_epilogue.tscn")
const PERFORMANCE_INSTRUMENTATION_SCRIPT := preload(
	"res://src/performance_instrumentation.gd"
)
const OPTIONS_SUMMARY_TEXT := (
	"Accessibility and audio choices are saved for this player "
	+ "and apply immediately."
)

enum TonguePhase {
	HIDDEN,
	EXTENDING,
	HOLDING,
	RETRACTING,
}

enum InteriorTransitionPhase {
	NONE,
	FADE_OUT,
	FADE_IN,
}

const WORLD_RECT := Rect2(-1760, -1360, 3520, 2720)
const GROWTH_THRESHOLDS := GAMEPLAY_TUNING_SCRIPT.GROWTH_THRESHOLDS
const TONGUE_RECOVERY := GAMEPLAY_TUNING_SCRIPT.TONGUE_RECOVERY
const TONGUE_EXTEND_DURATION := 0.09
const TONGUE_HOLD_DURATION := 0.06
const TONGUE_RETRACT_DURATION := 0.12
const TONGUE_COLOR := Color(0.96, 0.42, 0.56, 1.0)
const STRUGGLE_DURATION := GAMEPLAY_TUNING_SCRIPT.STRUGGLE_DURATION
const DAMAGE_COOLDOWN := 1.4
const NIGHT_AUDIO_THRESHOLD := 0.38
const GUIDE_PROFILE_ENTRIES_PER_PAGE := 6
const GUIDE_CLUES_PER_PAGE := 5
const GUIDE_FIELD_ENTRIES_PER_PAGE := 7
const RAIN_START := 0.58
const RAIN_FULL_START := 0.62
const RAIN_FULL_END := 0.74
const RAIN_END := 0.78
const WIND_START := 0.30
const WIND_FULL_START := 0.34
const WIND_FULL_END := 0.42
const WIND_END := 0.46
const KITE_FESTIVAL_START := 0.46
const KITE_FESTIVAL_FULL_START := 0.48
const KITE_FESTIVAL_FULL_END := 0.54
const KITE_FESTIVAL_END := 0.56
const CROWD_START := 0.18
const CROWD_FULL_START := 0.22
const CROWD_FULL_END := 0.50
const CROWD_END := 0.56
const FESTIVAL_START := 0.78
const FESTIVAL_FULL_START := 0.82
const FESTIVAL_FULL_END := 0.12
const FESTIVAL_END := 0.16
const CROWD_HIDE_DURATION := 1.75
const ODDITIES_SHOP_OPEN_START := 0.78
const ODDITIES_SHOP_OPEN_END := 0.18
const MOONLIGHT_MARKET_OPEN_START := 0.30
const MOONLIGHT_MARKET_OPEN_END := 0.58
const CITY_DETOUR_START := 0.62
const CITY_DETOUR_END := 0.74
const CITY_DETOUR_RETRY_DELAY := 1.0
const CITY_DETOUR_ANCHORS := [
	{
		"position": Vector2(0, -900),
		"size": Vector2(220, 48),
	},
	{
		"position": Vector2(-1080, 430),
		"size": Vector2(220, 48),
	},
	{
		"position": Vector2(0, 1080),
		"size": Vector2(220, 48),
	},
]
const SHOP_DOORWAY_CLEARANCE := 8.0
const ROADBLOCK_DEPLOY_DELAY := 3.0
const ROADBLOCK_MIN_DISTANCE := 260.0
const ROADBLOCK_MAX_DISTANCE := 850.0
const ROADBLOCK_ANCHORS := [
	{
		"position": Vector2(0, -900),
		"size": Vector2(360, 52),
		"layout": PrototypeRoadblock.LAYOUT_STRAIGHT,
	},
	{
		"position": Vector2(-1080, -650),
		"size": Vector2(360, 52),
		"layout": PrototypeRoadblock.LAYOUT_STAGGERED,
	},
	{
		"position": Vector2(0, 430),
		"size": Vector2(360, 52),
		"layout": PrototypeRoadblock.LAYOUT_STAGGERED,
	},
	{
		"position": Vector2(-1080, 430),
		"size": Vector2(280, 52),
		"layout": PrototypeRoadblock.LAYOUT_STRAIGHT,
	},
	{
		"position": Vector2(0, 1080),
		"size": Vector2(360, 52),
		"layout": PrototypeRoadblock.LAYOUT_STAGGERED,
	},
	{
		"position": Vector2(-1080, 1100),
		"size": Vector2(280, 52),
		"layout": PrototypeRoadblock.LAYOUT_STRAIGHT,
	},
]
const PURSUIT_TRAP_DEPLOY_DELAY := (
	PrototypePursuer.ANIMAL_CONTROL_TRAP_DEPLOY_DELAY
)
const PURSUIT_TRAP_MIN_DISTANCE := 180.0
const PURSUIT_TRAP_MAX_DISTANCE := 700.0
const PURSUIT_TRAP_ANCHORS := [
	Vector2(-900, -285),
	Vector2(350, -285),
	Vector2(850, 260),
	Vector2(-820, 650),
	Vector2(360, 650),
	Vector2(-900, 1020),
	Vector2(330, 1020),
]
const NET_ESCAPE_DURATION := 3.0
const NET_ESCAPE_TAPS := 6
const TARGET_STRUGGLE_TITLE := "It is trying to escape!"
const TARGET_STRUGGLE_HINT := "Tap rapidly anywhere!"
const CAMERA_AUTO_ALIGN_DELAY := 1.8
const CAMERA_AUTO_ALIGN_SPEED := 2.0
const STOCKROOM_ID := "leap_cafe_stockroom"
const INTERIOR_SPACE_ORIGIN := Vector2(0, 10000000)
const STOCKROOM_POSITION := INTERIOR_SPACE_ORIGIN
const STOCKROOM_CAMERA_ZOOM := Vector2(1.2, 1.2)
const CANAL_UPPER_HALL_ID := "canal_apartments_upper_hall"
const CANAL_UPPER_HALL_POSITION := INTERIOR_SPACE_ORIGIN + Vector2(0, 1200)
const MARKET_ROOFTOP_ID := "moonlight_market_rooftop"
const MARKET_ROOFTOP_POSITION := INTERIOR_SPACE_ORIGIN + Vector2(0, 2400)
const ODDITIES_CELLAR_ID := "oddities_shop_cellar"
const ODDITIES_CELLAR_POSITION := INTERIOR_SPACE_ORIGIN + Vector2(0, 3600)
const CANAL_FIRE_ESCAPE_ID := "canal_apartments_fire_escape"
const CANAL_FIRE_ESCAPE_POSITION := (
	INTERIOR_SPACE_ORIGIN + Vector2(0, 4800)
)
const RIVER_SEWER_JUNCTION_ID := "river_sewer_junction"
const RIVER_SEWER_JUNCTION_POSITION := (
	INTERIOR_SPACE_ORIGIN + Vector2(0, 6400)
)
const RIVER_SUBWAY_TUNNEL_ID := "river_subway_service_tunnel"
const RIVER_SUBWAY_TUNNEL_POSITION := (
	INTERIOR_SPACE_ORIGIN + Vector2(0, 7800)
)
const RIVER_POND_BOARDWALK_ID := "river_park_pond_boardwalk"
const RIVER_POND_BOARDWALK_POSITION := (
	INTERIOR_SPACE_ORIGIN + Vector2(0, 9200)
)
const CONSTRUCTION_CRANE_ID := "construction_crane_deck"
const CONSTRUCTION_CRANE_POSITION := (
	INTERIOR_SPACE_ORIGIN + Vector2(0, 10600)
)
const RIVER_HIDDEN_MAINTENANCE_ID := "river_sewer_hidden_maintenance"
const RIVER_HIDDEN_MAINTENANCE_POSITION := (
	INTERIOR_SPACE_ORIGIN + Vector2(0, 12200)
)
const SECRET_DISTRICT_DESTINATION := "secret_fantasy_district_world"
const SECRET_DISTRICT_RETURN_PORTAL_ID := "secret_star_path_return"
const CITY_EXPLORATION_PORTALS := [
	{
		"id": "construction_crane_lift",
		"label": "construction crane lift",
		"marker_position": Vector2(-1510, -1120),
		"approach_position": Vector2(-1410, -1120),
		"destination": CONSTRUCTION_CRANE_ID,
		"destination_entry_id": "from_lift",
		"min_growth_tier": 1,
		"requirement_text": "Grow once before riding the construction lift.",
	},
	{
		"id": "river_pond_boardwalk",
		"label": "River Park pond boardwalk",
		"marker_position": Vector2(520, 560),
		"approach_position": Vector2(520, 650),
		"destination": RIVER_POND_BOARDWALK_ID,
		"destination_entry_id": "from_park",
	},
	{
		"id": "river_sewer_hatch",
		"label": "River Park sewer hatch",
		"marker_position": Vector2(1050, 550),
		"approach_position": Vector2(980, 550),
		"destination": RIVER_SEWER_JUNCTION_ID,
		"destination_entry_id": "from_city",
	},
]
const INTERIOR_TRANSITION_DURATION := 0.18
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
	"leap_cafe": {
		"ordered": true,
		"parts": [
			{
				"part_id": "sign",
				"id": "leap_cafe_menu_board",
				"name": "Sidewalk Menu Board",
				"value": 36,
				"radius": 32.0,
				"color": Color("f2d28b"),
			},
			{
				"part_id": "counter",
				"id": "leap_cafe_espresso_counter",
				"name": "Rear Espresso Counter",
				"value": 92,
				"tier": 1,
				"radius": 40.0,
				"resistant": true,
				"taps": 9,
				"color": Color("82533f"),
			},
			{
				"part_id": "door",
				"id": "leap_cafe_awning",
				"name": "Front Awning",
				"value": 58,
				"tier": 1,
				"radius": 36.0,
				"color": Color("e8a596"),
			},
		],
		"whole": {
			"id": "leap_cafe_building",
			"name": "Leap Cafe",
			"value": 440,
			"radius": 150.0,
			"taps": 16,
			"color": Color("ca8d77"),
		},
	},
	"canal_apartments": {
		"ordered": true,
		"parts": [
			{
				"part_id": "sign",
				"id": "canal_apartments_address_plaque",
				"name": "Address Plaque",
				"value": 40,
				"radius": 32.0,
				"color": Color("d7e0ef"),
			},
			{
				"part_id": "counter",
				"id": "canal_apartments_lobby_bench",
				"name": "Lobby Bench",
				"value": 94,
				"tier": 1,
				"radius": 38.0,
				"resistant": true,
				"taps": 9,
				"color": Color("637b9f"),
			},
			{
				"part_id": "door",
				"id": "canal_apartments_entry_canopy",
				"name": "Entry Canopy",
				"value": 64,
				"tier": 1,
				"radius": 36.0,
				"color": Color("b8c9e3"),
			},
		],
		"whole": {
			"id": "canal_apartments_building",
			"name": "Canal Apartments",
			"value": 480,
			"radius": 155.0,
			"taps": 17,
			"color": Color("8aa6ce"),
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
@onready var _top_bar: HBoxContainer = $HUD/Root/TopMargin/TopBar
@onready var _profile_slot: Control = $HUD/Root/TopMargin/TopBar/ProfileSlot
@onready var _profile_label: Label = %ProfileLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _growth_label: Label = %GrowthLabel
@onready var _power_label: Label = %PowerLabel
@onready var _guide_button: Button = %GuideButton
@onready var _belly_button: Button = %BellyButton
@onready var _options_button: Button = %OptionsButton
@onready var _end_button: Button = %EndButton
@onready var _top_bar_spacer: Control = $HUD/Root/TopMargin/TopBar/Spacer
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
@onready var _struggle_title: Label = $HUD/Root/StrugglePanel/Margin/Content/Title
@onready var _struggle_hint: Label = $HUD/Root/StrugglePanel/Margin/Content/Hint
@onready var _belly_overlay: Control = %BellyOverlay
@onready var _belly_center: CenterContainer = $HUD/Root/BellyOverlay/Center
@onready var _belly_list: VBoxContainer = %BellyList
@onready var _digest_all_button: Button = %DigestAllButton
@onready var _end_game_belly_button: Button = %EndGameBellyButton
@onready var _close_belly_button: Button = %CloseBellyButton
@onready var _tutorial_marker: TutorialMarker = $World/TutorialMarker
@onready var _tutorial_panel: PanelContainer = %TutorialPanel
@onready var _tutorial_progress: Label = %TutorialProgress
@onready var _tutorial_card_art: TutorialCardArt = %TutorialCardArt
@onready var _tutorial_title: Label = %TutorialTitle
@onready var _tutorial_instruction: Label = %TutorialInstruction
@onready var _skip_tutorial_button: Button = %SkipTutorialButton
@onready var _reward_label: Label = %RewardLabel
@onready var _guide_overlay: Control = %GuideOverlay
@onready var _guide_progress: Label = %GuideProgress
@onready var _guide_scroll: ScrollContainer = (
	$HUD/Root/GuideOverlay/Center/Panel/Margin/Content/Scroll
)
@onready var _guide_list: VBoxContainer = %GuideList
@onready var _previous_guide_page_button: Button = (
	%PreviousGuidePageButton
)
@onready var _guide_page_label: Label = %GuidePageLabel
@onready var _next_guide_page_button: Button = %NextGuidePageButton
@onready var _end_game_guide_button: Button = %EndGameGuideButton
@onready var _close_guide_button: Button = %CloseGuideButton
@onready var _options_overlay: Control = %OptionsOverlay
@onready var _options_center: CenterContainer = $HUD/Root/OptionsOverlay/Center
@onready var _options_summary: Label = (
	$HUD/Root/OptionsOverlay/Center/Panel/Margin/Content/Summary
)
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _larger_ui_toggle: CheckButton = %LargerUiToggle
@onready var _input_assist_option: OptionButton = %InputAssistOption
@onready var _camera_sensitivity_label: Label = %CameraSensitivityLabel
@onready var _camera_sensitivity_slider: HSlider = %CameraSensitivitySlider
@onready var _camera_auto_align_toggle: CheckButton = %CameraAutoAlignToggle
@onready var _haptics_toggle: CheckButton = %HapticsToggle
@onready var _left_handed_toggle: CheckButton = %LeftHandedToggle
@onready var _reset_camera_button: Button = %ResetCameraButton
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
@onready var _interior_transition_fade: ColorRect = %InteriorTransitionFade

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
var _interior_rooms: Dictionary = {}
var _interior_room_building_ids: Dictionary = {}
var _session_seed := 0
var _district_definitions: Dictionary = {}
var _district_states: Dictionary = {}
var _loaded_districts: Dictionary = {}
var _current_district_coordinate := Vector2i.ZERO
var _secret_district_coordinate := Vector2i.ZERO
var _next_session_instance_id := 1
var _pursuer: PrototypePursuer
var _roadblock: PrototypeRoadblock
var _pursuit_trap: PrototypePursuitTrap
var _city_detour: PrototypeCityDetour
var _navigation: DeterministicNavigation2D = NAVIGATION_SCRIPT.new()
var _navigation_dirty := true
var _frog_route_requested_destination := Vector2.INF
var _frog_route_fallback := false

var _tongue_recovery := 0.0
var _tongue_phase := TonguePhase.HIDDEN
var _tongue_phase_time := 0.0
var _tongue_extension := 0.0
var _tongue_retract_start := 0.0
var _tongue_end := Vector2.ZERO
var _struggle_kick := 0.0
var _damage_cooldown := 0.0
var _status_time := 0.0
var _power_state: TemporaryPowerState = POWER_STATE_SCRIPT.new()
var _power_discoveries: Dictionary = {}
var _achievement_model = ACHIEVEMENT_MODEL_SCRIPT.new()
var _story_clues: Dictionary = {}
var _secret_unlocks: Dictionary = {}
var _day_clock := 0.23
var _current_daylight := 0.0
var _current_rain_intensity := 0.0
var _current_wind_intensity := 0.0
var _current_crowd_intensity := 0.0
var _current_kite_festival_intensity := 0.0
var _oddities_shop_scheduled_open := false
var _moonlight_market_scheduled_open := false
var _city_detour_window_active := false
var _city_detour_retry_time := 0.0
var _crowd_hide_time := 0.0
var _roadblock_deploy_time := 0.0
var _roadblock_deployed := false
var _pursuit_trap_deploy_time := 0.0
var _pursuit_trap_deployed := false
var _last_safe_ground_position := Vector2.ZERO
var _rare_respawn_pending: Dictionary = {}
var _pending_growth_tier := -1

var _struggle_target: EdibleTarget
var _struggle_accuracy := 0.0
var _struggle_taps := 0
var _struggle_required_taps := 0
var _struggle_time_left := 0.0
var _struggle_hit_offset := Vector2.ZERO
var _net_escape_active := false
var _net_escape_taps := 0
var _net_escape_required_taps := NET_ESCAPE_TAPS
var _net_escape_time_left := 0.0
var _net_source_position := Vector2.ZERO
var _active_interior_id := ""
var _pending_interior_transition := ""
var _pending_interior_portal_id := ""
var _interior_transition_destination := ""
var _interior_transition_entry_id := "default"
var _interior_transition_source_space := ""
var _interior_transition_source_portal_id := ""
var _interior_transition_phase := InteriorTransitionPhase.NONE
var _interior_transition_time := 0.0
var _city_return_position := Vector2.ZERO
var _city_camera_zoom := Vector2(0.9, 0.9)
var _city_camera_rotation := 0.0
var _city_camera_smoothing_enabled := true
var _pull_target: EdibleTarget
var _pull_time_left := 0.0
var _pull_hit_offset := Vector2.ZERO

var _active_touches: Dictionary = {}
var _camera_gesture := false
var _camera_driver_id := -1
var _mouse_rotating := false
var _ignore_mouse_until_msec := 0
var _last_assisted_tap_msec := -1000
var _last_assisted_tap_position := Vector2.INF
var _hold_tongue_started_msec := 0
var _hold_tongue_position := Vector2.INF
var _assist_hold_active := false
var _assist_hold_elapsed := 0.0
var _assist_hold_pointer_id := -2
var _tutorial: TutorialController
var _tutorial_original_target_states: Dictionary = {}
var _discoveries: Dictionary = {}
var _guide_page_index := 0
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
var _input_assist_mode := AccessibilityPresentation.INPUT_ASSIST_STANDARD
var _camera_sensitivity := 1.0
var _camera_auto_align_enabled := false
var _camera_manual_override_time := 0.0
var _haptics_enabled := false
var _left_handed_hud_enabled := false
var _accessibility_configured := false
var _refreshing_accessibility_controls := false
var _audio_preferences := AudioPreferences.defaults()
var _refreshing_audio_controls := false
var _audio_dragging := false
var _progression_audio_enabled := false
var _tutorial_panel_was_visible_before_options := false
var _performance_instrumentation: CanvasLayer
var _score_epilogue: ScoreEpilogue
var _end_return_requested := false
var _save_warning_panel: PanelContainer
var _save_warning_label: Label
var _save_warning_message := ""
var _safe_area_insets := Vector4.ZERO


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
	_previous_guide_page_button.pressed.connect(
		_on_previous_guide_page
	)
	_next_guide_page_button.pressed.connect(_on_next_guide_page)
	_close_guide_button.pressed.connect(_close_guide)
	_populate_input_assist_options()
	_reduce_motion_toggle.toggled.connect(_on_accessibility_toggled)
	_larger_ui_toggle.toggled.connect(_on_accessibility_toggled)
	_camera_auto_align_toggle.toggled.connect(_on_accessibility_toggled)
	_haptics_toggle.toggled.connect(_on_accessibility_toggled)
	_left_handed_toggle.toggled.connect(_on_accessibility_toggled)
	_input_assist_option.item_selected.connect(
		_on_accessibility_option_selected
	)
	_camera_sensitivity_slider.value_changed.connect(
		_on_camera_sensitivity_changed
	)
	_reset_camera_button.pressed.connect(_reset_camera_orientation)
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
	_sync_progression_portals()
	_current_district_coordinate = DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
	_update_district_streaming(true)
	_refresh_navigation_geometry()
	_city_camera_zoom = _camera.zoom
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
	_status_label.text = _default_status_text()
	_evaluate_persisted_progression()
	_progression_audio_enabled = true
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
	if is_instance_valid(_score_epilogue):
		get_tree().paused = false
	AudioDirector.leave_context(self)


func show_save_error(message: String) -> void:
	_save_warning_message = message
	if message.is_empty():
		_clear_save_warning()
		_update_save_warning_surfaces()
		return
	if not is_instance_valid(_save_warning_panel):
		_create_save_warning()
	_save_warning_label.text = "SAVE WARNING: %s" % message
	_apply_save_warning_layout()
	_update_save_warning_surfaces()


func _create_save_warning() -> void:
	_save_warning_panel = PanelContainer.new()
	_save_warning_panel.name = "SaveWarning"
	_save_warning_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_warning_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_warning_panel.z_index = 30
	var panel_style := _status_panel.get_theme_stylebox("panel")
	if panel_style != null:
		_save_warning_panel.add_theme_stylebox_override("panel", panel_style)

	_save_warning_label = Label.new()
	_save_warning_label.name = "SaveWarningLabel"
	_save_warning_label.custom_minimum_size = Vector2(0.0, 76.0)
	_save_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_warning_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.82, 0.35)
	)
	_save_warning_label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.9)
	)
	_save_warning_label.add_theme_constant_override("outline_size", 3)
	_save_warning_label.add_theme_font_size_override("font_size", 18)
	_save_warning_panel.add_child(_save_warning_label)
	$HUD/Root.add_child(_save_warning_panel)
	AccessibilityPresentation.apply(
		_save_warning_panel,
		_larger_text_controls_enabled
	)


func _clear_save_warning() -> void:
	if is_instance_valid(_save_warning_panel):
		_save_warning_panel.queue_free()
	_save_warning_panel = null
	_save_warning_label = null


func _update_save_warning_surfaces() -> void:
	_options_summary.text = (
		OPTIONS_SUMMARY_TEXT
		if _save_warning_message.is_empty()
		else "SAVE WARNING: %s\n%s" % [
			_save_warning_message,
			OPTIONS_SUMMARY_TEXT,
		]
	)
	if is_instance_valid(_score_epilogue):
		_score_epilogue.set_save_warning(_save_warning_message)
	if is_instance_valid(_save_warning_panel):
		_save_warning_panel.visible = (
			not _options_overlay.visible
			and not _belly_overlay.visible
			and not _guide_overlay.visible
			and not is_instance_valid(_score_epilogue)
		)


func _apply_save_warning_layout() -> void:
	if not is_instance_valid(_save_warning_panel):
		return
	var viewport_width := get_viewport_rect().size.x
	var left := maxf(0.0, _safe_area_insets.x)
	var top := maxf(0.0, _safe_area_insets.y)
	var right := maxf(0.0, _safe_area_insets.z)
	var safe_width := maxf(0.0, viewport_width - left - right)
	var center_x := left + safe_width * 0.5
	var half_width := minf(330.0, maxf(220.0, (safe_width - 48.0) * 0.5))
	_save_warning_panel.anchor_left = 0.0
	_save_warning_panel.anchor_top = 0.0
	_save_warning_panel.anchor_right = 0.0
	_save_warning_panel.anchor_bottom = 0.0
	_save_warning_panel.offset_left = center_x - half_width
	_save_warning_panel.offset_top = 230.0 + top
	_save_warning_panel.offset_right = center_x + half_width
	_save_warning_panel.offset_bottom = 306.0 + top


func configure(
	profile_id: String,
	display_name: String,
	tutorial_required: bool,
	discovered_ids: PackedStringArray = PackedStringArray(),
	accessibility_preferences: Dictionary = {},
	audio_preferences: Dictionary = {},
	session_seed: int = 0,
	power_discoveries: PackedStringArray = PackedStringArray(),
	profile_achievements: PackedStringArray = PackedStringArray(),
	device_achievements: PackedStringArray = PackedStringArray(),
	story_clues: PackedStringArray = PackedStringArray(),
	secret_unlocks: PackedStringArray = PackedStringArray()
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
		_input_assist_mode = str(sanitized["input_assist_mode"])
		_camera_sensitivity = float(sanitized["camera_sensitivity"])
		_camera_auto_align_enabled = bool(sanitized["camera_auto_align"])
		_haptics_enabled = bool(sanitized["haptics_enabled"])
		_left_handed_hud_enabled = bool(sanitized["left_handed_hud"])
		_accessibility_configured = true
	if not audio_preferences.is_empty():
		_audio_preferences = AudioPreferences.sanitize_preferences(
			audio_preferences
		)
	_power_discoveries.clear()
	for power_id in power_discoveries:
		var normalized_id := str(power_id).strip_edges()
		if not ProgressionCatalog.power_entry(normalized_id).is_empty():
			_power_discoveries[normalized_id] = true
	_achievement_model.configure(
		profile_achievements,
		device_achievements
	)
	_story_clues.clear()
	for clue_id in story_clues:
		var normalized_id := str(clue_id).strip_edges()
		if not ProgressionCatalog.story_clue_entry(normalized_id).is_empty():
			_story_clues[normalized_id] = true
	_secret_unlocks.clear()
	for secret_id in secret_unlocks:
		var normalized_id := str(secret_id).strip_edges()
		if ProgressionCatalog.secret_unlock_ids().has(normalized_id):
			_secret_unlocks[normalized_id] = true
	_session_seed = (
		session_seed
		if session_seed != 0
		else _create_session_seed(profile_id)
	)
	_secret_district_coordinate = (
		DISTRICT_GENERATOR_SCRIPT.secret_coordinate(_session_seed)
	)
	_configured = true


func _create_session_seed(profile_id: String) -> int:
	var entropy := "%s:%d:%d" % [
		profile_id,
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
	]
	return maxi(1, absi(entropy.hash()))


func _update_district_streaming(force: bool = false) -> void:
	if not _active_interior_id.is_empty():
		return
	var next_coordinate := DISTRICT_GENERATOR_SCRIPT.coordinate_for_position(
		_frog.global_position
	)
	var coordinate_changed := (
		next_coordinate != _current_district_coordinate
	)
	_current_district_coordinate = next_coordinate
	var desired := _desired_generated_districts(
		next_coordinate,
		_frog.global_position
	)
	for coordinate_value in desired:
		var coordinate := coordinate_value as Vector2i
		if not _loaded_districts.has(coordinate):
			_load_generated_district(coordinate)
	for coordinate_value in _loaded_districts.keys().duplicate():
		var coordinate := coordinate_value as Vector2i
		if not desired.has(coordinate):
			_unload_generated_district(coordinate)
	if _is_secret_district_coordinate(_current_district_coordinate):
		_record_secret_district_entered()
	if coordinate_changed and not force:
		_clear_roadblock()
		_clear_pursuit_trap()
		_clear_city_detour()


func _desired_generated_districts(
	current: Vector2i,
	frog_position: Vector2
) -> Dictionary:
	var desired := {}
	if current != DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE:
		for x_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				var coordinate := current + Vector2i(x_offset, y_offset)
				if coordinate != DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE:
					desired[coordinate] = true
		return desired

	var bounds := DISTRICT_GENERATOR_SCRIPT.CORE_BOUNDS
	var near_west := (
		frog_position.x - bounds.position.x
		<= DISTRICT_GENERATOR_SCRIPT.STREAM_MARGIN
	)
	var near_east := (
		bounds.end.x - frog_position.x
		<= DISTRICT_GENERATOR_SCRIPT.STREAM_MARGIN
	)
	var near_north := (
		frog_position.y - bounds.position.y
		<= DISTRICT_GENERATOR_SCRIPT.STREAM_MARGIN
	)
	var near_south := (
		bounds.end.y - frog_position.y
		<= DISTRICT_GENERATOR_SCRIPT.STREAM_MARGIN
	)
	if near_west:
		desired[Vector2i(-1, 0)] = true
	if near_east:
		desired[Vector2i(1, 0)] = true
	if near_north:
		desired[Vector2i(0, -1)] = true
	if near_south:
		desired[Vector2i(0, 1)] = true
	if near_west and near_north:
		desired[Vector2i(-1, -1)] = true
	if near_west and near_south:
		desired[Vector2i(-1, 1)] = true
	if near_east and near_north:
		desired[Vector2i(1, -1)] = true
	if near_east and near_south:
		desired[Vector2i(1, 1)] = true
	return desired


func _load_generated_district(coordinate: Vector2i) -> void:
	if (
		coordinate == DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
		or _loaded_districts.has(coordinate)
	):
		return
	var definition := _district_definition(coordinate)
	var root := GENERATED_DISTRICT_SCRIPT.new() as GeneratedDistrict
	root.configure(definition)
	root.set_meta("district_coordinate", coordinate)
	_world.add_child(root)
	_loaded_districts[coordinate] = root

	var state := _district_states.get(
		_district_key(coordinate),
		_new_district_state()
	) as Dictionary
	var spawned_instances := {}
	for index in definition.buildings.size():
		var building_data := definition.buildings[index] as Dictionary
		var building_id := "%s_building_%d" % [
			definition.district_id,
			index,
		]
		var building := _spawn_building(
			building_data["position"] as Vector2,
			building_data["size"] as Vector2,
			str(building_data["name"]),
			str(building_data["door_side"]),
			building_data["color"] as Color,
			building_id,
			true,
			building_data["counter_position"] as Vector2,
			[],
			PrototypeBuilding.ENTRANCE_PART_AWNING,
			building_data["counter_size"] as Vector2,
			root
		)
		building.set_meta("district_coordinate", coordinate)
		_apply_generated_building_state(building, state)
		_spawn_generated_building_targets(
			building,
			coordinate,
			root,
			state,
			spawned_instances
		)

	for target_data_value in definition.targets:
		_spawn_generated_target(
			target_data_value as Dictionary,
			coordinate,
			root,
			state,
			spawned_instances
		)
	var target_states := state["target_states"] as Dictionary
	var removed_targets := state["removed_targets"] as Dictionary
	for instance_id_value in target_states:
		var instance_id := str(instance_id_value)
		if (
			spawned_instances.has(instance_id)
			or removed_targets.has(instance_id)
		):
			continue
		_spawn_generated_target(
			target_states[instance_id] as Dictionary,
			coordinate,
			root,
			state,
			spawned_instances
		)
	_invalidate_navigation()


func _unload_generated_district(coordinate: Vector2i) -> void:
	var root := _loaded_districts.get(coordinate) as GeneratedDistrict
	if not is_instance_valid(root):
		_loaded_districts.erase(coordinate)
		return
	var key := _district_key(coordinate)
	var state := _district_states.get(
		key,
		_new_district_state()
	) as Dictionary
	_district_states[key] = state
	var target_states := {}
	for target in _targets.duplicate():
		if (
			is_instance_valid(target)
			and target.district_coordinate == coordinate
			and not target.world_instance_id.is_empty()
		):
			if target.world_state_dirty:
				target_states[target.world_instance_id] = _serialize_target(
					target
				)
			_targets.erase(target)
	state["target_states"] = target_states
	for building in _buildings.duplicate():
		if (
			is_instance_valid(building)
			and building.has_meta("district_coordinate")
			and building.get_meta("district_coordinate") == coordinate
		):
			_capture_generated_building_state(building)
			_buildings.erase(building)
			_building_by_id.erase(building.building_id)
	if _district_state_is_empty(state):
		_district_states.erase(key)
	else:
		_district_states[key] = state
	_district_definitions.erase(key)
	_loaded_districts.erase(coordinate)
	root.queue_free()
	_invalidate_navigation()


func _district_definition(coordinate: Vector2i) -> DistrictDefinition:
	var key := _district_key(coordinate)
	if not _district_definitions.has(key):
		_district_definitions[key] = (
			DISTRICT_GENERATOR_SCRIPT.generate_secret(
				_session_seed,
				coordinate
			)
			if _is_secret_district_coordinate(coordinate)
			else (
				DISTRICT_GENERATOR_SCRIPT.generate_reserved(
					_session_seed,
					coordinate
				)
				if coordinate == _secret_district_coordinate
				else DISTRICT_GENERATOR_SCRIPT.generate(
					_session_seed,
					coordinate
				)
			)
		)
	return _district_definitions[key] as DistrictDefinition


func _district_state(coordinate: Vector2i) -> Dictionary:
	var key := _district_key(coordinate)
	if not _district_states.has(key):
		_district_states[key] = _new_district_state()
	return _district_states[key] as Dictionary


func _new_district_state() -> Dictionary:
	return {
		"removed_targets": {},
		"target_states": {},
		"building_states": {},
	}


func _district_state_is_empty(state: Dictionary) -> bool:
	return (
		(state["removed_targets"] as Dictionary).is_empty()
		and (state["target_states"] as Dictionary).is_empty()
		and (state["building_states"] as Dictionary).is_empty()
	)


func _district_key(coordinate: Vector2i) -> String:
	return "%d,%d" % [coordinate.x, coordinate.y]


func _apply_generated_building_state(
	building: PrototypeBuilding,
	state: Dictionary
) -> void:
	var building_states := state["building_states"] as Dictionary
	var building_state := (
		building_states.get(building.building_id, {}) as Dictionary
	)
	var removed_parts := (
		building_state.get("removed_parts", {}) as Dictionary
	)
	for part_id in [
		PrototypeBuilding.PART_SIGN,
		PrototypeBuilding.PART_DOOR,
		PrototypeBuilding.PART_COUNTER,
	]:
		if bool(removed_parts.get(part_id, false)):
			building.remove_part(part_id)
	if bool(building_state.get("consumed", false)):
		building.consume()


func _spawn_generated_building_targets(
	building: PrototypeBuilding,
	coordinate: Vector2i,
	parent: Node,
	state: Dictionary,
	spawned_instances: Dictionary
) -> void:
	var part_definitions := [
		{
			"part_id": PrototypeBuilding.PART_SIGN,
			"id": "generated_building_sign",
			"name": "%s Sign" % building.display_name,
			"value": 38,
			"radius": 31.0,
			"color": building.floor_color.lightened(0.26),
		},
		{
			"part_id": PrototypeBuilding.PART_DOOR,
			"id": "generated_building_awning",
			"name": "%s Awning" % building.display_name,
			"value": 58,
			"tier": 1,
			"radius": 35.0,
			"color": building.floor_color.lightened(0.18),
		},
		{
			"part_id": PrototypeBuilding.PART_COUNTER,
			"id": "generated_building_fixture",
			"name": "%s Fixture" % building.display_name,
			"value": 82,
			"tier": 1,
			"radius": 39.0,
			"resistant": true,
			"taps": 8,
			"color": building.floor_color.darkened(0.16),
		},
	]
	for part_value in part_definitions:
		var part := (part_value as Dictionary).duplicate(true)
		var part_id := str(part["part_id"])
		var instance_id := "%s_%s" % [building.building_id, part_id]
		if building.is_part_removed(part_id):
			continue
		part.erase("part_id")
		part["instance_id"] = instance_id
		part["position"] = building.part_world_position(part_id)
		part["kind"] = "building_part"
		part["restockable"] = false
		part["building_id"] = building.building_id
		part["building_part_id"] = part_id
		_spawn_generated_target(
			part,
			coordinate,
			parent,
			state,
			spawned_instances
		)

	var whole_instance_id := "%s_whole" % building.building_id
	if building.consumed:
		return
	_spawn_generated_target(
		{
			"instance_id": whole_instance_id,
			"id": "generated_building",
			"name": building.display_name,
			"position": building.global_position,
			"value": 430,
			"tier": 2,
			"kind": "building",
			"radius": 150.0,
			"resistant": true,
			"taps": 15,
			"color": building.floor_color,
			"restockable": false,
			"building_id": building.building_id,
			"hidden": not building.is_ready_to_swallow(),
			"selectable": building.is_ready_to_swallow(),
		},
		coordinate,
		parent,
		state,
		spawned_instances
	)


func _spawn_generated_target(
	data: Dictionary,
	coordinate: Vector2i,
	parent: Node,
	state: Dictionary,
	spawned_instances: Dictionary
) -> EdibleTarget:
	var instance_id := str(data.get("instance_id", ""))
	if instance_id.is_empty():
		push_error("Generated target is missing a world instance ID.")
		return null
	var removed_targets := state["removed_targets"] as Dictionary
	if removed_targets.has(instance_id):
		return null
	var target_data := data.duplicate(true)
	var target_states := state["target_states"] as Dictionary
	if target_states.has(instance_id):
		target_data.merge(
			target_states[instance_id] as Dictionary,
			true
		)
	target_data["world_instance_id"] = instance_id
	target_data["district_coordinate"] = coordinate
	target_data["bounds"] = target_data.get(
		"bounds",
		_district_definition(coordinate).bounds.grow(-100.0)
	)
	target_data["motion_seed"] = int(target_data.get(
		"motion_seed",
		DISTRICT_GENERATOR_SCRIPT.seed_for_coordinate(
			_session_seed + instance_id.hash(),
			coordinate
		)
	))
	var target := _spawn_target(target_data, parent)
	spawned_instances[instance_id] = true
	return target


func _capture_generated_building_state(
	building: PrototypeBuilding
) -> void:
	if (
		not is_instance_valid(building)
		or not building.has_meta("district_coordinate")
	):
		return
	var coordinate := building.get_meta("district_coordinate") as Vector2i
	var removed_parts := {
		PrototypeBuilding.PART_SIGN: building.is_part_removed(
			PrototypeBuilding.PART_SIGN
		),
		PrototypeBuilding.PART_DOOR: building.is_part_removed(
			PrototypeBuilding.PART_DOOR
		),
		PrototypeBuilding.PART_COUNTER: building.is_part_removed(
			PrototypeBuilding.PART_COUNTER
		),
	}
	var changed := building.consumed
	for removed in removed_parts.values():
		if bool(removed):
			changed = true
	if changed:
		var state := _district_state(coordinate)
		var building_states := state["building_states"] as Dictionary
		building_states[building.building_id] = {
			"consumed": building.consumed,
			"removed_parts": removed_parts,
		}
		return
	var key := _district_key(coordinate)
	if _district_states.has(key):
		var state := _district_states[key] as Dictionary
		var building_states := state["building_states"] as Dictionary
		building_states.erase(building.building_id)


func _mark_generated_target_removed(target: EdibleTarget) -> void:
	if target.world_instance_id.is_empty():
		return
	var state := _district_state(target.district_coordinate)
	var removed_targets := state["removed_targets"] as Dictionary
	var target_states := state["target_states"] as Dictionary
	removed_targets[target.world_instance_id] = true
	target_states.erase(target.world_instance_id)


func _mark_generated_target_present(target: EdibleTarget) -> void:
	if target.world_instance_id.is_empty():
		return
	var state := _district_state(target.district_coordinate)
	var removed_targets := state["removed_targets"] as Dictionary
	var target_states := state["target_states"] as Dictionary
	removed_targets.erase(target.world_instance_id)
	target.world_state_dirty = true
	target_states[target.world_instance_id] = _serialize_target(target)


func _serialize_target(target: EdibleTarget) -> Dictionary:
	return {
		"instance_id": target.world_instance_id,
		"id": target.target_id,
		"name": target.display_name,
		"position": target.global_position,
		"value": target.base_value,
		"tier": target.size_tier,
		"kind": target.kind,
		"rare": target.rare,
		"resistant": target.resistant,
		"taps": target.taps_required,
		"radius": target.pick_radius,
		"velocity": target.velocity,
		"unpredictable": target.unpredictable,
		"bounds": target.move_bounds,
		"dangerous": target.dangerous_location,
		"color": target.target_color,
		"restockable": target.restockable,
		"building_id": target.building_id,
		"building_part_id": target.building_part_id,
		"selectable": target.selectable,
		"hidden": not target.visible,
		"world_instance_id": target.world_instance_id,
		"district_coordinate": target.district_coordinate,
		"motion_seed": target.motion_seed,
		"world_state_dirty": target.world_state_dirty,
	}


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
			_status_label.text = _default_status_text()

	if _interior_transition_phase != InteriorTransitionPhase.NONE:
		_update_interior_transition(delta)
		_update_camera()
		_camera.offset = Vector2.ZERO
		return

	if get_tree().paused:
		_update_camera()
		_camera.offset = Vector2.ZERO
		return

	_tongue_recovery = maxf(0.0, _tongue_recovery - delta)
	_damage_cooldown = maxf(0.0, _damage_cooldown - delta)
	_update_powers(delta)
	_update_day_night(delta)
	_retry_pending_growth()

	if is_instance_valid(_struggle_target):
		_struggle_time_left -= delta
		if _struggle_time_left <= 0.0:
			_fail_struggle()
	if _net_escape_active:
		_update_net_escape(delta)
	_update_input_assistance(delta)
	_update_crowd_hiding(delta)
	_update_city_detour(delta)
	_update_pursuit_roadblock(delta)
	_update_pursuit_trap(delta)
	_update_district_streaming()
	_update_navigation_paths()

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
			_cancel_frog_navigation()
			_frog.move_to(pull_end)

	_update_camera_assistance(delta)
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
	if (
		_overlay_blocking()
		or _interior_transition_phase != InteriorTransitionPhase.NONE
	):
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
		if _net_escape_active:
			_register_net_escape_tap()
			_begin_assisted_hold(event.index)
			_active_touches[event.index] = {"blocked": true}
			return
		if is_instance_valid(_struggle_target):
			_register_struggle_tap()
			_begin_assisted_hold(event.index)
			_active_touches[event.index] = {"blocked": true}
			return

		_active_touches[event.index] = {
			"position": event.position,
			"start_position": event.position,
			"blocked": false,
			"pressed_msec": Time.get_ticks_msec(),
			"hold_tongue": (
				_input_assist_mode
				== AccessibilityPresentation.INPUT_ASSIST_HOLD
				and _screen_position_has_target(event.position)
			),
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
	if event.index == _assist_hold_pointer_id:
		_end_assisted_hold()
	if (
		not touch_data.is_empty()
		and not bool(touch_data.get("blocked", true))
		and not event.canceled
	):
		var held_for_msec := (
			Time.get_ticks_msec()
			- int(touch_data.get("pressed_msec", Time.get_ticks_msec()))
		)
		var touch_start := touch_data.get(
			"start_position",
			event.position
		) as Vector2
		if (
			bool(touch_data.get("hold_tongue", false))
			and held_for_msec
			>= AccessibilityPresentation.HOLD_TONGUE_DELAY_MSEC
			and event.position.distance_to(touch_start) <= 40.0
		):
			_try_tongue_at_screen(touch_start)
		elif _is_relaxed_double_tap(event.position):
			_try_tongue_at_screen(event.position)
			_last_assisted_tap_msec = -1000
			_last_assisted_tap_position = Vector2.INF
		else:
			_record_assisted_tap(event.position)
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
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		if _assist_hold_pointer_id == -1:
			_end_assisted_hold()
		if (
			_input_assist_mode
			== AccessibilityPresentation.INPUT_ASSIST_HOLD
			and _hold_tongue_position != Vector2.INF
		):
			var hold_position := _hold_tongue_position
			var held_long_enough := (
				Time.get_ticks_msec() - _hold_tongue_started_msec
				>= AccessibilityPresentation.HOLD_TONGUE_DELAY_MSEC
			)
			_hold_tongue_position = Vector2.INF
			if (
				held_long_enough
				and event.position.distance_to(hold_position) <= 40.0
			):
				_try_tongue_at_screen(hold_position)
			else:
				_handle_world_tap(event.position)
		return

	if _net_escape_active:
		_register_net_escape_tap()
		_begin_assisted_hold(-1)
	elif is_instance_valid(_struggle_target):
		_register_struggle_tap()
		_begin_assisted_hold(-1)
	elif event.double_click or _is_relaxed_double_tap(event.position):
		_last_assisted_tap_msec = -1000
		_last_assisted_tap_position = Vector2.INF
		_try_tongue_at_screen(event.position)
	elif (
		_input_assist_mode == AccessibilityPresentation.INPUT_ASSIST_HOLD
		and _screen_position_has_target(event.position)
	):
		_hold_tongue_started_msec = Time.get_ticks_msec()
		_hold_tongue_position = event.position
	else:
		_record_assisted_tap(event.position)
		_handle_world_tap(event.position)


func _screen_position_has_target(screen_position: Vector2) -> bool:
	var world_position := _screen_to_world(screen_position)
	return (
		_find_target_at(world_position) != null
		or (
			is_instance_valid(_pursuer)
			and _pursuer.hit_test(world_position)
		)
	)


func _is_relaxed_double_tap(screen_position: Vector2) -> bool:
	if (
		_input_assist_mode
		!= AccessibilityPresentation.INPUT_ASSIST_RELAXED
		or not _screen_position_has_target(screen_position)
	):
		return false
	return (
		Time.get_ticks_msec() - _last_assisted_tap_msec
		<= AccessibilityPresentation.RELAXED_DOUBLE_TAP_WINDOW_MSEC
		and screen_position.distance_to(_last_assisted_tap_position) <= 72.0
	)


func _record_assisted_tap(screen_position: Vector2) -> void:
	if (
		_input_assist_mode
		!= AccessibilityPresentation.INPUT_ASSIST_RELAXED
		or not _screen_position_has_target(screen_position)
	):
		return
	_last_assisted_tap_msec = Time.get_ticks_msec()
	_last_assisted_tap_position = screen_position


func _begin_assisted_hold(pointer_id: int) -> void:
	if _input_assist_mode != AccessibilityPresentation.INPUT_ASSIST_HOLD:
		return
	if _assist_hold_active:
		return
	_assist_hold_active = true
	_assist_hold_elapsed = 0.0
	_assist_hold_pointer_id = pointer_id


func _end_assisted_hold() -> void:
	_assist_hold_active = false
	_assist_hold_elapsed = 0.0
	_assist_hold_pointer_id = -2


func _update_input_assistance(delta: float) -> void:
	if (
		not _assist_hold_active
		or _input_assist_mode
		!= AccessibilityPresentation.INPUT_ASSIST_HOLD
	):
		return
	_assist_hold_elapsed += delta
	while (
		_assist_hold_elapsed
		>= AccessibilityPresentation.HOLD_REPEAT_INTERVAL
	):
		_assist_hold_elapsed -= AccessibilityPresentation.HOLD_REPEAT_INTERVAL
		if _net_escape_active:
			_register_net_escape_tap()
		elif is_instance_valid(_struggle_target):
			_register_struggle_tap()
		else:
			_end_assisted_hold()
			break


func _handle_world_tap(screen_position: Vector2) -> void:
	if _net_escape_active:
		_show_status("Tap rapidly anywhere to break free from the net!")
		return
	if is_instance_valid(_pull_target):
		_show_status("The tongue is pulling the frog right now.")
		return
	var world_position := _screen_to_world(screen_position)
	if _try_handle_interior_transition_tap(world_position):
		return
	_pending_interior_transition = ""
	_pending_interior_portal_id = ""
	if _find_target_at(world_position) != null:
		_show_status(
			"Hold that target to shoot your tongue."
			if (
				_input_assist_mode
				== AccessibilityPresentation.INPUT_ASSIST_HOLD
			)
			else "Double-tap that target to shoot your tongue."
		)
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
	_request_frog_navigation(movement_destination)


func _try_handle_interior_transition_tap(world_position: Vector2) -> bool:
	if (
		is_instance_valid(_struggle_target)
		or is_instance_valid(_pull_target)
		or _net_escape_active
	):
		return false
	if not _active_interior_id.is_empty():
		var active_room := (
			_interior_rooms.get(_active_interior_id) as PrototypeInteriorRoom
		)
		if not is_instance_valid(active_room):
			return false
		var portal := active_room.portal_at(world_position)
		if portal.is_empty():
			return false
		var requirement := _interior_portal_requirement(portal)
		if not requirement.is_empty():
			_show_status(requirement)
			return true
		var destination := str(portal.get("destination", ""))
		var portal_id := str(portal.get("id", ""))
		var approach_position := active_room.portal_approach_position(portal)
		if _frog.global_position.distance_to(
			approach_position
		) <= 130.0:
			_begin_interior_transition(destination, portal_id)
		else:
			var route := _request_frog_navigation(
				approach_position,
				false,
				false
			)
			if bool(route["reachable"]):
				_pending_interior_transition = destination
				_pending_interior_portal_id = portal_id
				_show_status(
					"Moving to the %s passage."
					% active_room.display_name
				)
			else:
				_pending_interior_transition = ""
				_pending_interior_portal_id = ""
				_show_status("No safe route reaches that exit.")
		return true

	var building := _transition_building_at(world_position)
	var city_portal := {}
	if not is_instance_valid(building):
		city_portal = _city_portal_at(world_position)
	if not is_instance_valid(building) and city_portal.is_empty():
		return false
	if _tutorial != null and _tutorial.active:
		_show_status("Finish or skip the tutorial before exploring another room.")
		return true
	if not city_portal.is_empty():
		var portal_requirement := _interior_portal_requirement(city_portal)
		if not portal_requirement.is_empty():
			_show_status(portal_requirement)
			return true
		var portal_destination := str(city_portal.get("destination", ""))
		var portal_id := str(city_portal.get("id", ""))
		var portal_approach := (
			city_portal.get("approach_position", Vector2.INF) as Vector2
		)
		if _frog.global_position.distance_to(portal_approach) <= 130.0:
			_begin_interior_transition(portal_destination, portal_id)
		else:
			var route := _request_frog_navigation(
				portal_approach,
				false,
				false
			)
			if bool(route["reachable"]):
				_pending_interior_transition = portal_destination
				_pending_interior_portal_id = portal_id
				_show_status(
					"Moving to the %s."
					% str(city_portal.get("label", "entrance"))
				)
			else:
				_pending_interior_transition = ""
				_pending_interior_portal_id = ""
				_show_status("No safe route reaches that entrance.")
		return true
	if not building.contains_world_point(_frog.global_position):
		_show_status(
			"Enter %s before using its %s."
			% [building.display_name, building.transition_door_label.to_lower()]
		)
		return true
	var requirement := _interior_transition_requirement(building)
	if not requirement.is_empty():
		_show_status(requirement)
		return true
	var destination := building.transition_room_id
	var approach_position := building.transition_door_approach_position()
	if _frog.global_position.distance_to(approach_position) <= 130.0:
		_begin_interior_transition(destination)
	else:
		var route := _request_frog_navigation(
			approach_position,
			false,
			false
		)
		if bool(route["reachable"]):
			_pending_interior_transition = destination
			_pending_interior_portal_id = ""
			_show_status("Moving to the %s entrance." % building.display_name)
		else:
			_pending_interior_transition = ""
			_pending_interior_portal_id = ""
			_show_status("No safe route reaches that entrance.")
	return true


func _transition_building_at(world_position: Vector2) -> PrototypeBuilding:
	for building in _buildings:
		if (
			not building.transition_room_id.is_empty()
			and building.transition_door_hit_test(world_position)
		):
			return building
	return null


func _city_portal_at(world_position: Vector2) -> Dictionary:
	for portal_value in _available_city_portals():
		var portal := portal_value as Dictionary
		var district_coordinate := (
			portal.get(
				"district_coordinate",
				DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
			) as Vector2i
		)
		if district_coordinate != _current_district_coordinate:
			continue
		var marker_position := (
			portal.get("marker_position", Vector2.INF) as Vector2
		)
		if marker_position.distance_to(world_position) <= 62.0:
			return portal
	return {}


func _city_portal_by_id(portal_id: String) -> Dictionary:
	for portal_value in _available_city_portals():
		var portal := portal_value as Dictionary
		if str(portal.get("id", "")) == portal_id:
			return portal
	return {}


func _available_city_portals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for portal_value in CITY_EXPLORATION_PORTALS:
		var portal := (portal_value as Dictionary).duplicate(true)
		portal["district_coordinate"] = (
			DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
		)
		result.append(portal)
	if _secret_unlocks.has(ProgressionCatalog.SECRET_FANTASY_DISTRICT):
		result.append({
			"id": SECRET_DISTRICT_RETURN_PORTAL_ID,
			"label": "star path",
			"marker_position": (
				DISTRICT_GENERATOR_SCRIPT.secret_portal_marker_position(
					_secret_district_coordinate
				)
			),
			"approach_position": (
				DISTRICT_GENERATOR_SCRIPT.secret_portal_approach_position(
					_secret_district_coordinate
				)
			),
			"destination": RIVER_HIDDEN_MAINTENANCE_ID,
			"destination_entry_id": "from_secret",
			"district_coordinate": _secret_district_coordinate,
			"preserve_city_return": true,
		})
	return result


func _building_for_interior_room(room_id: String) -> PrototypeBuilding:
	var building_id := str(_interior_room_building_ids.get(room_id, ""))
	return _building_by_id.get(building_id) as PrototypeBuilding


func _interior_transition_requirement(
	building: PrototypeBuilding
) -> String:
	if _growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER:
		return (
			"The enormous frog cannot fit through %s's %s."
			% [building.display_name, building.transition_door_label.to_lower()]
		)
	if _growth_tier < building.transition_min_growth_tier:
		return (
			"Grow once before using %s's %s."
			% [building.display_name, building.transition_door_label.to_lower()]
		)
	if (
		not building.transition_required_removed_part.is_empty()
		and not building.is_part_removed(
			building.transition_required_removed_part
		)
	):
		var part_label := building.transition_required_part_label
		if part_label.is_empty():
			part_label = "required fixture"
		return (
			"Remove the %s before using %s's %s."
			% [
				part_label,
				building.display_name,
				building.transition_door_label.to_lower(),
			]
		)
	return ""


func _interior_portal_requirement(portal: Dictionary) -> String:
	var requirement_text := str(portal.get("requirement_text", ""))
	var destination := str(portal.get("destination", ""))
	if (
		_active_interior_id.is_empty()
		and _growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
		and _interior_rooms.has(destination)
	):
		return "The enormous frog cannot fit through this entrance."
	if _growth_tier < int(portal.get("min_growth_tier", 0)):
		return (
			requirement_text
			if not requirement_text.is_empty()
			else "Grow before using this passage."
		)
	var required_discovery_id := str(
		portal.get("required_discovery_id", "")
	)
	if (
		not required_discovery_id.is_empty()
		and not _discoveries.has(required_discovery_id)
	):
		return (
			requirement_text
			if not requirement_text.is_empty()
			else "Explore this area further before using that passage."
		)
	var required_building_id := str(
		portal.get("required_building_id", "")
	)
	if required_building_id.is_empty():
		return ""
	var building := (
		_building_by_id.get(required_building_id) as PrototypeBuilding
	)
	if not is_instance_valid(building):
		return "That passage is unavailable."
	var required_removed_part := str(
		portal.get("required_removed_part", "")
	)
	if (
		not required_removed_part.is_empty()
		and not building.is_part_removed(required_removed_part)
	):
		return (
			requirement_text
			if not requirement_text.is_empty()
			else "Remove the blocking fixture before using that passage."
		)
	if building.weakness_count() < int(portal.get("required_weakness", 0)):
		return (
			requirement_text
			if not requirement_text.is_empty()
			else "Weaken the connected building before using that passage."
		)
	return ""


func _begin_interior_transition(
	destination: String,
	source_portal_id: String = ""
) -> void:
	if _interior_transition_phase != InteriorTransitionPhase.NONE:
		return
	var source_space := _active_interior_id
	var destination_entry_id := "default"
	if not source_space.is_empty():
		var source_room := (
			_interior_rooms.get(source_space) as PrototypeInteriorRoom
		)
		if not is_instance_valid(source_room):
			return
		var portal := (
			source_room.portal_by_id(source_portal_id)
			if not source_portal_id.is_empty()
			else source_room.portal_to_destination(destination)
		)
		if (
			portal.is_empty()
			or not bool(portal.get("visible", true))
			or str(portal.get("destination", "")) != destination
		):
			_show_status("That passage is not accessible from here.")
			return
		var portal_requirement := _interior_portal_requirement(portal)
		if not portal_requirement.is_empty():
			_show_status(portal_requirement)
			return
		destination_entry_id = str(
			portal.get("destination_entry_id", "default")
		)
	elif destination == "city":
		return
	elif _interior_rooms.has(destination):
		if not source_portal_id.is_empty():
			var city_portal := _city_portal_by_id(source_portal_id)
			var portal_approach := (
				city_portal.get("approach_position", Vector2.INF)
				as Vector2
			)
			var portal_coordinate := (
				city_portal.get(
					"district_coordinate",
					DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
				) as Vector2i
			)
			if (
				city_portal.is_empty()
				or str(city_portal.get("destination", "")) != destination
				or _current_district_coordinate != portal_coordinate
				or _frog.global_position.distance_to(portal_approach)
				> 130.0
			):
				_show_status("That entrance is not accessible from here.")
				return
			var portal_requirement := _interior_portal_requirement(
				city_portal
			)
			if not portal_requirement.is_empty():
				_show_status(portal_requirement)
				return
			destination_entry_id = str(
				city_portal.get("destination_entry_id", "default")
			)
		else:
			var building := _building_for_interior_room(destination)
			if is_instance_valid(building):
				var requirement := _interior_transition_requirement(building)
				if not requirement.is_empty():
					_show_status(requirement)
					return
			if (
				not is_instance_valid(building)
				or not _active_interior_id.is_empty()
				or building.consumed
				or not building.contains_world_point(_frog.global_position)
				or building.transition_room_id != destination
			):
				var room := (
					_interior_rooms.get(destination)
					as PrototypeInteriorRoom
				)
				var room_name := (
					room.display_name
					if is_instance_valid(room)
					else "separate room"
				)
				_show_status(
					"The %s is not accessible from here." % room_name
				)
				return
	else:
		push_error("Unknown interior transition destination: %s." % destination)
		return

	_pending_interior_transition = ""
	_pending_interior_portal_id = ""
	_interior_transition_destination = destination
	_interior_transition_entry_id = destination_entry_id
	_interior_transition_source_space = source_space
	_interior_transition_source_portal_id = source_portal_id
	_cancel_frog_navigation()
	_frog.clear_knockback()
	_frog.movement_enabled = false
	_reset_touch_input_state()
	_clear_camera_shake()
	if _motion_scale <= 0.0:
		_complete_interior_transfer()
		_finish_interior_transition()
		return
	_interior_transition_phase = InteriorTransitionPhase.FADE_OUT
	_interior_transition_time = 0.0
	_set_interior_fade_alpha(0.0)
	_interior_transition_fade.visible = true
	_sync_overlay_pause()


func _update_interior_transition(delta: float) -> void:
	if _interior_transition_phase == InteriorTransitionPhase.NONE:
		return
	_interior_transition_time += maxf(0.0, delta)
	var linear_progress := clampf(
		_interior_transition_time / INTERIOR_TRANSITION_DURATION,
		0.0,
		1.0
	)
	var progress := (
		linear_progress
		* linear_progress
		* (3.0 - 2.0 * linear_progress)
	)
	if _interior_transition_phase == InteriorTransitionPhase.FADE_OUT:
		_set_interior_fade_alpha(progress)
		if linear_progress >= 1.0:
			_complete_interior_transfer()
			_interior_transition_phase = InteriorTransitionPhase.FADE_IN
			_interior_transition_time = 0.0
	elif _interior_transition_phase == InteriorTransitionPhase.FADE_IN:
		_set_interior_fade_alpha(1.0 - progress)
		if linear_progress >= 1.0:
			_finish_interior_transition()


func _complete_interior_transfer() -> void:
	AudioDirector.play_effect(FrogAudioDirector.ROOM_TRAVEL)
	if _interior_transition_destination == SECRET_DISTRICT_DESTINATION:
		_active_interior_id = ""
		_clear_city_detour()
		_frog.global_position = (
			DISTRICT_GENERATOR_SCRIPT.secret_entry_position(
				_secret_district_coordinate
			)
		)
		_camera.zoom = _city_camera_zoom
		_camera.rotation = _city_camera_rotation
		_camera.position_smoothing_enabled = (
			_city_camera_smoothing_enabled
		)
		if is_instance_valid(_pursuer):
			_pursuer._escape()
		_update_district_streaming(true)
		_record_secret_district_entered()
		_show_status("Entered Starfall Quarter through the secret path.")
	elif _interior_transition_destination != "city":
		var room := (
			_interior_rooms.get(_interior_transition_destination)
			as PrototypeInteriorRoom
		)
		if not is_instance_valid(room):
			push_error(
				"Interior transition '%s' is missing its room."
				% _interior_transition_destination
			)
			return
		if _interior_transition_source_space.is_empty():
			if not _interior_transition_source_portal_id.is_empty():
				var city_portal := _city_portal_by_id(
					_interior_transition_source_portal_id
				)
				if not bool(
					city_portal.get("preserve_city_return", false)
				):
					_city_return_position = city_portal.get(
						"approach_position",
						Vector2.ZERO
					) as Vector2
					_city_camera_rotation = _camera.rotation
					_city_camera_smoothing_enabled = (
						_camera.position_smoothing_enabled
					)
			else:
				var building := _building_for_interior_room(
					_interior_transition_destination
				)
				if not is_instance_valid(building):
					push_error(
						"Interior transition '%s' is missing its building."
						% _interior_transition_destination
					)
					return
				_city_return_position = (
					building.transition_door_approach_position()
				)
				_city_camera_rotation = _camera.rotation
				_city_camera_smoothing_enabled = (
					_camera.position_smoothing_enabled
				)
		_active_interior_id = _interior_transition_destination
		_clear_city_detour()
		_frog.global_position = room.entry_position(
			_interior_transition_entry_id
		)
		_camera.zoom = room.camera_zoom
		_camera.rotation = 0.0
		_camera.position_smoothing_enabled = false
		if is_instance_valid(_pursuer):
			_pursuer._escape()
		_show_status("Entered the %s." % room.display_name)
	else:
		var building := _building_for_interior_room(_active_interior_id)
		_active_interior_id = ""
		_frog.global_position = _city_return_position
		_camera.zoom = _city_camera_zoom
		_camera.rotation = _city_camera_rotation
		_camera.position_smoothing_enabled = (
			_city_camera_smoothing_enabled
		)
		_show_status(
			"Returned to %s."
			% (
				building.display_name
				if is_instance_valid(building)
				else "the city"
			)
		)
	_last_safe_ground_position = _frog.global_position
	_invalidate_navigation()
	_update_camera()
	_camera.reset_smoothing()


func _finish_interior_transition() -> void:
	_interior_transition_phase = InteriorTransitionPhase.NONE
	_interior_transition_destination = ""
	_interior_transition_entry_id = "default"
	_interior_transition_source_space = ""
	_interior_transition_source_portal_id = ""
	_interior_transition_time = 0.0
	_interior_transition_fade.visible = false
	_set_interior_fade_alpha(0.0)
	_frog.movement_enabled = true
	_sync_overlay_pause()


func _set_interior_fade_alpha(value: float) -> void:
	var fade_color := _interior_transition_fade.color
	fade_color.a = clampf(value, 0.0, 1.0)
	_interior_transition_fade.color = fade_color


func _try_tongue_at_screen(screen_position: Vector2) -> void:
	if _net_escape_active:
		_show_status("Break free from the net before using the tongue.")
		return
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
	_play_haptic(8)
	var shot_offset := world_position - _frog.global_position
	if shot_offset.length() > _frog.tongue_range():
		var limited_end := (
			_frog.global_position
			+ shot_offset.normalized() * _frog.tongue_range()
		)
		var range_obstruction := _first_tongue_obstruction(
			limited_end,
			_can_swallow_pursuer()
		)
		if not range_obstruction.is_empty():
			_handle_tongue_obstruction(
				range_obstruction,
				"That spot is out of tongue range."
			)
		else:
			_show_tongue(limited_end)
			_tongue_recovery = _adjusted_tongue_recovery(TONGUE_RECOVERY)
			AudioDirector.play_effect(FrogAudioDirector.TONGUE_MISS)
			_show_status("That spot is out of tongue range.")
		return

	var obstruction := _first_tongue_obstruction(
		world_position,
		pursuer_hit != null or _can_swallow_pursuer(),
		target
	)
	if not obstruction.is_empty():
		_handle_tongue_obstruction(
			obstruction,
			"The tongue bounced off a wall."
		)
		return

	if pursuer_hit != null:
		AudioDirector.play_effect(FrogAudioDirector.TONGUE_HIT)
		if not _can_swallow_pursuer():
			pursuer_hit.pulse_deflect()
			_show_tongue(world_position)
			_tongue_recovery = _adjusted_tongue_recovery(TONGUE_RECOVERY)
			_show_status(pursuer_hit.protection_status())
		else:
			_show_tongue(world_position)
			_swallow_pursuer(pursuer_hit, pursuer_hit.hit_accuracy(world_position))
		return

	if target == null:
		_show_tongue(world_position)
		_tongue_recovery = _adjusted_tongue_recovery(TONGUE_RECOVERY)
		AudioDirector.play_effect(FrogAudioDirector.TONGUE_MISS)
		_show_status("Miss! Aim directly at something you can eat.")
		return

	AudioDirector.play_effect(FrogAudioDirector.TONGUE_HIT)
	if target.kind == "building":
		var building := _building_by_id.get(target.building_id) as PrototypeBuilding
		if is_instance_valid(building) and (
			not building.is_ready_to_swallow()
			or (
				_growth_tier
				< GAMEPLAY_TUNING_SCRIPT.WHOLE_BUILDING_EDIBLE_TIER
			)
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
					"%s is weak, but the frog must reach large growth."
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
	_struggle_required_taps = (
		AccessibilityPresentation.assisted_struggle_taps(
			GAMEPLAY_TUNING_SCRIPT.struggle_taps_required(
				target.taps_required,
				target.size_tier,
				_growth_tier
			),
			_input_assist_mode
		)
	)
	_struggle_progress.max_value = _struggle_required_taps
	_struggle_progress.value = 0
	_struggle_title.text = TARGET_STRUGGLE_TITLE
	_struggle_hint.text = _struggle_input_hint()
	_struggle_panel.visible = true
	_cancel_frog_navigation()
	_frog.movement_enabled = false
	if _tongue_phase == TonguePhase.HIDDEN:
		_show_tongue(target.global_position + hit_offset)
	_show_status("%s is fighting back!" % target.display_name)


func _register_struggle_tap() -> void:
	if not is_instance_valid(_struggle_target):
		return
	AudioDirector.play_effect(FrogAudioDirector.STRUGGLE_TAP)
	_play_haptic(12)
	_struggle_taps += 1
	_struggle_kick = 1.0
	_struggle_target.pulse_feedback(_motion_scale)
	_struggle_progress.value = _struggle_taps
	if _struggle_taps >= _struggle_required_taps:
		_complete_struggle()


func _complete_struggle() -> void:
	if not is_instance_valid(_struggle_target):
		return
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
		_tongue_recovery = _adjusted_tongue_recovery(TONGUE_RECOVERY)
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
	_tongue_recovery = _adjusted_tongue_recovery(
		TONGUE_RECOVERY * 1.5
	)
	var pursuer_archetype := _pursuer_archetype_for_escape(escaped_target)
	var response_name := PrototypePursuer.display_name_for(
		pursuer_archetype
	)
	if building_repelled:
		_show_status(
			"%s shook the frog off and called %s!"
			% [escaped_target.display_name, response_name]
		)
	elif interior_building != null:
		_show_status(
			"%s hid inside %s and called %s!"
			% [
				escaped_target.display_name,
				interior_building.display_name,
				response_name,
			]
		)
	else:
		_show_status(
			"%s escaped and called %s!"
			% [escaped_target.display_name, response_name]
		)
	_spawn_pursuer(pursuer_archetype)


func _pursuer_archetype_for_escape(target: EdibleTarget) -> String:
	if is_instance_valid(target) and target.kind == "living":
		return PrototypePursuer.ARCHETYPE_WATCHDOG
	if is_instance_valid(target) and target.kind in [
		"object",
		"vehicle",
		"building_part",
		"building",
	]:
		return PrototypePursuer.ARCHETYPE_SECURITY_GUARD
	return PrototypePursuer.ARCHETYPE_ANIMAL_CONTROL


func _clear_struggle() -> void:
	if is_instance_valid(_struggle_target):
		_tongue_end = (
			_struggle_target.global_position + _struggle_hit_offset
		)
		_struggle_target.set_latched(false)
	_struggle_target = null
	_struggle_required_taps = 0
	_end_assisted_hold()
	_struggle_panel.visible = false
	_frog.movement_enabled = true
	_start_tongue_retract()


func _swallow_target(target: EdibleTarget, accuracy: float) -> void:
	var effect_position := target.global_position
	var effect_color := target.target_color
	var swallowed_building := target.kind == "building"
	var swallowed_building_part := target.kind == "building_part"
	var chased := _is_actively_chased()
	var item := target.make_belly_item(accuracy, target.dangerous_location, chased)
	_mark_generated_target_removed(target)
	_normalize_tutorial_belly_item(item)
	_record_discovery(item.target_id, item.display_name)
	_challenges.record_swallow(item.target_id, item.accuracy)
	_update_challenge_hud()
	_record_event_goals_for_swallow()
	if swallowed_building:
		_unlock_profile_achievement("building_banquet")
	var building := _building_by_id.get(target.building_id) as PrototypeBuilding
	var building_was_weakened := false
	if is_instance_valid(building):
		if not target.building_part_id.is_empty():
			building_was_weakened = building.remove_part(target.building_part_id)
			if building.is_ready_to_swallow():
				_activate_building_target(building.building_id)
			elif building_was_weakened:
				_activate_next_ordered_building_part(building)
		elif target.kind == "building":
			building.consume()
		_capture_generated_building_state(building)
	_belly.append(item)
	_targets.erase(target)
	target.queue_free()
	AudioDirector.play_effect(FrogAudioDirector.SWALLOW)
	_play_haptic(24)
	_frog.celebrate_swallow()
	_effects.emit_swallow(effect_position, effect_color, swallowed_building)
	if swallowed_building or swallowed_building_part:
		AudioDirector.play_effect(FrogAudioDirector.DESTRUCTION)
		_effects.emit_destruction(
			effect_position,
			effect_color,
			swallowed_building
		)
	if swallowed_building:
		_trigger_camera_shake(6.0, 0.22)
	_tongue_recovery = _adjusted_tongue_recovery(TONGUE_RECOVERY)
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
	if _net_escape_active:
		_show_status("Break free from the net before opening the belly.")
		return
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
	_cancel_frog_navigation()
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
	_update_save_warning_surfaces()
	_sync_overlay_pause()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _close_belly() -> void:
	_belly_overlay.visible = false
	_update_save_warning_surfaces()
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
	if _net_escape_active:
		_show_status("Break free from the net before opening the Field Guide.")
		return
	if is_instance_valid(_pull_target):
		_show_status("Finish being pulled before opening the Field Guide.")
		return
	if _belly_overlay.visible or _options_overlay.visible:
		return
	_cancel_frog_navigation()
	_rebuild_guide()
	_reset_touch_input_state()
	_clear_camera_shake()
	_hide_discovery_banner()
	_guide_overlay.visible = true
	_update_save_warning_surfaces()
	_sync_overlay_pause()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _close_guide() -> void:
	_guide_overlay.visible = false
	_update_save_warning_surfaces()
	_reset_touch_input_state()
	_sync_overlay_pause()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _open_options() -> void:
	if _belly_overlay.visible or _guide_overlay.visible:
		return
	_cancel_frog_navigation()
	_update_accessibility_controls()
	_reset_touch_input_state()
	_clear_camera_shake()
	_hide_discovery_banner()
	_tutorial_panel_was_visible_before_options = _tutorial_panel.visible
	_tutorial_panel.visible = false
	_options_overlay.visible = true
	_update_save_warning_surfaces()
	_sync_overlay_pause()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _close_options() -> void:
	_options_overlay.visible = false
	_update_save_warning_surfaces()
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
		or _interior_transition_phase != InteriorTransitionPhase.NONE
	)


func _sync_overlay_pause() -> void:
	get_tree().paused = _overlay_blocking()


func _reset_touch_input_state() -> void:
	_active_touches.clear()
	_camera_gesture = false
	_camera_driver_id = -1
	_mouse_rotating = false
	_hold_tongue_position = Vector2.INF
	_end_assisted_hold()


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
	_guide_progress.text = (
		"Field Guide %d / %d | Profile achievements %d / %d\n"
		+ "Story clues %d / %d | Device milestones %d / %d"
	) % [
		discovered_count,
		DiscoveryCatalog.count(),
		_achievement_model.unlocked_count(
			ProgressionCatalog.SCOPE_PROFILE
		),
		ProgressionCatalog.profile_achievement_ids().size(),
		_story_clues.size(),
		ProgressionCatalog.story_clue_ids().size(),
		_achievement_model.unlocked_count(
			ProgressionCatalog.SCOPE_DEVICE
		),
		ProgressionCatalog.device_achievement_ids().size(),
	]
	var pages := _guide_pages()
	_guide_page_index = clampi(
		_guide_page_index,
		0,
		maxi(0, pages.size() - 1)
	)
	var page := pages[_guide_page_index]
	var row := Label.new()
	row.custom_minimum_size = Vector2(0, 390)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_theme_font_size_override("font_size", 19)
	row.add_theme_color_override("font_color", Color(0.84, 0.92, 0.88))
	row.text = str(page["text"])
	_guide_list.add_child(row)
	AccessibilityPresentation.apply(
		row,
		_larger_text_controls_enabled
	)
	_guide_page_label.text = "%d / %d  %s" % [
		_guide_page_index + 1,
		pages.size(),
		page["title"],
	]
	_previous_guide_page_button.disabled = _guide_page_index <= 0
	_next_guide_page_button.disabled = _guide_page_index >= pages.size() - 1
	_guide_scroll.scroll_vertical = 0


func _on_previous_guide_page() -> void:
	if _guide_page_index <= 0:
		return
	_guide_page_index -= 1
	_rebuild_guide()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _on_next_guide_page() -> void:
	var pages := _guide_pages()
	if _guide_page_index >= pages.size() - 1:
		return
	_guide_page_index += 1
	_rebuild_guide()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _guide_pages() -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var lines: Array[String] = []

	for entry in ProgressionCatalog.session_goal_entries():
		var goal_id := str(entry["id"])
		var definition := SessionChallenges.definition_for(goal_id)
		lines.append(
			"%s %s (%d / %d) - %s" % [
				(
					"[DONE]"
					if _achievement_model.is_unlocked(
						ProgressionCatalog.SCOPE_SESSION,
						goal_id
					)
					else "[ ]"
				),
				entry["name"],
				_challenges.progress(goal_id),
				int(definition.get("goal", 1)),
				entry["description"],
			]
		)
	_append_guide_pages(
		pages,
		"SESSION GOALS",
		"SESSION GOALS - reset with every Start New Game",
		lines,
		lines.size()
	)

	lines = []
	for entry in ProgressionCatalog.profile_achievement_entries():
		var achievement_id := str(entry["id"])
		lines.append(
			"%s %s - %s" % [
				(
					"[UNLOCKED]"
					if _achievement_model.is_unlocked(
						ProgressionCatalog.SCOPE_PROFILE,
						achievement_id
					)
					else "[ ]"
				),
				entry["name"],
				entry["description"],
			]
		)
	_append_guide_pages(
		pages,
		"PROFILE ACHIEVEMENTS",
		"PROFILE ACHIEVEMENTS - saved for %s" % _display_name,
		lines,
		GUIDE_PROFILE_ENTRIES_PER_PAGE
	)

	lines = []
	for entry in ProgressionCatalog.device_achievement_entries():
		var achievement_id := str(entry["id"])
		lines.append(
			"%s %s - %s" % [
				(
					"[UNLOCKED]"
					if _achievement_model.is_unlocked(
						ProgressionCatalog.SCOPE_DEVICE,
						achievement_id
					)
					else "[ ]"
				),
				entry["name"],
				entry["description"],
			]
		)
	_append_guide_pages(
		pages,
		"DEVICE MILESTONES",
		"DEVICE MILESTONES - shared on this device",
		lines,
		lines.size()
	)

	lines = []
	var postcard_number := 1
	for entry in ProgressionCatalog.story_clue_entries():
		var clue_id := str(entry["id"])
		lines.append(
			(
				"POSTCARD %02d [STAMPED] %s - %s" % [
					postcard_number,
					entry["name"],
					entry["text"],
				]
				if _story_clues.has(clue_id)
				else "POSTCARD %02d [UNDELIVERED] Undiscovered clue"
				% postcard_number
			)
		)
		postcard_number += 1
	_append_guide_pages(
		pages,
		"STORY CLUES",
		"STORY CLUES - POSTCARDS saved for %s" % _display_name,
		lines,
		GUIDE_CLUES_PER_PAGE
	)

	lines = []
	for entry in ProgressionCatalog.power_entries():
		var power_id := str(entry["id"])
		lines.append(
			(
				"[FOUND] %s" % entry["name"]
				if _power_discoveries.has(power_id)
				else "[?] Undiscovered power"
			)
		)
	lines.append(
		(
			"[UNLOCKED] Secret path revealed"
			if _secret_unlocks.has(
				ProgressionCatalog.SECRET_FANTASY_DISTRICT
			)
			else "[LOCKED] Secret path - %d / %d clues" % [
				_story_clues.size(),
				ProgressionCatalog.SECRET_CLUE_REQUIREMENT,
			]
		)
	)
	_append_guide_pages(
		pages,
		"POWERS & SECRET PATH",
		"POWER DISCOVERIES - saved for %s" % _display_name,
		lines,
		lines.size()
	)

	lines = []
	for entry in DiscoveryCatalog.entries():
		var target_id := str(entry["id"])
		var discovered := _discoveries.has(target_id)
		lines.append(
			(
				"[FOUND] %s - %s" % [entry["name"], entry["hint"]]
				if discovered
				else "[UNKNOWN] Hint: %s" % entry["hint"]
			)
		)
	_append_guide_pages(
		pages,
		"FIELD GUIDE",
		"FIELD GUIDE - city discoveries",
		lines,
		GUIDE_FIELD_ENTRIES_PER_PAGE
	)
	return pages


func _append_guide_pages(
	pages: Array[Dictionary],
	title: String,
	heading: String,
	lines: Array[String],
	lines_per_page: int
) -> void:
	var page_size := maxi(1, lines_per_page)
	var page_count := maxi(1, ceili(float(lines.size()) / float(page_size)))
	for page_index in page_count:
		var start := page_index * page_size
		var end := mini(lines.size(), start + page_size)
		var page_lines := lines.slice(start, end)
		var numbered_heading := heading
		if page_count > 1:
			numbered_heading += " (%d / %d)" % [page_index + 1, page_count]
		pages.append({
			"title": title,
			"text": "%s\n\n%s" % [
				numbered_heading,
				"\n\n".join(page_lines),
			],
		})


func _known_discovery_count() -> int:
	var total := 0
	for target_id in DiscoveryCatalog.ids():
		if _discoveries.has(target_id):
			total += 1
	return total


func _begin_session_challenges() -> void:
	_achievement_model.reset_session()
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


func _on_challenge_completed(challenge_id: String) -> void:
	_achievement_model.unlock_session(challenge_id)
	_challenge_pulse_times[challenge_id] = HUD_PULSE_DURATION
	_update_challenge_hud()
	_rebuild_guide()
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
	target_discovered.emit(target_id)
	var clue_id := ProgressionCatalog.story_clue_for_discovery(target_id)
	if not clue_id.is_empty():
		_record_story_clue(clue_id)
	if _all_ids_known(
		ProgressionCatalog.generated_archetype_discovery_ids(),
		_discoveries
	):
		_record_story_clue("district_glyph")
	_evaluate_profile_achievements()
	_sync_progression_portals()
	AudioDirector.play_effect(FrogAudioDirector.DISCOVERY)
	_rebuild_guide()
	_update_hud()
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


func _evaluate_persisted_progression() -> void:
	for discovery_id in _discoveries:
		var clue_id := ProgressionCatalog.story_clue_for_discovery(
			str(discovery_id)
		)
		if not clue_id.is_empty():
			_record_story_clue(clue_id)
	for power_id in _power_discoveries:
		var clue_id := ProgressionCatalog.story_clue_for_power(
			str(power_id)
		)
		if not clue_id.is_empty():
			_record_story_clue(clue_id)
	if _any_id_known(
		ProgressionCatalog.whole_building_discovery_ids(),
		_discoveries
	):
		_unlock_profile_achievement("building_banquet")
	for achievement_id in _achievement_model.unlocked_ids(
		ProgressionCatalog.SCOPE_PROFILE
	):
		var clue_id := (
			ProgressionCatalog.story_clue_for_profile_achievement(
				achievement_id
			)
		)
		if not clue_id.is_empty():
			_record_story_clue(clue_id)
	if _all_ids_known(
		ProgressionCatalog.generated_archetype_discovery_ids(),
		_discoveries
	):
		_record_story_clue("district_glyph")
	_evaluate_profile_achievements()
	_evaluate_device_achievements()


func _evaluate_profile_achievements() -> void:
	if _has_first_growth_evidence():
		_unlock_profile_achievement("growth_spurt")
	if _known_discovery_count() >= 12:
		_unlock_profile_achievement("city_gourmet")
	if _power_discoveries.size() == ProgressionCatalog.power_ids().size():
		_unlock_profile_achievement("power_sampler")
	if _story_clues.size() >= ProgressionCatalog.SECRET_CLUE_REQUIREMENT:
		_unlock_profile_achievement("clue_collector")
		_unlock_secret_path()
	_evaluate_event_explorer()


func _evaluate_device_achievements() -> void:
	if _score >= ProgressionCatalog.DEVICE_SCORE_MILESTONE_THRESHOLD:
		_unlock_device_achievement("device_score_2500")


func _unlock_profile_achievement(achievement_id: String) -> bool:
	if not _achievement_model.unlock_profile(achievement_id):
		return false
	if _progression_audio_enabled:
		AudioDirector.play_effect(FrogAudioDirector.ACHIEVEMENT)
	var clue_id := (
		ProgressionCatalog.story_clue_for_profile_achievement(
			achievement_id
		)
	)
	var clue_was_added := false
	if not clue_id.is_empty():
		clue_was_added = _accept_story_clue(clue_id)
	profile_achievement_unlocked.emit(achievement_id, clue_id)
	if clue_was_added:
		if _progression_audio_enabled:
			AudioDirector.play_effect(FrogAudioDirector.CLUE_FOUND)
		story_clue_found.emit(clue_id)
		_apply_story_clue_thresholds()
	if ProgressionCatalog.event_profile_achievement_ids().has(
		achievement_id
	):
		_evaluate_event_explorer()
	return true


func _unlock_device_achievement(achievement_id: String) -> bool:
	if not _achievement_model.unlock_device(achievement_id):
		return false
	if _progression_audio_enabled:
		AudioDirector.play_effect(FrogAudioDirector.ACHIEVEMENT)
	device_achievement_unlocked.emit(achievement_id)
	return true


func _record_story_clue(clue_id: String) -> bool:
	var normalized_id := clue_id.strip_edges()
	if not _accept_story_clue(normalized_id):
		return false
	if _progression_audio_enabled:
		AudioDirector.play_effect(FrogAudioDirector.CLUE_FOUND)
	story_clue_found.emit(normalized_id)
	_apply_story_clue_thresholds()
	return true


func _accept_story_clue(clue_id: String) -> bool:
	if (
		clue_id.is_empty()
		or _story_clues.has(clue_id)
		or ProgressionCatalog.story_clue_entry(clue_id).is_empty()
	):
		return false
	_story_clues[clue_id] = true
	return true


func _apply_story_clue_thresholds() -> void:
	if _story_clues.size() >= ProgressionCatalog.SECRET_CLUE_REQUIREMENT:
		_unlock_profile_achievement("clue_collector")
		_unlock_secret_path()


func _unlock_secret_path() -> bool:
	var secret_id := ProgressionCatalog.SECRET_FANTASY_DISTRICT
	if _secret_unlocks.has(secret_id):
		return false
	_secret_unlocks[secret_id] = true
	_prepare_secret_district()
	_sync_progression_portals()
	secret_unlocked.emit(secret_id)
	return true


func _prepare_secret_district() -> void:
	if _secret_district_coordinate == Vector2i.ZERO:
		return
	call_deferred("_replace_secret_district_definition")


func _replace_secret_district_definition() -> void:
	if _loaded_districts.has(_secret_district_coordinate):
		_unload_generated_district(_secret_district_coordinate)
	var key := _district_key(_secret_district_coordinate)
	_district_definitions.erase(key)
	if (
		_active_interior_id.is_empty()
		and _current_district_coordinate == _secret_district_coordinate
	):
		call_deferred("_update_district_streaming", true)


func _is_secret_district_coordinate(coordinate: Vector2i) -> bool:
	return (
		_secret_unlocks.has(ProgressionCatalog.SECRET_FANTASY_DISTRICT)
		and coordinate == _secret_district_coordinate
	)


func _evaluate_event_explorer() -> void:
	for achievement_id in ProgressionCatalog.event_profile_achievement_ids():
		if not _achievement_model.is_unlocked(
			ProgressionCatalog.SCOPE_PROFILE,
			achievement_id
		):
			return
	_unlock_profile_achievement("event_explorer")


func _record_event_goals_for_swallow() -> void:
	if festival_intensity_for_clock(_day_clock) > 0.0:
		_unlock_profile_achievement("event_moonlight_bazaar")
	if kite_festival_intensity_for_clock(_day_clock) > 0.0:
		_unlock_profile_achievement("event_kite_festival")
	if (
		city_detour_active_for_clock(_day_clock)
		and is_instance_valid(_city_detour)
	):
		_unlock_profile_achievement("event_water_main")
	if wind_squall_intensity_for_clock(_day_clock) > 0.0:
		_unlock_profile_achievement("event_wind_squall")


func _record_secret_district_entered() -> void:
	_unlock_profile_achievement("secret_finder")
	_unlock_device_achievement("device_secret_found")


func _record_enormous_growth() -> void:
	_unlock_profile_achievement("enormous_appetite")
	_unlock_device_achievement("device_enormous_growth")


func _all_ids_known(ids: PackedStringArray, known_ids: Dictionary) -> bool:
	for item_id in ids:
		if not known_ids.has(item_id):
			return false
	return true


func _any_id_known(ids: PackedStringArray, known_ids: Dictionary) -> bool:
	for item_id in ids:
		if known_ids.has(item_id):
			return true
	return false


func _has_first_growth_evidence() -> bool:
	return (
		not _power_discoveries.is_empty()
		or _any_id_known(
			ProgressionCatalog.first_growth_evidence_discovery_ids(),
			_discoveries
		)
		or _any_profile_achievement_unlocked(
			ProgressionCatalog.first_growth_evidence_achievement_ids()
		)
		or _any_id_known(
			ProgressionCatalog.first_growth_evidence_clue_ids(),
			_story_clues
		)
	)


func _any_profile_achievement_unlocked(
	achievement_ids: PackedStringArray
) -> bool:
	for achievement_id in achievement_ids:
		if _achievement_model.is_unlocked(
			ProgressionCatalog.SCOPE_PROFILE,
			achievement_id
		):
			return true
	return false


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
	_play_haptic(32)
	var points := item.score_value()
	_score += points
	var growth_gain := _growth_value_for_item(item)
	_growth_points += growth_gain
	_apply_digest_effects(item)
	item_digested.emit(item.target_id)
	_apply_growth_thresholds()
	score_changed.emit(_score)
	_evaluate_device_achievements()
	_show_status("Digested %s for %d points!" % [item.display_name, points])
	_update_hud()
	_show_digest_reward(points, growth_gain)
	_rebuild_belly_list()
	if tutorial_digest:
		call_deferred("_close_belly_after_tutorial_digest")


func _growth_value_for_item(item: BellyItem) -> int:
	var value := GAMEPLAY_TUNING_SCRIPT.growth_value(
		item.base_value,
		item.size_tier,
		item.rare
	)
	if (
		_tutorial != null
		and _tutorial.active
		and _tutorial.step == TutorialController.Step.DIGEST_SIGN
		and item.target_id == "moonlight_market_sign"
	):
		return maxi(value, GROWTH_THRESHOLDS[0] - _growth_points)
	return value


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
		var growth_gain := _growth_value_for_item(item)
		total_points += points
		total_growth += growth_gain
		_score += points
		_growth_points += growth_gain
		_apply_digest_effects(item)
	_apply_growth_thresholds()
	score_changed.emit(_score)
	_evaluate_device_achievements()
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
	if not _belly_item_matches_active_space(item):
		_show_status(
			"Return to %s before spitting out %s."
			% [
				_belly_item_space_label(item),
				item.display_name,
			]
		)
		_rebuild_belly_list()
		return
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
	target.district_coordinate = _current_district_coordinate
	if (
		target.world_instance_id.is_empty()
		and _current_district_coordinate
		!= DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
	):
		target.world_instance_id = "session_spit_%d" % (
			_next_session_instance_id
		)
		_next_session_instance_id += 1
	target.position = spawn_position
	target.dangerous_location = _belly_item_retains_danger(item)
	if target.velocity != Vector2.ZERO and not target.is_vehicle:
		target.move_bounds = Rect2(
			spawn_position - Vector2(360, 260),
			Vector2(720, 520)
		).intersection(_active_navigation_rect().grow(-80))
	var target_parent := _district_parent_for_coordinate(
		target.district_coordinate
	)
	target.z_as_relative = false
	target_parent.add_child(target)
	_targets.append(target)
	_mark_generated_target_present(target)
	AudioDirector.play_effect(FrogAudioDirector.SPIT)
	_show_status("%s was returned safely." % item.display_name)
	_update_hud()
	_rebuild_belly_list()


func _belly_item_matches_active_space(item: BellyItem) -> bool:
	var item_room_id := ""
	if _interior_rooms.has(item.building_id):
		item_room_id = item.building_id
	if not item_room_id.is_empty():
		return item_room_id == _active_interior_id
	if not _active_interior_id.is_empty():
		return false
	if item.kind == "building":
		return item.district_coordinate == _current_district_coordinate
	return true


func _belly_item_retains_danger(item: BellyItem) -> bool:
	return (
		item.intrinsic_dangerous_location
		and _interior_rooms.has(item.building_id)
	)


func _sync_progression_portals() -> void:
	var sewer_junction := (
		_interior_rooms.get(RIVER_SEWER_JUNCTION_ID)
		as PrototypeInteriorRoom
	)
	if is_instance_valid(sewer_junction):
		sewer_junction.set_portal_visible(
			"hidden_maintenance_hatch",
			_discoveries.has("river_sewer_valve")
		)
	var hidden_maintenance := (
		_interior_rooms.get(RIVER_HIDDEN_MAINTENANCE_ID)
		as PrototypeInteriorRoom
	)
	if is_instance_valid(hidden_maintenance):
		hidden_maintenance.set_portal_visible(
			"secret_star_path",
			_secret_unlocks.has(
				ProgressionCatalog.SECRET_FANTASY_DISTRICT
			)
		)


func _belly_item_space_label(item: BellyItem) -> String:
	if not _interior_rooms.has(item.building_id):
		if item.kind == "building":
			if (
				item.district_coordinate
				== DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
			):
				return "the central district"
			return "district %d,%d" % [
				item.district_coordinate.x,
				item.district_coordinate.y,
			]
		return "the city"
	var room := _interior_rooms.get(item.building_id) as PrototypeInteriorRoom
	return (
		"the %s" % room.display_name.to_lower()
		if is_instance_valid(room)
		else "separate room"
	)


func _apply_growth_thresholds() -> void:
	var next_tier := 0
	for threshold in GROWTH_THRESHOLDS:
		if _growth_points >= threshold:
			next_tier += 1
	if next_tier == _growth_tier:
		_pending_growth_tier = -1
		return
	if (
		next_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
		and not _active_interior_id.is_empty()
	):
		_pending_growth_tier = next_tier
		_show_status("Return outdoors so the frog has room to grow enormous.")
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
	if (
		_pending_growth_tier <= _growth_tier
		or _frog.is_flying
		or (
			_pending_growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
			and not _active_interior_id.is_empty()
		)
	):
		return
	var safe_position := _find_safe_frog_position(
		_frog.radius_for_tier(_pending_growth_tier)
	)
	if safe_position == Vector2.INF:
		return
	_frog.global_position = safe_position
	_apply_growth_tier(_pending_growth_tier)


func _apply_growth_tier(tier: int) -> void:
	if (
		tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
		and not _active_interior_id.is_empty()
	):
		_pending_growth_tier = tier
		_show_status("Return outdoors so the frog has room to grow enormous.")
		return
	_growth_tier = tier
	_pending_growth_tier = -1
	_frog.set_growth_tier(_growth_tier)
	_city_camera_zoom = GAMEPLAY_TUNING_SCRIPT.city_camera_zoom(
		_growth_tier
	)
	if _active_interior_id.is_empty():
		_camera.zoom = _city_camera_zoom
	_invalidate_navigation()
	_frog.celebrate_growth(_motion_scale)
	_effects.emit_growth(_frog.global_position)
	AudioDirector.play_effect(
		FrogAudioDirector.GROWTH_MAJOR
		if _growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
		else FrogAudioDirector.GROWTH
	)
	if _growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER:
		if is_instance_valid(_pursuer):
			_pursuer.cancel_active_attack()
			_pursuer.set_frog_netted(false)
		_clear_pursuit_trap()
		_show_status("Enormous growth! Pursuers are now edible.")
	else:
		_show_status(
			"Growth tier %d! The frog and tongue are larger."
			% (_growth_tier + 1)
		)
	if _growth_tier >= 1:
		_unlock_profile_achievement("growth_spurt")
	if _growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER:
		_record_enormous_growth()
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
	var active_crowd_members := 0
	var festival_lanterns := 0
	if is_instance_valid(_city_activity):
		active_pedestrians = _city_activity.active_pedestrian_count()
		active_vehicles = _city_activity.active_vehicle_count()
		active_crowd_members = _city_activity.active_crowd_member_count()
		festival_lanterns = (
			_city_activity.visible_festival_lantern_count()
		)
	var generated_targets := 0
	for target in _targets:
		if (
			is_instance_valid(target)
			and not target.world_instance_id.is_empty()
		):
			generated_targets += 1
	var generated_buildings := 0
	for building in _buildings:
		if (
			is_instance_valid(building)
			and building.has_meta("district_coordinate")
		):
			generated_buildings += 1
	var audio_structure := AudioDirector.structure_snapshot()
	var navigation_metrics := _navigation.metrics_snapshot()
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
		"generated_targets": generated_targets,
		"generated_buildings": generated_buildings,
		"loaded_generated_districts": _loaded_districts.size(),
		"generated_district_records": _district_definitions.size(),
		"district_state_records": _district_states.size(),
		"current_district": _current_district_coordinate,
		"interior_rooms": _interior_rooms.size(),
		"active_interior": _active_interior_id,
		"oddities_shop_scheduled_open": _oddities_shop_scheduled_open,
		"moonlight_market_scheduled_open": (
			_moonlight_market_scheduled_open
		),
		"pursuers": 1 if is_instance_valid(_pursuer) else 0,
		"pursuer_archetype": (
			_pursuer.archetype_id
			if is_instance_valid(_pursuer)
			else ""
		),
		"pursuer_detects_frog": (
			_pursuer.frog_detected()
			if is_instance_valid(_pursuer)
			else false
		),
		"roadblocks": 1 if is_instance_valid(_roadblock) else 0,
		"roadblock_layout": (
			_roadblock.layout_id
			if is_instance_valid(_roadblock)
			else ""
		),
		"roadblock_segments": (
			_roadblock.collision_shape_count()
			if is_instance_valid(_roadblock)
			else 0
		),
		"city_detour_window_active": _city_detour_window_active,
		"city_detours": 1 if is_instance_valid(_city_detour) else 0,
		"pursuit_traps": 1 if is_instance_valid(_pursuit_trap) else 0,
		"pursuit_trap_variant": (
			_pursuit_trap.variant_id
			if is_instance_valid(_pursuit_trap)
			else ""
		),
		"pursuer_deflecting": (
			_pursuer.deflect_feedback_active()
			if is_instance_valid(_pursuer)
			else false
		),
		"net_projectiles": (
			_pursuer.active_net_projectile_count()
			if is_instance_valid(_pursuer)
			else 0
		),
		"flashlight_attack": (
			_pursuer.flashlight_attack_active()
			if is_instance_valid(_pursuer)
			else false
		),
		"watchdog_lunge": (
			_pursuer.lunge_attack_active()
			if is_instance_valid(_pursuer)
			else false
		),
		"frog_netted": _net_escape_active,
		"belly_items": _belly.size(),
		"belly_rows": _belly_list.get_child_count(),
		"guide_rows": _guide_list.get_child_count(),
		"known_discoveries": _known_discovery_count(),
		"active_pedestrians": active_pedestrians,
		"active_vehicles": active_vehicles,
		"active_crowd_members": active_crowd_members,
		"active_city_actors": (
			active_pedestrians
			+ active_vehicles
			+ active_crowd_members
		),
		"rain_intensity": _current_rain_intensity,
		"rain_streaks": (
			_city_activity.visible_rain_streak_count()
			if is_instance_valid(_city_activity)
			else 0
		),
		"wind_intensity": _current_wind_intensity,
		"wind_ribbons": (
			_city_activity.visible_wind_ribbon_count()
			if is_instance_valid(_city_activity)
			else 0
		),
		"festival_intensity": (
			_city_activity.festival_intensity
			if is_instance_valid(_city_activity)
			else 0.0
		),
		"festival_lanterns": festival_lanterns,
		"kite_festival_intensity": _current_kite_festival_intensity,
		"kite_festival_kites": (
			_city_activity.visible_kite_festival_count()
			if is_instance_valid(_city_activity)
			else 0
		),
		"crowd_intensity": _current_crowd_intensity,
		"crowd_hide_progress": (
			_crowd_hide_time / _pursuer.crowd_escape_duration()
			if is_instance_valid(_pursuer)
			else 0.0
		),
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
		"save_warning_active": not _save_warning_message.is_empty(),
		"save_warning_visible": (
			is_instance_valid(_save_warning_panel)
			and _save_warning_panel.visible
		),
		"save_warnings": (
			1 if is_instance_valid(_save_warning_panel) else 0
		),
		"score_epilogues": (
			1 if is_instance_valid(_score_epilogue) else 0
		),
		"reduce_motion": _reduce_motion_enabled,
		"larger_text_controls": _larger_text_controls_enabled,
		"performance_instrumentation": is_instance_valid(
			_performance_instrumentation
		),
		"navigation_revision": navigation_metrics["navigation_revision"],
		"navigation_obstacles": navigation_metrics["navigation_obstacles"],
		"navigation_requests": navigation_metrics["navigation_requests"],
		"navigation_successes": navigation_metrics["navigation_successes"],
		"navigation_fallbacks": navigation_metrics["navigation_fallbacks"],
		"navigation_failures": navigation_metrics["navigation_failures"],
		"navigation_budget_rejections": navigation_metrics[
			"navigation_budget_rejections"
		],
		"navigation_last_request_usec": navigation_metrics[
			"navigation_last_request_usec"
		],
		"navigation_max_request_usec": navigation_metrics[
			"navigation_max_request_usec"
		],
		"navigation_last_query_cells": navigation_metrics[
			"navigation_last_query_cells"
		],
		"navigation_max_query_cells": navigation_metrics[
			"navigation_max_query_cells"
		],
		"navigation_last_path_points": navigation_metrics[
			"navigation_last_path_points"
		],
		"navigation_max_path_points": navigation_metrics[
			"navigation_max_path_points"
		],
		"navigation_active_frog_points": (
			_frog.active_path_point_count()
			if is_instance_valid(_frog)
			else 0
		),
		"navigation_active_pursuer_points": (
			_pursuer.active_navigation_point_count()
			if is_instance_valid(_pursuer)
			else 0
		),
		"navigation_pursuer_repaths": (
			_pursuer.navigation_repath_count()
			if is_instance_valid(_pursuer)
			else 0
		),
		"navigation_pursuer_failures": (
			_pursuer.navigation_failure_count()
			if is_instance_valid(_pursuer)
			else 0
		),
		"navigation_pursuer_reaches_frog": (
			_pursuer.navigation_reaches_frog()
			if is_instance_valid(_pursuer)
			else false
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
	if is_instance_valid(_pursuer):
		_pursuer.set_presentation_motion_scale(_motion_scale)
	if is_instance_valid(_pursuit_trap):
		_pursuit_trap.set_presentation_motion_scale(_motion_scale)
	if is_instance_valid(_frog):
		_frog.set_presentation_motion_scale(_motion_scale)
	for target in _targets:
		if is_instance_valid(target):
			target.set_presentation_motion_scale(_motion_scale)
	if is_instance_valid(_touch_feedback):
		_touch_feedback.set_motion_scale(_motion_scale)
	if is_instance_valid(_tutorial_marker):
		_tutorial_marker.set_motion_scale(_motion_scale)
	if is_instance_valid(_tutorial_card_art):
		_tutorial_card_art.set_motion_scale(_motion_scale)
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


func _show_status(message: String, duration: float = 3.0) -> void:
	_status_label.text = message
	_status_time = maxf(0.0, duration)


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
	if is_instance_valid(_pursuer) and (
		exclude_pursuer
		or not _pursuer.protects_target(selected_target)
	):
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
	var bounds := _active_navigation_rect()
	return Vector2(
		clampf(world_position.x, bounds.position.x, bounds.end.x),
		clampf(world_position.y, bounds.position.y, bounds.end.y)
	)


func _rotate_camera(
	screen_delta_x: float,
	screen_position: Vector2 = Vector2.INF
) -> void:
	if not _active_interior_id.is_empty():
		var active_room := (
			_interior_rooms.get(_active_interior_id) as PrototypeInteriorRoom
		)
		if (
			not is_instance_valid(active_room)
			or not active_room.camera_follows_frog()
		):
			return
	if (
		_tutorial != null
		and _tutorial.active
		and not _tutorial.allows_camera_rotation()
	):
		return
	var radians := screen_delta_x * 0.006 * _camera_sensitivity
	if is_zero_approx(radians):
		return
	_camera.rotation -= radians
	if not _active_interior_id.is_empty():
		var active_room := (
			_interior_rooms.get(_active_interior_id) as PrototypeInteriorRoom
		)
		if (
			is_instance_valid(active_room)
			and active_room.camera_rotation_limit > 0.0
		):
			_camera.rotation = clampf(
				_camera.rotation,
				-active_room.camera_rotation_limit,
				active_room.camera_rotation_limit
			)
	else:
		_city_camera_rotation = _camera.rotation
	_camera_manual_override_time = CAMERA_AUTO_ALIGN_DELAY
	manual_camera_rotated.emit(absf(radians))
	_touch_feedback.show_camera(
		get_viewport_rect().size / 2.0
		if screen_position == Vector2.INF
		else screen_position
	)


func _update_camera_assistance(delta: float) -> void:
	_camera_manual_override_time = maxf(
		0.0,
		_camera_manual_override_time - delta
	)
	if (
		not _camera_auto_align_enabled
		or _camera_manual_override_time > 0.0
		or not _active_interior_id.is_empty()
		or _frog.velocity.length_squared() < 2500.0
		or (
			_tutorial != null
			and _tutorial.active
			and not _tutorial.allows_camera_rotation()
		)
	):
		return
	var target_rotation := wrapf(
		_frog.velocity.angle() + PI * 0.5,
		-PI,
		PI
	)
	_camera.rotation = lerp_angle(
		_camera.rotation,
		target_rotation,
		clampf(delta * CAMERA_AUTO_ALIGN_SPEED, 0.0, 1.0)
	)
	_city_camera_rotation = _camera.rotation


func _reset_camera_orientation() -> void:
	_camera.rotation = 0.0
	_city_camera_rotation = 0.0
	_camera_manual_override_time = CAMERA_AUTO_ALIGN_DELAY
	_touch_feedback.show_camera(get_viewport_rect().size * 0.5)
	_show_status("Camera reset to the city map.")
	_play_haptic(20)
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _update_camera() -> void:
	if not _active_interior_id.is_empty():
		var room := (
			_interior_rooms.get(_active_interior_id) as PrototypeInteriorRoom
		)
		if not is_instance_valid(room):
			_camera.global_position = _frog.global_position
			return
		if room.camera_follows_frog():
			var room_forward := Vector2.UP.rotated(_camera.rotation)
			var desired := (
				_frog.global_position
				+ room_forward * room.camera_follow_distance
			)
			var half_view := (
				get_viewport_rect().size
				/ (_camera.zoom * 2.0)
			)
			var cosine := absf(cos(_camera.rotation))
			var sine := absf(sin(_camera.rotation))
			half_view = Vector2(
				cosine * half_view.x + sine * half_view.y,
				sine * half_view.x + cosine * half_view.y
			)
			var interior_bounds := room.interior_rect()
			var minimum := interior_bounds.position + half_view
			var maximum := interior_bounds.end - half_view
			if minimum.x > maximum.x:
				minimum.x = interior_bounds.get_center().x
				maximum.x = minimum.x
			if minimum.y > maximum.y:
				minimum.y = interior_bounds.get_center().y
				maximum.y = minimum.y
			_camera.global_position = Vector2(
				clampf(
					desired.x,
					minimum.x,
					maximum.x
				),
				clampf(
					desired.y,
					minimum.y,
					maximum.y
				)
			)
			_camera.reset_smoothing()
		else:
			_camera.global_position = room.global_position
		return
	var forward := Vector2.UP.rotated(_camera.rotation)
	_camera.global_position = (
		_frog.global_position
		+ forward
		* GAMEPLAY_TUNING_SCRIPT.city_camera_forward_offset(
			_growth_tier
		)
	)


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
			_apply_damage(
				target.global_position,
				GAMEPLAY_TUNING_SCRIPT.VEHICLE_COLLISION_PENALTY,
				"A delivery van knocked the frog back!"
			)
			return


func _apply_damage(
	source_position: Vector2,
	penalty: int,
	message: String,
	pursuit_hit: bool = false
) -> void:
	if _damage_cooldown > 0.0:
		return
	if (
		pursuit_hit
		and _growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
	):
		return
	if (
		pursuit_hit
		and _power_state.consume(TemporaryPowerState.BUBBLE_SHIELD)
	):
		_update_power_label()
		AudioDirector.play_effect(FrogAudioDirector.SHIELD_POP)
		_show_status("The Bubble Shield blocked the pursuit hit!")
		return
	_damage_cooldown = DAMAGE_COOLDOWN
	_score = maxi(0, _score - penalty)
	_cancel_frog_navigation()
	_frog.knock_back_from(source_position)
	_effects.emit_damage(_frog.global_position)
	_trigger_camera_shake(8.0, 0.24)
	AudioDirector.play_effect(FrogAudioDirector.DAMAGE)
	_play_haptic(70)
	score_changed.emit(_score)
	_update_hud()
	_show_status(message)


func _spawn_pursuer(
	archetype_id: String = PrototypePursuer.ARCHETYPE_ANIMAL_CONTROL
) -> void:
	if is_instance_valid(_pursuer):
		return
	if _power_state.is_active(TemporaryPowerState.CAMOUFLAGE):
		_show_status(
			"Camouflage kept %s from finding the frog."
			% PrototypePursuer.display_name_for(archetype_id)
		)
		return
	if not _active_interior_id.is_empty():
		_show_status(
			"%s cannot find the frog in here."
			% PrototypePursuer.display_name_for(archetype_id)
		)
		return
	var pursuer_radius := (
		PrototypePursuer.WATCHDOG_NAVIGATION_RADIUS
		if archetype_id == PrototypePursuer.ARCHETYPE_WATCHDOG
		else (
			PrototypePursuer.SECURITY_NAVIGATION_RADIUS
			if archetype_id == PrototypePursuer.ARCHETYPE_SECURITY_GUARD
			else PrototypePursuer.NAVIGATION_RADIUS
		)
	)
	var spawn_position := _find_pursuer_spawn_position(pursuer_radius)
	if spawn_position == Vector2.INF:
		_show_status(
			"%s was called, but could not reach this area."
			% PrototypePursuer.display_name_for(archetype_id)
		)
		return
	_refresh_navigation_geometry()
	_pursuer = PURSUER_SCRIPT.new() as PrototypePursuer
	_pursuer.configure_archetype(archetype_id)
	_pursuer.frog = _frog
	_pursuer.navigation = _navigation
	_pursuer.position = spawn_position
	_pursuer.set_presentation_motion_scale(_motion_scale)
	_pursuer.set_frog_camouflaged(
		_power_state.is_active(TemporaryPowerState.CAMOUFLAGE)
	)
	_pursuer.caught.connect(_on_pursuer_caught)
	_pursuer.netted.connect(_on_pursuer_netted)
	_pursuer.attack_started.connect(_on_pursuer_attack_started)
	_pursuer.attack_hit.connect(_on_pursuer_attack_hit)
	_pursuer.escaped.connect(_on_pursuer_escaped)
	_world.add_child(_pursuer)
	AudioDirector.set_pursuit(self, true)
	AudioDirector.play_effect(FrogAudioDirector.PURSUIT_ALERT)
	_clear_roadblock()
	_roadblock_deploy_time = (
		ROADBLOCK_DEPLOY_DELAY if _pursuer.deploys_roadblock() else 0.0
	)
	_roadblock_deployed = not _pursuer.deploys_roadblock()
	_clear_pursuit_trap()
	_pursuit_trap_deploy_time = (
		_pursuer.pursuit_trap_deploy_delay()
		if _pursuer.deploys_pursuit_trap()
		else 0.0
	)
	_pursuit_trap_deployed = not _pursuer.deploys_pursuit_trap()


static func city_detour_active_for_clock(value: float) -> bool:
	var clock := fposmod(value, 1.0)
	return clock >= CITY_DETOUR_START and clock < CITY_DETOUR_END


func _update_city_detour(delta: float) -> void:
	var should_be_active := city_detour_active_for_clock(_day_clock)
	if not should_be_active:
		var was_visible := is_instance_valid(_city_detour)
		_clear_city_detour()
		if _city_detour_window_active and was_visible:
			_show_status("Water-main repairs cleared the road.")
		_city_detour_window_active = false
		_city_detour_retry_time = 0.0
		return
	if not _city_detour_window_active:
		_city_detour_window_active = true
		_city_detour_retry_time = 0.0
	if (
		not _active_interior_id.is_empty()
		or _current_district_coordinate
		!= DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
	):
		_clear_city_detour()
		return
	if is_instance_valid(_city_detour) or is_instance_valid(_roadblock):
		return
	_city_detour_retry_time = maxf(
		0.0,
		_city_detour_retry_time - maxf(0.0, delta)
	)
	if _city_detour_retry_time > 0.0:
		return
	if not _spawn_city_detour():
		_city_detour_retry_time = CITY_DETOUR_RETRY_DELAY


func _spawn_city_detour() -> bool:
	if is_instance_valid(_city_detour):
		return true
	if is_instance_valid(_roadblock):
		return false
	var configuration := _select_city_detour_anchor()
	if configuration.is_empty():
		return false
	var detour := CITY_DETOUR_SCRIPT.new() as PrototypeCityDetour
	detour.position = configuration["position"] as Vector2
	detour.configure(configuration["size"] as Vector2)
	_world.add_child(detour)
	_city_detour = detour
	_invalidate_navigation()
	_show_status("A water-main repair opened a marked detour.")
	return true


func _select_city_detour_anchor() -> Dictionary:
	for configuration_value in CITY_DETOUR_ANCHORS:
		var configuration := configuration_value as Dictionary
		if _city_detour_anchor_clear(configuration):
			return configuration
	return {}


func _city_detour_anchor_clear(configuration: Dictionary) -> bool:
	var roadblock_configuration := configuration.duplicate()
	roadblock_configuration["layout"] = PrototypeRoadblock.LAYOUT_STRAIGHT
	return _roadblock_anchor_clear(roadblock_configuration)


func _clear_city_detour() -> void:
	_city_detour_retry_time = 0.0
	if is_instance_valid(_city_detour):
		_city_detour.dismiss()
		_city_detour = null
		_invalidate_navigation()


func _city_detour_reserves_obstacle_slot() -> bool:
	return (
		is_instance_valid(_city_detour)
		or (
			city_detour_active_for_clock(_day_clock)
			and _active_interior_id.is_empty()
			and _current_district_coordinate
			== DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
		)
	)


func _update_pursuit_roadblock(delta: float) -> void:
	if not is_instance_valid(_pursuer):
		_clear_roadblock()
		return
	if not _pursuer.deploys_roadblock():
		_clear_roadblock()
		return
	if (
		_roadblock_deployed
		or _city_detour_reserves_obstacle_slot()
		or not _active_interior_id.is_empty()
		or not _frog.movement_enabled
		or _growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
	):
		return
	_roadblock_deploy_time = maxf(
		0.0,
		_roadblock_deploy_time - maxf(0.0, delta)
	)
	if _roadblock_deploy_time > 0.0:
		return
	_roadblock_deployed = _spawn_roadblock()


func _spawn_roadblock() -> bool:
	if is_instance_valid(_roadblock):
		return true
	if _city_detour_reserves_obstacle_slot():
		return false
	var configuration := _select_roadblock_anchor()
	if configuration.is_empty():
		return false
	var roadblock := ROADBLOCK_SCRIPT.new() as PrototypeRoadblock
	roadblock.position = configuration["position"] as Vector2
	roadblock.configure_layout(
		str(
			configuration.get(
				"layout",
				PrototypeRoadblock.LAYOUT_STRAIGHT
			)
		),
		configuration["size"] as Vector2
	)
	roadblock.removed.connect(_on_roadblock_removed)
	_world.add_child(roadblock)
	_roadblock = roadblock
	AudioDirector.play_effect(FrogAudioDirector.ROADBLOCK_DEPLOY)
	_invalidate_navigation()
	_show_status(
		"Animal Control deployed a %s!" % roadblock.display_name()
	)
	return true


func _select_roadblock_anchor() -> Dictionary:
	var selected := {}
	var selected_distance := INF
	for configuration_value in _current_roadblock_anchors():
		var configuration := configuration_value as Dictionary
		var position := configuration["position"] as Vector2
		var distance := position.distance_to(_frog.global_position)
		if (
			distance < ROADBLOCK_MIN_DISTANCE
			or distance > ROADBLOCK_MAX_DISTANCE
			or not _roadblock_anchor_clear(configuration)
		):
			continue
		if distance < selected_distance:
			selected = configuration
			selected_distance = distance
	return selected


func _roadblock_anchor_clear(configuration: Dictionary) -> bool:
	var position := configuration["position"] as Vector2
	var size := configuration["size"] as Vector2
	var layout_id := str(
		configuration.get(
			"layout",
			PrototypeRoadblock.LAYOUT_STRAIGHT
		)
	)
	var local_rects := PrototypeRoadblock.local_rects_for_layout(
		layout_id,
		size
	)
	var required_clearance := PrototypeRoadblock.SAFE_EDGE_CLEARANCE
	for local_rect in local_rects:
		var footprint := Rect2(
			position + local_rect.position,
			local_rect.size
		)
		if not _navigation_rect_for_position(position).encloses(
			footprint.grow(required_clearance)
		):
			return false
		var shape := RectangleShape2D.new()
		shape.size = footprint.size
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(
			0.0,
			footprint.get_center()
		)
		query.collision_mask = 1
		if not get_world_2d().direct_space_state.intersect_shape(
			query,
			16
		).is_empty():
			return false
		for building in _buildings:
			if (
				is_instance_valid(building)
				and not building.consumed
				and footprint.grow(24.0).intersects(
					building.footprint_rect()
				)
			):
				return false
			if (
				is_instance_valid(building)
				and not building.consumed
				and not building.transition_room_id.is_empty()
				and (
					_circle_overlaps_rect(
						building.transition_door_approach_position(),
						required_clearance,
						footprint
					)
					or _circle_overlaps_rect(
						building.transition_door_world_position(),
						required_clearance,
						footprint
					)
				)
			):
				return false
		for portal_value in CITY_EXPLORATION_PORTALS:
			var portal := portal_value as Dictionary
			if (
				_circle_overlaps_rect(
					portal["approach_position"] as Vector2,
					required_clearance,
					footprint
				)
				or _circle_overlaps_rect(
					portal["marker_position"] as Vector2,
					required_clearance,
					footprint
				)
			):
				return false
		for target in _targets:
			if (
				is_instance_valid(target)
				and target.kind != "building"
				and _circle_overlaps_rect(
					target.global_position,
					target.pick_radius + 24.0,
					footprint
				)
			):
				return false
	return true


func _handle_tongue_obstruction(
	obstruction: Dictionary,
	fallback_status: String
) -> void:
	_show_tongue(obstruction["position"] as Vector2)
	_tongue_recovery = _adjusted_tongue_recovery(TONGUE_RECOVERY)
	var collider := obstruction.get("collider") as Object
	if is_instance_valid(_pursuer) and collider == _pursuer:
		_pursuer.pulse_deflect()
		AudioDirector.play_effect(FrogAudioDirector.TONGUE_HIT)
		_show_status(_pursuer.protection_status())
		return
	if is_instance_valid(_roadblock) and collider == _roadblock:
		var roadblock := _roadblock
		var broken := roadblock.register_tongue_hit()
		AudioDirector.play_effect(FrogAudioDirector.TONGUE_HIT)
		AudioDirector.play_effect(
			FrogAudioDirector.ROADBLOCK_BREAK
			if broken
			else FrogAudioDirector.ROADBLOCK_HIT
		)
		if broken:
			_show_status("The Animal Control roadblock broke apart!")
		else:
			_show_status(
				"Roadblock hit! %d more tongue hits."
				% roadblock.remaining_hits()
			)
		return
	AudioDirector.play_effect(FrogAudioDirector.TONGUE_MISS)
	_show_status(fallback_status)


func _clear_roadblock() -> void:
	_roadblock_deploy_time = 0.0
	if is_instance_valid(_roadblock):
		_roadblock.dismiss(false)
	_roadblock = null


func _on_roadblock_removed(
	roadblock: PrototypeRoadblock,
	_broken: bool
) -> void:
	if _roadblock == roadblock:
		_roadblock = null
		_invalidate_navigation()


func _update_pursuit_trap(delta: float) -> void:
	if not is_instance_valid(_pursuer):
		_clear_pursuit_trap()
		return
	if not _pursuer.deploys_pursuit_trap():
		_clear_pursuit_trap()
		return
	if is_instance_valid(_pursuit_trap):
		_pursuit_trap.advance(maxf(0.0, delta))
		if _pursuit_trap.expired():
			_pursuit_trap.dismiss(false)
			return
		if _pursuit_trap_can_trigger() and (
			_pursuit_trap.global_position.distance_to(_frog.global_position)
			<= _pursuit_trap.radius() + _frog.collision_radius()
		):
			var triggered_trap := _pursuit_trap
			var source_position := triggered_trap.global_position
			var variant_id := triggered_trap.variant_id
			_pursuit_trap.dismiss(true)
			AudioDirector.play_effect(FrogAudioDirector.TRAP_TRIGGER)
			match variant_id:
				PrototypePursuitTrap.VARIANT_MOTION_BEACON:
					_pursuer.reveal_frog(
						_frog.global_position,
						PrototypePursuitTrap.BEACON_REVEAL_DURATION
					)
					_reset_crowd_hiding()
					_show_status(
						"The motion beacon revealed the frog to Security!"
					)
				PrototypePursuitTrap.VARIANT_STICKY_PATCH:
					_tongue_recovery = maxf(
						_tongue_recovery,
						_adjusted_tongue_recovery(
							PrototypePursuitTrap.STICKY_TONGUE_RECOVERY
						)
					)
					_show_status(
						"Sticky scent paste tangled the frog's tongue!"
					)
				_:
					_pursuer.cancel_active_attack()
					_apply_damage(
						source_position,
						GAMEPLAY_TUNING_SCRIPT.ANIMAL_CONTROL_TRAP_PENALTY,
						"An Animal Control snare knocked the frog back!",
						true
					)
		return
	if (
		_pursuit_trap_deployed
		or not _active_interior_id.is_empty()
		or not _frog.movement_enabled
		or _growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
	):
		return
	_pursuit_trap_deploy_time = maxf(
		0.0,
		_pursuit_trap_deploy_time - maxf(0.0, delta)
	)
	if _pursuit_trap_deploy_time > 0.0:
		return
	_pursuit_trap_deployed = _spawn_pursuit_trap()


func _pursuit_trap_can_trigger() -> bool:
	return (
		is_instance_valid(_pursuit_trap)
		and _pursuit_trap.is_armed()
		and (
			not _pursuit_trap.causes_damage()
			or _damage_cooldown <= 0.0
		)
		and _growth_tier < GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
		and not _frog.is_flying
		and not _power_state.is_active(TemporaryPowerState.CAMOUFLAGE)
		and not _frog.knockback_active()
		and _frog.movement_enabled
		and not _net_escape_active
		and not is_instance_valid(_struggle_target)
		and not is_instance_valid(_pull_target)
	)


func _spawn_pursuit_trap() -> bool:
	if is_instance_valid(_pursuit_trap):
		return true
	var position := _select_pursuit_trap_anchor()
	if position == Vector2.INF:
		return false
	var pursuit_trap := PURSUIT_TRAP_SCRIPT.new() as PrototypePursuitTrap
	pursuit_trap.configure_variant(_pursuer.pursuit_trap_variant())
	pursuit_trap.position = position
	pursuit_trap.set_presentation_motion_scale(_motion_scale)
	pursuit_trap.removed.connect(_on_pursuit_trap_removed)
	_world.add_child(pursuit_trap)
	_pursuit_trap = pursuit_trap
	AudioDirector.play_effect(FrogAudioDirector.TRAP_DEPLOY)
	_show_status(
		pursuit_trap.deployment_status(_pursuer.display_name())
	)
	return true


func _select_pursuit_trap_anchor() -> Vector2:
	var selected := Vector2.INF
	var selected_distance := INF
	for position_value in _current_pursuit_trap_anchors():
		var position := position_value as Vector2
		var distance := position.distance_to(_frog.global_position)
		if (
			distance < PURSUIT_TRAP_MIN_DISTANCE
			or distance > PURSUIT_TRAP_MAX_DISTANCE
			or not _pursuit_trap_anchor_clear(position)
		):
			continue
		if distance < selected_distance:
			selected = position
			selected_distance = distance
	return selected


func _pursuit_trap_anchor_clear(position: Vector2) -> bool:
	var variant_id := (
		_pursuer.pursuit_trap_variant()
		if is_instance_valid(_pursuer)
		else PrototypePursuitTrap.VARIANT_SNARE
	)
	var radius := (
		PrototypePursuitTrap.radius_for_variant(variant_id) + 18.0
	)
	if not _navigation_rect_for_position(position).grow(-radius).has_point(
		position
	):
		return false
	if not _circle_position_clear(position, radius, false):
		return false
	if _position_overlaps_target(position, radius, 12.0):
		return false
	return not _position_inside_building(position)


func _current_roadblock_anchors() -> Array:
	if (
		_current_district_coordinate
		== DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
	):
		return ROADBLOCK_ANCHORS
	return _district_definition(
		_current_district_coordinate
	).roadblock_anchors


func _current_pursuit_trap_anchors() -> Array:
	if (
		_current_district_coordinate
		== DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
	):
		return PURSUIT_TRAP_ANCHORS
	return _district_definition(
		_current_district_coordinate
	).pursuit_trap_anchors


func _clear_pursuit_trap() -> void:
	_pursuit_trap_deploy_time = 0.0
	if is_instance_valid(_pursuit_trap):
		_pursuit_trap.dismiss(false)
	_pursuit_trap = null


func _on_pursuit_trap_removed(
	pursuit_trap: PrototypePursuitTrap,
	_triggered: bool
) -> void:
	if _pursuit_trap == pursuit_trap:
		_pursuit_trap = null


func _find_pursuer_spawn_position(radius: float = 28.0) -> Vector2:
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
			candidate = _clamp_circle_to_world(candidate, radius)
			if _position_inside_building(candidate):
				continue
			if not _circle_position_clear(candidate, radius, false):
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


func _activate_next_ordered_building_part(
	building: PrototypeBuilding
) -> void:
	var configuration := (
		DESTRUCTIBLE_BUILDING_TARGETS.get(building.building_id, {})
		as Dictionary
	)
	if not bool(configuration.get("ordered", false)):
		return
	for part_configuration in configuration.get("parts", []):
		var part_data := part_configuration as Dictionary
		var part_id := str(part_data.get("part_id", ""))
		if part_id.is_empty():
			push_error(
				"Ordered destruction part is missing an ID for %s."
				% building.building_id
			)
			return
		if building.is_part_removed(part_id):
			continue
		var target_id := str(part_data.get("id", ""))
		var next_target := _find_target_by_id(target_id)
		if next_target == null:
			push_error(
				"Ordered destruction target %s is missing for %s."
				% [target_id, building.building_id]
			)
			return
		next_target.visible = true
		next_target.selectable = true
		return
	if not building.is_ready_to_swallow():
		push_error(
			"No remaining ordered part could be activated for %s."
			% building.building_id
		)


func _on_pursuer_caught(source_position: Vector2) -> void:
	if _net_escape_active:
		_clear_net_escape()
	if not is_instance_valid(_pursuer):
		return
	_apply_damage(
		source_position,
		_pursuer.contact_penalty(),
		"%s caught you! You lost some points."
		% _pursuer.display_name(),
		true
	)


func _on_pursuer_attack_hit(
	source_position: Vector2,
	penalty: int,
	message: String
) -> void:
	_apply_damage(source_position, penalty, message, true)


func _on_pursuer_attack_started(attack_id: StringName) -> void:
	var effect_id := FrogAudioDirector.NET_WARNING
	match attack_id:
		PrototypePursuer.ATTACK_FLASHLIGHT:
			effect_id = FrogAudioDirector.FLASHLIGHT_WARNING
		PrototypePursuer.ATTACK_LUNGE:
			effect_id = FrogAudioDirector.WATCHDOG_LUNGE
		PrototypePursuer.ATTACK_NET:
			pass
		_:
			push_warning("Unknown pursuer attack audio event: %s" % attack_id)
			return
	AudioDirector.play_effect(effect_id)


func _on_pursuer_netted(source_position: Vector2) -> void:
	if (
		_frog.growth_tier >= GAMEPLAY_TUNING_SCRIPT.ENORMOUS_TIER
		or _frog.is_flying
	):
		if is_instance_valid(_pursuer):
			_pursuer.set_frog_netted(false)
		return
	if _power_state.consume(TemporaryPowerState.BUBBLE_SHIELD):
		if is_instance_valid(_pursuer):
			_pursuer.set_frog_netted(false)
			_pursuer.cancel_active_attack()
		_update_power_label()
		AudioDirector.play_effect(FrogAudioDirector.SHIELD_POP)
		_show_status("The Bubble Shield popped Animal Control's net!")
		return
	if is_instance_valid(_struggle_target):
		_fail_struggle()
	if is_instance_valid(_pull_target):
		_cancel_pull()
	_net_escape_active = true
	_net_escape_taps = 0
	_net_escape_required_taps = (
		AccessibilityPresentation.assisted_struggle_taps(
			NET_ESCAPE_TAPS,
			_input_assist_mode
		)
	)
	_net_escape_time_left = NET_ESCAPE_DURATION
	_net_source_position = source_position
	_struggle_progress.max_value = _net_escape_required_taps
	_struggle_progress.value = 0
	_struggle_title.text = "Caught in Animal Control's net!"
	_struggle_hint.text = _struggle_input_hint()
	_struggle_panel.visible = true
	_cancel_frog_navigation()
	_frog.movement_enabled = false
	_reset_touch_input_state()
	_show_status("Animal Control netted you! Tap rapidly to escape.")


func _update_net_escape(delta: float) -> void:
	if not _net_escape_active or delta <= 0.0:
		return
	_net_escape_time_left = maxf(0.0, _net_escape_time_left - delta)
	if _net_escape_time_left <= 0.0:
		_fail_net_escape()


func _register_net_escape_tap() -> void:
	if not _net_escape_active:
		return
	AudioDirector.play_effect(FrogAudioDirector.STRUGGLE_TAP)
	_play_haptic(12)
	_net_escape_taps += 1
	_struggle_progress.value = _net_escape_taps
	if is_instance_valid(_pursuer):
		_pursuer.pulse_net()
	if _net_escape_taps >= _net_escape_required_taps:
		_complete_net_escape()


func _complete_net_escape() -> void:
	if not _net_escape_active:
		return
	_clear_net_escape()
	_show_status("You tore through Animal Control's net!")


func _fail_net_escape() -> void:
	var source_position := _net_source_position
	var damage_blocked := _damage_cooldown > 0.0
	_clear_net_escape()
	if damage_blocked:
		_show_status("The net tightened, but the frog was still recovering.")
		return
	_apply_damage(
		source_position,
		GAMEPLAY_TUNING_SCRIPT.ANIMAL_CONTROL_NET_PENALTY,
		"Animal Control tightened the net! You lost some points.",
		true
	)


func _clear_net_escape() -> void:
	_net_escape_active = false
	_net_escape_taps = 0
	_net_escape_required_taps = NET_ESCAPE_TAPS
	_net_escape_time_left = 0.0
	_end_assisted_hold()
	_net_source_position = Vector2.ZERO
	_struggle_panel.visible = false
	_struggle_title.text = TARGET_STRUGGLE_TITLE
	_struggle_hint.text = TARGET_STRUGGLE_HINT
	_frog.movement_enabled = true
	if is_instance_valid(_pursuer):
		_pursuer.set_frog_netted(false)


func _on_pursuer_escaped() -> void:
	if _net_escape_active:
		_clear_net_escape()
	var pursuer_name := (
		_pursuer.display_name()
		if is_instance_valid(_pursuer)
		else "The pursuer"
	)
	AudioDirector.set_pursuit(self, false)
	AudioDirector.play_effect(FrogAudioDirector.PURSUIT_ESCAPE)
	_pursuer = null
	_clear_roadblock()
	_clear_pursuit_trap()
	_reset_crowd_hiding()
	_show_status("You escaped %s!" % pursuer_name)


func _is_actively_chased() -> bool:
	return (
		is_instance_valid(_pursuer)
		and _pursuer.active
		and _pursuer.global_position.distance_to(_frog.global_position) < 920.0
	)


func _can_swallow_pursuer() -> bool:
	return (
		_growth_tier
		>= GAMEPLAY_TUNING_SCRIPT.PURSUER_EDIBLE_TIER
	)


func _swallow_pursuer(pursuer: PrototypePursuer, accuracy: float) -> void:
	if _net_escape_active:
		_clear_net_escape()
	_reset_crowd_hiding()
	var effect_position := pursuer.global_position
	var belly_data := pursuer.belly_data()
	var item := BellyItem.new()
	item.target_id = str(belly_data["id"])
	item.display_name = str(belly_data["name"])
	item.kind = "living"
	item.base_value = int(belly_data["value"])
	item.size_tier = GAMEPLAY_TUNING_SCRIPT.PURSUER_EDIBLE_TIER
	item.resistant = true
	item.taps_required = int(belly_data["taps"])
	item.pick_radius = 40.0
	item.accuracy = accuracy
	item.captured_while_chased = true
	item.target_color = belly_data["color"] as Color
	item.movement_bounds = DISTRICT_GENERATOR_SCRIPT.bounds_for_coordinate(
		_current_district_coordinate
	).grow(-100)
	item.district_coordinate = _current_district_coordinate
	item.restockable = false
	_record_discovery(item.target_id, item.display_name)
	_challenges.record_swallow(item.target_id, item.accuracy)
	_update_challenge_hud()
	_record_event_goals_for_swallow()
	_belly.append(item)
	pursuer.active = false
	pursuer.queue_free()
	AudioDirector.set_pursuit(self, false)
	_pursuer = null
	_clear_roadblock()
	_clear_pursuit_trap()
	AudioDirector.play_effect(FrogAudioDirector.SWALLOW)
	_play_haptic(36)
	_frog.celebrate_swallow()
	_effects.emit_swallow(effect_position, item.target_color)
	_tongue_recovery = _adjusted_tongue_recovery(TONGUE_RECOVERY)
	_update_hud()
	_show_status(
		"You swallowed %s! Digest or return them safely."
		% item.display_name
	)


func _start_pull(target: EdibleTarget, hit_offset: Vector2) -> void:
	_pull_target = target
	_pull_time_left = 1.8
	_pull_hit_offset = hit_offset
	_cancel_frog_navigation()
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
	_tongue_recovery = _adjusted_tongue_recovery(TONGUE_RECOVERY)


func _queue_living_respawn(item: BellyItem) -> void:
	if not item.restockable:
		return
	if item.kind == "living":
		_respawn_living_later(item)
	else:
		_restock_target_later(item)


func _apply_digest_effects(item: BellyItem) -> void:
	_queue_living_respawn(item)
	var power_entry := ProgressionCatalog.power_for_target(item.target_id)
	if not power_entry.is_empty():
		_activate_power(str(power_entry["id"]))


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
	target.dangerous_location = _belly_item_retains_danger(item)
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
	target.dangerous_location = _belly_item_retains_danger(item)
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
		if _position_overlaps_target(candidate, radius, 60.0):
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


func _activate_power(power_id: String, duration: float = -1.0) -> void:
	var entry := ProgressionCatalog.power_entry(power_id)
	if entry.is_empty():
		push_warning("Cannot activate unknown temporary power '%s'." % power_id)
		return
	_power_state.activate(power_id, duration)
	AudioDirector.play_effect(FrogAudioDirector.POWER_ACTIVATE)
	if not _power_discoveries.has(power_id):
		_power_discoveries[power_id] = true
		power_discovered.emit(power_id)
		_evaluate_profile_achievements()
	var clue_id := ProgressionCatalog.story_clue_for_power(power_id)
	if not clue_id.is_empty():
		_record_story_clue(clue_id)
	if power_id == TemporaryPowerState.FLIGHT:
		_start_flight()
	_apply_power_effects()
	_show_status(_power_activation_message(power_id))
	_update_power_label()


func _activate_flight(duration: float) -> void:
	_activate_power(TemporaryPowerState.FLIGHT, duration)


func _start_flight() -> void:
	var destination := _frog_route_requested_destination
	_cancel_frog_navigation()
	_frog.set_flying(true)
	if destination != Vector2.INF:
		_frog_route_requested_destination = destination
		_frog.move_to(
			_clamp_circle_to_world(destination, _frog.collision_radius())
		)


func _update_powers(delta: float) -> void:
	var expired := _power_state.advance(delta)
	if expired.has(TemporaryPowerState.FLIGHT):
		if not _land_frog_safely():
			_power_state.set_remaining(TemporaryPowerState.FLIGHT, 0.5)
			_show_status("Fly to an open area so the frog can land safely.")
		else:
			_frog.set_flying(false)
			if _frog._has_move_target:
				var destination := _frog._move_target
				_frog.stop_moving()
				_request_frog_navigation(destination, false)
			_show_status("The flight power wore off.")
	_apply_power_effects()
	_update_power_label()


func _apply_power_effects() -> void:
	_frog.set_ground_speed_multiplier(
		1.35
		if _power_state.is_active(TemporaryPowerState.SPEED_BURST)
		else 1.0
	)
	_frog.set_tongue_range_multiplier(
		1.4
		if _power_state.is_active(TemporaryPowerState.LONG_TONGUE)
		else 1.0
	)
	if is_instance_valid(_pursuer):
		_pursuer.set_frog_camouflaged(
			_power_state.is_active(TemporaryPowerState.CAMOUFLAGE)
		)


func _adjusted_tongue_recovery(duration: float) -> float:
	return (
		duration * 0.8
		if _power_state.is_active(TemporaryPowerState.LONG_TONGUE)
		else duration
	)


func _power_activation_message(power_id: String) -> String:
	match power_id:
		TemporaryPowerState.FLIGHT:
			return "Flight power! The frog can fly over walls for one minute."
		TemporaryPowerState.SPEED_BURST:
			return "Speed Burst! Ground movement is faster for 20 seconds."
		TemporaryPowerState.LONG_TONGUE:
			return "Long Tongue! Range is longer and recovery is faster for 30 seconds."
		TemporaryPowerState.CAMOUFLAGE:
			return "Camouflage! Pursuers lose the frog for 20 seconds."
		TemporaryPowerState.BUBBLE_SHIELD:
			return "Bubble Shield! The next pursuit hit is blocked."
	return "Temporary power activated."


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
	var labels := PackedStringArray()
	var abbreviations := {
		TemporaryPowerState.FLIGHT: "F",
		TemporaryPowerState.SPEED_BURST: "S",
		TemporaryPowerState.LONG_TONGUE: "T",
		TemporaryPowerState.CAMOUFLAGE: "C",
		TemporaryPowerState.BUBBLE_SHIELD: "B",
	}
	for power_id in _power_state.active_ids():
		labels.append(
			"%s%d" % [
				abbreviations[power_id],
				ceili(_power_state.remaining(power_id)),
			]
		)
	_power_label.text = " ".join(labels)


func _update_day_night(delta: float) -> void:
	_day_clock = fmod(_day_clock + delta / 180.0, 1.0)
	var daylight := (sin(_day_clock * TAU - PI / 2.0) + 1.0) * 0.5
	_current_daylight = daylight
	var night_color := Color(0.44, 0.56, 0.78)
	var clear_color := night_color.lerp(Color.WHITE, 0.38 + daylight * 0.62)
	var rain_intensity := rain_intensity_for_clock(_day_clock)
	var wind_intensity := wind_squall_intensity_for_clock(_day_clock)
	var crowd_intensity := crowd_intensity_for_clock(_day_clock)
	var festival_intensity := festival_intensity_for_clock(_day_clock)
	var kite_festival_intensity := kite_festival_intensity_for_clock(
		_day_clock
	)
	_current_rain_intensity = rain_intensity
	_current_wind_intensity = wind_intensity
	_current_crowd_intensity = crowd_intensity
	_current_kite_festival_intensity = kite_festival_intensity
	var weather_color := clear_color.lerp(
		Color(0.68, 0.76, 0.84),
		rain_intensity * 0.3
	)
	_world_tint.color = weather_color.lerp(
		Color(0.82, 0.88, 0.9),
		wind_intensity * 0.12
	)
	if is_instance_valid(_city_activity):
		_city_activity.set_daylight(daylight)
		_city_activity.set_rain_intensity(rain_intensity)
		_city_activity.set_wind_intensity(wind_intensity)
		_city_activity.set_crowd_intensity(crowd_intensity)
		_city_activity.set_festival_intensity(festival_intensity)
		_city_activity.set_kite_festival_intensity(
			kite_festival_intensity
		)
	_update_oddities_shop_schedule()
	_update_moonlight_market_schedule()
	AudioDirector.set_game_ambience(
		self,
		daylight < NIGHT_AUDIO_THRESHOLD
	)


static func rain_intensity_for_clock(value: float) -> float:
	var clock := fposmod(value, 1.0)
	if clock < RAIN_START or clock > RAIN_END:
		return 0.0
	if clock < RAIN_FULL_START:
		return smoothstep(RAIN_START, RAIN_FULL_START, clock)
	if clock > RAIN_FULL_END:
		return 1.0 - smoothstep(RAIN_FULL_END, RAIN_END, clock)
	return 1.0


static func wind_squall_intensity_for_clock(value: float) -> float:
	var clock := fposmod(value, 1.0)
	if clock < WIND_START or clock > WIND_END:
		return 0.0
	if clock < WIND_FULL_START:
		return smoothstep(WIND_START, WIND_FULL_START, clock)
	if clock > WIND_FULL_END:
		return 1.0 - smoothstep(WIND_FULL_END, WIND_END, clock)
	return 1.0


static func kite_festival_intensity_for_clock(value: float) -> float:
	var clock := fposmod(value, 1.0)
	if clock < KITE_FESTIVAL_START or clock > KITE_FESTIVAL_END:
		return 0.0
	if clock < KITE_FESTIVAL_FULL_START:
		return smoothstep(
			KITE_FESTIVAL_START,
			KITE_FESTIVAL_FULL_START,
			clock
		)
	if clock > KITE_FESTIVAL_FULL_END:
		return 1.0 - smoothstep(
			KITE_FESTIVAL_FULL_END,
			KITE_FESTIVAL_END,
			clock
		)
	return 1.0


static func crowd_intensity_for_clock(value: float) -> float:
	var clock := fposmod(value, 1.0)
	if clock < CROWD_START or clock > CROWD_END:
		return 0.0
	if clock < CROWD_FULL_START:
		return smoothstep(CROWD_START, CROWD_FULL_START, clock)
	if clock > CROWD_FULL_END:
		return 1.0 - smoothstep(CROWD_FULL_END, CROWD_END, clock)
	return 1.0


static func festival_intensity_for_clock(value: float) -> float:
	var clock := fposmod(value, 1.0)
	if clock >= FESTIVAL_START:
		if clock < FESTIVAL_FULL_START:
			return smoothstep(
				FESTIVAL_START,
				FESTIVAL_FULL_START,
				clock
			)
		return 1.0
	if clock <= FESTIVAL_END:
		if clock > FESTIVAL_FULL_END:
			return 1.0 - smoothstep(
				FESTIVAL_FULL_END,
				FESTIVAL_END,
				clock
			)
		return 1.0
	return 0.0


static func oddities_shop_open_for_clock(value: float) -> bool:
	var clock := fposmod(value, 1.0)
	return (
		clock >= ODDITIES_SHOP_OPEN_START
		or clock <= ODDITIES_SHOP_OPEN_END
	)


static func moonlight_market_open_for_clock(value: float) -> bool:
	var clock := fposmod(value, 1.0)
	return (
		clock >= MOONLIGHT_MARKET_OPEN_START
		and clock < MOONLIGHT_MARKET_OPEN_END
	)


func _update_oddities_shop_schedule() -> void:
	var shop := (
		_building_by_id.get("oddities_shop") as PrototypeBuilding
	)
	if not is_instance_valid(shop):
		return
	if shop.consumed:
		_oddities_shop_scheduled_open = false
		return
	if shop.is_part_removed(PrototypeBuilding.PART_DOOR):
		shop.set_entrance_part_temporarily_open(false)
		_oddities_shop_scheduled_open = false
		return
	var should_open := oddities_shop_open_for_clock(_day_clock)
	if (
		not should_open
		and _scheduled_shop_doorway_occupied(
			shop,
			ODDITIES_CELLAR_ID
		)
	):
		should_open = true
	_set_oddities_shop_scheduled_open(shop, should_open)


func _update_moonlight_market_schedule() -> void:
	var market := (
		_building_by_id.get("moonlight_market") as PrototypeBuilding
	)
	if not is_instance_valid(market):
		return
	if market.consumed:
		_moonlight_market_scheduled_open = false
		return
	if market.is_part_removed(PrototypeBuilding.PART_DOOR):
		market.set_entrance_part_temporarily_open(false)
		_moonlight_market_scheduled_open = false
		return
	var should_open := moonlight_market_open_for_clock(_day_clock)
	if (
		not should_open
		and _scheduled_shop_doorway_occupied(
			market,
			MARKET_ROOFTOP_ID
		)
	):
		should_open = true
	_set_moonlight_market_scheduled_open(market, should_open)


func _scheduled_shop_doorway_occupied(
	shop: PrototypeBuilding,
	connected_room_id: String
) -> bool:
	if _active_interior_id == connected_room_id:
		return true
	var doorway := shop.entrance_part_world_rect().grow(
		SHOP_DOORWAY_CLEARANCE
	)
	if (
		shop.contains_world_point(_frog.global_position)
		or _circle_overlaps_rect(
			_frog.global_position,
			_frog.collision_radius(),
			doorway
		)
	):
		return true
	if not is_instance_valid(_pursuer):
		return false
	return (
		shop.contains_world_point(_pursuer.global_position)
		or _circle_overlaps_rect(
			_pursuer.global_position,
			_pursuer.collision_radius(),
			doorway
		)
	)


func _set_oddities_shop_scheduled_open(
	shop: PrototypeBuilding,
	value: bool
) -> void:
	if (
		_oddities_shop_scheduled_open == value
		and shop.entrance_part_temporarily_open == value
	):
		return
	_oddities_shop_scheduled_open = value
	_set_scheduled_shop_entrance(
		shop,
		"oddities_shop_door",
		value,
		"Oddities Shop opened for the night.",
		"Oddities Shop closed for the day."
	)


func _set_moonlight_market_scheduled_open(
	market: PrototypeBuilding,
	value: bool
) -> void:
	if (
		_moonlight_market_scheduled_open == value
		and market.entrance_part_temporarily_open == value
	):
		return
	_moonlight_market_scheduled_open = value
	_set_scheduled_shop_entrance(
		market,
		"moonlight_market_door",
		value,
		"Moonlight Market opened for the day.",
		"Moonlight Market closed as the rain arrived."
	)


func _set_scheduled_shop_entrance(
	shop: PrototypeBuilding,
	entrance_target_id: String,
	value: bool,
	open_message: String,
	closed_message: String
) -> void:
	shop.set_entrance_part_temporarily_open(value)
	var entrance_target := _find_target_by_id(entrance_target_id)
	if is_instance_valid(entrance_target):
		entrance_target.visible = not value
		entrance_target.selectable = not value
	_show_status(open_message if value else closed_message)


func _update_crowd_hiding(delta: float) -> void:
	var can_attempt_hide := (
		is_instance_valid(_pursuer)
		and _pursuer.active
		and _active_interior_id.is_empty()
		and _growth_tier < 2
		and not _frog.is_flying
		and not _frog.knockback_active()
		and _frog.movement_enabled
		and not _net_escape_active
		and not is_instance_valid(_struggle_target)
		and not is_instance_valid(_pull_target)
		and is_instance_valid(_city_activity)
		and _city_activity.crowd_cover_available()
	)
	if is_instance_valid(_city_activity):
		_city_activity.set_crowd_cover_chase_active(can_attempt_hide)
	if not can_attempt_hide:
		_reset_crowd_hiding()
		return
	if not _city_activity.crowd_cover_contains(_frog.global_position):
		_reset_crowd_hide_progress()
		return
	if _crowd_hide_time <= 0.0:
		_show_status(
			"Stay in the River Park crowd to lose %s."
			% _pursuer.display_name()
		)
	var hide_duration := _pursuer.crowd_escape_duration()
	_crowd_hide_time = minf(
		hide_duration,
		_crowd_hide_time + maxf(0.0, delta)
	)
	_city_activity.set_crowd_hide_progress(
		_crowd_hide_time / hide_duration
	)
	if _crowd_hide_time < hide_duration:
		return
	var pursuer := _pursuer
	var pursuer_name := pursuer.display_name()
	_reset_crowd_hiding()
	pursuer._escape()
	_show_status("%s lost you in the River Park crowd!" % pursuer_name)


func _reset_crowd_hiding() -> void:
	_reset_crowd_hide_progress()
	if is_instance_valid(_city_activity):
		_city_activity.set_crowd_cover_chase_active(false)


func _reset_crowd_hide_progress() -> void:
	_crowd_hide_time = 0.0
	if is_instance_valid(_city_activity):
		_city_activity.set_crowd_hide_progress(0.0)


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
	var preferences := _accessibility_preferences_from_controls()
	var previous_input_assist_mode := _input_assist_mode
	_reduce_motion_enabled = bool(preferences["reduce_motion"])
	_larger_text_controls_enabled = bool(
		preferences["larger_text_controls"]
	)
	_input_assist_mode = str(preferences["input_assist_mode"])
	_camera_sensitivity = float(preferences["camera_sensitivity"])
	_camera_auto_align_enabled = bool(preferences["camera_auto_align"])
	_haptics_enabled = bool(preferences["haptics_enabled"])
	_left_handed_hud_enabled = bool(preferences["left_handed_hud"])
	if _input_assist_mode != previous_input_assist_mode:
		_refresh_active_input_assistance()
	_apply_motion_scale(0.0 if _reduce_motion_enabled else 1.0)
	_apply_accessibility_presentation()
	_apply_safe_area()
	_update_accessibility_controls()
	accessibility_changed.emit(preferences)
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)
	_play_haptic(16)


func _on_accessibility_option_selected(_index: int) -> void:
	_on_accessibility_toggled(false)


func _on_camera_sensitivity_changed(_value: float) -> void:
	_on_accessibility_toggled(false)


func _refresh_active_input_assistance() -> void:
	_end_assisted_hold()
	_struggle_hint.text = _struggle_input_hint()
	if is_instance_valid(_struggle_target):
		_struggle_required_taps = (
			AccessibilityPresentation.assisted_struggle_taps(
				GAMEPLAY_TUNING_SCRIPT.struggle_taps_required(
					_struggle_target.taps_required,
					_struggle_target.size_tier,
					_growth_tier
				),
				_input_assist_mode
			)
		)
		_struggle_progress.max_value = _struggle_required_taps
		_struggle_progress.value = _struggle_taps
		if _struggle_taps >= _struggle_required_taps:
			_complete_struggle()
	elif _net_escape_active:
		_net_escape_required_taps = (
			AccessibilityPresentation.assisted_struggle_taps(
				NET_ESCAPE_TAPS,
				_input_assist_mode
			)
		)
		_struggle_progress.max_value = _net_escape_required_taps
		_struggle_progress.value = _net_escape_taps
		if _net_escape_taps >= _net_escape_required_taps:
			_complete_net_escape()


func _update_accessibility_controls() -> void:
	_refreshing_accessibility_controls = true
	_reduce_motion_toggle.button_pressed = _reduce_motion_enabled
	_larger_ui_toggle.button_pressed = _larger_text_controls_enabled
	_select_input_assist_mode(_input_assist_mode)
	_camera_sensitivity_slider.value = _camera_sensitivity * 100.0
	_camera_auto_align_toggle.button_pressed = _camera_auto_align_enabled
	_haptics_toggle.button_pressed = _haptics_enabled
	_left_handed_toggle.button_pressed = _left_handed_hud_enabled
	_reduce_motion_toggle.text = "Reduce motion: %s" % (
		"On" if _reduce_motion_enabled else "Off"
	)
	_larger_ui_toggle.text = "Larger text & controls: %s" % (
		"On" if _larger_text_controls_enabled else "Off"
	)
	_camera_sensitivity_label.text = "Camera sensitivity: %d%%" % roundi(
		_camera_sensitivity * 100.0
	)
	_camera_auto_align_toggle.text = "Camera auto-align: %s" % (
		"On" if _camera_auto_align_enabled else "Off"
	)
	_haptics_toggle.text = "Haptics: %s" % (
		"On" if _haptics_enabled else "Off"
	)
	_left_handed_toggle.text = "Left-handed HUD: %s" % (
		"On" if _left_handed_hud_enabled else "Off"
	)
	match _input_assist_mode:
		AccessibilityPresentation.INPUT_ASSIST_RELAXED:
			_instructions_label.text = (
				"Tap to move. Double-tap targets with extra time. "
				+ "Turn with two fingers. Tap to struggle."
			)
		AccessibilityPresentation.INPUT_ASSIST_HOLD:
			_instructions_label.text = (
				"Tap to move. Hold a target for tongue. "
				+ "Turn with two fingers. Hold to struggle."
			)
		_:
			_instructions_label.text = (
				"Tap to move. Double-tap a target to eat. "
				+ "Turn with two fingers."
			)
	_refreshing_accessibility_controls = false


func _populate_input_assist_options() -> void:
	_input_assist_option.clear()
	for mode in AccessibilityPresentation.INPUT_ASSIST_MODES:
		_input_assist_option.add_item(
			AccessibilityPresentation.input_assist_label(mode)
		)
		_input_assist_option.set_item_metadata(
			_input_assist_option.item_count - 1,
			mode
		)


func _select_input_assist_mode(mode: String) -> void:
	for index in _input_assist_option.item_count:
		if str(_input_assist_option.get_item_metadata(index)) == mode:
			_input_assist_option.select(index)
			return
	_input_assist_option.select(0)


func _accessibility_preferences_from_controls() -> Dictionary:
	return AccessibilityPresentation.sanitize_preferences({
		"reduce_motion": _reduce_motion_toggle.button_pressed,
		"larger_text_controls": _larger_ui_toggle.button_pressed,
		"input_assist_mode": str(
			_input_assist_option.get_item_metadata(
				_input_assist_option.selected
			)
		),
		"camera_sensitivity": _camera_sensitivity_slider.value / 100.0,
		"camera_auto_align": _camera_auto_align_toggle.button_pressed,
		"haptics_enabled": _haptics_toggle.button_pressed,
		"left_handed_hud": _left_handed_toggle.button_pressed,
	})


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
	_apply_hud_handedness()


func _apply_hud_handedness() -> void:
	var ordered_nodes: Array[Control]
	if _left_handed_hud_enabled:
		ordered_nodes = [
			_guide_button,
			_belly_button,
			_options_button,
			_end_button,
			_top_bar_spacer,
			_profile_slot,
			_score_label,
			_growth_label,
			_power_label,
		]
	else:
		ordered_nodes = [
			_profile_slot,
			_score_label,
			_growth_label,
			_power_label,
			_top_bar_spacer,
			_guide_button,
			_belly_button,
			_options_button,
			_end_button,
		]
	for index in ordered_nodes.size():
		_top_bar.move_child(ordered_nodes[index], index)


func _play_haptic(duration_msec: int) -> void:
	AccessibilityPresentation.play_haptic(
		_haptics_enabled,
		duration_msec
	)


func _default_status_text() -> String:
	match _input_assist_mode:
		AccessibilityPresentation.INPUT_ASSIST_RELAXED:
			return "Tap to move. Double-tap targets with extra time to eat."
		AccessibilityPresentation.INPUT_ASSIST_HOLD:
			return "Tap to move. Press and hold a target to eat."
		_:
			return "Tap the ground to move. Double-tap a target to eat it."


func _struggle_input_hint() -> String:
	return (
		"Press and hold anywhere!"
		if (
			_input_assist_mode
			== AccessibilityPresentation.INPUT_ASSIST_HOLD
		)
		else TARGET_STRUGGLE_HINT
	)


func _apply_safe_area() -> void:
	apply_safe_area_insets(
		AccessibilityPresentation.current_safe_area_insets(
			get_viewport_rect().size
		)
	)


func apply_safe_area_insets(insets: Vector4) -> void:
	_safe_area_insets = insets
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
	_apply_save_warning_layout()

	if _left_handed_hud_enabled:
		_control_legend.anchor_left = 0.0
		_control_legend.anchor_right = 0.0
		_control_legend.offset_left = 22.0 + left
		_control_legend.offset_top = -104.0 - bottom
		_control_legend.offset_right = 500.0 + left
		_control_legend.offset_bottom = -18.0 - bottom
		_instructions_label.offset_left = 34.0 + left
		_instructions_label.offset_top = -96.0 - bottom
		_instructions_label.offset_right = 488.0 + left
		_instructions_label.offset_bottom = -26.0 - bottom
		_tutorial_panel.anchor_left = 0.0
		_tutorial_panel.anchor_right = 0.0
		_tutorial_panel.offset_left = 24.0 + left
		_tutorial_panel.offset_top = -348.0 - bottom
		_tutorial_panel.offset_right = 610.0 + left
		_tutorial_panel.offset_bottom = -24.0 - bottom
	else:
		_control_legend.anchor_left = 1.0
		_control_legend.anchor_right = 1.0
		_control_legend.offset_left = -500.0 - right
		_control_legend.offset_top = -104.0 - bottom
		_control_legend.offset_right = -22.0 - right
		_control_legend.offset_bottom = -18.0 - bottom
		_instructions_label.offset_left = -488.0 - right
		_instructions_label.offset_top = -96.0 - bottom
		_instructions_label.offset_right = -34.0 - right
		_instructions_label.offset_bottom = -26.0 - bottom
		_tutorial_panel.anchor_left = 1.0
		_tutorial_panel.anchor_right = 1.0
		_tutorial_panel.offset_left = -610.0 - right
		_tutorial_panel.offset_top = -348.0 - bottom
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
	if is_instance_valid(_score_epilogue):
		_score_epilogue.apply_safe_area_insets(insets)


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
	var search_distances := [60.0, 110.0, 170.0, 240.0]
	if radius >= PlayerFrog.TIER_RADII[PlayerFrog.ENORMOUS_TIER]:
		search_distances.append_array([320.0, 420.0])
	for distance in search_distances:
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
	var bounds := _navigation_rect_for_position(position)
	if not bounds.grow(-radius).has_point(position):
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
	var inset := _active_navigation_rect().grow(-radius)
	return Vector2(
		clampf(position.x, inset.position.x, inset.end.x),
		clampf(position.y, inset.position.y, inset.end.y)
	)


func _request_frog_navigation(
	destination: Vector2,
	show_unreachable_status: bool = true,
	allow_fallback: bool = true
) -> Dictionary:
	var failed := {
		"requested_destination": destination,
		"resolved_destination": _frog.global_position,
		"reachable": false,
		"fallback": true,
		"revision": _navigation.revision(),
		"points": PackedVector2Array(),
	}
	if not _frog.movement_enabled or _frog.knockback_active():
		return failed
	_frog_route_requested_destination = destination
	if _frog.is_flying:
		var flight_destination := _clamp_circle_to_world(
			destination,
			_frog.collision_radius()
		)
		_frog.move_to(flight_destination)
		_frog_route_fallback = not flight_destination.is_equal_approx(
			destination
		)
		_touch_feedback.show_move(flight_destination)
		failed["resolved_destination"] = flight_destination
		failed["reachable"] = not _frog_route_fallback
		failed["fallback"] = _frog_route_fallback
		failed["points"] = PackedVector2Array([
			_frog.global_position,
			flight_destination,
		])
		return failed

	_refresh_navigation_geometry()
	var route := _navigation.find_path(
		_frog.global_position,
		destination,
		_frog.collision_radius()
	)
	var points := route["points"] as PackedVector2Array
	if (
		points.is_empty()
		or (not allow_fallback and not bool(route["reachable"]))
		or not _frog.follow_path(
		points,
		int(route["revision"])
		)
	):
		_cancel_frog_navigation()
		if show_unreachable_status:
			_show_status("No safe route is available from here.")
		return route
	_frog_route_fallback = bool(route["fallback"])
	var resolved := route["resolved_destination"] as Vector2
	_touch_feedback.show_move(resolved)
	if _frog_route_fallback and show_unreachable_status:
		_show_status(
			"That spot is blocked. Moving to the nearest reachable place."
		)
	return route


func _cancel_frog_navigation() -> void:
	_frog_route_requested_destination = Vector2.INF
	_frog_route_fallback = false
	_pending_interior_transition = ""
	_pending_interior_portal_id = ""
	if is_instance_valid(_frog):
		_frog.stop_moving()


func _invalidate_navigation() -> void:
	_navigation_dirty = true
	if (
		is_instance_valid(_frog)
		and _frog.has_active_path()
	):
		_frog.stop_moving()
	if (
		is_instance_valid(_pursuer)
		and _pursuer.has_method("invalidate_navigation")
	):
		_pursuer.call("invalidate_navigation")


func _update_navigation_paths() -> void:
	if not _navigation_dirty:
		return
	var pending_destination := _frog_route_requested_destination
	_refresh_navigation_geometry()
	if (
		pending_destination == Vector2.INF
		or not _frog.movement_enabled
		or _frog.is_flying
		or _frog.knockback_active()
		or is_instance_valid(_struggle_target)
		or is_instance_valid(_pull_target)
		or _net_escape_active
		or _interior_transition_phase != InteriorTransitionPhase.NONE
	):
		return
	var route := _request_frog_navigation(pending_destination, false)
	if (
		not _pending_interior_transition.is_empty()
		and not bool(route["reachable"])
	):
		_pending_interior_transition = ""
		_cancel_frog_navigation()
		_show_status("The route changed and no longer reaches that entrance.")
		return
	if not bool(route["reachable"]) and (
		route["points"] as PackedVector2Array
	).is_empty():
		_show_status("The route changed and no safe path remains.")
	elif bool(route["fallback"]):
		_show_status(
			"The route changed. Moving to the nearest reachable place."
		)


func _refresh_navigation_geometry() -> void:
	if not _navigation_dirty:
		return
	var bounds := _active_navigation_rect()
	var obstacles: Array[Rect2] = []
	if not _active_interior_id.is_empty():
		var room := (
			_interior_rooms.get(_active_interior_id) as PrototypeInteriorRoom
		)
		if is_instance_valid(room):
			for rect in room.navigation_obstacle_rects():
				if rect.intersects(bounds):
					obstacles.append(rect)
	else:
		for building in _buildings:
			if not is_instance_valid(building) or building.consumed:
				continue
			for rect in building.navigation_obstacle_rects():
				if rect.intersects(bounds):
					obstacles.append(rect)
		for district_value in _loaded_districts.values():
			var district := district_value as GeneratedDistrict
			if not is_instance_valid(district):
				continue
			for rect in district.navigation_obstacle_rects():
				if rect.intersects(bounds):
					obstacles.append(rect)
		if (
			is_instance_valid(_roadblock)
			and _roadblock.collision_layer != 0
		):
			obstacles.append_array(
				_roadblock.navigation_obstacle_rects()
			)
		if (
			is_instance_valid(_city_detour)
			and _city_detour.collision_layer != 0
		):
			obstacles.append(_city_detour.navigation_obstacle_rect())
	_navigation.update_geometry(bounds, obstacles)
	_navigation_dirty = false


func _active_navigation_rect() -> Rect2:
	if not _active_interior_id.is_empty():
		var room := (
			_interior_rooms.get(_active_interior_id) as PrototypeInteriorRoom
		)
		if is_instance_valid(room):
			return room.interior_rect()
	return _loaded_world_navigation_rect()


func _navigation_rect_for_position(position: Vector2) -> Rect2:
	for room_value in _interior_rooms.values():
		var room := room_value as PrototypeInteriorRoom
		if is_instance_valid(room) and room.contains_world_point(position):
			return room.interior_rect()
	var coordinate := DISTRICT_GENERATOR_SCRIPT.coordinate_for_position(
		position
	)
	if (
		coordinate == _current_district_coordinate
		or _loaded_districts.has(coordinate)
	):
		return _loaded_world_navigation_rect()
	return DISTRICT_GENERATOR_SCRIPT.bounds_for_coordinate(coordinate)


func _loaded_world_navigation_rect() -> Rect2:
	var bounds := DISTRICT_GENERATOR_SCRIPT.bounds_for_coordinate(
		_current_district_coordinate
	)
	for coordinate_value in _loaded_districts:
		var coordinate := coordinate_value as Vector2i
		if (
			absi(coordinate.x - _current_district_coordinate.x) <= 1
			and absi(coordinate.y - _current_district_coordinate.y) <= 1
		):
			bounds = bounds.merge(
				DISTRICT_GENERATOR_SCRIPT.bounds_for_coordinate(
					coordinate
				)
			)
	return bounds


func _position_overlaps_target(
	position: Vector2,
	radius: float,
	extra_spacing: float = 12.0
) -> bool:
	for target in _targets:
		if (
			is_instance_valid(target)
			and target.kind != "building"
			and target.global_position.distance_to(position)
			< target.pick_radius + radius + extra_spacing
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
	target.z_as_relative = false
	_district_parent_for_coordinate(item.district_coordinate).add_child(target)
	_targets.append(target)
	_capture_generated_building_state(building)
	_mark_generated_target_present(target)
	return true


func _district_parent_for_coordinate(coordinate: Vector2i) -> Node:
	if coordinate == DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE:
		return _world
	var district := _loaded_districts.get(coordinate) as GeneratedDistrict
	return district if is_instance_valid(district) else _world


func _building_footprint_clear(building: PrototypeBuilding) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = building.building_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, building.global_position)
	query.collision_mask = 1
	query.exclude = building.structural_body_rids()
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
	_tutorial_panel.visible = not _options_overlay.visible
	_tutorial_progress.text = "Tutorial %d / %d" % [step_index + 1, step_count]
	_tutorial_title.text = title
	_tutorial_instruction.text = instruction
	_tutorial_card_art.set_step(step_index)
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
	_frog_route_requested_destination = Vector2.INF
	_frog_route_fallback = false
	if not _pending_interior_transition.is_empty():
		var destination := _pending_interior_transition
		var portal_id := _pending_interior_portal_id
		_pending_interior_transition = ""
		_pending_interior_portal_id = ""
		var expected_position := Vector2.INF
		if not _active_interior_id.is_empty():
			var room := (
				_interior_rooms.get(_active_interior_id)
				as PrototypeInteriorRoom
			)
			if is_instance_valid(room):
				var portal := room.portal_by_id(portal_id)
				if not portal.is_empty():
					expected_position = room.portal_approach_position(
						portal
					)
		else:
			if not portal_id.is_empty():
				var city_portal := _city_portal_by_id(portal_id)
				if not city_portal.is_empty():
					expected_position = city_portal.get(
						"approach_position",
						Vector2.INF
					) as Vector2
			else:
				var building := _building_for_interior_room(destination)
				if is_instance_valid(building):
					expected_position = (
						building.transition_door_approach_position()
					)
		if (
			expected_position == Vector2.INF
			or world_position.distance_to(expected_position) > 130.0
		):
			_show_status("The frog could not reach that entrance.")
			return
		_begin_interior_transition(destination, portal_id)
		return
	movement_reached.emit(world_position)


func _find_target_by_id(target_id: String) -> EdibleTarget:
	for target in _targets:
		if is_instance_valid(target) and target.target_id == target_id:
			return target
	return null


func _end_game() -> void:
	if is_instance_valid(_score_epilogue):
		return
	_end_return_requested = false
	if is_instance_valid(_struggle_target):
		_clear_struggle()
	if _net_escape_active:
		_clear_net_escape()
	_clear_roadblock()
	_clear_pursuit_trap()
	_clear_city_detour()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)
	_belly_overlay.visible = false
	_guide_overlay.visible = false
	_options_overlay.visible = false
	_tutorial_panel.visible = false
	_tutorial_marker.active = false
	_score_epilogue = SCORE_EPILOGUE_SCENE.instantiate() as ScoreEpilogue
	$HUD/Root.add_child(_score_epilogue)
	_score_epilogue.configure(
		_display_name,
		_score,
		_growth_tier,
		_known_discovery_count(),
		_challenges.completed_count(),
		_larger_text_controls_enabled,
		_reduce_motion_enabled
	)
	_score_epilogue.apply_safe_area_insets(_safe_area_insets)
	_score_epilogue.continue_requested.connect(_finish_end_game)
	AudioDirector.enter_epilogue(self)
	AudioDirector.play_effect(FrogAudioDirector.EPILOGUE_OPEN)
	_update_save_warning_surfaces()
	get_tree().paused = true


func _finish_end_game() -> void:
	if (
		not is_instance_valid(_score_epilogue)
		or _end_return_requested
	):
		return
	_end_return_requested = true
	AudioDirector.play_effect(FrogAudioDirector.EPILOGUE_RETURN)
	end_requested.emit(_score)


func _build_prototype_city() -> void:
	var cafe_props: Array[Rect2] = [
		Rect2(-196, -18, 110, 106),
		Rect2(86, -18, 110, 106),
	]
	var apartment_props: Array[Rect2] = [
		Rect2(-231, -28, 86, 128),
		Rect2(145, -28, 86, 56),
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
	market.entrance_schedule_open_label = "DAY MARKET OPEN"
	market.entrance_schedule_closed_label = "OPENS AFTER DAWN"
	market.transition_door_position = Vector2(-160, -125)
	market.transition_door_approach_offset = Vector2(90, 65)
	market.transition_door_label = "ROOFTOP LADDER"
	market.transition_room_id = MARKET_ROOFTOP_ID
	market.transition_min_growth_tier = 1
	market.queue_redraw()
	var cafe := _spawn_building(
		Vector2(610, -570),
		Vector2(440, 360),
		"Leap Café",
		"south",
		Color("ca8d77"),
		"leap_cafe",
		true,
		Vector2(0, -120),
		cafe_props,
		PrototypeBuilding.ENTRANCE_PART_AWNING
	)
	cafe.transition_door_position = Vector2(145, -145)
	cafe.transition_door_approach_offset = Vector2(0, 72)
	cafe.transition_door_label = "STOCKROOM"
	cafe.transition_room_id = STOCKROOM_ID
	cafe.queue_redraw()
	var apartments := _spawn_building(
		Vector2(-610, 1210),
		Vector2(510, 330),
		"Canal Apartments",
		"north",
		Color("8aa6ce"),
		"canal_apartments",
		true,
		Vector2(188, 100),
		apartment_props,
		PrototypeBuilding.ENTRANCE_PART_AWNING,
		Vector2(86, 60)
	)
	apartments.transition_door_position = Vector2(188, -105)
	apartments.transition_door_approach_offset = Vector2(-90, 55)
	apartments.transition_door_label = "STAIRS UP"
	apartments.transition_room_id = CANAL_UPPER_HALL_ID
	apartments.queue_redraw()
	var cafe_bounds := cafe.interior_rect()
	var apartment_bounds := apartments.interior_rect()
	var stockroom := _spawn_interior_room(
		STOCKROOM_ID,
		"Leap Cafe Stockroom",
		STOCKROOM_POSITION,
		Vector2(1100, 820),
		Color("a77b5f"),
		[
			Rect2(-430, -320, 260, 80),
			Rect2(170, -320, 260, 80),
			Rect2(-470, 20, 105, 180),
			Rect2(365, -40, 105, 180),
		],
		cafe.building_id,
		"RETURN TO CAFE"
	)
	var upper_hall := _spawn_interior_room(
		CANAL_UPPER_HALL_ID,
		"Canal Apartments Upper Hall",
		CANAL_UPPER_HALL_POSITION,
		Vector2(1100, 820),
		Color("7f91ae"),
		[
			Rect2(-430, -320, 250, 82),
			Rect2(180, -320, 250, 82),
			Rect2(-470, 15, 110, 185),
			Rect2(360, -20, 110, 185),
		],
		apartments.building_id,
		"RETURN TO LOBBY"
	)
	upper_hall.set_entry(
		"from_fire_escape",
		Vector2(350, -160)
	)
	upper_hall.add_portal(
		"fire_escape_door",
		"FIRE ESCAPE",
		Vector2(475, -160),
		Vector2(350, -160),
		CANAL_FIRE_ESCAPE_ID,
		"from_upper_hall",
		1,
		"Grow once before climbing onto the fire escape."
	)
	var fire_escape := _spawn_interior_room(
		CANAL_FIRE_ESCAPE_ID,
		"Canal Apartments Fire Escape",
		CANAL_FIRE_ESCAPE_POSITION,
		Vector2(1700, 1200),
		Color("6f7f89"),
		[
			Rect2(-760, -380, 300, 76),
			Rect2(460, -380, 300, 76),
			Rect2(-760, 285, 280, 72),
			Rect2(500, 275, 250, 82),
		],
		apartments.building_id,
		"RETURN TO UPPER HALL",
		CANAL_UPPER_HALL_ID,
		"from_fire_escape"
	)
	fire_escape.camera_mode = PrototypeInteriorRoom.CAMERA_FOLLOW
	fire_escape.camera_zoom = Vector2(1.15, 1.15)
	fire_escape.camera_follow_distance = 120.0
	fire_escape.camera_rotation_limit = 0.3
	fire_escape.set_entry(
		"from_upper_hall",
		Vector2(-650, 120)
	)
	fire_escape.set_portal_geometry(
		"return",
		Vector2(-780, 120),
		Vector2(-650, 120)
	)
	var sewer_junction := _spawn_interior_room(
		RIVER_SEWER_JUNCTION_ID,
		"River Park Sewer Junction",
		RIVER_SEWER_JUNCTION_POSITION,
		Vector2(1600, 1100),
		Color("536b65"),
		[
			Rect2(-700, -450, 280, 88),
			Rect2(420, -450, 280, 88),
			Rect2(-720, 300, 230, 96),
			Rect2(490, 285, 210, 110),
		],
		"",
		"RETURN TO RIVER PARK"
	)
	sewer_junction.camera_mode = PrototypeInteriorRoom.CAMERA_FOLLOW
	sewer_junction.camera_zoom = Vector2(1.25, 1.25)
	sewer_junction.camera_follow_distance = 110.0
	sewer_junction.camera_rotation_limit = 0.2
	sewer_junction.set_entry("from_city", Vector2(0, 390))
	sewer_junction.set_entry("from_tunnel", Vector2(500, -250))
	sewer_junction.set_entry("from_maintenance", Vector2(-540, -220))
	sewer_junction.add_portal(
		"service_tunnel",
		"SERVICE TUNNEL",
		Vector2(690, -260),
		Vector2(540, -260),
		RIVER_SUBWAY_TUNNEL_ID,
		"from_junction"
	)
	sewer_junction.add_portal(
		"hidden_maintenance_hatch",
		"MAINTENANCE HATCH",
		Vector2(-690, -220),
		Vector2(-540, -220),
		RIVER_HIDDEN_MAINTENANCE_ID,
		"from_junction",
		0,
		"Inspect the Sewer Valve Wheel to reveal this service hatch.",
		"river_sewer_valve"
	)
	var subway_tunnel := _spawn_interior_room(
		RIVER_SUBWAY_TUNNEL_ID,
		"Old Subway Service Tunnel",
		RIVER_SUBWAY_TUNNEL_POSITION,
		Vector2(1800, 1000),
		Color("4d5963"),
		[
			Rect2(-800, -410, 320, 82),
			Rect2(480, -410, 320, 82),
			Rect2(-810, 300, 260, 74),
			Rect2(550, 285, 230, 88),
		],
		"",
		"RETURN TO SEWER JUNCTION",
		RIVER_SEWER_JUNCTION_ID,
		"from_tunnel"
	)
	subway_tunnel.camera_mode = PrototypeInteriorRoom.CAMERA_FOLLOW
	subway_tunnel.camera_zoom = Vector2(1.3, 1.3)
	subway_tunnel.camera_follow_distance = 100.0
	subway_tunnel.camera_rotation_limit = 0.15
	subway_tunnel.set_entry("from_junction", Vector2(-700, 100))
	subway_tunnel.set_portal_geometry(
		"return",
		Vector2(-820, 100),
		Vector2(-700, 100)
	)
	var pond_boardwalk := _spawn_interior_room(
		RIVER_POND_BOARDWALK_ID,
		"River Park Lily Pond Boardwalk",
		RIVER_POND_BOARDWALK_POSITION,
		Vector2(1900, 1200),
		Color("668d72"),
		[
			Rect2(-840, -500, 290, 110),
			Rect2(550, -500, 290, 110),
			Rect2(-850, 360, 250, 100),
			Rect2(600, 350, 230, 110),
		],
		"",
		"RETURN TO RIVER PARK"
	)
	pond_boardwalk.camera_mode = PrototypeInteriorRoom.CAMERA_FOLLOW
	pond_boardwalk.camera_zoom = Vector2(1.15, 1.15)
	pond_boardwalk.camera_follow_distance = 120.0
	pond_boardwalk.camera_rotation_limit = 0.25
	pond_boardwalk.set_entry("from_park", Vector2(0, 430))
	var crane_deck := _spawn_interior_room(
		CONSTRUCTION_CRANE_ID,
		"Construction Crane High Deck",
		CONSTRUCTION_CRANE_POSITION,
		Vector2(2100, 1300),
		Color("9a784e"),
		[
			Rect2(-950, -450, 320, 90),
			Rect2(630, -450, 320, 90),
			Rect2(-960, 315, 270, 90),
			Rect2(690, 305, 240, 100),
		],
		"",
		"RETURN TO CONSTRUCTION SITE"
	)
	crane_deck.camera_mode = PrototypeInteriorRoom.CAMERA_FOLLOW
	crane_deck.camera_zoom = Vector2(1.1, 1.1)
	crane_deck.camera_follow_distance = 130.0
	crane_deck.camera_rotation_limit = 0.25
	crane_deck.set_entry("from_lift", Vector2(-760, 250))
	var hidden_maintenance := _spawn_interior_room(
		RIVER_HIDDEN_MAINTENANCE_ID,
		"Hidden Sewer Maintenance Pocket",
		RIVER_HIDDEN_MAINTENANCE_POSITION,
		Vector2(1300, 900),
		Color("445956"),
		[
			Rect2(-530, -330, 260, 82),
			Rect2(270, -330, 260, 82),
			Rect2(-540, 160, 190, 120),
			Rect2(350, 150, 170, 130),
		],
		"",
		"RETURN TO SEWER JUNCTION",
		RIVER_SEWER_JUNCTION_ID,
		"from_maintenance"
	)
	hidden_maintenance.camera_zoom = Vector2(1.25, 1.25)
	hidden_maintenance.set_entry("from_junction", Vector2(450, 80))
	hidden_maintenance.set_portal_geometry(
		"return",
		Vector2(400, 80),
		Vector2(300, 80)
	)
	hidden_maintenance.set_entry("from_secret", Vector2(0, 0))
	hidden_maintenance.add_portal(
		"secret_star_path",
		"STAR PATH",
		Vector2(0, -310),
		Vector2(0, -200),
		SECRET_DISTRICT_DESTINATION
	)
	var market_rooftop := _spawn_interior_room(
		MARKET_ROOFTOP_ID,
		"Moonlight Market Rooftop Garden",
		MARKET_ROOFTOP_POSITION,
		Vector2(1100, 820),
		Color("718d68"),
		[
			Rect2(-430, -320, 260, 86),
			Rect2(170, -320, 260, 86),
			Rect2(-470, 20, 110, 190),
			Rect2(360, -30, 110, 190),
		],
		market.building_id,
		"RETURN TO MARKET"
	)
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
	oddities_shop.entrance_schedule_open_label = "NIGHT OPEN"
	oddities_shop.entrance_schedule_closed_label = "OPENS AT NIGHT"
	oddities_shop.transition_door_position = oddities_shop.counter_position
	oddities_shop.transition_door_approach_offset = Vector2(-140, 0)
	oddities_shop.transition_door_label = "CELLAR TRAPDOOR"
	oddities_shop.transition_room_id = ODDITIES_CELLAR_ID
	oddities_shop.transition_required_removed_part = (
		PrototypeBuilding.PART_COUNTER
	)
	oddities_shop.transition_required_part_label = "Curio Shelf"
	oddities_shop.queue_redraw()
	var oddities_cellar := _spawn_interior_room(
		ODDITIES_CELLAR_ID,
		"Oddities Shop Curio Cellar",
		ODDITIES_CELLAR_POSITION,
		Vector2(1100, 820),
		Color("665b78"),
		[
			Rect2(-430, -320, 260, 86),
			Rect2(170, -320, 260, 86),
			Rect2(-470, 20, 110, 190),
			Rect2(360, -30, 110, 190),
		],
		oddities_shop.building_id,
		"RETURN TO SHOP"
	)
	_spawn_destruction_targets(market)
	_spawn_destruction_targets(cafe)
	_spawn_destruction_targets(apartments)

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
		"id": "cafe_stockroom_coffee_tin",
		"name": "Stockroom Coffee Tin",
		"position": stockroom.global_position + Vector2(-280, -205),
		"value": 34,
		"kind": "object",
		"radius": 28.0,
		"bounds": stockroom.interior_rect(),
		"building_id": STOCKROOM_ID,
		"color": Color("8eb39a"),
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
	_spawn_target({
		"id": "market_rooftop_beehive",
		"name": "Rooftop Beehive",
		"position": market_rooftop.global_position + Vector2(-250, -180),
		"value": 72,
		"tier": 1,
		"kind": "object",
		"radius": 34.0,
		"resistant": true,
		"taps": 7,
		"bounds": market_rooftop.interior_rect(),
		"building_id": MARKET_ROOFTOP_ID,
		"color": Color("e0b64f"),
	})
	_spawn_destruction_targets(oddities_shop)
	_spawn_target({
		"id": "oddities_cellar_music_box",
		"name": "Cursed Music Box",
		"position": oddities_cellar.global_position + Vector2(-250, -180),
		"value": 84,
		"tier": 1,
		"kind": "object",
		"radius": 34.0,
		"resistant": true,
		"taps": 8,
		"bounds": oddities_cellar.interior_rect(),
		"building_id": ODDITIES_CELLAR_ID,
		"color": Color("b68bc8"),
	})
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
	_spawn_target({
		"id": "canal_upper_hall_vacuum",
		"name": "Hallway Vacuum",
		"position": upper_hall.global_position + Vector2(-250, -180),
		"value": 54,
		"tier": 1,
		"kind": "object",
		"radius": 34.0,
		"bounds": upper_hall.interior_rect(),
		"building_id": CANAL_UPPER_HALL_ID,
		"color": Color("d3a96f"),
	})
	_spawn_target({
		"id": "canal_fire_escape_laundry",
		"name": "Balcony Laundry Basket",
		"position": fire_escape.global_position + Vector2(420, -180),
		"value": 58,
		"tier": 1,
		"kind": "object",
		"radius": 34.0,
		"bounds": fire_escape.interior_rect(),
		"building_id": CANAL_FIRE_ESCAPE_ID,
		"color": Color("d9c7a1"),
	})
	_spawn_target({
		"id": "river_sewer_valve",
		"name": "Sewer Valve Wheel",
		"position": sewer_junction.global_position + Vector2(-360, -170),
		"value": 52,
		"kind": "object",
		"radius": 32.0,
		"bounds": sewer_junction.interior_rect(),
		"building_id": RIVER_SEWER_JUNCTION_ID,
		"color": Color("b86f4e"),
	})
	_spawn_target({
		"id": "river_subway_signal",
		"name": "Abandoned Signal Lamp",
		"position": subway_tunnel.global_position + Vector2(380, -150),
		"value": 68,
		"tier": 1,
		"kind": "object",
		"radius": 34.0,
		"resistant": true,
		"taps": 7,
		"bounds": subway_tunnel.interior_rect(),
		"building_id": RIVER_SUBWAY_TUNNEL_ID,
		"color": Color("d8a84d"),
	})
	_spawn_target({
		"id": "river_pond_lily_planter",
		"name": "Lily Pad Planter",
		"position": pond_boardwalk.global_position + Vector2(420, -180),
		"value": 64,
		"tier": 1,
		"kind": "object",
		"radius": 36.0,
		"bounds": pond_boardwalk.interior_rect(),
		"building_id": RIVER_POND_BOARDWALK_ID,
		"color": Color("79b962"),
	})
	_spawn_target({
		"id": "construction_crane_toolbox",
		"name": "Crane Operator Toolbox",
		"position": crane_deck.global_position + Vector2(520, -180),
		"value": 78,
		"tier": 1,
		"kind": "object",
		"radius": 38.0,
		"resistant": true,
		"taps": 7,
		"bounds": crane_deck.interior_rect(),
		"building_id": CONSTRUCTION_CRANE_ID,
		"dangerous": true,
		"color": Color("d7a34b"),
	})
	_spawn_target({
		"id": "river_hidden_pump_handle",
		"name": "Maintenance Pump Handle",
		"position": (
			hidden_maintenance.global_position + Vector2(220, -120)
		),
		"value": 72,
		"tier": 1,
		"kind": "object",
		"radius": 36.0,
		"resistant": true,
		"taps": 6,
		"bounds": hidden_maintenance.interior_rect(),
		"building_id": RIVER_HIDDEN_MAINTENANCE_ID,
		"dangerous": true,
		"color": Color("a9c8b4"),
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
	interior_props: Array[Rect2] = [],
	entrance_part_style: String = PrototypeBuilding.ENTRANCE_PART_DOOR,
	counter_size: Vector2 = Vector2(140, 52),
	parent: Node = null
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
	building.counter_size = counter_size
	building.interior_props = interior_props.duplicate()
	building.entrance_part_style = entrance_part_style
	building.z_as_relative = false
	building.navigation_changed.connect(_on_building_navigation_changed)
	(parent if parent != null else _world).add_child(building)
	_buildings.append(building)
	_building_by_id[building_id] = building
	return building


func _on_building_navigation_changed() -> void:
	_invalidate_navigation()


func _spawn_interior_room(
	room_id: String,
	room_name: String,
	room_position: Vector2,
	room_size: Vector2,
	color: Color,
	props: Array[Rect2],
	origin_building_id: String,
	return_label: String,
	return_destination: String = "city",
	return_destination_entry_id: String = "default"
) -> PrototypeInteriorRoom:
	var room := INTERIOR_ROOM_SCRIPT.new() as PrototypeInteriorRoom
	room.room_id = room_id
	room.display_name = room_name
	room.position = room_position
	room.room_size = room_size
	room.floor_color = color
	room.return_label = return_label
	room.props = props.duplicate()
	room.set_entry(
		"default",
		Vector2(0, room_size.y * 0.31)
	)
	room.add_portal(
		"return",
		return_label,
		Vector2(0, room_size.y * 0.4),
		Vector2(0, room_size.y * 0.3),
		return_destination,
		return_destination_entry_id
	)
	_world.add_child(room)
	_interior_rooms[room_id] = room
	_interior_room_building_ids[room_id] = origin_building_id
	return room


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
	var ordered := bool(configuration.get("ordered", false))
	var part_index := 0
	for part_configuration in configuration.get("parts", []):
		var target_data := (part_configuration as Dictionary).duplicate(true)
		var part_id := str(target_data.get("part_id", ""))
		if part_id.is_empty():
			push_error(
				"Destruction target configuration is missing a part ID for %s."
				% building.building_id
			)
			return
		target_data.erase("part_id")
		target_data["position"] = building.part_world_position(part_id)
		target_data["kind"] = "building_part"
		target_data["restockable"] = false
		target_data["building_id"] = building.building_id
		target_data["building_part_id"] = part_id
		if ordered and part_index > 0:
			target_data["hidden"] = true
			target_data["selectable"] = false
		_spawn_target(target_data)
		part_index += 1

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


func _spawn_target(
	data: Dictionary,
	parent: Node = null
) -> EdibleTarget:
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
	var district_coordinate_value: Variant = data.get(
		"district_coordinate",
		DISTRICT_GENERATOR_SCRIPT.CORE_COORDINATE
	)
	if district_coordinate_value is Vector2i:
		target.district_coordinate = district_coordinate_value as Vector2i
	target.move_bounds = data.get(
		"bounds",
		DISTRICT_GENERATOR_SCRIPT.bounds_for_coordinate(
			target.district_coordinate
		).grow(-100)
	)
	target.dangerous_location = bool(data.get("dangerous", false))
	target.target_color = data.get("color", Color("f5a84b"))
	target.is_vehicle = target.kind == "vehicle"
	target.restockable = bool(data.get("restockable", true))
	target.building_id = str(data.get("building_id", ""))
	target.building_part_id = str(data.get("building_part_id", ""))
	target.selectable = bool(data.get("selectable", true))
	target.world_instance_id = str(data.get("world_instance_id", ""))
	target.motion_seed = int(data.get("motion_seed", 0))
	target.world_state_dirty = bool(data.get("world_state_dirty", false))
	target.visible = not bool(data.get("hidden", false))
	target.set_presentation_motion_scale(_motion_scale)
	target.z_as_relative = false
	(parent if parent != null else _world).add_child(target)
	_targets.append(target)
	return target
