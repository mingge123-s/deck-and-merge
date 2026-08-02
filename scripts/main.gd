extends Node2D

const VIEW_SIZE := Vector2(720, 1280)
const BATTLE_RECT := Rect2(36, 116, 648, 300)
const TRAY_RECT := Rect2(36, 432, 648, 156)
const BOARD_RECT := Rect2(36, 604, 648, 636)
const CARD_SIZE := Vector2(138, 166)
const TRAY_SLOT_SIZE := Vector2(80, 80)
const TRAY_SLOT_STEP := 89.0
const TRAY_SLOT_ORIGIN := Vector2(16, 48)
const DECK_LOW_MARGIN := 12 # 牌堆少于目标-12张才触发补牌；每次把缺口最大的卡补齐到目标(单张单批≤3)
const TRAY_SLOTS := 7
const PREP_WAVE_INTERVAL := 3
const SPAWN_STAGGER := 0.6
const WAVE_DURATION := 180.0
const KILL_COIN_MULT := 0.2
const ERA_UP_ROUNDS := [2, 4, 7, 10] # 在这些轮次各升一级时代：1石器/2铁器/4工业/7现代/10未来
const BATCH_BASE_GROUPS := 60
const BATCH_GROUP_STEP := 10
const MIN_BOSS_GROUPS := 2 # 每批保底当前时代 BOSS 组数（保证至少能合成）
const DIFFICULTIES := {
	"easy": {"name": "简单", "wave_min": 6.0, "first_delay": 7.0, "count_base": 5, "count_step": 6, "count_max": 10, "enemy_mult": 0.6, "boss_wave": 8, "tower_mult": 1.9, "ai_income_mult": 0.6, "ai_trickle": 0.3, "ai_effect_chance": 0.25},
	"normal": {"name": "普通", "wave_min": 5.0, "first_delay": 4.0, "count_base": 5, "count_step": 4, "count_max": 13, "enemy_mult": 1.0, "boss_wave": 5, "tower_mult": 1.1, "ai_income_mult": 1.0, "ai_trickle": 0.5, "ai_effect_chance": 0.4},
	"hard": {"name": "困难", "wave_min": 3.0, "first_delay": 3.0, "count_base": 8, "count_step": 3, "count_max": 18, "enemy_mult": 1.3, "boss_wave": 4, "tower_mult": 1.0, "ai_income_mult": 1.4, "ai_trickle": 0.8, "ai_effect_chance": 0.55},
}
const BATTLE_GROUND_Y := 222.0
const CAMERA_FOLLOW_SPEED := 4.0
const CAMERA_MANUAL_HOLD := 3.0
const WORLD_WIDTH := 1680.0
const BATTLE_VIEW_W := 648.0
const ALLY_TOWER_X := 96.0
const ENEMY_TOWER_X := WORLD_WIDTH - 96.0
const TOWER_RANGE := 82.0
const TOWER_HEIGHT := 160.0
const TOWER_GROUND_NUDGE := 3.0
const TOWER_ATTACK_RANGE := 420.0
const TOWER_ATTACK_CD := 1.1
const TOWER_BASE_DAMAGE := 90.0
const TOWER_POWER_MAX := 3.0
const TANK_AGGRO_RADIUS := 150.0
const PROJECTILE_RANGE_THRESHOLD := 100.0
const UNIT_CAP := 30
const ENEMY_UNIT_CAP := 60 # 敌方同屏上限（AI出兵x5后需高于己方）
const VICTORY_REWARD_BASE := 120
const RANDOM_EFFECT_PRICE_BASE := 260
const CLEAR_TRAY_COST := 200
const AI_EFFECT_CD := 8.0
const RALLY_BURST := 6
const RANDOM_EFFECTS := [
	{"id": "reinforcement", "name": "召唤援军", "desc": "立刻召唤 1 个随机时代的随机英雄", "duration": 0.0},
	{"id": "boss_call", "name": "BOSS 召唤", "desc": "立刻出战 1 个当前时代的 BOSS 英雄", "duration": 0.0},
	{"id": "field_aid", "name": "战场急救", "desc": "我方全体回复 40% 生命", "duration": 0.0},
	{"id": "freeze", "name": "冰冻力场", "desc": "敌方全体停止行动 3 秒", "duration": 3.0},
	{"id": "frenzy", "name": "狂暴号角", "desc": "我方攻速 +40%，持续 20 秒", "duration": 20.0},
	{"id": "morale", "name": "战意鼓舞", "desc": "我方攻击 +25%，持续 30 秒", "duration": 30.0},
	{"id": "bulwark", "name": "铁壁阵型", "desc": "我方受到伤害 -30%，持续 30 秒", "duration": 30.0},
	{"id": "haste", "name": "疾行药剂", "desc": "我方移速 +50%，持续 20 秒", "duration": 20.0},
	{"id": "lifesteal", "name": "吸血图腾", "desc": "我方造成伤害的 20% 转为治疗，持续 30 秒", "duration": 30.0},
	{"id": "thorns", "name": "荆棘护甲", "desc": "我方受到近战伤害时反弹 30%，持续 30 秒", "duration": 30.0},
	{"id": "tower_repair", "name": "修复我方塔", "desc": "我方塔回复 25% 满血", "duration": 0.0},
	{"id": "tower_power", "name": "塔炮升级", "desc": "我方塔攻击 +50%，整局有效", "duration": 0.0},
	{"id": "bounty", "name": "悬赏令", "desc": "30 秒内每击杀额外 +15 金币（随时代缩放）", "duration": 30.0},
]
const BOUNTY_COIN_BASE := 15
## 合成台上长按多久弹卡牌详情
const CARD_INFO_HOLD := 0.4
const EFFECT_ICON_PATH := "res://assets/icons/effects/%s.png"
const EFFECT_CARD_PREFIX := "effect_"
const EFFECT_CARD_PAIR_SIZE := 2
const EFFECT_CARDS_PER_ERA_MIN := 2
const EFFECT_CARDS_PER_ERA_MAX := 3
const EFFECT_CARD_COLOR := Color("#8754d8")
const TUTORIAL_STEPS := [
	{
		"title": "欢迎来到牌桌远征",
		"text": "目标：打光敌方塔的血量即获胜，自己的塔被打光则失败。\n跟着下面几步走一遍，十秒学会。",
		"rect": Rect2(),
	},
	{
		"title": "第 1 步：从牌堆取牌",
		"text": "这里是牌堆。点击[b]没被压住[/b]的卡牌，它会飞进上方的合成台；被压在下面的卡点不动。\n牌堆取空就进入下一轮，自动发一批新牌。",
		"rect": BOARD_RECT,
	},
	{
		"title": "第 2 步：在合成台合成",
		"text": "合成台共 7 格。小兵卡[b]3 张同名[/b]自动合成英雄并上场；效果卡[b]2 张同名[/b]立刻发动（召唤援军、修复我方塔、塔炮升级等）。\n注意：7 格放满且凑不出任何合成时，会自动扣 200 金币清空，金币不足就判负。别乱收用不上的牌。",
		"rect": TRAY_RECT,
	},
	{
		"title": "第 3 步：看战场",
		"text": "合成出的英雄会自动前进作战，你不用指挥。左右拖动可查看整个战场，右上角小地图显示双方单位与塔血。\n击杀敌人获得金币；敌人按波次进攻，每 3 波会有一段整备期。",
		"rect": BATTLE_RECT,
	},
	{
		"title": "第 4 步：时代会自己升级",
		"text": "顶栏显示当前时代、轮次、波次与金币。每过一轮自动推进一个时代：石器 → 铁器 → 工业 → 现代 → 未来。\n时代越高，双方塔的血量与攻击越强，牌堆也会混入新时代的卡。右上角 ? 可随时重看本教程。",
		"rect": Rect2(30, 30, 660, 70),
	},
	{
		"title": "开始吧",
		"text": "一句话口诀：[b]先凑当前时代的三连，别把合成台塑死[/b]。\nBOSS 卡（图腾/王冠/烟囱/军徽/AI核心）少但最强，碰到优先凑齐。",
		"rect": Rect2(),
	},
]

const ERA_TOWER_TINTS := {
	"stone": Color(1.0, 0.93, 0.82),
	"iron": Color(0.92, 0.96, 1.0),
	"industrial": Color(1.0, 0.9, 0.76),
	"modern": Color(0.84, 0.89, 0.95),
	"future": Color(0.7, 0.88, 0.94),
}

var board: Control
var tray: Control
var battlefield: Control
var world: Control
var fx_manager: FxManager
var minimap: BattleMinimap
var camera_x := 0.0
var camera_manual_timer := 0.0
var dragging := false
var card_layer: Control
var board_bg: TextureRect
var board_bg_fade: TextureRect
var battle_bg: TextureRect
var battle_bg_fade: TextureRect
var ally_tower_sprite: Sprite2D
var enemy_tower_sprite: Sprite2D
var ally_tower_shadow: Sprite2D
var enemy_tower_shadow: Sprite2D
var ally_tower_aura: Line2D
var enemy_tower_aura: Line2D
var ally_tower_alarm_vfx: Node2D
var enemy_tower_alarm_vfx: Node2D
var ally_tower_aura_tween: Tween
var enemy_tower_aura_tween: Tween
var tray_cards: Array[String] = []
var tray_incoming := 0
var tray_views: Array[Control] = []
var deck_cards: Array[CardView] = []
var battle_units: Array[BattleUnit] = []
var occupied_units := 0
var coin_count := 300
var current_era := "stone"
var current_difficulty := "normal"
var difficulty_buttons: Dictionary = {}
var era_index := 0
var kill_score := 0
var coin_label: Label
var era_label: Label
var score_label: Label
var deck_label: Label
var status_label: Label
var update_status_label: Label
var restart_button: Button
var result_menu_button: Button
var return_button: Button
var pause_button: Button
var main_menu: Control
var settings_panel: Panel
var era_select_panel: Panel
var era_select_buttons: Array[Button] = []
var pause_overlay: Control
var pause_top_button: Button
var pause_bottom_button: Button
var pause_mode := "prep"
var pause_title_label: Label
var pause_hint_label: Label
var tutorial_overlay: Control
var help_button: Button
var tutorial_resume_paused := false
var tutorial_hid_menu := false
var tutorial_step := 0
var tutorial_dims: Array[ColorRect] = []
var tutorial_focus: Panel
var tutorial_card: Panel
var tutorial_title_label: Label
var tutorial_text_label: RichTextLabel
var tutorial_step_label: Label
var tutorial_prev_button: Button
var tutorial_next_button: Button
var tutorial_skip_button: Button
var card_info_overlay: Control
var card_info_title_label: Label
var card_info_text_label: RichTextLabel
var tray_press_index := -1
var wave_bar: ProgressBar
var wave_bar_label: Label
var result_overlay: Control
var music_slider: HSlider
var sfx_slider: HSlider
var battle_hint: Label
var boss_entry_overlay: Control
var boss_entry_banner: Label
var boss_entry_tween: Tween
var ally_tower_bar: TowerHealthBar
var enemy_tower_bar: TowerHealthBar
var battle_active := false
var battle_ended := false
var battle_won := false
var paused := false
var wave_min_timer := 0.0
var wave_spawning := false
var wave_active_timer := 0.0
var wave_boss_pending := false
var enemy_spawn_timer := 0.0
var enemy_spawn_index := 0
var wave_number := 0
var round_number := 0
var base_era_index := 0
var ally_tower_cd := 0.0
var enemy_tower_cd := 0.0
var card_z_top := 0
var ally_tower_hp := 1.0
var enemy_tower_hp := 1.0
var ally_tower_max_hp := 1.0
var enemy_tower_max_hp := 1.0
var tower_destruction_started := false
var ally_alarm_50_played := false
var ally_alarm_25_played := false
var enemy_era_index := 0
var enemy_era := "stone"
var era_visual_tween: Tween
var rng := RandomNumberGenerator.new()
var prep_pending := false
var auto_prep := false
var buff_timers: Dictionary = {}
var enemy_buff_timers: Dictionary = {}
var ai_effects: Array = []
var effect_cards_by_era: Dictionary = {}
var buff_label: RichTextLabel
var enemy_buff_label: RichTextLabel
var enemy_action_label: Label
var enemy_freeze_time := 0.0
var ally_freeze_time := 0.0
var tower_attack_bonus := 1.0
var enemy_tower_attack_bonus := 1.0
var _bounty_pulse_phase := 0.0
var enemy_coin := 0.0
var enemy_effect_cd := 0.0
var enemy_rally_fired := 0
var stuck_warned := false
var hit_fx_pool: Array[Label] = []
var camera_shake_offset := Vector2.ZERO
var camera_shake_tween: Tween
var walk_dust_cooldowns: Dictionary = {}
var fx_unit_count_cache := 0

func _diff() -> Dictionary:
	return DIFFICULTIES[current_difficulty]

func _register_effect_cards() -> void:
	for effect in RANDOM_EFFECTS:
		var effect_id := str(effect.id)
		GameData.CARDS[_effect_card_id(effect_id)] = {
			"name": str(effect.name),
			"effect": effect_id,
			"era": "effect",
			"color": EFFECT_CARD_COLOR,
		}

func _all_effect_ids() -> Array[String]:
	var ids: Array[String] = []
	for effect in RANDOM_EFFECTS:
		ids.append(str(effect.id))
	return ids

func _roll_effect_cards_by_era() -> void:
	effect_cards_by_era.clear()
	var all_effect_ids := _all_effect_ids()
	for era in GameData.ERAS:
		var pool := all_effect_ids.duplicate()
		pool.shuffle()
		var selected: Array[String] = []
		var count := rng.randi_range(EFFECT_CARDS_PER_ERA_MIN, EFFECT_CARDS_PER_ERA_MAX)
		for index in range(mini(count, pool.size())):
			selected.append(str(pool[index]))
		effect_cards_by_era[era] = selected

func _effect_card_id(effect_id: String) -> String:
	return EFFECT_CARD_PREFIX + effect_id

func _is_effect_card(card_id: String) -> bool:
	return card_id.begins_with(EFFECT_CARD_PREFIX)

func _effect_id_from_card(card_id: String) -> String:
	return card_id.substr(EFFECT_CARD_PREFIX.length())

func _effect_by_id(effect_id: String) -> Dictionary:
	for effect in RANDOM_EFFECTS:
		if str(effect.id) == effect_id:
			return effect
	return {}

func _effect_card_sort_key(card_id: String) -> int:
	var effect_id := _effect_id_from_card(card_id)
	for era_order in range(GameData.ERAS.size()):
		var era := GameData.ERAS[era_order]
		var effect_ids: Array = effect_cards_by_era.get(era, [])
		var local_index := effect_ids.find(effect_id)
		if local_index >= 0:
			return era_order * 100 + 50 + local_index
	return 9999 + maxi(_all_effect_ids().find(effect_id), 0)

func _card_texture_path(card_id: String) -> String:
	if _is_effect_card(card_id):
		var effect_path := "res://assets/cards/%s.png" % card_id
		if ResourceLoader.exists(effect_path):
			return effect_path
		return ""
	return GameData.card_texture_path(card_id)

func _ready() -> void:
	_apply_default_font()
	GameData.initialize()
	_register_effect_cards()
	coin_count = 300
	rng.randomize()
	for effect in RANDOM_EFFECTS:
		if str(effect.id) != "bounty":
			ai_effects.append(effect)
	_build_background()
	_build_top_bar()
	_build_board()
	_build_tray()
	_build_battlefield()
	_build_overlay()
	_build_main_menu()
	Updater.status_changed.connect(_on_update_status)
	Updater.update_ready.connect(_on_update_ready)
	Updater.check_for_update(false)

func _on_battlefield_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		camera_x = clampf(camera_x - event.relative.x, 0.0, WORLD_WIDTH - BATTLE_VIEW_W)
		camera_manual_timer = CAMERA_MANUAL_HOLD
		_apply_camera()

func _apply_camera() -> void:
	if world != null:
		world.position = Vector2(7.0 - camera_x, 7.0) + camera_shake_offset

