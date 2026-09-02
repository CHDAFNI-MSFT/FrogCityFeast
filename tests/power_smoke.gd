extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_power_state()
	await _test_game_integration()
	await _finish()


func _test_power_state() -> void:
	var powers := TemporaryPowerState.new()
	_check(
		powers.activate(TemporaryPowerState.SPEED_BURST)
		and is_equal_approx(
			powers.remaining(TemporaryPowerState.SPEED_BURST),
			20.0
		),
		"Speed Burst starts with its exact standard duration."
	)
	powers.advance(5.0)
	_check(
		is_equal_approx(
			powers.remaining(TemporaryPowerState.SPEED_BURST),
			15.0
		),
		"Power timers advance deterministically during active play."
	)
	powers.activate(TemporaryPowerState.SPEED_BURST)
	_check(
		is_equal_approx(
			powers.remaining(TemporaryPowerState.SPEED_BURST),
			20.0
		),
		"Recollecting a power refreshes without stacking durations."
	)
	powers.activate(TemporaryPowerState.LONG_TONGUE)
	var active_before_pause := powers.active_ids()
	powers.advance(8.0, true)
	_check(
		active_before_pause == powers.active_ids()
		and is_equal_approx(
			powers.remaining(TemporaryPowerState.SPEED_BURST),
			20.0
		)
		and is_equal_approx(
			powers.remaining(TemporaryPowerState.LONG_TONGUE),
			30.0
		),
		"Different powers coexist and paused updates consume no duration."
	)
	powers.activate(TemporaryPowerState.BUBBLE_SHIELD)
	_check(
		powers.consume(TemporaryPowerState.BUBBLE_SHIELD)
		and not powers.consume(TemporaryPowerState.BUBBLE_SHIELD),
		"Bubble Shield is a one-charge power."
	)
	_check(
		not powers.activate("unknown")
		and not powers.set_remaining("unknown", 10.0),
		"Unknown power IDs are rejected."
	)


