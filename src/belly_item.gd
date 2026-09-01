class_name BellyItem
extends RefCounted

const TUNING := preload("res://src/gameplay_tuning.gd")

var target_id := ""
var display_name := ""
var kind := "object"
var base_value := 10
var size_tier := 0
var rare := false
var resistant := false
var taps_required := 0
var pick_radius := 28.0
var accuracy := 0.5
var dangerous_location := false
var captured_while_chased := false
var target_color := Color.WHITE
var movement_velocity := Vector2.ZERO
var movement_bounds := Rect2()
var unpredictable := false
var intrinsic_dangerous_location := false
var restockable := true
var building_id := ""
var building_part_id := ""
var selectable := true
var world_instance_id := ""
var district_coordinate := Vector2i.ZERO
var motion_seed := 0


func score_value() -> int:
	return TUNING.score_value(
		base_value,
		size_tier,
		accuracy,
		rare,
		dangerous_location,
		captured_while_chased
	)
