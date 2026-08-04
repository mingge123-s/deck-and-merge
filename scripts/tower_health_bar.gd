class_name TowerHealthBar
extends Node2D

var health_ratio := 1.0
var bar_color := Color("#7fd65e")
var show_phases := false
var total_phases := 1
var current_phase := 0
var phase_label := ""

func set_health(current: float, maximum: float) -> void:
	health_ratio = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	queue_redraw()

func set_phase(phase: int, phases: int, label: String) -> void:
	current_phase = phase
	total_phases = maxi(1, phases)
	phase_label = label
	queue_redraw()

func _draw() -> void:
	var bar_width := 78.0
	if show_phases:
		var pip_gap := 2.0
		var pip_width := (bar_width - pip_gap * float(total_phases - 1)) / float(total_phases)
		for index in range(total_phases):
			var pip_color := Color("#6d5142", 0.55)
			if index < current_phase:
				pip_color = Color("#ffd273")
			elif index == current_phase:
				pip_color = Color("#fff0a8")
			var pip_rect := Rect2(
				-bar_width * 0.5 + float(index) * (pip_width + pip_gap),
				-15,
				pip_width,
				4
			)
			draw_rect(pip_rect, Color("#2b160f", 0.9), true)
			draw_rect(pip_rect.grow(-1.0), pip_color, true)
		var font := ThemeDB.fallback_font
		var label_position := Vector2(-bar_width * 0.5, -29)
		draw_string(
			font,
			label_position + Vector2(1, 1),
			phase_label,
			HORIZONTAL_ALIGNMENT_CENTER,
			bar_width,
			10,
			Color("#24150f", 0.95)
		)
		draw_string(
			font,
			label_position,
			phase_label,
			HORIZONTAL_ALIGNMENT_CENTER,
			bar_width,
			10,
			Color("#ffe8ae")
		)
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
