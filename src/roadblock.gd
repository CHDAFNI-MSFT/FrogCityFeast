class_name PrototypeRoadblock
extends StaticBody2D

signal removed(roadblock: PrototypeRoadblock, broken: bool)

const REQUIRED_HITS := 3
const LIFETIME := 10.0
const LAYOUT_STRAIGHT := "straight"
const LAYOUT_STAGGERED := "staggered"
const MAX_SEGMENTS := 2
const SAFE_EDGE_CLEARANCE := 68.0
const MIN_STAGGERED_OPENING := 104.0

var barrier_size := Vector2(360, 52)
var layout_id := LAYOUT_STRAIGHT
var _hits := 0
var _time_left := LIFETIME
var _removing := false


func configure_layout(value: String, size: Vector2) -> void:
	if value not in [LAYOUT_STRAIGHT, LAYOUT_STAGGERED]:
		push_error("Unknown roadblock layout: %s." % value)
		layout_id = LAYOUT_STRAIGHT
	else:
		layout_id = value
	barrier_size = size


func _ready() -> void:
	z_index = 4
	collision_layer = 1
	collision_mask = 1
	for rect in local_collision_rects():
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.position = rect.get_center()
		collision.shape = shape
		add_child(collision)
	queue_redraw()


func _process(delta: float) -> void:
	if _removing or delta <= 0.0:
		return
	_time_left = maxf(0.0, _time_left - delta)
	if _time_left <= 0.0:
		dismiss(false)


func register_tongue_hit() -> bool:
	if _removing:
		return false
	_hits += 1
	if _hits >= REQUIRED_HITS:
		dismiss(true)
		return true
	queue_redraw()
	return false


func remaining_hits() -> int:
	return maxi(0, REQUIRED_HITS - _hits)


func navigation_obstacle_rect() -> Rect2:
	var rects := navigation_obstacle_rects()
	if rects.is_empty():
		return Rect2(global_position, Vector2.ZERO)
	var bounds := rects[0]
	for index in range(1, rects.size()):
		bounds = bounds.merge(rects[index])
	return bounds


func navigation_obstacle_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for rect in local_collision_rects():
		result.append(Rect2(global_position + rect.position, rect.size))
	return result


func local_collision_rects() -> Array[Rect2]:
	return local_rects_for_layout(layout_id, barrier_size)


func collision_shape_count() -> int:
	return local_collision_rects().size()


func display_name() -> String:
	return (
		"staggered chicane"
		if layout_id == LAYOUT_STAGGERED
		else "straight barricade"
	)


static func local_rects_for_layout(
	value: String,
	size: Vector2
) -> Array[Rect2]:
	if value not in [LAYOUT_STRAIGHT, LAYOUT_STAGGERED]:
		push_error("Unknown roadblock layout: %s." % value)
		return [Rect2(-size / 2.0, size)]
	if value != LAYOUT_STAGGERED:
		return [Rect2(-size / 2.0, size)]
	var horizontal := size.x >= size.y
	var length := (
		size.x * 0.28 if horizontal else size.y * 0.28
	)
	var thickness := size.y if horizontal else size.x
	var along_offset := (
		size.x * 0.36 if horizontal else size.y * 0.36
	)
	var cross_offset := thickness * 0.85
	var segment_size := (
		Vector2(length, thickness)
		if horizontal
		else Vector2(thickness, length)
	)
	var first_center := (
		Vector2(-along_offset, -cross_offset)
		if horizontal
		else Vector2(-cross_offset, -along_offset)
	)
	var second_center := -first_center
	return [
		Rect2(first_center - segment_size / 2.0, segment_size),
		Rect2(second_center - segment_size / 2.0, segment_size),
	]


static func central_opening_width(value: String, size: Vector2) -> float:
	if value != LAYOUT_STAGGERED:
		return 0.0
	var rects := local_rects_for_layout(value, size)
	return (
		rects[1].position.x - rects[0].end.x
		if size.x >= size.y
		else rects[1].position.y - rects[0].end.y
	)


func dismiss(broken: bool) -> void:
	if _removing:
		return
	_removing = true
	collision_layer = 0
	collision_mask = 0
	set_process(false)
	removed.emit(self, broken)
	queue_free()


func _draw() -> void:
	var rects := local_collision_rects()
	for rect in rects:
		draw_rect(rect, Color("d88335"))
		if layout_id == LAYOUT_STRAIGHT:
			draw_rect(
				rect.grow(-5.0),
				Color("352d29"),
				false,
				4.0
			)
		var horizontal := rect.size.x >= rect.size.y
		var stripe_count := 4 if layout_id == LAYOUT_STAGGERED else 8
		var stripe_length := (
			rect.size.x / float(stripe_count)
			if horizontal
			else rect.size.y / float(stripe_count)
		)
		for index in stripe_count:
			if index % 2 != 0:
				continue
			var stripe_rect := (
				Rect2(
					Vector2(
						rect.position.x
							+ float(index) * stripe_length,
						rect.position.y + 6.0
					),
					Vector2(stripe_length, rect.size.y - 12.0)
				)
				if horizontal
				else Rect2(
					Vector2(
						rect.position.x + 6.0,
						rect.position.y
							+ float(index) * stripe_length
					),
					Vector2(rect.size.x - 12.0, stripe_length)
				)
			)
			draw_rect(stripe_rect, Color("f4e5bb"))
	for hit_index in _hits:
		var target_rect := rects[hit_index % rects.size()]
		var center := target_rect.get_center()
		var x := center.x - 30.0 + float(hit_index) * 30.0
		draw_line(
			Vector2(x - 16, center.y - 15),
			Vector2(x + 4, center.y + 1),
			Color("5b2521"),
			5.0
		)
		draw_line(
			Vector2(x + 4, center.y + 1),
			Vector2(x - 8, center.y + 17),
			Color("5b2521"),
			5.0
		)
	var bounds := navigation_obstacle_rect()
	var local_bounds := Rect2(
		bounds.position - global_position,
		bounds.size
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-110, local_bounds.position.y - 14.0),
		(
			"CONTROL CHICANE"
			if layout_id == LAYOUT_STAGGERED
			else "ANIMAL CONTROL"
		),
		HORIZONTAL_ALIGNMENT_CENTER,
		220,
		18,
		Color("f8f1dd")
	)
