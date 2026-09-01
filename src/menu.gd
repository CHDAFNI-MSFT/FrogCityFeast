class_name MainMenu
extends Control

signal start_requested(
	profile_id: String,
	display_name: String,
	force_tutorial: bool
)

@onready var _profile_select: OptionButton = %ProfileSelect
@onready var _new_name: LineEdit = %NewName
@onready var _best_label: Label = %BestLabel
@onready var _guide_label: Label = %GuideLabel
@onready var _device_best_label: Label = %DeviceBestLabel
@onready var _last_score_label: Label = %LastScoreLabel
@onready var _start_button: Button = %StartButton
@onready var _replay_tutorial_button: Button = %ReplayTutorialButton
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _larger_ui_toggle: CheckButton = %LargerUiToggle
@onready var _input_assist_option: OptionButton = %InputAssistOption
@onready var _camera_sensitivity_label: Label = %CameraSensitivityLabel
@onready var _camera_sensitivity_slider: HSlider = %CameraSensitivitySlider
@onready var _camera_auto_align_toggle: CheckButton = %CameraAutoAlignToggle
@onready var _haptics_toggle: CheckButton = %HapticsToggle
@onready var _left_handed_toggle: CheckButton = %LeftHandedToggle
@onready var _master_volume_label: Label = %MasterVolumeLabel
@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _music_volume_label: Label = %MusicVolumeLabel
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _effects_volume_label: Label = %EffectsVolumeLabel
@onready var _effects_volume_slider: HSlider = %EffectsVolumeSlider
@onready var _center: CenterContainer = $Center
@onready var _panel_margin: MarginContainer = $Center/Panel/Margin
@onready var _content: VBoxContainer = $Center/Panel/Margin/Content
@onready var _backdrop: MenuBackdrop = $Backdrop
@onready var _save_warning: PanelContainer = %SaveWarning
@onready var _save_warning_label: Label = %SaveWarningLabel

var _profile_store: ProfileStore
var _preview_profile_id := ""
var _new_profile_preferences := AccessibilityPresentation.defaults()
var _new_profile_audio_preferences := AudioPreferences.defaults()
var _refreshing_preferences := false
var _refreshing_audio_controls := false
var _audio_dragging := false
var _clearing_name_for_selection := false


func _ready() -> void:
	_populate_input_assist_options()
	_profile_select.item_selected.connect(_on_profile_selected)
	_new_name.text_changed.connect(_on_new_name_changed)
	_start_button.pressed.connect(_on_start_pressed)
	_replay_tutorial_button.pressed.connect(_on_replay_tutorial_pressed)
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
	for slider in _audio_sliders():
		slider.value_changed.connect(_on_audio_value_changed)
		slider.drag_started.connect(_on_audio_drag_started)
		slider.drag_ended.connect(_on_audio_drag_ended)
	get_viewport().size_changed.connect(_apply_safe_area)
	AccessibilityPresentation.apply(self, false)
	_apply_menu_density(false)
	_apply_safe_area()


func _exit_tree() -> void:
	AudioDirector.leave_context(self)


func show_save_error(message: String) -> void:
	if message.is_empty():
		_save_warning.visible = false
		_save_warning_label.text = ""
		return
	_save_warning_label.text = "SAVE WARNING: %s" % message
	_save_warning.visible = true


func configure(profile_store: ProfileStore, last_score: int) -> void:
	_profile_store = profile_store
	_profile_select.clear()
	for profile in _profile_store.list_profiles():
		var index := _profile_select.item_count
		_profile_select.add_item(str(profile["name"]))
		_profile_select.set_item_metadata(index, str(profile["id"]))

	if _profile_select.item_count > 0:
		_profile_select.select(0)
		_on_profile_selected(0)
	_device_best_label.text = "iPad best: %d" % _profile_store.get_device_best()
	_last_score_label.text = "Last score: %d" % last_score if last_score > 0 else ""


func _on_profile_selected(index: int) -> void:
	if _profile_store == null or index < 0:
		return
	if not _new_name.text.is_empty():
		_clearing_name_for_selection = true
		_new_name.clear()
		_clearing_name_for_selection = false
	var profile_id := str(_profile_select.get_item_metadata(index))
	_show_profile_preview(profile_id)


func _show_profile_preview(profile_id: String) -> void:
	_preview_profile_id = profile_id
	_best_label.text = "Player best: %d" % _profile_store.get_profile_best(profile_id)
	_guide_label.text = _profile_progress_text(profile_id)
	_start_button.text = (
		"Start New Game"
		if _profile_store.is_tutorial_complete(profile_id)
		else "Start Tutorial"
	)
	_replay_tutorial_button.visible = (
		_profile_store.is_tutorial_complete(profile_id)
	)
	_show_accessibility_preferences(
		_profile_store.get_accessibility_preferences(profile_id)
	)
	_show_audio_preferences(
		_profile_store.get_audio_preferences(profile_id)
	)


