extends SceneTree

const AUDIO_PATHS := [
	"res://assets/audio/ui_feedback.wav",
	"res://assets/audio/tongue_launch.wav",
	"res://assets/audio/tongue_hit.wav",
	"res://assets/audio/tongue_miss.wav",
	"res://assets/audio/struggle_tap.wav",
	"res://assets/audio/swallow.wav",
	"res://assets/audio/digest.wav",
	"res://assets/audio/spit.wav",
	"res://assets/audio/growth.wav",
	"res://assets/audio/damage.wav",
	"res://assets/audio/discovery.wav",
	"res://assets/audio/challenge_complete.wav",
	"res://assets/audio/pursuit_alert.wav",
	"res://assets/audio/pursuit_escape.wav",
	"res://assets/audio/net_warning.wav",
	"res://assets/audio/flashlight_warning.wav",
	"res://assets/audio/watchdog_lunge.wav",
	"res://assets/audio/trap_deploy.wav",
	"res://assets/audio/trap_trigger.wav",
	"res://assets/audio/roadblock_deploy.wav",
	"res://assets/audio/roadblock_hit.wav",
	"res://assets/audio/roadblock_break.wav",
	"res://assets/audio/power_activate.wav",
	"res://assets/audio/shield_pop.wav",
	"res://assets/audio/room_travel.wav",
	"res://assets/audio/destruction.wav",
	"res://assets/audio/clue_found.wav",
	"res://assets/audio/achievement.wav",
	"res://assets/audio/growth_major.wav",
	"res://assets/audio/epilogue_open.wav",
	"res://assets/audio/epilogue_return.wav",
	"res://assets/audio/city_day.wav",
	"res://assets/audio/city_night.wav",
	"res://assets/audio/menu_music.wav",
	"res://assets/audio/gameplay_day.wav",
	"res://assets/audio/gameplay_night.wav",
	"res://assets/audio/pursuit_music.wav",
	"res://assets/audio/epilogue_music.wav",
]
const LOOP_PATHS := [
	"res://assets/audio/city_day.wav",
	"res://assets/audio/city_night.wav",
	"res://assets/audio/menu_music.wav",
	"res://assets/audio/gameplay_day.wav",
	"res://assets/audio/gameplay_night.wav",
	"res://assets/audio/pursuit_music.wav",
	"res://assets/audio/epilogue_music.wav",
]
const PRODUCTION_EFFECT_IDS := [
	FrogAudioDirector.PURSUIT_ALERT,
	FrogAudioDirector.PURSUIT_ESCAPE,
	FrogAudioDirector.NET_WARNING,
	FrogAudioDirector.FLASHLIGHT_WARNING,
	FrogAudioDirector.WATCHDOG_LUNGE,
	FrogAudioDirector.TRAP_DEPLOY,
	FrogAudioDirector.TRAP_TRIGGER,
	FrogAudioDirector.ROADBLOCK_DEPLOY,
	FrogAudioDirector.ROADBLOCK_HIT,
	FrogAudioDirector.ROADBLOCK_BREAK,
	FrogAudioDirector.POWER_ACTIVATE,
	FrogAudioDirector.SHIELD_POP,
	FrogAudioDirector.ROOM_TRAVEL,
	FrogAudioDirector.DESTRUCTION,
	FrogAudioDirector.CLUE_FOUND,
	FrogAudioDirector.ACHIEVEMENT,
	FrogAudioDirector.GROWTH_MAJOR,
	FrogAudioDirector.EPILOGUE_OPEN,
	FrogAudioDirector.EPILOGUE_RETURN,
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	AudioDirector.reset_for_tests()
	_test_buses_assets_and_limits()
	_test_cooldowns_and_rng_isolation()
	_test_production_effect_inventory()
	_test_profile_compatibility()
	await _test_controls_events_and_lifecycle()
	await _finish()


func _test_buses_assets_and_limits() -> void:
	var master_index := AudioServer.get_bus_index(&"Master")
	var music_index := AudioServer.get_bus_index(&"Music")
	var effects_index := AudioServer.get_bus_index(&"Effects")
	_check(
		master_index == 0
			and music_index >= 0
			and effects_index >= 0
			and AudioServer.get_bus_send(music_index) == &"Master"
			and AudioServer.get_bus_send(effects_index) == &"Master",
		"Master, Music, and Effects buses load with explicit routing."
	)

	var total_bytes := 0
	var resources_are_valid := true
	for path in AUDIO_PATHS:
		var stream := load(path)
		if stream is not AudioStreamWAV or stream.get_length() <= 0.0:
			resources_are_valid = false
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			resources_are_valid = false
			continue
		var header := file.get_buffer(44)
		total_bytes += file.get_length()
		var peak_sample := 0
		while file.get_position() + 1 < file.get_length():
			var raw_sample := file.get_16()
			var signed_sample := (
				raw_sample - 65536
				if raw_sample >= 32768
				else raw_sample
			)
			peak_sample = maxi(peak_sample, absi(signed_sample))
		file.close()
		if (
			header.size() < 44
			or header.slice(0, 4).get_string_from_ascii() != "RIFF"
			or header.slice(8, 12).get_string_from_ascii() != "WAVE"
			or header.decode_u16(22) != 1
			or header.decode_u32(24) != 22050
			or header.decode_u16(34) != 16
			or peak_sample < 512
		):
			resources_are_valid = false
		var import_text := FileAccess.get_file_as_string(path + ".import")
		if (
			not import_text.contains('importer="wav"')
			or not import_text.contains('type="AudioStreamWAV"')
		):
			resources_are_valid = false
	_check(
		resources_are_valid
			and total_bytes < 2 * 1024 * 1024,
		"All 38 original WAV assets are non-silent mono 22.05 kHz, importable, and under 2 MiB."
	)

	var loop_lengths_are_valid := true
	for path in LOOP_PATHS:
		var loop_stream := load(path) as AudioStreamWAV
		if not is_equal_approx(loop_stream.get_length(), 4.0):
			loop_lengths_are_valid = false
	var director := AudioDirector.director()
	for key in [
		"menu",
		"gameplay_day",
		"gameplay_night",
		"pursuit",
		"epilogue",
		"day",
		"night",
	]:
		var runtime_loop := director._loop_streams[key] as AudioStreamWAV
		if (
			runtime_loop.loop_mode != AudioStreamWAV.LOOP_FORWARD
			or runtime_loop.loop_begin != 0
			or runtime_loop.loop_end <= 0
		):
			loop_lengths_are_valid = false
	_check(
		loop_lengths_are_valid,
		"Music and ambience are exact four-second assets with runtime loop boundaries."
	)

	var provenance := FileAccess.get_file_as_string(
		"res://assets/audio/README.md"
	)
	var generator := FileAccess.get_file_as_string(
		"res://scripts/generate-audio.ps1"
	)
	_check(
		provenance.contains("No recordings, sample libraries")
			and provenance.contains("reuse outside")
			and provenance.contains("requires the owner's permission")
			and generator.contains("Write-MonoWav")
			and generator.contains("Add-Pluck")
			and generator.contains("New-MusicLoop")
			and generator.contains("New-AmbienceLoop"),
		"Audio provenance, reproduction, and licensing are recorded with the generator."
	)

	var structure := director.structure_snapshot()
	_check(
		director.get_child_count()
			== FrogAudioDirector.TOTAL_PLAYER_COUNT
			and int(structure["audio_nodes"])
			== PerformanceBudgets.MAX_AUDIO_NODES
			and int(structure["audio_players"])
			== PerformanceBudgets.MAX_AUDIO_PLAYERS
			and int(structure["audio_effect_voices"])
			== PerformanceBudgets.MAX_AUDIO_EFFECT_VOICES,
		"Audio uses one fixed loop pair and four reusable effect voices."
	)


func _test_cooldowns_and_rng_isolation() -> void:
	AudioDirector.reset_for_tests()
	var first_play := AudioDirector.play_effect(
		FrogAudioDirector.STRUGGLE_TAP,
		1000
	)
	var blocked_play := AudioDirector.play_effect(
		FrogAudioDirector.STRUGGLE_TAP,
		1030
	)
	var second_play := AudioDirector.play_effect(
		FrogAudioDirector.STRUGGLE_TAP,
		1060
	)
	_check(
		first_play
			and not blocked_play
			and second_play
			and AudioDirector.effect_play_count(
				FrogAudioDirector.STRUGGLE_TAP
			) == 2,
		"Per-event cooldowns bound rapid struggle feedback."
	)

	for index in 40:
		AudioDirector.play_effect(
			FrogAudioDirector.TONGUE_HIT,
			2000 + index * 80
		)
	var director := AudioDirector.director()
	_check(
		director.effect_voice_count()
			== FrogAudioDirector.EFFECT_VOICE_LIMIT
			and director.active_effect_voice_count()
			<= FrogAudioDirector.EFFECT_VOICE_LIMIT
			and director.get_child_count()
			== FrogAudioDirector.TOTAL_PLAYER_COUNT,
		"Repeated effects steal fixed voices without allocating players."
	)

	seed(20260830)
	var expected_random := randf()
	seed(20260830)
	AudioDirector.reset_for_tests()
	for index in 12:
		AudioDirector.play_effect(
			FrogAudioDirector.UI_FEEDBACK,
			3000 + index * 100
		)
	var actual_random := randf()
	_check(
		is_equal_approx(actual_random, expected_random),
		"Audio variation never consumes the gameplay random-number stream."
	)


func _test_production_effect_inventory() -> void:
	var inventory_is_complete := (
		FrogAudioDirector.EFFECT_STREAMS.size() == 31
		and FrogAudioDirector.EFFECT_COOLDOWNS_MSEC.size() == 31
		and FrogAudioDirector.EFFECT_VOLUME_DB.size() == 31
	)
	for effect_id in PRODUCTION_EFFECT_IDS:
		inventory_is_complete = (
			inventory_is_complete
			and FrogAudioDirector.EFFECT_STREAMS.has(effect_id)
			and FrogAudioDirector.EFFECT_COOLDOWNS_MSEC.has(effect_id)
			and FrogAudioDirector.EFFECT_VOLUME_DB.has(effect_id)
		)
	_check(
		inventory_is_complete,
		"Every production event has a stream, cooldown, and volume balance."
	)

	var game_source := FileAccess.get_file_as_string(
		"res://src/game.gd"
	)
	var pursuer_source := FileAccess.get_file_as_string(
		"res://src/pursuer.gd"
	)
	var service_source := FileAccess.get_file_as_string(
		"res://src/audio_service.gd"
	)
	_check(
		game_source.contains("FrogAudioDirector.PURSUIT_ALERT")
			and game_source.contains("FrogAudioDirector.PURSUIT_ESCAPE")
			and game_source.contains("FrogAudioDirector.ROADBLOCK_DEPLOY")
			and game_source.contains("FrogAudioDirector.TRAP_TRIGGER")
			and game_source.contains("FrogAudioDirector.POWER_ACTIVATE")
			and game_source.contains("FrogAudioDirector.SHIELD_POP")
			and game_source.contains("FrogAudioDirector.ROOM_TRAVEL")
			and game_source.contains("FrogAudioDirector.DESTRUCTION")
			and game_source.contains("FrogAudioDirector.CLUE_FOUND")
			and game_source.contains("FrogAudioDirector.ACHIEVEMENT")
			and game_source.contains("FrogAudioDirector.GROWTH_MAJOR")
			and game_source.contains("FrogAudioDirector.EPILOGUE_OPEN")
			and game_source.contains("FrogAudioDirector.EPILOGUE_RETURN")
			and pursuer_source.contains(
				"attack_started.emit(ATTACK_NET)"
			)
			and pursuer_source.contains(
				"attack_started.emit(ATTACK_FLASHLIGHT)"
			)
			and pursuer_source.contains(
				"attack_started.emit(ATTACK_LUNGE)"
			)
			and service_source.contains("static func set_pursuit")
			and service_source.contains("static func enter_epilogue"),
		"Production pursuit, obstacle, power, progression, travel, destruction, and epilogue events are wired."
	)


func _test_profile_compatibility() -> void:
	_check(
		AudioPreferences.sanitize_preferences({
			"master": 2.0,
			"music": -1.0,
			"effects": "0.5",
		}) == {
			"master": 1.0,
			"music": 0.0,
			"effects": AudioPreferences.DEFAULT_EFFECTS,
		}
			and is_equal_approx(
				AudioPreferences.volume_to_db(1.0),
				0.0
			)
			and AudioPreferences.volume_to_db(0.0) == -80.0,
		"Audio preferences clamp numeric values and reject malformed save data."
	)

	var save_path := "user://audio_smoke_scores.cfg"
	var absolute_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)
	var store := ProfileStore.new(save_path)
	var profile_id := str(store.list_profiles()[0]["id"])
	store.update_high_scores(profile_id, 321)
	store.mark_tutorial_complete(profile_id)
	store.mark_discovered(profile_id, "street_donut")
	_check(
		store.get_audio_preferences(profile_id)
		== AudioPreferences.defaults(),
		"Existing version 1 profiles use documented audio defaults."
	)
	var saved_preferences := {
		"master": 0.65,
		"music": 0.35,
		"effects": 0.55,
	}
	store.set_audio_preferences(profile_id, saved_preferences)
	var reloaded := ProfileStore.new(save_path)
	_check(
		reloaded.get_audio_preferences(profile_id) == saved_preferences
			and reloaded.get_profile_best(profile_id) == 321
			and reloaded.is_tutorial_complete(profile_id)
			and reloaded.get_discoveries(profile_id)
			== PackedStringArray(["street_donut"])
		and ProfileStore.SAVE_VERSION == 3,
		"Audio preferences persist through the version 3 progression save."
	)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)

	var legacy_path := "user://audio_smoke_legacy.cfg"
	var absolute_legacy_path := ProjectSettings.globalize_path(legacy_path)
	var legacy := ConfigFile.new()
	legacy.set_value("meta", "version", 1)
	legacy.set_value("profiles", "legacy", "Legacy Audio Frog")
	legacy.set_value("scores", "legacy", 88)
	legacy.save(legacy_path)
	var legacy_store := ProfileStore.new(legacy_path)
	_check(
		legacy_store.get_audio_preferences("legacy")
			== AudioPreferences.defaults()
			and legacy_store.get_profile_best("legacy") == 88,
		"Legacy version 1 saves without audio fields load unchanged with defaults."
	)
	for file_name in DirAccess.get_files_at("user://"):
		if str(file_name).begins_with(
			"audio_smoke_legacy.cfg.migration-v1-to-v2-"
		):
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path("user://%s" % file_name)
			)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(absolute_legacy_path)