func _reset_camera() -> void:
	camera_x = 0.0
	camera_manual_timer = 0.0
	_apply_camera()

func _frontline_focus_x() -> float:
	var lead := -INF
	for unit in battle_units:
		if is_instance_valid(unit) and unit.alive and unit.faction == "ally":
			lead = maxf(lead, unit.position.x)
	if lead != -INF:
		return lead
	var nearest := INF
	for unit in battle_units:
		if is_instance_valid(unit) and unit.alive and unit.faction == "enemy":
			nearest = minf(nearest, unit.position.x)
	if nearest != INF:
		return nearest
	return ALLY_TOWER_X + BATTLE_VIEW_W * 0.5

func _update_camera_follow(delta: float) -> void:
	if world == null:
		return
	if camera_manual_timer > 0.0:
		camera_manual_timer = maxf(0.0, camera_manual_timer - delta)
		return
	var target := clampf(_frontline_focus_x() - BATTLE_VIEW_W * 0.5, 0.0, WORLD_WIDTH - BATTLE_VIEW_W)
	camera_x = lerpf(camera_x, target, clampf(delta * CAMERA_FOLLOW_SPEED, 0.0, 1.0))
	_apply_camera()

func _set_camera_shake(offset: Vector2) -> void:
	camera_shake_offset = offset
	_apply_camera()

func _shake_battlefield() -> void:
	if camera_shake_tween != null:
		camera_shake_tween.kill()
	_set_camera_shake(Vector2.ZERO)
	var first_offset := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0))
	var second_offset := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-2.0, 2.0))
	var third_offset := Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.5, 1.5))
	camera_shake_tween = create_tween()
	camera_shake_tween.tween_method(
		_set_camera_shake,
		Vector2.ZERO,
		first_offset,
		0.04
	)
	camera_shake_tween.tween_method(
		_set_camera_shake,
		first_offset,
		second_offset,
		0.04
	)
	camera_shake_tween.tween_method(_set_camera_shake, second_offset, third_offset, 0.04)
	camera_shake_tween.tween_method(_set_camera_shake, third_offset, Vector2.ZERO, 0.06)

func _update_minimap() -> void:
	if minimap == null:
		return
	var dots: Array = []
	for unit in battle_units:
		if is_instance_valid(unit) and unit.alive:
			var color := Color("#5fb7ff") if unit.faction == "ally" else Color("#ff5555")
			dots.append({"x": unit.position.x, "color": color})
	var towers := [
		{"x": ALLY_TOWER_X, "color": Color("#7fe0a0")},
		{"x": ENEMY_TOWER_X, "color": Color("#ffb066")},
	]
	minimap.update_map(dots, towers, camera_x)

func _process(delta: float) -> void:
	if paused:
		return
	_update_minimap()
	if not battle_active or battle_ended:
		return
	fx_unit_count_cache = _living_units("ally").size() + _living_units("enemy").size()
	_tick_buffs(delta)
	_sync_persistent_status_vfx(delta)
	_update_tower_alarm_vfx(delta)
	_update_wave_bar()
	if wave_spawning:
		wave_active_timer -= delta
		if wave_active_timer <= 0.0:
			wave_spawning = false
		else:
			enemy_spawn_timer -= delta
			if enemy_spawn_timer <= 0.0 and _living_units("enemy").size() < _wave_field_target() and _living_units("enemy").size() < ENEMY_UNIT_CAP:
				_spawn_one_enemy()
				enemy_spawn_timer = SPAWN_STAGGER
	wave_min_timer -= delta
	enemy_coin += float(_diff().ai_trickle) * KILL_COIN_MULT * delta
	enemy_effect_cd = maxf(0.0, enemy_effect_cd - delta)
	if enemy_tower_max_hp > 0.0 and enemy_tower_hp > 0.0:
		var target_crossed := 0
		for t in [0.8, 0.6, 0.4, 0.2]:
			if enemy_tower_hp <= enemy_tower_max_hp * float(t):
				target_crossed += 1
		if target_crossed > enemy_rally_fired:
			_enemy_rally_surge()
			enemy_rally_fired += 1
		elif target_crossed < enemy_rally_fired:
			enemy_rally_fired = target_crossed
	var cleared := not wave_spawning and _living_units("enemy").is_empty()
	if prep_pending:
		if cleared:
			_enter_preparation()
			return
	else:
		if cleared and wave_min_timer <= 0.0:
			_spawn_wave()
			wave_min_timer = _diff().wave_min
	_step_battle(delta)
	_update_camera_follow(delta)
	_update_tower_ui()

func _update_tower_alarm_vfx(delta: float) -> void:
	var ally_active := ally_tower_max_hp > 0.0 and ally_tower_hp / ally_tower_max_hp <= 0.25
	var enemy_active := enemy_tower_max_hp > 0.0 and enemy_tower_hp / enemy_tower_max_hp <= 0.25
	for entry in [
		{"node": ally_tower_alarm_vfx, "tower": ally_tower_sprite, "active": ally_active, "phase": 0.0},
		{"node": enemy_tower_alarm_vfx, "tower": enemy_tower_sprite, "active": enemy_active, "phase": 1.7},
	]:
		var node: Node2D = entry.node
		if node == null:
			continue
		node.visible = bool(entry.active)
		if not node.visible:
			continue
		var phase := Time.get_ticks_msec() * 0.003 + float(entry.phase)
		node.modulate.a = 0.92 + sin(phase) * 0.06
		node.position = _tower_alarm_anchor(entry.tower)
		for index in range(3):
			var puff := node.get_node_or_null("SmokePuff%d" % index) as Polygon2D
			if puff == null:
				continue
			var puff_phase := phase * (0.72 + index * 0.08) + index * 1.9
			var rise := fmod(puff_phase, TAU) / TAU
			puff.position = Vector2(
				(index - 1) * 7.0 + sin(puff_phase) * (3.0 + index),
				-3.0 - index * 15.0 - rise * 5.0
			)
			puff.scale = Vector2.ONE * (0.78 + index * 0.14 + rise * 0.24)
			puff.modulate.a = 0.78 - rise * 0.42
		for index in range(4):
			var ember := node.get_node_or_null("AlarmEmber%d" % index) as Polygon2D
			if ember == null:
				continue
			var ember_phase := phase * (1.1 + index * 0.13) + index * 1.7
			var ember_rise := fmod(ember_phase, TAU) / TAU
			ember.position = Vector2(
				(index - 1.5) * 6.0 + sin(ember_phase * 1.4) * 4.0,
				-4.0 - ember_rise * 38.0
			)
			ember.scale = Vector2.ONE * (0.72 + (1.0 - ember_rise) * 0.42)
			ember.modulate.a = (1.0 - ember_rise) * (0.45 + maxf(0.0, sin(ember_phase * 2.0)) * 0.55)

func _tower_alarm_anchor(tower: Sprite2D) -> Vector2:
	if tower == null or tower.texture == null:
		return Vector2(ALLY_TOWER_X if tower == ally_tower_sprite else ENEMY_TOWER_X, BATTLE_GROUND_Y - TOWER_HEIGHT)
	var image := tower.texture.get_image()
	var used := image.get_used_rect()
	var local_center_x := (float(used.position.x) + float(used.size.x) * 0.5 - float(image.get_width()) * 0.5) * tower.scale.x
	var local_top := (float(used.position.y) - float(image.get_height()) * 0.5) * tower.scale.y
	return tower.position + Vector2(local_center_x, local_top + 2.0)

func _panel_style(color: Color, border := Color("#70412c"), radius := 20, width := 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.16, 0.08, 0.04, 0.28)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	return style

func _label(parent: Node, text: String, position: Vector2, size: Vector2, font_size: int, color := Color("#fff0c7")) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _rich_label(parent: Node, position: Vector2, size: Vector2, font_size: int, color: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.position = position
	label.size = size
	label.bbcode_enabled = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	parent.add_child(label)
	return label

func _apply_default_font() -> void:
	var font_path := "res://assets/fonts/ui_cjk.ttf"
	if ResourceLoader.exists(font_path):
		var font := load(font_path)
		if font is Font:
			ThemeDB.fallback_font = font

func _build_background() -> void:
	var background := ColorRect.new()
	background.size = VIEW_SIZE
	background.color = Color("#5c3826")
	add_child(background)
	var wash := ColorRect.new()
	wash.position = Vector2(14, 14)
	wash.size = Vector2(692, 1252)
	wash.color = Color("#d69a60")
	add_child(wash)

func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.position = Vector2(30, 30)
	bar.size = Vector2(660, 70)
	bar.add_theme_stylebox_override("panel", _panel_style(Color("#a75d38"), Color("#633822"), 19, 3))
	add_child(bar)
	return_button = Button.new()
	return_button.position = Vector2(12, 12)
	return_button.size = Vector2(46, 46)
	return_button.text = "≡"
	return_button.tooltip_text = "主界面"
	return_button.add_theme_font_size_override("font_size", 24)
	return_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 12, 2))
	return_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 12, 2))
	return_button.pressed.connect(_show_main_menu)
	return_button.pressed.connect(_play_button_sfx)
	bar.add_child(return_button)
	pause_button = Button.new()
	pause_button.position = Vector2(540, 12)
	pause_button.size = Vector2(46, 46)
	pause_button.text = "⏸"
	pause_button.tooltip_text = "暂停"
	pause_button.add_theme_font_size_override("font_size", 20)
	pause_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 12, 2))
	pause_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 12, 2))
	pause_button.pressed.connect(_toggle_pause)
	pause_button.pressed.connect(_play_button_sfx)
	pause_button.visible = false
	bar.add_child(pause_button)
	help_button = Button.new()
	help_button.position = Vector2(596, 12)
	help_button.size = Vector2(46, 46)
	help_button.text = "?"
	help_button.tooltip_text = "玩法介绍"
	help_button.add_theme_font_size_override("font_size", 22)
	help_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 12, 2))
	help_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 12, 2))
	help_button.pressed.connect(_show_tutorial)
	help_button.pressed.connect(_play_button_sfx)
	bar.add_child(help_button)
	_label(bar, "🪨 牌桌远征", Vector2(68, 5), Vector2(205, 30), 21)
	era_label = _label(bar, "", Vector2(70, 38), Vector2(220, 20), 12, Color("#f6d69f"))
	coin_label = _label(bar, "", Vector2(350, 8), Vector2(165, 28), 16, Color("#fff0c7"))
	score_label = _label(bar, "", Vector2(350, 37), Vector2(175, 22), 12, Color("#ffe3a5"))
	_update_progress_ui()
	_update_coin_ui()

func _update_coin_ui() -> void:
	if coin_label != null:
		coin_label.text = "💰  %d" % coin_count

func _build_board() -> void:
	board = Panel.new()
	board.position = BOARD_RECT.position
	board.size = BOARD_RECT.size
	board.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	add_child(board)
	var bg := TextureRect.new()
	bg.position = Vector2(8, 8)
	bg.size = BOARD_RECT.size - Vector2(16, 16)
	bg.texture = load("res://assets/bg_board.png")
	board_bg = bg
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(bg)
	board_bg_fade = _make_fade_twin(bg)
	board.add_child(board_bg_fade)
	_label(board, "🃏 牌堆", Vector2(20, 10), Vector2(150, 30), 20)
	deck_label = _label(board, "", Vector2(150, 8), Vector2(200, 34), 24, Color("#ffe9a8"))
	_outline(deck_label, 6)
	_label(board, "点击没有被压住的卡牌", Vector2(22, 44), Vector2(230, 23), 12, Color("#6e452f"))
	_build_wave_bar()
	card_layer = Control.new()
	card_layer.position = Vector2(26, 80)
	card_layer.size = Vector2(596, 526)
	card_layer.clip_contents = false
	card_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	card_layer.gui_input.connect(_on_card_layer_input)
	board.add_child(card_layer)

func _build_tray() -> void:
	tray = Panel.new()
	tray.position = TRAY_RECT.position
	tray.size = TRAY_RECT.size
	tray.add_theme_stylebox_override("panel", _panel_style(Color("#e7bd76"), Color("#70412c"), 20, 3))
	add_child(tray)
	_label(tray, "✨ 合成台", Vector2(18, 9), Vector2(150, 28), 19)
	_label(tray, "小兵 3 张合成 · 效果 2 张发动", Vector2(168, 13), Vector2(330, 22), 12, Color("#765035"))
	for index in range(7):
		var slot := Panel.new()
		slot.position = TRAY_SLOT_ORIGIN + Vector2(index * TRAY_SLOT_STEP, 0)
		slot.size = TRAY_SLOT_SIZE
		slot.add_theme_stylebox_override("panel", _panel_style(Color("#aa7044", 0.25), Color("#a66e43"), 12, 2))
		tray.add_child(slot)

func _build_battlefield() -> void:
	battlefield = Panel.new()
	battlefield.position = BATTLE_RECT.position
	battlefield.size = BATTLE_RECT.size
	battlefield.add_theme_stylebox_override("panel", _panel_style(Color("#8d5d3f"), Color("#70412c"), 22, 3))
	battlefield.clip_contents = true
	battlefield.gui_input.connect(_on_battlefield_input)
	add_child(battlefield)
	world = Control.new()
	world.position = Vector2(7, 7)
	world.size = Vector2(WORLD_WIDTH, BATTLE_RECT.size.y - 14)
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battlefield.add_child(world)
	battle_bg = TextureRect.new()
	battle_bg.position = Vector2.ZERO
	battle_bg.size = Vector2(WORLD_WIDTH, BATTLE_RECT.size.y - 14)
	battle_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battle_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	battle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(battle_bg)
	battle_bg_fade = _make_fade_twin(battle_bg)
	world.add_child(battle_bg_fade)
	fx_manager = FxManager.new()
	fx_manager.name = "FxManager"
	world.add_child(fx_manager)
	fx_manager.setup(Callable(self, "_fx_unit_count"))
	ally_tower_shadow = _create_tower_shadow(true)
	enemy_tower_shadow = _create_tower_shadow(false)
	ally_tower_sprite = _create_tower_sprite(true)
	enemy_tower_sprite = _create_tower_sprite(false)
	ally_tower_aura = _create_tower_aura(true)
	enemy_tower_aura = _create_tower_aura(false)
	ally_tower_alarm_vfx = _create_tower_alarm_vfx(true)
	enemy_tower_alarm_vfx = _create_tower_alarm_vfx(false)
	battle_hint = _label(battlefield, "拖动战场查看双方阵地", Vector2(16, 18), Vector2(300, 22), 12, Color("#f9deb0"))
	buff_label = _rich_label(battlefield, Vector2(16, 36), Vector2(440, 66), 12, Color("#ffd98a"))
	buff_label.fit_content = true
	buff_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	buff_label.clip_contents = true
	enemy_buff_label = _rich_label(battlefield, Vector2(330, 54), Vector2(310, 48), 12, Color("#ff9a7a"))
	enemy_buff_label.fit_content = true
	enemy_buff_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	enemy_buff_label.clip_contents = true
	enemy_action_label = _label(battlefield, " ", Vector2(180, 8), Vector2(270, 24), 15, Color("#ff7a5c"))
	enemy_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_action_label.z_index = 20
	enemy_action_label.modulate.a = 0.0
	boss_entry_overlay = Control.new()
	boss_entry_overlay.position = BATTLE_RECT.position
	boss_entry_overlay.size = BATTLE_RECT.size
	boss_entry_overlay.z_index = 100
	boss_entry_overlay.clip_contents = true
	boss_entry_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_entry_overlay)
	boss_entry_banner = _label(boss_entry_overlay, "", Vector2(174, 244), Vector2(300, 48), 25, Color("#ffe3a0"))
	boss_entry_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_entry_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_entry_banner.z_index = 1
	boss_entry_banner.pivot_offset = boss_entry_banner.size * 0.5
	boss_entry_banner.add_theme_color_override("font_outline_color", Color("#24150f"))
	boss_entry_banner.add_theme_constant_override("outline_size", 9)
	boss_entry_overlay.visible = false
	minimap = BattleMinimap.new()
	minimap.position = Vector2(462, 8)
	minimap.size = Vector2(176, 46)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.configure(WORLD_WIDTH, BATTLE_VIEW_W)
	battlefield.add_child(minimap)
	_create_tower_ui(true)
	_create_tower_ui(false)
	_apply_camera()