func _on_new_name_changed(new_text: String) -> void:
	if _clearing_name_for_selection:
		return
	var typed_name := new_text.strip_edges()
	if typed_name.is_empty():
		if _profile_select.selected >= 0:
			_on_profile_selected(_profile_select.selected)
		return
	typed_name = ProfileStore.normalize_profile_name(typed_name)
	for profile in _profile_store.list_profiles():
		if str(profile["name"]).nocasecmp_to(typed_name) == 0:
			_show_profile_preview(str(profile["id"]))
			return
	_preview_profile_id = ""
	_best_label.text = "Player best: 0"
	_start_button.text = "Start Tutorial"
	_replay_tutorial_button.visible = false
	_guide_label.text = (
		"Field Guide: 0 / %d\n"
		+ "Profile: 0 / %d achievements | 0 / %d clues\n"
		+ "Powers: 0 / %d | Secrets: 0 / %d\n"
		+ "Device: %d / %d milestones"
	) % [
		DiscoveryCatalog.count(),
		ProgressionCatalog.profile_achievement_ids().size(),
		ProgressionCatalog.story_clue_ids().size(),
		ProgressionCatalog.power_ids().size(),
		ProgressionCatalog.secret_unlock_ids().size(),
		_profile_store.get_device_achievements().size(),
		ProgressionCatalog.device_achievement_ids().size(),
	]
	_show_accessibility_preferences(_new_profile_preferences)
	_show_audio_preferences(_new_profile_audio_preferences)


func _profile_progress_text(profile_id: String) -> String:
	return (
		"Field Guide: %d / %d\n"
		+ "Profile: %d / %d achievements | %d / %d clues\n"
		+ "Powers: %d / %d | Secrets: %d / %d\n"
		+ "Device: %d / %d milestones"
	) % [
		_profile_store.get_discovery_count(profile_id),
		DiscoveryCatalog.count(),
		_profile_store.get_profile_achievements(profile_id).size(),
		ProgressionCatalog.profile_achievement_ids().size(),
		_profile_store.get_story_clues(profile_id).size(),
		ProgressionCatalog.story_clue_ids().size(),
		_profile_store.get_power_discoveries(profile_id).size(),
		ProgressionCatalog.power_ids().size(),
		_profile_store.get_secret_unlocks(profile_id).size(),
		ProgressionCatalog.secret_unlock_ids().size(),
		_profile_store.get_device_achievements().size(),
		ProgressionCatalog.device_achievement_ids().size(),
	]


func _on_start_pressed() -> void:
	var typed_name := _new_name.text.strip_edges()
	var profile_id: String
	if not typed_name.is_empty():
		typed_name = ProfileStore.normalize_profile_name(typed_name)
		profile_id = _profile_store.ensure_profile(typed_name)
	else:
		var selected_index := _profile_select.selected
		if selected_index < 0:
			profile_id = _profile_store.ensure_profile(ProfileStore.DEFAULT_PROFILE_NAME)
		else:
			profile_id = str(_profile_select.get_item_metadata(selected_index))
	_profile_store.set_accessibility_preferences(
		profile_id,
		_accessibility_preferences_from_controls()
	)
	_profile_store.set_audio_preferences(
		profile_id,
		_audio_preferences_from_controls()
	)
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)
	_play_haptic(20)
	start_requested.emit(
		profile_id,
		_profile_store.get_profile_name(profile_id),
		false
	)


func _on_replay_tutorial_pressed() -> void:
	if _profile_store == null or _preview_profile_id.is_empty():
		return
	_profile_store.set_accessibility_preferences(
		_preview_profile_id,
		_accessibility_preferences_from_controls()
	)
	_profile_store.set_audio_preferences(
		_preview_profile_id,
		_audio_preferences_from_controls()
	)
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)
	_play_haptic(20)
	start_requested.emit(
		_preview_profile_id,
		_profile_store.get_profile_name(_preview_profile_id),
		true
	)


func _on_accessibility_toggled(_pressed: bool) -> void:
	if _refreshing_preferences or _profile_store == null:
		return
	var preferences := _accessibility_preferences_from_controls()
	if _preview_profile_id.is_empty():
		_new_profile_preferences = preferences
	else:
		_profile_store.set_accessibility_preferences(
			_preview_profile_id,
			preferences
		)
	_update_accessibility_labels()
	AccessibilityPresentation.apply(
		self,
		_larger_ui_toggle.button_pressed
	)
	_apply_menu_density(_larger_ui_toggle.button_pressed)
	_backdrop.set_motion_scale(
		0.0 if _reduce_motion_toggle.button_pressed else 1.0
	)
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)
	_play_haptic(16)


func _on_accessibility_option_selected(_index: int) -> void:
	_on_accessibility_toggled(false)


func _on_camera_sensitivity_changed(_value: float) -> void:
	_on_accessibility_toggled(false)


