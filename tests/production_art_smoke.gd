extends SceneTree

const ART_PATHS := [
	"res://assets/art/characters/frog.svg",
	"res://assets/art/characters/frog_wing.svg",
	"res://assets/art/targets/food.svg",
	"res://assets/art/targets/living.svg",
	"res://assets/art/targets/object.svg",
	"res://assets/art/targets/vehicle.svg",
	"res://assets/art/targets/building_part.svg",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_original_svg_assets()
	_test_art_runtime_contract()
	_test_palette_contrast()
	await process_frame
	if _failures.is_empty():
		print("Production art smoke tests passed.")
		quit(0)
	else:
		print(
			"Production art smoke tests failed: %s"
			% ", ".join(_failures)
		)
		quit(1)


func _test_original_svg_assets() -> void:
	var manifest := FileAccess.get_file_as_string(
		"res://assets/art/README.md"
	)
	var all_assets_valid := true
	for path_value in ART_PATHS:
		var path := str(path_value)
		var source := FileAccess.get_file_as_string(path)
		var texture := load(path)
		var import_text := FileAccess.get_file_as_string(path + ".import")
		var filename: String = path.get_file()
		if (
			source.is_empty()
			or not source.contains("<svg")
			or source.contains("<image")
			or source.contains("href=")
			or source.contains("<script")
			or texture is not Texture2D
			or (texture as Texture2D).get_size().x < 64.0
			or not import_text.contains('importer="texture"')
			or not import_text.contains("svg/scale=")
			or not manifest.contains(filename)
		):
			all_assets_valid = false
	_check(
		all_assets_valid,
		"All production SVGs are local, linked-resource-free, documented, and importable."
	)


func _test_art_runtime_contract() -> void:
	var kinds := [
		"food",
		"living",
		"object",
		"vehicle",
		"building_part",
		"building",
	]
	var textures_are_valid := true
	for kind in kinds:
		if (
			ProductionArt.target_texture(kind) is not Texture2D
			or ProductionArt.target_visual_size(kind, 28.0).x <= 0.0
			or ProductionArt.target_visual_size(kind, 28.0).y <= 0.0
		):
			textures_are_valid = false
	var frog := (
		load("res://scenes/frog.tscn") as PackedScene
	).instantiate() as PlayerFrog
	root.add_child(frog)
	await process_frame
	frog.celebrate_swallow()
	frog.set_presentation_motion_scale(0.0)
	_check(
		textures_are_valid
			and frog._swallow_celebration_time > 0.0
			and is_zero_approx(frog._presentation_motion_scale()),
		"Production art maps every gameplay category and respects reduced motion."
	)
	frog.queue_free()


func _test_palette_contrast() -> void:
	_check(
		_contrast_ratio(ProductionArt.CREAM, ProductionArt.INK) >= 7.0
			and _contrast_ratio(
				ProductionArt.FOCUS_MINT,
				ProductionArt.NIGHT_NAVY
			) >= 4.5
			and _contrast_ratio(
				ProductionArt.MAGIC_AMBER,
				ProductionArt.NIGHT_NAVY
			) >= 4.5,
		"The production status palette meets high-contrast text and focus targets."
	)


func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	var lighter := maxf(first_luminance, second_luminance)
	var darker := minf(first_luminance, second_luminance)
	return (lighter + 0.05) / (darker + 0.05)


func _relative_luminance(color: Color) -> float:
	return (
		0.2126 * _linear_channel(color.r)
		+ 0.7152 * _linear_channel(color.g)
		+ 0.0722 * _linear_channel(color.b)
	)


func _linear_channel(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	_failures.append(description)
	push_error("FAIL: %s" % description)
