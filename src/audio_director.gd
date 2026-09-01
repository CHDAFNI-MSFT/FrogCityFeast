class_name FrogAudioDirector
extends Node

const EFFECT_VOICE_LIMIT := 4
const LOOP_PLAYER_COUNT := 2
const TOTAL_PLAYER_COUNT := EFFECT_VOICE_LIMIT + LOOP_PLAYER_COUNT

const UI_FEEDBACK := &"ui_feedback"
const TONGUE_LAUNCH := &"tongue_launch"
const TONGUE_HIT := &"tongue_hit"
const TONGUE_MISS := &"tongue_miss"
const STRUGGLE_TAP := &"struggle_tap"
const SWALLOW := &"swallow"
const DIGEST := &"digest"
const SPIT := &"spit"
const GROWTH := &"growth"
const DAMAGE := &"damage"
const DISCOVERY := &"discovery"
const CHALLENGE_COMPLETE := &"challenge_complete"
const PURSUIT_ALERT := &"pursuit_alert"
const PURSUIT_ESCAPE := &"pursuit_escape"
const NET_WARNING := &"net_warning"
const FLASHLIGHT_WARNING := &"flashlight_warning"
const WATCHDOG_LUNGE := &"watchdog_lunge"
const TRAP_DEPLOY := &"trap_deploy"
const TRAP_TRIGGER := &"trap_trigger"
const ROADBLOCK_DEPLOY := &"roadblock_deploy"
const ROADBLOCK_HIT := &"roadblock_hit"
const ROADBLOCK_BREAK := &"roadblock_break"
const POWER_ACTIVATE := &"power_activate"
const SHIELD_POP := &"shield_pop"
const ROOM_TRAVEL := &"room_travel"
const DESTRUCTION := &"destruction"
const CLUE_FOUND := &"clue_found"
const ACHIEVEMENT := &"achievement"
const GROWTH_MAJOR := &"growth_major"
const EPILOGUE_OPEN := &"epilogue_open"
const EPILOGUE_RETURN := &"epilogue_return"

const MENU_MUSIC := preload("res://assets/audio/menu_music.wav")
const GAMEPLAY_DAY_MUSIC := preload("res://assets/audio/gameplay_day.wav")
const GAMEPLAY_NIGHT_MUSIC := preload("res://assets/audio/gameplay_night.wav")
const PURSUIT_MUSIC := preload("res://assets/audio/pursuit_music.wav")
const EPILOGUE_MUSIC := preload("res://assets/audio/epilogue_music.wav")
const CITY_DAY := preload("res://assets/audio/city_day.wav")
const CITY_NIGHT := preload("res://assets/audio/city_night.wav")

