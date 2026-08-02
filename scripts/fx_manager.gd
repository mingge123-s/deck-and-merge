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

const PRESETS := {
	"hit": {
		"texture": "spark", "role": "hot", "amount": 9, "lifetime": 0.32,
		"scale": Vector2(1.1, 2.0), "speed": Vector2(110, 215), "spread": 34.0,
		"gravity": Vector2(0, 200), "spin": true, "curve": "shrink",
	},
	"flash": {
		"texture": "dot", "role": "hot", "amount": 3, "lifetime": 0.16,
		"scale": Vector2(1.6, 2.6), "speed": Vector2(10, 40), "spread": 180.0,
		"gravity": Vector2.ZERO, "spin": false, "curve": "shrink",
	},
	"death": {
		"texture": "shard", "role": "material", "amount": 22, "lifetime": 0.82,
		"scale": Vector2(0.9, 1.55), "speed": Vector2(130, 280), "spread": 76.0,
		"gravity": Vector2(0, 450), "spin": true, "curve": "shrink",
	},
	"dust": {
		"texture": "puff", "role": "smoke", "amount": 4, "lifetime": 0.6,
		"scale": Vector2(0.9, 1.8), "speed": Vector2(14, 48), "spread": 120.0,
		"gravity": Vector2(0, -26), "spin": false, "curve": "grow",
	},
	"smoke": {
		"texture": "puff", "role": "smoke", "amount": 14, "lifetime": 1.15,
		"scale": Vector2(1.2, 2.4), "speed": Vector2(24, 70), "spread": 55.0,
		"gravity": Vector2(0, -54), "spin": false, "curve": "grow",
	},
	"spawn": {
		"texture": "dot", "role": "hot", "amount": 12, "lifetime": 0.55,
		"scale": Vector2(0.35, 0.8), "speed": Vector2(26, 70), "spread": 140.0,
		"gravity": Vector2(0, 34), "spin": false, "curve": "shrink",
	},
	"effect": {
		"texture": "dot", "role": "hot", "amount": 18, "lifetime": 0.8,
		"scale": Vector2(0.45, 1.0), "speed": Vector2(40, 120), "spread": 140.0,
		"gravity": Vector2(0, 20), "spin": false, "curve": "shrink",
	},
	"lifesteal": {
		"texture": "dot", "role": "hot", "amount": 6, "lifetime": 0.45,
		"scale": Vector2(0.4, 0.85), "speed": Vector2(90, 150), "spread": 16.0,
		"gravity": Vector2.ZERO, "spin": false, "curve": "shrink",
	},
	"heal": {
		"texture": "dot", "role": "hot", "amount": 8, "lifetime": 0.7,
		"scale": Vector2(0.4, 0.9), "speed": Vector2(46, 92), "spread": 16.0,
		"gravity": Vector2(0, -46), "spin": false, "curve": "shrink",
	},
	"tower_hit": {
		"texture": "shard", "role": "material", "amount": 12, "lifetime": 0.55,
		"scale": Vector2(0.6, 1.2), "speed": Vector2(120, 260), "spread": 78.0,
		"gravity": Vector2(0, 460), "spin": true, "curve": "shrink",
	},
	"tower_destroy": {
		"texture": "shard", "role": "material", "amount": 24, "lifetime": 0.82,
		"scale": Vector2(0.8, 1.75), "speed": Vector2(90, 190), "spread": 32.0,
		"gravity": Vector2(0, 440), "spin": true, "curve": "shrink",
	},
	"blast": {
		"texture": "dot", "role": "hot", "amount": 16, "lifetime": 0.4,
		"scale": Vector2(1.4, 3.2), "speed": Vector2(60, 190), "spread": 180.0,
		"gravity": Vector2(0, -40), "spin": false, "curve": "shrink",
	},
	"tower_power": {
		"texture": "dot", "role": "hot", "amount": 14, "lifetime": 0.6,
		"scale": Vector2(0.45, 1.0), "speed": Vector2(40, 110), "spread": 120.0,
		"gravity": Vector2(0, -70), "spin": false, "curve": "shrink",
	},
	"boss_entry": {
		"texture": "dot", "role": "hot", "amount": 42, "lifetime": 0.9,
		"scale": Vector2(0.6, 1.4), "speed": Vector2(60, 170), "spread": 170.0,
		"gravity": Vector2(0, -24), "spin": false, "curve": "shrink",
	},
}

