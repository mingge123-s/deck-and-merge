extends Node2D

const VIEW_SIZE := Vector2(720, 1280)
const BATTLE_RECT := Rect2(36, 36, 648, 300)
const TRAY_RECT := Rect2(36, 352, 648, 156)
const BOARD_RECT := Rect2(36, 604, 648, 636)
const INFO_BAR_RECT := Rect2(36, 524, 648, 64)
const CARD_SIZE := Vector2(138, 166)
const TRAY_SLOT_SIZE := Vector2(80, 80)
const TRAY_SLOT_STEP := 89.0
const TRAY_SLOT_ORIGIN := Vector2(16, 48)
const DECK_LOW_MARGIN := 12 # 牌堆少于目标-12张才触发补牌；每次把缺口最大的卡补齐到目标(单张单批≤3)
const TRAY_SLOTS := 7
const PREP_WAVE_INTERVAL := 3
const WAVE_DURATION := 180.0
# 每关「目标用时」（速度奖励基准，不再超时判负）。
# 进关时启动并累计已用时间；过关进入下一关时换本关目标并重新计时。
# 与 WAVE_DURATION（单波出兵窗口）不同——这是打爆本关敌塔的速度参考预算。
# 暂停 / 奖励面板打开时冻结（不罚玩家看选项）。可按难度、按关卡 index 0..4 配置。
# 第 2 关目标 = 第 1 关 ×2（仅评级/金币倍率用，倒计时归零不失败）。
const STAGE_TIME_LIMIT := {
	"easy": [240.0, 480.0, 240.0, 240.0, 240.0],
	"normal": [180.0, 360.0, 180.0, 180.0, 180.0],
	"hard": [150.0, 300.0, 150.0, 150.0, 150.0],
}
## AI 经济倍率（敌方击杀/涓流收入）；玩家击杀金币已归零，不再乘此值
const KILL_COIN_MULT := 0.2
## 方案甲：玩家击杀/塔击杀金币固定为 0（防刷改由速度过关金解决）
const PLAYER_KILL_GOLD := 0
## 击杀积分弱化系数（磨兵收益下降；过关关卡分+速度分成为主体）
const KILL_SCORE_MULT := 0.25
const STARTING_COINS := 400
## 过关金币基础（再 × 关卡时代倍率 × 难度系数 × 速度倍率）
const CLEAR_GOLD_BASE := 180
const CLEAR_GOLD_DIFF_MULT := {"easy": 1.15, "normal": 1.0, "hard": 0.9}
const CLEAR_GOLD_SPEED_MIN := 0.35
const CLEAR_GOLD_SPEED_MAX := 1.6
## 过关积分：关卡分（随关卡略增）+ 速度分（随速度倍率）
const STAGE_SCORE_BASE := 800
const SPEED_SCORE_BASE := 400
const BOUNTY_INSTANT_GOLD := 80
const BOUNTY_CLEAR_GOLD_MULT := 1.25
# 关卡制：敌方关卡只靠打爆敌塔推进；玩家牌池时代额外按本关轮次升级
const ERA_UP_ROUNDS := [2, 4, 7, 10] # 相对本关起始时代，在这些轮次各升一级牌池时代
const BATCH_BASE_GROUPS := 60
const BATCH_GROUP_STEP := 10
const MIN_BOSS_GROUPS := 2 # 每批保底当前时代 BOSS 组数（保证至少能合成）
const DIFFICULTIES := {
	"easy": {"name": "简单", "wave_min": 6.0, "first_delay": 7.0, "enemy_mult": 0.6, "boss_wave": 8, "tower_mult": 1.9, "ai_income_mult": 0.6, "ai_trickle": 0.3, "ai_effect_chance": 0.25},
	"normal": {"name": "普通", "wave_min": 5.0, "first_delay": 4.0, "enemy_mult": 1.0, "boss_wave": 5, "tower_mult": 1.1, "ai_income_mult": 1.0, "ai_trickle": 0.5, "ai_effect_chance": 0.4},
	"hard": {"name": "困难", "wave_min": 3.0, "first_delay": 3.0, "enemy_mult": 1.3, "boss_wave": 4, "tower_mult": 1.0, "ai_income_mult": 1.4, "ai_trickle": 0.8, "ai_effect_chance": 0.55},
}
const BATTLE_GROUND_Y := 222.0
const BATTLE_LANES := 5
const BATTLE_LANE_STEP := 11.0
const CAMERA_FOLLOW_SPEED := 4.0
const CAMERA_MANUAL_HOLD := 3.0
const SHAKE_JERK_THRESHOLD := 12.0 # 相邻两帧加速度变化超过该值判定为一次摇动
const SHAKE_COOLDOWN := 1.5
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
const RANGED_RANGE_MULT := 1.2 # 玩家远程单位的攻击距离提升 20%
const FRONT_TOLERANCE := 8.0
## 被身后近战/英雄打中后，短时优先还击该攻击者（方案 A；前方优先仍为默认）
const BACKSTAB_RETALIATE_DURATION := 2.0
const SANDBOX_SIDE_CAP := 20
const TOUCH_SCROLL_CLICK_THRESHOLD := 12.0
const UNIT_CAP := 30
const ENEMY_UNIT_CAP := 60 # 敌方同屏上限（AI出兵x5后需高于己方）
const RANDOM_EFFECT_PRICE_BASE := 260
const CLEAR_TRAY_COST := 100
# 少于这个张数清空没有意义（凑不出三连也不会卡台）
const MIN_CLEAR_TRAY_CARDS := 3
const RESHUFFLE_COST := 200
# 奖励面板刷新（重roll 三选一）花费的金币，便于以后调整
const REWARD_REROLL_COST := 100
const AI_EFFECT_CD := 8.0
# weight 越大越常见（按强度分档：常见 10 / 中等 6 / 稀有 3 / 极稀有 1）
const RANDOM_EFFECTS := [
	{"id": "reinforcement", "name": "召唤援军", "desc": "立刻召唤 1 个随机时代的随机英雄", "duration": 0.0, "weight": 3.0},
	{"id": "boss_call", "name": "BOSS 召唤", "desc": "立刻出战 1 个当前时代的 BOSS 英雄", "duration": 0.0, "weight": 1.0},
	{"id": "field_aid", "name": "战场急救", "desc": "我方全体回复 40% 生命", "duration": 0.0, "weight": 6.0},
	{"id": "freeze", "name": "冰冻力场", "desc": "敌方全体停止行动 3 秒", "duration": 3.0, "weight": 6.0},
	{"id": "frenzy", "name": "狂暴号角", "desc": "我方攻速 +40%，持续 20 秒", "duration": 20.0, "weight": 10.0},
	{"id": "morale", "name": "战意鼓舞", "desc": "我方攻击 +25%，持续 30 秒", "duration": 30.0, "weight": 10.0},
	{"id": "bulwark", "name": "铁壁阵型", "desc": "我方受到伤害 -30%，持续 30 秒", "duration": 30.0, "weight": 10.0},
	{"id": "haste", "name": "疾行药剂", "desc": "我方移速 +50%，持续 20 秒", "duration": 20.0, "weight": 10.0},
	{"id": "lifesteal", "name": "吸血图腾", "desc": "我方造成伤害的 20% 转为治疗，持续 30 秒", "duration": 30.0, "weight": 10.0},
	{"id": "thorns", "name": "荆棘护甲", "desc": "我方受到近战伤害时反弹 30%，持续 30 秒", "duration": 30.0, "weight": 10.0},
	{"id": "tower_repair", "name": "修复我方塔", "desc": "我方塔回复 25% 满血", "duration": 0.0, "weight": 6.0},
	{"id": "tower_power", "name": "塔炮升级", "desc": "我方塔攻击 +50%，整局有效", "duration": 0.0, "weight": 3.0},
	{"id": "bounty", "name": "疾战悬赏", "desc": "立即获得 80 金币（随时代缩放）；30 秒内过关金币 +25%", "duration": 30.0, "weight": 6.0},
]
## 合成台上长按多久弹卡牌详情
const CARD_INFO_HOLD := 0.4
const EFFECT_ICON_PATH := "res://assets/icons/effects/%s.png"
const REWARD_ICON_PATH := "res://assets/icons/rewards/%s.png"
const SKILL_ICON_PATH := "res://assets/icons/skills/%s.png"
## 致盲状态下普攻的失手概率
const BLIND_MISS_CHANCE := 0.5
const EFFECT_CARD_PREFIX := "effect_"
const EFFECT_CARD_PAIR_SIZE := 2
## 每批发多少「对」效果卡：基础对数 + 随轮次增长（每 EFFECT_PAIRS_ROUND_STEP 轮 +1 对），上限封顶
const EFFECT_PAIRS_BASE := 4
const EFFECT_PAIRS_ROUND_STEP := 2
const EFFECT_PAIRS_MAX := 8
const EFFECT_CARD_COLOR := Color("#8754d8")
const TUTORIAL_STEPS := [
	{
		"title": "欢迎来到牌桌远征",
		"text": "目标：打爆敌方防御塔即[b]过关[/b]，自己的塔被打爆则失败。共 5 关，打爆第 5 关敌塔获胜。\n跟着下面几步走一遍，十秒学会。",
		"rect": Rect2(),
	},
	{
		"title": "第 1 步：从牌堆取牌",
		"text": "这里是牌堆。点击[b]没被压住[/b]的卡牌，它会飞进上方的合成台；被压在下面的卡点不动。\n牌堆取空就进入[b]本关下一轮[/b]，自动发一批新牌，并逐轮混入[b]更高时代[/b]的卡。",
		"rect": BOARD_RECT,
	},
	{
		"title": "第 2 步：在合成台合成",
		"text": "合成台共 7 格。小兵卡[b]3 张同名[/b]自动合成英雄并上场；效果卡[b]2 张同名[/b]立刻发动（召唤援军、修复我方塔、塔炮升级等）。\n注意：7 格放满且凑不出任何合成时，会自动扣 100 金币清空，金币不足就判负。别乱收用不上的牌。\n信息栏上的[b]清空[/b]方块按钮（重排左侧）可随时手动清空，卡牌会补回牌堆底；有免费清空次数时优先消耗免费次数（角标显示剩余次数）。",
		"rect": TRAY_RECT,
	},
	{
		"title": "第 3 步：看战场",
		"text": "合成出的英雄会自动前进作战，你不用指挥。左右拖动可查看整个战场，右上角小地图显示双方单位与塔血。\n敌人按波次持续进攻；[b]金币主要靠尽快打爆敌塔[/b]（用时越短奖励越高），击杀本身不再刷金币。",
		"rect": BATTLE_RECT,
	},
	{
		"title": "第 4 步：关卡与轮次",
		"text": "信息栏显示当前[b]关卡[/b]、本关轮次、金币与积分（波次进度条在牌堆上方）。信息栏 ⏱ 显示本关[b]已用时间与速度评级[/b]（对照目标用时，暂停/选增益时冻结）——[b]倒计时归零不会判负[/b]，但越快过关金币与速度分越高。共 5 关：第 1 关石器 → 第 2 关铁器 → 第 3 关工业 → 第 4 关现代 → 第 5 关未来。\n[b]打爆敌塔即过关[/b]：选完增益后直接进下一关——当前牌堆与合成台剩牌作废，双方小兵全部消失，双方塔满血重建，发本关第 1 轮牌；金币与永久增益保留。关卡越高，双方塔血与敌方出兵越强。信息栏左端是 ≡ 主界面，右端一排依次是清空 / 重排 / 暂停 / [b]?[/b]，点最右的 [b]?[/b] 可随时重看本教程。",
		"rect": INFO_BAR_RECT,
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
var tray_slot_panels: Array[Panel] = []
var tray_slots := TRAY_SLOTS
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
var score_label: Label
var era_label: Label
var deck_label: Label
var stage_timer_label: Label
var reshuffle_button: Button
var reshuffle_confirm_overlay: Control
var clear_tray_button: Button
var clear_tray_badge: Label
var clear_tray_confirm_overlay: Control
var status_label: Label
var update_status_label: Label
var update_restart_overlay: Control
var update_restart_notes_label: Label
var restart_button: Button
var result_menu_button: Button
var return_button: Button
var pause_button: Button
var main_menu: Control
var settings_panel: Panel
var leaderboard_panel: Panel
var leaderboard_rows: VBoxContainer
var era_select_panel: Panel
var sandbox_panel: Panel
var sandbox_control_panel: Panel
var sandbox_status_label: Label
var sandbox_start_button: Button
var sandbox_ally_count_labels: Dictionary = {}
var sandbox_enemy_count_labels: Dictionary = {}
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
var codex_panel: Panel
var codex_rows: VBoxContainer
var codex_category := "unit"
var codex_category_buttons: Dictionary = {}
var codex_detail_overlay: Control
var codex_detail_icon: TextureRect
var codex_detail_unit_icon: TextureRect
var codex_detail_icon_label: Label
var codex_detail_unit_icon_label: Label
var codex_detail_title: Label
var codex_detail_text: RichTextLabel
var tray_press_index := -1
var touch_scroll_press_position := Vector2.ZERO
var touch_scroll_press_button: Button
var touch_scroll_dragged := false
var touch_scroll_hover_button: Button
var touch_scroll_pressed_button: Button
var wave_bar: ProgressBar
var wave_bar_label: Label
var result_overlay: Control
var music_slider: HSlider
var sfx_slider: HSlider
var battle_hint: Label
var boss_entry_overlay: Control
var boss_entry_banner: Label
var boss_entry_tween: Tween
var toast_overlay: Control
var toast_panel: Panel
var toast_label: Label
var toast_tween: Tween
var ally_tower_bar: TowerHealthBar
var enemy_tower_bar: TowerHealthBar
var battle_active := false
var battle_ended := false
var battle_won := false
var sandbox_mode := false
var sandbox_ally_counts: Dictionary = {}
var sandbox_enemy_counts: Dictionary = {}
var paused := false
var wave_min_timer := 0.0
var wave_spawning := false
var wave_active_timer := 0.0
var enemy_spawn_index := 0
var ai_spawn := AiSpawn.new()
var wave_number := 0
var round_number := 0
var base_era_index := 0
var ally_tower_cd := 0.0
var enemy_tower_cd := 0.0
var card_z_top := 0
var shake_cooldown := 0.0
var prev_accel := Vector3.ZERO
var accel_primed := false
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
var ally_lane_cursor := 0
var enemy_lane_cursor := 0
var stuck_warned := false
var reward_active := false
var stage_clear_pending := false
## 本关目标用时（秒）；stage_elapsed 为已用，stage_time_left 为距目标剩余（仅 UI/参考）
var stage_time_limit := 0.0
var stage_time_left := 0.0
var stage_elapsed := 0.0
## 本关是否已发放过关金币/关卡分（防重复）
var stage_clear_economy_awarded := false
var reward_overlay: Control
var reward_panel: Panel
var reward_buttons: Array[Button] = []
var reward_icons: Array[TextureRect] = []
var reward_name_labels: Array[Label] = []
var reward_desc_labels: Array[Label] = []
var reward_options: Array[Dictionary] = []
var reward_confirm_button: Button
var reward_reroll_button: Button
var reward_selected_index := -1
var reward_context := "round"
var reward_title_label: Label
var run_atk_mult := 1.0
var run_hp_mult := 1.0
var run_aspd_mult := 1.0
var run_move_mult := 1.0
var run_crit_chance := 0.0
var run_lifesteal := 0.0
var run_tank_reduce := 0.0
var run_ranged_atk_mult := 1.0
var run_assassin_crit_chance := 0.0
var run_assassin_crit_mult := 0.0
var run_stun_mult := 1.0
## 己方塔满血倍率（塔壁奖励等永久项，过关重建时仍生效）
var run_tower_hp_mult := 1.0
var run_hero_mult: Dictionary = {}
var free_reshuffles := 0
var free_clear_tokens := 0
var round_weight_mult: Dictionary = {}
var round_removed_cards: Array[String] = []
var round_no_effect_cards := false
var round_effect_pairs_bonus := 0
var round_extra_tray_slots := 0
var round_coin_mult := 1.0
var round_initial_energy := 0
var round_tower_thorns := false
var round_tower_regen := false
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

func _effect_weight(effect: Dictionary) -> float:
	return maxf(0.0, float(effect.get("weight", 1.0)))

func _weighted_random_effect_id() -> String:
	var total := 0.0
	for effect in RANDOM_EFFECTS:
		total += _effect_weight(effect)
	if total <= 0.0:
		return str(RANDOM_EFFECTS[rng.randi_range(0, RANDOM_EFFECTS.size() - 1)].id)
	var roll := rng.randf() * total
	for effect in RANDOM_EFFECTS:
		roll -= _effect_weight(effect)
		if roll <= 0.0:
			return str(effect.id)
	return str(RANDOM_EFFECTS[RANDOM_EFFECTS.size() - 1].id)

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
	coin_count = STARTING_COINS
	rng.randomize()
	_setup_ai_spawn()
	for effect in RANDOM_EFFECTS:
		if str(effect.id) != "bounty":
			ai_effects.append(effect)
	_build_background()
	_build_top_bar()
	_build_board()
	_build_tray()
	_build_battlefield()
	_build_reward_overlay()
	_build_overlay()
	_build_main_menu()
	_build_sandbox_control_panel()
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
	_poll_shake_input(delta)
	if paused:
		return
	if reward_active:
		_update_minimap()
		return
	_update_minimap()
	if not battle_active or battle_ended:
		return
	if sandbox_mode:
		fx_unit_count_cache = _living_units("ally").size() + _living_units("enemy").size()
		_tick_buffs(delta)
		_sync_persistent_status_vfx(delta)
		_update_tower_alarm_vfx(delta)
		_step_battle(delta)
		_update_camera_follow(delta)
		_update_tower_ui()
		_update_sandbox_status()
		_check_sandbox_end()
		return
	fx_unit_count_cache = _living_units("ally").size() + _living_units("enemy").size()
	_tick_buffs(delta)
	_tick_stage_timer(delta)
	if battle_ended:
		return
	if round_tower_regen and ally_tower_hp > 0.0:
		ally_tower_hp = minf(ally_tower_max_hp, ally_tower_hp + ally_tower_max_hp * 0.02 * delta)
	_sync_persistent_status_vfx(delta)
	_update_tower_alarm_vfx(delta)
	_update_wave_bar()
	if wave_spawning:
		wave_active_timer -= delta
		if wave_active_timer <= 0.0:
			wave_spawning = false
		else:
			ai_spawn.tick(delta)
	wave_min_timer -= delta
	enemy_coin += float(_diff().ai_trickle) * KILL_COIN_MULT * delta
	enemy_effect_cd = maxf(0.0, enemy_effect_cd - delta)
	if enemy_tower_max_hp > 0.0 and enemy_tower_hp > 0.0:
		var enemy_tower_ratio := enemy_tower_hp / enemy_tower_max_hp
		if enemy_tower_ratio < 0.1 and enemy_rally_fired == 0:
			_enemy_rally_surge()
			enemy_rally_fired = 1
		elif enemy_tower_ratio >= 0.1:
			enemy_rally_fired = 0
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

func _poll_shake_input(delta: float) -> void:
	var accel := Input.get_accelerometer()
	if accel == Vector3.ZERO:
		accel = Input.get_gravity()
	if accel_primed:
		if (accel - prev_accel).length() > SHAKE_JERK_THRESHOLD and shake_cooldown <= 0.0:
			_try_shake_deck()
	else:
		accel_primed = true
	prev_accel = accel
	shake_cooldown = maxf(0.0, shake_cooldown - delta)

func _input(event: InputEvent) -> void:
	# 桌面调试：按 S 模拟摇一摇（与按钮同费用/同规则）
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		_try_shake_deck()

func _try_shake_deck() -> void:
	if shake_cooldown > 0.0:
		return
	if not battle_active or battle_ended:
		return
	shake_cooldown = SHAKE_COOLDOWN
	# 禁止免费绕过：与信息栏重排按钮走同一入口（含首次确认/扣费/拦截 toast）
	_on_reshuffle_pressed()

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
	bar.position = INFO_BAR_RECT.position
	bar.size = INFO_BAR_RECT.size
	bar.add_theme_stylebox_override("panel", _panel_style(Color("#a75d38"), Color("#633822"), 19, 3))
	add_child(bar)
	return_button = Button.new()
	return_button.position = Vector2(12, 9)
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
	pause_button.position = Vector2(536, 9)
	pause_button.size = Vector2(46, 46)
	pause_button.tooltip_text = "暂停"
	pause_button.icon = load("res://assets/ui/pause_icon.png")
	pause_button.expand_icon = true
	pause_button.add_theme_constant_override("icon_max_width", 26)
	pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 12, 2))
	pause_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 12, 2))
	pause_button.pressed.connect(_toggle_pause)
	pause_button.pressed.connect(_play_button_sfx)
	pause_button.visible = false
	bar.add_child(pause_button)
	help_button = Button.new()
	help_button.position = Vector2(592, 9)
	help_button.size = Vector2(46, 46)
	help_button.text = "?"
	help_button.tooltip_text = "玩法介绍"
	help_button.add_theme_font_size_override("font_size", 22)
	help_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 12, 2))
	help_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 12, 2))
	help_button.pressed.connect(_show_tutorial)
	help_button.pressed.connect(_play_button_sfx)
	bar.add_child(help_button)
	coin_label = _label(bar, "", Vector2(70, 18), Vector2(140, 28), 16, Color("#fff0c7"))
	score_label = _label(bar, "", Vector2(70, 40), Vector2(160, 22), 13, Color("#f6d69f"))
	era_label = _label(bar, "", Vector2(215, 22), Vector2(200, 20), 12, Color("#f6d69f"))
	# 倒计时右缘须避开清空按钮（x=424），避免与顶栏右侧方块按钮重叠
	stage_timer_label = _label(bar, "⏱ --:--", Vector2(250, 38), Vector2(160, 24), 17, Color("#f6d69f"))
	_outline(stage_timer_label, 4)
	clear_tray_button = Button.new()
	clear_tray_button.position = Vector2(424, 9)
	clear_tray_button.size = Vector2(46, 46)
	clear_tray_button.tooltip_text = "清空合成台，卡牌补回牌堆底（-%d 金币，有免费次数时优先用免费）" % CLEAR_TRAY_COST
	clear_tray_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 12, 2))
	clear_tray_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 12, 2))
	clear_tray_button.add_theme_stylebox_override("pressed", _panel_style(Color("#c9702f"), Color("#713722"), 12, 2))
	clear_tray_button.add_theme_stylebox_override("disabled", _panel_style(Color("#9c6b45"), Color("#5e3320"), 12, 2))
	clear_tray_button.icon = load("res://assets/ui/clear_tray_icon.png")
	clear_tray_button.expand_icon = true
	clear_tray_button.add_theme_constant_override("icon_max_width", 30)
	clear_tray_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_tray_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	clear_tray_button.pressed.connect(_on_clear_tray_pressed)
	clear_tray_button.pressed.connect(_play_button_sfx)
	bar.add_child(clear_tray_button)
	clear_tray_badge = Label.new()
	clear_tray_badge.position = Vector2(26, -4)
	clear_tray_badge.size = Vector2(24, 20)
	clear_tray_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_tray_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clear_tray_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear_tray_badge.add_theme_font_size_override("font_size", 13)
	clear_tray_badge.add_theme_color_override("font_color", Color("#fff6d0"))
	_outline(clear_tray_badge, 3)
	clear_tray_badge.visible = false
	clear_tray_button.add_child(clear_tray_badge)
	reshuffle_button = Button.new()
	reshuffle_button.position = Vector2(480, 9)
	reshuffle_button.size = Vector2(46, 46)
	reshuffle_button.tooltip_text = "重排牌序（-%d 金币）" % RESHUFFLE_COST
	reshuffle_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 12, 2))
	reshuffle_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 12, 2))
	reshuffle_button.add_theme_stylebox_override("pressed", _panel_style(Color("#c9702f"), Color("#713722"), 12, 2))
	reshuffle_button.add_theme_stylebox_override("disabled", _panel_style(Color("#9c6b45"), Color("#5e3320"), 12, 2))
	reshuffle_button.icon = load("res://assets/ui/reshuffle_icon.png")
	reshuffle_button.expand_icon = true
	reshuffle_button.add_theme_constant_override("icon_max_width", 30)
	reshuffle_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reshuffle_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	reshuffle_button.pressed.connect(_on_reshuffle_pressed)
	reshuffle_button.pressed.connect(_play_button_sfx)
	bar.add_child(reshuffle_button)
	_update_progress_ui()
	_update_coin_ui()
	_update_clear_tray_button()