const EFFECT_STREAMS := {
	UI_FEEDBACK: preload("res://assets/audio/ui_feedback.wav"),
	TONGUE_LAUNCH: preload("res://assets/audio/tongue_launch.wav"),
	TONGUE_HIT: preload("res://assets/audio/tongue_hit.wav"),
	TONGUE_MISS: preload("res://assets/audio/tongue_miss.wav"),
	STRUGGLE_TAP: preload("res://assets/audio/struggle_tap.wav"),
	SWALLOW: preload("res://assets/audio/swallow.wav"),
	DIGEST: preload("res://assets/audio/digest.wav"),
	SPIT: preload("res://assets/audio/spit.wav"),
	GROWTH: preload("res://assets/audio/growth.wav"),
	DAMAGE: preload("res://assets/audio/damage.wav"),
	DISCOVERY: preload("res://assets/audio/discovery.wav"),
	CHALLENGE_COMPLETE: preload(
		"res://assets/audio/challenge_complete.wav"
	),
	PURSUIT_ALERT: preload("res://assets/audio/pursuit_alert.wav"),
	PURSUIT_ESCAPE: preload("res://assets/audio/pursuit_escape.wav"),
	NET_WARNING: preload("res://assets/audio/net_warning.wav"),
	FLASHLIGHT_WARNING: preload(
		"res://assets/audio/flashlight_warning.wav"
	),
	WATCHDOG_LUNGE: preload("res://assets/audio/watchdog_lunge.wav"),
	TRAP_DEPLOY: preload("res://assets/audio/trap_deploy.wav"),
	TRAP_TRIGGER: preload("res://assets/audio/trap_trigger.wav"),
	ROADBLOCK_DEPLOY: preload("res://assets/audio/roadblock_deploy.wav"),
	ROADBLOCK_HIT: preload("res://assets/audio/roadblock_hit.wav"),
	ROADBLOCK_BREAK: preload("res://assets/audio/roadblock_break.wav"),
	POWER_ACTIVATE: preload("res://assets/audio/power_activate.wav"),
	SHIELD_POP: preload("res://assets/audio/shield_pop.wav"),
	ROOM_TRAVEL: preload("res://assets/audio/room_travel.wav"),
	DESTRUCTION: preload("res://assets/audio/destruction.wav"),
	CLUE_FOUND: preload("res://assets/audio/clue_found.wav"),
	ACHIEVEMENT: preload("res://assets/audio/achievement.wav"),
	GROWTH_MAJOR: preload("res://assets/audio/growth_major.wav"),
	EPILOGUE_OPEN: preload("res://assets/audio/epilogue_open.wav"),
	EPILOGUE_RETURN: preload("res://assets/audio/epilogue_return.wav"),
}
const EFFECT_COOLDOWNS_MSEC := {
	UI_FEEDBACK: 90,
	TONGUE_LAUNCH: 70,
	TONGUE_HIT: 70,
	TONGUE_MISS: 140,
	STRUGGLE_TAP: 55,
	SWALLOW: 90,
	DIGEST: 120,
	SPIT: 140,
	GROWTH: 260,
	DAMAGE: 260,
	DISCOVERY: 360,
	CHALLENGE_COMPLETE: 320,
	PURSUIT_ALERT: 500,
	PURSUIT_ESCAPE: 500,
	NET_WARNING: 500,
	FLASHLIGHT_WARNING: 500,
	WATCHDOG_LUNGE: 500,
	TRAP_DEPLOY: 600,
	TRAP_TRIGGER: 400,
	ROADBLOCK_DEPLOY: 600,
	ROADBLOCK_HIT: 120,
	ROADBLOCK_BREAK: 400,
	POWER_ACTIVATE: 180,
	SHIELD_POP: 350,
	ROOM_TRAVEL: 250,
	DESTRUCTION: 240,
	CLUE_FOUND: 400,
	ACHIEVEMENT: 450,
	GROWTH_MAJOR: 400,
	EPILOGUE_OPEN: 500,
	EPILOGUE_RETURN: 500,
}
const EFFECT_VOLUME_DB := {
	UI_FEEDBACK: -8.0,
	TONGUE_LAUNCH: -5.0,
	TONGUE_HIT: -5.0,
	TONGUE_MISS: -7.0,
	STRUGGLE_TAP: -10.0,
	SWALLOW: -4.0,
	DIGEST: -4.0,
	SPIT: -5.0,
	GROWTH: -4.0,
	DAMAGE: -3.0,
	DISCOVERY: -6.0,
	CHALLENGE_COMPLETE: -5.0,
	PURSUIT_ALERT: -4.0,
	PURSUIT_ESCAPE: -6.0,
	NET_WARNING: -4.0,
	FLASHLIGHT_WARNING: -6.0,
	WATCHDOG_LUNGE: -3.0,
	TRAP_DEPLOY: -6.0,
	TRAP_TRIGGER: -4.0,
	ROADBLOCK_DEPLOY: -5.0,
	ROADBLOCK_HIT: -5.0,
	ROADBLOCK_BREAK: -3.0,
	POWER_ACTIVATE: -5.0,
	SHIELD_POP: -3.0,
	ROOM_TRAVEL: -7.0,
	DESTRUCTION: -2.0,
	CLUE_FOUND: -6.0,
	ACHIEVEMENT: -5.0,
	GROWTH_MAJOR: -2.0,
	EPILOGUE_OPEN: -6.0,
	EPILOGUE_RETURN: -7.0,
}
const PITCH_VARIANTS := [0.97, 1.0, 1.035, 1.0]
const MENU_MUSIC_VOLUME_DB := -11.0
const GAMEPLAY_MUSIC_VOLUME_DB := -13.0
const PURSUIT_MUSIC_VOLUME_DB := -11.5
const EPILOGUE_MUSIC_VOLUME_DB := -12.0
const AMBIENCE_VOLUME_DB := -15.0

