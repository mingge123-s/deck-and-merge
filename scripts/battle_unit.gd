class_name BattleUnit
extends Node2D

signal expired(unit: BattleUnit)

static var _meta_cache: Dictionary = {}
static var _frames_cache: Dictionary = {}

var unit_id := ""
var faction := ""
var stats: Dictionary = {}
var max_hp := 1.0
var hp := 1.0
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

func setup(id: String, side: String, data: Dictionary, texture: Texture2D) -> void:
	unit_id = id
	faction = side
	stats = data
	max_hp = float(data.hp)
	hp = max_hp
	var role_scale := float(data.get("scale", 1.0))
	var desired_height := (104.0 if side == "ally" else 92.0) * role_scale
	if _setup_animated(str(data.get("anim", id)), side, desired_height):
		animated = true
	else:
		_setup_static(side, desired_height, texture)
	queue_redraw()

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
	if flash_time > 0.0 and is_instance_valid(visual):
		flash_time -= delta
		visual.modulate = Color(1.0, 0.7, 0.5) if flash_time > 0.0 else Color.WHITE

func receive_damage(amount: float) -> void:
	if not alive:
		return
	hp = max(0.0, hp - amount)
	flash_time = 0.12
	_play_hit_punch()
	queue_redraw()
	if hp <= 0.0:
		_die()

func _play_hit_punch() -> void:
	if not is_instance_valid(visual):
		return
	if hit_punch_tween != null:
		hit_punch_tween.kill()
	visual.scale = visual_base_scale
	hit_punch_tween = create_tween()
	hit_punch_tween.tween_property(visual, "scale", visual_base_scale * 1.06, 0.045)
	hit_punch_tween.tween_property(visual, "scale", visual_base_scale, 0.055)

func _die() -> void:
	alive = false
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
	var bar_width := 72.0
	var bar_y := -122.0 if faction == "ally" else -111.0
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 8), Color("#43251d", 0.9), true)
	var ratio := hp / max_hp
	var bar_color := Color("#7fd65e") if faction == "ally" else Color("#ef6a4f")
	draw_rect(Rect2(-bar_width * 0.5 + 2, bar_y + 2, (bar_width - 4) * ratio, 4), bar_color, true)
	draw_line(Vector2(-bar_width * 0.5, bar_y + 9), Vector2(bar_width * 0.5, bar_y + 9), Color("#f7dfac", 0.7), 1.0)