func _test_controls_events_and_lifecycle() -> void:
	var save_path := "user://audio_ui_smoke.cfg"
	var absolute_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)
	var store := ProfileStore.new(save_path)
	var profile_id := str(store.list_profiles()[0]["id"])
	var stored_preferences := {
		"master": 0.65,
		"music": 0.35,
		"effects": 0.55,
	}
	store.set_audio_preferences(profile_id, stored_preferences)

	var menu := (
		load("res://scenes/menu.tscn") as PackedScene
	).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	menu.configure(store, 0)
	_check(
		menu._audio_preferences_from_controls() == stored_preferences,
		"Menu loads the selected profile's Master, Music, and Effects values."
	)
	menu._master_volume_slider.value = 60.0
	await process_frame
	_check(
		store.get_audio_preferences(profile_id)["master"] == 0.6
			and AudioDirector.director().current_preferences()["master"]
			== 0.6,
		"Menu sliders apply live and persist non-drag changes."
	)
	menu.activate_audio_context()
	var menu_snapshot := AudioDirector.structure_snapshot()
	_check(
		menu_snapshot["audio_context"] == "menu"
			and menu_snapshot["music_key"] == "menu"
			and menu_snapshot["ambience_key"] == "",
		"Menu context starts exactly one music loop and no city ambience."
	)

	var game_preferences := {
		"master": 0.7,
		"music": 0.4,
		"effects": 0.75,
	}
	var game := (
		load("res://scenes/game.tscn") as PackedScene
	).instantiate() as FrogGame
	game.configure(
		profile_id,
		"Audio Frog",
		false,
		PackedStringArray(),
		{},
		game_preferences
	)
	var audio_events: Array[Dictionary] = []
	game.audio_changed.connect(func(preferences: Dictionary) -> void:
		audio_events.append(preferences)
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	_check(
		game._audio_preferences_from_controls() == game_preferences,
		"Game Options loads the same three per-profile audio values."
	)
	game._effects_volume_slider.value = 65.0
	await process_frame
	_check(
		audio_events == [{
			"master": 0.7,
			"music": 0.4,
			"effects": 0.65,
		}],
		"Game Options emits one sanitized preference update outside a drag."
	)

	AudioDirector.reset_for_tests()
	var score_before_audio := game._score
	var growth_before_audio := game._growth_points
	var far_world := (
		game._frog.global_position
		+ Vector2.RIGHT * (game._frog.tongue_range() + 200.0)
	)
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform() * far_world
	)
	_check(
		AudioDirector.effect_play_count(
			FrogAudioDirector.TONGUE_LAUNCH
		) == 1
			and AudioDirector.effect_play_count(
				FrogAudioDirector.TONGUE_MISS
			) == 1
			and game._score == score_before_audio
			and game._growth_points == growth_before_audio,
		"Tongue launch and miss audio preserve score and growth outcomes."
	)

	AudioDirector.reset_for_tests()
	var donut := game._find_target_by_id("street_donut")
	game._tongue_recovery = 0.0
	game._try_tongue_at_screen(
		game.get_viewport().get_canvas_transform()
		* donut.global_position
	)
	_check(
		AudioDirector.effect_play_count(
			FrogAudioDirector.TONGUE_LAUNCH
		) == 1
			and AudioDirector.effect_play_count(
				FrogAudioDirector.TONGUE_HIT
			) == 1
			and AudioDirector.effect_play_count(
				FrogAudioDirector.SWALLOW
			) == 1
			and AudioDirector.effect_play_count(
				FrogAudioDirector.DISCOVERY
			) == 1
			and game._belly.size() == 1
			and game._score == score_before_audio,
		"Tongue hit, swallow, and discovery events are wired after normal capture resolution."
	)

	AudioDirector.reset_for_tests()
	game._belly[0].restockable = false
	game._digest_item(0)
	_check(
		AudioDirector.effect_play_count(FrogAudioDirector.DIGEST) == 1
			and game._score > score_before_audio
			and game._growth_points > growth_before_audio,
		"Digest audio accompanies the existing points and growth result."
	)

	var hotdog := game._find_target_by_id("running_hotdog")
	AudioDirector.reset_for_tests()
	game._begin_struggle(hotdog, 0.8, Vector2.ZERO)
	game._register_struggle_tap()
	_check(
		AudioDirector.effect_play_count(
			FrogAudioDirector.STRUGGLE_TAP
		) == 1
			and game._struggle_taps == 1,
		"Struggle audio is bounded without changing tap progress."
	)
	game._clear_struggle()

	var apple := game._find_target_by_id("market_apple")
	game._swallow_target(apple, 1.0)
	AudioDirector.reset_for_tests()
	var target_count_before_spit := game._targets.size()
	game._spit_item(game._belly.size() - 1)
	_check(
		AudioDirector.effect_play_count(FrogAudioDirector.SPIT) == 1
			and game._targets.size() == target_count_before_spit + 1,
		"Spit audio preserves safe target restoration."
	)

	AudioDirector.reset_for_tests()
	game._apply_growth_tier(1)
	game._damage_cooldown = 0.0
	game._apply_damage(
		game._frog.global_position + Vector2.LEFT,
		1,
		"Audio damage test"
	)
	game._on_challenge_completed(SessionChallenges.SHARP_AIM)
	_check(
		AudioDirector.effect_play_count(FrogAudioDirector.GROWTH) == 1
			and AudioDirector.effect_play_count(
				FrogAudioDirector.DAMAGE
			) == 1
			and AudioDirector.effect_play_count(
				FrogAudioDirector.CHALLENGE_COMPLETE
			) == 1,
		"Growth, damage, and challenge completion use distinct semantic sounds."
	)

	AudioDirector.reset_for_tests()
	game._apply_growth_tier(GameplayTuning.ENORMOUS_TIER)
	game._apply_growth_tier(GameplayTuning.LARGE_TIER)
	game._activate_power(TemporaryPowerState.SPEED_BURST, 1.0)
	game._power_state.activate(TemporaryPowerState.BUBBLE_SHIELD, 1.0)
	game._damage_cooldown = 0.0
	game._apply_damage(
		game._frog.global_position + Vector2.LEFT,
		1,
		"Shield audio test",
		true
	)
	_check(
		AudioDirector.effect_play_count(
			FrogAudioDirector.GROWTH_MAJOR
		) == 1
			and AudioDirector.effect_play_count(
				FrogAudioDirector.POWER_ACTIVATE
			) == 1
			and AudioDirector.effect_play_count(
				FrogAudioDirector.SHIELD_POP
			) == 1,
		"Major growth, temporary powers, and shield consumption have distinct feedback."
	)

	AudioDirector.reset_for_tests()
	game.activate_audio_context()
	var game_snapshot := AudioDirector.structure_snapshot()
	var music_starts := int(game_snapshot["music_start_count"])
	var ambience_starts := int(game_snapshot["ambience_start_count"])
	game.activate_audio_context()
	game._day_clock = 0.5
	game._update_day_night(0.0)
	game._update_day_night(0.0)
	var day_snapshot := AudioDirector.structure_snapshot()
	game._day_clock = 0.0
	game._update_day_night(0.0)
	game._update_day_night(0.0)
	var night_snapshot := AudioDirector.structure_snapshot()
	AudioDirector.set_pursuit(game, true)
	AudioDirector.set_pursuit(game, true)
	var pursuit_snapshot := AudioDirector.structure_snapshot()
	game._day_clock = 0.5
	game._update_day_night(0.0)
	var pursuit_day_snapshot := AudioDirector.structure_snapshot()
	AudioDirector.set_pursuit(game, false)
	var resumed_snapshot := AudioDirector.structure_snapshot()
	AudioDirector.enter_epilogue(game)
	var epilogue_snapshot := AudioDirector.structure_snapshot()
	_check(
		game_snapshot["audio_context"] == "game"
			and game_snapshot["music_key"] == "gameplay_day"
			and music_starts == 1
			and int(day_snapshot["music_start_count"]) == 1
			and int(day_snapshot["ambience_start_count"])
			<= ambience_starts + 1
			and night_snapshot["music_key"] == "gameplay_night"
			and night_snapshot["ambience_key"] == "night"
			and int(night_snapshot["music_start_count"]) == 2
			and int(night_snapshot["ambience_start_count"])
			<= ambience_starts + 2
			and pursuit_snapshot["music_key"] == "pursuit"
			and pursuit_snapshot["pursuit_active"]
			and int(pursuit_snapshot["music_start_count"]) == 3
			and pursuit_day_snapshot["music_key"] == "pursuit"
			and int(pursuit_day_snapshot["music_start_count"]) == 3
			and resumed_snapshot["music_key"] == "gameplay_day"
			and not resumed_snapshot["pursuit_active"]
			and int(resumed_snapshot["music_start_count"]) == 4
			and epilogue_snapshot["audio_context"] == "epilogue"
			and epilogue_snapshot["music_key"] == "epilogue"
			and epilogue_snapshot["ambience_key"] == ""
			and int(epilogue_snapshot["music_start_count"]) == 5
			and int(epilogue_snapshot["audio_players"])
			== FrogAudioDirector.TOTAL_PLAYER_COUNT,
		"Day, night, pursuit, recovery, and epilogue contexts reuse one loop pair without stacking players."
	)

	menu.queue_free()
	await process_frame
	_check(
		AudioDirector.structure_snapshot()["audio_context"] == "epilogue",
		"Removing an older menu cannot stop the active epilogue context."
	)
	game.queue_free()
	await process_frame
	var stopped_snapshot := AudioDirector.structure_snapshot()
	_check(
		stopped_snapshot["audio_context"] == ""
			and stopped_snapshot["music_key"] == ""
			and stopped_snapshot["ambience_key"] == "",
		"Removing the active game stops both loops and clears its context."
	)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)


func _finish() -> void:
	paused = false
	AudioDirector.reset_for_tests()
	await create_timer(0.2).timeout
	AudioDirector.shutdown_for_tests()
	for _frame in 4:
		await process_frame
	if _failures.is_empty():
		print("Audio smoke tests passed.")
		quit(0)
	else:
		print("Audio smoke tests failed: %s" % ", ".join(_failures))
		quit(1)
