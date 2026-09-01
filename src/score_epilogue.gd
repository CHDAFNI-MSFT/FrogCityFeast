class_name ScoreEpilogue
extends Control

signal continue_requested

const ART := preload("res://src/production_art.gd")

@onready var _title: Label = %Title
@onready var _story: Label = %Story
@onready var _score_label: Label = %Score
@onready var _growth_label: Label = %Growth
@onready var _discoveries_label: Label = %Discoveries
@onready var _challenges_label: Label = %Challenges
@onready var _continue_button: Button = %ContinueButton
@onready var _center: CenterContainer = $Center

var _motion_scale := 1.0
var _animation_time := 0.0
var _story_text := ""
var _save_warning := ""


func _ready() -> void:
	_continue_button.pressed.connect(continue_requested.emit)
	set_process(true)
	queue_redraw()


func configure(
	display_name: String,
	score: int,
	growth_tier: int,
	discovery_count: int,
	challenge_count: int,
	larger_text_controls: bool,
	reduce_motion: bool
) -> void:
	_title.text = _epilogue_title(score, growth_tier)
	_story_text = (
		"At dusk, %s left a trail of crumbs, surprised city workers, "
		+ "and one very memorable frog-shaped ripple."
	) % display_name
	_update_story()
	_score_label.text = "Final score  %d" % score
	_growth_label.text = "Growth reached  %s" % _growth_name(growth_tier)
	_discoveries_label.text = "Field Guide finds  %d" % discovery_count
	_challenges_label.text = "Session goals  %d / 3" % challenge_count
	_motion_scale = 0.0 if reduce_motion else 1.0
	set_process(_motion_scale > 0.0)
	AccessibilityPresentation.apply(self, larger_text_controls)
	queue_redraw()


func set_save_warning(message: String) -> void:
	_save_warning = message
	_update_story()


func _update_story() -> void:
	_story.text = (
		_story_text
		if _save_warning.is_empty()
		else "SAVE WARNING: %s\n\n%s" % [_save_warning, _story_text]
	)


func apply_safe_area_insets(insets: Vector4) -> void:
	_center.offset_left = maxf(0.0, insets.x)
	_center.offset_top = maxf(0.0, insets.y)
	_center.offset_right = -maxf(0.0, insets.z)
	_center.offset_bottom = -maxf(0.0, insets.w)


func _process(delta: float) -> void:
	if _motion_scale <= 0.0:
		return
	_animation_time = fmod(_animation_time + delta, TAU * 6.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(ART.NIGHT_NAVY, 0.98))
	var horizon := size.y * 0.58
	draw_rect(
		Rect2(0, horizon, size.x, size.y - horizon),
		ART.CANAL_TEAL.darkened(0.36)
	)
	for index in 9:
		var building_width := 70.0 + float(index % 3) * 18.0
		var building_height := 100.0 + float((index * 3) % 5) * 26.0
		var position := Vector2(
			30.0 + float(index) * size.x / 8.5,
			horizon - building_height
		)
		draw_rect(
			Rect2(position, Vector2(building_width, building_height)),
			(
				ART.CITY_CORAL.darkened(0.45)
				if index % 2 == 0
				else ART.CITY_GOLD.darkened(0.52)
			)
		)
	var drift := sin(_animation_time) * 4.0 * _motion_scale
	draw_texture_rect(
		ART.FROG_TEXTURE,
		Rect2(
			Vector2(size.x * 0.1 - 72, horizon - 100 + drift),
			Vector2(144, 144)
		),
		false,
		Color(1.0, 1.0, 1.0, 0.72)
	)
	for index in 7:
		var y := horizon + 30.0 + float(index) * 34.0
		draw_line(
			Vector2(0, y),
			Vector2(size.x, y + drift * 0.15),
			Color(ART.CREAM, 0.08),
			3.0
		)


func _epilogue_title(score: int, growth_tier: int) -> String:
	if growth_tier >= GameplayTuning.ENORMOUS_TIER:
		return "A Giant Evening in Frog City"
	if score >= 2500:
		return "The City's Grandest Snack Story"
	if score >= 1000:
		return "A Very Satisfying City Feast"
	return "A Small Frog's Big Afternoon"


func _growth_name(growth_tier: int) -> String:
	return str(
		["Small", "Growing", "Large", "Enormous"][
			clampi(growth_tier, 0, 3)
		]
	)
