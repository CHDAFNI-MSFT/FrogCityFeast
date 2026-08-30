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

var _profile_store: ProfileStore


func _ready() -> void:
	_profile_select.item_selected.connect(_on_profile_selected)
	_new_name.text_changed.connect(_on_new_name_changed)
	_start_button.pressed.connect(_on_start_pressed)


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
	var profile_id := str(_profile_select.get_item_metadata(index))
	_show_profile_preview(profile_id)


func _show_profile_preview(profile_id: String) -> void:
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


func _on_new_name_changed(new_text: String) -> void:
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
	_best_label.text = "Player best: 0"
	_start_button.text = "Start Tutorial"
	_guide_label.text = "Field Guide: 0 / %d" % DiscoveryCatalog.count()


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
	start_requested.emit(profile_id, _profile_store.get_profile_name(profile_id))
