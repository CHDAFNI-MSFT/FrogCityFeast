extends Node


const MENU_SCENE := preload("res://scenes/menu.tscn")
const GAME_SCENE := preload("res://scenes/game.tscn")

var _profile_store: ProfileStore
var _current_screen: Node
var _last_score := 0


func _ready() -> void:
	_profile_store = ProfileStore.new()
	_show_menu()


func _show_menu() -> void:
	get_tree().paused = false
	_replace_screen(MENU_SCENE.instantiate())
	var menu := _current_screen as MainMenu
	menu.configure(_profile_store, _last_score)
	menu.start_requested.connect(_start_game)
	menu.activate_audio_context()


func _start_game(profile_id: String, display_name: String) -> void:
	var game := GAME_SCENE.instantiate() as FrogGame
	game.configure(
		profile_id,
		display_name,
		not _profile_store.is_tutorial_complete(profile_id),
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


func _on_score_changed(score: int, profile_id: String) -> void:
	_profile_store.update_high_scores(profile_id, score)


func _on_game_ended(score: int, profile_id: String) -> void:
	_last_score = score
	_profile_store.update_high_scores(profile_id, score)
	_show_menu()


func _on_tutorial_finished(_skipped: bool, profile_id: String) -> void:
	_profile_store.mark_tutorial_complete(profile_id)


func _on_target_discovered(target_id: String, profile_id: String) -> void:
	_profile_store.mark_discovered(profile_id, target_id)


func _on_accessibility_changed(
	reduce_motion: bool,
	larger_text_controls: bool,
	profile_id: String
) -> void:
	_profile_store.set_accessibility_preferences(
		profile_id,
		reduce_motion,
		larger_text_controls
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


func _replace_screen(next_screen: Node) -> void:
	if is_instance_valid(_current_screen):
		remove_child(_current_screen)
		_current_screen.queue_free()
	_current_screen = next_screen
	add_child(_current_screen)
