extends SceneTree

const STATES := preload("res://tools/app_store_screenshot_states.gd")
const OUTPUT_SIZE := Vector2i(2752, 2064)
const LOGICAL_SIZE := Vector2i(1280, 960)
const IMAGE_DIRECTORY := "ipad-13-inch"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_root := _output_root()
	var image_directory := output_root.path_join(IMAGE_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		image_directory
	)
	if directory_error != OK:
		_fail(
			"Could not create screenshot output directory '%s' (error %d)."
			% [image_directory, directory_error]
		)
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	root.content_scale_size = LOGICAL_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = OUTPUT_SIZE
	DisplayServer.window_set_size(OUTPUT_SIZE)
	await process_frame
	await process_frame

	for spec in STATES.screenshot_specs():
		paused = false
		var state_id := str(spec["id"])
		var game := STATES.instantiate_game(state_id)
		if not is_instance_valid(game):
			_fail("Could not instantiate screenshot state '%s'." % state_id)
			return
		root.add_child(game)
		if not STATES.author_state(game, state_id):
			_fail("Could not author screenshot state '%s'." % state_id)
			return
		game.set_process(false)
		game.set_physics_process(false)
		paused = false
		await process_frame
		paused = true
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw

		var image := root.get_texture().get_image()
		if image.get_size() != OUTPUT_SIZE:
			_fail(
				"State '%s' rendered at %s instead of %s."
				% [state_id, image.get_size(), OUTPUT_SIZE]
			)
			return
		image.convert(Image.FORMAT_RGB8)
		var output_path := image_directory.path_join(str(spec["filename"]))
		var save_error := image.save_png(output_path)
		if save_error != OK:
			_fail(
				"Could not save '%s' (error %d)."
				% [output_path, save_error]
			)
			return
		print(
			"CAPTURED %s %dx%d RGB"
			% [output_path, image.get_width(), image.get_height()]
		)

		paused = false
		game._belly.clear()
		game.queue_free()
		await process_frame
		AudioDirector.reset_for_tests()
		await process_frame

	print(
		"Generated %d App Store screenshots in %s."
		% [STATES.screenshot_specs().size(), image_directory]
	)
	quit(0)


func _output_root() -> String:
	var user_arguments := OS.get_cmdline_user_args()
	for index in user_arguments.size():
		if (
			user_arguments[index] == "--output"
			and index + 1 < user_arguments.size()
		):
			return ProjectSettings.globalize_path(user_arguments[index + 1])
	return ProjectSettings.globalize_path(
		"res://build/app-store/screenshots"
	)


func _fail(message: String) -> void:
	push_error(message)
	paused = false
	quit(1)
