class_name MainMenu
extends Control

signal start_requested(profile_id: String, display_name: String)

@onready var _profile_select: OptionButton = %ProfileSelect
@onready var _new_name: LineEdit = %NewName
@onready var _best_label: Label = %BestLabel
@onready var _guide_label: Label = %GuideLabel
@onready var _device_best_label: Label = %DeviceBestLabel
@onready var _last_score_label: Label = %LastScoreLabel
@onready var _start_button: Button = %StartButton
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _larger_ui_toggle: CheckButton = %LargerUiToggle
@onready var _center: CenterContainer = $Center

var _profile_store: ProfileStore
var _preview_profile_id := ""
var _new_profile_preferences := {
	"reduce_motion": false,
	"larger_text_controls": false,
}
var _refreshing_preferences := false
var _clearing_name_for_selection := false


func _ready() -> void:
	_profile_select.item_selected.connect(_on_profile_selected)
	_new_name.text_changed.connect(_on_new_name_changed)
	_start_button.pressed.connect(_on_start_pressed)
	_reduce_motion_toggle.toggled.connect(_on_accessibility_toggled)
	_larger_ui_toggle.toggled.connect(_on_accessibility_toggled)
	get_viewport().size_changed.connect(_apply_safe_area)
	AccessibilityPresentation.apply(self, false)
	_apply_safe_area()


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
	_guide_label.text = "Field Guide: %d / %d" % [
		_profile_store.get_discovery_count(profile_id),
		DiscoveryCatalog.count(),
	]
	_start_button.text = (
		"Start New Game"
		if _profile_store.is_tutorial_complete(profile_id)
		else "Start Tutorial"
	)
	_show_accessibility_preferences(
		_profile_store.get_accessibility_preferences(profile_id)
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
	_guide_label.text = "Field Guide: 0 / %d" % DiscoveryCatalog.count()
	_show_accessibility_preferences(_new_profile_preferences)


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
		_reduce_motion_toggle.button_pressed,
		_larger_ui_toggle.button_pressed
	)
	start_requested.emit(profile_id, _profile_store.get_profile_name(profile_id))


func _on_accessibility_toggled(_pressed: bool) -> void:
	if _refreshing_preferences or _profile_store == null:
		return
	var preferences := {
		"reduce_motion": _reduce_motion_toggle.button_pressed,
		"larger_text_controls": _larger_ui_toggle.button_pressed,
	}
	if _preview_profile_id.is_empty():
		_new_profile_preferences = preferences
	else:
		_profile_store.set_accessibility_preferences(
			_preview_profile_id,
			bool(preferences["reduce_motion"]),
			bool(preferences["larger_text_controls"])
		)
	_update_accessibility_labels()
	AccessibilityPresentation.apply(
		self,
		_larger_ui_toggle.button_pressed
	)


func _show_accessibility_preferences(preferences: Dictionary) -> void:
	var sanitized := AccessibilityPresentation.sanitize_preferences(preferences)
	_refreshing_preferences = true
	_reduce_motion_toggle.button_pressed = bool(sanitized["reduce_motion"])
	_larger_ui_toggle.button_pressed = bool(
		sanitized["larger_text_controls"]
	)
	_refreshing_preferences = false
	_update_accessibility_labels()
	AccessibilityPresentation.apply(
		self,
		_larger_ui_toggle.button_pressed
	)


func _update_accessibility_labels() -> void:
	_reduce_motion_toggle.text = "Reduce motion: %s" % (
		"On" if _reduce_motion_toggle.button_pressed else "Off"
	)
	_larger_ui_toggle.text = "Larger text & controls: %s" % (
		"On" if _larger_ui_toggle.button_pressed else "Off"
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
