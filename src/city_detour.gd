class_name PrototypeCityDetour
extends StaticBody2D

const DEFAULT_SIZE := Vector2(220, 48)

var barrier_size := DEFAULT_SIZE


func configure(size: Vector2) -> void:
	barrier_size = Vector2(
		maxf(1.0, size.x),
		maxf(1.0, size.y)
	)


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


func navigation_obstacle_rect() -> Rect2:
	return Rect2(global_position - barrier_size / 2.0, barrier_size)


func dismiss() -> void:
	collision_layer = 0
	collision_mask = 0
	queue_free()


func _draw() -> void:
	var barrier := Rect2(-barrier_size / 2.0, barrier_size)
	draw_rect(barrier, Color("d9a441"))
	draw_rect(barrier.grow(-5.0), Color("3d4548"), false, 4.0)
	var stripe_width := barrier_size.x / 6.0
	for index in 6:
		if index % 2 == 0:
			draw_rect(
				Rect2(
					barrier.position
					+ Vector2(float(index) * stripe_width, 6.0),
					Vector2(stripe_width, barrier_size.y - 12.0)
				),
				Color("f2e3b4")
			)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-130, -barrier_size.y / 2.0 - 16.0),
		"WATER REPAIR - DETOUR",
		HORIZONTAL_ALIGNMENT_CENTER,
		260,
		17,
		Color("f7f2dc")
	)