func _fx_unit_count() -> int:
	return fx_unit_count_cache

func _create_tower_alarm_vfx(ally: bool) -> Node2D:
	var root := Node2D.new()
	root.name = "AllyTowerAlarmVfx" if ally else "EnemyTowerAlarmVfx"
	root.position = Vector2(ALLY_TOWER_X if ally else ENEMY_TOWER_X, BATTLE_GROUND_Y - TOWER_HEIGHT + 2.0)
	root.z_index = 5
	root.visible = false
	for index in range(3):
		var puff := Polygon2D.new()
		var points := PackedVector2Array()
		for point_index in range(11):
			var angle := TAU * float(point_index) / 11.0
			points.append(Vector2(cos(angle), sin(angle)) * (11.0 + index * 4.0))
		puff.polygon = points
		puff.name = "SmokePuff%d" % index
		puff.color = Color(0.38, 0.37, 0.35, 0.72)
		root.add_child(puff)
	for index in range(4):
		var ember := Polygon2D.new()
		var ember_points := PackedVector2Array()
		for point_index in range(8):
			var angle := TAU * float(point_index) / 8.0
			ember_points.append(Vector2(cos(angle), sin(angle)) * 2.8)
		ember.name = "AlarmEmber%d" % index
		ember.polygon = ember_points
		ember.color = Color("#ffd78c")
		root.add_child(ember)
	world.add_child(root)
	return root

func _create_tower_sprite(ally: bool) -> Sprite2D:
	var tower := Sprite2D.new()
	tower.position = Vector2(
		ALLY_TOWER_X if ally else ENEMY_TOWER_X,
		BATTLE_GROUND_Y - TOWER_HEIGHT * 0.5 + TOWER_GROUND_NUDGE
	)
	tower.z_index = 1
	tower.flip_h = not ally
	world.add_child(tower)
	return tower

func _create_tower_shadow(ally: bool) -> Sprite2D:
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/fx/shadow.png")
	shadow.position = Vector2(ALLY_TOWER_X if ally else ENEMY_TOWER_X, BATTLE_GROUND_Y)
	shadow.scale = Vector2(0.45, 0.4)
	shadow.z_index = 0
	world.add_child(shadow)
	return shadow

func _create_tower_aura(ally: bool) -> Line2D:
	var aura := Line2D.new()
	aura.name = "AllyTowerAura" if ally else "EnemyTowerAura"
	aura.closed = true
	aura.width = 5.0
	aura.antialiased = true
	aura.points = _tower_aura_points()
	aura.position = Vector2(ALLY_TOWER_X if ally else ENEMY_TOWER_X, BATTLE_GROUND_Y)
	aura.z_index = 1
	aura.default_color = _effect_color("tower_power", "ally" if ally else "enemy")
	aura.visible = false
	world.add_child(aura)
	return aura

func _tower_aura_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(Vector2(cos(angle) * 62.0, sin(angle) * 20.0))
	return points

## 背景交叉淡入的时长（时代切换要缓缓过渡，不能一下子跳）
const ERA_FADE_TIME := 1.6
const ERA_TOWER_FADE_TIME := 0.5

func _make_fade_twin(source: TextureRect) -> TextureRect:
	# 与背景同位同尺寸的副本，切时代时贴旧图再慢慢淡出，形成交叉淡入
	var twin := TextureRect.new()
	twin.position = source.position
	twin.size = source.size
	twin.expand_mode = source.expand_mode
	twin.stretch_mode = source.stretch_mode
	twin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	twin.visible = false
	return twin

func _refresh_era_visuals(animate := false) -> void:
	if era_visual_tween != null:
		era_visual_tween.kill()
	if not animate:
		if battle_bg_fade != null:
			battle_bg_fade.visible = false
		if board_bg_fade != null:
			board_bg_fade.visible = false
		_apply_era_visuals()
		return
	var towers: Array[CanvasItem] = [
		ally_tower_sprite,
		enemy_tower_sprite,
		ally_tower_shadow,
		enemy_tower_shadow,
	]
	for pair in [[battle_bg, battle_bg_fade], [board_bg, board_bg_fade]]:
		var source: TextureRect = pair[0]
		var twin: TextureRect = pair[1]
		if source == null or twin == null:
			continue
		twin.texture = source.texture
		twin.modulate = Color.WHITE
		twin.visible = true
	_apply_era_visuals()
	for tower in towers:
		tower.modulate.a = 0.0
	era_visual_tween = create_tween()
	era_visual_tween.set_parallel(true)
	era_visual_tween.set_trans(Tween.TRANS_SINE)
	for twin in [battle_bg_fade, board_bg_fade]:
		if twin != null:
			era_visual_tween.tween_property(twin, "modulate:a", 0.0, ERA_FADE_TIME)
	for tower in towers:
		era_visual_tween.tween_property(tower, "modulate:a", 1.0, ERA_TOWER_FADE_TIME).set_delay(ERA_FADE_TIME * 0.35)
	era_visual_tween.chain().tween_callback(func() -> void:
		for twin in [battle_bg_fade, board_bg_fade]:
			if twin != null:
				twin.visible = false
	)

func _apply_era_visuals() -> void:
	var bg_path := "res://assets/bg_battle_%s.png" % current_era
	if not ResourceLoader.exists(bg_path):
		bg_path = "res://assets/bg_battle_stone.png"
	battle_bg.texture = load(bg_path)
	if board_bg != null:
		var board_path := "res://assets/bg_board_%s.png" % current_era
		if not ResourceLoader.exists(board_path):
			board_path = "res://assets/bg_board.png"
		board_bg.texture = load(board_path)
	for tower_data in [
		{"tower": ally_tower_sprite, "era": current_era},
		{"tower": enemy_tower_sprite, "era": enemy_era},
	]:
		var tower: Sprite2D = tower_data["tower"]
		var era := str(tower_data["era"])
		var tower_path := "res://assets/towers/%s.png" % era
		if not ResourceLoader.exists(tower_path):
			tower_path = "res://assets/towers/stone.png"
		tower.texture = load(tower_path)
		var factor := TOWER_HEIGHT / maxf(1.0, float(tower.texture.get_height()))
		tower.scale = Vector2(factor, factor)
		tower.modulate = ERA_TOWER_TINTS.get(era, ERA_TOWER_TINTS.stone)
	_sync_tower_shadow(ally_tower_sprite, ally_tower_shadow)
	_sync_tower_shadow(enemy_tower_sprite, enemy_tower_shadow)
	battle_bg.modulate = Color.WHITE
	ally_tower_shadow.modulate = Color.WHITE
	enemy_tower_shadow.modulate = Color.WHITE

func _sync_tower_shadow(tower: Sprite2D, shadow: Sprite2D) -> void:
	shadow.position = Vector2(tower.position.x, BATTLE_GROUND_Y)
	var footprint := float(tower.texture.get_width()) * tower.scale.x
	shadow.scale = Vector2(clampf(footprint / 256.0 * 1.15, 0.32, 0.7), 0.4)

func _create_tower_ui(ally: bool) -> void:
	var bar := TowerHealthBar.new()
	bar.position = Vector2(
		ALLY_TOWER_X if ally else ENEMY_TOWER_X,
		BATTLE_GROUND_Y - TOWER_HEIGHT - 12.0
	)
	bar.bar_color = Color("#7fd65e") if ally else Color("#ef6a4f")
	bar.z_index = 5
	world.add_child(bar)
	if ally:
		ally_tower_bar = bar
	else:
		enemy_tower_bar = bar