var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _effect_players: Array[AudioStreamPlayer] = []
var _loop_streams: Dictionary = {}
var _context: Node
var _context_kind := ""
var _current_music_key := ""
var _current_ambience_key := ""
var _game_is_night := false
var _pursuit_active := false
var _effect_voice_cursor := 0
var _last_effect_msec: Dictionary = {}
var _effect_play_counts: Dictionary = {}
var _music_start_count := 0
var _ambience_start_count := 0
var _preferences := AudioPreferences.defaults()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_validate_buses()
	_create_players()
	_loop_streams = {
		"menu": _prepare_loop(MENU_MUSIC),
		"gameplay_day": _prepare_loop(GAMEPLAY_DAY_MUSIC),
		"gameplay_night": _prepare_loop(GAMEPLAY_NIGHT_MUSIC),
		"pursuit": _prepare_loop(PURSUIT_MUSIC),
		"epilogue": _prepare_loop(EPILOGUE_MUSIC),
		"day": _prepare_loop(CITY_DAY),
		"night": _prepare_loop(CITY_NIGHT),
	}
	apply_preferences(_preferences)


func _exit_tree() -> void:
	_stop_music()
	_stop_ambience()
	for player in _effect_players:
		player.stop()
		player.stream = null
	_loop_streams.clear()
	_context = null


func enter_menu(context: Node, preferences: Dictionary) -> void:
	_context = context
	_context_kind = "menu"
	_game_is_night = false
	_pursuit_active = false
	apply_preferences(preferences)
	_play_music("menu", MENU_MUSIC_VOLUME_DB)
	_stop_ambience()


func enter_game(
	context: Node,
	preferences: Dictionary,
	is_night: bool
) -> void:
	_context = context
	_context_kind = "game"
	_game_is_night = is_night
	_pursuit_active = false
	apply_preferences(preferences)
	_play_music(
		"gameplay_night" if is_night else "gameplay_day",
		GAMEPLAY_MUSIC_VOLUME_DB
	)
	_play_ambience("night" if is_night else "day")


func set_game_ambience(context: Node, is_night: bool) -> void:
	if (
		_context_kind != "game"
		or not is_instance_valid(_context)
		or _context != context
	):
		return
	_game_is_night = is_night
	if not _pursuit_active:
		_play_music(
			"gameplay_night" if is_night else "gameplay_day",
			GAMEPLAY_MUSIC_VOLUME_DB
		)
	_play_ambience("night" if is_night else "day")


func set_pursuit(context: Node, active: bool) -> void:
	if (
		_context_kind != "game"
		or not is_instance_valid(_context)
		or _context != context
		or _pursuit_active == active
	):
		return
	_pursuit_active = active
	_play_music(
		"pursuit"
		if active
		else (
			"gameplay_night"
			if _game_is_night
			else "gameplay_day"
		),
		PURSUIT_MUSIC_VOLUME_DB
		if active
		else GAMEPLAY_MUSIC_VOLUME_DB
	)


func enter_epilogue(context: Node) -> void:
	if not is_instance_valid(context):
		return
	_context = context
	_context_kind = "epilogue"
	_pursuit_active = false
	_play_music("epilogue", EPILOGUE_MUSIC_VOLUME_DB)
	_stop_ambience()


func leave_context(context: Node) -> void:
	if not is_instance_valid(_context) or _context != context:
		return
	_stop_music()
	_stop_ambience()
	_context = null
	_context_kind = ""
	_game_is_night = false
	_pursuit_active = false


func apply_preferences(value: Variant) -> void:
	_preferences = AudioPreferences.sanitize_preferences(value)
	_set_bus_volume(&"Master", float(_preferences["master"]))
	_set_bus_volume(&"Music", float(_preferences["music"]))
	_set_bus_volume(&"Effects", float(_preferences["effects"]))


func current_preferences() -> Dictionary:
	return _preferences.duplicate()


