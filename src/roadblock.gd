class_name PrototypeRoadblock
extends StaticBody2D

signal removed(roadblock: PrototypeRoadblock, broken: bool)

const REQUIRED_HITS := 3
const LIFETIME := 10.0

var barrier_size := Vector2(360, 52)
var _hits := 0
var _time_left := LIFETIME
var _removing := false


func _ready() -> void:
	z_index = 4
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = barrier_size
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
	var rect := Rect2(-barrier_size / 2.0, barrier_size)
	draw_rect(rect, Color("d88335"))
	draw_rect(rect.grow(-5.0), Color("352d29"), false, 4.0)
	var stripe_width := barrier_size.x / 8.0
	for index in 8:
		if index % 2 == 0:
			draw_rect(
				Rect2(
					Vector2(
						rect.position.x + float(index) * stripe_width,
						rect.position.y + 6.0
					),
					Vector2(stripe_width, barrier_size.y - 12.0)
				),
				Color("f4e5bb")
			)
	for hit_index in _hits:
		var x := -54.0 + float(hit_index) * 54.0
		draw_line(
			Vector2(x - 16, -15),
			Vector2(x + 4, 1),
			Color("5b2521"),
			5.0
		)
		draw_line(
			Vector2(x + 4, 1),
			Vector2(x - 8, 17),
			Color("5b2521"),
			5.0
		)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-95, -barrier_size.y * 0.78),
		"ANIMAL CONTROL",
		HORIZONTAL_ALIGNMENT_CENTER,
		190,
		18,
		Color("f8f1dd")
	)
