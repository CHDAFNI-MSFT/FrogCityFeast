extends Node


const MENU_SCENE := preload("res://scenes/menu.tscn")
const GAME_SCENE := preload("res://scenes/game.tscn")
const SCREEN_FADE_DURATION := 0.22

@onready var _transition_fade: ColorRect = %Fade
@onready var _loading_label: Label = %LoadingLabel

var _profile_store: ProfileStore
var _current_screen: Node
var _last_score := 0
var _transitioning := false


func _ready() -> void:
	if _profile_store == null:
		_profile_store = ProfileStore.new()
	_profile_store.save_error.connect(_on_profile_store_save_error)
	_show_menu()
	if not _profile_store.last_save_error().is_empty():
		_on_profile_store_save_error(_profile_store.last_save_error())


func configure_profile_store(profile_store: ProfileStore) -> void:
	if is_inside_tree():
		push_error("Main profile storage must be configured before entering the tree.")
		return
	_profile_store = profile_store


func _show_menu() -> void:
	get_tree().paused = false
	_replace_screen(MENU_SCENE.instantiate())
	var menu := _current_screen as MainMenu
	menu.configure(_profile_store, _last_score)
	menu.start_requested.connect(_start_game)
	menu.activate_audio_context()
	if not _profile_store.last_save_error().is_empty():
		menu.show_save_error(_profile_store.last_save_error())


func _start_game(
	profile_id: String,
	display_name: String,
	force_tutorial: bool = false
) -> void:
	if _transitioning:
		return
	_transitioning = true
	var transition_duration := _transition_duration(profile_id)
	await _fade_to(
		1.0,
		transition_duration,
		"Opening Frog City..."
	)
	var game := GAME_SCENE.instantiate() as FrogGame
	game.configure(
		profile_id,
		display_name,
		force_tutorial or not _profile_store.is_tutorial_complete(profile_id),
		_profile_store.get_discoveries(profile_id),
		_profile_store.get_accessibility_preferences(profile_id),
		_profile_store.get_audio_preferences(profile_id),
		0,
		_profile_store.get_power_discoveries(profile_id),
		_profile_store.get_profile_achievements(profile_id),
		_profile_store.get_device_achievements(),
		_profile_store.get_story_clues(profile_id),
		_profile_store.get_secret_unlocks(profile_id)
	)
	game.score_changed.connect(_on_score_changed.bind(profile_id))
	game.end_requested.connect(_on_game_ended.bind(profile_id))
	game.tutorial_finished.connect(_on_tutorial_finished.bind(profile_id))
	game.target_discovered.connect(_on_target_discovered.bind(profile_id))
	game.accessibility_changed.connect(
		_on_accessibility_changed.bind(profile_id)
	)
	game.audio_changed.connect(_on_audio_changed.bind(profile_id))
	game.power_discovered.connect(_on_power_discovered.bind(profile_id))
	game.profile_achievement_unlocked.connect(
		_on_profile_achievement_unlocked.bind(profile_id)
	)
	game.device_achievement_unlocked.connect(
		_on_device_achievement_unlocked
	)
	game.story_clue_found.connect(_on_story_clue_found.bind(profile_id))
	game.secret_unlocked.connect(_on_secret_unlocked.bind(profile_id))
	_replace_screen(game)
	game.activate_audio_context()
	if not _profile_store.last_save_error().is_empty():
		game.show_save_error(_profile_store.last_save_error())
	await get_tree().process_frame
	await _fade_to(0.0, transition_duration, "")
	_transitioning = false


func _on_score_changed(score: int, profile_id: String) -> void:
	_profile_store.update_high_scores(profile_id, score)


func _on_game_ended(score: int, profile_id: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	_last_score = score
	_profile_store.update_high_scores(profile_id, score)
	var transition_duration := _transition_duration(profile_id)
	await _fade_to(
		1.0,
		transition_duration,
		"Returning to the river..."
	)
	_show_menu()
	await get_tree().process_frame
	await _fade_to(0.0, transition_duration, "")
	_transitioning = false


func _on_tutorial_finished(_skipped: bool, profile_id: String) -> void:
	_profile_store.mark_tutorial_complete(profile_id)


func _on_target_discovered(target_id: String, profile_id: String) -> void:
	_profile_store.mark_discovered(profile_id, target_id)


func _on_accessibility_changed(
	preferences: Dictionary,
	profile_id: String
) -> void:
	_profile_store.set_accessibility_preferences(
		profile_id,
		preferences
	)


func _on_audio_changed(
	preferences: Dictionary,
	profile_id: String
) -> void:
	_profile_store.set_audio_preferences(profile_id, preferences)


func _on_power_discovered(power_id: String, profile_id: String) -> void:
	_profile_store.mark_power_discovered(profile_id, power_id)


func _on_profile_achievement_unlocked(
	achievement_id: String,
	derived_clue_id: String,
	profile_id: String
) -> void:
	_profile_store.mark_profile_achievement(
		profile_id,
		achievement_id,
		derived_clue_id
	)


func _on_device_achievement_unlocked(achievement_id: String) -> void:
	_profile_store.mark_device_achievement(achievement_id)


func _on_story_clue_found(clue_id: String, profile_id: String) -> void:
	_profile_store.mark_story_clue(profile_id, clue_id)


func _on_secret_unlocked(secret_id: String, profile_id: String) -> void:
	_profile_store.mark_secret_unlocked(profile_id, secret_id)


func _on_profile_store_save_error(message: String) -> void:
	if _current_screen is MainMenu:
		(_current_screen as MainMenu).show_save_error(message)
	elif _current_screen is FrogGame:
		(_current_screen as FrogGame).show_save_error(message)


func _transition_duration(profile_id: String) -> float:
	var preferences := _profile_store.get_accessibility_preferences(profile_id)
	return (
		0.0
		if bool(preferences["reduce_motion"])
		else SCREEN_FADE_DURATION
	)


func _fade_to(
	target_alpha: float,
	duration: float,
	message: String
) -> void:
	_loading_label.text = message
	_transition_fade.visible = true
	if duration <= 0.0:
		_set_transition_alpha(target_alpha)
	else:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(
			Tween.EASE_IN if target_alpha >= 1.0 else Tween.EASE_OUT
		)
		tween.tween_method(
			_set_transition_alpha,
			_transition_fade.color.a,
			target_alpha,
			duration
		)
		await tween.finished
	if target_alpha <= 0.0:
		_transition_fade.visible = false


func _set_transition_alpha(value: float) -> void:
	var fade_color := _transition_fade.color
	fade_color.a = clampf(value, 0.0, 1.0)
	_transition_fade.color = fade_color


func _replace_screen(next_screen: Node) -> void:
	if is_instance_valid(_current_screen):
		remove_child(_current_screen)
		_current_screen.queue_free()
	_current_screen = next_screen
	add_child(_current_screen)
