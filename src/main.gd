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


func _start_game(profile_id: String, display_name: String) -> void:
	var game := GAME_SCENE.instantiate() as FrogGame
	game.configure(
		profile_id,
		display_name,
		not _profile_store.is_tutorial_complete(profile_id),
		_profile_store.get_discoveries(profile_id)
	)
	game.score_changed.connect(_on_score_changed.bind(profile_id))
	game.end_requested.connect(_on_game_ended.bind(profile_id))
	game.tutorial_finished.connect(_on_tutorial_finished.bind(profile_id))
	game.target_discovered.connect(_on_target_discovered.bind(profile_id))
	_replace_screen(game)


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


func _replace_screen(next_screen: Node) -> void:
	if is_instance_valid(_current_screen):
		remove_child(_current_screen)
		_current_screen.queue_free()
	_current_screen = next_screen
	add_child(_current_screen)