func _update_coin_ui() -> void:
	if coin_label != null:
		coin_label.text = "💰  %d" % coin_count
	_update_reshuffle_button()

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
	_label(tray, "小兵 3 张合成 · 效果 2 张发动", Vector2(168, 13), Vector2(300, 22), 12, Color("#765035"))
	for index in range(TRAY_SLOTS + 1):
		var slot := Panel.new()
		slot.size = TRAY_SLOT_SIZE
		slot.add_theme_stylebox_override("panel", _panel_style(Color("#aa7044", 0.25), Color("#a66e43"), 12, 2))
		tray.add_child(slot)
		tray_slot_panels.append(slot)
	_layout_tray_slots()

func _layout_tray_slots() -> void:
	if tray == null or tray_slot_panels.is_empty():
		return
	var step := (tray.size.x - TRAY_SLOT_ORIGIN.x * 2.0 - TRAY_SLOT_SIZE.x) / float(maxi(tray_slots - 1, 1))
	for index in range(tray_slot_panels.size()):
		var slot := tray_slot_panels[index]
		slot.visible = index < tray_slots
		slot.position = TRAY_SLOT_ORIGIN + Vector2(step * index, 0)

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
	toast_overlay = Control.new()
	# 拦截提示靠近信息栏；z 高于 pause_overlay，整备/暂停时仍可见
	toast_overlay.position = Vector2(0.0, INFO_BAR_RECT.position.y - 72.0)
	toast_overlay.size = Vector2(VIEW_SIZE.x, 72.0)
	toast_overlay.z_index = 4096
	toast_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_overlay)
	toast_panel = Panel.new()
	toast_panel.size = Vector2(380, 56)
	toast_panel.position = Vector2((VIEW_SIZE.x - 380.0) * 0.5, 8.0)
	toast_panel.add_theme_stylebox_override("panel", _panel_style(Color("#3a2016", 0.92), Color("#ffd273"), 14, 2))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_overlay.add_child(toast_panel)
	toast_label = _label(toast_panel, "", Vector2(10, 0), Vector2(360, 56), 15, Color("#ffe9b8"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_overlay.visible = false
	minimap = BattleMinimap.new()
	minimap.position = Vector2(462, 8)
	minimap.size = Vector2(176, 46)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.configure(WORLD_WIDTH, BATTLE_VIEW_W)
	battlefield.add_child(minimap)
	_create_tower_ui(true)
	_create_tower_ui(false)
	_apply_camera()

func _build_reward_overlay() -> void:
	reward_overlay = Control.new()
	reward_overlay.size = VIEW_SIZE
	reward_overlay.z_index = 200
	reward_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(reward_overlay)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color(0.05, 0.02, 0.01, 0.78)
	reward_overlay.add_child(shade)
	reward_panel = Panel.new()
	reward_panel.size = Vector2(680, 620)
	reward_panel.position = Vector2((VIEW_SIZE.x - reward_panel.size.x) * 0.5, 300)
	reward_panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#ffd273"), 24, 3))
	reward_overlay.add_child(reward_panel)
	var title := _label(reward_panel, "选择一项增益", Vector2(0, 34), Vector2(680, 52), 30, Color("#fff0c7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_title_label = title
	for index in range(3):
		var button := Button.new()
		button.position = Vector2(24 + index * 224, 130)
		button.size = Vector2(208, 360)
		button.add_theme_stylebox_override("normal", _panel_style(Color("#c58a53"), Color("#ffd273"), 20, 3))
		button.add_theme_stylebox_override("hover", _panel_style(Color("#e0a05e"), Color("#ffe19a"), 20, 3))
		button.add_theme_stylebox_override("pressed", _panel_style(Color("#b87549"), Color("#ffd273"), 20, 3))
		button.pressed.connect(_play_button_sfx)
		button.pressed.connect(_on_reward_button_pressed.bind(index))
		reward_panel.add_child(button)
		reward_buttons.append(button)
		var icon := TextureRect.new()
		icon.position = Vector2(48, 24)
		icon.size = Vector2(112, 112)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		reward_icons.append(icon)
		var name_label := _label(button, "", Vector2(12, 150), Vector2(184, 54), 20, Color("#fff0c7"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_name_labels.append(name_label)
		var desc_label := _label(button, "", Vector2(14, 214), Vector2(180, 128), 15, Color("#f0dcb4"))
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_desc_labels.append(desc_label)
	reward_confirm_button = Button.new()
	reward_confirm_button.size = Vector2(240, 72)
	reward_confirm_button.position = Vector2((reward_panel.size.x - 240) * 0.5, 516)
	reward_confirm_button.text = "确认"
	reward_confirm_button.add_theme_font_size_override("font_size", 26)
	reward_confirm_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 18, 3))
	reward_confirm_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 18, 3))
	reward_confirm_button.add_theme_stylebox_override("pressed", _panel_style(Color("#c9702f"), Color("#713722"), 18, 3))
	reward_confirm_button.add_theme_stylebox_override("disabled", _panel_style(Color("#9c6b45"), Color("#5e3320"), 18, 3))
	reward_confirm_button.add_theme_color_override("font_disabled_color", Color("#c9b394"))
	reward_confirm_button.disabled = true
	reward_confirm_button.pressed.connect(_play_button_sfx)
	reward_confirm_button.pressed.connect(_on_reward_confirm_pressed)
	reward_panel.add_child(reward_confirm_button)
	reward_reroll_button = Button.new()
	reward_reroll_button.size = Vector2(180, 64)
	reward_reroll_button.position = Vector2(24, 520)
	reward_reroll_button.text = "刷新（%d）" % REWARD_REROLL_COST
	reward_reroll_button.add_theme_font_size_override("font_size", 20)
	reward_reroll_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 16, 3))
	reward_reroll_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 16, 3))
	reward_reroll_button.add_theme_stylebox_override("pressed", _panel_style(Color("#c9702f"), Color("#713722"), 16, 3))
	reward_reroll_button.add_theme_stylebox_override("disabled", _panel_style(Color("#9c6b45"), Color("#5e3320"), 16, 3))
	reward_reroll_button.add_theme_color_override("font_disabled_color", Color("#c9b394"))
	reward_reroll_button.pressed.connect(_play_button_sfx)
	reward_reroll_button.pressed.connect(_on_reward_reroll_pressed)
	reward_panel.add_child(reward_reroll_button)
	reward_overlay.visible = false

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
		bar.show_phases = true
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
	restart_button.pressed.connect(_on_restart_pressed)
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
	_build_codex_detail_overlay()
	_build_reshuffle_confirm_overlay()
	_build_clear_tray_confirm_overlay()

