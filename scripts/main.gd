extends Node2D

const VIEW_SIZE := Vector2(720, 1280)
const BATTLE_RECT := Rect2(36, 116, 648, 300)
const TRAY_RECT := Rect2(36, 432, 648, 156)
const BOARD_RECT := Rect2(36, 604, 648, 636)
const CARD_SIZE := Vector2(138, 166)
const DECK_LOW := 33
const DECK_REFILL_TO := 45
const TRAY_SLOTS := 7
const DIFFICULTIES := {
	"easy": {"name": "简单", "wave_interval": 12.0, "first_delay": 6.0, "count_base": 1, "count_step": 5, "count_max": 3, "enemy_mult": 0.7},
	"normal": {"name": "普通", "wave_interval": 9.0, "first_delay": 4.0, "count_base": 2, "count_step": 4, "count_max": 5, "enemy_mult": 1.0},
	"hard": {"name": "困难", "wave_interval": 6.0, "first_delay": 3.0, "count_base": 3, "count_step": 3, "count_max": 7, "enemy_mult": 1.3},
}
const BATTLE_GROUND_Y := 222.0
const WORLD_WIDTH := 1680.0
const BATTLE_VIEW_W := 648.0
const ALLY_TOWER_X := 96.0
const ENEMY_TOWER_X := WORLD_WIDTH - 96.0
const TOWER_RANGE := 82.0
const TOWER_HEIGHT := 160.0
const TOWER_GROUND_NUDGE := 3.0
const TOWER_ATTACK_RANGE := 420.0
const TOWER_ATTACK_CD := 1.1
const TANK_AGGRO_RADIUS := 150.0
const VICTORY_REWARD_BASE := 120
const REINFORCEMENT_PRICE_BASE := 200
const REPAIR_PRICE_BASE := 150
const CLEAR_TRAY_PRICE_BASE := 120
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
var minimap: BattleMinimap
var camera_x := 0.0
var dragging := false
var card_layer: Control
var battle_bg: TextureRect
var ally_tower_sprite: Sprite2D
var enemy_tower_sprite: Sprite2D
var ally_tower_shadow: Sprite2D
var enemy_tower_shadow: Sprite2D
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
var status_label: Label
var restart_button: Button
var result_menu_button: Button
var return_button: Button
var shop_button: Button
var pause_button: Button
var main_menu: Control
var settings_panel: Panel
var shop_panel: Panel
var shop_coin_label: Label
var shop_reinforcement_button: Button
var shop_repair_button: Button
var shop_clear_tray_button: Button
var shop_era_button: Button
var era_select_panel: Panel
var era_select_buttons: Array[Button] = []
var pause_overlay: Control
var pause_shop_button: Button
var tutorial_overlay: Control
var result_overlay: Control
var music_slider: HSlider
var sfx_slider: HSlider
var battle_hint: Label
var ally_tower_bar: TowerHealthBar
var enemy_tower_bar: TowerHealthBar
var battle_active := false
var battle_ended := false
var battle_won := false
var paused := false
var wave_timer := 0.0
var wave_number := 0
var ally_tower_cd := 0.0
var enemy_tower_cd := 0.0
var card_z_top := 0
var pending_era_cards: Array[String] = []
var era_card_timer := 0.0
var ally_tower_hp := 1.0
var enemy_tower_hp := 1.0
var era_visual_tween: Tween
var rng := RandomNumberGenerator.new()
var hit_fx_pool: Array[Label] = []
var camera_shake_offset := Vector2.ZERO
var camera_shake_tween: Tween

func _diff() -> Dictionary:
	return DIFFICULTIES[current_difficulty]

func _ready() -> void:
	_apply_default_font()
	GameData.initialize()
	coin_count = SaveManager.get_coins()
	rng.randomize()
	_build_background()
	_build_top_bar()
	_build_board()
	_build_tray()
	_build_battlefield()
	_build_overlay()
	_build_main_menu()

func _on_battlefield_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		camera_x = clampf(camera_x - event.relative.x, 0.0, WORLD_WIDTH - BATTLE_VIEW_W)
		_apply_camera()

func _apply_camera() -> void:
	if world != null:
		world.position = Vector2(7.0 - camera_x, 7.0) + camera_shake_offset

