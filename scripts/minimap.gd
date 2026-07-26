class_name BattleMinimap
extends Control

var world_width := 1680.0
var ground_ratio := 0.72
var dots: Array = []
var towers: Array = []
var view_x := 0.0
var view_w := 648.0

func configure(new_world_width: float, new_view_w: float) -> void:
	world_width = new_world_width
	view_w = new_view_w
	queue_redraw()

func update_map(new_dots: Array, new_towers: Array, new_view_x: float) -> void:
	dots = new_dots
	towers = new_towers
	view_x = new_view_x
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.09, 0.06, 0.78), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.79, 0.45, 0.9), false, 1.5)
	var gy := h * ground_ratio
	draw_line(Vector2(4, gy), Vector2(w - 4, gy), Color(1, 1, 1, 0.12), 1.0)
	for tower in towers:
		var tx: float = clampf(float(tower.x) / world_width, 0.0, 1.0) * w
		draw_rect(Rect2(tx - 3.0, gy - 11.0, 6.0, 12.0), tower.color, true)
	for dot in dots:
		var dx: float = clampf(float(dot.x) / world_width, 0.0, 1.0) * w
		draw_circle(Vector2(dx, gy - 3.0), 2.6, dot.color)
	var vx: float = clampf(view_x / world_width, 0.0, 1.0) * w
	var vw: float = clampf(view_w / world_width, 0.0, 1.0) * w
	draw_rect(Rect2(vx, 2.0, vw, h - 4.0), Color(1, 1, 1, 0.9), false, 1.5)
