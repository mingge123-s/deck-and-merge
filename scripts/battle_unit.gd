class_name BattleUnit
extends Node2D

signal expired(unit: BattleUnit)
signal death_started(unit: BattleUnit)
signal poison_tick(unit: BattleUnit, dps_amount: float, source: String)

static var _meta_cache: Dictionary = {}
static var _frames_cache: Dictionary = {}
static var _outline_material: ShaderMaterial

var unit_id := ""
var faction := ""
var stats: Dictionary = {}
var max_hp := 1.0
var hp := 1.0
var body_height := 104.0
var attack_cooldown := 0.0
var alive := true
var flash_time := 0.0

var visual: CanvasItem          # sprite OR anim, used for flash/modulate
var sprite: Sprite2D            # static fallback
var anim: AnimatedSprite2D      # frame animation
var animated := false
var _attacking := false
var _moving := false
var score_awarded := false
var visual_base_scale := Vector2.ONE
var hit_punch_tween: Tween
var spin_tween: Tween
var last_damage_source := "hero"
var energy := 0.0
var skill_cost := 0
var skill_once := false
var skill_used := false
var stun_time := 0.0
var shield_time := 0.0
var shield_reduce := 0.0
var reflect_time := 0.0
var reflect_frac := 0.0
var reflect_shield_reduce := 0.0
var berserk_time := 0.0
var berserk_atk := 1.0
var berserk_aspd := 1.0
var poison_time := 0.0
var poison_dps := 0.0
var poison_source := "hero"
var taunted_by: BattleUnit
var taunt_time := 0.0
var _buff_aura_root: Node2D
var _buff_ring: Line2D
var _buff_dots_root: Node2D
var _buff_aura_ids: Array[String] = []
var _buff_aura_colors: Array[Color] = []
var _buff_aura_tween: Tween
var _buff_aura_phase := 0.0

func setup(id: String, side: String, data: Dictionary, texture: Texture2D) -> void:
	unit_id = id
	faction = side
	stats = data
	var skill_data: Dictionary = data.get("skill", {})
	skill_cost = int(skill_data.get("cost", 0))
	skill_once = bool(skill_data.get("once", false))
	energy = 0.0
	skill_used = false
	max_hp = float(data.hp)
	hp = max_hp
	var role_scale := float(data.get("scale", 1.0))
	var desired_height := (118.0 if side == "ally" else 104.0) * role_scale
	body_height = desired_height
	if _setup_animated(str(data.get("anim", id)), side, desired_height):
		animated = true
	else:
		_setup_static(side, desired_height, texture)
	queue_redraw()

func set_buff_aura(ids: Array[String], colors: Array[Color]) -> void:
	if ids == _buff_aura_ids and colors == _buff_aura_colors:
		return
	_buff_aura_ids = ids.duplicate()
	_buff_aura_colors = colors.duplicate()
	if _buff_aura_ids.is_empty():
		_fade_buff_aura()
		return
	_ensure_buff_aura()
	if _buff_aura_tween != null:
		_buff_aura_tween.kill()
	_buff_aura_tween = null
	_buff_aura_root.visible = true
	_buff_aura_root.modulate.a = 1.0
	_buff_ring.default_color = _buff_aura_colors[0]
	_rebuild_buff_dots()

func clear_buff_aura(immediate := false) -> void:
	_buff_aura_ids.clear()
	_buff_aura_colors.clear()
	if immediate:
		if _buff_aura_tween != null:
			_buff_aura_tween.kill()
			_buff_aura_tween = null
		if _buff_aura_root != null:
			_buff_aura_root.visible = false
			_buff_aura_root.modulate.a = 0.0
	else:
		_fade_buff_aura()

func _ensure_buff_aura() -> void:
	if _buff_aura_root != null:
		return
	_buff_aura_root = Node2D.new()
	_buff_aura_root.name = "BuffAura"
	_buff_aura_root.z_index = -2
	add_child(_buff_aura_root)
	_buff_ring = Line2D.new()
	_buff_ring.name = "GroundRing"
	_buff_ring.closed = true
	_buff_ring.width = 4.0
	_buff_ring.antialiased = true
	_buff_ring.points = _aura_ring_points()
	_buff_aura_root.add_child(_buff_ring)
	_buff_dots_root = Node2D.new()
	_buff_dots_root.name = "BuffDots"
	_buff_dots_root.position = Vector2(0, -106)
	_buff_dots_root.z_index = -1
	_buff_aura_root.add_child(_buff_dots_root)