func _reset_camera() -> void:
	camera_x = 0.0
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
	if not pending_era_cards.is_empty():
		era_card_timer -= delta
		if era_card_timer <= 0.0:
			_spawn_card(pending_era_cards.pop_front(), deck_cards.size())
			era_card_timer = 0.32
			_refresh_covered()
	if not battle_active or battle_ended:
		return
	wave_timer -= delta
	if wave_timer <= 0.0:
		_spawn_wave()
		wave_timer = _diff().wave_interval
	_step_battle(delta)
	_update_tower_ui()

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
	shop_button = Button.new()
	shop_button.position = Vector2(594, 12)
	shop_button.size = Vector2(54, 46)
	shop_button.text = "🛒"
	shop_button.tooltip_text = "商店"
	shop_button.add_theme_font_size_override("font_size", 22)
	shop_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 12, 2))
	shop_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 12, 2))
	shop_button.pressed.connect(_show_shop)
	shop_button.pressed.connect(_play_button_sfx)
	bar.add_child(shop_button)
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
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(bg)
	_label(board, "🃏 牌堆", Vector2(20, 14), Vector2(150, 32), 21)
	_label(board, "点击没有被压住的卡牌", Vector2(22, 48), Vector2(230, 23), 12, Color("#6e452f"))
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
	_label(tray, "3 张同名卡 → 1 个时代英雄", Vector2(168, 13), Vector2(300, 22), 12, Color("#765035"))
	for index in range(7):
		var slot := Panel.new()
		slot.position = Vector2(16 + index * 89, 48)
		slot.size = Vector2(80, 88)
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
	ally_tower_shadow = _create_tower_shadow(true)
	enemy_tower_shadow = _create_tower_shadow(false)
	ally_tower_sprite = _create_tower_sprite(true)
	enemy_tower_sprite = _create_tower_sprite(false)
	battle_hint = _label(battlefield, "拖动战场查看双方阵地", Vector2(16, 18), Vector2(300, 22), 12, Color("#f9deb0"))
	minimap = BattleMinimap.new()
	minimap.position = Vector2(462, 8)
	minimap.size = Vector2(176, 46)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.configure(WORLD_WIDTH, BATTLE_VIEW_W)
	battlefield.add_child(minimap)
	_create_tower_ui(true)
	_create_tower_ui(false)
	_apply_camera()

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

func _refresh_era_visuals(animate := false) -> void:
	if era_visual_tween != null:
		era_visual_tween.kill()
	if not animate:
		_apply_era_visuals()
		return
	var visuals: Array[CanvasItem] = [
		battle_bg,
		ally_tower_sprite,
		enemy_tower_sprite,
		ally_tower_shadow,
		enemy_tower_shadow,
	]
	era_visual_tween = create_tween()
	era_visual_tween.set_parallel(true)
	for visual in visuals:
		era_visual_tween.tween_property(visual, "modulate:a", 0.0, 0.3)
	era_visual_tween.chain().tween_callback(func() -> void:
		_apply_era_visuals()
		for visual in visuals:
			visual.modulate.a = 0.0
		era_visual_tween = create_tween()
		era_visual_tween.set_parallel(true)
		for visual in visuals:
			era_visual_tween.tween_property(visual, "modulate:a", 1.0, 0.3)
	)

func _apply_era_visuals() -> void:
	var bg_path := "res://assets/bg_battle_%s.png" % current_era
	if not ResourceLoader.exists(bg_path):
		bg_path = "res://assets/bg_battle_stone.png"
	battle_bg.texture = load(bg_path)
	var tower_path := "res://assets/towers/%s.png" % current_era
	if not ResourceLoader.exists(tower_path):
		tower_path = "res://assets/towers/stone.png"
	var tower_tint: Color = ERA_TOWER_TINTS.get(current_era, ERA_TOWER_TINTS.stone)
	for tower in [ally_tower_sprite, enemy_tower_sprite]:
		tower.texture = load(tower_path)
		var factor := TOWER_HEIGHT / maxf(1.0, float(tower.texture.get_height()))
		tower.scale = Vector2(factor, factor)
		tower.modulate = tower_tint
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
	result_overlay.z_index = 155
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

