class_name BattleMinimap
extends Control

var world_width := 1680.0
var ground_ratio := 0.72
var dots: Array = []
var towers: Array = []
var view_x := 0.0
var view_w := 648.0
var background: Panel

func configure(new_world_width: float, new_view_w: float) -> void:
	world_width = new_world_width
	view_w = new_view_w
	if background == null:
		background = Panel.new()
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.show_behind_parent = true
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#211509", 0.92)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color("#f2ca72", 0.9)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 4
		background.add_theme_stylebox_override("panel", style)
		add_child(background)
		move_child(background, 0)
	queue_redraw()

func update_map(new_dots: Array, new_towers: Array, new_view_x: float) -> void:
	dots = new_dots
	towers = new_towers
	view_x = new_view_x
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var gy := h * ground_ratio
	draw_line(Vector2(4, gy), Vector2(w - 4, gy), Color(1, 1, 1, 0.1), 1.0)
	for tower in towers:
		var tx: float = clampf(float(tower.x) / world_width, 0.0, 1.0) * w
		var tower_color: Color = tower.color
		draw_rect(Rect2(tx - 3.5, gy - 11.0, 7.0, 12.0), tower_color.darkened(0.25), true)
		draw_rect(Rect2(tx - 2.5, gy - 12.0, 5.0, 3.0), tower_color.lightened(0.25), true)
	for dot in dots:
		var dx: float = clampf(float(dot.x) / world_width, 0.0, 1.0) * w
		draw_circle(Vector2(dx, gy - 3.0), 3.4, Color(0.02, 0.01, 0.01, 0.5))
		draw_circle(Vector2(dx, gy - 3.0), 2.6, dot.color)
	var vx: float = clampf(view_x / world_width, 0.0, 1.0) * w
	var vw: float = clampf(view_w / world_width, 0.0, 1.0) * w
	draw_rect(Rect2(vx, 2.0, vw, h - 4.0), Color(1, 1, 1, 0.1), true)
	draw_rect(Rect2(vx, 2.0, vw, h - 4.0), Color(1, 1, 1, 0.5), false, 1.0)