func _build_overlay() -> void:
	result_overlay = Control.new()
	result_overlay.size = VIEW_SIZE
	result_overlay.z_index = 4050
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.visible = false
	add_child(result_overlay)
	var dim := ColorRect.new()
	dim.size = VIEW_SIZE
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.add_child(dim)
	var panel := Panel.new()
	panel.size = Vector2(540, 330)
	panel.position = (VIEW_SIZE - panel.size) / 2.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	result_overlay.add_child(panel)
	status_label = _label(panel, "", Vector2(30, 40), Vector2(480, 140), 24, Color("#fff2c4"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	restart_button = Button.new()
	restart_button.position = Vector2((panel.size.x - 200) / 2.0, 196)
	restart_button.size = Vector2(200, 54)
	restart_button.text = "重新开始"
	restart_button.add_theme_font_size_override("font_size", 19)
	restart_button.add_theme_stylebox_override("normal", _panel_style(Color("#d77a3d"), Color("#6d3724"), 15, 3))
	restart_button.add_theme_stylebox_override("hover", _panel_style(Color("#ec994d"), Color("#6d3724"), 15, 3))
	restart_button.pressed.connect(_start_round)
	restart_button.pressed.connect(_play_button_sfx)
	panel.add_child(restart_button)
	result_menu_button = Button.new()
	result_menu_button.position = Vector2((panel.size.x - 200) / 2.0, 260)
	result_menu_button.size = Vector2(200, 50)
	result_menu_button.text = "返回主界面"
	result_menu_button.add_theme_font_size_override("font_size", 17)
	result_menu_button.add_theme_stylebox_override("normal", _panel_style(Color("#a75d38"), Color("#6d3724"), 15, 3))
	result_menu_button.add_theme_stylebox_override("hover", _panel_style(Color("#c87845"), Color("#6d3724"), 15, 3))
	result_menu_button.pressed.connect(_show_main_menu)
	result_menu_button.pressed.connect(_play_button_sfx)
	panel.add_child(result_menu_button)
	_build_pause_overlay()
	_build_tutorial_overlay()
	_build_card_info_overlay()

func _build_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.size = VIEW_SIZE
	pause_overlay.z_index = 4000
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.visible = false
	add_child(pause_overlay)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color(0.05, 0.03, 0.02, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(130, 136)
	panel.size = Vector2(460, 280)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	pause_overlay.add_child(panel)
	pause_title_label = _label(panel, "整备时间", Vector2(0, 30), Vector2(460, 46), 30)
	pause_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint_label = _label(panel, "战斗、出兵和牌堆均已冻结", Vector2(0, 92), Vector2(460, 28), 16, Color("#ffe3a5"))
	pause_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_top_button = _menu_button(panel, "", Vector2(130, 140), Vector2(200, 58), 20)
	pause_top_button.pressed.connect(_on_pause_top_pressed)
	pause_bottom_button = _menu_button(panel, "确认再战", Vector2(130, 214), Vector2(200, 58), 20)
	pause_bottom_button.pressed.connect(_on_pause_bottom_pressed)
	_configure_pause("prep")

func _build_tutorial_overlay() -> void:
	tutorial_overlay = Control.new()
	tutorial_overlay.size = VIEW_SIZE
	tutorial_overlay.z_index = 4090
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.visible = false
	add_child(tutorial_overlay)
	tutorial_dims.clear()
	for _i in range(4):
		var dim := ColorRect.new()
		dim.color = Color(0.05, 0.03, 0.02, 0.72)
		tutorial_overlay.add_child(dim)
		tutorial_dims.append(dim)
	tutorial_focus = Panel.new()
	tutorial_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_focus.add_theme_stylebox_override("panel", _panel_style(Color(1, 1, 1, 0.0), Color("#ffd07a"), 18, 4))
	tutorial_overlay.add_child(tutorial_focus)
	tutorial_card = Panel.new()
	tutorial_card.size = Vector2(612, 330)
	tutorial_card.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	tutorial_overlay.add_child(tutorial_card)
	tutorial_title_label = _label(tutorial_card, "", Vector2(0, 24), Vector2(612, 40), 26)
	tutorial_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_text_label = RichTextLabel.new()
	tutorial_text_label.bbcode_enabled = true
	tutorial_text_label.scroll_active = false
	tutorial_text_label.position = Vector2(42, 74)
	tutorial_text_label.size = Vector2(528, 160)
	tutorial_text_label.add_theme_font_size_override("normal_font_size", 18)
	tutorial_text_label.add_theme_color_override("default_color", Color("#fff0c7"))
	tutorial_card.add_child(tutorial_text_label)
	tutorial_step_label = _label(tutorial_card, "", Vector2(0, 240), Vector2(612, 22), 13, Color("#e6c199"))
	tutorial_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_prev_button = _menu_button(tutorial_card, "上一步", Vector2(42, 262), Vector2(150, 50), 17)
	tutorial_prev_button.pressed.connect(_tutorial_prev)
	tutorial_skip_button = _menu_button(tutorial_card, "跳过", Vector2(232, 262), Vector2(120, 50), 17)
	tutorial_skip_button.pressed.connect(_hide_tutorial)
	tutorial_next_button = _menu_button(tutorial_card, "下一步", Vector2(392, 262), Vector2(178, 50), 17)
	tutorial_next_button.pressed.connect(_tutorial_next)

func _tutorial_next() -> void:
	_play_button_sfx()
	if tutorial_step >= TUTORIAL_STEPS.size() - 1:
		_hide_tutorial()
		return
	tutorial_step += 1
	_refresh_tutorial_step()

func _tutorial_prev() -> void:
	_play_button_sfx()
	if tutorial_step <= 0:
		return
	tutorial_step -= 1
	_refresh_tutorial_step()

func _refresh_tutorial_step() -> void:
	var step: Dictionary = TUTORIAL_STEPS[tutorial_step]
	tutorial_title_label.text = str(step.get("title", ""))
	tutorial_text_label.text = str(step.get("text", ""))
	tutorial_step_label.text = "%d / %d" % [tutorial_step + 1, TUTORIAL_STEPS.size()]
	tutorial_prev_button.disabled = tutorial_step == 0
	tutorial_next_button.text = "开始游戏" if tutorial_step == TUTORIAL_STEPS.size() - 1 else "下一步"
	var focus_rect: Rect2 = step.get("rect", Rect2())
	_layout_tutorial_focus(focus_rect)

func _layout_tutorial_focus(focus_rect: Rect2) -> void:
	var has_focus := focus_rect.size.x > 0.0 and focus_rect.size.y > 0.0
	tutorial_focus.visible = has_focus
	if has_focus:
		var pad := 8.0
		tutorial_focus.position = focus_rect.position - Vector2(pad, pad)
		tutorial_focus.size = focus_rect.size + Vector2(pad, pad) * 2.0
		# 四块遮罩拼出中间的镟空
		var hole := Rect2(tutorial_focus.position, tutorial_focus.size)
		_set_dim(0, Rect2(0, 0, VIEW_SIZE.x, hole.position.y))
		_set_dim(1, Rect2(0, hole.end.y, VIEW_SIZE.x, VIEW_SIZE.y - hole.end.y))
		_set_dim(2, Rect2(0, hole.position.y, hole.position.x, hole.size.y))
		_set_dim(3, Rect2(hole.end.x, hole.position.y, VIEW_SIZE.x - hole.end.x, hole.size.y))
		var below := hole.end.y + 20.0
		if below + tutorial_card.size.y <= VIEW_SIZE.y - 20.0:
			tutorial_card.position = Vector2(54, below)
		else:
			tutorial_card.position = Vector2(54, max(20.0, hole.position.y - tutorial_card.size.y - 20.0))
	else:
		_set_dim(0, Rect2(0, 0, VIEW_SIZE.x, VIEW_SIZE.y))
		for index in range(1, 4):
			_set_dim(index, Rect2())
		tutorial_card.position = Vector2(54, (VIEW_SIZE.y - tutorial_card.size.y) * 0.5)

func _set_dim(index: int, rect: Rect2) -> void:
	var dim := tutorial_dims[index]
	dim.position = rect.position
	dim.size = rect.size
	dim.visible = rect.size.x > 0.0 and rect.size.y > 0.0

func _toggle_pause() -> void:
	if not battle_active or battle_ended:
		return
	paused = not paused
	if not paused:
		auto_prep = false
		_check_stuck()
		if battle_ended:
			return
		AudioManager.set_music_filtered(false)
	elif not auto_prep:
		_configure_pause("prep")
		_set_pause_text("整备时间", "战斗、出兵和牌堆均已冻结")
		AudioManager.set_music_filtered(true)
	if pause_overlay != null:
		pause_overlay.visible = paused
	_update_progress_ui()

func _enter_preparation() -> void:
	prep_pending = false
	auto_prep = true
	paused = true
	wave_spawning = false
	wave_active_timer = 0.0
	wave_boss_pending = false
	enemy_spawn_timer = 0.0
	enemy_spawn_index = 0
	wave_min_timer = _diff().wave_min
	_configure_pause("prep")
	_set_pause_text(
		"第 %d 波结束 · 自动整备" % wave_number,
		"每 %d 波自动整备一次，可继续取牌合成" % PREP_WAVE_INTERVAL
	)
	if pause_overlay != null:
		pause_overlay.visible = true
	AudioManager.set_music_filtered(true)
	AudioManager.play_sfx("era")
	_update_progress_ui()

func _set_pause_text(title: String, hint: String) -> void:
	if pause_title_label != null:
		pause_title_label.text = title
	if pause_hint_label != null:
		pause_hint_label.text = hint

func _configure_pause(mode: String) -> void:
	pause_mode = mode
	if pause_top_button == null or pause_bottom_button == null:
		return
	if mode == "clear_confirm":
		pause_top_button.visible = true
		pause_top_button.text = "扣 %d 金币清理并继续" % CLEAR_TRAY_COST
		pause_bottom_button.text = "返回主界面"
	else:
		pause_top_button.visible = false
		pause_bottom_button.text = "确认再战"

func _on_pause_top_pressed() -> void:
	_play_button_sfx()
	if pause_mode == "clear_confirm":
		_confirm_clear_tray()

func _on_pause_bottom_pressed() -> void:
	_play_button_sfx()
	if pause_mode == "clear_confirm":
		_show_main_menu()
	else:
		_toggle_pause()

func _show_tutorial() -> void:
	if tutorial_overlay != null and tutorial_overlay.visible:
		return
	tutorial_resume_paused = paused
	paused = true
	AudioManager.set_music_filtered(true)
	# 教程要高亮真实的牌堆/合成台/战场，从主菜单打开时先把菜单收起来
	tutorial_hid_menu = main_menu != null and main_menu.visible
	if tutorial_hid_menu:
		main_menu.visible = false
	if tutorial_overlay != null:
		move_child(tutorial_overlay, get_child_count() - 1)
		tutorial_step = 0
		_refresh_tutorial_step()
		tutorial_overlay.visible = true

func _hide_tutorial() -> void:
	if tutorial_overlay != null:
		tutorial_overlay.visible = false
	SaveManager.set_tutorial_seen(true)
	AudioManager.set_music_filtered(false)
	if tutorial_hid_menu and main_menu != null:
		main_menu.visible = true
	tutorial_hid_menu = false
	paused = tutorial_resume_paused
	tutorial_resume_paused = false

func _build_main_menu() -> void:
	main_menu = Control.new()
	main_menu.name = "MainMenu"
	main_menu.size = VIEW_SIZE
	main_menu.z_index = 3800
	main_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(main_menu)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color("#2a1710")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	main_menu.add_child(shade)
	var bg := TextureRect.new()
	bg.size = VIEW_SIZE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/bg_menu.png"):
		bg.texture = load("res://assets/bg_menu.png")
	main_menu.add_child(bg)
	var vignette := ColorRect.new()
	vignette.size = VIEW_SIZE
	vignette.color = Color(0.05, 0.03, 0.02, 0.28)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_menu.add_child(vignette)
	var card := Panel.new()
	card.position = Vector2(66, 170)
	card.size = Vector2(588, 900)
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.17, 0.09, 0.06, 0.55), Color(0.55, 0.32, 0.18, 0.9), 30, 4))
	main_menu.add_child(card)
	var title := _label(card, "牌桌远征", Vector2(0, 105), Vector2(588, 70), 44, Color("#fff0c7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(card, "Deck & Merge", Vector2(0, 176), Vector2(588, 34), 21, Color("#f2ca92"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tagline := _label(card, "从石器时代开始，守护你的牌桌", Vector2(0, 230), Vector2(588, 28), 14, Color("#e6c199"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var start_button := _menu_button(card, "开始游戏", Vector2(144, 330), Vector2(300, 68), 24)
	start_button.pressed.connect(_enter_game)
	var solo_button := _menu_button(card, "单机闯关", Vector2(144, 430), Vector2(300, 56), 19)
	solo_button.pressed.connect(_show_era_select)
	var online_button := _menu_button(card, "联机匹配", Vector2(144, 508), Vector2(300, 56), 19)
	online_button.disabled = true
	online_button.tooltip_text = "敬请期待"
	var soon := _label(card, "敬请期待", Vector2(458, 522), Vector2(94, 24), 12, Color("#e6c199"))
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var settings_button := _menu_button(card, "设置", Vector2(144, 586), Vector2(300, 56), 19)
	settings_button.pressed.connect(_show_settings)
	var menu_help_button := _menu_button(card, "玩法介绍", Vector2(388, 34), Vector2(160, 50), 17)
	menu_help_button.pressed.connect(_show_tutorial)
	var difficulty_label := _label(card, "难度", Vector2(0, 650), Vector2(588, 26), 15, Color("#fff0c7"))
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var difficulty_keys := ["easy", "normal", "hard"]
	var difficulty_x_positions := [150, 250, 350]
	for index in range(difficulty_keys.size()):
		var key: String = difficulty_keys[index]
		var button := _menu_button(card, DIFFICULTIES[key].name, Vector2(difficulty_x_positions[index], 684), Vector2(92, 46), 15)
		button.pressed.connect(_set_difficulty.bind(key))
		difficulty_buttons[key] = button
	_set_difficulty("normal")
	_label(card, "点击开始，自动进入战斗", Vector2(0, 746), Vector2(588, 28), 14, Color("#e6c199")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var check_update_button := _menu_button(card, "检查更新", Vector2(194, 792), Vector2(200, 44), 16)
	check_update_button.pressed.connect(_on_check_update_pressed)
	var version_label := _label(card, "内容版本 v%d" % Updater.installed_version, Vector2(0, 842), Vector2(588, 18), 12, Color("#e6c199"))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_status_label = _label(card, "", Vector2(0, 862), Vector2(588, 18), 12, Color("#ffe3a5"))
	update_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_settings_panel(card)
	_build_era_select_panel()

func _on_check_update_pressed() -> void:
	_play_button_sfx()
	Updater.check_for_update(true)

func _on_update_status(text: String) -> void:
	if update_status_label != null:
		update_status_label.text = text

func _on_update_ready(version: int, _notes: String) -> void:
	if update_status_label != null:
		update_status_label.text = "已下载 v%d，重启生效" % version

func _menu_button(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.position = position
	button.size = size
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#b86a3e"), Color("#713722"), 16, 3))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#d5864b"), Color("#713722"), 16, 3))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#8c735f"), Color("#6b5548"), 16, 3))
	button.pressed.connect(_play_button_sfx)
	parent.add_child(button)
	return button

func _set_difficulty(key: String) -> void:
	if not DIFFICULTIES.has(key):
		return
	current_difficulty = key
	for difficulty_key in difficulty_buttons:
		var button: Button = difficulty_buttons[difficulty_key]
		var selected: bool = difficulty_key == current_difficulty
		var normal_color := Color("#e0a34d") if selected else Color("#b86a3e")
		var hover_color := Color("#f0b962") if selected else Color("#d5864b")
		button.add_theme_stylebox_override("normal", _panel_style(normal_color, Color("#713722"), 16, 3))
		button.add_theme_stylebox_override("hover", _panel_style(hover_color, Color("#713722"), 16, 3))

func _build_settings_panel(parent: Control) -> void:
	settings_panel = Panel.new()
	settings_panel.position = Vector2(84, 250)
	settings_panel.size = Vector2(420, 430)
	settings_panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	settings_panel.visible = false
	parent.add_child(settings_panel)
	var title := _label(settings_panel, "设置", Vector2(0, 30), Vector2(420, 40), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(settings_panel, "音乐音量", Vector2(42, 112), Vector2(120, 28), 17, Color("#fff0c7"))
	music_slider = _volume_slider(settings_panel, Vector2(172, 112), "Music")
	_label(settings_panel, "音效音量", Vector2(42, 202), Vector2(120, 28), 17, Color("#fff0c7"))
	sfx_slider = _volume_slider(settings_panel, Vector2(172, 202), "SFX")
	var close_button := _menu_button(settings_panel, "关闭", Vector2(110, 310), Vector2(200, 54), 18)
	close_button.pressed.connect(_hide_settings)

func _play_button_sfx() -> void:
	AudioManager.play_sfx("button")

func _volume_slider(parent: Control, position: Vector2, bus_name: String) -> HSlider:
	var slider := HSlider.new()
	slider.position = position
	slider.size = Vector2(205, 32)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = SaveManager.get_volume(bus_name)
	slider.value_changed.connect(_on_volume_changed.bind(bus_name))
	parent.add_child(slider)
	return slider

func _on_volume_changed(value: float, bus_name: String) -> void:
	AudioManager.apply_volume(bus_name, value)

func _show_settings() -> void:
	if settings_panel != null:
		settings_panel.visible = true

func _hide_settings() -> void:
	if settings_panel != null:
		settings_panel.visible = false

func _era_amount(base_amount: int) -> int:
	return _era_amount_for(current_era, base_amount)

func _era_amount_for(era: String, base_amount: int) -> int:
	return maxi(1, roundi(float(base_amount) * float(GameData.ERA_MULT.get(era, 1.0))))

func _summon_reinforcement(any_era := true) -> void:
	if _living_units("ally").size() >= UNIT_CAP:
		return
	var max_era_index := GameData.ERAS.size() - 1 if any_era else era_index
	var era: String = GameData.ERAS[rng.randi_range(0, max_era_index)]
	var ids := GameData.heroes_for_era(era)
	if ids.is_empty():
		return
	var hero_id := ids[rng.randi_range(0, ids.size() - 1)]
	_spawn_ally(hero_id)
	var hero: Dictionary = GameData.HEROES.get(hero_id, {})
	battle_hint.text = "援军抵达：%s（%s）" % [str(hero.get("name", hero_id)), str(hero.get("era_name", era))]

func _apply_random_effect(effect: Dictionary, actor := "ally") -> void:
	var effect_id := str(effect.id)
	var duration := float(effect.get("duration", 0.0))
	var foe := "enemy" if actor == "ally" else "ally"
	var actor_era := current_era if actor == "ally" else enemy_era
	match effect_id:
		"reinforcement":
			if actor == "ally":
				_summon_reinforcement(true)
			else:
				var era: String = GameData.ERAS[rng.randi_range(0, enemy_era_index)]
				var ids := GameData.heroes_for_era(era)
				if not ids.is_empty():
					_spawn_enemy(ids[rng.randi_range(0, ids.size() - 1)], 0, 1)
		"boss_call":
			for hero_id in GameData.heroes_for_era(actor_era):
				if str(GameData.HEROES[hero_id].get("role", "")) == "boss":
					if actor == "ally":
						_spawn_ally(hero_id)
					else:
						_spawn_enemy(hero_id, 0, 1)
					break
		"field_aid":
			for unit in _living_units(actor):
				unit.heal(unit.max_hp * 0.4)
				_spawn_hit_fx(unit.position, Color("#8ce68c"), "＋", 0.9)
				if fx_manager != null:
					fx_manager.emit_heal(unit.position, current_era if actor == "ally" else enemy_era)
		"freeze":
			if actor == "ally":
				enemy_freeze_time = maxf(enemy_freeze_time, duration)
			else:
				ally_freeze_time = maxf(ally_freeze_time, duration)
			for unit in _living_units(foe):
				_spawn_hit_fx(unit.position, Color("#8fd8ff"), "❄")
		"tower_repair":
			if actor == "ally":
				ally_tower_hp = minf(ally_tower_hp + ally_tower_max_hp * 0.25, ally_tower_max_hp)
			else:
				enemy_tower_hp = minf(enemy_tower_hp + enemy_tower_max_hp * 0.25, enemy_tower_max_hp)
		"tower_power":
			if actor == "ally":
				tower_attack_bonus = minf(tower_attack_bonus * 1.5, TOWER_POWER_MAX)
			else:
				enemy_tower_attack_bonus = minf(enemy_tower_attack_bonus * 1.5, TOWER_POWER_MAX)
			if fx_manager != null:
				fx_manager.emit_tower_power(
					Vector2(ALLY_TOWER_X if actor == "ally" else ENEMY_TOWER_X, BATTLE_GROUND_Y - 82.0),
					current_era if actor == "ally" else enemy_era
				)
		_:
			var timers: Dictionary = buff_timers if actor == "ally" else enemy_buff_timers
			timers[effect_id] = maxf(float(timers.get(effect_id, 0.0)), duration)
	_play_effect_vfx(effect_id, _effect_position(effect_id, actor), actor)

func _announce_enemy_action(text: String, _effect_id: String) -> void:
	if enemy_action_label == null:
		return
	enemy_action_label.text = text
	enemy_action_label.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(enemy_action_label, "modulate:a", 0.0, 0.6)

func _effect_position(effect_id: String, actor: String) -> Vector2:
	if effect_id == "tower_repair" or effect_id == "tower_power":
		return Vector2(ALLY_TOWER_X if actor == "ally" else ENEMY_TOWER_X, BATTLE_GROUND_Y - 82.0)
	if effect_id == "bounty":
		if is_instance_valid(coin_label):
			return coin_label.get_global_rect().get_center()
		return Vector2(430.0, 18.0)
	var units := _living_units(actor)
	if units.is_empty():
		return Vector2(ALLY_TOWER_X if actor == "ally" else ENEMY_TOWER_X, BATTLE_GROUND_Y - 60.0)
	var center := Vector2.ZERO
	for unit in units:
		center += unit.position
	return center / float(units.size())

func _effect_color(effect_id: String, actor: String) -> Color:
	match effect_id:
		"reinforcement":
			return Color("#8fd8ff") if actor == "ally" else Color("#ff9a78")
		"boss_call":
			return Color("#ffd273") if actor == "ally" else Color("#ff6f61")
		"field_aid":
			return Color("#8ce68c")
		"freeze":
			return Color("#8fd8ff")
		"frenzy":
			return Color("#ff5964")
		"morale":
			return Color("#ffd05c")
		"bulwark":
			return Color("#9db9d9")
		"haste":
			return Color("#b78cff")
		"lifesteal":
			return Color("#e95d87")
		"thorns":
			return Color("#72c982")
		"tower_repair":
			return Color("#8ce68c")
		"tower_power":
			return Color("#ffd273")
		"bounty":
			return Color("#f5c85b")
		_:
			return Color.WHITE

func _effect_symbol(effect_id: String) -> String:
	match effect_id:
		"reinforcement":
			return "＋"
		"boss_call":
			return "◆"
		"field_aid":
			return "＋"
		"freeze":
			return "○"
		"frenzy":
			return "△"
		"morale":
			return "★"
		"bulwark":
			return "□"
		"haste":
			return "→"
		"lifesteal":
			return "●"
		"thorns":
			return "※"
		"tower_repair":
			return "＋"
		"tower_power":
			return "◎"
		"bounty":
			return "¤"
		_:
			return "◆"

func _effect_sfx(effect_id: String) -> String:
	match effect_id:
		"reinforcement", "boss_call", "freeze":
			return "era"
		"tower_power":
			return "tower"
		_:
			return "merge"

func _play_effect_vfx(effect_id: String, position: Vector2, actor := "ally") -> void:
	var color := _effect_color(effect_id, actor)
	var era := current_era if actor == "ally" else enemy_era
	if fx_manager != null:
		var amount := 26 if effect_id in ["freeze", "thorns"] else (12 if effect_id == "haste" else 18)
		fx_manager.emit("effect", position, Vector2.UP, era, 1, amount, color)
		var radius := 72.0 if effect_id in ["field_aid", "freeze", "bulwark"] else 64.0
		fx_manager.emit_ring(position, color, radius, 0.7, 1)
	var label_text := "%s %s" % [_effect_symbol(effect_id), _effect_name(effect_id)]
	var text_offset := -24.0 if effect_id in ["tower_repair", "tower_power"] else -34.0
	if effect_id == "bounty":
		_spawn_hit_fx(
			Vector2(camera_x + BATTLE_VIEW_W * 0.5, 170.0),
			color,
			label_text,
			0.85
		)
	else:
		_spawn_hit_fx(position, color, label_text, 0.85, text_offset)
	AudioManager.play_sfx(_effect_sfx(effect_id))
	if effect_id == "boss_call" or effect_id == "tower_power":
		_shake_battlefield()

func _play_spawn_vfx(position: Vector2, color := Color("#ff9a78")) -> void:
	if fx_manager != null:
		fx_manager.emit("spawn", position, Vector2.UP, current_era, 2, 12, color)
		fx_manager.emit_ring(position, color, 52.0, 0.45, 2)

func _play_boss_entry_vfx(position: Vector2, ally: bool, hero_name: String) -> void:
	var color := Color("#ffd273") if ally else Color("#ff625c")
	if fx_manager != null:
		var era := current_era if ally else enemy_era
		fx_manager.emit_boss_entry(position, color, era)
		fx_manager.emit_ring(position, color, 86.0, 0.8, 0)
		fx_manager.emit_ring(position, color.lightened(0.18), 56.0, 0.65, 0)
	_shake_battlefield()
	_show_boss_entry_banner(hero_name, ally)
	AudioManager.play_sfx("boss_ally_entry" if ally else "boss_enemy_entry", {"priority": 0})

func _entry_ring_points(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := -TAU * float(index) / float(point_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _show_boss_entry_banner(hero_name: String, ally: bool) -> void:
	if boss_entry_banner == null:
		return
	if boss_entry_tween != null:
		boss_entry_tween.kill()
	boss_entry_banner.text = ("%s BOSS 登场 · %s" if ally else "%s BOSS 来袭 · %s") % [
		"★" if ally else "◆",
		hero_name,
	]
	var text_width := boss_entry_banner.get_theme_default_font().get_string_size(
		boss_entry_banner.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		25
	).x
	var banner_width := clampf(text_width + 56.0, 260.0, 540.0)
	boss_entry_banner.size = Vector2(banner_width, 48.0)
	boss_entry_banner.position = Vector2((BATTLE_RECT.size.x - banner_width) * 0.5, 244.0)
	boss_entry_banner.pivot_offset = boss_entry_banner.size * 0.5
	boss_entry_banner.add_theme_color_override(
		"font_color",
		Color("#ffe08a") if ally else Color("#ff8178")
	)
	boss_entry_overlay.visible = true
	boss_entry_banner.modulate = Color(1, 1, 1, 0)
	boss_entry_banner.scale = Vector2.ONE
	boss_entry_tween = create_tween()
	boss_entry_tween.tween_property(boss_entry_banner, "modulate:a", 1.0, 0.2)
	boss_entry_tween.tween_interval(1.05)
	boss_entry_tween.tween_property(boss_entry_banner, "modulate:a", 0.0, 0.4)
	boss_entry_tween.tween_callback(func() -> void:
		if boss_entry_overlay != null:
			boss_entry_overlay.visible = false
	)

func _effect_icon_bb(effect_id: String, icon_size: int) -> String:
	var path := EFFECT_ICON_PATH % effect_id
	if not ResourceLoader.exists(path):
		return ""
	return "[img=%d]%s[/img] " % [icon_size, path]

func _buff_active(effect_id: String) -> bool:
	return _buff_active_side("ally", effect_id)

func _buff_active_side(faction: String, effect_id: String) -> bool:
	var timers: Dictionary = buff_timers if faction == "ally" else enemy_buff_timers
	return float(timers.get(effect_id, 0.0)) > 0.0

func _effect_name(effect_id: String) -> String:
	for effect in RANDOM_EFFECTS:
		if str(effect.id) == effect_id:
			return str(effect.name)
	return effect_id

func _tick_buffs(delta: float) -> void:
	enemy_freeze_time = maxf(0.0, enemy_freeze_time - delta)
	ally_freeze_time = maxf(0.0, ally_freeze_time - delta)
	for timers in [buff_timers, enemy_buff_timers]:
		var expired: Array[String] = []
		for effect_id in timers:
			timers[effect_id] = float(timers[effect_id]) - delta
			if float(timers[effect_id]) <= 0.0:
				expired.append(str(effect_id))
		for effect_id in expired:
			timers.erase(effect_id)
	_update_buff_ui()

func _sync_persistent_status_vfx(delta: float) -> void:
	_sync_unit_buff_auras("ally")
	_sync_unit_buff_auras("enemy")
	_sync_tower_power_vfx()
	_sync_bounty_vfx(delta)

func _sync_unit_buff_auras(faction: String) -> void:
	var ids: Array[String] = []
	var colors: Array[Color] = []
	var timers: Dictionary = buff_timers if faction == "ally" else enemy_buff_timers
	for effect_id in ["frenzy", "morale", "bulwark", "haste", "lifesteal", "thorns"]:
		if float(timers.get(effect_id, 0.0)) > 0.0:
			ids.append(effect_id)
			colors.append(_effect_color(effect_id, faction))
	var frozen := enemy_freeze_time > 0.0 if faction == "enemy" else ally_freeze_time > 0.0
	if frozen:
		ids.append("freeze")
		colors.append(_effect_color("freeze", faction))
	for unit in _living_units(faction):
		unit.set_buff_aura(ids, colors)

func _sync_tower_power_vfx() -> void:
	_update_tower_aura(ally_tower_aura, tower_attack_bonus > 1.0)
	_update_tower_aura(enemy_tower_aura, enemy_tower_attack_bonus > 1.0)

func _update_tower_aura(aura: Line2D, active: bool) -> void:
	if aura == null:
		return
	if active:
		var active_tween: Tween = ally_tower_aura_tween if aura == ally_tower_aura else enemy_tower_aura_tween
		if active_tween != null:
			active_tween.kill()
			if aura == ally_tower_aura:
				ally_tower_aura_tween = null
			else:
				enemy_tower_aura_tween = null
		aura.visible = true
		aura.modulate.a = 0.68 + sin(Time.get_ticks_msec() * 0.004) * 0.14
		aura.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.04)
	else:
		var fade_tween: Tween = ally_tower_aura_tween if aura == ally_tower_aura else enemy_tower_aura_tween
		if aura.visible and fade_tween == null:
			fade_tween = create_tween()
			fade_tween.tween_property(aura, "modulate:a", 0.0, 0.3)
			fade_tween.tween_callback(func() -> void:
				aura.visible = false
				aura.scale = Vector2.ONE
			)
			if aura == ally_tower_aura:
				ally_tower_aura_tween = fade_tween
			else:
				enemy_tower_aura_tween = fade_tween

func _sync_bounty_vfx(delta: float) -> void:
	if coin_label == null:
		return
	if float(buff_timers.get("bounty", 0.0)) > 0.0:
		_bounty_pulse_phase = fmod(_bounty_pulse_phase + delta * 2.8, TAU)
		var pulse := sin(_bounty_pulse_phase) * 0.06
		coin_label.pivot_offset = coin_label.size * 0.5
		coin_label.scale = Vector2.ONE * (1.0 + pulse)
		coin_label.modulate = Color(1.0, 0.92 + pulse, 0.68 + pulse, 1.0)
	else:
		_bounty_pulse_phase = 0.0
		coin_label.scale = Vector2.ONE
		coin_label.modulate = Color.WHITE

func _update_buff_ui() -> void:
	if buff_label == null or enemy_buff_label == null:
		return
	var parts: Array[String] = []
	if enemy_freeze_time > 0.0:
		parts.append("%s%s %ds" % [_effect_icon_bb("freeze", 18), _effect_name("freeze"), int(ceil(enemy_freeze_time))])
	for effect_id in buff_timers:
		var id := str(effect_id)
		parts.append("%s%s %ds" % [_effect_icon_bb(id, 18), _effect_name(id), int(ceil(float(buff_timers[effect_id])))])
	if tower_attack_bonus > 1.0:
		parts.append("%s塔炮 ×%.1f" % [_effect_icon_bb("tower_power", 18), tower_attack_bonus])
	buff_label.text = "   ".join(parts)
	var enemy_parts: Array[String] = []
	if ally_freeze_time > 0.0:
		enemy_parts.append("%s%s %ds" % [_effect_icon_bb("freeze", 18), _effect_name("freeze"), int(ceil(ally_freeze_time))])
	for effect_id in enemy_buff_timers:
		var id := str(effect_id)
		enemy_parts.append("%s%s %ds" % [_effect_icon_bb(id, 18), _effect_name(id), int(ceil(float(enemy_buff_timers[effect_id])))])
	if enemy_tower_attack_bonus > 1.0:
		enemy_parts.append("%s敌塔炮 ×%.1f" % [_effect_icon_bb("tower_power", 18), enemy_tower_attack_bonus])
	enemy_buff_label.text = "   ".join(enemy_parts)

func _do_clear_tray() -> void:
	if not battle_active or battle_ended or tray_cards.size() < 3:
		return
	coin_count = maxi(0, coin_count - CLEAR_TRAY_COST)
	var removals: Array[String] = tray_cards.duplicate()
	removals.sort_custom(func(a: String, b: String) -> bool:
		var count_a := tray_cards.count(a)
		var count_b := tray_cards.count(b)
		if count_a == count_b:
			return _card_sort_key(a) < _card_sort_key(b)
		return count_a < count_b
	)
	var removed := mini(3, removals.size())
	for index in range(removed):
		tray_cards.erase(removals[index])
	_rebuild_tray_visuals()
	battle_hint.text = "已扣 %d 金币清理合成台（移除 %d 张）" % [CLEAR_TRAY_COST, removed]
	_update_coin_ui()

func _build_era_select_panel() -> void:
	era_select_panel = Panel.new()
	era_select_panel.position = Vector2(84, 220)
	era_select_panel.size = Vector2(552, 730)
	era_select_panel.z_index = 10
	era_select_panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	era_select_panel.visible = false
	main_menu.add_child(era_select_panel)
	var title := _label(era_select_panel, "选择时代", Vector2(0, 28), Vector2(552, 42), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index in range(GameData.ERAS.size()):
		var era: String = GameData.ERAS[index]
		var unlocked := index <= SaveManager.get_unlocked_era_index()
		var text := str(GameData.ERA_NAMES.get(era, era))
		if not unlocked:
			text += "（未解锁）"
		var button := _menu_button(era_select_panel, text, Vector2(86, 94 + index * 88), Vector2(380, 60), 19)
		button.disabled = not unlocked
		era_select_buttons.append(button)
		if unlocked:
			button.pressed.connect(_select_start_era.bind(index))
	var close_button := _menu_button(era_select_panel, "关闭", Vector2(176, 570), Vector2(200, 54), 18)
	close_button.pressed.connect(_hide_era_select)

func _show_era_select() -> void:
	_hide_settings()
	_refresh_era_select_ui()
	if era_select_panel != null:
		era_select_panel.visible = true

func _refresh_era_select_ui() -> void:
	var unlocked_index := SaveManager.get_unlocked_era_index()
	for index in range(era_select_buttons.size()):
		var unlocked := index <= unlocked_index
		era_select_buttons[index].disabled = not unlocked
		era_select_buttons[index].text = str(GameData.ERA_NAMES.get(GameData.ERAS[index], GameData.ERAS[index]))
		if not unlocked:
			era_select_buttons[index].text += "（未解锁）"

func _hide_era_select() -> void:
	if era_select_panel != null:
		era_select_panel.visible = false

func _select_start_era(index: int) -> void:
	_hide_era_select()
	if main_menu != null:
		main_menu.visible = false
	_start_round(index)

func _enter_game() -> void:
	_hide_settings()
	_hide_era_select()
	if main_menu != null:
		main_menu.visible = false
	_start_round()

func _show_main_menu() -> void:
	battle_active = false
	battle_ended = false
	battle_won = false
	paused = false
	AudioManager.set_music_filtered(false)
	_hide_settings()
	_hide_era_select()
	if result_overlay != null:
		result_overlay.visible = false
	if pause_overlay != null:
		pause_overlay.visible = false
	if tutorial_overlay != null:
		tutorial_overlay.visible = false
	if pause_button != null:
		pause_button.visible = false
	_remove_battle_units()
	_update_progress_ui()
	if main_menu != null:
		main_menu.visible = true

func _start_round(start_era_index: int = 0) -> void:
	AudioManager.set_music_filtered(false)
	for card in deck_cards:
		if is_instance_valid(card):
			card.queue_free()
	deck_cards.clear()
	for view in tray_views:
		if is_instance_valid(view):
			view.queue_free()
	tray_views.clear()
	tray_cards.clear()
	tray_incoming = 0
	occupied_units = 0
	era_index = clampi(start_era_index, 0, GameData.ERAS.size() - 1)
	base_era_index = era_index
	current_era = GameData.ERAS[era_index]
	_roll_effect_cards_by_era()
	coin_count = 300
	kill_score = 0
	prep_pending = false
	auto_prep = false
	stuck_warned = false
	enemy_era_index = 0
	enemy_era = "stone"
	buff_timers.clear()
	enemy_buff_timers.clear()
	enemy_freeze_time = 0.0
	ally_freeze_time = 0.0
	tower_attack_bonus = 1.0
	enemy_tower_attack_bonus = 1.0
	tower_destruction_started = false
	enemy_coin = 0.0
	enemy_effect_cd = 0.0
	enemy_rally_fired = 0
	_update_buff_ui()
	_update_coin_ui()
	battle_active = true
	battle_ended = false
	battle_won = false
	paused = false
	if pause_overlay != null:
		pause_overlay.visible = false
	if tutorial_overlay != null:
		tutorial_overlay.visible = false
	if pause_button != null:
		pause_button.visible = true
	wave_min_timer = _diff().first_delay
	wave_spawning = false
	wave_active_timer = 0.0
	wave_boss_pending = false
	enemy_spawn_timer = 0.0
	enemy_spawn_index = 0
	wave_number = 0
	round_number = 0
	ally_tower_cd = 0.0
	enemy_tower_cd = 0.0
	card_z_top = 0
	ally_tower_hp = GameData.tower_hp(current_era) * float(_diff().tower_mult)
	enemy_tower_hp = GameData.tower_hp(enemy_era)
	ally_tower_max_hp = ally_tower_hp
	enemy_tower_max_hp = enemy_tower_hp
	ally_alarm_50_played = false
	ally_alarm_25_played = false
	battle_hint.text = "备战 %d 秒，敌方部队即将出击" % int(_diff().first_delay)
	if result_overlay != null:
		result_overlay.visible = false
	_remove_battle_units()
	_update_progress_ui()
	_update_tower_ui()
	_sync_persistent_status_vfx(0.0)
	_spawn_next_batch()
	_refresh_era_visuals(false)
	_reset_camera()
	if not SaveManager.get_tutorial_seen():
		_show_tutorial()

func _spawn_card(card_id: String, index: int, from_bottom := false) -> void:
	var card := CardView.new()
	var texture: Texture2D
	var path := _card_texture_path(card_id)
	if path != "" and ResourceLoader.exists(path):
		texture = load(path)
	var card_data: Dictionary = GameData.CARDS.get(card_id, {})
	var tint: Color = card_data.get("color", Color("#888888"))
	card.setup(card_id, texture, tint)
	card.rotation = rng.randf_range(-0.45, 0.45)
	card.position = _hidden_pile_position(card.rotation) if from_bottom else _pile_position(index)
	if from_bottom:
		for existing in deck_cards:
			if is_instance_valid(existing):
				existing.z_index += 1
		card.z_index = 0
	else:
		card.z_index = index
		card_z_top = maxi(card_z_top, index)
	card_layer.add_child(card)
	deck_cards.append(card)

func _spawn_next_batch() -> void:
	round_number += 1
	var era_steps := 0
	for up_round in ERA_UP_ROUNDS:
		if round_number >= int(up_round):
			era_steps += 1
	var target_ei := mini(base_era_index + era_steps, GameData.ERAS.size() - 1)
	while era_index < target_ei:
		_advance_era()
	var groups := BATCH_BASE_GROUPS + (round_number - 1) * BATCH_GROUP_STEP
	var batch := _build_batch_cards(groups)
	batch.shuffle()
	for index in range(batch.size()):
		_spawn_card(batch[index], index)
	_refresh_covered()
	_update_progress_ui()

func _build_batch_cards(groups_needed: int) -> Array[String]:
	var counts := GameData.blended_deck_counts(era_index)
	var result: Array[String] = []
	if counts.is_empty() or groups_needed <= 0:
		return result
	var total_weight := 0
	for card_id in counts:
		total_weight += int(counts[card_id])
	if total_weight <= 0:
		return result
	var remainders: Array[Dictionary] = []
	var assigned := 0
	for card_id in counts:
		var exact := float(groups_needed) * float(counts[card_id]) / float(total_weight)
		var whole := int(floor(exact))
		assigned += whole
		remainders.append({"card": str(card_id), "groups": whole, "rest": exact - float(whole)})
	remainders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.rest) > float(b.rest)
	)
	var leftover := groups_needed - assigned
	for index in range(remainders.size()):
		if leftover <= 0:
			break
		remainders[index]["groups"] = int(remainders[index].groups) + 1
		leftover -= 1
	var boss_card := _current_era_boss_card()
	if boss_card != "":
		for entry in remainders:
			if str(entry.card) == boss_card and int(entry.groups) < MIN_BOSS_GROUPS:
				entry["groups"] = MIN_BOSS_GROUPS
	for entry in remainders:
		for _g in range(int(entry.groups)):
			for _c in range(3):
				result.append(str(entry.card))
	result.append_array(_build_effect_cards_for_batch())
	return result

func _current_era_boss_card() -> String:
	for hero_id in GameData.heroes_for_era(current_era):
		if str(GameData.HEROES[hero_id].get("role", "")) == "boss":
			return str(GameData.HEROES[hero_id].get("card", hero_id))
	return ""

func _build_effect_cards_for_batch() -> Array[String]:
	var result: Array[String] = []
	if effect_cards_by_era.is_empty():
		_roll_effect_cards_by_era()
	for effect_id in effect_cards_by_era.get(current_era, []):
		for _copy in range(EFFECT_CARD_PAIR_SIZE):
			result.append(_effect_card_id(str(effect_id)))
	return result

func _pile_position(index: int) -> Vector2:
	return _random_pile_position()

func _random_pile_position() -> Vector2:
	var limit := card_layer.size - CARD_SIZE
	return Vector2(
		rng.randf_range(0.0, maxf(limit.x, 0.0)),
		rng.randf_range(0.0, maxf(limit.y, 0.0))
	)

func _hidden_pile_position(rotation: float) -> Vector2:
	if deck_cards.is_empty():
		return _random_pile_position()
	var best_position := _random_pile_position()
	var best_coverage := -1.0
	var existing_cards: Array[Dictionary] = []
	for existing in deck_cards:
		if not is_instance_valid(existing) or existing.claimed:
			continue
		var existing_transform := Transform2D(existing.rotation, existing.position)
		existing_cards.append({
			"inverse": existing_transform.affine_inverse(),
			"aabb": _card_aabb(existing.position, existing.rotation),
		})
	for _candidate_index in range(24):
		var candidate := _random_pile_position()
		var coverage := _pile_coverage(candidate, rotation, existing_cards)
		if coverage > best_coverage:
			best_coverage = coverage
			best_position = candidate
	if best_coverage < 0.9:
		for _candidate_index in range(72):
			var candidate := _random_pile_position()
			var coverage := _pile_coverage(candidate, rotation, existing_cards)
			if coverage > best_coverage:
				best_coverage = coverage
				best_position = candidate
	return best_position

func _pile_coverage(position: Vector2, rotation: float, existing_cards: Array[Dictionary]) -> float:
	var transform := Transform2D(rotation, position)
	var covered := 0
	var samples := 0
	for y in range(9, int(CARD_SIZE.y), 18):
		for x in range(9, int(CARD_SIZE.x), 18):
			samples += 1
			var canvas_point := transform * Vector2(x, y)
			for existing in existing_cards:
				if not existing["aabb"].has_point(canvas_point):
					continue
				if Rect2(Vector2.ZERO, CARD_SIZE).has_point(existing["inverse"] * canvas_point):
					covered += 1
					break
	return float(covered) / float(samples) if samples > 0 else 0.0

func _card_aabb(position: Vector2, rotation: float) -> Rect2:
	var transform := Transform2D(rotation, position)
	var corners := [
		transform * Vector2.ZERO,
		transform * Vector2(CARD_SIZE.x, 0.0),
		transform * Vector2(0.0, CARD_SIZE.y),
		transform * CARD_SIZE,
	]
	var min_point: Vector2 = corners[0]
	var max_point: Vector2 = corners[0]
	for corner in corners:
		min_point.x = minf(min_point.x, corner.x)
		min_point.y = minf(min_point.y, corner.y)
		max_point.x = maxf(max_point.x, corner.x)
		max_point.y = maxf(max_point.y, corner.y)
	return Rect2(min_point, max_point - min_point)

func _clamp_pile_position(spot: Vector2) -> Vector2:
	var limit := card_layer.size - CARD_SIZE
	return Vector2(clampf(spot.x, 0.0, maxf(limit.x, 0.0)), clampf(spot.y, 0.0, maxf(limit.y, 0.0)))

func _refresh_covered() -> void:
	var snapshots: Array[Dictionary] = []
	for card in deck_cards:
		if not is_instance_valid(card) or card.claimed:
			continue
		var transform := card.get_global_transform_with_canvas()
		var inverse := transform.affine_inverse()
		var corners := [
			transform * Vector2.ZERO,
			transform * Vector2(CARD_SIZE.x, 0.0),
			transform * Vector2(0.0, CARD_SIZE.y),
			transform * CARD_SIZE,
		]
		var min_point: Vector2 = corners[0]
		var max_point: Vector2 = corners[0]
		for corner in corners:
			min_point.x = minf(min_point.x, corner.x)
			min_point.y = minf(min_point.y, corner.y)
			max_point.x = maxf(max_point.x, corner.x)
			max_point.y = maxf(max_point.y, corner.y)
		snapshots.append({
			"card": card,
			"z_index": card.z_index,
			"inverse": inverse,
			"aabb": Rect2(min_point, max_point - min_point),
			"transform": transform,
		})
	for snapshot_index in range(snapshots.size()):
		var snapshot: Dictionary = snapshots[snapshot_index]
		var blockers: Array[Dictionary] = []
		for candidate in snapshots:
			if candidate["z_index"] <= snapshot["z_index"]:
				continue
			if not candidate["aabb"].intersects(snapshot["aabb"]):
				continue
			blockers.append(candidate)
		blockers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["z_index"] > b["z_index"]
		)
		snapshots[snapshot_index]["blockers"] = blockers
	for card in deck_cards:
		if is_instance_valid(card):
			var snapshot: Dictionary = {}
			for candidate in snapshots:
				if candidate["card"] == card:
					snapshot = candidate
					break
			card.set_locked(not _card_has_exposed_area(snapshot, snapshots))
	_update_progress_ui()

func _on_card_layer_input(event: InputEvent) -> void:
	if not _can_pick_cards():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			AudioManager.play_sfx("ui_denied")
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var canvas_point: Vector2 = card_layer.get_global_transform_with_canvas() * event.position
	var card := _top_card_at(canvas_point)
	if card != null and card.locked:
		AudioManager.play_sfx("card_locked")
	elif card != null:
		_on_card_clicked(card)
		card_layer.accept_event()

func _top_card_at(canvas_point: Vector2) -> CardView:
	var result: CardView
	var highest_z := -2147483648
	for card in deck_cards:
		if not is_instance_valid(card) or card.claimed:
			continue
		var local_point := card.get_global_transform_with_canvas().affine_inverse() * canvas_point
		if Rect2(Vector2.ZERO, CARD_SIZE).has_point(local_point) and card.z_index > highest_z:
			result = card
			highest_z = card.z_index
	return result

func _card_has_exposed_area(snapshot: Dictionary, snapshots: Array[Dictionary]) -> bool:
	if snapshot.is_empty():
		return false
	var transform: Transform2D = snapshot["transform"]
	var blockers: Array[Dictionary] = snapshot["blockers"]
	for y in range(1, int(CARD_SIZE.y), 16):
		for x in range(1, int(CARD_SIZE.x), 16):
			var canvas_point := transform * Vector2(x, y)
			var covered := false
			for candidate in blockers:
				var aabb: Rect2 = candidate["aabb"]
				if not aabb.has_point(canvas_point):
					continue
				var inverse: Transform2D = candidate["inverse"]
				if Rect2(Vector2.ZERO, CARD_SIZE).has_point(inverse * canvas_point):
					covered = true
					break
			if not covered:
				return true
	return false

func _on_card_clicked(card: CardView) -> void:
	if not _can_pick_cards() or card.locked or card.claimed:
		return
	var target_index := _first_open_slot()
	if target_index < 0:
		battle_hint.text = "合成台已满，先合成 3 张小兵或 2 张效果"
		AudioManager.play_sfx("card_jam", {"priority": 0})
		return
	AudioManager.play_sfx("click")
	card.claimed = true
	tray_incoming += 1
	deck_cards.erase(card)
	if deck_cards.is_empty():
		_spawn_next_batch()
	_refresh_covered()
	var selected_id := card.card_id
	card.reparent(self)
	card.z_index = 30
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "global_position", _slot_position(target_index) - CARD_SIZE / 2.0, 0.36)
	tween.parallel().tween_property(card, "rotation", 0.0, 0.36)
	tween.tween_callback(func() -> void:
		if is_instance_valid(card):
			card.queue_free()
		_add_to_tray(selected_id)
		AudioManager.play_sfx("place")
		if fx_manager != null:
			fx_manager.emit_card_pick(_slot_position(target_index), _card_fx_color(selected_id), current_era)
	)

func _card_fx_color(card_id: String) -> Color:
	if _is_effect_card(card_id):
		return Color("#d58cff")
	var data: Dictionary = GameData.CARDS.get(card_id, {})
	return data.get("color", Color("#ffd273"))

func _can_pick_cards() -> bool:
	return battle_active and not battle_ended and (not paused or auto_prep)

func _first_open_slot() -> int:
	var used := tray_cards.size() + tray_incoming
	return used if used < TRAY_SLOTS else -1

func _slot_position(index: int) -> Vector2:
	return tray.global_position + TRAY_SLOT_ORIGIN + Vector2(index * TRAY_SLOT_STEP, 0) + TRAY_SLOT_SIZE * 0.5

func _add_to_tray(card_id: String) -> void:
	tray_incoming = maxi(0, tray_incoming - 1)
	tray_cards.append(card_id)
	tray_cards.sort_custom(func(a: String, b: String) -> bool:
		return _card_sort_key(a) < _card_sort_key(b)
	)
	_rebuild_tray_visuals()
	_check_merges()
	_check_stuck()

func _check_stuck() -> void:
	if battle_ended or not battle_active:
		return
	if tray_incoming > 0:
		return
	if tray_cards.size() < TRAY_SLOTS or _has_merge():
		if tray_cards.size() == TRAY_SLOTS - 1 and not _has_merge():
			battle_hint.text = "⚠ 合成台只剩 1 格，凑不齐将扣 %d 金币清理" % CLEAR_TRAY_COST
		return
	if coin_count < CLEAR_TRAY_COST:
		AudioManager.play_sfx("ui_denied")
		_finish_battle(false, "金币不足，无法清理合成台")
		return
	if not stuck_warned:
		_enter_clear_confirm()
		return
	_do_clear_tray()

func _enter_clear_confirm() -> void:
	prep_pending = false
	auto_prep = true
	paused = true
	_configure_pause("clear_confirm")
	_set_pause_text("合成台已满", "凑不齐三连，需扣 %d 金币清理合成台" % CLEAR_TRAY_COST)
	if pause_overlay != null:
		pause_overlay.visible = true
	AudioManager.play_sfx("era")
	_update_progress_ui()

func _confirm_clear_tray() -> void:
	stuck_warned = true
	paused = false
	auto_prep = false
	_configure_pause("prep")
	if pause_overlay != null:
		pause_overlay.visible = false
	_do_clear_tray()
	_update_progress_ui()

func _card_sort_key(card_id: String) -> int:
	if _is_effect_card(card_id):
		return _effect_card_sort_key(card_id)
	var hero := GameData.hero_for_card(card_id)
	var era := str(hero.get("era", current_era))
	var era_order := maxi(GameData.ERAS.find(era), 0)
	var card_order := maxi(GameData.cards_for_era(era).find(card_id), 0)
	return era_order * 100 + card_order

func _rebuild_tray_visuals() -> void:
	for view in tray_views:
		if is_instance_valid(view):
			view.queue_free()
	tray_views.clear()
	for index in range(tray_cards.size()):
		var icon := TextureRect.new()
		icon.position = TRAY_SLOT_ORIGIN + Vector2(index * TRAY_SLOT_STEP, 0)
		icon.size = TRAY_SLOT_SIZE
		var path := _card_texture_path(tray_cards[index])
		if path != "" and ResourceLoader.exists(path):
			icon.texture = load(path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.gui_input.connect(_on_tray_card_input.bind(index))
		tray.add_child(icon)
		tray_views.append(icon)
	_update_progress_ui()

func _on_tray_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tray_press_index = index
			var timer := get_tree().create_timer(CARD_INFO_HOLD)
			timer.timeout.connect(_on_tray_hold_elapsed.bind(index))
		else:
			tray_press_index = -1
	elif event is InputEventMouseMotion and tray_press_index == index:
		var motion := event as InputEventMouseMotion
		if motion.relative.length() > 12.0:
			tray_press_index = -1

func _on_tray_hold_elapsed(index: int) -> void:
	if tray_press_index != index or index >= tray_cards.size():
		return
	tray_press_index = -1
	_show_card_info(tray_cards[index])

func _build_card_info_overlay() -> void:
	card_info_overlay = Control.new()
	card_info_overlay.size = VIEW_SIZE
	card_info_overlay.z_index = 4095
	card_info_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	card_info_overlay.visible = false
	card_info_overlay.gui_input.connect(_on_card_info_input)
	add_child(card_info_overlay)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color(0.05, 0.03, 0.02, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_info_overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(70, 430)
	panel.size = Vector2(580, 420)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	card_info_overlay.add_child(panel)
	card_info_title_label = _label(panel, "", Vector2(0, 26), Vector2(580, 40), 26)
	card_info_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_info_text_label = RichTextLabel.new()
	card_info_text_label.bbcode_enabled = true
	card_info_text_label.scroll_active = false
	card_info_text_label.position = Vector2(40, 78)
	card_info_text_label.size = Vector2(500, 258)
	card_info_text_label.add_theme_font_size_override("normal_font_size", 18)
	card_info_text_label.add_theme_color_override("default_color", Color("#fff0c7"))
	panel.add_child(card_info_text_label)
	var close_button := _menu_button(panel, "关闭", Vector2(190, 344), Vector2(200, 52), 18)
	close_button.pressed.connect(_hide_card_info)

func _on_card_info_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hide_card_info()

func _show_card_info(card_id: String) -> void:
	if card_info_overlay == null:
		return
	var card: Dictionary = GameData.CARDS.get(card_id, {})
	card_info_title_label.text = str(card.get("name", card_id))
	card_info_text_label.text = _card_info_text(card_id)
	move_child(card_info_overlay, get_child_count() - 1)
	card_info_overlay.visible = true
	_play_button_sfx()

func _hide_card_info() -> void:
	if card_info_overlay != null:
		card_info_overlay.visible = false

func _card_info_text(card_id: String) -> String:
	var held := 0
	for held_card in tray_cards:
		if held_card == card_id:
			held += 1
	if _is_effect_card(card_id):
		var effect := _effect_by_id(_effect_id_from_card(card_id))
		var lines := [
			"类型：[b]效果卡[/b]",
			"发动：同名 [b]2 张[/b]自动发动（不上场）",
			"效果：%s" % str(effect.get("desc", "—")),
		]
		var duration := float(effect.get("duration", 0.0))
		if duration > 0.0:
			lines.append("持续：%.0f 秒" % duration)
		lines.append("合成台已有：%d / 2 张" % held)
		return "\n".join(lines)
	var hero := GameData.hero_for_card(card_id)
	if hero.is_empty():
		return "合成台已有：%d 张" % held
	var info := [
		"类型：[b]小兵卡[/b]（%s・%s）" % [str(hero.get("era_name", "")), str(hero.get("role_name", ""))],
		"合成：同名 [b]3 张[/b] → %s" % str(hero.get("name", card_id)),
		"生命 %.0f　攻击 %.0f" % [float(hero.get("hp", 0.0)), float(hero.get("attack", 0.0))],
		"攻速 %.2f 次/秒　射程 %.0f" % [float(hero.get("attack_speed", 0.0)), float(hero.get("range", 0.0))],
		"移速 %.0f" % float(hero.get("move_speed", 0.0)),
		"合成台已有：%d / 3 张" % held,
	]
	return "\n".join(info)

func _check_merges() -> void:
	for effect_id in _all_effect_ids():
		var effect_card_id := _effect_card_id(effect_id)
		if tray_cards.count(effect_card_id) >= EFFECT_CARD_PAIR_SIZE:
			for _count in range(EFFECT_CARD_PAIR_SIZE):
				tray_cards.erase(effect_card_id)
			var effect := _effect_by_id(effect_id)
			print("效果合成: %d x %s -> %s" % [EFFECT_CARD_PAIR_SIZE, effect_card_id, str(effect.name)])
			AudioManager.play_sfx("merge")
			if fx_manager != null:
				fx_manager.emit_card_merge(tray.global_position + Vector2(324, 40), Color("#d58cff"), current_era)
			_rebuild_tray_visuals()
			_apply_random_effect(effect)
			battle_hint.text = "效果卡发动：%s" % str(effect.name)
			_check_merges()
			return
	for card_id in GameData.CARDS:
		if _is_effect_card(str(card_id)):
			continue
		if tray_cards.count(card_id) >= 3:
			for _count in range(3):
				tray_cards.erase(card_id)
			var hero_id: String = GameData.CARDS[card_id].hero
			print("合成成功: 3 x %s -> %s" % [card_id, hero_id])
			AudioManager.play_sfx("merge")
			if fx_manager != null:
				fx_manager.emit_card_merge(tray.global_position + Vector2(324, 40), Color("#ffd273"), current_era)
			_rebuild_tray_visuals()
			_spawn_ally(hero_id)
			_check_merges()
			return

func _has_merge() -> bool:
	return _has_effect_pair() or _has_triple()

func _has_effect_pair() -> bool:
	for effect_id in _all_effect_ids():
		if tray_cards.count(_effect_card_id(effect_id)) >= EFFECT_CARD_PAIR_SIZE:
			return true
	return false

func _has_triple() -> bool:
	for card_id in GameData.CARDS:
		if _is_effect_card(str(card_id)):
			continue
		if tray_cards.count(card_id) >= 3:
			return true
	return false

func _spawn_ally(hero_id: String) -> BattleUnit:
	var data: Dictionary = GameData.HEROES.get(hero_id, {})
	if data.is_empty() or _living_units("ally").size() >= UNIT_CAP:
		return null
	var texture: Texture2D
	var path := GameData.hero_texture_path(hero_id)
	if path != "":
		texture = load(path)
	var unit := BattleUnit.new()
	unit.setup(hero_id, "ally", data, texture)
	var ally_count := _living_units("ally").size()
	var units_per_row := 6
	var row := ally_count / units_per_row
	var column := ally_count % units_per_row
	var spacing := 48.0
	unit.position = Vector2(
		ALLY_TOWER_X + 96 + column * spacing + row * 28.0,
		BATTLE_GROUND_Y - (row % 3) * 12.0
	)
	unit.z_index = 4
	unit.expired.connect(_on_unit_expired)
	unit.death_started.connect(_on_unit_death_started)
	world.add_child(unit)
	battle_units.append(unit)
	occupied_units += 1
	var is_boss := str(data.get("role", "")) == "boss"
	var hero_name := str(data.get("name", hero_id))
	if is_boss:
		_play_boss_entry_vfx(unit.position, true, hero_name)
	else:
		_play_spawn_vfx(unit.position, Color("#8fd8ff"))
	return unit

func _spawn_wave() -> void:
	wave_number += 1
	if wave_number % PREP_WAVE_INTERVAL == 0:
		prep_pending = true
	_update_progress_ui()
	var d := _diff()
	wave_active_timer = WAVE_DURATION
	wave_spawning = true
	wave_boss_pending = wave_number % int(d.boss_wave) == 0
	enemy_spawn_index = 0
	enemy_spawn_timer = 0.0
	if fx_manager != null:
		fx_manager.emit_wave_start(Vector2(360, BATTLE_GROUND_Y - 36.0), Color("#ff9a78"), enemy_era)
	_enemy_ai_take_turn()

func _wave_field_target() -> int:
	var d := _diff()
	return clampi(int(d.count_base) + wave_number / int(d.count_step), int(d.count_base), int(d.count_max))

func _spawn_one_enemy(allow_boss_in_pool := false) -> void:
	var ids := GameData.heroes_for_era(enemy_era)
	if ids.is_empty():
		return
	var chosen := ""
	if wave_boss_pending:
		for hero_id in ids:
			if str(GameData.HEROES[hero_id].get("role", "")) == "boss":
				chosen = hero_id
				break
		wave_boss_pending = false
	if chosen == "":
		var weighted: Array[String] = []
		for hero_id in ids:
			if not allow_boss_in_pool and str(GameData.HEROES[hero_id].get("role", "")) == "boss":
				continue
			var weight := maxi(0, int(GameData.HEROES[hero_id].get("deck_count", 12)))
			for _w in range(weight):
				weighted.append(hero_id)
		if weighted.is_empty():
			weighted = ids
		chosen = weighted[rng.randi_range(0, weighted.size() - 1)]
	_spawn_enemy(chosen, enemy_spawn_index % 3, 3)
	enemy_spawn_index += 1

func _enemy_rally_surge() -> void:
	var room := ENEMY_UNIT_CAP - _living_units("enemy").size()
	if room <= 0:
		return
	var burst := mini(RALLY_BURST, room)
	var saved_boss := wave_boss_pending
	wave_boss_pending = false
	for _i in range(burst):
		_spawn_one_enemy(true)
	wave_boss_pending = saved_boss
	_announce_enemy_action("敌方拼死反扑！", "")
	AudioManager.play_sfx("era")
	_update_tower_ui()

func _enemy_ai_take_turn() -> void:
	var d := _diff()
	var next_index := enemy_era_index + 1
	if next_index < GameData.ERAS.size() and enemy_era_index < era_index + 1:
		var cost := int(GameData.ERA_UPGRADE_COST.get(enemy_era, 0))
		if cost > 0 and enemy_coin >= float(cost):
			enemy_coin -= float(cost)
			_advance_enemy_era()
			return
	if enemy_effect_cd <= 0.0 and rng.randf() < float(d.ai_effect_chance):
		var price := _era_amount_for(enemy_era, RANDOM_EFFECT_PRICE_BASE)
		if enemy_coin >= float(price) and not ai_effects.is_empty():
			enemy_coin -= float(price)
			var effect: Dictionary = ai_effects[rng.randi_range(0, ai_effects.size() - 1)]
			_apply_random_effect(effect, "enemy")
			enemy_effect_cd = AI_EFFECT_CD
			_announce_enemy_action("敌方施放：%s" % str(effect.name), str(effect.id))
			_update_buff_ui()
			_update_tower_ui()

func _spawn_enemy(hero_id: String, index: int, total_count: int) -> BattleUnit:
	if _living_units("enemy").size() >= ENEMY_UNIT_CAP:
		return null
	var data: Dictionary = GameData.HEROES[hero_id].duplicate(true)
	var mult := float(_diff().enemy_mult)
	data["hp"] = float(data.hp) * mult
	data["attack"] = float(data.attack) * mult
	var texture: Texture2D
	var path := GameData.hero_texture_path(hero_id)
	if path != "":
		texture = load(path)
	var unit := BattleUnit.new()
	unit.setup(hero_id, "enemy", data, texture)
	var spacing := minf(78.0, 300.0 / maxf(1.0, float(total_count - 1)))
	unit.position = Vector2(
		ENEMY_TOWER_X - 70.0 - index * spacing,
		BATTLE_GROUND_Y - (index % 2) * 6.0
	)
	unit.z_index = 4
	unit.expired.connect(_on_unit_expired)
	unit.death_started.connect(_on_unit_death_started)
	world.add_child(unit)
	battle_units.append(unit)
	var is_boss := str(data.get("role", "")) == "boss"
	var hero_name := str(data.get("name", hero_id))
	if is_boss:
		_play_boss_entry_vfx(unit.position, false, hero_name)
	else:
		_play_spawn_vfx(unit.position)
	return unit

func _step_battle(delta: float) -> void:
	var ally_units := _living_units("ally")
	var enemy_units := _living_units("enemy")
	for unit in battle_units:
		if not is_instance_valid(unit) or not unit.alive:
			continue
		if unit.faction == "enemy" and enemy_freeze_time > 0.0:
			unit.set_moving(false)
			continue
		if unit.faction == "ally" and ally_freeze_time > 0.0:
			unit.set_moving(false)
			continue
		unit.attack_cooldown = maxf(0.0, unit.attack_cooldown - delta)
		var target := _find_target(unit, ally_units, enemy_units)
		if target != null:
			var distance := absf(target.position.x - unit.position.x)
			if distance > float(unit.stats.range):
				_move_unit(unit, target.position.x, delta)
			elif unit.attack_cooldown <= 0.0:
				_attack(unit, target)
		else:
			var tower_x := ENEMY_TOWER_X if unit.faction == "ally" else ALLY_TOWER_X
			if absf(tower_x - unit.position.x) > TOWER_RANGE:
				_move_unit(unit, tower_x, delta)
			elif unit.attack_cooldown <= 0.0:
				_attack_tower(unit)
	ally_tower_cd = maxf(0.0, ally_tower_cd - delta)
	enemy_tower_cd = maxf(0.0, enemy_tower_cd - delta)
	_process_tower_attack(true, enemy_units)
	_process_tower_attack(false, ally_units)
	if enemy_tower_hp <= 0.0:
		_trigger_tower_destruction(true)
	elif ally_tower_hp <= 0.0:
		_trigger_tower_destruction(false)

func _find_tower_target(ally: bool, candidates: Array[BattleUnit]) -> BattleUnit:
	var tower_x := ALLY_TOWER_X if ally else ENEMY_TOWER_X
	var nearest: BattleUnit
	var nearest_distance := TOWER_ATTACK_RANGE + 1.0
	for unit in candidates:
		if not is_instance_valid(unit) or not unit.alive:
			continue
		var distance := absf(unit.position.x - tower_x)
		if distance <= TOWER_ATTACK_RANGE and distance < nearest_distance:
			nearest = unit
			nearest_distance = distance
	return nearest

func _process_tower_attack(ally: bool, candidates: Array[BattleUnit]) -> void:
	var cooldown := ally_tower_cd if ally else enemy_tower_cd
	if cooldown > 0.0:
		return
	var target := _find_tower_target(ally, candidates)
	if target == null:
		return
	var tower_x := ALLY_TOWER_X if ally else ENEMY_TOWER_X
	var start_pos := Vector2(tower_x, BATTLE_GROUND_Y - TOWER_HEIGHT)
	var target_pos := func() -> Variant:
		if is_instance_valid(target) and target.alive:
			return target.position + Vector2(0, -56.0)
		return null
	var tower_era := current_era if ally else enemy_era
	var damage := TOWER_BASE_DAMAGE * float(GameData.ERA_MULT.get(tower_era, 1.0))
	if ally:
		damage *= tower_attack_bonus
	else:
		damage *= enemy_tower_attack_bonus
	var on_hit := func() -> void:
		if not is_instance_valid(target) or not target.alive:
			return
		_deal_damage(target, damage, "tower")
		_spawn_hit_fx(target.position, Color("#ffd273"), "✦")
		if fx_manager != null:
			fx_manager.emit_tower_hit(target.position, tower_era)
		_nudge_tower(ally)
		AudioManager.play_sfx("hit")
	var projectile := Projectile.new()
	projectile.setup(start_pos, target_pos, 300.0, tower_era, Color("#ffd273"), on_hit)
	world.add_child(projectile)
	if ally:
		ally_tower_cd = TOWER_ATTACK_CD
	else:
		enemy_tower_cd = TOWER_ATTACK_CD

func _move_unit(unit: BattleUnit, target_x: float, delta: float) -> void:
	var direction := signf(target_x - unit.position.x)
	var speed := float(unit.stats.move_speed)
	if _buff_active_side(unit.faction, "haste"):
		speed *= 1.5
	unit.position.x += direction * speed * delta
	unit.set_moving(true)
	var unit_key := unit.get_instance_id()
	var cooldown := float(walk_dust_cooldowns.get(unit_key, 0.0)) - delta
	if cooldown <= 0.0:
		var role := str(unit.stats.get("role", ""))
		var nearby := absf(unit.position.x - camera_x) <= BATTLE_VIEW_W * 0.8
		if nearby and (role in ["tank", "boss"] or float(unit.stats.get("size", 1.0)) >= 1.25):
			if fx_manager != null:
				fx_manager.emit("dust", unit.position + Vector2(0, 8), Vector2.UP, current_era if unit.faction == "ally" else enemy_era, 2, 2)
			cooldown = 0.24
		else:
			cooldown = 0.5
	walk_dust_cooldowns[unit_key] = cooldown

func _unit_damage(attacker: BattleUnit) -> float:
	var damage := float(attacker.stats.attack)
	if _buff_active_side(attacker.faction, "morale"):
		damage *= 1.25
	return damage

func _deal_damage(target: BattleUnit, amount: float, source: String, attacker: BattleUnit = null) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	var damage := amount
	if _buff_active_side(target.faction, "bulwark"):
		damage *= 0.7
	target.receive_damage(damage, source)
	if attacker == null or not is_instance_valid(attacker) or not attacker.alive:
		return
	if _buff_active_side(attacker.faction, "lifesteal"):
		var heal_amount := damage * 0.2
		attacker.heal(heal_amount)
		if fx_manager != null:
			fx_manager.emit_lifesteal(
				target.position,
				attacker.position + Vector2(0, -56.0),
				current_era if attacker.faction == "ally" else enemy_era
			)
	var melee := float(attacker.stats.get("range", 0.0)) < PROJECTILE_RANGE_THRESHOLD
	if melee and attacker.faction != target.faction and _buff_active_side(target.faction, "thorns"):
		attacker.receive_damage(damage * 0.3, "hero")

func _find_target(unit: BattleUnit, ally_units: Array[BattleUnit], enemy_units: Array[BattleUnit]) -> BattleUnit:
	var candidates := enemy_units if unit.faction == "ally" else ally_units
	if candidates.is_empty():
		return null
	var aggro_tanks: Array[BattleUnit] = []
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate.alive:
			continue
		if str(candidate.stats.get("role", "")) != "tank":
			continue
		if absf(candidate.position.x - unit.position.x) <= TANK_AGGRO_RADIUS:
			aggro_tanks.append(candidate)
	if not aggro_tanks.is_empty():
		return _nearest_unit(unit, aggro_tanks)
	return _nearest_unit(unit, candidates)

func _nearest_unit(unit: BattleUnit, candidates: Array[BattleUnit]) -> BattleUnit:
	var nearest: BattleUnit
	var nearest_distance := INF
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate.alive:
			continue
		var distance := absf(candidate.position.x - unit.position.x)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _attack(attacker: BattleUnit, target: BattleUnit) -> void:
	attacker.spend_attack_time()
	if _buff_active_side(attacker.faction, "frenzy"):
		attacker.attack_cooldown /= 1.4
	attacker.play_attack()
	var damage := _unit_damage(attacker)
	if float(attacker.stats.get("range", 0.0)) >= PROJECTILE_RANGE_THRESHOLD:
		var facing := 1.0 if attacker.faction == "ally" else -1.0
		var start_pos := attacker.position + Vector2(facing * 30.0, -56.0)
		var target_pos := func() -> Variant:
			if is_instance_valid(target) and target.alive:
				return target.position + Vector2(0, -56.0)
			return null
		var on_hit := func() -> void:
			if is_instance_valid(target) and target.alive:
				_deal_damage(target, damage, "hero", attacker)
				_spawn_hit_fx(target.position, Color("#ffd273"), "✦")
				if fx_manager != null:
					fx_manager.emit_hit(
						target.position,
						(target.position - attacker.position).normalized(),
						str(attacker.stats.era)
					)
				AudioManager.play_sfx("hit")
		var projectile := Projectile.new()
		projectile.setup(
			start_pos,
			target_pos,
			300.0,
			str(attacker.stats.era),
			attacker.stats.color_value,
			on_hit
		)
		world.add_child(projectile)
		return
	_deal_damage(target, damage, "hero", attacker)
	_spawn_hit_fx(target.position, Color("#ffd273"), "✦")
	if fx_manager != null:
		fx_manager.emit_hit(
			target.position,
			(target.position - attacker.position).normalized(),
			str(attacker.stats.era)
		)
	AudioManager.play_sfx("hit")

func _attack_tower(attacker: BattleUnit) -> void:
	attacker.spend_attack_time()
	if _buff_active_side(attacker.faction, "frenzy"):
		attacker.attack_cooldown /= 1.4
	attacker.play_attack()
	var damage := _unit_damage(attacker)
	var tower_x := ENEMY_TOWER_X if attacker.faction == "ally" else ALLY_TOWER_X
	if float(attacker.stats.get("range", 0.0)) >= PROJECTILE_RANGE_THRESHOLD:
		var facing := 1.0 if attacker.faction == "ally" else -1.0
		var start_pos := attacker.position + Vector2(facing * 30.0, -56.0)
		var tower_point := Vector2(tower_x, BATTLE_GROUND_Y - 56.0)
		var target_pos := func() -> Variant:
			return tower_point
		var on_hit := func() -> void:
			if attacker.faction == "ally":
				enemy_tower_hp = maxf(0.0, enemy_tower_hp - damage)
				_spawn_hit_fx(tower_point, Color("#ffd273"), "✦")
				if fx_manager != null:
					fx_manager.emit_tower_hit(tower_point, attacker.stats.era)
				_nudge_tower(false)
				AudioManager.play_sfx("tower")
				_shake_battlefield()
			else:
				ally_tower_hp = maxf(0.0, ally_tower_hp - damage)
				_spawn_hit_fx(tower_point, Color("#ff8e70"), "✦")
				if fx_manager != null:
					fx_manager.emit_tower_hit(tower_point, attacker.stats.era)
				_nudge_tower(true)
				AudioManager.play_sfx("tower")
				_shake_battlefield()
		var projectile := Projectile.new()
		projectile.setup(
			start_pos,
			target_pos,
			300.0,
			str(attacker.stats.era),
			attacker.stats.color_value,
			on_hit
		)
		world.add_child(projectile)
		return
	if attacker.faction == "ally":
		enemy_tower_hp = maxf(0.0, enemy_tower_hp - damage)
		_spawn_hit_fx(Vector2(ENEMY_TOWER_X, BATTLE_GROUND_Y - 40.0), Color("#ffd273"), "✦")
		if fx_manager != null:
			fx_manager.emit_tower_hit(Vector2(ENEMY_TOWER_X, BATTLE_GROUND_Y - 40.0), attacker.stats.era)
		_nudge_tower(false)
		AudioManager.play_sfx("tower")
		_shake_battlefield()
	else:
		ally_tower_hp = maxf(0.0, ally_tower_hp - damage)
		_spawn_hit_fx(Vector2(ALLY_TOWER_X, BATTLE_GROUND_Y - 40.0), Color("#ff8e70"), "✦")
		if fx_manager != null:
			fx_manager.emit_tower_hit(Vector2(ALLY_TOWER_X, BATTLE_GROUND_Y - 40.0), attacker.stats.era)
		_nudge_tower(true)
		AudioManager.play_sfx("tower")
		_shake_battlefield()

func _on_unit_expired(unit: BattleUnit) -> void:
	if not is_instance_valid(unit):
		return
	var faction := unit.faction
	battle_units.erase(unit)
	walk_dust_cooldowns.erase(unit.get_instance_id())
	AudioManager.play_sfx("unit_death", {"priority": 1})
	if faction == "ally":
		occupied_units = maxi(0, occupied_units - 1)
	if faction == "enemy" and not unit.score_awarded:
		unit.score_awarded = true
		var kill_score_value := int(unit.stats.get("kill_score", 0))
		var coins := maxi(1, int(round(float(_era_amount(kill_score_value)) * KILL_COIN_MULT)))
		if _buff_active("bounty"):
			coins += maxi(1, int(round(float(_era_amount(BOUNTY_COIN_BASE)) * KILL_COIN_MULT)))
		_change_coins(coins)
		if unit.last_damage_source != "tower":
			kill_score += kill_score_value
		_update_progress_ui()
	elif faction == "ally" and not unit.score_awarded:
		unit.score_awarded = true
		var reward := float(_era_amount_for(enemy_era, int(unit.stats.get("kill_score", 0)))) * float(_diff().ai_income_mult) * KILL_COIN_MULT
		enemy_coin += reward
	unit.queue_free()

func _on_unit_death_started(unit: BattleUnit) -> void:
	if fx_manager == null or not is_instance_valid(unit):
		return
	var faction := unit.faction
	fx_manager.emit_death(
		unit.position,
		Vector2.LEFT if faction == "enemy" else Vector2.RIGHT,
		current_era if faction == "ally" else enemy_era
	)

func _nudge_tower(ally: bool) -> void:
	var tower := ally_tower_sprite if ally else enemy_tower_sprite
	if tower == null:
		return
	var base_x := ALLY_TOWER_X if ally else ENEMY_TOWER_X
	var tween := create_tween()
	tween.tween_property(tower, "position:x", base_x + (-5.0 if ally else 5.0), 0.045)
	tween.tween_property(tower, "position:x", base_x, 0.08)

func _trigger_tower_destruction(won: bool) -> void:
	if tower_destruction_started:
		return
	tower_destruction_started = true
	var destroyed_ally := not won
	var position := Vector2(ALLY_TOWER_X if destroyed_ally else ENEMY_TOWER_X, BATTLE_GROUND_Y - 72.0)
	if fx_manager != null:
		fx_manager.emit_tower_destroy(position, current_era if destroyed_ally else enemy_era)
	_shake_battlefield()
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(_finish_battle.bind(won, "胜利！敌方防御塔已摧毁" if won else "失败！己方防御塔被摧毁"))

func _advance_era() -> void:
	if era_index >= GameData.ERAS.size() - 1:
		return
	era_index += 1
	current_era = GameData.ERAS[era_index]
	SaveManager.unlock_era(era_index)
	AudioManager.play_sfx("era")
	if fx_manager != null:
		fx_manager.emit_era_transition(Vector2(360, 280), _era_fx_color(current_era), current_era)
	_rescale_towers_for_era()
	_update_progress_ui()
	battle_hint.text = "文明进阶：%s！新一轮牌堆解锁更高级卡牌" % GameData.ERA_NAMES[current_era]
	_refresh_era_visuals(true)
	print("时代进阶: %s" % current_era)

func _advance_enemy_era() -> void:
	if enemy_era_index >= GameData.ERAS.size() - 1:
		return
	enemy_era_index += 1
	enemy_era = GameData.ERAS[enemy_era_index]
	var target := GameData.tower_hp(enemy_era)
	if target > enemy_tower_max_hp:
		enemy_tower_hp = target * (enemy_tower_hp / maxf(1.0, enemy_tower_max_hp))
		enemy_tower_max_hp = target
	_refresh_era_visuals(true)
	_update_tower_ui()
	AudioManager.play_sfx("era")
	if fx_manager != null:
		fx_manager.emit_era_transition(Vector2(360, 280), _era_fx_color(enemy_era), enemy_era)
	_announce_enemy_action("敌方进阶：%s" % str(GameData.ERA_NAMES.get(enemy_era, enemy_era)), "")

func _era_fx_color(era: String) -> Color:
	var material: Dictionary = fx_manager.era_material(era) if fx_manager != null else {}
	return material.get("primary", Color("#ffd273"))

func _rescale_towers_for_era() -> void:
	var ally_target := GameData.tower_hp(current_era) * float(_diff().tower_mult)
	if ally_target > ally_tower_max_hp:
		ally_tower_hp = ally_target * (ally_tower_hp / maxf(1.0, ally_tower_max_hp))
		ally_tower_max_hp = ally_target
	_update_tower_ui()

func _spawn_hit_fx(local_position: Vector2, color: Color, text: String, hold := 0.3, vertical_offset := 0.0) -> void:
	var fx: Label
	if hit_fx_pool.is_empty():
		fx = Label.new()
		fx.z_index = 6
		fx.add_theme_font_size_override("font_size", 24)
		fx.add_theme_color_override("font_outline_color", Color("#24150f"))
		fx.add_theme_constant_override("outline_size", 6)
	else:
		fx = hit_fx_pool.pop_back()
	var text_y := maxf(8.0, local_position.y - 130.0 + vertical_offset)
	fx.position = Vector2(local_position.x - 14.0, text_y)
	fx.text = text
	fx.add_theme_color_override("font_color", color)
	fx.modulate = Color.WHITE
	fx.visible = true
	if fx.get_parent() == null:
		world.add_child(fx)
	var tween := create_tween()
	tween.set_parallel(true)
	var rise := 36.0 if hold > 0.5 else 18.0
	tween.tween_property(fx, "position:y", maxf(8.0, fx.position.y - rise), hold)
	tween.tween_property(fx, "modulate", Color(1, 1, 1, 0), hold)
	tween.chain().tween_callback(_recycle_hit_fx.bind(fx))

func _recycle_hit_fx(fx: Label) -> void:
	if not is_instance_valid(fx):
		return
	fx.visible = false
	fx.modulate = Color.WHITE
	hit_fx_pool.append(fx)

func _finish_battle(won: bool, message: String) -> void:
	if battle_ended:
		return
	battle_ended = true
	battle_active = false
	battle_won = won
	_update_progress_ui()
	AudioManager.play_sfx("victory" if won else "defeat")
	if fx_manager != null:
		if won:
			fx_manager.emit_victory(Vector2(360, BATTLE_GROUND_Y - 42.0), Color("#ffd273"), current_era)
	print("战斗结束: %s" % message)
	if won:
		var reward := _era_amount(VICTORY_REWARD_BASE)
		_change_coins(reward)
		_finish_round("%s\n获得 +%d 金币" % [message, reward])
	else:
		_finish_round(message)

func _change_coins(amount: int) -> void:
	coin_count = maxi(0, coin_count + amount)
	_update_coin_ui()

func _living_units(side: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit in battle_units:
		if is_instance_valid(unit) and unit.alive and unit.faction == side:
			result.append(unit)
	return result

func _remove_battle_units() -> void:
	for unit in battle_units:
		if is_instance_valid(unit):
			unit.queue_free()
	battle_units.clear()
	if world != null:
		for child in world.get_children():
			if child is Projectile:
				child.queue_free()

func _finish_round(message: String) -> void:
	var best_score := maxi(SaveManager.get_best_score(), kill_score)
	SaveManager.set_best_score(best_score)
	status_label.text = "%s\n本局积分 %d（最高 %d）" % [message, kill_score, best_score]
	if result_overlay != null:
		result_overlay.visible = true

func _outline(label: Label, size: int, color := Color("#2b1409")) -> void:
	label.add_theme_constant_override("outline_size", size)
	label.add_theme_color_override("font_outline_color", color)

func _build_wave_bar() -> void:
	# 植物大战僵尸式波次进度条：走满一格 = 一波，走到头就是整备期
	wave_bar = ProgressBar.new()
	wave_bar.position = Vector2(360, 12)
	wave_bar.size = Vector2(268, 30)
	wave_bar.min_value = 0.0
	wave_bar.max_value = 1.0
	wave_bar.step = 0.001
	wave_bar.show_percentage = false
	wave_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_bar.add_theme_stylebox_override("background", _panel_style(Color("#4a2b1b"), Color("#2b1409"), 14, 2))
	wave_bar.add_theme_stylebox_override("fill", _panel_style(Color("#4cbf4c"), Color("#2b1409"), 14, 0))
	board.add_child(wave_bar)
	wave_bar_label = _label(board, "", Vector2(360, 15), Vector2(268, 26), 16, Color("#ffffff"))
	wave_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(wave_bar_label, 6)

func _update_wave_bar() -> void:
	if wave_bar == null:
		return
	var in_wave := 0.0
	if wave_spawning:
		in_wave = clampf(1.0 - wave_active_timer / WAVE_DURATION, 0.0, 1.0)
	var done_waves := wave_number % PREP_WAVE_INTERVAL
	if wave_spawning and done_waves > 0:
		done_waves -= 1
	elif wave_spawning:
		done_waves = PREP_WAVE_INTERVAL - 1
	var ratio := clampf((float(done_waves) + in_wave) / float(PREP_WAVE_INTERVAL), 0.0, 1.0)
	wave_bar.value = ratio
	wave_bar.add_theme_stylebox_override("fill", _panel_style(Color("#4cbf4c").lerp(Color("#e2452f"), ratio), Color("#2b1409"), 14, 0))
	if not battle_active or battle_ended:
		wave_bar_label.text = "备战中"
		wave_bar.value = 0.0
	elif paused and auto_prep:
		wave_bar_label.text = "整备期"
	elif wave_number <= 0:
		wave_bar_label.text = "敌军将至"
	else:
		wave_bar_label.text = "第 %d 波" % wave_number

func _update_progress_ui() -> void:
	_update_wave_bar()
	if era_label == null:
		return
	var state := "备战"
	if battle_ended:
		state = "已通关" if battle_won else "已失守"
	elif battle_active:
		state = "战斗中"
	if battle_active and not battle_ended:
		if paused and auto_prep:
			state = "整备中"
		elif prep_pending:
			state = "本波结束进入整备"
		else:
			state = "距下次整备 %d 波" % (PREP_WAVE_INTERVAL - wave_number % PREP_WAVE_INTERVAL)
	era_label.text = "%s · 第 %d 轮 · %s" % [GameData.ERA_NAMES.get(current_era, current_era), round_number, state]
	if battle_active and not battle_ended:
		score_label.text = "积分 %d · 第 %d 波 · 敌 %d" % [kill_score, wave_number, _living_units("enemy").size()]
	else:
		score_label.text = "击杀积分 %d" % kill_score
	if deck_label != null:
		deck_label.text = "剩 %d 张" % deck_cards.size()

func _update_tower_ui() -> void:
	if ally_tower_bar == null:
		return
	ally_tower_bar.set_health(ally_tower_hp, ally_tower_max_hp)
	enemy_tower_bar.set_health(enemy_tower_hp, enemy_tower_max_hp)
	if ally_tower_max_hp > 0.0:
		var health_ratio := ally_tower_hp / ally_tower_max_hp
		if health_ratio <= 0.25 and not ally_alarm_25_played:
			ally_alarm_25_played = true
			AudioManager.play_sfx("tower_alarm", {"priority": 0, "throttle_ms": 0})
		elif health_ratio <= 0.5 and not ally_alarm_50_played:
			ally_alarm_50_played = true
			AudioManager.play_sfx("tower_alarm", {"priority": 0, "throttle_ms": 0})