func _build_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.size = VIEW_SIZE
	pause_overlay.z_index = 4000
	# 根节点放行：由 shade/cover/panel 各自拦截；INFO_BAR 镂空可点重排
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.visible = false
	add_child(pause_overlay)
	var info := INFO_BAR_RECT
	var shade_rects: Array[Rect2] = [
		Rect2(0.0, 0.0, VIEW_SIZE.x, info.position.y),
		Rect2(0.0, info.end.y, VIEW_SIZE.x, VIEW_SIZE.y - info.end.y),
		Rect2(0.0, info.position.y, info.position.x, info.size.y),
		Rect2(info.end.x, info.position.y, VIEW_SIZE.x - info.end.x, info.size.y),
	]
	for rect in shade_rects:
		var shade := ColorRect.new()
		shade.position = rect.position
		shade.size = rect.size
		shade.color = Color(0.04, 0.03, 0.02, 0.88)
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		pause_overlay.add_child(shade)
	for rect in [BATTLE_RECT, TRAY_RECT, BOARD_RECT]:
		var cover := ColorRect.new()
		cover.position = rect.position - Vector2(6, 6)
		cover.size = rect.size + Vector2(12, 12)
		cover.color = Color(0.06, 0.04, 0.03, 1.0)
		cover.mouse_filter = Control.MOUSE_FILTER_STOP
		pause_overlay.add_child(cover)
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
	enemy_spawn_index = 0
	ai_spawn.reset()
	ai_spawn.set_difficulty(current_difficulty)
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
	var solo_button := _menu_button(card, "单机闯关", Vector2(144, 406), Vector2(300, 50), 19)
	solo_button.pressed.connect(_show_era_select)
	var sandbox_button := _menu_button(card, "自定义对战", Vector2(144, 466), Vector2(300, 50), 19)
	sandbox_button.pressed.connect(_show_sandbox_config)
	var online_button := _menu_button(card, "联机匹配", Vector2(144, 526), Vector2(300, 50), 19)
	online_button.disabled = true
	online_button.tooltip_text = "敬请期待"
	var soon := _label(card, "敬请期待", Vector2(458, 538), Vector2(94, 24), 12, Color("#e6c199"))
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var settings_button := _menu_button(card, "设置", Vector2(144, 586), Vector2(142, 50), 19)
	settings_button.pressed.connect(_show_settings)
	var leaderboard_button := _menu_button(card, "排行榜", Vector2(302, 586), Vector2(142, 50), 19)
	leaderboard_button.pressed.connect(_show_leaderboard)
	var menu_help_button := _menu_button(card, "玩法介绍", Vector2(388, 34), Vector2(160, 50), 17)
	menu_help_button.pressed.connect(_show_tutorial)
	var codex_button := _menu_button(card, "图鉴", Vector2(40, 34), Vector2(160, 50), 17)
	codex_button.pressed.connect(_show_codex)
	var difficulty_label := _label(card, "难度", Vector2(0, 646), Vector2(588, 26), 15, Color("#fff0c7"))
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var difficulty_keys := ["easy", "normal", "hard"]
	var difficulty_x_positions := [150, 250, 350]
	for index in range(difficulty_keys.size()):
		var key: String = difficulty_keys[index]
		var button := _menu_button(card, DIFFICULTIES[key].name, Vector2(difficulty_x_positions[index], 676), Vector2(92, 44), 15)
		button.pressed.connect(_set_difficulty.bind(key))
		difficulty_buttons[key] = button
	_set_difficulty("normal")
	_label(card, "点击开始，自动进入战斗", Vector2(0, 732), Vector2(588, 28), 14, Color("#e6c199")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var check_update_button := _menu_button(card, "检查更新", Vector2(194, 772), Vector2(200, 42), 16)
	check_update_button.pressed.connect(_on_check_update_pressed)
	var version_label := _label(card, "内容版本 v%d" % Updater.installed_version, Vector2(0, 818), Vector2(588, 18), 12, Color("#e6c199"))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_status_label = _label(card, "", Vector2(0, 836), Vector2(588, 36), 14, Color("#ffe3a5"))
	update_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_settings_panel(card)
	_build_leaderboard_panel()
	_build_era_select_panel()
	_build_sandbox_config_panel()
	_build_codex_panel()
	_build_update_restart_overlay()

func _on_check_update_pressed() -> void:
	_play_button_sfx()
	Updater.check_for_update(true)

func _on_update_status(text: String) -> void:
	if update_status_label == null:
		return
	update_status_label.text = text
	# 待重启/下载完成：醒目强调；普通进度保持原色
	if text.find("退出") >= 0 or text.find("重启") >= 0 or text.begins_with("★"):
		update_status_label.add_theme_color_override("font_color", Color("#ffd36a"))
		update_status_label.add_theme_font_size_override("font_size", 15)
	elif text.find("失败") >= 0:
		update_status_label.add_theme_color_override("font_color", Color("#ffb0a0"))
		update_status_label.add_theme_font_size_override("font_size", 14)
	else:
		update_status_label.add_theme_color_override("font_color", Color("#ffe3a5"))
		update_status_label.add_theme_font_size_override("font_size", 14)

func _on_update_ready(version: int, notes: String) -> void:
	if update_status_label != null:
		update_status_label.text = "★ 已下载 v%d，请完全退出后再打开 ★" % version
		update_status_label.add_theme_color_override("font_color", Color("#ffd36a"))
		update_status_label.add_theme_font_size_override("font_size", 15)
	_show_update_restart_overlay(version, notes)

func _build_update_restart_overlay() -> void:
	update_restart_overlay = Control.new()
	update_restart_overlay.size = VIEW_SIZE
	update_restart_overlay.z_index = 4096
	update_restart_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	update_restart_overlay.visible = false
	add_child(update_restart_overlay)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color(0.05, 0.03, 0.02, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	update_restart_overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(70, 420)
	panel.size = Vector2(580, 340)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	update_restart_overlay.add_child(panel)
	var title := _label(panel, "更新已就绪", Vector2(0, 28), Vector2(580, 40), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var desc := _label(
		panel,
		"新内容已下载完成。\n请完全退出游戏后再次打开，更新才会生效。\n（返回桌面再点图标即可）",
		Vector2(36, 86),
		Vector2(508, 110),
		17,
		Color("#fff0c7")
	)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	update_restart_notes_label = _label(panel, "", Vector2(36, 200), Vector2(508, 48), 14, Color("#ffe3a5"))
	update_restart_notes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_restart_notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok_button := _menu_button(panel, "知道了", Vector2(190, 260), Vector2(200, 56), 20)
	ok_button.pressed.connect(_hide_update_restart_overlay)

func _show_update_restart_overlay(version: int, notes: String) -> void:
	if update_restart_overlay == null:
		return
	if update_restart_notes_label != null:
		var note_text := notes.strip_edges()
		if note_text == "":
			update_restart_notes_label.text = "内容版本 v%d" % version
		else:
			update_restart_notes_label.text = "v%d：%s" % [version, note_text]
	move_child(update_restart_overlay, get_child_count() - 1)
	update_restart_overlay.visible = true

func _hide_update_restart_overlay() -> void:
	if update_restart_overlay != null:
		update_restart_overlay.visible = false

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
	_hide_leaderboard()
	if settings_panel != null:
		settings_panel.visible = true

func _hide_settings() -> void:
	if settings_panel != null:
		settings_panel.visible = false

func _build_leaderboard_panel() -> void:
	leaderboard_panel = Panel.new()
	leaderboard_panel.name = "LeaderboardPanel"
	leaderboard_panel.position = Vector2(66, 190)
	leaderboard_panel.size = Vector2(588, 860)
	leaderboard_panel.z_index = 25
	leaderboard_panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	leaderboard_panel.visible = false
	main_menu.add_child(leaderboard_panel)
	var title := _label(leaderboard_panel, "本机排行榜", Vector2(0, 28), Vector2(588, 40), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(leaderboard_panel, "Top 10 · 本地记录", Vector2(0, 72), Vector2(588, 26), 15, Color("#e6c199"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var header := _label(
		leaderboard_panel,
		"名次　　积分　　难度　　到达　　时间",
		Vector2(36, 118),
		Vector2(516, 28),
		15,
		Color("#fff0c7")
	)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var divider := ColorRect.new()
	divider.position = Vector2(36, 150)
	divider.size = Vector2(516, 2)
	divider.color = Color("#70412c", 0.75)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaderboard_panel.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 164)
	scroll.size = Vector2(532, 580)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	leaderboard_panel.add_child(scroll)
	leaderboard_rows = VBoxContainer.new()
	leaderboard_rows.custom_minimum_size = Vector2(512, 0)
	leaderboard_rows.add_theme_constant_override("separation", 4)
	leaderboard_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(leaderboard_rows)
	var close_button := _menu_button(leaderboard_panel, "返回", Vector2(194, 770), Vector2(200, 54), 18)
	close_button.pressed.connect(_hide_leaderboard)

func _show_leaderboard() -> void:
	_hide_settings()
	_hide_era_select()
	_hide_sandbox_config()
	_hide_codex()
	_refresh_leaderboard_panel()
	if leaderboard_panel != null:
		leaderboard_panel.visible = true

func _hide_leaderboard() -> void:
	if leaderboard_panel != null:
		leaderboard_panel.visible = false

func _refresh_leaderboard_panel() -> void:
	if leaderboard_rows == null:
		return
	for child in leaderboard_rows.get_children():
		child.queue_free()
	var board: Array = SaveManager.get_leaderboard()
	var best := SaveManager.get_best_score()
	var best_text := "尚无记录，完成一局后结算入榜"
	if best > 0:
		best_text = "历史最高　%d" % best
	var best_line := _label(
		leaderboard_rows,
		best_text,
		Vector2.ZERO,
		Vector2(512, 30),
		16,
		Color("#ffe3a5")
	)
	best_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_line.custom_minimum_size = Vector2(512, 30)
	if board.is_empty():
		var empty := _label(leaderboard_rows, "——", Vector2.ZERO, Vector2(512, 36), 18, Color("#e6c199"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(512, 36)
		return
	for index in range(board.size()):
		var row: Dictionary = board[index]
		var score := int(row.get("score", 0))
		var diff_key := str(row.get("difficulty", "normal"))
		var diff_name := str(DIFFICULTIES.get(diff_key, {}).get("name", diff_key))
		var stage := int(row.get("stage_reached", 1))
		var stamp := int(row.get("timestamp", 0))
		var time_text := "—"
		if stamp > 0:
			var dt := Time.get_datetime_dict_from_unix_time(stamp)
			time_text = "%02d-%02d %02d:%02d" % [int(dt.month), int(dt.day), int(dt.hour), int(dt.minute)]
		var accent := Color("#fff0c7") if index > 0 else Color("#ffd273")
		var line := _label(
			leaderboard_rows,
			"%2d　　%6d　　%s　　第%d关　　%s" % [index + 1, score, diff_name, stage, time_text],
			Vector2.ZERO,
			Vector2(512, 40),
			16,
			accent
		)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.custom_minimum_size = Vector2(512, 40)

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
		"bounty":
			if actor == "ally":
				_change_coins(_era_amount(BOUNTY_INSTANT_GOLD))
			var bounty_timers: Dictionary = buff_timers if actor == "ally" else enemy_buff_timers
			bounty_timers[effect_id] = maxf(float(bounty_timers.get(effect_id, 0.0)), duration)
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

func _show_toast(text: String) -> void:
	if toast_overlay == null:
		return
	if toast_tween != null:
		toast_tween.kill()
	toast_label.text = text
	toast_overlay.visible = true
	toast_panel.modulate = Color(1, 1, 1, 0)
	toast_tween = create_tween()
	toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	toast_tween.tween_interval(1.6)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	toast_tween.tween_callback(func() -> void:
		if toast_overlay != null:
			toast_overlay.visible = false
	)

func _reward_pool() -> Array[String]:
	return [
		"tower_wall", "tower_repair", "tower_cannon", "tower_thorns", "tower_regen",
		"deck_boost", "deck_remove", "deck_elite", "effect_harvest", "deck_purge",
		"free_reshuffle", "bloodline", "tray_expand", "free_clear", "coin_bag",
		"loot_boost", "atk_up", "hp_up", "aspd_up", "move_up", "crit", "lifesteal",
		"tank_guard", "ranged_up", "assassin_crit", "energy_start", "stun_boost",
		"call_reinforce", "tower_overload",
	]

func _round_unit_cards() -> Array[String]:
	var result: Array[String] = []
	for card_id in GameData.cards_for_era(current_era):
		var hero := GameData.hero_for_card(card_id)
		if str(hero.get("role", "")) != "boss":
			result.append(str(card_id))
	return result

func _hero_name_for_card(card_id: String) -> String:
	var hero := GameData.hero_for_card(card_id)
	return str(hero.get("name", card_id))

func _roll_reward_option(reward_id: String) -> Dictionary:
	var option := {"id": reward_id, "name": reward_id, "desc": "", "card": "", "hero": ""}
	var unit_cards := _round_unit_cards()
	var card := ""
	if not unit_cards.is_empty():
		card = unit_cards[rng.randi_range(0, unit_cards.size() - 1)]
	var boss_card := _current_era_boss_card()
	var hero_ids := GameData.heroes_for_era(current_era)
	var hero_id := ""
	if not hero_ids.is_empty():
		hero_id = hero_ids[rng.randi_range(0, hero_ids.size() - 1)]
	option.card = card
	option.hero = hero_id
	match reward_id:
		"tower_wall":
			option.name = "壁垒加固"
			option.desc = "我方防御塔最大生命值提升 20%"
		"tower_repair":
			option.name = "紧急修复"
			option.desc = "立即将我方防御塔生命值恢复至满"
		"tower_cannon":
			option.name = "塔炮强化"
			option.desc = "我方防御塔攻击力提升 30%"
		"tower_thorns":
			option.name = "荆棘壁垒"
			option.desc = "本轮敌方近战攻击防御塔时，反弹 40% 伤害"
		"tower_regen":
			option.name = "自愈壁垒"
			option.desc = "本轮我方防御塔每秒恢复 2% 最大生命值"
		"deck_boost":
			option.name = "征募强化：%s" % _hero_name_for_card(card)
			option.desc = "本轮该单位卡的出现概率提升一倍"
		"deck_remove":
			option.name = "移除卡牌"
			option.desc = "本轮从抽牌池中移除 %s" % _hero_name_for_card(card)
		"deck_elite":
			option.name = "精英强化"
			option.desc = "本轮 %s 的出现概率提升至 3 倍" % _hero_name_for_card(boss_card)
			option.card = boss_card
		"effect_harvest":
			option.name = "效果丰收"
			option.desc = "本轮额外获得 2 对效果卡"
		"deck_purge":
			option.name = "净化牌堆"
			option.desc = "本轮不再出现效果卡"
		"free_reshuffle":
			option.name = "免费重排"
			option.desc = "获得 3 次免费重排牌序的机会"
		"bloodline":
			option.name = "血脉强化"
			option.desc = "%s 单位全属性提升 15%%" % str(GameData.HEROES[hero_id].get("name", hero_id))
		"tray_expand":
			option.name = "台面扩容"
			option.desc = "本轮合成台增加 1 格"
		"free_clear":
			option.name = "清台券"
			option.desc = "获得 1 张免费清台券"
		"coin_bag":
			option.name = "金币补给"
			option.desc = "立即获得 200 金币"
		"loot_boost":
			option.name = "疾战赏金"
			option.desc = "本轮过关金币提升 30%"
		"atk_up":
			option.name = "全军强攻"
			option.desc = "我方全体单位攻击力提升 10%"
		"hp_up":
			option.name = "全军健体"
			option.desc = "我方全体单位生命值提升 12%"
		"aspd_up":
			option.name = "全军迅击"
			option.desc = "我方全体单位攻击速度提升 10%"
		"move_up":
			option.name = "全军疾行"
			option.desc = "我方全体单位移动速度提升 12%"
		"crit":
			option.name = "致命一击"
			option.desc = "我方全体单位暴击率提升 10%"
		"lifesteal":
			option.name = "生命汲取"
			option.desc = "我方全体单位造成伤害的 8% 转化为治疗"
		"tank_guard":
			option.name = "坚盾守护"
			option.desc = "我方坦克单位受到的伤害降低 15%"
		"ranged_up":
			option.name = "远程精通"
			option.desc = "我方远程单位攻击力提升 20%"
		"assassin_crit":
			option.name = "刺客专精"
			option.desc = "我方刺客单位暴击率提升 25%，暴击伤害提升 0.5 倍"
		"energy_start":
			option.name = "充能启动"
			option.desc = "本轮我方技能初始能量增加 1 点"
		"stun_boost":
			option.name = "震慑强化"
			option.desc = "我方眩晕类技能的持续时间提升 50%"
		"call_reinforce":
			option.name = "紧急增援"
			option.desc = "立即召唤 3 个随机援军"
		"tower_overload":
			option.name = "塔炮过载"
			option.desc = "我方防御塔攻击力提升 50%"
	return option

func _show_round_reward() -> void:
	_show_reward("round")

func _show_stage_clear_reward() -> void:
	var award := _award_stage_clear_economy()
	_show_reward("stage_clear")
	if reward_title_label != null:
		# 过关奖励时仍停留在当前关：_stage_number()=N，下一关文案需 N+1
		reward_title_label.text = "过关！评级 %s · +%d 金 · 选择增益后进入%s" % [
			str(award.get("grade", "B")),
			int(award.get("gold", 0)),
			_stage_name(_stage_number() + 1),
		]

func _show_reward(context: String) -> void:
	if reward_overlay == null:
		return
	if reward_active:
		push_warning("_show_reward blocked: reward already active (context=%s, requested=%s)" % [reward_context, context])
		return
	reward_context = context
	if reward_title_label != null:
		if context == "stage_clear":
			# 标题由 _show_stage_clear_reward 写入速度/金币摘要；此处兜底
			reward_title_label.text = "过关！选择一项增益，随后进入%s" % _stage_name(_stage_number() + 1)
		else:
			reward_title_label.text = "选择一项增益"
	_roll_reward_options()
	_update_reward_reroll_button()
	reward_active = true
	reward_overlay.visible = true
	_update_clear_tray_button()

func _roll_reward_options() -> void:
	# 刷新奖励时重新随机三项，并清空当前选择，避免沿用旧奖励。
	var pool := _reward_pool()
	pool.shuffle()
	reward_options.clear()
	for index in range(3):
		reward_options.append(_roll_reward_option(pool[index]))
		var option := reward_options[index]
		reward_name_labels[index].text = str(option.name)
		reward_desc_labels[index].text = str(option.desc)
		var icon_path := REWARD_ICON_PATH % str(option.id)
		if ResourceLoader.exists(icon_path):
			reward_icons[index].texture = load(icon_path) as Texture2D
			reward_icons[index].visible = true
		else:
			reward_icons[index].texture = null
			reward_icons[index].visible = false
		reward_buttons[index].disabled = false
	reward_selected_index = -1
	_update_reward_selection()

func _update_reward_reroll_button() -> void:
	if reward_reroll_button != null:
		reward_reroll_button.disabled = coin_count < REWARD_REROLL_COST

func _update_reward_selection() -> void:
	for index in range(reward_buttons.size()):
		var button := reward_buttons[index]
		if index == reward_selected_index:
			button.add_theme_stylebox_override("normal", _panel_style(Color("#b87549"), Color("#fff4cd"), 20, 6))
			button.add_theme_stylebox_override("hover", _panel_style(Color("#c07d50"), Color("#fff4cd"), 20, 6))
		else:
			button.add_theme_stylebox_override("normal", _panel_style(Color("#c58a53"), Color("#ffd273"), 20, 3))
			button.add_theme_stylebox_override("hover", _panel_style(Color("#e0a05e"), Color("#ffe19a"), 20, 3))
	if reward_confirm_button != null:
		reward_confirm_button.disabled = reward_selected_index < 0

func _on_reward_button_pressed(index: int) -> void:
	if not reward_active or index < 0 or index >= reward_options.size():
		return
	reward_selected_index = index
	_update_reward_selection()

func _on_reward_reroll_pressed() -> void:
	if not reward_active:
		return
	if coin_count < REWARD_REROLL_COST:
		_show_toast("金币不足，无法刷新奖励")
		_update_reward_reroll_button()
		return
	# 先扣除刷新费用，再重新随机奖励选项，不关闭面板也不自动确认。
	_change_coins(-REWARD_REROLL_COST)
	_roll_reward_options()
	_update_reward_reroll_button()

func _on_reward_confirm_pressed() -> void:
	if not reward_active:
		return
	if reward_selected_index < 0 or reward_selected_index >= reward_options.size():
		return
	var option: Dictionary = reward_options[reward_selected_index]
	if reward_context == "stage_clear":
		_apply_stage_clear_reward(option)
	else:
		_apply_round_reward(option)

func _reset_round_mods() -> void:
	round_weight_mult.clear()
	round_removed_cards.clear()
	round_no_effect_cards = false
	round_effect_pairs_bonus = 0
	round_extra_tray_slots = 0
	round_coin_mult = 1.0
	round_initial_energy = 0
	round_tower_thorns = false
	round_tower_regen = false
	tray_slots = TRAY_SLOTS + round_extra_tray_slots
	_layout_tray_slots()

func _apply_round_reward(option: Dictionary) -> void:
	_reset_round_mods()
	_apply_reward_effect(option)
	reward_active = false
	reward_overlay.visible = false
	reward_options.clear()
	reward_selected_index = -1
	_update_reward_selection()
	AudioManager.play_sfx("era")
	_update_tower_ui()
	if stage_clear_pending:
		stage_clear_pending = false
		_show_stage_clear_reward()
		return
	_spawn_next_batch()
	_update_progress_ui()

func _apply_stage_clear_reward(option: Dictionary) -> void:
	_apply_reward_effect(option)
	reward_active = false
	reward_overlay.visible = false
	reward_options.clear()
	reward_selected_index = -1
	_update_reward_selection()
	_enter_next_stage()

func _apply_reward_effect(option: Dictionary) -> void:
	var reward_id := str(option.get("id", ""))
	match reward_id:
		"tower_wall":
			var old_max := ally_tower_max_hp
			run_tower_hp_mult *= 1.2
			ally_tower_max_hp *= 1.2
			ally_tower_hp = minf(ally_tower_max_hp, ally_tower_hp + ally_tower_max_hp - old_max)
		"tower_repair":
			ally_tower_hp = ally_tower_max_hp
		"tower_cannon":
			tower_attack_bonus = minf(tower_attack_bonus * 1.3, TOWER_POWER_MAX)
		"tower_thorns":
			round_tower_thorns = true
		"tower_regen":
			round_tower_regen = true
		"deck_boost":
			round_weight_mult[str(option.card)] = 2.0
		"deck_remove":
			round_removed_cards.append(str(option.card))
		"deck_elite":
			round_weight_mult[str(option.card)] = 3.0
		"effect_harvest":
			round_effect_pairs_bonus = 2
		"deck_purge":
			round_no_effect_cards = true
		"free_reshuffle":
			free_reshuffles += 3
		"bloodline":
			var selected_hero := str(option.hero)
			run_hero_mult[selected_hero] = float(run_hero_mult.get(selected_hero, 1.0)) * 1.15
		"tray_expand":
			round_extra_tray_slots = 1
			tray_slots = TRAY_SLOTS + round_extra_tray_slots
			_layout_tray_slots()
		"free_clear":
			free_clear_tokens += 1
		"coin_bag":
			_change_coins(200)
		"loot_boost":
			round_coin_mult = 1.3
		"atk_up":
			run_atk_mult *= 1.1
		"hp_up":
			run_hp_mult *= 1.12
		"aspd_up":
			run_aspd_mult *= 1.1
		"move_up":
			run_move_mult *= 1.12
		"crit":
			run_crit_chance = minf(run_crit_chance + 0.10, 0.6)
		"lifesteal":
			run_lifesteal += 0.08
		"tank_guard":
			run_tank_reduce = minf(run_tank_reduce + 0.15, 0.6)
		"ranged_up":
			run_ranged_atk_mult *= 1.2
		"assassin_crit":
			run_assassin_crit_chance = minf(run_assassin_crit_chance + 0.25, 0.8)
			run_assassin_crit_mult += 0.5
		"energy_start":
			round_initial_energy += 1
		"stun_boost":
			run_stun_mult *= 1.5
		"call_reinforce":
			for _index in range(3):
				_summon_reinforcement(true)
		"tower_overload":
			tower_attack_bonus = minf(tower_attack_bonus * 1.5, TOWER_POWER_MAX)

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
		var unit_ids := ids.duplicate()
		var unit_colors := colors.duplicate()
		if unit.shield_time > 0.0:
			unit_ids.append("skill_shield")
			unit_colors.append(Color("#ffd273"))
		if unit.reflect_time > 0.0:
			unit_ids.append("skill_reflect")
			unit_colors.append(Color("#d7e9ff"))
		if unit.berserk_time > 0.0:
			unit_ids.append("skill_berserk")
			unit_colors.append(Color("#ff665c"))
		if unit.poison_time > 0.0:
			unit_ids.append("skill_poison")
			unit_colors.append(Color("#8ee56d"))
		unit.set_buff_aura(unit_ids, unit_colors)

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

func _do_clear_tray(manual: bool = false) -> void:
	if not battle_active or battle_ended or tray_cards.size() < MIN_CLEAR_TRAY_CARDS:
		return
	var free_clear := free_clear_tokens > 0
	if free_clear:
		free_clear_tokens -= 1
	else:
		coin_count = maxi(0, coin_count - CLEAR_TRAY_COST)
	var returned: Array[String] = tray_cards.duplicate()
	tray_cards.clear()
	# 整台清空：被清的卡无感补回牌堆底部，避免销毁后剩余同名卡永远凑不齐
	for card_id in returned:
		_spawn_card(card_id, deck_cards.size(), true)
	_rebuild_tray_visuals()
	_refresh_covered()
	if free_clear:
		battle_hint.text = "免费清空合成台（%d 张补回牌堆）" % returned.size()
		_show_toast("免费清空合成台（%d 张已补回牌堆）" % returned.size())
	else:
		battle_hint.text = "已扣 %d 金币清空合成台（%d 张补回牌堆）" % [CLEAR_TRAY_COST, returned.size()]
		if manual:
			_show_toast("已扣 %d 金币清空合成台（%d 张已补回牌堆）" % [CLEAR_TRAY_COST, returned.size()])
		else:
			_show_toast("合成台已满，自动扣 %d 金币清空（%d 张已补回牌堆）" % [CLEAR_TRAY_COST, returned.size()])
	AudioManager.play_sfx("ui_denied")
	_update_coin_ui()
	_update_progress_ui()

func _build_era_select_panel() -> void:
	era_select_panel = Panel.new()
	era_select_panel.position = Vector2(84, 220)
	era_select_panel.size = Vector2(552, 730)
	era_select_panel.z_index = 10
	era_select_panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	era_select_panel.visible = false
	main_menu.add_child(era_select_panel)
	var title := _label(era_select_panel, "选择起始关卡", Vector2(0, 28), Vector2(552, 42), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index in range(GameData.ERAS.size()):
		var unlocked := index <= SaveManager.get_unlocked_era_index()
		var text := _stage_name(index + 1)
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
	_hide_leaderboard()
	_refresh_era_select_ui()
	if era_select_panel != null:
		era_select_panel.visible = true

func _refresh_era_select_ui() -> void:
	var unlocked_index := SaveManager.get_unlocked_era_index()
	for index in range(era_select_buttons.size()):
		var unlocked := index <= unlocked_index
		era_select_buttons[index].disabled = not unlocked
		era_select_buttons[index].text = _stage_name(index + 1)
		if not unlocked:
			era_select_buttons[index].text += "（未解锁）"

func _hide_era_select() -> void:
	if era_select_panel != null:
		era_select_panel.visible = false

func _build_sandbox_config_panel() -> void:
	sandbox_panel = Panel.new()
	sandbox_panel.position = Vector2(60, 150)
	sandbox_panel.size = Vector2(600, 1000)
	sandbox_panel.z_index = 20
	sandbox_panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	sandbox_panel.visible = false
	main_menu.add_child(sandbox_panel)
	var title := _label(sandbox_panel, "自定义对战", Vector2(0, 24), Vector2(600, 42), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(
		sandbox_panel,
		"分别为 我方(蓝) / 敌方(红) 选择出战单位与数量",
		Vector2(20, 68),
		Vector2(560, 26),
		14,
		Color("#ffe3a5")
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 104)
	scroll.size = Vector2(560, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sandbox_panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(540, 0)
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	sandbox_ally_count_labels.clear()
	sandbox_enemy_count_labels.clear()
	for era in GameData.ERAS:
		var heroes := GameData.heroes_for_era(era)
		for role in GameData.ROLES:
			for hero_id in heroes:
				var data: Dictionary = GameData.HEROES.get(hero_id, {})
				if str(data.get("role", "")) != role:
					continue
				_sandbox_add_unit_row(rows, str(hero_id), data)
	_set_touch_scroll_buttons_ignore(rows)
	_enable_touch_scroll_click_forwarding(scroll, rows)
	var total_label := _label(sandbox_panel, "", Vector2(24, 820), Vector2(552, 32), 18, Color("#fff0c7"))
	total_label.name = "SandboxTotalLabel"
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sandbox_panel.set_meta("total_label", total_label)
	sandbox_start_button = _menu_button(sandbox_panel, "开战", Vector2(82, 872), Vector2(130, 54), 18)
	sandbox_start_button.pressed.connect(_on_sandbox_start_pressed)
	var clear_button := _menu_button(sandbox_panel, "清空", Vector2(235, 872), Vector2(130, 54), 18)
	clear_button.pressed.connect(_clear_sandbox_counts)
	var close_button := _menu_button(sandbox_panel, "返回", Vector2(388, 872), Vector2(130, 54), 18)
	close_button.pressed.connect(_hide_sandbox_config)

func _sandbox_add_unit_row(parent: VBoxContainer, hero_id: String, data: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(540, 48)
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(218, 48)
	row.add_child(info)
	var name_label := _label(info, str(data.get("name", hero_id)), Vector2.ZERO, Vector2(218, 25), 14)
	name_label.custom_minimum_size = Vector2(218, 25)
	var detail := "%s·%s" % [
		str(GameData.ERA_NAMES.get(data.get("era", "stone"), data.get("era", "stone"))),
		str(GameData.ROLE_NAMES.get(data.get("role", "warrior"), data.get("role", "warrior"))),
	]
	var detail_label := _label(info, detail, Vector2.ZERO, Vector2(218, 19), 10, Color("#e6c199"))
	detail_label.custom_minimum_size = Vector2(218, 19)
	_sandbox_add_side_controls(row, hero_id, "ally")
	_sandbox_add_side_controls(row, hero_id, "enemy")

func _sandbox_add_side_controls(parent: HBoxContainer, hero_id: String, side: String) -> void:
	var side_box := HBoxContainer.new()
	side_box.custom_minimum_size = Vector2(156, 44)
	side_box.add_theme_constant_override("separation", 3)
	parent.add_child(side_box)
	var side_label := _label(
		side_box,
		"我" if side == "ally" else "敌",
		Vector2.ZERO,
		Vector2(22, 36),
		14,
		Color("#8fd8ff") if side == "ally" else Color("#ff8b72")
	)
	side_label.custom_minimum_size = Vector2(22, 36)
	side_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var minus := _sandbox_stepper_button("-")
	side_box.add_child(minus)
	minus.pressed.connect(_sandbox_change_count.bind(hero_id, side, -1))
	var count_label := _label(side_box, "0", Vector2.ZERO, Vector2(34, 36), 14, Color("#fff0c7"))
	count_label.custom_minimum_size = Vector2(34, 36)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var plus := _sandbox_stepper_button("+")
	side_box.add_child(plus)
	plus.pressed.connect(_sandbox_change_count.bind(hero_id, side, 1))
	if side == "ally":
		sandbox_ally_count_labels[hero_id] = count_label
	else:
		sandbox_enemy_count_labels[hero_id] = count_label

func _sandbox_stepper_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(36, 36)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#a75d38"), Color("#70412c"), 10, 2))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#d5864b"), Color("#70412c"), 10, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#e0a34d"), Color("#70412c"), 10, 2))
	button.pressed.connect(_play_button_sfx)
	return button

func _sandbox_count_total(counts: Dictionary) -> int:
	var total := 0
	for value in counts.values():
		total += int(value)
	return total

func _sandbox_change_count(hero_id: String, side: String, delta: int) -> void:
	var counts := sandbox_ally_counts if side == "ally" else sandbox_enemy_counts
	var current := int(counts.get(hero_id, 0))
	var next := clampi(current + delta, 0, 10)
	if delta > 0 and _sandbox_count_total(counts) >= SANDBOX_SIDE_CAP:
		return
	counts[hero_id] = next
	_sandbox_refresh_config_ui()

func _sandbox_refresh_config_ui() -> void:
	for hero_id in sandbox_ally_count_labels:
		sandbox_ally_count_labels[hero_id].text = str(int(sandbox_ally_counts.get(hero_id, 0)))
	for hero_id in sandbox_enemy_count_labels:
		sandbox_enemy_count_labels[hero_id].text = str(int(sandbox_enemy_counts.get(hero_id, 0)))
	var ally_total := _sandbox_count_total(sandbox_ally_counts)
	var enemy_total := _sandbox_count_total(sandbox_enemy_counts)
	if sandbox_panel != null:
		var total_label := sandbox_panel.get_meta("total_label") as Label
		if total_label != null:
			total_label.text = "我方 %d ｜ 敌方 %d" % [ally_total, enemy_total]
	if sandbox_start_button != null:
		sandbox_start_button.disabled = ally_total < 1 or enemy_total < 1

func _clear_sandbox_counts() -> void:
	sandbox_ally_counts.clear()
	sandbox_enemy_counts.clear()
	_sandbox_refresh_config_ui()

func _show_sandbox_config() -> void:
	_hide_settings()
	_hide_leaderboard()
	_hide_era_select()
	_sandbox_refresh_config_ui()
	if sandbox_panel != null:
		sandbox_panel.visible = true

func _hide_sandbox_config() -> void:
	if sandbox_panel != null:
		sandbox_panel.visible = false

func _on_sandbox_start_pressed() -> void:
	_hide_sandbox_config()
	if main_menu != null:
		main_menu.visible = false
	_start_sandbox_battle()

func _build_codex_panel() -> void:
	codex_panel = Panel.new()
	codex_panel.position = Vector2(60, 150)
	codex_panel.size = Vector2(600, 1000)
	codex_panel.z_index = 20
	codex_panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	codex_panel.visible = false
	main_menu.add_child(codex_panel)
	var title := _label(codex_panel, "图鉴", Vector2(0, 22), Vector2(600, 42), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var unit_button := _menu_button(codex_panel, "小兵图鉴", Vector2(20, 70), Vector2(270, 42), 16)
	unit_button.pressed.connect(_set_codex_category.bind("unit"))
	codex_category_buttons["unit"] = unit_button
	var effect_button := _menu_button(codex_panel, "效果卡图鉴", Vector2(310, 70), Vector2(270, 42), 16)
	effect_button.pressed.connect(_set_codex_category.bind("effect"))
	codex_category_buttons["effect"] = effect_button
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 120)
	scroll.size = Vector2(560, 780)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	codex_panel.add_child(scroll)
	codex_rows = VBoxContainer.new()
	codex_rows.custom_minimum_size = Vector2(540, 0)
	codex_rows.add_theme_constant_override("separation", 6)
	codex_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(codex_rows)
	_enable_touch_scroll_click_forwarding(scroll, codex_rows)
	var close_button := _menu_button(codex_panel, "返回", Vector2(200, 924), Vector2(200, 54), 18)
	close_button.pressed.connect(_hide_codex)

func _enable_touch_scroll_click_forwarding(scroll: ScrollContainer, rows: Control) -> void:
	scroll.gui_input.connect(_on_touch_scroll_gui_input.bind(scroll, rows))
	scroll.mouse_exited.connect(_on_touch_scroll_mouse_exited)

func _set_touch_scroll_buttons_ignore(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_set_touch_scroll_buttons_ignore(child)

func _on_touch_scroll_mouse_exited() -> void:
	_set_touch_scroll_button_visual(touch_scroll_hover_button, false)
	touch_scroll_hover_button = null

func _on_touch_scroll_gui_input(event: InputEvent, scroll: ScrollContainer, rows: Control) -> void:
	if event is InputEventMouseMotion:
		var hovered_button := _touch_scroll_button_at_event(scroll, rows, event.position)
		if hovered_button != touch_scroll_hover_button:
			_set_touch_scroll_button_visual(touch_scroll_hover_button, false)
			touch_scroll_hover_button = hovered_button
			_set_touch_scroll_button_visual(touch_scroll_hover_button, true)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_scroll_begin(scroll, rows, event.position)
		else:
			_touch_scroll_end(event.position)
		return
	if event is InputEventScreenDrag:
		if touch_scroll_press_position.distance_to(event.position) >= TOUCH_SCROLL_CLICK_THRESHOLD:
			touch_scroll_dragged = true
			_set_touch_scroll_button_visual(touch_scroll_pressed_button, false)
			touch_scroll_pressed_button = null
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_scroll_begin(scroll, rows, event.position)
			touch_scroll_pressed_button = touch_scroll_press_button
			_set_touch_scroll_button_visual(touch_scroll_pressed_button, true, true)
		else:
			_touch_scroll_end(event.position)

func _touch_scroll_begin(scroll: ScrollContainer, rows: Control, position: Vector2) -> void:
	touch_scroll_press_position = position
	touch_scroll_press_button = _touch_scroll_button_at_event(scroll, rows, position)
	touch_scroll_dragged = false

func _touch_scroll_button_at_event(scroll: ScrollContainer, rows: Control, position: Vector2) -> Button:
	return _touch_scroll_button_at_local(
		rows,
		rows.get_global_transform_with_canvas().affine_inverse() * (scroll.get_global_transform_with_canvas() * position)
	)

func _touch_scroll_end(position: Vector2) -> void:
	_set_touch_scroll_button_visual(touch_scroll_pressed_button, false)
	touch_scroll_pressed_button = null
	if touch_scroll_press_button != null and not touch_scroll_dragged and touch_scroll_press_position.distance_to(position) < TOUCH_SCROLL_CLICK_THRESHOLD:
		touch_scroll_press_button.emit_signal("pressed")
	touch_scroll_press_button = null
	touch_scroll_dragged = false

func _set_touch_scroll_button_visual(button: Button, active: bool, pressed := false) -> void:
	if button != null and is_instance_valid(button):
		button.modulate = Color(0.88, 0.88, 0.88) if pressed else Color(1.08, 1.08, 1.08) if active else Color.WHITE

func _touch_scroll_button_at_local(control: Control, position: Vector2) -> Button:
	for index in range(control.get_child_count() - 1, -1, -1):
		var child := control.get_child(index)
		if child is Control:
			var child_control := child as Control
			var child_position := child_control.position
			if Rect2(child_position, child_control.size).has_point(position):
				if child is Button:
					return child as Button
				var nested := _touch_scroll_button_at_local(child_control, position - child_position)
				if nested != null:
					return nested
	return null

func _set_codex_category(category: String) -> void:
	if category != "unit" and category != "effect":
		return
	codex_category = category
	_refresh_codex()

func _refresh_codex() -> void:
	if codex_rows == null:
		return
	for child in codex_rows.get_children():
		child.queue_free()
	_refresh_codex_category_buttons()
	if codex_category == "effect":
		for effect in RANDOM_EFFECTS:
			_codex_add_effect_row(str(effect.id))
		return
	for era in GameData.ERAS:
		var heroes := GameData.heroes_for_era(era)
		for role in GameData.ROLES:
			for hero_id in heroes:
				var data: Dictionary = GameData.HEROES.get(hero_id, {})
				if str(data.get("role", "")) == role:
					_codex_add_unit_row(str(hero_id))

func _refresh_codex_category_buttons() -> void:
	for category in codex_category_buttons:
		var button: Button = codex_category_buttons[category]
		var selected := str(category) == codex_category
		var normal_color := Color("#e0a34d") if selected else Color("#b86a3e")
		var hover_color := Color("#f0b962") if selected else Color("#d5864b")
		button.add_theme_stylebox_override("normal", _panel_style(normal_color, Color("#713722"), 16, 3))
		button.add_theme_stylebox_override("hover", _panel_style(hover_color, Color("#713722"), 16, 3))

func _codex_add_unit_row(hero_id: String) -> void:
	var hero: Dictionary = GameData.HEROES.get(hero_id, {})
	if hero.is_empty():
		return
	var button := _codex_row_button()
	var path := GameData.card_texture_path(str(hero.get("card", hero_id)))
	var placeholder_color := Color("#888888")
	if hero.get("color_value", null) is Color:
		placeholder_color = hero["color_value"]
	_codex_add_row_icon(button, path, placeholder_color)
	var unit_path := GameData.unit_portrait_path(hero_id)
	if unit_path != "" and unit_path != path:
		_codex_add_row_icon(button, unit_path, placeholder_color, 58.0)
	var title := _label(button, str(hero.get("name", hero_id)), Vector2(112, 10), Vector2(410, 25), 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var subtitle := _label(
		button,
		"%s·%s" % [str(hero.get("era_name", hero.get("era", ""))), str(hero.get("role_name", hero.get("role", "")))],
		Vector2(112, 36),
		Vector2(450, 18),
		11,
		Color("#e6c199")
	)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.pressed.connect(_show_codex_detail_unit.bind(hero_id))
	_codex_add_row(button)

func _codex_add_effect_row(effect_id: String) -> void:
	var effect := _effect_by_id(effect_id)
	if effect.is_empty():
		return
	var button := _codex_row_button()
	_codex_add_row_icon(button, EFFECT_ICON_PATH % effect_id, EFFECT_CARD_COLOR)
	var title := _label(button, str(effect.get("name", effect_id)), Vector2(68, 10), Vector2(450, 25), 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var duration := float(effect.get("duration", 0.0))
	var subtitle_text := "效果卡 ｜ 持续 %.0f 秒" % duration if duration > 0.0 else "效果卡 ｜ 立即生效"
	var subtitle := _label(button, subtitle_text, Vector2(68, 36), Vector2(450, 18), 11, Color("#e6c199"))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.pressed.connect(_show_codex_detail_effect.bind(effect_id))
	_codex_add_row(button)

func _codex_add_row(button: Button) -> void:
	_set_touch_scroll_buttons_ignore(button)
	codex_rows.add_child(button)

func _codex_row_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(540, 64)
	button.size = Vector2(540, 64)
	button.add_theme_stylebox_override("normal", _panel_style(Color("#a75d38"), Color("#70412c"), 12, 2))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#d5864b"), Color("#70412c"), 12, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#e0a34d"), Color("#70412c"), 12, 2))
	button.pressed.connect(_play_button_sfx)
	return button

func _codex_add_row_icon(parent: Button, path: String, placeholder_color: Color, offset_x: float = 10.0) -> void:
	if ResourceLoader.exists(path):
		var icon := TextureRect.new()
		icon.position = Vector2(offset_x, 10)
		icon.size = Vector2(44, 44)
		icon.texture = load(path) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(icon)
		return
	var placeholder := Panel.new()
	placeholder.position = Vector2(offset_x, 10)
	placeholder.size = Vector2(44, 44)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.add_theme_stylebox_override("panel", _panel_style(placeholder_color, Color("#70412c"), 10, 2))
	parent.add_child(placeholder)

func _show_codex() -> void:
	_hide_settings()
	_hide_leaderboard()
	_hide_era_select()
	_hide_sandbox_config()
	codex_category = "unit"
	_refresh_codex()
	if codex_panel != null:
		codex_panel.visible = true

func _hide_codex() -> void:
	if codex_panel != null:
		codex_panel.visible = false
	_hide_codex_detail()

func _build_codex_detail_overlay() -> void:
	codex_detail_overlay = Control.new()
	codex_detail_overlay.size = VIEW_SIZE
	codex_detail_overlay.z_index = 4096
	codex_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	codex_detail_overlay.visible = false
	codex_detail_overlay.gui_input.connect(_on_codex_detail_input)
	add_child(codex_detail_overlay)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color(0.05, 0.03, 0.02, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	codex_detail_overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(70, 360)
	panel.size = Vector2(580, 578)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	codex_detail_overlay.add_child(panel)
	codex_detail_icon = TextureRect.new()
	codex_detail_icon.position = Vector2(242, 24)
	codex_detail_icon.size = Vector2(96, 96)
	codex_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	codex_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	codex_detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(codex_detail_icon)
	codex_detail_unit_icon = TextureRect.new()
	codex_detail_unit_icon.position = Vector2(332, 24)
	codex_detail_unit_icon.size = Vector2(96, 96)
	codex_detail_unit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	codex_detail_unit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	codex_detail_unit_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	codex_detail_unit_icon.visible = false
	panel.add_child(codex_detail_unit_icon)
	codex_detail_icon_label = _label(panel, "卡牌", Vector2(152, 122), Vector2(96, 22), 13, Color("#e6c199"))
	codex_detail_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codex_detail_icon_label.visible = false
	codex_detail_unit_icon_label = _label(panel, "角色", Vector2(332, 122), Vector2(96, 22), 13, Color("#e6c199"))
	codex_detail_unit_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codex_detail_unit_icon_label.visible = false
	codex_detail_title = _label(panel, "", Vector2(20, 150), Vector2(540, 42), 26)
	codex_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codex_detail_text = RichTextLabel.new()
	codex_detail_text.bbcode_enabled = true
	codex_detail_text.scroll_active = true
	codex_detail_text.position = Vector2(40, 202)
	codex_detail_text.size = Vector2(500, 292)
	codex_detail_text.add_theme_font_size_override("normal_font_size", 18)
	codex_detail_text.add_theme_color_override("default_color", Color("#fff0c7"))
	panel.add_child(codex_detail_text)
	var close_button := _menu_button(panel, "关闭", Vector2(190, 510), Vector2(200, 52), 18)
	close_button.pressed.connect(_hide_codex_detail)

func _on_codex_detail_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hide_codex_detail()

func _show_codex_detail_unit(hero_id: String) -> void:
	var hero: Dictionary = GameData.HEROES.get(hero_id, {})
	if hero.is_empty() or codex_detail_overlay == null:
		return
	var path := GameData.card_texture_path(str(hero.get("card", hero_id)))
	var unit_path := GameData.unit_portrait_path(hero_id)
	var card_texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var unit_texture: Texture2D = load(unit_path) as Texture2D if ResourceLoader.exists(unit_path) else null
	if unit_texture != null and unit_texture == card_texture:
		unit_texture = null
	var both := card_texture != null and unit_texture != null
	codex_detail_icon.texture = card_texture
	codex_detail_icon.visible = card_texture != null
	codex_detail_icon.position = Vector2(152 if both else 242, 24)
	codex_detail_unit_icon.texture = unit_texture
	codex_detail_unit_icon.visible = unit_texture != null
	codex_detail_unit_icon.position = Vector2(332 if both else 242, 24)
	codex_detail_icon_label.visible = card_texture != null
	codex_detail_icon_label.position = Vector2(152 if both else 242, 122)
	codex_detail_unit_icon_label.visible = unit_texture != null
	codex_detail_unit_icon_label.position = Vector2(332 if both else 242, 122)
	codex_detail_title.text = str(hero.get("name", hero_id))
	var lines := [
		"类型：[b]小兵/角色卡[/b]（%s·%s）" % [str(hero.get("era_name", hero.get("era", ""))), str(hero.get("role_name", hero.get("role", "")))],
		"合成：同名 [b]3 张[/b] 上场",
		"生命 %.0f　攻击 %.0f" % [float(hero.get("hp", 0.0)), float(hero.get("attack", 0.0))],
		"攻速 %.2f 次/秒　射程 %.0f" % [float(hero.get("attack_speed", 0.0)), float(hero.get("range", 0.0))],
		"移速 %.0f　击杀分 %d" % [float(hero.get("move_speed", 0.0)), int(hero.get("kill_score", 0))],
	]
	var splash: Variant = hero.get("basic_splash", {})
	if splash is Dictionary and not splash.is_empty():
		lines.append("普攻溅射：半径%.0f，%.0f%% 伤害" % [
			float(splash.get("radius", 0.0)),
			float(splash.get("frac", 0.0)) * 100.0,
		])
	if card_texture == null or unit_texture == null:
		lines.append("[i]提示：本英雄暂缺%s图资源[/i]" % ("卡牌" if card_texture == null else "角色"))
	var skill: Variant = hero.get("skill", {})
	if skill is Dictionary and not skill.is_empty():
		lines.append("")
		var skill_icon := _skill_icon_path(str(skill.get("type", "")))
		var skill_line := "技能："
		if skill_icon != "":
			skill_line += "[img=26]%s[/img] " % skill_icon
		skill_line += "[b]%s[/b]" % str(skill.get("name", "特殊技能"))
		if skill.has("cost"):
			skill_line += "（消耗 %d）" % int(skill.get("cost", 0))
		lines.append(skill_line)
		lines.append(_skill_description(str(skill.get("type", ""))))
	codex_detail_text.text = "\n".join(lines)
	move_child(codex_detail_overlay, get_child_count() - 1)
	codex_detail_overlay.visible = true
	_play_button_sfx()

func _show_codex_detail_effect(effect_id: String) -> void:
	var effect := _effect_by_id(effect_id)
	if effect.is_empty() or codex_detail_overlay == null:
		return
	var path := EFFECT_ICON_PATH % effect_id
	codex_detail_icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	codex_detail_icon.visible = true
	codex_detail_icon.position = Vector2(242, 24)
	codex_detail_unit_icon.visible = false
	codex_detail_unit_icon.texture = null
	codex_detail_icon_label.visible = false
	codex_detail_unit_icon_label.visible = false
	codex_detail_title.text = str(effect.get("name", effect_id))
	var lines := [
		"类型：[b]效果卡[/b]",
		"发动：同名 [b]2 张[/b]自动发动（不上场）",
		"效果：%s" % str(effect.get("desc", "—")),
	]
	var duration := float(effect.get("duration", 0.0))
	lines.append("持续：%.0f 秒" % duration if duration > 0.0 else "生效：立即")
	codex_detail_text.text = "\n".join(lines)
	move_child(codex_detail_overlay, get_child_count() - 1)
	codex_detail_overlay.visible = true
	_play_button_sfx()

func _hide_codex_detail() -> void:
	if codex_detail_overlay != null:
		codex_detail_overlay.visible = false

func _skill_description(skill_type: String) -> String:
	match skill_type:
		"taunt_shield":
			return "为自身附加护盾，并嘲讽周围敌人 3 秒"
		"smash_stun":
			return "对目标造成双倍伤害并眩晕 1.5 秒"
		"poison":
			return "使目标中毒，持续掉血 5 秒"
		"boulder_splash":
			return "投掷巨石，对落点范围造成溅射伤害"
		"aoe_stun":
			return "范围震吼，眩晕附近所有敌人 2.5 秒"
		"thorns_shield":
			return "进入反伤姿态，短时间反弹所受伤害"
		"whirlwind":
			return "回旋斩击，对周围敌人造成范围伤害"
		"blink_crit":
			return "瞬移到目标身后并造成 2.5 倍暴击伤害"
		"multishot":
			return "同时射击最多 3 个敌人"
		"berserk":
			return "进入狂暴，短时间大幅提升攻击与攻速"
		"overpressure_steam":
			return "举盾获得强力护盾，锅炉泄压把周围敌人击退并减速"
		"piston_charge":
			return "直线冲刺挥拳，沿途造成伤害，正面第一个敌人被击退并眩晕"
		"smoke_raid":
			return "烟雾弹致盲并减速周围敌人，自身短暂闪避，目标中毒"
		"shotgun_blast":
			return "近距离扇形散射，命中前方多个敌人并击退"
		"overpressure_burst":
			return "大范围蒸汽爆炸眩晕敌人，并给我方全体攻速光环"
		"shield_wall":
			return "身后我方群体减伤，盾击震晕正面敌人"
		"suppress_fire":
			return "对目标及周围多段扫射，并施加压制减速"
		"decap_strike":
			return "突进最脆弱的目标，按其缺失生命提升斩杀伤害"
		"lethal_snipe":
			return "蓄力后必定暴击的远程一枪，贯穿直线上的敌人"
		"artillery_support":
			return "预警后延迟落下大范围轰炸，并给我方全体攻击增益"
		"force_field":
			return "为我方全体附加能量护盾，自身短暂免疫伤害"
		"laser_slash":
			return "前方大扇形激光横扫，范围爆发并附加灼烧"
		"phase_execute":
			return "隐身瞬移到目标身后斩杀，残血目标伤害大幅提升，自身短暂不可被选中"
		"plasma_lance":
			return "蓄力光束贯穿直线上的所有敌人"
		"overload_barrage":
			return "肩炮多发弹幕轰击，随后 EMP 眩晕并清空敌方技能能量，自身过载狂暴"
		_:
			return "特殊技能"

func _build_sandbox_control_panel() -> void:
	sandbox_control_panel = Panel.new()
	sandbox_control_panel.position = Vector2(36, 432)
	sandbox_control_panel.size = Vector2(648, 808)
	sandbox_control_panel.z_index = 3000
	sandbox_control_panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	sandbox_control_panel.visible = false
	add_child(sandbox_control_panel)
	sandbox_status_label = _label(
		sandbox_control_panel,
		"",
		Vector2(24, 42),
		Vector2(600, 72),
		24,
		Color("#fff2c4")
	)
	sandbox_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sandbox_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var hint := _label(
		sandbox_control_panel,
		"战斗将持续到一方单位全部倒下",
		Vector2(24, 122),
		Vector2(600, 30),
		15,
		Color("#ffe3a5")
	)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var restart := _menu_button(
		sandbox_control_panel,
		"重新模拟",
		Vector2(174, 270),
		Vector2(300, 58),
		19
	)
	restart.pressed.connect(_start_sandbox_battle)
	var edit := _menu_button(
		sandbox_control_panel,
		"修改配置",
		Vector2(174, 344),
		Vector2(300, 58),
		19
	)
	edit.pressed.connect(_show_sandbox_config_from_battle)
	var back := _menu_button(
		sandbox_control_panel,
		"返回主菜单",
		Vector2(174, 418),
		Vector2(300, 58),
		19
	)
	back.pressed.connect(_show_main_menu)

func _show_sandbox_config_from_battle() -> void:
	_show_main_menu()
	_show_sandbox_config()

func _start_sandbox_battle() -> void:
	AudioManager.set_music_filtered(false)
	sandbox_mode = true
	_remove_battle_units()
	occupied_units = 0
	buff_timers.clear()
	enemy_buff_timers.clear()
	enemy_freeze_time = 0.0
	ally_freeze_time = 0.0
	tower_attack_bonus = 1.0
	enemy_tower_attack_bonus = 1.0
	tower_destruction_started = false
	ally_lane_cursor = 0
	enemy_lane_cursor = 0
	kill_score = 0
	prep_pending = false
	auto_prep = false
	stuck_warned = false
	wave_spawning = false
	wave_min_timer = 0.0
	wave_active_timer = 0.0
	enemy_spawn_index = 0
	ai_spawn.reset()
	ai_spawn.set_difficulty(current_difficulty)
	wave_number = 0
	round_number = 0
	ally_tower_cd = 0.0
	enemy_tower_cd = 0.0
	enemy_coin = 0.0
	enemy_effect_cd = 0.0
	enemy_rally_fired = 0
	run_atk_mult = 1.0
	run_hp_mult = 1.0
	run_aspd_mult = 1.0
	run_move_mult = 1.0
	run_crit_chance = 0.0
	run_lifesteal = 0.0
	run_tank_reduce = 0.0
	run_ranged_atk_mult = 1.0
	run_assassin_crit_chance = 0.0
	run_assassin_crit_mult = 0.0
	run_stun_mult = 1.0
	run_tower_hp_mult = 1.0
	run_hero_mult.clear()
	_reset_round_mods()
	ally_alarm_50_played = false
	ally_alarm_25_played = false
	var display_era_index := 0
	for counts in [sandbox_ally_counts, sandbox_enemy_counts]:
		for hero_id in counts:
			var data: Dictionary = GameData.HEROES.get(hero_id, {})
			var candidate := GameData.ERAS.find(str(data.get("era", "stone")))
			display_era_index = maxi(display_era_index, candidate)
	era_index = display_era_index
	base_era_index = display_era_index
	enemy_era_index = display_era_index
	current_era = GameData.ERAS[display_era_index]
	enemy_era = current_era
	ally_tower_hp = GameData.ally_tower_hp(current_era)
	enemy_tower_hp = GameData.tower_hp(current_era)
	ally_tower_max_hp = ally_tower_hp
	enemy_tower_max_hp = enemy_tower_hp
	battle_active = true
	battle_ended = false
	battle_won = false
	paused = false
	if main_menu != null:
		main_menu.visible = false
	if board != null:
		board.visible = false
	if tray != null:
		tray.visible = false
	if sandbox_control_panel != null:
		sandbox_control_panel.visible = true
	if pause_overlay != null:
		pause_overlay.visible = false
	if tutorial_overlay != null:
		tutorial_overlay.visible = false
	if result_overlay != null:
		result_overlay.visible = false
	if pause_button != null:
		pause_button.visible = true
	if restart_button != null:
		restart_button.text = "再来一次"
	battle_hint.text = "自定义模拟对战"
	_update_buff_ui()
	_update_coin_ui()
	_update_progress_ui()
	_update_tower_ui()
	_sync_persistent_status_vfx(0.0)
	_refresh_era_visuals(false)
	_reset_camera()
	for hero_id in sandbox_ally_counts:
		for _i in range(int(sandbox_ally_counts[hero_id])):
			_spawn_ally(str(hero_id))
	var enemy_total := _sandbox_count_total(sandbox_enemy_counts)
	var enemy_index := 0
	for hero_id in sandbox_enemy_counts:
		for _i in range(int(sandbox_enemy_counts[hero_id])):
			_spawn_enemy(str(hero_id), enemy_index, enemy_total, false)
			enemy_index += 1
	_update_sandbox_status()

func _update_sandbox_status() -> void:
	if sandbox_status_label == null:
		return
	sandbox_status_label.text = "我方存活 %d ｜ 敌方存活 %d" % [
		_living_units("ally").size(),
		_living_units("enemy").size(),
	]

func _check_sandbox_end() -> void:
	var ally_units := _living_units("ally")
	var enemy_units := _living_units("enemy")
	var ally_alive := not ally_units.is_empty()
	var enemy_alive := not enemy_units.is_empty()
	if ally_alive and enemy_alive:
		return
	var text := ""
	if ally_alive and not enemy_alive:
		text = "我方胜利！\n存活 %d 个单位" % ally_units.size()
	elif enemy_alive and not ally_alive:
		text = "敌方胜利！\n存活 %d 个单位" % enemy_units.size()
	else:
		text = "同归于尽（平局）"
	_finish_sandbox(text)

func _finish_sandbox(text: String) -> void:
	if battle_ended:
		return
	battle_ended = true
	battle_active = false
	battle_won = text.begins_with("我方胜利")
	AudioManager.play_sfx("victory")
	status_label.text = text
	if sandbox_control_panel != null:
		sandbox_control_panel.visible = false
	if result_overlay != null:
		result_overlay.visible = true
	_update_progress_ui()

func _on_restart_pressed() -> void:
	if sandbox_mode:
		_start_sandbox_battle()
	else:
		_start_round()

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
	sandbox_mode = false
	paused = false
	reward_active = false
	stage_clear_pending = false
	AudioManager.set_music_filtered(false)
	_hide_settings()
	_hide_leaderboard()
	_hide_era_select()
	_hide_sandbox_config()
	_hide_codex()
	if result_overlay != null:
		result_overlay.visible = false
	if pause_overlay != null:
		pause_overlay.visible = false
	if tutorial_overlay != null:
		tutorial_overlay.visible = false
	if reward_overlay != null:
		reward_overlay.visible = false
	reward_selected_index = -1
	_update_reward_selection()
	if pause_button != null:
		pause_button.visible = false
	if sandbox_control_panel != null:
		sandbox_control_panel.visible = false
	if board != null:
		board.visible = true
	if tray != null:
		tray.visible = true
	if restart_button != null:
		restart_button.text = "重新开始"
	_remove_battle_units()
	_update_progress_ui()
	if main_menu != null:
		main_menu.visible = true

func _start_round(start_era_index: int = 0) -> void:
	AudioManager.set_music_filtered(false)
	sandbox_mode = false
	if sandbox_control_panel != null:
		sandbox_control_panel.visible = false
	if board != null:
		board.visible = true
	if tray != null:
		tray.visible = true
	if restart_button != null:
		restart_button.text = "重新开始"
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
	tray_slots = TRAY_SLOTS
	_layout_tray_slots()
	occupied_units = 0
	era_index = clampi(start_era_index, 0, GameData.ERAS.size() - 1)
	base_era_index = era_index
	current_era = GameData.ERAS[era_index]
	coin_count = STARTING_COINS
	kill_score = 0
	prep_pending = false
	auto_prep = false
	stuck_warned = false
	# 关卡制：起始关卡 = 所选时代，敌方与玩家时代同关锁定
	enemy_era_index = era_index
	enemy_era = current_era
	buff_timers.clear()
	enemy_buff_timers.clear()
	enemy_freeze_time = 0.0
	ally_freeze_time = 0.0
	tower_attack_bonus = 1.0
	enemy_tower_attack_bonus = 1.0
	run_atk_mult = 1.0
	run_hp_mult = 1.0
	run_aspd_mult = 1.0
	run_move_mult = 1.0
	run_crit_chance = 0.0
	run_lifesteal = 0.0
	run_tank_reduce = 0.0
	run_ranged_atk_mult = 1.0
	run_assassin_crit_chance = 0.0
	run_assassin_crit_mult = 0.0
	run_stun_mult = 1.0
	run_tower_hp_mult = 1.0
	run_hero_mult.clear()
	free_reshuffles = 0
	free_clear_tokens = 0
	reward_active = false
	stage_clear_pending = false
	stage_clear_economy_awarded = false
	_reset_round_mods()
	tower_destruction_started = false
	enemy_coin = 0.0
	enemy_effect_cd = 0.0
	enemy_rally_fired = 0
	ally_lane_cursor = 0
	enemy_lane_cursor = 0
	_update_buff_ui()
	_update_coin_ui()
	battle_active = true
	battle_ended = false
	battle_won = false
	paused = false
	_reset_stage_timer()
	if pause_overlay != null:
		pause_overlay.visible = false
	if tutorial_overlay != null:
		tutorial_overlay.visible = false
	if pause_button != null:
		pause_button.visible = true
	wave_min_timer = _diff().first_delay
	wave_spawning = false
	wave_active_timer = 0.0
	enemy_spawn_index = 0
	ai_spawn.reset()
	ai_spawn.set_difficulty(current_difficulty)
	wave_number = 0
	round_number = 0
	ally_tower_cd = 0.0
	enemy_tower_cd = 0.0
	card_z_top = 0
	ally_tower_hp = _ally_tower_target_hp()
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
	# 牌池时代：本关时代下限 + 本关轮次阈值升级（只升不降）
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
	counts = counts.duplicate()
	for card_id in round_weight_mult:
		if counts.has(card_id):
			counts[card_id] = maxi(1, int(round(float(counts[card_id]) * float(round_weight_mult[card_id]))))
	for card_id in round_removed_cards:
		counts.erase(card_id)
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

func _effect_pairs_for_round() -> int:
	var pairs := EFFECT_PAIRS_BASE + (round_number - 1) / EFFECT_PAIRS_ROUND_STEP
	return clampi(pairs, 0, EFFECT_PAIRS_MAX)

func _build_effect_cards_for_batch() -> Array[String]:
	var result: Array[String] = []
	if round_no_effect_cards:
		return result
	var pairs := _effect_pairs_for_round() + round_effect_pairs_bonus
	for _pair in range(pairs):
		var effect_id := _weighted_random_effect_id()
		for _copy in range(EFFECT_CARD_PAIR_SIZE):
			result.append(_effect_card_id(effect_id))
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
		_show_round_reward()
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
	return battle_active and not battle_ended and (not paused or auto_prep) and not reward_active

func _build_reshuffle_confirm_overlay() -> void:
	reshuffle_confirm_overlay = Control.new()
	reshuffle_confirm_overlay.size = VIEW_SIZE
	reshuffle_confirm_overlay.z_index = 4095
	reshuffle_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reshuffle_confirm_overlay.visible = false
	add_child(reshuffle_confirm_overlay)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color(0.05, 0.03, 0.02, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reshuffle_confirm_overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(70, 500)
	panel.size = Vector2(580, 280)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	reshuffle_confirm_overlay.add_child(panel)
	var title := _label(panel, "重排牌序", Vector2(0, 26), Vector2(580, 40), 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var desc := _label(panel, "把牌堆里未取走的卡牌重新洗牌摆放，解开互相压住的牌。\n每次 %d 金币（有免费次数时优先扣免费）。确定使用？" % RESHUFFLE_COST, Vector2(40, 86), Vector2(500, 80), 17, Color("#fff0c7"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cancel_button := _menu_button(panel, "取消", Vector2(60, 190), Vector2(200, 56), 19)
	cancel_button.pressed.connect(_hide_reshuffle_confirm)
	var confirm_button := _menu_button(panel, "确定重排", Vector2(320, 190), Vector2(200, 56), 19)
	confirm_button.pressed.connect(_on_reshuffle_confirmed)

func _hide_reshuffle_confirm() -> void:
	if reshuffle_confirm_overlay != null:
		reshuffle_confirm_overlay.visible = false

func _on_reshuffle_confirmed() -> void:
	_hide_reshuffle_confirm()
	SaveManager.set_reshuffle_hint_seen(true)
	_do_reshuffle()

func _on_reshuffle_pressed() -> void:
	var reason := _reshuffle_block_reason()
	if reason != "":
		AudioManager.play_sfx("ui_denied")
		battle_hint.text = reason
		_show_toast(reason)
		return
	if not SaveManager.get_reshuffle_hint_seen() and reshuffle_confirm_overlay != null:
		move_child(reshuffle_confirm_overlay, get_child_count() - 1)
		reshuffle_confirm_overlay.visible = true
		return
	_do_reshuffle()

func _can_reshuffle() -> bool:
	return _reshuffle_block_reason() == ""

func _reshuffle_live_deck_count() -> int:
	var live_count := 0
	for card in deck_cards:
		if is_instance_valid(card) and not card.claimed:
			live_count += 1
	return live_count

# 返回空串表示可重排，否则为不可重排的中文原因（用于点击时弹提示）
func _reshuffle_block_reason() -> String:
	if not _can_pick_cards():
		return "当前阶段不可重排"
	if _reshuffle_live_deck_count() < 2:
		return "牌堆可重排卡牌不足 2 张"
	if free_reshuffles <= 0 and coin_count < RESHUFFLE_COST:
		return "金币不足，重排需要 %d 金币" % RESHUFFLE_COST
	return ""

func _do_reshuffle() -> void:
	if not _can_reshuffle():
		AudioManager.play_sfx("ui_denied")
		return
	if free_reshuffles > 0:
		free_reshuffles -= 1
		battle_hint.text = "免费重排牌序（剩 %d 次）" % free_reshuffles
	else:
		coin_count = maxi(0, coin_count - RESHUFFLE_COST)
		battle_hint.text = "已扣 %d 金币重排牌序" % RESHUFFLE_COST
	_reshuffle_deck()
	AudioManager.play_sfx("place")
	_update_coin_ui()
	_update_progress_ui()

func _reshuffle_deck() -> void:
	var live_cards: Array[CardView] = []
	for card in deck_cards:
		if is_instance_valid(card) and not card.claimed:
			live_cards.append(card)
	live_cards.shuffle()
	card_z_top = 0
	for index in range(live_cards.size()):
		var card := live_cards[index]
		card.rotation = rng.randf_range(-0.45, 0.45)
		card.position = _random_pile_position()
		card.z_index = index
		card_z_top = maxi(card_z_top, index)
	_refresh_covered()

func _first_open_slot() -> int:
	var used := tray_cards.size() + tray_incoming
	return used if used < tray_slots else -1

func _slot_position(index: int) -> Vector2:
	var step := (tray.size.x - TRAY_SLOT_ORIGIN.x * 2.0 - TRAY_SLOT_SIZE.x) / float(maxi(tray_slots - 1, 1))
	return tray.global_position + TRAY_SLOT_ORIGIN + Vector2(index * step, 0) + TRAY_SLOT_SIZE * 0.5

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
	if tray_cards.size() < tray_slots or _has_merge():
		if tray_cards.size() == tray_slots - 1 and not _has_merge():
			battle_hint.text = "⚠ 合成台只剩 1 格，凑不齐将扣 %d 金币清理" % CLEAR_TRAY_COST
		return
	if free_clear_tokens <= 0 and coin_count < CLEAR_TRAY_COST:
		AudioManager.play_sfx("ui_denied")
		_finish_battle(false, "金币不足，无法清理合成台")
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
	AudioManager.play_sfx("ui_denied")
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

# 返回空串表示可清空，否则为不可清空的中文原因（用于点击时弹提示）
func _clear_tray_block_reason() -> String:
	if not _can_pick_cards():
		return "当前阶段不可清空合成台"
	if tray_cards.size() < MIN_CLEAR_TRAY_CARDS:
		return "合成台不足 %d 张，无需清空" % MIN_CLEAR_TRAY_CARDS
	if free_clear_tokens <= 0 and coin_count < CLEAR_TRAY_COST:
		return "金币不足，清空合成台需要 %d 金币" % CLEAR_TRAY_COST
	return ""

func _on_clear_tray_pressed() -> void:
	var reason := _clear_tray_block_reason()
	if reason != "":
		AudioManager.play_sfx("ui_denied")
		if battle_hint != null:
			battle_hint.text = reason
		_show_toast(reason)
		return
	if not SaveManager.get_clear_tray_hint_seen() and clear_tray_confirm_overlay != null:
		move_child(clear_tray_confirm_overlay, get_child_count() - 1)
		clear_tray_confirm_overlay.visible = true
		return
	_do_clear_tray(true)

func _build_clear_tray_confirm_overlay() -> void:
	clear_tray_confirm_overlay = Control.new()
	clear_tray_confirm_overlay.size = VIEW_SIZE
	clear_tray_confirm_overlay.z_index = 4095
	clear_tray_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	clear_tray_confirm_overlay.visible = false
	add_child(clear_tray_confirm_overlay)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color(0.05, 0.03, 0.02, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear_tray_confirm_overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(70, 500)
	panel.size = Vector2(580, 280)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	clear_tray_confirm_overlay.add_child(panel)
	var title := _label(panel, "清空合成台", Vector2(0, 26), Vector2(580, 40), 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var desc := _label(panel, "把合成台上的卡牌全部补回牌堆底部，腾出格子。\n每次 %d 金币（有免费清空次数时优先扣免费）。确定清空？" % CLEAR_TRAY_COST, Vector2(40, 86), Vector2(500, 80), 17, Color("#fff0c7"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cancel_button := _menu_button(panel, "取消", Vector2(60, 190), Vector2(200, 56), 19)
	cancel_button.pressed.connect(_hide_clear_tray_confirm)
	var confirm_button := _menu_button(panel, "确定清空", Vector2(320, 190), Vector2(200, 56), 19)
	confirm_button.pressed.connect(_on_clear_tray_confirmed)

func _hide_clear_tray_confirm() -> void:
	if clear_tray_confirm_overlay != null:
		clear_tray_confirm_overlay.visible = false

func _on_clear_tray_confirmed() -> void:
	_hide_clear_tray_confirm()
	SaveManager.set_clear_tray_hint_seen(true)
	if _clear_tray_block_reason() != "":
		_on_clear_tray_pressed()
		return
	_do_clear_tray(true)

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
	var step := (tray.size.x - TRAY_SLOT_ORIGIN.x * 2.0 - TRAY_SLOT_SIZE.x) / float(maxi(tray_slots - 1, 1))
	for index in range(tray_cards.size()):
		var icon := TextureRect.new()
		icon.position = TRAY_SLOT_ORIGIN + Vector2(index * step, 0)
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
	var data: Dictionary = GameData.HEROES.get(hero_id, {}).duplicate(true)
	if data.is_empty() or _living_units("ally").size() >= UNIT_CAP:
		return null
	var role := str(data.get("role", ""))
	var hero_mult := float(run_hero_mult.get(hero_id, 1.0))
	data["hp"] = float(data.get("hp", 1.0)) * run_hp_mult * hero_mult
	data["attack"] = float(data.get("attack", 1.0)) * run_atk_mult * hero_mult
	if role == "ranged":
		data["attack"] = float(data.attack) * run_ranged_atk_mult
		data["range"] = float(data.get("range", 0.0)) * RANGED_RANGE_MULT
	data["attack_speed"] = float(data.get("attack_speed", 1.0)) * run_aspd_mult
	data["move_speed"] = float(data.get("move_speed", 0.0)) * run_move_mult
	var texture: Texture2D
	var path := GameData.hero_texture_path(hero_id)
	if path != "":
		texture = load(path)
	var unit := BattleUnit.new()
	unit.setup(hero_id, "ally", data, texture)
	if unit.skill_cost > 0 and round_initial_energy > 0:
		unit.energy = clampf(float(round_initial_energy), 0.0, float(unit.skill_cost))
		unit.queue_redraw()
	var ally_count := _living_units("ally").size()
	var units_per_row := 6
	var row := ally_count / units_per_row
	var column := ally_count % units_per_row
	var spacing := 48.0
	var lane := ally_lane_cursor % BATTLE_LANES
	ally_lane_cursor += 1
	var lane_offset := (float(lane) - float(BATTLE_LANES - 1) * 0.5) * BATTLE_LANE_STEP
	unit.position = Vector2(
		ALLY_TOWER_X + 96 + column * spacing + row * 28.0,
		BATTLE_GROUND_Y + lane_offset
	)
	unit.z_index = 4 + lane
	unit.expired.connect(_on_unit_expired)
	unit.death_started.connect(_on_unit_death_started)
	unit.poison_tick.connect(_on_unit_poison_tick)
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
	_update_progress_ui()
	var d := _diff()
	wave_active_timer = WAVE_DURATION
	wave_spawning = true
	enemy_spawn_index = 0
	ai_spawn.set_difficulty(current_difficulty)
	ai_spawn.begin_wave(wave_number, int(d.boss_wave))
	if fx_manager != null:
		fx_manager.emit_wave_start(Vector2(360, BATTLE_GROUND_Y - 36.0), Color("#ff9a78"), enemy_era)
	_enemy_ai_take_turn()

func _setup_ai_spawn() -> void:
	ai_spawn.setup(
		rng,
		func() -> String: return enemy_era,
		func() -> int: return _living_units("enemy").size(),
		_spawn_ai_enemy,
		ENEMY_UNIT_CAP,
		func() -> int: return enemy_era_index
	)
	ai_spawn.set_difficulty(current_difficulty)

func _spawn_ai_enemy(hero_id: String) -> bool:
	var unit := _spawn_enemy(hero_id, enemy_spawn_index % 3, 3)
	if unit == null:
		return false
	enemy_spawn_index += 1
	return true

func _enemy_rally_surge() -> void:
	var room := ENEMY_UNIT_CAP - _living_units("enemy").size()
	if room <= 0:
		return
	var burst := mini(AiSpawnConfig.rally_burst(enemy_era_index), room)
	for _i in range(burst):
		ai_spawn.spawn_one(true)
	ai_spawn.on_rally()
	_announce_enemy_action("敌方拼死反扑！", "")
	AudioManager.play_sfx("era")
	_update_tower_ui()

func _enemy_ai_take_turn() -> void:
	var d := _diff()
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

func _spawn_enemy(hero_id: String, index: int, total_count: int, apply_diff := true) -> BattleUnit:
	if _living_units("enemy").size() >= ENEMY_UNIT_CAP:
		return null
	var data: Dictionary = GameData.HEROES[hero_id].duplicate(true)
	var mult := float(_diff().enemy_mult) if apply_diff else 1.0
	data["hp"] = float(data.hp) * mult
	data["attack"] = float(data.attack) * mult
	var texture: Texture2D
	var path := GameData.hero_texture_path(hero_id)
	if path != "":
		texture = load(path)
	var unit := BattleUnit.new()
	unit.setup(hero_id, "enemy", data, texture)
	var spacing := minf(78.0, 300.0 / maxf(1.0, float(total_count - 1)))
	var lane := enemy_lane_cursor % BATTLE_LANES
	enemy_lane_cursor += 1
	var lane_offset := (float(lane) - float(BATTLE_LANES - 1) * 0.5) * BATTLE_LANE_STEP
	unit.position = Vector2(
		ENEMY_TOWER_X - 70.0 - index * spacing,
		BATTLE_GROUND_Y + lane_offset
	)
	unit.z_index = 4 + lane
	unit.expired.connect(_on_unit_expired)
	unit.death_started.connect(_on_unit_death_started)
	unit.poison_tick.connect(_on_unit_poison_tick)
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
		if unit.stun_time > 0.0:
			unit.set_moving(false)
			continue
		unit.attack_cooldown = maxf(0.0, unit.attack_cooldown - delta)
		if unit.skill_ready() and _is_seek_skill(_skill_type(unit)):
			if unit.attack_cooldown <= 0.0 and _try_cast_skill(unit, null):
				continue
		var tower_x := ENEMY_TOWER_X if unit.faction == "ally" else ALLY_TOWER_X
		# Prefer towers once inside full attack range (not engage/stop distance).
		# Ranged units engage at ~range*0.72 for troops, but can still hit towers at stats.range.
		var tower_reach := maxf(float(unit.stats.get("range", 0.0)), TOWER_RANGE)
		if absf(tower_x - unit.position.x) <= tower_reach:
			unit.set_moving(false)
			if unit.attack_cooldown <= 0.0:
				_attack_tower(unit)
			continue
		var target := _find_target(unit, ally_units, enemy_units)
		if target != null:
			var distance := absf(target.position.x - unit.position.x)
			var engage := _engage_distance(unit)
			var in_range := distance <= float(unit.stats.range)
			if distance > engage:
				_move_unit(unit, target.position.x, delta)
				if in_range and unit.attack_cooldown <= 0.0:
					if not _try_cast_skill(unit, target):
						_attack(unit, target)
			elif unit.attack_cooldown <= 0.0:
				if not _try_cast_skill(unit, target):
					_attack(unit, target)
		else:
			if absf(tower_x - unit.position.x) > TOWER_RANGE:
				_move_unit(unit, tower_x, delta)
			elif unit.attack_cooldown <= 0.0:
				_attack_tower(unit)
	ally_tower_cd = maxf(0.0, ally_tower_cd - delta)
	enemy_tower_cd = maxf(0.0, enemy_tower_cd - delta)
	_process_tower_attack(true, enemy_units)
	_process_tower_attack(false, ally_units)
	if enemy_tower_hp <= 0.0:
		_on_enemy_tower_destroyed()
	elif ally_tower_hp <= 0.0:
		_trigger_tower_destruction(false)

func _find_tower_target(ally: bool, candidates: Array[BattleUnit]) -> BattleUnit:
	var tower_x := ALLY_TOWER_X if ally else ENEMY_TOWER_X
	var nearest: BattleUnit
	var nearest_distance := TOWER_ATTACK_RANGE + 1.0
	for unit in candidates:
		if not is_instance_valid(unit) or not unit.targetable():
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
	speed *= unit.move_speed_multiplier()
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

func _engage_distance(unit: BattleUnit) -> float:
	var unit_range := float(unit.stats.get("range", 0.0))
	if unit_range < PROJECTILE_RANGE_THRESHOLD:
		return unit_range
	return clampf(unit_range * 0.72, PROJECTILE_RANGE_THRESHOLD, unit_range)

func _unit_damage(attacker: BattleUnit) -> float:
	var damage := float(attacker.stats.attack)
	if _buff_active_side(attacker.faction, "morale"):
		damage *= 1.25
	if attacker.berserk_time > 0.0:
		damage *= attacker.berserk_atk
	if attacker.faction == "ally":
		var crit_chance := run_crit_chance
		var crit_mult := 1.5
		if str(attacker.stats.get("role", "")) == "assassin":
			crit_chance += run_assassin_crit_chance
			crit_mult += run_assassin_crit_mult
		if crit_chance > 0.0 and rng.randf() < crit_chance:
			damage *= crit_mult
	return damage

func _deal_damage(target: BattleUnit, amount: float, source: String, attacker: BattleUnit = null) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	if target.invuln_time > 0.0:
		_spawn_hit_fx(target.position, Color("#9ff2ff"), "免疫", 0.4)
		return
	if target.dodge_time > 0.0 and attacker != null:
		_spawn_hit_fx(target.position, Color("#c9a8ff"), "闪避", 0.4)
		return
	var damage := amount
	if _buff_active_side(target.faction, "bulwark"):
		damage *= 0.7
	if target.faction == "ally" and run_tank_reduce > 0.0 and str(target.stats.get("role", "")) == "tank":
		damage *= 1.0 - run_tank_reduce
	if target.shield_time > 0.0:
		damage *= 1.0 - target.shield_reduce
	if target.reflect_time > 0.0:
		damage *= 1.0 - target.reflect_shield_reduce
	target.receive_damage(damage, source)
	if attacker == null or not is_instance_valid(attacker) or not attacker.alive:
		return
	_register_backstab_retaliate(target, attacker, source)
	if _buff_active_side(attacker.faction, "lifesteal"):
		var heal_amount := damage * 0.2
		attacker.heal(heal_amount)
		if fx_manager != null:
			fx_manager.emit_lifesteal(
				target.position,
				attacker.position + Vector2(0, -56.0),
				current_era if attacker.faction == "ally" else enemy_era
			)
	if attacker.faction == "ally" and run_lifesteal > 0.0:
		attacker.heal(damage * run_lifesteal)
	var melee := float(attacker.stats.get("range", 0.0)) < PROJECTILE_RANGE_THRESHOLD
	if melee and attacker.faction != target.faction and _buff_active_side(target.faction, "thorns"):
		attacker.receive_damage(damage * 0.3, "hero")
	if melee and attacker.faction != target.faction and target.reflect_time > 0.0:
		attacker.receive_damage(damage * target.reflect_frac, "hero")

func _register_backstab_retaliate(target: BattleUnit, attacker: BattleUnit, source: String) -> void:
	if source != "hero":
		return
	if attacker.faction == target.faction:
		return
	var melee := float(attacker.stats.get("range", 0.0)) < PROJECTILE_RANGE_THRESHOLD
	if not melee:
		return
	if _is_front_candidate(target, attacker):
		return
	# untargetable（如 phase_execute 1.5s）结束后仍需有有效还击窗口
	var window := BACKSTAB_RETALIATE_DURATION
	if attacker.untargetable_time > 0.0:
		window = maxf(window, attacker.untargetable_time + BACKSTAB_RETALIATE_DURATION)
	target.add_backstab_retaliate(attacker, window)

func _find_target(unit: BattleUnit, ally_units: Array[BattleUnit], enemy_units: Array[BattleUnit]) -> BattleUnit:
	var source_candidates := enemy_units if unit.faction == "ally" else ally_units
	var candidates: Array[BattleUnit] = []
	for candidate in source_candidates:
		if is_instance_valid(candidate) and candidate.targetable():
			candidates.append(candidate)
	if candidates.is_empty():
		return null
	if unit.taunt_time > 0.0 and is_instance_valid(unit.taunted_by) and unit.taunted_by.alive:
		return unit.taunted_by
	# 方案 A：身后近战仇恨窗口内，优先还击该攻击者（不废除默认前方优先）
	var retaliate := unit.backstab_retaliate_by
	if unit.backstab_retaliate_time > 0.0 and is_instance_valid(retaliate) and retaliate.alive and retaliate.targetable():
		return retaliate
	var aggro_tanks: Array[BattleUnit] = []
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate.alive:
			continue
		if str(candidate.stats.get("role", "")) != "tank":
			continue
		if absf(candidate.position.x - unit.position.x) <= TANK_AGGRO_RADIUS and _is_front_candidate(unit, candidate):
			aggro_tanks.append(candidate)
	if not aggro_tanks.is_empty():
		return _nearest_unit(unit, aggro_tanks)
	return _nearest_unit(unit, candidates)

func _nearest_unit(unit: BattleUnit, candidates: Array[BattleUnit]) -> BattleUnit:
	var nearest_front: BattleUnit
	var nearest_front_distance := INF
	var nearest_any: BattleUnit
	var nearest_any_distance := INF
	for candidate in candidates:
		if not is_instance_valid(candidate) or not candidate.alive:
			continue
		var distance := absf(candidate.position.x - unit.position.x)
		if distance < nearest_any_distance:
			nearest_any = candidate
			nearest_any_distance = distance
		if _is_front_candidate(unit, candidate) and distance < nearest_front_distance:
			nearest_front = candidate
			nearest_front_distance = distance
	return nearest_front if nearest_front != null else nearest_any

func _is_front_candidate(unit: BattleUnit, candidate: BattleUnit) -> bool:
	# 身后还击窗口：对该攻击者临时关闭前方过滤（其余目标仍走前方优先）
	if unit.backstab_retaliate_time > 0.0 and unit.backstab_retaliate_by == candidate:
		return true
	if unit.faction == "ally":
		return candidate.position.x >= unit.position.x - FRONT_TOLERANCE
	return candidate.position.x <= unit.position.x + FRONT_TOLERANCE

func _skill_data(unit: BattleUnit) -> Dictionary:
	var value: Variant = unit.stats.get("skill", {})
	return value if value is Dictionary else {}

func _skill_type(unit: BattleUnit) -> String:
	return str(_skill_data(unit).get("type", ""))

func _skill_color(unit: BattleUnit) -> Color:
	return Color("#ffd273") if unit.faction == "ally" else Color("#ff8e70")

## 会主动扑向目标的突进类技能，不需要目标已在攻击距离内
func _is_seek_skill(skill_type: String) -> bool:
	return skill_type in ["blink_crit", "decap_strike", "phase_execute"]

func _spend_unit_attack_time(unit: BattleUnit) -> void:
	unit.spend_attack_time()
	if _buff_active_side(unit.faction, "frenzy"):
		unit.attack_cooldown /= 1.4
	if unit.berserk_time > 0.0:
		unit.attack_cooldown /= unit.berserk_aspd

func _try_cast_skill(unit: BattleUnit, target: BattleUnit) -> bool:
	if not unit.skill_ready():
		return false
	var skill_type := _skill_type(unit)
	if _is_seek_skill(skill_type):
		target = _lowest_health_enemy(unit, 600.0)
	if target == null or not is_instance_valid(target) or not target.alive:
		return false
	_spend_unit_attack_time(unit)
	unit.play_attack()
	unit.energy = 0.0
	if unit.skill_once:
		unit.skill_used = true
	_cast_skill(unit, target)
	return true

func _whirlwind_tick(unit: BattleUnit, color: Color) -> void:
	if not is_instance_valid(unit) or not unit.alive:
		return
	var enemies := _living_units("enemy" if unit.faction == "ally" else "ally")
	for enemy in enemies:
		if enemy.position.distance_to(unit.position) <= 120.0:
			_deal_damage(enemy, _unit_damage(unit) * 0.8, "hero", unit)
			_spawn_hit_fx(enemy.position, color, "斩击", 0.4)

func _cast_skill(unit: BattleUnit, target: BattleUnit) -> void:
	var skill_type := _skill_type(unit)
	var skill_name := str(_skill_data(unit).get("name", skill_type))
	var color := _skill_color(unit)
	var stun_mult := run_stun_mult if unit.faction == "ally" else 1.0
	_spawn_hit_fx(unit.position, color, skill_name, 0.8, -12.0)
	_spawn_skill_icon_fx(unit, skill_type)
	var era := str(unit.stats.get("era", "stone"))
	match skill_type:
		"taunt_shield":
			unit.add_shield(4.0, 0.4)
			for enemy in _living_units("enemy" if unit.faction == "ally" else "ally"):
				if enemy.position.distance_to(unit.position) <= 180.0:
					enemy.add_taunt(unit, 3.0)
			if fx_manager != null:
				fx_manager.emit_ring(unit.position, Color("#ffd273"), 58.0, 0.7, 0)
				fx_manager.emit("effect", unit.position + Vector2(0, -48), Vector2.UP, era, 1, 18, Color("#ffe8a0"))
		"smash_stun":
			_deal_damage(target, _unit_damage(unit) * 2.0, "hero", unit)
			target.add_stun(1.5 * stun_mult)
			_spawn_hit_fx(target.position, Color("#fff0bd"), "眩晕", 0.65)
			if fx_manager != null:
				fx_manager.emit("blast", target.position, Vector2.UP, era, 0, 22, color)
				fx_manager.emit_impact_line(target.position, target.position - unit.position, Color("#fff4c4"), 0.2)
		"poison":
			target.add_poison(5.0, _unit_damage(unit) * 0.6, unit.faction)
			_spawn_hit_fx(target.position, Color("#9df078"), "中毒", 0.7)
			if fx_manager != null:
				fx_manager.emit("smoke", target.position + Vector2(0, -34), Vector2.UP, era, 1, 12, Color("#7bd66a"))
				fx_manager.emit_ring(target.position, Color("#8ee56d"), 34.0, 0.5, 1)
		"boulder_splash":
			_cast_boulder_splash(unit, target)
		"aoe_stun":
			var enemies := _living_units("enemy" if unit.faction == "ally" else "ally")
			for enemy in enemies:
				if enemy.position.distance_to(unit.position) <= 200.0:
					enemy.add_stun(2.5 * stun_mult)
					_spawn_hit_fx(enemy.position, Color("#fff0bd"), "眩晕", 0.65)
			if fx_manager != null:
				fx_manager.emit_shockwave(unit.position, color, 200.0)
			_shake_battlefield()
		"thorns_shield":
			unit.add_reflect(5.0, 0.3, 0.5)
			if fx_manager != null:
				fx_manager.emit_ring(unit.position, Color("#d7e9ff"), 60.0, 0.7, 0)
				for index in range(4):
					fx_manager.emit_impact_line(unit.position, Vector2.RIGHT.rotated(float(index) * TAU / 4.0), Color("#eaf4ff"), 0.2)
		"whirlwind":
			unit.play_spin(0.55, 3)
			unit.play_whirlwind_trail(color, 0.55, 3)
			_whirlwind_tick(unit, color)
			var whirlwind_tween := create_tween()
			whirlwind_tween.tween_interval(0.2)
			whirlwind_tween.tween_callback(_whirlwind_tick.bind(unit, color))
			whirlwind_tween.tween_interval(0.2)
			whirlwind_tween.tween_callback(_whirlwind_tick.bind(unit, color))
			if fx_manager != null:
				var center := unit.position + Vector2(0, -40)
				fx_manager.emit_shockwave(center, color, 130.0)
				for index in range(8):
					var dir := Vector2.RIGHT.rotated(float(index) * TAU / 8.0)
					fx_manager.emit_impact_line(center + dir * 60.0, dir, color, 0.2)
			_shake_battlefield()
			var finish := create_tween()
			finish.tween_interval(0.5)
			finish.tween_callback(func() -> void:
				if is_instance_valid(unit) and unit.alive and fx_manager != null:
					fx_manager.emit_slash_arc(
						unit.position + Vector2(0, -54),
						color,
						120.0,
						1.0 if unit.faction == "ally" else -1.0
					)
					fx_manager.emit("blast", unit.position, Vector2.UP, era, 0, 14, color)
			)
		"blink_crit":
			var from := unit.position
			var facing := 1.0 if unit.faction == "ally" else -1.0
			unit.position = target.position + Vector2(-facing * 44.0, 0)
			_deal_damage(target, _unit_damage(unit) * 2.5, "hero", unit)
			_spawn_hit_fx(target.position, Color("#fff4ae"), "暴击!", 0.8)
			if fx_manager != null:
				fx_manager.emit_afterimage(from, unit.position, Color("#c78cff"))
				fx_manager.emit_hit(target.position, Vector2(facing, 0), era)
		"multishot":
			_cast_multishot(unit, target)
		"berserk":
			unit.add_berserk(8.0, 1.5, 1.5)
			if fx_manager != null:
				fx_manager.emit_ring(unit.position, Color("#ff665c"), 62.0, 0.75, 0)
				fx_manager.emit("effect", unit.position + Vector2(0, -52), Vector2.UP, era, 1, 20, Color("#ff665c"))
			var pulse := create_tween()
			pulse.tween_property(unit, "scale", Vector2(1.12, 1.12), 0.12)
			pulse.tween_property(unit, "scale", Vector2.ONE, 0.18)
		"overpressure_steam":
			_cast_overpressure_steam(unit, stun_mult)
		"piston_charge":
			_cast_piston_charge(unit, target, stun_mult)
		"smoke_raid":
			_cast_smoke_raid(unit, target)
		"shotgun_blast":
			_cast_shotgun_blast(unit)
		"overpressure_burst":
			_cast_overpressure_burst(unit, stun_mult)
		"shield_wall":
			_cast_shield_wall(unit, target, stun_mult)
		"suppress_fire":
			_cast_suppress_fire(unit, target)
		"decap_strike":
			_cast_decap_strike(unit, target)
		"lethal_snipe":
			_cast_lethal_snipe(unit)
		"artillery_support":
			_cast_artillery_support(unit, stun_mult)
		"force_field":
			_cast_force_field(unit)
		"laser_slash":
			_cast_laser_slash(unit)
		"phase_execute":
			_cast_phase_execute(unit, target)
		"plasma_lance":
			_cast_plasma_lance(unit)
		"overload_barrage":
			_cast_overload_barrage(unit, stun_mult)

func _lowest_health_enemy(unit: BattleUnit, radius: float) -> BattleUnit:
	var candidates := _living_units("enemy" if unit.faction == "ally" else "ally")
	var result: BattleUnit
	var lowest := INF
	for candidate in candidates:
		if candidate.position.distance_to(unit.position) > radius:
			continue
		if candidate.hp < lowest:
			result = candidate
			lowest = candidate.hp
	return result

func _cast_boulder_splash(attacker: BattleUnit, target: BattleUnit) -> void:
	var start_pos := attacker.position + Vector2(30.0 if attacker.faction == "ally" else -30.0, -56.0)
	var impact_position := target.position
	var target_pos := func() -> Variant:
		if is_instance_valid(target) and target.alive:
			return target.position + Vector2(0, -56.0)
		return impact_position
	var damage := _unit_damage(attacker) * 1.2
	var on_hit := func() -> void:
		var victims := _living_units("enemy" if attacker.faction == "ally" else "ally")
		for victim in victims:
			if victim.position.distance_to(impact_position) <= 90.0:
				_deal_damage(victim, damage, "hero", attacker)
		_spawn_hit_fx(impact_position, Color("#ffe09a"), "巨石!", 0.65)
		if fx_manager != null:
			fx_manager.emit("blast", impact_position, Vector2.UP, str(attacker.stats.era), 0, 28, Color("#dfbb79"))
			fx_manager.emit_ring(impact_position, Color("#ffe09a"), 90.0, 0.6, 0)
	var projectile := Projectile.new()
	projectile.setup(start_pos, target_pos, 180.0, str(attacker.stats.era), Color("#dfbb79"), on_hit)
	world.add_child(projectile)

func _cast_multishot(attacker: BattleUnit, target: BattleUnit) -> void:
	var candidates := _living_units("enemy" if attacker.faction == "ally" else "ally")
	candidates.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return a.position.distance_to(attacker.position) < b.position.distance_to(attacker.position)
	)
	var count := mini(3, candidates.size())
	for index in range(count):
		var victim: BattleUnit = candidates[index]
		_deal_damage(victim, _unit_damage(attacker), "hero", attacker)
		_spawn_hit_fx(victim.position, Color("#e7ff9b"), "箭", 0.35)
		if fx_manager != null:
			fx_manager.emit_hit(victim.position, (victim.position - attacker.position).normalized(), str(attacker.stats.era))

func _skill_icon_path(skill_type: String) -> String:
	var path := SKILL_ICON_PATH % skill_type
	return path if ResourceLoader.exists(path) else ""

func _spawn_skill_icon_fx(unit: BattleUnit, skill_type: String) -> void:
	var path := _skill_icon_path(skill_type)
	if path == "":
		return
	var texture := load(path) as Texture2D
	if texture == null:
		return
	var icon := Sprite2D.new()
	icon.texture = texture
	icon.position = unit.position + Vector2(0, -unit.body_height - 46.0)
	icon.z_index = 7
	icon.scale = Vector2(0.5, 0.5)
	world.add_child(icon)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(icon, "scale", Vector2(0.85, 0.85), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "position:y", icon.position.y - 24.0, 0.7)
	tween.chain().tween_property(icon, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(icon.queue_free)

func _skill_facing(unit: BattleUnit) -> float:
	return 1.0 if unit.faction == "ally" else -1.0

func _opposing_units(unit: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for candidate in _living_units("enemy" if unit.faction == "ally" else "ally"):
		if candidate.targetable():
			result.append(candidate)
	return result

func _friendly_units(unit: BattleUnit) -> Array[BattleUnit]:
	return _living_units(unit.faction)

func _delayed_call(delay: float, action: Callable) -> void:
	var tween := create_tween()
	tween.tween_interval(maxf(0.0, delay))
	tween.tween_callback(action)

func _knockback(victim: BattleUnit, facing: float, distance: float) -> void:
	if not is_instance_valid(victim) or not victim.alive:
		return
	var destination := clampf(
		victim.position.x + facing * distance,
		ALLY_TOWER_X + 40.0,
		ENEMY_TOWER_X - 40.0
	)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(victim, "position:x", destination, 0.18)

func _cone_victims(unit: BattleUnit, radius: float, half_angle: float) -> Array[BattleUnit]:
	var facing := _skill_facing(unit)
	var result: Array[BattleUnit] = []
	for victim in _opposing_units(unit):
		var offset := victim.position - unit.position
		if offset.length() > radius:
			continue
		if signf(offset.x) != facing and absf(offset.x) > 12.0:
			continue
		var angle := absf(atan2(offset.y, absf(offset.x)))
		if angle <= half_angle:
			result.append(victim)
	return result

func _line_victims(unit: BattleUnit, length: float, half_height: float) -> Array[BattleUnit]:
	var facing := _skill_facing(unit)
	var result: Array[BattleUnit] = []
	for victim in _opposing_units(unit):
		var offset := victim.position - unit.position
		if signf(offset.x) != facing and absf(offset.x) > 12.0:
			continue
		if absf(offset.x) > length or absf(offset.y) > half_height:
			continue
		result.append(victim)
	result.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return absf(a.position.x - unit.position.x) < absf(b.position.x - unit.position.x)
	)
	return result

func _radius_victims(unit: BattleUnit, center: Vector2, radius: float) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for victim in _opposing_units(unit):
		if victim.position.distance_to(center) <= radius:
			result.append(victim)
	return result

func _dash_to(unit: BattleUnit, destination_x: float, duration := 0.16) -> void:
	var destination := clampf(destination_x, ALLY_TOWER_X + 40.0, ENEMY_TOWER_X - 40.0)
	if fx_manager != null:
		fx_manager.emit_afterimage(unit.position, Vector2(destination, unit.position.y), _skill_color(unit))
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "position:x", destination, duration)

func _cast_overpressure_steam(unit: BattleUnit, stun_mult: float) -> void:
	var era := str(unit.stats.get("era", "industrial"))
	unit.add_shield(6.0, 0.55)
	var facing := _skill_facing(unit)
	for victim in _radius_victims(unit, unit.position, 190.0):
		_deal_damage(victim, _unit_damage(unit) * 0.6, "hero", unit)
		victim.add_slow(4.0, 0.55)
		victim.add_stun(0.3 * stun_mult)
		_knockback(victim, signf(victim.position.x - unit.position.x) if victim.position.x != unit.position.x else facing, 74.0)
		_spawn_hit_fx(victim.position, Color("#bfe6ff"), "泄压", 0.45)
	if fx_manager != null:
		fx_manager.emit_dome(unit.position, Color("#ffd273"), 62.0, 1.1)
		fx_manager.emit_shockwave(unit.position, Color("#e8e2d2"), 190.0)
		fx_manager.emit_smoke_cloud(unit.position, Color("#e6e6e6"), 150.0, era)
	_shake_battlefield()

func _cast_piston_charge(unit: BattleUnit, target: BattleUnit, stun_mult: float) -> void:
	var facing := _skill_facing(unit)
	var start_x := unit.position.x
	var destination_x := target.position.x - facing * 46.0
	_dash_to(unit, destination_x, 0.18)
	_delayed_call(0.18, func() -> void:
		if not is_instance_valid(unit) or not unit.alive:
			return
		var low := minf(start_x, unit.position.x) - 30.0
		var high := maxf(start_x, unit.position.x) + 30.0
		var first: BattleUnit
		for victim in _opposing_units(unit):
			if victim.position.x < low or victim.position.x > high:
				continue
			if absf(victim.position.y - unit.position.y) > 46.0:
				continue
			_deal_damage(victim, _unit_damage(unit) * 0.9, "hero", unit)
			if first == null or absf(victim.position.x - unit.position.x) < absf(first.position.x - unit.position.x):
				first = victim
		if first == null:
			first = target
		if is_instance_valid(first) and first.alive:
			_deal_damage(first, _unit_damage(unit) * 1.6, "hero", unit)
			first.add_stun(1.4 * stun_mult)
			_knockback(first, facing, 96.0)
			_spawn_hit_fx(first.position, Color("#ffcf7a"), "冲拳!", 0.6)
			if fx_manager != null:
				fx_manager.emit("blast", first.position + Vector2(0, -44), Vector2.UP, str(unit.stats.era), 0, 20, Color("#ffcf7a"))
				fx_manager.emit_impact_line(first.position + Vector2(0, -44), Vector2(facing, 0), Color("#fff4c4"), 0.2)
		if fx_manager != null:
			fx_manager.emit_smoke_cloud(Vector2(start_x, unit.position.y), Color("#dcdcdc"), 70.0, str(unit.stats.era))
		_shake_battlefield()
	)

func _cast_smoke_raid(unit: BattleUnit, target: BattleUnit) -> void:
	var era := str(unit.stats.get("era", "industrial"))
	unit.add_dodge(2.0)
	target.add_poison(5.0, _unit_damage(unit) * 0.6, unit.faction)
	_spawn_hit_fx(target.position, Color("#9df078"), "中毒", 0.6)
	for victim in _radius_victims(unit, target.position, 150.0):
		victim.add_blind(4.0)
		victim.add_slow(3.0, 0.6)
		_spawn_hit_fx(victim.position, Color("#b7b7b7"), "致盲", 0.5)
	if fx_manager != null:
		fx_manager.emit_smoke_cloud(target.position, Color("#c8ccc9"), 150.0, era)
		fx_manager.emit_ring(unit.position, Color("#9fb3b0"), 60.0, 0.5, 1)

func _cast_shotgun_blast(unit: BattleUnit) -> void:
	var facing := _skill_facing(unit)
	var victims := _cone_victims(unit, 230.0, 0.42)
	for victim in victims:
		_deal_damage(victim, _unit_damage(unit) * 1.1, "hero", unit)
		_knockback(victim, facing, 58.0)
		_spawn_hit_fx(victim.position, Color("#ffd9a0"), "霰弹", 0.4)
		if fx_manager != null:
			fx_manager.emit_hit(victim.position, Vector2(facing, 0), str(unit.stats.era))
	if fx_manager != null:
		fx_manager.emit_cone(unit.position, facing, 230.0, 0.42, Color("#ffcf7a"), 0.34)
		fx_manager.emit("smoke", unit.position + Vector2(facing * 34.0, -52.0), Vector2(facing, 0), str(unit.stats.era), 1, 8, Color("#e8e8e8"))

func _cast_overpressure_burst(unit: BattleUnit, stun_mult: float) -> void:
	var era := str(unit.stats.get("era", "industrial"))
	for victim in _radius_victims(unit, unit.position, 240.0):
		_deal_damage(victim, _unit_damage(unit) * 1.4, "hero", unit)
		victim.add_stun(2.0 * stun_mult)
		_spawn_hit_fx(victim.position, Color("#fff0bd"), "眩晕", 0.55)
	for friend in _friendly_units(unit):
		friend.add_berserk(10.0, 1.0, 1.4)
	_spawn_hit_fx(unit.position, Color("#ffcf7a"), "攻速光环", 0.7, -40.0)
	if fx_manager != null:
		fx_manager.emit_shockwave(unit.position, Color("#ffcf7a"), 240.0)
		fx_manager.emit_smoke_cloud(unit.position, Color("#efefef"), 210.0, era)
		fx_manager.emit_dome(unit.position, Color("#ffb347"), 90.0, 0.8)
	_shake_battlefield()

func _cast_shield_wall(unit: BattleUnit, target: BattleUnit, stun_mult: float) -> void:
	var facing := _skill_facing(unit)
	for friend in _friendly_units(unit):
		if (friend.position.x - unit.position.x) * facing > 20.0:
			continue
		if absf(friend.position.x - unit.position.x) > 300.0:
			continue
		friend.add_shield(6.0, 0.35)
		if fx_manager != null:
			fx_manager.emit_ring(friend.position, Color("#7fb8ff"), 44.0, 0.5, 2)
	_deal_damage(target, _unit_damage(unit) * 1.2, "hero", unit)
	target.add_stun(1.5 * stun_mult)
	_knockback(target, facing, 46.0)
	_spawn_hit_fx(target.position, Color("#cfe4ff"), "盾击", 0.55)
	if fx_manager != null:
		fx_manager.emit_dome(unit.position, Color("#7fb8ff"), 64.0, 1.0)
		fx_manager.emit_impact_line(target.position + Vector2(0, -46), Vector2(facing, 0), Color("#dceaff"), 0.22)
	_shake_battlefield()

func _cast_suppress_fire(unit: BattleUnit, target: BattleUnit) -> void:
	var impact := target.position
	for index in range(5):
		_delayed_call(0.12 * float(index), func() -> void:
			if not is_instance_valid(unit) or not unit.alive:
				return
			var center := target.position if is_instance_valid(target) and target.alive else impact
			for victim in _radius_victims(unit, center, 90.0):
				_deal_damage(victim, _unit_damage(unit) * 0.45, "hero", unit)
				victim.add_slow(3.0, 0.6)
				if fx_manager != null:
					fx_manager.emit_hit(victim.position, (victim.position - unit.position).normalized(), str(unit.stats.era))
			if fx_manager != null:
				fx_manager.emit_beam(
					unit.position + Vector2(_skill_facing(unit) * 26.0, -56.0),
					center + Vector2(rng.randf_range(-20.0, 20.0), -50.0),
					Color("#ffe9a8"),
					4.0,
					0.14
				)
		)
	_spawn_hit_fx(target.position, Color("#ffe9a8"), "压制", 0.6)

func _cast_decap_strike(unit: BattleUnit, target: BattleUnit) -> void:
	var facing := _skill_facing(unit)
	_dash_to(unit, target.position.x - facing * 40.0, 0.14)
	_delayed_call(0.14, func() -> void:
		if not is_instance_valid(unit) or not unit.alive or not is_instance_valid(target) or not target.alive:
			return
		var missing := 1.0 - clampf(target.hp / maxf(1.0, target.max_hp), 0.0, 1.0)
		var damage := _unit_damage(unit) * (1.8 + missing * 2.2)
		_deal_damage(target, damage, "hero", unit)
		_spawn_hit_fx(target.position, Color("#ff9f6b"), "斩首!", 0.7)
		if fx_manager != null:
			fx_manager.emit_slash_arc(target.position + Vector2(0, -54), Color("#ffd0b0"), 90.0, facing)
			fx_manager.emit_hit(target.position, Vector2(facing, 0), str(unit.stats.era))
	)

func _cast_lethal_snipe(unit: BattleUnit) -> void:
	var facing := _skill_facing(unit)
	if fx_manager != null:
		fx_manager.emit_charge_up(unit.position + Vector2(facing * 26.0, -56.0), Color("#ffe9a8"), 0.4)
	_delayed_call(0.4, func() -> void:
		if not is_instance_valid(unit) or not unit.alive:
			return
		var origin := unit.position + Vector2(facing * 26.0, -56.0)
		var victims := _line_victims(unit, 560.0, 34.0)
		for victim in victims:
			_deal_damage(victim, _unit_damage(unit) * 2.0 * 1.5, "hero", unit)
			_spawn_hit_fx(victim.position, Color("#fff4ae"), "暴击!", 0.6)
			if fx_manager != null:
				fx_manager.emit_hit(victim.position, Vector2(facing, 0), str(unit.stats.era))
		if fx_manager != null:
			fx_manager.emit_beam(origin, origin + Vector2(facing * 560.0, 0), Color("#fff0c0"), 7.0, 0.3)
		AudioManager.play_sfx("hit")
	)

func _cast_artillery_support(unit: BattleUnit, stun_mult: float) -> void:
	var facing := _skill_facing(unit)
	for friend in _friendly_units(unit):
		friend.add_berserk(12.0, 1.35, 1.0)
	_spawn_hit_fx(unit.position, Color("#ffd273"), "攻击增益", 0.7, -40.0)
	var victims := _opposing_units(unit)
	var centers: Array[Vector2] = []
	if victims.is_empty():
		centers.append(unit.position + Vector2(facing * 260.0, 0))
	else:
		victims.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return absf(a.position.x - unit.position.x) < absf(b.position.x - unit.position.x)
		)
		for index in range(mini(3, victims.size())):
			centers.append(victims[index].position)
	var damage := _unit_damage(unit) * 1.6
	for center in centers:
		if fx_manager != null:
			fx_manager.emit_warning_circle(center, Color("#ff8e70"), 110.0, 1.1)
		_delayed_call(1.1, func() -> void:
			if not is_instance_valid(unit):
				return
			for victim in _radius_victims(unit, center, 110.0):
				_deal_damage(victim, damage, "hero", unit)
				victim.add_stun(0.8 * stun_mult)
				_spawn_hit_fx(victim.position, Color("#ffb27a"), "轰炸", 0.5)
			if fx_manager != null:
				fx_manager.emit("blast", center + Vector2(0, -30), Vector2.UP, str(unit.stats.era), 0, 26, Color("#ffb27a"))
				fx_manager.emit_shockwave(center, Color("#ff8e70"), 110.0)
				fx_manager.emit_smoke_cloud(center, Color("#d8d2c8"), 110.0, str(unit.stats.era))
			_shake_battlefield()
			AudioManager.play_sfx("hit")
		)

func _cast_force_field(unit: BattleUnit) -> void:
	unit.add_invulnerable(1.6)
	for friend in _friendly_units(unit):
		friend.add_shield(8.0, 0.4)
		if fx_manager != null:
			fx_manager.emit_dome(friend.position, Color("#7ee8ff"), 48.0, 0.8)
	_spawn_hit_fx(unit.position, Color("#9ff2ff"), "全体护盾", 0.7, -40.0)
	if fx_manager != null:
		fx_manager.emit_dome(unit.position, Color("#9ff2ff"), 74.0, 1.4)
		fx_manager.emit_ring(unit.position, Color("#7ee8ff"), 120.0, 0.7, 0)

func _cast_laser_slash(unit: BattleUnit) -> void:
	var facing := _skill_facing(unit)
	var victims := _cone_victims(unit, 210.0, 0.72)
	for victim in victims:
		_deal_damage(victim, _unit_damage(unit) * 1.6, "hero", unit)
		victim.add_poison(4.0, _unit_damage(unit) * 0.3, unit.faction)
		_spawn_hit_fx(victim.position, Color("#8fd8ff"), "灼烧", 0.5)
	if fx_manager != null:
		fx_manager.emit_cone(unit.position, facing, 210.0, 0.72, Color("#3aa0d8"), 0.36)
		fx_manager.emit_slash_arc(unit.position + Vector2(0, -54), Color("#9fe0ff"), 150.0, facing)
		fx_manager.emit_beam(
			unit.position + Vector2(0, -54),
			unit.position + Vector2(facing * 210.0, -54),
			Color("#6fd0ff"),
			10.0,
			0.26
		)
	_shake_battlefield()

func _cast_phase_execute(unit: BattleUnit, target: BattleUnit) -> void:
	var facing := _skill_facing(unit)
	var from := unit.position
	unit.position = Vector2(
		clampf(target.position.x + facing * 44.0, ALLY_TOWER_X + 40.0, ENEMY_TOWER_X - 40.0),
		target.position.y
	)
	unit.add_untargetable(1.5)
	var ratio := target.hp / maxf(1.0, target.max_hp)
	var damage := _unit_damage(unit) * 2.0
	var executed := ratio <= 0.25
	if executed:
		damage *= 2.5
	_deal_damage(target, damage, "hero", unit)
	_spawn_hit_fx(target.position, Color("#e0a8ff"), "处决!" if executed else "相位斩", 0.7)
	if fx_manager != null:
		fx_manager.emit_afterimage(from, unit.position, Color("#c78cff"))
		fx_manager.emit_slash_arc(target.position + Vector2(0, -54), Color("#d9a8ff"), 96.0, -facing)
		fx_manager.emit_hit(target.position, Vector2(-facing, 0), str(unit.stats.era))

func _cast_plasma_lance(unit: BattleUnit) -> void:
	var facing := _skill_facing(unit)
	if fx_manager != null:
		fx_manager.emit_charge_up(unit.position + Vector2(facing * 28.0, -56.0), Color("#39c06a"), 0.45)
	_delayed_call(0.45, func() -> void:
		if not is_instance_valid(unit) or not unit.alive:
			return
		var origin := unit.position + Vector2(facing * 28.0, -56.0)
		for victim in _line_victims(unit, 620.0, 40.0):
			_deal_damage(victim, _unit_damage(unit) * 1.8, "hero", unit)
			_spawn_hit_fx(victim.position, Color("#8cf0a8"), "贯穿", 0.5)
			if fx_manager != null:
				fx_manager.emit_ring(victim.position, Color("#39c06a"), 46.0, 0.4, 1)
		if fx_manager != null:
			fx_manager.emit_beam(origin, origin + Vector2(facing * 620.0, 0), Color("#4fe08a"), 16.0, 0.34)
		_shake_battlefield()
		AudioManager.play_sfx("hit")
	)

func _cast_overload_barrage(unit: BattleUnit, stun_mult: float) -> void:
	var era := str(unit.stats.get("era", "future"))
	unit.add_berserk(10.0, 1.4, 1.4)
	var damage := _unit_damage(unit) * 0.7
	for index in range(6):
		_delayed_call(0.14 * float(index), func() -> void:
			if not is_instance_valid(unit) or not unit.alive:
				return
			var victims := _opposing_units(unit)
			if victims.is_empty():
				return
			var focus: BattleUnit = victims[rng.randi_range(0, victims.size() - 1)]
			var center := focus.position
			for victim in _radius_victims(unit, center, 70.0):
				_deal_damage(victim, damage, "hero", unit)
			if fx_manager != null:
				fx_manager.emit("blast", center + Vector2(0, -30), Vector2.UP, era, 1, 14, Color("#ff6b8e"))
				fx_manager.emit_ring(center, Color("#ff6b8e"), 70.0, 0.35, 1)
			_spawn_hit_fx(center, Color("#ff9db4"), "弹幕", 0.35)
		)
	_delayed_call(0.95, func() -> void:
		if not is_instance_valid(unit) or not unit.alive:
			return
		for victim in _radius_victims(unit, unit.position, 320.0):
			victim.add_stun(1.8 * stun_mult)
			victim.drain_energy()
			_spawn_hit_fx(victim.position, Color("#a8e8ff"), "EMP", 0.55)
		if fx_manager != null:
			fx_manager.emit_shockwave(unit.position, Color("#7ee8ff"), 320.0)
			fx_manager.emit_dome(unit.position, Color("#7ee8ff"), 120.0, 0.7)
		_shake_battlefield()
	)

func _apply_basic_splash(attacker: BattleUnit, target: BattleUnit, damage: float) -> void:
	var splash_value: Variant = attacker.stats.get("basic_splash", null)
	if not splash_value is Dictionary:
		return
	var splash: Dictionary = splash_value
	var radius := float(splash.get("radius", 0.0))
	var frac := float(splash.get("frac", 0.0))
	var candidates := _living_units("enemy" if attacker.faction == "ally" else "ally")
	for victim in candidates:
		if victim == target:
			continue
		if victim.position.distance_to(target.position) <= radius:
			_deal_damage(victim, damage * frac, "hero", attacker)
			if fx_manager != null:
				fx_manager.emit_hit(victim.position, Vector2.UP, str(attacker.stats.era))

func _on_unit_poison_tick(unit: BattleUnit, dps_amount: float, source: String) -> void:
	if not is_instance_valid(unit) or not unit.alive:
		return
	_deal_damage(unit, dps_amount, source)
	_spawn_hit_fx(unit.position, Color("#8ee56d"), "毒", 0.25)
	if fx_manager != null:
		fx_manager.emit("effect", unit.position + Vector2(0, -34), Vector2.UP, str(unit.stats.get("era", "stone")), 1, 3, Color("#8ee56d"))

func _attack(attacker: BattleUnit, target: BattleUnit) -> void:
	_spend_unit_attack_time(attacker)
	attacker.play_attack()
	if attacker.blind_time > 0.0 and rng.randf() < BLIND_MISS_CHANCE:
		attacker.gain_energy()
		_spawn_hit_fx(attacker.position, Color("#b7b7b7"), "失准", 0.35)
		return
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
				_apply_basic_splash(attacker, target, damage)
				attacker.gain_energy()
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
	_apply_basic_splash(attacker, target, damage)
	attacker.gain_energy()
	_spawn_hit_fx(target.position, Color("#ffd273"), "✦")
	if fx_manager != null:
		fx_manager.emit_hit(
			target.position,
			(target.position - attacker.position).normalized(),
			str(attacker.stats.era)
		)
	AudioManager.play_sfx("hit")

func _attack_tower(attacker: BattleUnit) -> void:
	_spend_unit_attack_time(attacker)
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
				if round_tower_thorns and float(attacker.stats.get("range", 0.0)) < PROJECTILE_RANGE_THRESHOLD and attacker.alive:
					attacker.receive_damage(damage * 0.4, "tower")
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
		if round_tower_thorns and float(attacker.stats.get("range", 0.0)) < PROJECTILE_RANGE_THRESHOLD and attacker.alive:
			attacker.receive_damage(damage * 0.4, "tower")
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
		# 方案甲：玩家击杀/塔击杀金币归零；积分弱化，主体改为过关关卡分+速度分
		if PLAYER_KILL_GOLD > 0:
			_change_coins(PLAYER_KILL_GOLD)
		var kill_score_value := int(unit.stats.get("kill_score", 0))
		if unit.last_damage_source != "tower":
			kill_score += maxi(0, int(round(float(kill_score_value) * KILL_SCORE_MULT)))
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
	if sandbox_mode:
		return
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

func _on_enemy_tower_destroyed() -> void:
	if sandbox_mode:
		return
	if enemy_tower_hp > 0.0:
		return
	if enemy_era_index >= GameData.ERAS.size() - 1:
		if not tower_destruction_started:
			_trigger_tower_destruction(true)
		return
	if reward_active and reward_context == "stage_clear":
		return
	if stage_clear_pending:
		return
	if reward_active:
		stage_clear_pending = true
		return
	_show_stage_clear_reward()

## 关卡编号（1 起）与文案：第 1 关=石器 … 第 5 关=未来
func _stage_number() -> int:
	return enemy_era_index + 1

func _stage_name(stage_number: int) -> String:
	var index := clampi(stage_number - 1, 0, GameData.ERAS.size() - 1)
	var era: String = GameData.ERAS[index]
	return "第 %d 关（%s）" % [stage_number, str(GameData.ERA_NAMES.get(era, era))]

## 本关目标用时（秒）：按难度表 + 关卡 index（0..4）取值；<=0 表示不计速度
func _stage_time_limit_for(stage_index: int) -> float:
	var table: Array = STAGE_TIME_LIMIT.get(current_difficulty, STAGE_TIME_LIMIT["normal"])
	if table.is_empty():
		return 0.0
	var idx := clampi(stage_index, 0, table.size() - 1)
	return float(table[idx])

## 进关/开局时重置并启动本关计时（累计已用；倒计时归零不失败）
func _reset_stage_timer() -> void:
	stage_time_limit = _stage_time_limit_for(enemy_era_index)
	stage_elapsed = 0.0
	stage_time_left = stage_time_limit
	stage_clear_economy_awarded = false
	_update_stage_timer_ui()

## 每帧累计已用时间（仅在战斗进行、未暂停、未开奖励面板时被调用 → 天然冻结）
func _tick_stage_timer(delta: float) -> void:
	if stage_time_limit <= 0.0 or battle_ended:
		return
	stage_elapsed += delta
	stage_time_left = maxf(0.0, stage_time_limit - stage_elapsed)
	_update_stage_timer_ui()

## 速度倍率：target / elapsed，夹在 [0.35, 1.6]
func _stage_speed_mult() -> float:
	if stage_time_limit <= 0.0:
		return 1.0
	return clampf(stage_time_limit / maxf(stage_elapsed, 1.0), CLEAR_GOLD_SPEED_MIN, CLEAR_GOLD_SPEED_MAX)

func _stage_speed_grade() -> String:
	if stage_time_limit <= 0.0:
		return "A"
	var ratio := stage_time_limit / maxf(stage_elapsed, 1.0)
	if ratio >= 1.3:
		return "S"
	if ratio >= 1.0:
		return "A"
	if ratio >= 0.7:
		return "B"
	if ratio >= CLEAR_GOLD_SPEED_MIN:
		return "C"
	return "D"

func _clear_gold_base_amount() -> int:
	var diff_mult := float(CLEAR_GOLD_DIFF_MULT.get(current_difficulty, 1.0))
	return maxi(1, int(round(float(_era_amount_for(enemy_era, CLEAR_GOLD_BASE)) * diff_mult)))

func _compute_clear_gold() -> int:
	var mult := _stage_speed_mult()
	mult *= maxf(0.0, round_coin_mult)
	if _buff_active("bounty"):
		mult *= BOUNTY_CLEAR_GOLD_MULT
	return maxi(1, int(round(float(_clear_gold_base_amount()) * mult)))

func _compute_stage_clear_scores() -> Dictionary:
	var stage_pts := int(round(float(STAGE_SCORE_BASE) * (1.0 + 0.15 * float(enemy_era_index))))
	var speed_pts := int(round(float(SPEED_SCORE_BASE) * _stage_speed_mult()))
	return {"stage": stage_pts, "speed": speed_pts}

## 过关/通关时发放速度金币与关卡+速度积分（幂等）
func _award_stage_clear_economy() -> Dictionary:
	var grade := _stage_speed_grade()
	if stage_clear_economy_awarded:
		return {"gold": 0, "stage_pts": 0, "speed_pts": 0, "grade": grade}
	stage_clear_economy_awarded = true
	var gold := _compute_clear_gold()
	var scores := _compute_stage_clear_scores()
	var stage_pts := int(scores.stage)
	var speed_pts := int(scores.speed)
	_change_coins(gold)
	kill_score += stage_pts + speed_pts
	_update_progress_ui()
	return {"gold": gold, "stage_pts": stage_pts, "speed_pts": speed_pts, "grade": grade}

func _update_stage_timer_ui() -> void:
	if stage_timer_label == null:
		return
	if not battle_active or battle_ended or stage_time_limit <= 0.0:
		stage_timer_label.text = "⏱ --:--"
		stage_timer_label.add_theme_color_override("font_color", Color("#f6d69f"))
		return
	var secs := int(floor(stage_elapsed))
	var grade := _stage_speed_grade()
	stage_timer_label.text = "⏱ %02d:%02d·%s" % [secs / 60, secs % 60, grade]
	var color := Color("#f6d69f")
	var ratio := stage_time_limit / maxf(stage_elapsed, 1.0)
	if ratio >= 1.3:
		color = Color("#8ce68c")
	elif ratio >= 1.0:
		color = Color("#f6d69f")
	elif ratio >= 0.7:
		color = Color("#ffd166")
	else:
		color = Color("#ff5a3c")
	stage_timer_label.add_theme_color_override("font_color", color)

## 把玩家时代下限提到当前关卡时代：牌池只升不降，已超前的轮次升级保留
func _sync_player_era_to_stage() -> void:
	base_era_index = maxi(base_era_index, enemy_era_index)
	era_index = maxi(era_index, base_era_index)
	current_era = GameData.ERAS[era_index]
	SaveManager.unlock_era(era_index)
	_refresh_era_visuals(true)

## 玩家牌池时代 +1（轮次升级），视觉与己方塔强度一并跟随
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

func _advance_enemy_era() -> void:
	if enemy_era_index >= GameData.ERAS.size() - 1:
		return
	enemy_era_index += 1
	enemy_era = GameData.ERAS[enemy_era_index]
	enemy_tower_max_hp = GameData.tower_hp(enemy_era)
	enemy_tower_hp = enemy_tower_max_hp
	enemy_rally_fired = 0
	_refresh_era_visuals(true)
	_update_tower_ui()
	AudioManager.play_sfx("era")
	if fx_manager != null:
		fx_manager.emit_era_transition(Vector2(360, 280), _era_fx_color(enemy_era), enemy_era)
	_announce_enemy_action("敌方防御塔重建：%s" % _stage_name(_stage_number()), "")

## 过关主路径：摧毁敌塔 → 进入下一关（新敌塔满血、双方清场、己方塔满血、发本关第 1 轮牌）
func _enter_next_stage() -> void:
	if enemy_era_index >= GameData.ERAS.size() - 1:
		return
	stage_clear_pending = false
	reward_context = "round"
	_advance_enemy_era()
	_sync_player_era_to_stage()
	_clear_all_battle_units()
	# 保留金币与 run_* / free_* 永久项，只重置当轮修饰
	_reset_round_mods()
	_discard_all_cards()
	buff_timers.clear()
	enemy_buff_timers.clear()
	enemy_freeze_time = 0.0
	ally_freeze_time = 0.0
	enemy_tower_attack_bonus = 1.0
	_update_buff_ui()
	# 己方塔按新关卡满血重建
	ally_tower_max_hp = _ally_tower_target_hp()
	ally_tower_hp = ally_tower_max_hp
	ally_alarm_50_played = false
	ally_alarm_25_played = false
	# 重启本关出兵节奏
	wave_spawning = false
	wave_active_timer = 0.0
	wave_number = 0
	enemy_spawn_index = 0
	enemy_lane_cursor = 0
	ally_lane_cursor = 0
	enemy_coin = 0.0
	enemy_effect_cd = 0.0
	enemy_rally_fired = 0
	prep_pending = false
	auto_prep = false
	stuck_warned = false
	occupied_units = 0
	ai_spawn.reset()
	ai_spawn.on_phase_start()
	wave_min_timer = _diff().first_delay
	_reset_stage_timer()
	# 关卡第 1 轮发牌（_spawn_next_batch 内部会 round_number += 1）
	round_number = 0
	_spawn_next_batch()
	_rescale_towers_for_era()
	_update_tower_ui()
	_update_progress_ui()
	battle_hint.text = "进入%s：敌方防御塔已重建，牌堆按本关时代下限重新发牌" % _stage_name(_stage_number())
	_show_toast("进入%s" % _stage_name(_stage_number()))
	print("进入关卡: %d (%s)" % [_stage_number(), current_era])

## 过关清场：双方单位与投射物全部消失
func _clear_all_battle_units() -> void:
	for unit in battle_units:
		if is_instance_valid(unit):
			walk_dust_cooldowns.erase(unit.get_instance_id())
			unit.queue_free()
	battle_units.clear()
	if world != null:
		for child in world.get_children():
			if child is Projectile:
				child.queue_free()

## 过关丢弃：牌堆 + 合成台当前轮次剩余牌直接作废
func _discard_all_cards() -> void:
	for card in deck_cards:
		if is_instance_valid(card):
			card.queue_free()
	deck_cards.clear()
	tray_cards.clear()
	tray_incoming = 0
	tray_slots = TRAY_SLOTS + round_extra_tray_slots
	_layout_tray_slots()
	_rebuild_tray_visuals()

func _era_fx_color(era: String) -> Color:
	var material: Dictionary = fx_manager.era_material(era) if fx_manager != null else {}
	return material.get("primary", Color("#ffd273"))

## 当前关卡下己方塔的满血值（关卡时代 × 难度倍率 × 永久塔血加成）
func _ally_tower_target_hp() -> float:
	return GameData.ally_tower_hp(current_era) * float(_diff().tower_mult) * run_tower_hp_mult

func _rescale_towers_for_era() -> void:
	var ally_target := _ally_tower_target_hp()
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
		var award := _award_stage_clear_economy()
		_finish_round("%s\n速度评级 %s · 过关 +%d 金币（关卡分 +%d / 速度分 +%d）" % [
			message,
			str(award.get("grade", "A")),
			int(award.get("gold", 0)),
			int(award.get("stage_pts", 0)),
			int(award.get("speed_pts", 0)),
		])
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
	var rank := SaveManager.try_submit_score(kill_score, current_difficulty, _stage_number())
	var best_score := SaveManager.get_best_score()
	if rank > 0:
		status_label.text = "%s\n本局积分 %d（最高 %d）\n新纪录！本机榜第 %d 名" % [message, kill_score, best_score, rank]
	else:
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
	# 进度条反映本波真实进度：出兵中按本波出兵窗口推进，出兵结束后满格进入清场
	var ratio := 0.0
	if wave_spawning:
		ratio = clampf(1.0 - wave_active_timer / WAVE_DURATION, 0.0, 1.0)
	elif wave_number > 0:
		ratio = 1.0
	wave_bar.value = ratio
	wave_bar.add_theme_stylebox_override("fill", _panel_style(Color("#4cbf4c").lerp(Color("#e2452f"), ratio), Color("#2b1409"), 14, 0))
	if not battle_active or battle_ended:
		wave_bar_label.text = "备战中"
		wave_bar.value = 0.0
	elif wave_number <= 0:
		wave_bar_label.text = "敌军将至"
	elif not wave_spawning and not _living_units("enemy").is_empty():
		wave_bar_label.text = "第 %d 波 · 清场中" % wave_number
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
		if paused:
			state = "已暂停"
		elif wave_spawning:
			state = "战斗中"
		elif not _living_units("enemy").is_empty():
			state = "清场中"
		else:
			state = "战斗中"
	# 信息栏空间有限：只放关卡号 + 轮次 + 状态（关卡对应时代在提示/奖励面板里给全名）
	era_label.text = "第 %d 关 · 第 %d 轮 · %s" % [_stage_number(), round_number, state]
	if score_label != null:
		score_label.text = "积分 %d" % kill_score
	if deck_label != null:
		deck_label.text = "剩 %d 张" % deck_cards.size()
	_update_reshuffle_button()

func _update_reshuffle_button() -> void:
	if reshuffle_button == null:
		return
	# 保持可点：不可用时点击弹中文提示，而不是静默 disabled
	reshuffle_button.disabled = false
	_update_clear_tray_button()

func _update_clear_tray_button() -> void:
	if clear_tray_button == null:
		return
	clear_tray_button.text = ""
	var free_clear := free_clear_tokens > 0
	if free_clear:
		clear_tray_button.tooltip_text = "免费清空合成台（剩 %d 次），卡牌补回牌堆底" % free_clear_tokens
	else:
		clear_tray_button.tooltip_text = "清空合成台，卡牌补回牌堆底（-%d 金币）" % CLEAR_TRAY_COST
	if clear_tray_badge != null:
		clear_tray_badge.visible = free_clear
		clear_tray_badge.text = str(free_clear_tokens) if free_clear else ""
	# 战斗未开始/已结束/奖励面板打开时直接置灰；其余不可用原因保持可点以弹中文提示
	clear_tray_button.disabled = not _can_pick_cards()

func _update_tower_ui() -> void:
	if ally_tower_bar == null:
		return
	ally_tower_bar.set_health(ally_tower_hp, ally_tower_max_hp)
	enemy_tower_bar.set_health(enemy_tower_hp, enemy_tower_max_hp)
	enemy_tower_bar.set_phase(
		enemy_era_index,
		GameData.ERAS.size(),
		"第 %d 关" % _stage_number()
	)
	if ally_tower_max_hp > 0.0:
		var health_ratio := ally_tower_hp / ally_tower_max_hp
		if health_ratio <= 0.25 and not ally_alarm_25_played:
			ally_alarm_25_played = true
			AudioManager.play_sfx("tower_alarm", {"priority": 0, "throttle_ms": 0})
		elif health_ratio <= 0.5 and not ally_alarm_50_played:
			ally_alarm_50_played = true
			AudioManager.play_sfx("tower_alarm", {"priority": 0, "throttle_ms": 0})
