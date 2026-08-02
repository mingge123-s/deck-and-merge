class_name FxManager
extends Node2D

const MAX_EMITTERS := 16
const MAX_PARTICLES := 400
const MAX_PROJECTILE_TRAILS := 24
const MAX_EFFECT_LINES := 8
const MAX_SHARDS := 24

const MATERIALS := {
	"stone": {
		"textures": ["shard", "puff"],
		"primary": Color("#d7b98a"),
		"secondary": Color("#8a6b4a"),
		"gravity": Vector2(0, 86),
		"spread": 125.0,
		"speed": Vector2(28, 72),
	},
	"iron": {
		"textures": ["spark"],
		"primary": Color("#ffcc6b"),
		"secondary": Color("#ff7a3c"),
		"gravity": Vector2(0, 48),
		"spread": 82.0,
		"speed": Vector2(42, 96),
	},
	"industrial": {
		"textures": ["puff", "shard"],
		"primary": Color("#dfe4e8"),
		"secondary": Color("#b98a3c"),
		"gravity": Vector2(0, -18),
		"spread": 150.0,
		"speed": Vector2(20, 58),
	},
	"modern": {
		"textures": ["spark", "puff"],
		"primary": Color("#ffe9a8"),
		"secondary": Color("#5c5c5c"),
		"gravity": Vector2(0, 36),
		"spread": 70.0,
		"speed": Vector2(48, 112),
	},
	"future": {
		"textures": ["dot", "ring"],
		"primary": Color("#7ee8ff"),
		"secondary": Color("#c48cff"),
		"gravity": Vector2.ZERO,
		"spread": 105.0,
		"speed": Vector2(34, 90),
	},
}

var unit_count_getter: Callable
var textures: Dictionary = {}
var emitter_pool: Array[CPUParticles2D] = []
var emitter_active: Array[bool] = []
var emitter_until: Array[float] = []
var emitter_amount: Array[int] = []
var emitter_tier: Array[int] = []
var projectile_trail_pool: Array[Line2D] = []
var projectile_trail_active: Array[bool] = []
var effect_line_pool: Array[Line2D] = []
var effect_line_active: Array[bool] = []
var effect_line_until: Array[float] = []
var effect_line_started: Array[float] = []
var effect_line_duration: Array[float] = []
var effect_line_kind: Array[String] = []
var shard_pool: Array[Sprite2D] = []
var shard_active: Array[bool] = []
var shard_until: Array[float] = []
var elapsed := 0.0
var active_particle_count := 0
var dropped_tier2 := 0
var preempted_tier2 := 0

func setup(get_unit_count: Callable) -> void:
	unit_count_getter = get_unit_count
	_build_textures()
	for _index in range(MAX_EMITTERS):
		var emitter := CPUParticles2D.new()
		emitter.one_shot = true
		emitter.emitting = false
		emitter.z_index = 7
		add_child(emitter)
		emitter_pool.append(emitter)
		emitter_active.append(false)
		emitter_until.append(0.0)
		emitter_amount.append(0)
		emitter_tier.append(2)
	for _index in range(MAX_PROJECTILE_TRAILS):
		var trail := Line2D.new()
		trail.width = 3.0
		trail.antialiased = true
		trail.z_index = 6
		trail.visible = false
		add_child(trail)
		projectile_trail_pool.append(trail)
		projectile_trail_active.append(false)
	for _index in range(MAX_EFFECT_LINES):
		var line := Line2D.new()
		line.width = 3.0
		line.antialiased = true
		line.z_index = 6
		line.visible = false
		add_child(line)
		effect_line_pool.append(line)
		effect_line_active.append(false)
		effect_line_until.append(0.0)
		effect_line_started.append(0.0)
		effect_line_duration.append(0.0)
		effect_line_kind.append("")
	for _index in range(MAX_SHARDS):
		var shard := Sprite2D.new()
		shard.texture = textures["shard"]
		shard.z_index = 7
		shard.visible = false
		add_child(shard)
		shard_pool.append(shard)
		shard_active.append(false)
		shard_until.append(0.0)