func _aura_ring_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(Vector2(cos(angle) * 36.0, sin(angle) * 14.0))
	return points

func _ellipse_points(radius_x: float, radius_y: float, center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points

func _get_outline_material() -> ShaderMaterial:
	if _outline_material == null:
		var shader := load("res://assets/fx/unit_outline.gdshader") as Shader
		if shader == null:
			return null
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = shader
	return _outline_material

func _rebuild_buff_dots() -> void:
	for child in _buff_dots_root.get_children():
		child.queue_free()
	var count := _buff_aura_colors.size()
	for index in range(count):
		var dot := Polygon2D.new()
		var points := PackedVector2Array()
		for point_index in range(9):
			var angle := TAU * float(point_index) / 8.0
			points.append(Vector2(cos(angle) * 4.5, sin(angle) * 4.5))
		dot.polygon = points
		dot.color = _buff_aura_colors[index]
		dot.position = Vector2((float(index) - float(count - 1) * 0.5) * 11.0, 0)
		_buff_dots_root.add_child(dot)

func _fade_buff_aura() -> void:
	if _buff_aura_root == null or not _buff_aura_root.visible:
		return
	if _buff_aura_tween != null:
		_buff_aura_tween.kill()
	_buff_aura_tween = create_tween()
	_buff_aura_tween.tween_property(_buff_aura_root, "modulate:a", 0.0, 0.3)
	_buff_aura_tween.tween_callback(func() -> void:
		if _buff_aura_root != null:
			_buff_aura_root.visible = false
	)

func _setup_animated(id: String, side: String, desired_height: float) -> bool:
	var dir := "res://assets/anim/%s" % id
	var meta_path := "%s/meta.json" % dir
	if not ResourceLoader.exists("%s/idle.png" % dir) or not FileAccess.file_exists(meta_path):
		return false
	var meta: Dictionary
	if _meta_cache.has(id):
		meta = _meta_cache[id]
	else:
		var parsed_meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if not parsed_meta is Dictionary:
			return false
		meta = parsed_meta
		_meta_cache[id] = meta
	var frames: SpriteFrames
	if _frames_cache.has(id):
		frames = _frames_cache[id]
	else:
		frames = SpriteFrames.new()
		frames.remove_animation("default")
		_add_anim(frames, dir, "idle", ["idle"], 4.0, true)
		_add_anim(frames, dir, "walk", ["walk_a", "walk_b"], 7.0, true)
		_add_anim(frames, dir, "attack", ["atk_a", "atk_b"], 11.0, false)
		_add_anim(frames, dir, "die", ["die"], 1.0, false)
		_frames_cache[id] = frames
	anim = AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.centered = false
	var anchor: Array = meta.get("anchor", [0, 0])
	anim.offset = Vector2(-float(anchor[0]), -float(anchor[1]))
	var char_height := float(meta.get("char_height", desired_height))
	var factor := desired_height / maxf(1.0, char_height)
	anim.scale = Vector2(-factor if side == "enemy" else factor, factor)
	anim.animation_finished.connect(_on_anim_finished)
	add_child(anim)
	visual = anim
	visual.material = _get_outline_material()
	visual_base_scale = anim.scale
	anim.play("idle")
	return true

func _add_anim(frames: SpriteFrames, dir: String, name: String, files: Array, fps: float, loop: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, loop)
	for file in files:
		var tex: Texture2D = load("%s/%s.png" % [dir, file])
		if tex != null:
			frames.add_frame(name, tex)

func _setup_static(side: String, desired_height: float, texture: Texture2D) -> void:
	if texture == null:
		var placeholder := Polygon2D.new()
		placeholder.polygon = PackedVector2Array([
			Vector2(-30, -desired_height),
			Vector2(30, -desired_height),
			Vector2(30, 0),
			Vector2(-30, 0),
		])
		placeholder.color = stats.get("color_value", Color("#777777"))
		placeholder.scale.x = -1.0 if side == "enemy" else 1.0
		add_child(placeholder)
		var label := Label.new()
		label.position = Vector2(-58, -desired_height - 24)
		label.size = Vector2(116, 24)
		label.text = str(stats.get("name", unit_id))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color("#fff0c7"))
		add_child(label)
		visual = placeholder
		visual_base_scale = placeholder.scale
		sprite = null
		return
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.flip_h = side == "enemy"
	var factor: float = desired_height / maxf(1.0, float(texture.get_height()))
	sprite.scale = Vector2(factor, factor)
	sprite.position.y = -desired_height * 0.5
	add_child(sprite)
	visual = sprite
	visual.material = _get_outline_material()
	visual_base_scale = sprite.scale