var unit_count_getter: Callable
var textures: Dictionary = {}
var color_ramps: Dictionary = {}
var shrink_curve: Curve
var grow_curve: Curve
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
	_build_curves()
	_build_color_ramps()
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
		image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - distance / 7.0, 0.0, 1.0)))
	, 16)
	textures["spark"] = _make_texture(func(image: Image, x: int, y: int) -> void:
		var along := absf(y - 7.5)
		var across := absf(x - 7.5)
		var alpha := clampf(1.0 - across / 1.8, 0.0, 1.0) * clampf(1.0 - along / 7.0, 0.0, 1.0)
		image.set_pixel(x, y, Color(1, 1, 1, alpha))
	, 16)
	textures["shard"] = _make_texture(func(image: Image, x: int, y: int) -> void:
		var inside := x >= 4 and x <= 11 and y >= 3 and y <= 12 and (x + y) <= 20 and (x - y) <= 6
		image.set_pixel(x, y, Color.WHITE if inside else Color(1, 1, 1, 0))
	, 16)
	textures["puff"] = _make_texture(func(image: Image, x: int, y: int) -> void:
		var distance := Vector2(x, y).distance_to(Vector2(7.5, 7.5))
		image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - distance / 8.0, 0.0, 1.0) * 0.85))
	, 16)
	textures["ring"] = _make_texture(func(image: Image, x: int, y: int) -> void:
		var distance := Vector2(x, y).distance_to(Vector2(7.5, 7.5))
		var alpha := 1.0 if distance > 5.2 and distance < 7.2 else 0.0
		image.set_pixel(x, y, Color(1, 1, 1, alpha))
	, 16)

func _build_curves() -> void:
	shrink_curve = Curve.new()
	shrink_curve.add_point(Vector2(0.0, 1.0))
	shrink_curve.add_point(Vector2(1.0, 0.15))
	grow_curve = Curve.new()
	grow_curve.add_point(Vector2(0.0, 0.45))
	grow_curve.add_point(Vector2(1.0, 1.0))

func _make_texture(draw_pixel: Callable, size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for y in range(size):
		for x in range(size):
			draw_pixel.call(image, x, y)
	return ImageTexture.create_from_image(image)

func _build_color_ramps() -> void:
	for era in MATERIALS:
		var material: Dictionary = MATERIALS[era]
		color_ramps[era] = {
			"hot": _make_ramp(Color.WHITE, material.primary, material.secondary),
			"material": _make_ramp(Color(material.primary).lightened(0.35), material.primary, material.secondary),
			"smoke": _make_ramp(
				Color(material.secondary).darkened(0.35),
				Color(material.secondary).darkened(0.15),
				Color(material.secondary).darkened(0.1),
				0.6
			),
		}

func _make_ramp(start: Color, middle: Color, tail: Color, peak_alpha := 1.0) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(start, peak_alpha),
		Color(middle, peak_alpha * 0.9),
		Color(tail, 0.0),
	])
	return gradient

func _era_ramp(era: String, role: String) -> Gradient:
	var ramps: Dictionary = color_ramps.get(era, color_ramps["stone"])
	return ramps.get(role, ramps["material"])

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
	var config: Dictionary = PRESETS.get(preset, PRESETS["hit"])
	var material: Dictionary = era_material(era)
	var particle_amount := int(config.amount) if amount < 0 else amount
	if tier == 2 and _unit_count() > 40:
		particle_amount = maxi(1, int(ceil(float(particle_amount) * 0.5)))
	var lifetime := float(config.lifetime)
	var slot := _acquire_emitter(tier, particle_amount)
	if slot < 0:
		if tier == 2:
			dropped_tier2 += 1
		return false
	var emitter := emitter_pool[slot]
	emitter.position = position
	emitter.texture = textures[_preset_texture(preset, config, material)]
	emitter.amount = particle_amount
	emitter.lifetime = lifetime
	emitter.explosiveness = 0.92
	emitter.direction = direction.normalized()
	emitter.spread = float(config.spread)
	emitter.initial_velocity_min = float(config.speed.x)
	emitter.initial_velocity_max = float(config.speed.y)
	emitter.gravity = config.gravity
	emitter.scale_amount_min = float(config.scale.x)
	emitter.scale_amount_max = float(config.scale.y)
	emitter.scale_amount_curve = shrink_curve if config.curve == "shrink" else grow_curve
	if bool(config.spin):
		emitter.angle_min = -180.0
		emitter.angle_max = 180.0
		emitter.angular_velocity_min = -520.0
		emitter.angular_velocity_max = 520.0
	else:
		emitter.angle_min = 0.0
		emitter.angle_max = 0.0
		emitter.angular_velocity_min = 0.0
		emitter.angular_velocity_max = 0.0
	emitter.color = Color.WHITE
	if color_override.a >= 0.0:
		emitter.color_ramp = _make_ramp(
			Color(color_override).lightened(0.45),
			color_override,
			Color(material.secondary)
		)
	else:
		emitter.color_ramp = _era_ramp(era, str(config.role))
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
	ring.width = 7.0
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
	line.points = PackedVector2Array([-facing * 28.0, facing * 16.0])
	line.width = 6.5
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
	trail.default_color = Color(color, 0.84)
	trail.width = 5.5
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
	trail.points = PackedVector2Array([position - offset * 1.55, position - offset * 1.0, position - offset * 0.45, position])

