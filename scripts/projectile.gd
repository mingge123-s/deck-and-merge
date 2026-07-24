class_name Projectile
extends Node2D

const MAX_LIFETIME := 2.0
const HIT_DISTANCE := 14.0

var target_getter: Callable
var hit_callback: Callable
var target_position := Vector2.ZERO
var target_lost := false
var elapsed := 0.0
var speed := 260.0
var era := "stone"
var projectile_color := Color.WHITE

func setup(
	start_pos: Vector2,
	get_target_pos: Callable,
	projectile_speed: float,
	projectile_era: String,
	color: Color,
	on_hit: Callable
) -> void:
	position = start_pos
	target_getter = get_target_pos
	hit_callback = on_hit
	speed = projectile_speed
	era = projectile_era
	projectile_color = color
	z_index = 6
	var initial_target = target_getter.call() if target_getter.is_valid() else null
	if initial_target is Vector2:
		target_position = initial_target
	else:
		target_position = start_pos
		target_lost = true
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if not target_lost and target_getter.is_valid():
		var current_target = target_getter.call()
		if current_target is Vector2:
			target_position = current_target
		else:
			target_lost = true
	var offset := target_position - position
	var distance := offset.length()
	if distance <= HIT_DISTANCE or elapsed >= MAX_LIFETIME:
		position = target_position
		_finish(not target_lost)
		return
	var direction := offset / distance
	position += direction * minf(speed * delta, distance)
	rotation = direction.angle()
	queue_redraw()

func _finish(apply_hit: bool) -> void:
	if not is_inside_tree():
		return
	if apply_hit and hit_callback.is_valid():
		hit_callback.call()
	queue_free()

func _draw() -> void:
	match era:
		"stone":
			draw_circle(Vector2.ZERO, 6.0, projectile_color.darkened(0.35))
			draw_circle(Vector2(-2, -2), 2.0, Color("#d0b083", 0.75))
		"iron":
			draw_line(Vector2(-11, 0), Vector2(7, 0), projectile_color, 2.0)
			draw_colored_polygon(
				PackedVector2Array([Vector2(12, 0), Vector2(5, -4), Vector2(5, 4)]),
				projectile_color
			)
		"industrial", "modern":
			draw_line(Vector2(-14, 0), Vector2(8, 0), projectile_color.lightened(0.25), 4.0)
			draw_line(Vector2(-10, 0), Vector2(12, 0), Color.WHITE, 1.5)
		"future":
			draw_circle(Vector2.ZERO, 8.0, Color(projectile_color, 0.22))
			draw_circle(Vector2.ZERO, 4.0, projectile_color.lightened(0.35))
			draw_line(Vector2(-13, 0), Vector2(5, 0), Color.WHITE, 2.5)