func _show_accessibility_preferences(preferences: Dictionary) -> void:
	var sanitized := AccessibilityPresentation.sanitize_preferences(preferences)
	_refreshing_preferences = true
	_reduce_motion_toggle.button_pressed = bool(sanitized["reduce_motion"])
	_larger_ui_toggle.button_pressed = bool(
		sanitized["larger_text_controls"]
	)
	_select_input_assist_mode(str(sanitized["input_assist_mode"]))
	_camera_sensitivity_slider.value = (
		float(sanitized["camera_sensitivity"]) * 100.0
	)
	_camera_auto_align_toggle.button_pressed = bool(
		sanitized["camera_auto_align"]
	)
	_haptics_toggle.button_pressed = bool(sanitized["haptics_enabled"])
	_left_handed_toggle.button_pressed = bool(
		sanitized["left_handed_hud"]
	)
	_refreshing_preferences = false
	_update_accessibility_labels()
	AccessibilityPresentation.apply(
		self,
		_larger_ui_toggle.button_pressed
	)
	_apply_menu_density(_larger_ui_toggle.button_pressed)
	_backdrop.set_motion_scale(
		0.0 if _reduce_motion_toggle.button_pressed else 1.0
	)


func _update_accessibility_labels() -> void:
	_reduce_motion_toggle.text = "Reduce motion: %s" % (
		"On" if _reduce_motion_toggle.button_pressed else "Off"
	)
	_larger_ui_toggle.text = "Larger text & controls: %s" % (
		"On" if _larger_ui_toggle.button_pressed else "Off"
	)
	_camera_sensitivity_label.text = "Camera sensitivity: %d%%" % roundi(
		_camera_sensitivity_slider.value
	)
	_camera_auto_align_toggle.text = "Camera auto-align: %s" % (
		"On" if _camera_auto_align_toggle.button_pressed else "Off"
	)
	_haptics_toggle.text = "Haptics: %s" % (
		"On" if _haptics_toggle.button_pressed else "Off"
	)
	_left_handed_toggle.text = "Left-handed HUD: %s" % (
		"On" if _left_handed_toggle.button_pressed else "Off"
	)


func _apply_menu_density(larger_text_controls: bool) -> void:
	var vertical_margin := 20 if larger_text_controls else 28
	_panel_margin.add_theme_constant_override("margin_top", vertical_margin)
	_panel_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	_content.add_theme_constant_override(
		"separation",
		8 if larger_text_controls else 12
	)


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


func _play_haptic(duration_msec: int) -> void:
	AccessibilityPresentation.play_haptic(
		_haptics_toggle.button_pressed,
		duration_msec
	)


func activate_audio_context() -> void:
	AudioDirector.enter_menu(
		self,
		_audio_preferences_from_controls()
	)


func _show_audio_preferences(preferences: Dictionary) -> void:
	var sanitized := AudioPreferences.sanitize_preferences(preferences)
	_refreshing_audio_controls = true
	_master_volume_slider.value = float(sanitized["master"]) * 100.0
	_music_volume_slider.value = float(sanitized["music"]) * 100.0
	_effects_volume_slider.value = float(sanitized["effects"]) * 100.0
	_refreshing_audio_controls = false
	_update_audio_labels()
	AudioDirector.apply_preferences(sanitized)


func _on_audio_drag_started() -> void:
	_audio_dragging = true


func _on_audio_drag_ended(value_changed: bool) -> void:
	_audio_dragging = false
	if not value_changed:
		return
	_persist_audio_preferences()
	AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _on_audio_value_changed(_value: float) -> void:
	if _refreshing_audio_controls:
		return
	_update_audio_labels()
	var preferences := _audio_preferences_from_controls()
	AudioDirector.apply_preferences(preferences)
	if _preview_profile_id.is_empty():
		_new_profile_audio_preferences = preferences
	elif not _audio_dragging:
		_profile_store.set_audio_preferences(
			_preview_profile_id,
			preferences
		)
	if not _audio_dragging:
		AudioDirector.play_effect(FrogAudioDirector.UI_FEEDBACK)


func _persist_audio_preferences() -> void:
	var preferences := _audio_preferences_from_controls()
	if _preview_profile_id.is_empty():
		_new_profile_audio_preferences = preferences
	else:
		_profile_store.set_audio_preferences(
			_preview_profile_id,
			preferences
		)


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


func _apply_safe_area() -> void:
	apply_safe_area_insets(
		AccessibilityPresentation.current_safe_area_insets(
			get_viewport_rect().size
		)
	)


func apply_safe_area_insets(insets: Vector4) -> void:
	_center.offset_left = insets.x
	_center.offset_top = insets.y
	_center.offset_right = -insets.z
	_center.offset_bottom = -insets.w
	_save_warning.offset_top = 18.0 + maxf(0.0, insets.y)
	_save_warning.offset_bottom = 94.0 + maxf(0.0, insets.y)
