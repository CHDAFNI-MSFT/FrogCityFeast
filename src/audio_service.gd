class_name AudioDirector
extends RefCounted


static func director() -> FrogAudioDirector:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("AudioDirector requires an active SceneTree.")
		return null
	var existing := _existing_director(tree)
	if existing != null:
		return existing
	var created := FrogAudioDirector.new()
	created.name = "AudioServiceTest"
	tree.root.add_child(created)
	return created


static func enter_menu(context: Node, preferences: Dictionary) -> void:
	director().enter_menu(context, preferences)


static func enter_game(
	context: Node,
	preferences: Dictionary,
	is_night: bool
) -> void:
	director().enter_game(context, preferences, is_night)


static func set_game_ambience(context: Node, is_night: bool) -> void:
	director().set_game_ambience(context, is_night)


static func set_pursuit(context: Node, active: bool) -> void:
	director().set_pursuit(context, active)


static func enter_epilogue(context: Node) -> void:
	director().enter_epilogue(context)


static func leave_context(context: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var existing := _existing_director(tree)
	if existing != null:
		existing.leave_context(context)


static func apply_preferences(value: Variant) -> void:
	director().apply_preferences(value)


static func play_effect(
	event_id: StringName,
	now_msec: int = -1
) -> bool:
	return director().play_effect(event_id, now_msec)


static func effect_play_count(event_id: StringName) -> int:
	return director().effect_play_count(event_id)


static func structure_snapshot() -> Dictionary:
	return director().structure_snapshot()


static func reset_for_tests() -> void:
	director().reset_for_tests()


static func shutdown_for_tests() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var test_director := tree.root.get_node_or_null("AudioServiceTest")
	if test_director is FrogAudioDirector:
		test_director.free()


static func _existing_director(tree: SceneTree) -> FrogAudioDirector:
	var existing := tree.root.get_node_or_null("AudioService")
	if existing is FrogAudioDirector:
		return existing as FrogAudioDirector
	var test_existing := tree.root.get_node_or_null("AudioServiceTest")
	if test_existing is FrogAudioDirector:
		return test_existing as FrogAudioDirector
	return null
