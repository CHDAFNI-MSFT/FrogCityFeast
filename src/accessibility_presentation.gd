class_name AccessibilityPresentation
extends RefCounted

const NORMAL_TOUCH_HEIGHT := 56.0
const LARGE_TOUCH_HEIGHT := 64.0
const LARGE_FONT_SCALE := 1.14
const MIN_SAFE_CONTENT_SIZE := Vector2(640, 480)

const META_BASE_FONT_SIZE := "accessibility_base_font_size"
const META_BASE_MINIMUM_SIZE := "accessibility_base_minimum_size"


static func sanitize_preferences(value: Variant) -> Dictionary:
	var preferences := {
		"reduce_motion": false,
		"larger_text_controls": false,
	}
	if value is not Dictionary:
		return preferences
	var stored := value as Dictionary
	if stored.get("reduce_motion") is bool:
		preferences["reduce_motion"] = stored["reduce_motion"]
	if stored.get("larger_text_controls") is bool:
		preferences["larger_text_controls"] = stored["larger_text_controls"]
	return preferences


static func safe_area_insets(
	safe_rect: Rect2,
	window_rect: Rect2,
	viewport_size: Vector2
) -> Vector4:
	if (
		safe_rect.size.x <= 0.0
		or safe_rect.size.y <= 0.0
		or window_rect.size.x <= 0.0
		or window_rect.size.y <= 0.0
		or viewport_size.x <= 0.0
		or viewport_size.y <= 0.0
	):
		return Vector4.ZERO
	var intersection := safe_rect.intersection(window_rect)
	if intersection.size.x <= 0.0 or intersection.size.y <= 0.0:
		return Vector4.ZERO
	if (
		intersection.position.x <= window_rect.position.x
		and intersection.position.y <= window_rect.position.y
		and intersection.end.x >= window_rect.end.x
		and intersection.end.y >= window_rect.end.y
	):
		return Vector4.ZERO

	var local_position := intersection.position - window_rect.position
	var local_end := intersection.end - window_rect.position
	var scale := Vector2(
		viewport_size.x / window_rect.size.x,
		viewport_size.y / window_rect.size.y
	)
	var insets := Vector4(
		ceilf(maxf(0.0, local_position.x) * scale.x),
		ceilf(maxf(0.0, local_position.y) * scale.y),
		ceilf(maxf(0.0, window_rect.size.x - local_end.x) * scale.x),
		ceilf(maxf(0.0, window_rect.size.y - local_end.y) * scale.y)
	)
	if (
		viewport_size.x - insets.x - insets.z < MIN_SAFE_CONTENT_SIZE.x
		or viewport_size.y - insets.y - insets.w < MIN_SAFE_CONTENT_SIZE.y
	):
		return Vector4.ZERO
	return insets


static func current_safe_area_insets(viewport_size: Vector2) -> Vector4:
	if OS.get_name() != "iOS":
		return Vector4.ZERO
	var window_position_value := DisplayServer.window_get_position()
	var window_size_value := DisplayServer.window_get_size()
	var safe_area_value := DisplayServer.get_display_safe_area()
	var window_position := Vector2(
		window_position_value.x,
		window_position_value.y
	)
	var window_size := Vector2(window_size_value.x, window_size_value.y)
	return safe_area_insets(
		Rect2(
			Vector2(safe_area_value.position.x, safe_area_value.position.y),
			Vector2(safe_area_value.size.x, safe_area_value.size.y)
		),
		Rect2(window_position, window_size),
		viewport_size
	)


static func apply(root: Node, larger_text_controls: bool) -> void:
	var styles := _button_styles()
	_apply_node(root, larger_text_controls, styles)


static func _apply_node(
	node: Node,
	larger_text_controls: bool,
	styles: Dictionary
) -> void:
	if node is Control:
		_apply_control(node as Control, larger_text_controls, styles)
	for child in node.get_children():
		_apply_node(child, larger_text_controls, styles)


static func _apply_control(
	control: Control,
	larger_text_controls: bool,
	styles: Dictionary
) -> void:
	if not control.has_meta(META_BASE_MINIMUM_SIZE):
		control.set_meta(META_BASE_MINIMUM_SIZE, control.custom_minimum_size)

	if (
		control is Label
		or control is BaseButton
		or control is LineEdit
	):
		if not control.has_meta(META_BASE_FONT_SIZE):
			control.set_meta(
				META_BASE_FONT_SIZE,
				maxi(1, control.get_theme_font_size("font_size"))
			)
		var base_font_size := int(control.get_meta(META_BASE_FONT_SIZE))
		control.add_theme_font_size_override(
			"font_size",
			roundi(
				float(base_font_size)
				* (LARGE_FONT_SCALE if larger_text_controls else 1.0)
			)
		)

	if control is BaseButton or control is LineEdit:
		var base_minimum := control.get_meta(
			META_BASE_MINIMUM_SIZE
		) as Vector2
		control.custom_minimum_size = Vector2(
			base_minimum.x,
			maxf(
				base_minimum.y,
				LARGE_TOUCH_HEIGHT
				if larger_text_controls
				else NORMAL_TOUCH_HEIGHT
			)
		)

	if control is BaseButton:
		var button := control as BaseButton
		button.add_theme_stylebox_override("normal", styles["normal"])
		button.add_theme_stylebox_override("hover", styles["hover"])
		button.add_theme_stylebox_override("pressed", styles["pressed"])
		button.add_theme_stylebox_override("focus", styles["focus"])
		button.add_theme_stylebox_override("disabled", styles["disabled"])
		button.add_theme_color_override("font_color", Color("f5fff9"))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_color_override(
			"font_disabled_color",
			Color(0.72, 0.77, 0.76, 0.82)
		)

static func _button_styles() -> Dictionary:
	return {
		"normal": _make_button_style(Color("123d3f"), Color("3d9185"), 2),
		"hover": _make_button_style(Color("195451"), Color("63b8a1"), 2),
		"pressed": _make_button_style(Color("28784f"), Color("a5e46e"), 3),
		"focus": _make_button_style(Color("174846"), Color("ffe082"), 3),
		"disabled": _make_button_style(Color("273536"), Color("536061"), 2),
	}


static func _make_button_style(
	background: Color,
	border: Color,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 14.0
	style.content_margin_top = 8.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 8.0
	return style
