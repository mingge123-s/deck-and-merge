class_name TowerHealthBar
extends Node2D

var health_ratio := 1.0
var bar_color := Color("#7fd65e")

func set_health(current: float, maximum: float) -> void:
	health_ratio = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var bar_width := 78.0
	draw_rect(Rect2(-bar_width * 0.5, 0, bar_width, 8), Color("#43251d", 0.9), true)
	draw_rect(
		Rect2(-bar_width * 0.5 + 2, 2, (bar_width - 4) * health_ratio, 4),
		bar_color,
		true
	)
	draw_line(
		Vector2(-bar_width * 0.5, 9),
		Vector2(bar_width * 0.5, 9),
		Color("#f7dfac", 0.7),
		1.0
	)