func set_moving(moving: bool) -> void:
	if not animated or not alive or _attacking:
		return
	if moving == _moving:
		return
	_moving = moving
	anim.play("walk" if moving else "idle")

func play_attack() -> void:
	if not animated or not alive:
		return
	_attacking = true
	anim.play("attack")

func _on_anim_finished() -> void:
	if not alive:
		return
	if anim.animation == "attack":
		_attacking = false
		anim.play("walk" if _moving else "idle")

func _process(delta: float) -> void:
	if _buff_aura_root != null and _buff_aura_root.visible:
		_buff_aura_phase = fmod(_buff_aura_phase + delta * 2.4, TAU)
		var pulse := 0.72 + sin(_buff_aura_phase) * 0.16
		_buff_ring.modulate.a = pulse
		_buff_dots_root.modulate.a = 0.78 + sin(_buff_aura_phase + 0.4) * 0.12
	if flash_time > 0.0 and is_instance_valid(visual):
		flash_time -= delta
		visual.modulate = Color(1.0, 0.7, 0.5) if flash_time > 0.0 else Color.WHITE
	stun_time = maxf(0.0, stun_time - delta)
	shield_time = maxf(0.0, shield_time - delta)
	reflect_time = maxf(0.0, reflect_time - delta)
	berserk_time = maxf(0.0, berserk_time - delta)
	taunt_time = maxf(0.0, taunt_time - delta)
	poison_time = maxf(0.0, poison_time - delta)
	if poison_time > 0.0 and alive and poison_dps > 0.0:
		_poison_tick_accumulator += delta
		while _poison_tick_accumulator >= 1.0:
			_poison_tick_accumulator -= 1.0
			poison_tick.emit(self, poison_dps, poison_source)
	else:
		_poison_tick_accumulator = 0.0
	queue_redraw()

var _poison_tick_accumulator := 0.0

func gain_energy(amount := 1.0) -> void:
	if skill_cost <= 0 or skill_used:
		return
	energy = minf(float(skill_cost), energy + amount)
	queue_redraw()

func skill_ready() -> bool:
	return skill_cost > 0 and energy >= float(skill_cost) and (not skill_once or not skill_used)

func add_stun(duration: float) -> void:
	stun_time = maxf(stun_time, duration)
	set_moving(false)
	queue_redraw()

func add_shield(duration: float, reduce: float) -> void:
	shield_time = maxf(shield_time, duration)
	shield_reduce = maxf(shield_reduce, reduce)
	queue_redraw()

func add_reflect(duration: float, reduction: float, reflect: float) -> void:
	reflect_time = maxf(reflect_time, duration)
	reflect_shield_reduce = maxf(reflect_shield_reduce, reduction)
	reflect_frac = maxf(reflect_frac, reflect)
	queue_redraw()

func add_berserk(duration: float, attack_multiplier: float, attack_speed_multiplier: float) -> void:
	berserk_time = maxf(berserk_time, duration)
	berserk_atk = maxf(berserk_atk, attack_multiplier)
	berserk_aspd = maxf(berserk_aspd, attack_speed_multiplier)
	queue_redraw()

func add_poison(duration: float, dps: float, source: String) -> void:
	poison_time = duration
	poison_dps = dps
	poison_source = source
	queue_redraw()

func add_taunt(source: BattleUnit, duration: float) -> void:
	taunted_by = source
	taunt_time = maxf(taunt_time, duration)
	queue_redraw()

func receive_damage(amount: float, source := "hero") -> void:
	if not alive:
		return
	last_damage_source = str(source)
	hp = max(0.0, hp - amount)
	flash_time = 0.12
	_play_hit_punch()
	queue_redraw()
	if hp <= 0.0:
		_die()

func _play_hit_punch() -> void:
	if not is_instance_valid(visual):
		return
	if spin_tween != null and spin_tween.is_valid():
		return
	if hit_punch_tween != null:
		hit_punch_tween.kill()
	visual.scale = visual_base_scale
	hit_punch_tween = create_tween()
	hit_punch_tween.tween_property(visual, "scale", visual_base_scale * 1.06, 0.045)
	hit_punch_tween.tween_property(visual, "scale", visual_base_scale, 0.055)

