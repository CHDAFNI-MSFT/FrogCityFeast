class_name PrototypePursuer
extends CharacterBody2D

signal caught(source_position: Vector2)
signal escaped

var frog: PlayerFrog
var active := true
var speed := 250.0
var _catch_cooldown := 0.0
var _far_time := 0.0
var _chase_time := 0.0
var _no_progress_time := 0.0
var _last_position := Vector2.ZERO


func _ready() -> void:
	z_index = 5
	collision_layer = 1
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	collision.shape = shape
	add_child(collision)
	_last_position = global_position
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(frog):
		velocity = Vector2.ZERO
		return

	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)
	_chase_time += delta
	var offset := frog.global_position - global_position
	if offset.length() > 920.0:
		_far_time += delta
	else:
		_far_time = maxf(0.0, _far_time - delta * 1.5)
	if _far_time >= 4.0 or _chase_time >= 32.0:
		_escape()
		return

	if offset.length() > 4.0:
		velocity = offset.normalized() * speed
		rotation = velocity.angle() + PI / 2.0
		move_and_slide()

	if global_position.distance_to(_last_position) < 2.0:
		_no_progress_time += delta
	else:
		_no_progress_time = 0.0
	_last_position = global_position
	if _no_progress_time >= 2.5:
		_escape()
		return

	var catch_distance := 28.0 + frog.collision_radius() + 6.0
	if (
		frog.growth_tier < 2
		and _catch_cooldown <= 0.0
		and global_position.distance_to(frog.global_position) < catch_distance
	):
		_catch_cooldown = 2.0
		caught.emit(global_position)


func _escape() -> void:
	active = false
	escaped.emit()
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 31.0, Color("da7462"))
	draw_rect(Rect2(-20, -37, 40, 30), Color("416c9a"))
	draw_circle(Vector2(-11, -25), 4.0, Color.WHITE)
	draw_circle(Vector2(11, -25), 4.0, Color.WHITE)
	draw_circle(Vector2(-11, -25), 2.0, Color("1d2328"))
	draw_circle(Vector2(11, -25), 2.0, Color("1d2328"))
	draw_line(Vector2(-18, 30), Vector2(-25, 47), Color("263642"), 8.0)
	draw_line(Vector2(18, 30), Vector2(25, 47), Color("263642"), 8.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-55, -52),
		"Animal Control",
		HORIZONTAL_ALIGNMENT_CENTER,
		110,
		15,
		Color.WHITE
	)


func hit_test(world_point: Vector2) -> bool:
	return global_position.distance_to(world_point) <= 40.0


func hit_accuracy(world_point: Vector2) -> float:
	return clampf(1.0 - global_position.distance_to(world_point) / 40.0, 0.0, 1.0)