func release_projectile_trail(trail: Line2D) -> void:
	if trail == null or not is_instance_valid(trail):
		return
	var slot := projectile_trail_pool.find(trail)
	if slot < 0:
		return
	projectile_trail_active[slot] = false
	trail.visible = false

func emit_hit(position: Vector2, direction := Vector2.LEFT, era := "stone") -> void:
	emit("hit", position, direction, era, 2, -1)
	emit("flash", position, Vector2.UP, era, 2, -1)
	emit_impact_line(position, direction, Color(1, 1, 1, 0.95), 0.12)

func emit_death(position: Vector2, direction := Vector2.UP, era := "stone") -> void:
	emit("death", position + Vector2(0, -10), direction.rotated(-0.5), era, 1, 22)
	emit("dust", position + Vector2(0, 6), Vector2.UP, era, 1, 12)
	emit_ground_stain(position)
	emit_ring(position, Color(0.16, 0.11, 0.07, 0.58), 44.0, 0.5, 1)

func emit_ground_stain(position: Vector2, duration := 0.8) -> bool:
	for index in range(shard_pool.size()):
		if shard_active[index]:
			continue
		var stain := shard_pool[index]
		stain.texture = textures["puff"]
		stain.position = position + Vector2(0, 8)
		stain.scale = Vector2(3.0, 1.1)
		stain.modulate = Color(0.12, 0.09, 0.07, 0.52)
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
	emit("tower_hit", position, Vector2.UP, era, 1, 12)
	emit("dust", position, Vector2.UP, era, 1, 4)
	emit_ring(position, Color("#fff0c7"), 26.0, 0.22, 1)
	emit_impact_line(position, Vector2.UP, Color("#fff8df"), 0.14)

func emit_tower_destroy(position: Vector2, era := "stone") -> void:
	emit("blast", position + Vector2(0, -30), Vector2.UP, era, 0, 16, Color("#ffe9a0"))
	emit("tower_destroy", position + Vector2(0, -20), Vector2.UP, era, 0, 24)
	emit("tower_destroy", position + Vector2(0, -6), Vector2.LEFT, era, 0, 16)
	emit("tower_destroy", position + Vector2(0, -6), Vector2.RIGHT, era, 0, 16)
	emit("smoke", position + Vector2(0, -24), Vector2.UP, era, 0, 14)
	emit_ring(position, Color("#ffd273"), 96.0, 0.7, 0)
	emit_ring(position + Vector2(0, -14), Color("#ff8e70"), 58.0, 0.55, 0)
	emit_ground_stain(position, 1.4)
	var delayed := get_tree().create_timer(0.28)
	delayed.timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		emit("blast", position + Vector2(26, -54), Vector2.UP, era, 0, 10, Color("#ffcf7a"))
		emit("tower_destroy", position + Vector2(12, -32), Vector2.UP, era, 0, 12)
		emit_ring(position + Vector2(12, -32), Color("#ffd273"), 62.0, 0.5, 0)
	)

func emit_tower_power(position: Vector2, era := "stone") -> void:
	emit("tower_power", position, Vector2.UP, era, 1, 12)
	emit_ring(position, Color("#ffd273"), 44.0, 0.6, 1)

func emit_boss_entry(position: Vector2, color: Color, era := "stone") -> void:
	emit("boss_entry", position, Vector2.UP, era, 0, 60, color)

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

func _preset_texture(preset: String, config: Dictionary, material: Dictionary) -> String:
	if preset in ["death", "tower_hit", "tower_destroy"]:
		var choices: Array = material.textures
		for choice in choices:
			if str(choice) != "puff":
				return str(choice)
	return str(config.texture)
