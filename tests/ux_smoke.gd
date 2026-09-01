extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_path := "user://ux_smoke.cfg"
	_remove_save_and_backups(save_path)
	var store := ProfileStore.new(save_path)
	var profile_id := store.ensure_profile("UX Frog")
	store.mark_tutorial_complete(profile_id)

	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main = main_scene.instantiate()
	main.configure_profile_store(store)
	root.add_child(main)
	await process_frame
	_check(
		main._current_screen is MainMenu
		and not main._transition_fade.visible,
		"The application opens on the illustrated title without a stale fade."
	)

	main._start_game(profile_id, store.get_profile_name(profile_id), false)
	_check(
		main._transition_fade.visible
		and main._loading_label.text == "Opening Frog City...",
		"Starting play blocks input behind a readable loading transition."
	)
	await create_timer(0.6).timeout
	_check(
		main._current_screen is FrogGame
		and not main._transition_fade.visible
		and not main._transitioning,
		"The loading transition reveals a configured game and completes."
	)

	var game := main._current_screen as FrogGame
	var valid_save_path := store._save_path
	store._save_path = "user://missing-ux-save-%d/ux_smoke.cfg" % (
		Time.get_ticks_usec()
	)
	game.score_changed.emit(321)
	await process_frame
	game._show_status("Digested Street Donut for 12 points!")
	await process_frame
	_check(
		store.last_save_error().contains("could not be saved")
		and store._save_dirty
		and is_instance_valid(game._save_warning_panel)
		and game._save_warning_label.text.contains("SAVE WARNING")
		and game._status_label.text.contains("Digested Street Donut"),
		"A real score-write failure stays visible without replacing gameplay feedback."
	)
	store._save_path = valid_save_path
	game.score_changed.emit(321)
	await process_frame
	var recovered_store := ProfileStore.new(save_path)
	_check(
		store.last_save_error().is_empty()
		and not store._save_dirty
		and not is_instance_valid(game._save_warning_panel)
		and recovered_store.get_profile_best(profile_id) == 321,
		"An unchanged score retries dirty data, persists it, and clears the warning."
	)
	game._score = 1234
	game._growth_tier = GameplayTuning.LARGE_TIER
	game.show_save_error("Final progress still needs to be saved.")
	game._end_game()
	_check(
		is_instance_valid(game._score_epilogue)
		and game._score_epilogue._score_label.text.contains("1234")
		and game._score_epilogue._story.text.contains("SAVE WARNING")
		and not game._save_warning_panel.visible
		and paused,
		"The paused epilogue integrates save warnings without banner overlap."
	)
	game.show_save_error("")
	game._finish_end_game()
	_check(
		main._transition_fade.visible
		and main._loading_label.text == "Returning to the river..."
		and paused
		and is_instance_valid(game._score_epilogue),
		"Return fading keeps the score postcard paused beneath the transition."
	)
	await create_timer(0.6).timeout
	_check(
		main._current_screen is MainMenu
		and not main._transition_fade.visible
		and not paused
		and main._last_score == 1234,
		"The return transition preserves the final score on the title screen."
	)
	var reduced_preferences := store.get_accessibility_preferences(profile_id)
	reduced_preferences["reduce_motion"] = true
	store.set_accessibility_preferences(profile_id, reduced_preferences)
	main._start_game(profile_id, store.get_profile_name(profile_id), false)
	await process_frame
	await process_frame
	_check(
		main._current_screen is FrogGame
		and not main._transition_fade.visible
		and not main._transitioning,
		"Reduce Motion converts title-to-game loading to an immediate cut."
	)

	main.queue_free()
	await process_frame
	_remove_save_and_backups(save_path)
	await _finish()


func _remove_save_and_backups(save_path: String) -> void:
	var base_name := save_path.get_file()
	for file_name in DirAccess.get_files_at("user://"):
		if (
			str(file_name) == base_name
			or str(file_name).begins_with("%s." % base_name)
		):
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path("user://%s" % file_name)
			)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("UX smoke tests passed.")
		quit(0)
		return
	push_error("UX smoke tests failed: %s" % ", ".join(_failures))
	quit(1)