func play_spin(duration := 0.5, turns := 2) -> void:
	if not is_instance_valid(visual):
		return
	if spin_tween != null:
		spin_tween.kill()
	if hit_punch_tween != null:
		hit_punch_tween.kill()
	visual.scale = visual_base_scale
	visual.position.y = 0.0
	spin_tween = create_tween()
	var quarters := maxi(1, turns) * 4
	var step := duration / float(quarters)
	var seq := [0.0, -visual_base_scale.x, 0.0, visual_base_scale.x]
	for index in range(quarters):
		spin_tween.tween_property(visual, "scale:x", seq[index % 4], step)
	spin_tween.tween_callback(func() -> void:
		visual.scale = visual_base_scale
		visual.position.y = 0.0
		spin_tween = null
	)
	var hop := create_tween()
	hop.tween_property(visual, "position:y", -10.0, duration * 0.5)
	hop.tween_property(visual, "position:y", 0.0, duration * 0.5)

func _die() -> void:
	alive = false
	clear_buff_aura(true)
	death_started.emit(self)
	queue_redraw()
	if animated:
		anim.play("die")
		var tween := create_tween()
		tween.tween_interval(0.45)
		tween.tween_property(visual, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func() -> void: expired.emit(self))
	else:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.38)
		tween.tween_property(self, "scale", Vector2(0.7, 0.7), 0.38)
		tween.chain().tween_callback(func() -> void: expired.emit(self))

func heal(amount: float) -> void:
	if not alive:
		return
	hp = min(max_hp, hp + amount)
	queue_redraw()

func spend_attack_time() -> void:
	attack_cooldown = 1.0 / max(0.1, float(stats.attack_speed))

func _draw() -> void:
	if not alive:
		return
	var shadow_width := body_height * 0.42
	var shadow_half_height := body_height * 0.13
	draw_colored_polygon(
		_ellipse_points(shadow_width * 0.5, shadow_half_height, Vector2(0, -2)),
		Color(0, 0, 0, 0.28)
	)
	var bar_width := 72.0
	var bar_y := -(body_height + 14.0)
	draw_rect(Rect2(-bar_width * 0.5 - 1, bar_y - 1, bar_width + 2, 10), Color(0.05, 0.03, 0.02, 0.9), true)
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 8), Color("#43251d", 0.95), true)
	var ratio := hp / max_hp
	var bar_color := Color("#7fd65e") if faction == "ally" else Color("#ef6a4f")
	draw_rect(Rect2(-bar_width * 0.5 + 2, bar_y + 2, (bar_width - 4) * ratio, 4), bar_color, true)
	draw_line(Vector2(-bar_width * 0.5, bar_y + 9), Vector2(bar_width * 0.5, bar_y + 9), Color("#f7dfac", 0.7), 1.0)
	if skill_cost > 0:
		var energy_y := bar_y + 11.0
		var energy_ratio := clampf(energy / float(skill_cost), 0.0, 1.0)
		draw_rect(Rect2(-bar_width * 0.5 - 1, energy_y - 1, bar_width + 2, 4), Color(0.05, 0.03, 0.02, 0.86), true)
		var energy_color := Color("#ffe27a") if energy_ratio < 1.0 else Color("#fff4ae")
		draw_rect(Rect2(-bar_width * 0.5, energy_y, bar_width * energy_ratio, 2), energy_color, true)
		if energy_ratio >= 1.0:
			draw_line(Vector2(-bar_width * 0.5, energy_y), Vector2(bar_width * 0.5, energy_y), Color("#fff8d0", 0.9), 1.0)
	if shield_time > 0.0 or reflect_time > 0.0:
		var shield_color := Color("#ffd273") if shield_time > 0.0 else Color("#d7e9ff")
		draw_arc(Vector2(0, -body_height * 0.42), 42.0, 0.0, TAU, 32, Color(shield_color, 0.75), 3.0)
	if stun_time > 0.0:
		var star_y := -(body_height + 35.0)
		for index in range(3):
			var angle := Time.get_ticks_msec() * 0.004 + float(index) * TAU / 3.0
			var center := Vector2(cos(angle) * 22.0, star_y + sin(angle) * 4.0)
			draw_circle(center, 4.0, Color("#fff4ae"))
			draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), Color("#fff8d0"), 1.5)
			draw_line(center + Vector2(0, -7), center + Vector2(0, 7), Color("#fff8d0"), 1.5)