func _test_game_integration() -> void:
	var scene := load("res://scenes/game.tscn") as PackedScene
	var game := scene.instantiate() as FrogGame
	game.configure(
		"power_test",
		"Power Tester",
		false,
		PackedStringArray(),
		{},
		{},
		0x504f5745,
		PackedStringArray(["flight"])
	)
	var discovered: Array[String] = []
	game.power_discovered.connect(func(power_id: String) -> void:
		discovered.append(power_id)
	)
	root.add_child(game)
	await process_frame
	await physics_frame

	var base_range := game._frog.tongue_range()
	game._activate_power(TemporaryPowerState.SPEED_BURST)
	game._activate_power(TemporaryPowerState.LONG_TONGUE)
	_check(
		is_equal_approx(game._frog.ground_speed_multiplier, 1.35)
		and is_equal_approx(game._frog.tongue_range(), base_range * 1.4)
		and is_equal_approx(
			game._adjusted_tongue_recovery(FrogGame.TONGUE_RECOVERY),
			FrogGame.TONGUE_RECOVERY * 0.8
		),
		"Speed Burst and Long Tongue apply exact movement, range, and recovery rules."
	)
	_check(
		game._power_label.text.contains("Long Tongue")
		and game._power_label.text.contains("(+1)")
		and game._power_label.tooltip_text.contains("Speed Burst")
		and game._power_label.tooltip_text.contains("Long Tongue")
		and game._status_label.text.contains("ACTIVE")
		and not game._power_label.text.contains("S20")
		and not game._power_label.text.contains("T30"),
		"Active powers use readable names and explicitly announce automatic use."
	)
	_check(
		discovered == [
			TemporaryPowerState.SPEED_BURST,
			TemporaryPowerState.LONG_TONGUE,
		],
		"Only newly discovered powers emit persistence events."
	)
	game._activate_power(TemporaryPowerState.SPEED_BURST)
	_check(
		discovered.size() == 2,
		"Recollecting a known power cannot farm discovery progress."
	)

	var speed_remaining := game._power_state.remaining(
		TemporaryPowerState.SPEED_BURST
	)
	game._open_guide()
	game._process(5.0)
	_check(
		is_equal_approx(
			game._power_state.remaining(TemporaryPowerState.SPEED_BURST),
			speed_remaining
		),
		"Power durations pause with the Field Guide overlay."
	)
	game._close_guide()
	game._interior_transition_phase = (
		FrogGame.InteriorTransitionPhase.FADE_OUT
	)
	game._interior_transition_time = 0.0
	game._process(0.01)
	_check(
		game._power_state.is_active(TemporaryPowerState.SPEED_BURST),
		"Powers persist through room transitions."
	)
	game._interior_transition_phase = FrogGame.InteriorTransitionPhase.NONE

	game._activate_power(TemporaryPowerState.CAMOUFLAGE)
	game._spawn_pursuer(PrototypePursuer.ARCHETYPE_ANIMAL_CONTROL)
	_check(
		not is_instance_valid(game._pursuer),
		"Camouflage blocks new pursuit calls."
	)
	game._power_state.consume(TemporaryPowerState.CAMOUFLAGE)
	game._apply_power_effects()
	game._spawn_pursuer(PrototypePursuer.ARCHETYPE_SECURITY_GUARD)
	_check(
		is_instance_valid(game._pursuer),
		"Pursuit can start after Camouflage ends."
	)
	game._activate_power(TemporaryPowerState.CAMOUFLAGE)
	var pursuer := game._pursuer
	pursuer._physics_process(PrototypePursuer.CAMOUFLAGE_ESCAPE_TIME)
	_check(
		not pursuer.active,
		"Camouflage ends an existing pursuit after the exact loss duration."
	)
	await process_frame
	game._pursuer = null

	game._score = 100
	game._activate_power(TemporaryPowerState.BUBBLE_SHIELD)
	game._apply_damage(Vector2.ZERO, 25, "blocked", true)
	_check(
		game._score == 100
		and not game._frog.knockback_active()
		and not game._power_state.is_active(
			TemporaryPowerState.BUBBLE_SHIELD
		),
		"Bubble Shield blocks one pursuit hit without score loss or knockback."
	)
	game._apply_damage(Vector2.ZERO, 25, "applied", true)
	_check(
		game._score == 75
		and game._frog.knockback_active(),
		"The next pursuit hit applies normally after the shield is consumed."
	)

	for entry in ProgressionCatalog.power_entries():
		var target_id := str(entry["target_id"])
		var mapped_power := ProgressionCatalog.power_for_target(target_id)
		_check(
			DiscoveryCatalog.entry_for(target_id).has("name")
			and str(mapped_power.get("id", "")) == str(entry["id"]),
			"Every Field Guide power source maps to one deterministic power: %s."
			% target_id
		)

	game._activate_power(TemporaryPowerState.FLIGHT)
	_check(
		game._frog.is_flying
		and game._status_label.text.contains("FLIGHT ACTIVE")
		and game._status_label.text.contains("No power button")
		and game._power_label.text.contains("Flight"),
		"Flight starts immediately and explains normal click/tap movement."
	)
	game._activate_power(TemporaryPowerState.BUBBLE_SHIELD)
	game._larger_text_controls_enabled = true
	game._apply_accessibility_presentation()
	game.apply_safe_area_insets(Vector4(44, 24, 44, 21))
	await process_frame
	var safe_right := game.get_viewport_rect().size.x - 44.0
	_check(
		game._power_state.active_ids().size() == 5
		and game._power_label.text.contains("Shield")
		and game._power_label.text.contains("(+4)")
		and game._power_label.tooltip_text.contains("Flight")
		and game._power_label.tooltip_text.contains("Camouflage")
		and game._end_button.get_global_rect().end.x <= safe_right + 0.5,
		"Five active powers stay readable without pushing actions outside the safe area."
	)

	game.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("Power smoke tests passed.")
		quit(0)
	else:
		push_error("Power smoke tests failed: %s" % ", ".join(_failures))
		quit(1)