func _build_textures() -> void:
	textures["dot"] = _make_texture(func(image: Image, x: int, y: int) -> void:
		var distance := Vector2(x, y).distance_to(Vector2(7.5, 7.5))
		image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - distance / 8.0, 0.0, 1.0)))
	, 16)
	textures["spark"] = _make_texture(func(image: Image, x: int, y: int) -> void:
		var center := Vector2(7.5, 7.5)
		var point := Vector2(x, y)
		var distance := absf((point - center).x + (point - center).y * 0.35)
		image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - distance / 2.7, 0.0, 1.0)))
	, 16)
	textures["shard"] = _make_texture(func(image: Image, x: int, y: int) -> void:
		var inside := (x >= 3 and x <= 12 and y >= 2 and y <= 13 and y <= 14 - x / 2)
		image.set_pixel(x, y, Color.WHITE if inside else Color(1, 1, 1, 0))
	, 16)
	textures["puff"] = _make_texture(func(image: Image, x: int, y: int) -> void:
		var distance := Vector2(x, y).distance_to(Vector2(7.5, 7.5))
		image.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - distance / 8.0) * 0.55, 0.0, 0.55)))
	, 16)
	textures["ring"] = _make_texture(func(image: Image, x: int, y: int) -> void:
		var distance := Vector2(x, y).distance_to(Vector2(7.5, 7.5))
		var alpha := 1.0 if distance > 5.2 and distance < 7.2 else 0.0
		image.set_pixel(x, y, Color(1, 1, 1, alpha))
	, 16)