func play_effect(
	event_id: StringName,
	now_msec: int = -1
) -> bool:
	if not EFFECT_STREAMS.has(event_id):
		push_warning("Unknown Frog City Feast audio event: %s" % event_id)
		return false
	var timestamp := (
		Time.get_ticks_msec()
		if now_msec < 0
		else now_msec
	)
	var last_played := int(_last_effect_msec.get(event_id, -1000000))
	var cooldown := int(EFFECT_COOLDOWNS_MSEC[event_id])
	if timestamp - last_played < cooldown:
		return false
	_last_effect_msec[event_id] = timestamp

	var play_count := int(_effect_play_counts.get(event_id, 0))
	var player := _effect_players[_effect_voice_cursor]
	_effect_voice_cursor = (
		(_effect_voice_cursor + 1) % _effect_players.size()
	)
	player.stop()
	player.stream = EFFECT_STREAMS[event_id]
	player.volume_db = float(EFFECT_VOLUME_DB[event_id])
	player.pitch_scale = PITCH_VARIANTS[play_count % PITCH_VARIANTS.size()]
	player.play()
	_effect_play_counts[event_id] = play_count + 1
	return true


func effect_play_count(event_id: StringName) -> int:
	return int(_effect_play_counts.get(event_id, 0))


func effect_voice_count() -> int:
	return _effect_players.size()


func active_effect_voice_count() -> int:
	var active := 0
	for player in _effect_players:
		if player.playing:
			active += 1
	return active


func structure_snapshot() -> Dictionary:
	return {
		"audio_nodes": 1 + TOTAL_PLAYER_COUNT,
		"audio_players": TOTAL_PLAYER_COUNT,
		"audio_effect_voices": _effect_players.size(),
		"audio_active_effect_voices": active_effect_voice_count(),
		"audio_context": _context_kind,
		"pursuit_active": _pursuit_active,
		"music_key": _current_music_key,
		"ambience_key": _current_ambience_key,
		"music_start_count": _music_start_count,
		"ambience_start_count": _ambience_start_count,
	}


func reset_for_tests() -> void:
	_stop_music()
	_stop_ambience()
	for player in _effect_players:
		player.stop()
		player.stream = null
	_context = null
	_context_kind = ""
	_game_is_night = false
	_pursuit_active = false
	_effect_voice_cursor = 0
	_last_effect_msec.clear()
	_effect_play_counts.clear()
	_music_start_count = 0
	_ambience_start_count = 0
	apply_preferences(AudioPreferences.defaults())


func _validate_buses() -> void:
	for bus_name in [&"Master", &"Music", &"Effects"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			push_error("Required audio bus is missing: %s" % bus_name)


func _create_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = &"Music"
	_ambience_player.volume_db = AMBIENCE_VOLUME_DB
	add_child(_ambience_player)

	for index in EFFECT_VOICE_LIMIT:
		var player := AudioStreamPlayer.new()
		player.name = "EffectVoice%d" % (index + 1)
		player.bus = &"Effects"
		add_child(player)
		_effect_players.append(player)


func _prepare_loop(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = maxi(
		1,
		roundi(stream.get_length() * float(stream.mix_rate))
	)
	return stream


func _play_music(key: String, volume_db: float) -> void:
	if _current_music_key == key:
		return
	_current_music_key = key
	_music_player.stop()
	_music_player.stream = _loop_streams[key]
	_music_player.volume_db = volume_db
	_music_player.play()
	_music_start_count += 1


func _play_ambience(key: String) -> void:
	if _current_ambience_key == key:
		return
	_current_ambience_key = key
	_ambience_player.stop()
	_ambience_player.stream = _loop_streams[key]
	_ambience_player.volume_db = AMBIENCE_VOLUME_DB
	_ambience_player.play()
	_ambience_start_count += 1


func _stop_music() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	_current_music_key = ""


func _stop_ambience() -> void:
	if is_instance_valid(_ambience_player):
		_ambience_player.stop()
		_ambience_player.stream = null
	_current_ambience_key = ""


func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Cannot set missing audio bus: %s" % bus_name)
		return
	var muted := volume <= 0.0
	AudioServer.set_bus_mute(bus_index, muted)
	AudioServer.set_bus_volume_db(
		bus_index,
		AudioPreferences.volume_to_db(volume)
	)