func _build_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.size = VIEW_SIZE
	pause_overlay.z_index = 150
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	add_child(pause_overlay)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color(0.05, 0.03, 0.02, 0.62)
	pause_overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(130, 410)
	panel.size = Vector2(460, 280)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	pause_overlay.add_child(panel)
	var title := _label(panel, "整备时间", Vector2(0, 30), Vector2(460, 46), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(panel, "战斗、出兵和牌堆均已冻结", Vector2(0, 92), Vector2(460, 28), 16, Color("#ffe3a5")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_shop_button = _menu_button(panel, "打开商店", Vector2(130, 140), Vector2(200, 58), 20)
	pause_shop_button.pressed.connect(_show_shop)
	var continue_button := _menu_button(panel, "确认再战", Vector2(130, 214), Vector2(200, 58), 20)
	continue_button.pressed.connect(_toggle_pause)

func _build_tutorial_overlay() -> void:
	tutorial_overlay = Control.new()
	tutorial_overlay.size = VIEW_SIZE
	tutorial_overlay.z_index = 160
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.visible = false
	add_child(tutorial_overlay)
	var shade := ColorRect.new()
	shade.size = VIEW_SIZE
	shade.color = Color(0.05, 0.03, 0.02, 0.62)
	tutorial_overlay.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(54, 190)
	panel.size = Vector2(612, 900)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	tutorial_overlay.add_child(panel)
	var title := _label(panel, "新手引导", Vector2(0, 34), Vector2(612, 46), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var content := _label(
		panel,
		"① 点击没被压住的卡牌，收进合成台\n\n② 3 张同名卡会自动合成英雄出战\n\n③ 拖动战场查看双方阵地，右上角小地图查看红蓝点\n\n④ 金币可在 🛒 商店召唤援军或修复我方塔\n\n⑤ 攒金币，在商店购买时代进阶",
		Vector2(42, 122),
		Vector2(528, 500),
		18,
		Color("#fff0c7")
	)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var acknowledge_button := _menu_button(panel, "知道了", Vector2(206, 710), Vector2(200, 58), 20)
	acknowledge_button.pressed.connect(_hide_tutorial)

func _toggle_pause() -> void:
	if not battle_active or battle_ended:
		return
	paused = not paused
	if pause_overlay != null:
		pause_overlay.visible = paused

func _show_tutorial() -> void:
	paused = true
	if tutorial_overlay != null:
		tutorial_overlay.visible = true

func _hide_tutorial() -> void:
	if tutorial_overlay != null:
		tutorial_overlay.visible = false
	SaveManager.set_tutorial_seen(true)
	paused = false

func _build_main_menu() -> void:
	main_menu = Control.new()
	main_menu.name = "MainMenu"
	main_menu.size = VIEW_SIZE
	main_menu.z_index = 100
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
	_build_settings_panel(card)
	_build_era_select_panel()
	_build_shop_panel()

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

func _build_shop_panel() -> void:
	shop_panel = Panel.new()
	shop_panel.position = Vector2(100, 280)
	shop_panel.size = Vector2(520, 690)
	shop_panel.z_index = 120
	shop_panel.add_theme_stylebox_override("panel", _panel_style(Color("#c58a53"), Color("#70412c"), 24, 3))
	shop_panel.visible = false
	add_child(shop_panel)
	var title := _label(shop_panel, "战斗商店", Vector2(0, 28), Vector2(520, 42), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_coin_label = _label(shop_panel, "", Vector2(52, 92), Vector2(180, 30), 18, Color("#fff0c7"))
	var reinforcement_label := _label(shop_panel, "召唤援军\n当前时代随机英雄", Vector2(52, 148), Vector2(230, 60), 17, Color("#fff0c7"))
	reinforcement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_reinforcement_button = _menu_button(shop_panel, "", Vector2(296, 148), Vector2(170, 60), 16)
	shop_reinforcement_button.pressed.connect(_buy_reinforcement)
	var repair_label := _label(shop_panel, "修复我方塔\n恢复当前时代满血的 25%", Vector2(52, 248), Vector2(230, 60), 17, Color("#fff0c7"))
	repair_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_repair_button = _menu_button(shop_panel, "", Vector2(296, 248), Vector2(170, 60), 16)
	shop_repair_button.pressed.connect(_buy_repair)
	var clear_label := _label(shop_panel, "清理合成台\n移除 3 张最难凑成三连的牌", Vector2(52, 348), Vector2(230, 60), 17, Color("#fff0c7"))
	clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_clear_tray_button = _menu_button(shop_panel, "", Vector2(296, 348), Vector2(170, 60), 16)
	shop_clear_tray_button.pressed.connect(_buy_clear_tray)
	var era_label := _label(shop_panel, "时代进阶\n花金币解锁下一个时代", Vector2(52, 448), Vector2(230, 60), 17, Color("#fff0c7"))
	era_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_era_button = _menu_button(shop_panel, "", Vector2(296, 448), Vector2(170, 60), 16)
	shop_era_button.pressed.connect(_buy_era_upgrade)
	var close_button := _menu_button(shop_panel, "关闭", Vector2(160, 570), Vector2(200, 56), 18)
	close_button.pressed.connect(_hide_shop)
	_update_shop_ui()

func _show_shop() -> void:
	if shop_panel != null:
		if paused and pause_overlay != null:
			pause_overlay.visible = false
		shop_panel.visible = true
		_update_shop_ui()

func _hide_shop() -> void:
	if shop_panel != null:
		shop_panel.visible = false
		if paused and pause_overlay != null:
			pause_overlay.visible = true

func _update_shop_ui() -> void:
	if shop_reinforcement_button == null:
		return
	var reinforcement_price := _era_amount(REINFORCEMENT_PRICE_BASE)
	var repair_price := _era_amount(REPAIR_PRICE_BASE)
	var clear_tray_price := _era_amount(CLEAR_TRAY_PRICE_BASE)
	shop_coin_label.text = "金币：%d" % coin_count
	shop_reinforcement_button.text = "召唤援军  %d" % reinforcement_price
	shop_repair_button.text = "修复我方塔  %d" % repair_price
	shop_clear_tray_button.text = "清理合成台  %d" % clear_tray_price
	var next_era_index := era_index + 1
	var can_upgrade := next_era_index < GameData.ERAS.size()
	var era_cost := int(GameData.ERA_UPGRADE_COST.get(current_era, 0))
	if can_upgrade:
		var next_era: String = GameData.ERAS[next_era_index]
		shop_era_button.text = "%s  %d" % [GameData.ERA_NAMES.get(next_era, next_era), era_cost]
	else:
		shop_era_button.text = "已是最终时代"
	shop_reinforcement_button.disabled = not battle_active or battle_ended or coin_count < reinforcement_price
	shop_repair_button.disabled = not battle_active or battle_ended or coin_count < repair_price
	shop_clear_tray_button.disabled = (
		not battle_active
		or battle_ended
		or tray_cards.size() < 3
		or coin_count < clear_tray_price
	)
	shop_era_button.disabled = not battle_active or battle_ended or not can_upgrade or coin_count < era_cost

func _era_amount(base_amount: int) -> int:
	return maxi(1, roundi(float(base_amount) * float(GameData.ERA_MULT.get(current_era, 1.0))))

func _buy_reinforcement() -> void:
	var price := _era_amount(REINFORCEMENT_PRICE_BASE)
	if not battle_active or battle_ended or coin_count < price:
		return
	var ids := GameData.heroes_for_era(current_era)
	if ids.is_empty():
		return
	coin_count -= price
	_spawn_ally(ids[rng.randi_range(0, ids.size() - 1)])
	_update_coin_ui()
	SaveManager.set_coins(coin_count)
	_update_shop_ui()

func _buy_repair() -> void:
	var price := _era_amount(REPAIR_PRICE_BASE)
	if not battle_active or battle_ended or coin_count < price:
		return
	coin_count -= price
	ally_tower_hp = minf(
		ally_tower_hp + GameData.tower_hp(current_era) * 0.25,
		GameData.tower_hp(current_era)
	)
	_update_coin_ui()
	_update_tower_ui()
	SaveManager.set_coins(coin_count)
	_update_shop_ui()

func _buy_clear_tray() -> void:
	var price := _era_amount(CLEAR_TRAY_PRICE_BASE)
	if not battle_active or battle_ended or tray_cards.size() < 3 or coin_count < price:
		return
	coin_count -= price
	var removals: Array[String] = tray_cards.duplicate()
	removals.sort_custom(func(a: String, b: String) -> bool:
		var count_a := tray_cards.count(a)
		var count_b := tray_cards.count(b)
		if count_a == count_b:
			return _card_sort_key(a) < _card_sort_key(b)
		return count_a < count_b
	)
	for index in range(mini(3, removals.size())):
		tray_cards.erase(removals[index])
	_rebuild_tray_visuals()
	_update_coin_ui()
	SaveManager.set_coins(coin_count)
	_update_shop_ui()

func _buy_era_upgrade() -> void:
	var next_era_index := era_index + 1
	if not battle_active or battle_ended or next_era_index >= GameData.ERAS.size():
		return
	var cost := int(GameData.ERA_UPGRADE_COST.get(current_era, 0))
	if cost <= 0 or coin_count < cost:
		return
	coin_count -= cost
	_advance_era()
	_update_coin_ui()
	SaveManager.set_coins(coin_count)
	_update_shop_ui()

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
	_hide_settings()
	_hide_era_select()
	_hide_shop()
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
	current_era = GameData.ERAS[era_index]
	kill_score = 0
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
	wave_timer = _diff().first_delay
	wave_number = 0
	ally_tower_cd = 0.0
	enemy_tower_cd = 0.0
	card_z_top = 0
	pending_era_cards.clear()
	era_card_timer = 0.0
	ally_tower_hp = GameData.tower_hp(current_era)
	enemy_tower_hp = GameData.tower_hp(current_era)
	battle_hint.text = "备战 %d 秒，敌方部队即将出击" % int(_diff().first_delay)
	if result_overlay != null:
		result_overlay.visible = false
	_remove_battle_units()
	_update_progress_ui()
	_update_tower_ui()
	var deck: Array[String] = []
	for card_id in GameData.cards_for_era(current_era):
		for _count in range(9):
			deck.append(card_id)
	deck.shuffle()
	for index in range(deck.size()):
		_spawn_card(deck[index], index)
	_refresh_covered()
	_refresh_era_visuals(false)
	_reset_camera()
	if not SaveManager.get_tutorial_seen():
		_show_tutorial()

func _spawn_card(card_id: String, index: int, from_bottom := false) -> void:
	var card := CardView.new()
	var texture: Texture2D
	var path := GameData.card_texture_path(card_id)
	if path != "" and ResourceLoader.exists(path):
		texture = load(path)
	card.setup(card_id, texture, GameData.CARDS[card_id].color)
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

func _on_card_layer_input(event: InputEvent) -> void:
	if paused:
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var canvas_point: Vector2 = card_layer.get_global_transform_with_canvas() * event.position
	var card := _top_card_at(canvas_point)
	if card != null and not card.locked:
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
	if paused or card.locked or card.claimed:
		return
	var target_index := _first_open_slot()
	if target_index < 0:
		battle_hint.text = "合成台已满，先合成三张"
		return
	AudioManager.play_sfx("click")
	card.claimed = true
	tray_incoming += 1
	deck_cards.erase(card)
	_refill_deck_if_low()
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
	)

func _refill_deck_if_low() -> void:
	if deck_cards.size() > DECK_LOW:
		return
	var pool := GameData.cards_for_era(current_era)
	if pool.is_empty():
		return
	while deck_cards.size() + 3 <= DECK_REFILL_TO:
		var card_id := pool[rng.randi() % pool.size()]
		for _copy in range(3):
			_spawn_card(card_id, deck_cards.size(), true)

func _first_open_slot() -> int:
	var used := tray_cards.size() + tray_incoming
	return used if used < TRAY_SLOTS else -1

func _slot_position(index: int) -> Vector2:
	return tray.global_position + Vector2(16 + index * 89 + 40, 48 + 44)

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
	if tray_cards.size() >= TRAY_SLOTS and not _has_triple():
		_finish_battle(false, "失败！合成台已满且无法继续合成")

func _card_sort_key(card_id: String) -> int:
	return GameData.cards_for_era(current_era).find(card_id)

func _rebuild_tray_visuals() -> void:
	for view in tray_views:
		if is_instance_valid(view):
			view.queue_free()
	tray_views.clear()
	for index in range(tray_cards.size()):
		var icon := TextureRect.new()
		icon.position = Vector2(20 + index * 89, 52)
		icon.size = Vector2(72, 64)
		var path := GameData.card_texture_path(tray_cards[index])
		if path != "" and ResourceLoader.exists(path):
			icon.texture = load(path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tray.add_child(icon)
		tray_views.append(icon)

func _check_merges() -> void:
	for card_id in GameData.CARDS:
		if tray_cards.count(card_id) >= 3:
			for _count in range(3):
				tray_cards.erase(card_id)
			var hero_id: String = GameData.CARDS[card_id].hero
			print("合成成功: 3 x %s -> %s" % [card_id, hero_id])
			AudioManager.play_sfx("merge")
			_rebuild_tray_visuals()
			_spawn_ally(hero_id)
			_check_merges()
			return

func _has_triple() -> bool:
	for card_id in GameData.CARDS:
		if tray_cards.count(card_id) >= 3:
			return true
	return false

func _spawn_ally(hero_id: String) -> void:
	var data: Dictionary = GameData.HEROES.get(hero_id, {})
	if data.is_empty():
		return
	var texture: Texture2D
	var path := GameData.hero_texture_path(hero_id)
	if path != "":
		texture = load(path)
	var unit := BattleUnit.new()
	unit.setup(hero_id, "ally", data, texture)
	unit.position = Vector2(ALLY_TOWER_X + 96 + (occupied_units % 3) * 60, BATTLE_GROUND_Y - (occupied_units % 3) * 6)
	unit.z_index = 4
	unit.expired.connect(_on_unit_expired)
	world.add_child(unit)
	battle_units.append(unit)
	occupied_units += 1

func _spawn_wave() -> void:
	var ids := GameData.heroes_for_era(current_era)
	if ids.is_empty():
		return
	wave_number += 1
	var d := _diff()
	var count := clampi(int(d.count_base) + wave_number / int(d.count_step), int(d.count_base), int(d.count_max))
	var spawn_index := 0
	var boss_ids: Array[String] = []
	if wave_number % 5 == 0:
		for hero_id in ids:
			if str(GameData.HEROES[hero_id].get("role", "")) == "boss":
				boss_ids.append(hero_id)
		if not boss_ids.is_empty():
			spawn_index += 1
	var spawn_ids: Array[String] = []
	if spawn_index > 0:
		spawn_ids.append(boss_ids[rng.randi_range(0, boss_ids.size() - 1)])
	for _index in range(count - spawn_index):
		spawn_ids.append(ids[rng.randi_range(0, ids.size() - 1)])
	for index in range(spawn_ids.size()):
		_spawn_enemy(spawn_ids[index], index, spawn_ids.size())

func _spawn_enemy(hero_id: String, index: int, total_count: int) -> void:
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
	world.add_child(unit)
	battle_units.append(unit)

func _step_battle(delta: float) -> void:
	var ally_units := _living_units("ally")
	var enemy_units := _living_units("enemy")
	for unit in battle_units:
		if not is_instance_valid(unit) or not unit.alive:
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
		_finish_battle(true, "胜利！敌方防御塔已摧毁")
	elif ally_tower_hp <= 0.0:
		_finish_battle(false, "失败！己方防御塔被摧毁")

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
	var damage := 30.0 * float(GameData.ERA_MULT.get(current_era, 1.0))
	var on_hit := func() -> void:
		if not is_instance_valid(target) or not target.alive:
			return
		target.receive_damage(damage, "tower")
		_spawn_hit_fx(target.position, Color("#ffd273"), "✦")
		AudioManager.play_sfx("hit")
	var projectile := Projectile.new()
	projectile.setup(start_pos, target_pos, 300.0, current_era, Color("#ffd273"), on_hit)
	world.add_child(projectile)
	if ally:
		ally_tower_cd = TOWER_ATTACK_CD
	else:
		enemy_tower_cd = TOWER_ATTACK_CD

func _move_unit(unit: BattleUnit, target_x: float, delta: float) -> void:
	var direction := signf(target_x - unit.position.x)
	unit.position.x += direction * float(unit.stats.move_speed) * delta
	unit.set_moving(true)

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
	attacker.play_attack()
	if attacker.stats.role == "ranged":
		var facing := 1.0 if attacker.faction == "ally" else -1.0
		var start_pos := attacker.position + Vector2(facing * 30.0, -56.0)
		var target_pos := func() -> Variant:
			if is_instance_valid(target) and target.alive:
				return target.position + Vector2(0, -56.0)
			return null
		var on_hit := func() -> void:
			if is_instance_valid(target) and target.alive:
				target.receive_damage(float(attacker.stats.attack), "hero")
				_spawn_hit_fx(target.position, Color("#ffd273"), "✦")
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
	target.receive_damage(float(attacker.stats.attack), "hero")
	_spawn_hit_fx(target.position, Color("#ffd273"), "✦")
	AudioManager.play_sfx("hit")

func _attack_tower(attacker: BattleUnit) -> void:
	attacker.spend_attack_time()
	attacker.play_attack()
	var damage := float(attacker.stats.attack)
	var tower_x := ENEMY_TOWER_X if attacker.faction == "ally" else ALLY_TOWER_X
	if attacker.stats.role == "ranged":
		var facing := 1.0 if attacker.faction == "ally" else -1.0
		var start_pos := attacker.position + Vector2(facing * 30.0, -56.0)
		var tower_point := Vector2(tower_x, BATTLE_GROUND_Y - 56.0)
		var target_pos := func() -> Variant:
			return tower_point
		var on_hit := func() -> void:
			if attacker.faction == "ally":
				enemy_tower_hp = maxf(0.0, enemy_tower_hp - damage)
				_spawn_hit_fx(tower_point, Color("#ffd273"), "✦")
				AudioManager.play_sfx("tower")
				_shake_battlefield()
			else:
				ally_tower_hp = maxf(0.0, ally_tower_hp - damage)
				_spawn_hit_fx(tower_point, Color("#ff8e70"), "✦")
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
		AudioManager.play_sfx("tower")
		_shake_battlefield()
	else:
		ally_tower_hp = maxf(0.0, ally_tower_hp - damage)
		_spawn_hit_fx(Vector2(ALLY_TOWER_X, BATTLE_GROUND_Y - 40.0), Color("#ff8e70"), "✦")
		AudioManager.play_sfx("tower")
		_shake_battlefield()

func _on_unit_expired(unit: BattleUnit) -> void:
	if unit.faction == "enemy" and not unit.score_awarded:
		unit.score_awarded = true
		var kill_score_value := int(unit.stats.get("kill_score", 0))
		_change_coins(_era_amount(kill_score_value))
		if unit.last_damage_source != "tower":
			kill_score += kill_score_value
		_update_progress_ui()

func _advance_era() -> void:
	if era_index >= GameData.ERAS.size() - 1:
		return
	era_index += 1
	current_era = GameData.ERAS[era_index]
	SaveManager.unlock_era(era_index)
	AudioManager.play_sfx("era")
	ally_tower_hp = minf(ally_tower_hp + GameData.tower_hp(current_era) * 0.25, GameData.tower_hp(current_era))
	enemy_tower_hp = minf(enemy_tower_hp + GameData.tower_hp(current_era) * 0.25, GameData.tower_hp(current_era))
	_add_new_era_cards()
	_update_progress_ui()
	battle_hint.text = "文明进阶：%s！新时代卡牌已从牌堆底部加入" % GameData.ERA_NAMES[current_era]
	_refresh_era_visuals(true)
	print("时代进阶: %s" % current_era)

func _add_new_era_cards() -> void:
	pending_era_cards.clear()
	for card_id in GameData.cards_for_era(current_era):
		for _count in range(3):
			pending_era_cards.append(card_id)
	era_card_timer = 0.0

func _spawn_hit_fx(local_position: Vector2, color: Color, text: String) -> void:
	var fx: Label
	if hit_fx_pool.is_empty():
		fx = Label.new()
		fx.z_index = 6
		fx.add_theme_font_size_override("font_size", 24)
	else:
		fx = hit_fx_pool.pop_back()
	fx.position = local_position + Vector2(-14, -130)
	fx.text = text
	fx.add_theme_color_override("font_color", color)
	fx.modulate = Color.WHITE
	fx.visible = true
	if fx.get_parent() == null:
		world.add_child(fx)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "position:y", fx.position.y - 18, 0.3)
	tween.tween_property(fx, "modulate", Color(1, 1, 1, 0), 0.3)
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
	_update_shop_ui()

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
	SaveManager.set_coins(coin_count)
	status_label.text = "%s\n本局积分 %d（最高 %d）" % [message, kill_score, best_score]
	if result_overlay != null:
		result_overlay.visible = true

func _update_progress_ui() -> void:
	if era_label == null:
		return
	var state := "备战"
	if battle_ended:
		state = "已通关" if battle_won else "已失守"
	elif battle_active:
		state = "战斗中"
	era_label.text = "%s · %s" % [GameData.ERA_NAMES.get(current_era, current_era), state]
	score_label.text = "击杀积分 %d" % kill_score

func _update_tower_ui() -> void:
	if ally_tower_bar == null:
		return
	var ally_max := GameData.tower_hp(current_era)
	var enemy_max := GameData.tower_hp(current_era)
	ally_tower_bar.set_health(ally_tower_hp, ally_max)
	enemy_tower_bar.set_health(enemy_tower_hp, enemy_max)