func _make_texture(draw_pixel: Callable, size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for y in range(size):
		for x in range(size):
			draw_pixel.call(image, x, y)
	return ImageTexture.create_from_image(image)

func era_material(era: String) -> Dictionary:
	return MATERIALS.get(era, MATERIALS["stone"])

func emit(
	preset: String,
	position: Vector2,
	direction := Vector2.UP,
	era := "stone",
	tier := 2,
	amount := -1,
	color_override := Color(-1, -1, -1, -1),
) -> bool:
	var material: Dictionary = era_material(era)
	var particle_amount := _preset_amount(preset) if amount < 0 else amount
	if tier == 2 and _unit_count() > 40:
		particle_amount = maxi(1, int(ceil(float(particle_amount) * 0.5)))
	var lifetime := _preset_lifetime(preset)
	var slot := _acquire_emitter(tier, particle_amount)
	if slot < 0:
		if tier == 2:
			dropped_tier2 += 1
		return false
	var emitter := emitter_pool[slot]
	var texture_name := _preset_texture(preset, material)
	emitter.position = position
	emitter.texture = textures[texture_name]
	emitter.amount = particle_amount
	emitter.lifetime = lifetime
	emitter.explosiveness = 0.9
	emitter.direction = direction.normalized()
	emitter.spread = _preset_spread(preset, float(material.spread))
	emitter.initial_velocity_min = _preset_speed_min(preset, material)
	emitter.initial_velocity_max = _preset_speed_max(preset, material)
	emitter.gravity = _preset_gravity(preset, material)
	emitter.scale_amount_min = 0.16 if preset == "hit" else 0.2
	emitter.scale_amount_max = 0.42 if preset == "hit" else 0.55
	var primary: Color = material.primary.lerp(material.secondary, 0.22)
	if color_override.a >= 0.0:
		primary = color_override.lerp(material.secondary, 0.22)
	emitter.color = Color(primary, 0.92)
	emitter.emitting = true
	emitter_active[slot] = true
	emitter_until[slot] = elapsed + lifetime + 0.08
	emitter_amount[slot] = particle_amount
	emitter_tier[slot] = tier
	active_particle_count += particle_amount
	return true

func emit_ring(position: Vector2, color: Color, radius: float, duration := 0.45, tier := 2) -> bool:
	var slot := _acquire_effect_line(tier)
	if slot < 0:
		if tier == 2:
			dropped_tier2 += 1
		return false
	var ring := effect_line_pool[slot]
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 19.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.position = position
	ring.points = points
	ring.closed = true
	ring.width = 4.0
	ring.default_color = Color(color, 0.9)
	ring.scale = Vector2(0.25, 0.45)
	ring.modulate.a = 1.0
	ring.visible = true
	effect_line_active[slot] = true
	effect_line_started[slot] = elapsed
	effect_line_duration[slot] = duration
	effect_line_until[slot] = elapsed + duration
	effect_line_kind[slot] = "ring"
	return true

func emit_impact_line(position: Vector2, direction: Vector2, color := Color.WHITE, duration := 0.1) -> bool:
	var slot := _acquire_effect_line(2)
	if slot < 0:
		dropped_tier2 += 1
		return false
	var line := effect_line_pool[slot]
	var facing := direction.normalized()
	line.position = position
	line.points = PackedVector2Array([-facing * 18.0, facing * 8.0])
	line.width = 3.0
	line.default_color = color
	line.scale = Vector2.ONE
	line.modulate.a = 1.0
	line.visible = true
	effect_line_active[slot] = true
	effect_line_started[slot] = elapsed
	effect_line_duration[slot] = duration
	effect_line_until[slot] = elapsed + duration
	effect_line_kind[slot] = "line"
	return true

func acquire_projectile_trail(color: Color, tier := 2) -> Line2D:
	var slot := _acquire_projectile_trail()
	if slot < 0:
		if tier == 2:
			dropped_tier2 += 1
		return null
	var trail := projectile_trail_pool[slot]
	trail.default_color = Color(color, 0.72)
	trail.width = 3.0
	trail.scale = Vector2.ONE
	trail.modulate.a = 1.0
	trail.visible = true
	projectile_trail_active[slot] = true
	return trail

func update_projectile_trail(trail: Line2D, position: Vector2, previous: Vector2) -> void:
	if trail == null or not is_instance_valid(trail):
		return
	trail.position = Vector2.ZERO
	var offset := position - previous
	trail.points = PackedVector2Array([position - offset * 0.9, position - offset * 0.35])

func release_projectile_trail(trail: Line2D) -> void:
	if trail == null or not is_instance_valid(trail):
		return
	var slot := projectile_trail_pool.find(trail)
	if slot < 0:
		return
	projectile_trail_active[slot] = false
	trail.visible = false

func emit_death(position: Vector2, direction := Vector2.UP, era := "stone") -> void:
	emit("death", position, direction, era, 1, 8)
	emit("dust", position, Vector2.UP, era, 1, 2)
	emit_ground_stain(position)
	emit_ring(position, Color(0.12, 0.08, 0.05, 0.55), 28.0, 0.42, 1)

func emit_ground_stain(position: Vector2, duration := 0.8) -> bool:
	for index in range(shard_pool.size()):
		if shard_active[index]:
			continue
		var stain := shard_pool[index]
		stain.texture = textures["puff"]
		stain.position = position + Vector2(0, 8)
		stain.scale = Vector2(1.8, 0.52)
		stain.modulate = Color(0.1, 0.07, 0.05, 0.42)
		stain.visible = true
		shard_active[index] = true
		shard_until[index] = elapsed + duration
		return true
	return false

func emit_lifesteal(from: Vector2, to: Vector2, era := "stone") -> void:
	var direction := (to - from).normalized()
	emit("lifesteal", from, direction, era, 2, 5, Color("#b93858"))

func emit_heal(position: Vector2, era := "stone") -> void:
	emit("heal", position, Vector2.UP, era, 2, 6, Color("#8ce68c"))

func emit_tower_hit(position: Vector2, era := "stone") -> void:
	emit("tower_hit", position, Vector2.UP, era, 1, 8)
	emit_impact_line(position, Vector2.UP, Color("#fff0c7"), 0.1)

func emit_tower_destroy(position: Vector2, era := "stone") -> void:
	emit("tower_destroy", position, Vector2.UP, era, 0, 24)
	emit("tower_destroy", position, Vector2.LEFT, era, 0, 24)
	emit_ring(position, Color("#ffd273"), 92.0, 0.75, 0)
	emit_ring(position, Color("#ff8e70"), 52.0, 0.5, 0)

func emit_tower_power(position: Vector2, era := "stone") -> void:
	emit("tower_power", position, Vector2.UP, era, 1, 12)
	emit_ring(position, Color("#ffd273"), 44.0, 0.6, 1)

func emit_boss_entry(position: Vector2, color: Color, era := "stone") -> void:
	emit("boss_entry", position, Vector2.UP, era, 0, 42, color)

func budget_stats() -> Dictionary:
	var emitters := 0
	for active in emitter_active:
		if active:
			emitters += 1
	return {
		"emitters": emitters,
		"particles": active_particle_count,
		"max_emitters": MAX_EMITTERS,
		"max_particles": MAX_PARTICLES,
		"dropped_tier2": dropped_tier2,
		"preempted_tier2": preempted_tier2,
	}

func _process(delta: float) -> void:
	elapsed += delta
	for index in range(emitter_pool.size()):
		if emitter_active[index] and elapsed >= emitter_until[index]:
			emitter_pool[index].emitting = false
			emitter_active[index] = false
			active_particle_count = maxi(0, active_particle_count - emitter_amount[index])
			emitter_amount[index] = 0
	for index in range(effect_line_pool.size()):
		if effect_line_active[index] and elapsed >= effect_line_until[index]:
			effect_line_active[index] = false
			effect_line_pool[index].visible = false
			effect_line_pool[index].points = PackedVector2Array()
		elif effect_line_active[index]:
			var progress := clampf((elapsed - effect_line_started[index]) / maxf(0.01, effect_line_duration[index]), 0.0, 1.0)
			if effect_line_kind[index] == "ring":
				effect_line_pool[index].scale = Vector2(0.25 + progress * 0.95, 0.45)
			else:
				effect_line_pool[index].scale = Vector2.ONE
			effect_line_pool[index].modulate.a = 1.0 - progress
	for index in range(shard_pool.size()):
		if shard_active[index] and elapsed >= shard_until[index]:
			shard_active[index] = false
			shard_pool[index].visible = false
		elif shard_active[index]:
			var stain_progress := clampf((elapsed - (shard_until[index] - 0.8)) / 0.8, 0.0, 1.0)
			shard_pool[index].modulate.a = 0.42 * (1.0 - stain_progress)

func _acquire_emitter(tier: int, amount: int) -> int:
	for index in range(emitter_pool.size()):
		if not emitter_active[index]:
			if active_particle_count + amount <= MAX_PARTICLES:
				return index
	if tier == 2:
		return -1
	if tier == 0:
		for index in range(emitter_pool.size()):
			if emitter_active[index] and emitter_tier[index] == 2:
				emitter_pool[index].emitting = false
				emitter_active[index] = false
				active_particle_count = maxi(0, active_particle_count - emitter_amount[index])
				emitter_amount[index] = 0
				preempted_tier2 += 1
				if active_particle_count + amount <= MAX_PARTICLES:
					return index
	return -1

func _acquire_projectile_trail() -> int:
	for index in range(projectile_trail_pool.size()):
		if not projectile_trail_active[index]:
			return index
	return -1

func _acquire_effect_line(tier: int) -> int:
	for index in range(effect_line_pool.size()):
		if not effect_line_active[index]:
			return index
	if tier == 0:
		var oldest := -1
		var oldest_time := INF
		for index in range(effect_line_pool.size()):
			if effect_line_active[index] and effect_line_started[index] < oldest_time:
				oldest = index
				oldest_time = effect_line_started[index]
		if oldest >= 0:
			effect_line_active[oldest] = false
			effect_line_pool[oldest].visible = false
			preempted_tier2 += 1
			return oldest
	return -1

func _unit_count() -> int:
	if unit_count_getter.is_valid():
		return int(unit_count_getter.call())
	return 0

func _preset_amount(preset: String) -> int:
	return {
		"spawn": 12,
		"effect": 18,
		"hit": 6,
		"death": 8,
		"dust": 2,
		"lifesteal": 5,
		"heal": 6,
		"tower_hit": 8,
		"tower_destroy": 24,
		"tower_power": 12,
		"boss_entry": 42,
	}.get(preset, 8)

func _preset_lifetime(preset: String) -> float:
	return {
		"spawn": 0.55,
		"effect": 0.8,
		"hit": 0.22,
		"death": 0.55,
		"dust": 0.4,
		"lifesteal": 0.45,
		"heal": 0.65,
		"tower_hit": 0.4,
		"tower_destroy": 0.9,
		"tower_power": 0.55,
		"boss_entry": 0.9,
	}.get(preset, 0.5)

func _preset_texture(preset: String, material: Dictionary) -> String:
	match preset:
		"lifesteal", "heal":
			return "dot"
		"dust":
			return "puff"
		"tower_destroy", "death", "tower_hit":
			return "shard"
		"boss_entry":
			return "dot"
		"tower_power":
			return str(material.textures[1]) if material.textures.size() > 1 else str(material.textures[0])
		_:
			var choices: Array = material.textures
			return str(choices[0])

func _preset_spread(preset: String, material_spread: float) -> float:
	match preset:
		"boss_entry":
			return 170.0
		"hit":
			return 55.0
		"lifesteal":
			return 20.0
		"heal":
			return 18.0
		_:
			return material_spread

func _preset_speed_min(preset: String, material: Dictionary) -> float:
	match preset:
		"boss_entry":
			return 34.0
		"lifesteal":
			return 42.0
		"heal":
			return 26.0
		"tower_destroy":
			return 60.0
		_:
			return float(material.speed.x)

func _preset_speed_max(preset: String, material: Dictionary) -> float:
	match preset:
		"boss_entry":
			return 108.0
		"lifesteal":
			return 78.0
		"heal":
			return 54.0
		"tower_destroy":
			return 140.0
		_:
			return float(material.speed.y)

func _preset_gravity(preset: String, material: Dictionary) -> Vector2:
	match preset:
		"boss_entry":
			return Vector2(0, -18)
		"lifesteal":
			return Vector2.ZERO
		"heal":
			return Vector2(0, -20)
		_:
			return material.gravity
