extends Node2D

const VIEW_SIZE := Vector2(720, 1280)
const BOARD_RECT := Rect2(36, 116, 648, 628)
const TRAY_RECT := Rect2(36, 766, 648, 156)
const BATTLE_RECT := Rect2(36, 944, 648, 280)
const CARD_SIZE := Vector2(138, 166)
const BATTLE_GROUND_Y := 222.0
const ALLY_TOWER_X := 64.0
const ENEMY_TOWER_X := 610.0
const TOWER_RANGE := 82.0
const TOWER_HEIGHT := 160.0
const TOWER_GROUND_NUDGE := 3.0
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
var card_layer: Control
var battle_bg: TextureRect
var ally_tower_sprite: Sprite2D
var enemy_tower_sprite: Sprite2D
var ally_tower_shadow: Sprite2D
var enemy_tower_shadow: Sprite2D
var tray_cards: Array[String] = []
var tray_views: Array[Control] = []
var deck_cards: Array[CardView] = []
var battle_units: Array[BattleUnit] = []
var occupied_units := 0
var coin_count := 2480
var current_era := "stone"
var era_index := 0
var kill_score := 0
var coin_label: Label
var era_label: Label
var score_label: Label
var status_label: Label
var restart_button: Button
var battle_button: Button
var battle_hint: Label
var ally_tower_bar: ProgressBar
var enemy_tower_bar: ProgressBar
var ally_tower_label: Label
var enemy_tower_label: Label
var battle_active := false
var battle_ended := false
var wave_timer := 0.0
var pending_era_cards: Array[String] = []
var era_card_timer := 0.0
var ally_tower_hp := 1.0
var enemy_tower_hp := 1.0
var era_visual_tween: Tween
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	GameData.initialize()
	rng.randomize()
	_build_background()
	_build_top_bar()
	_build_board()
	_build_tray()
	_build_battlefield()
	_build_overlay()
	_start_round()

func _process(delta: float) -> void:
	if not pending_era_cards.is_empty():
		era_card_timer -= delta
		if era_card_timer <= 0.0:
			_spawn_card(pending_era_cards.pop_front(), deck_cards.size(), true)
			era_card_timer = 0.32
			_refresh_covered()
	if not battle_active or battle_ended:
		return
	wave_timer -= delta
	if wave_timer <= 0.0:
		_spawn_wave()
		wave_timer = 6.0
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
	_label(bar, "🪨 牌桌远征", Vector2(18, 5), Vector2(205, 30), 21)
	era_label = _label(bar, "", Vector2(20, 38), Vector2(220, 20), 12, Color("#f6d69f"))
	coin_label = _label(bar, "💰  2,480", Vector2(350, 8), Vector2(120, 28), 16, Color("#fff0c7"))
	score_label = _label(bar, "", Vector2(350, 37), Vector2(280, 22), 12, Color("#ffe3a5"))
	_update_progress_ui()

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
	add_child(battlefield)
	battle_bg = TextureRect.new()
	battle_bg.position = Vector2(7, 7)
	battle_bg.size = BATTLE_RECT.size - Vector2(14, 14)
	battle_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battle_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	battle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battlefield.add_child(battle_bg)
	ally_tower_shadow = _create_tower_shadow(true)
	enemy_tower_shadow = _create_tower_shadow(false)
	ally_tower_sprite = _create_tower_sprite(true)
	enemy_tower_sprite = _create_tower_sprite(false)
	_label(battlefield, "🛡 防御塔战线", Vector2(18, 10), Vector2(210, 28), 18)
	battle_hint = _label(battlefield, "敌方英雄将从右塔出击", Vector2(250, 14), Vector2(260, 22), 12, Color("#f9deb0"))
	battle_button = Button.new()
	battle_button.position = Vector2(514, 12)
	battle_button.size = Vector2(112, 45)
	battle_button.text = "⚔ 开战"
	battle_button.add_theme_font_size_override("font_size", 17)
	battle_button.add_theme_stylebox_override("normal", _panel_style(Color("#e4863e"), Color("#713722"), 14, 3))
	battle_button.add_theme_stylebox_override("hover", _panel_style(Color("#f2a252"), Color("#713722"), 14, 3))
	battle_button.pressed.connect(_start_battle)
	battlefield.add_child(battle_button)
	_create_tower_ui(true)
	_create_tower_ui(false)
	_label(battlefield, "己方英雄", Vector2(26, 245), Vector2(120, 22), 12, Color("#fff0c7"))
	_label(battlefield, "镜像敌军", Vector2(515, 245), Vector2(110, 22), 12, Color("#ffd5a7"))

func _create_tower_sprite(ally: bool) -> Sprite2D:
	var tower := Sprite2D.new()
	tower.position = Vector2(
		ALLY_TOWER_X if ally else ENEMY_TOWER_X,
		BATTLE_GROUND_Y - TOWER_HEIGHT * 0.5 + TOWER_GROUND_NUDGE
	)
	tower.z_index = 1
	tower.flip_h = not ally
	battlefield.add_child(tower)
	return tower

func _create_tower_shadow(ally: bool) -> Sprite2D:
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/fx/shadow.png")
	shadow.position = Vector2(ALLY_TOWER_X if ally else ENEMY_TOWER_X, BATTLE_GROUND_Y)
	shadow.scale = Vector2(0.45, 0.4)
	shadow.z_index = 0
	battlefield.add_child(shadow)
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
	var x := 18.0 if ally else 524.0
	var title := "己方塔" if ally else "敌方塔"
	var panel := Panel.new()
	panel.position = Vector2(x, 62)
	panel.size = Vector2(100, 70)
	panel.z_index = 2
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#51362d", 0.82), Color("#f3ca74"), 10, 2))
	battlefield.add_child(panel)
	_label(panel, title, Vector2(8, 5), Vector2(84, 20), 13)
	var bar := ProgressBar.new()
	bar.position = Vector2(8, 29)
	bar.size = Vector2(84, 14)
	bar.max_value = 100.0
	bar.show_percentage = false
	panel.add_child(bar)
	var hp_label := _label(panel, "", Vector2(8, 46), Vector2(84, 18), 11, Color("#ffe8b0"))
	if ally:
		ally_tower_bar = bar
		ally_tower_label = hp_label
	else:
		enemy_tower_bar = bar
		enemy_tower_label = hp_label

func _build_overlay() -> void:
	status_label = _label(self, "", Vector2(75, 365), Vector2(570, 64), 22, Color("#fff2c4"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.visible = false
	restart_button = Button.new()
	restart_button.position = Vector2(275, 430)
	restart_button.size = Vector2(170, 52)
	restart_button.text = "重新开始"
	restart_button.add_theme_font_size_override("font_size", 19)
	restart_button.add_theme_stylebox_override("normal", _panel_style(Color("#d77a3d"), Color("#6d3724"), 15, 3))
	restart_button.add_theme_stylebox_override("hover", _panel_style(Color("#ec994d"), Color("#6d3724"), 15, 3))
	restart_button.pressed.connect(_start_round)
	restart_button.visible = false
	add_child(restart_button)

func _start_round() -> void:
	for card in deck_cards:
		if is_instance_valid(card):
			card.queue_free()
	deck_cards.clear()
	for view in tray_views:
		if is_instance_valid(view):
			view.queue_free()
	tray_views.clear()
	tray_cards.clear()
	occupied_units = 0
	current_era = GameData.ERAS[0]
	era_index = 0
	kill_score = 0
	battle_active = false
	battle_ended = false
	wave_timer = 0.0
	pending_era_cards.clear()
	era_card_timer = 0.0
	ally_tower_hp = GameData.tower_hp(current_era)
	enemy_tower_hp = GameData.tower_hp(current_era)
	battle_button.disabled = false
	battle_button.text = "⚔ 开战"
	battle_hint.text = "敌方英雄将从右塔出击"
	status_label.visible = false
	restart_button.visible = false
	_remove_battle_units()
	_update_progress_ui()
	_update_tower_ui()
	var deck: Array[String] = []
	for card_id in GameData.cards_for_era(current_era):
		for _count in range(3):
			deck.append(card_id)
	deck.shuffle()
	for index in range(deck.size()):
		_spawn_card(deck[index], index)
	_refresh_covered()
	_refresh_era_visuals(false)

func _spawn_card(card_id: String, index: int, bottom := false) -> void:
	var card := CardView.new()
	var texture: Texture2D
	var path := GameData.card_texture_path(card_id)
	if path != "" and ResourceLoader.exists(path):
		texture = load(path)
	card.setup(card_id, texture, GameData.CARDS[card_id].color)
	card.position = _pile_position(index)
	card.rotation = rng.randf_range(-0.30, 0.30)
	card.z_index = -index if bottom else index
	card_layer.add_child(card)
	deck_cards.append(card)

func _pile_position(index: int) -> Vector2:
	var columns := 5
	var column := index % columns
	var row := index / columns
	return Vector2(8.0 + column * 92.0 + rng.randf_range(-28.0, 28.0), 3.0 + row * 86.0 + rng.randf_range(-28.0, 28.0))

func _refresh_covered() -> void:
	for card in deck_cards:
		if is_instance_valid(card):
			card.set_locked(not _card_has_exposed_area(card))

func _on_card_layer_input(event: InputEvent) -> void:
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

func _card_has_exposed_area(card: CardView) -> bool:
	for y in range(1, int(CARD_SIZE.y), 3):
		for x in range(1, int(CARD_SIZE.x), 3):
			if _top_card_at(card.get_global_transform_with_canvas() * Vector2(x, y)) == card:
				return true
	return false

func _on_card_clicked(card: CardView) -> void:
	if card.locked or card.claimed:
		return
	card.claimed = true
	deck_cards.erase(card)
	_refresh_covered()
	var target_index := _first_open_slot()
	if target_index < 0:
		return
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
	)

func _first_open_slot() -> int:
	return tray_cards.size() if tray_cards.size() < 7 else -1

func _slot_position(index: int) -> Vector2:
	return tray.global_position + Vector2(16 + index * 89 + 40, 48 + 44)

func _add_to_tray(card_id: String) -> void:
	tray_cards.append(card_id)
	tray_cards.sort_custom(func(a: String, b: String) -> bool:
		return _card_sort_key(a) < _card_sort_key(b)
	)
	_rebuild_tray_visuals()
	_check_merges()
	if deck_cards.is_empty() and tray_cards.is_empty() and not battle_active:
		battle_hint.text = "牌堆清空！点击开战迎击镜像敌军"
	elif tray_cards.size() == 7 and not _has_triple():
		_finish_round("卡住了！合成台已满")

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
	unit.position = Vector2(126 + (occupied_units % 3) * 68, BATTLE_GROUND_Y - (occupied_units / 3) * 32)
	unit.z_index = 4
	unit.expired.connect(_on_unit_expired)
	battlefield.add_child(unit)
	battle_units.append(unit)
	occupied_units += 1

func _start_battle() -> void:
	if battle_active or battle_ended:
		return
	if _living_units("ally").is_empty():
		_finish_round("先合成至少一个时代英雄")
		return
	battle_active = true
	battle_ended = false
	wave_timer = 0.0
	battle_button.disabled = true
	battle_button.text = "战斗中"
	battle_hint.text = "镜像敌军持续从右塔出击"
	print("战斗开始: 时代=%s, 己方=%d" % [current_era, _living_units("ally").size()])

func _spawn_wave() -> void:
	var ids := GameData.heroes_for_era(current_era)
	if ids.is_empty():
		return
	var count := rng.randi_range(3, 5)
	for index in range(count):
		_spawn_enemy(ids[rng.randi_range(0, ids.size() - 1)], index)

func _spawn_enemy(hero_id: String, index: int) -> void:
	var data: Dictionary = GameData.HEROES[hero_id]
	var texture: Texture2D
	var path := GameData.hero_texture_path(hero_id)
	if path != "":
		texture = load(path)
	var unit := BattleUnit.new()
	unit.setup(hero_id, "enemy", data, texture)
	unit.position = Vector2(ENEMY_TOWER_X - (index % 2) * 26, BATTLE_GROUND_Y - (index / 2) * 34)
	unit.z_index = 4
	unit.expired.connect(_on_unit_expired)
	battlefield.add_child(unit)
	battle_units.append(unit)

func _step_battle(delta: float) -> void:
	for unit in battle_units:
		if not is_instance_valid(unit) or not unit.alive:
			continue
		unit.attack_cooldown = maxf(0.0, unit.attack_cooldown - delta)
		var target := _find_target(unit)
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
	if enemy_tower_hp <= 0.0:
		_finish_battle(true, "胜利！敌方防御塔已摧毁")
	elif ally_tower_hp <= 0.0:
		_finish_battle(false, "失败！己方防御塔被摧毁")
	elif _living_units("ally").is_empty() and _living_units("enemy").size() > 0:
		_finish_battle(false, "失败！部落英雄全部倒下")

func _move_unit(unit: BattleUnit, target_x: float, delta: float) -> void:
	var direction := signf(target_x - unit.position.x)
	unit.position.x += direction * float(unit.stats.move_speed) * delta
	unit.set_moving(true)

func _find_target(unit: BattleUnit) -> BattleUnit:
	var candidates: Array[BattleUnit] = []
	var enemy_faction := "enemy" if unit.faction == "ally" else "ally"
	for candidate in _living_units(enemy_faction):
		candidates.append(candidate)
	if candidates.is_empty():
		return null
	var nearest: BattleUnit = candidates[0]
	var nearest_distance := absf(nearest.position.x - unit.position.x)
	for candidate in candidates:
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
				target.receive_damage(float(attacker.stats.attack))
				_spawn_hit_fx(target.position, Color("#ffd273"), "✦")
		var projectile := Projectile.new()
		projectile.setup(
			start_pos,
			target_pos,
			300.0,
			str(attacker.stats.era),
			attacker.stats.color_value,
			on_hit
		)
		battlefield.add_child(projectile)
		return
	target.receive_damage(float(attacker.stats.attack))
	_spawn_hit_fx(target.position, Color("#ffd273"), "✦")

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
			else:
				ally_tower_hp = maxf(0.0, ally_tower_hp - damage)
				_spawn_hit_fx(tower_point, Color("#ff8e70"), "✦")
		var projectile := Projectile.new()
		projectile.setup(
			start_pos,
			target_pos,
			300.0,
			str(attacker.stats.era),
			attacker.stats.color_value,
			on_hit
		)
		battlefield.add_child(projectile)
		return
	if attacker.faction == "ally":
		enemy_tower_hp = maxf(0.0, enemy_tower_hp - damage)
		_spawn_hit_fx(Vector2(ENEMY_TOWER_X, 80), Color("#ffd273"), "✦")
	else:
		ally_tower_hp = maxf(0.0, ally_tower_hp - damage)
		_spawn_hit_fx(Vector2(ALLY_TOWER_X, 80), Color("#ff8e70"), "✦")

func _on_unit_expired(unit: BattleUnit) -> void:
	if unit.faction == "enemy" and not unit.score_awarded:
		unit.score_awarded = true
		kill_score += int(unit.stats.get("kill_score", 0))
		_check_era_upgrade()
		_update_progress_ui()

func _check_era_upgrade() -> void:
	if era_index >= GameData.ERAS.size() - 1:
		return
	var threshold := int(GameData.ERA_UPGRADE_SCORE.get(current_era, 999999))
	if kill_score < threshold:
		return
	era_index += 1
	current_era = GameData.ERAS[era_index]
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
	var fx := Label.new()
	fx.position = BATTLE_RECT.position + local_position + Vector2(-14, -130)
	fx.text = text
	fx.add_theme_font_size_override("font_size", 24)
	fx.add_theme_color_override("font_color", color)
	add_child(fx)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "position:y", fx.position.y - 18, 0.3)
	tween.tween_property(fx, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.chain().tween_callback(fx.queue_free)

func _finish_battle(won: bool, message: String) -> void:
	if battle_ended:
		return
	battle_ended = true
	battle_active = false
	print("战斗结束: %s" % message)
	if won:
		coin_count += 120
		coin_label.text = "💰  %d" % coin_count
		_finish_round("%s\n获得 +120 金币" % message)
	else:
		_finish_round(message)

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

func _finish_round(message: String) -> void:
	status_label.text = message
	status_label.visible = true
	restart_button.visible = true

func _update_progress_ui() -> void:
	if era_label == null:
		return
	era_label.text = "%s · %s" % [GameData.ERA_NAMES.get(current_era, current_era), "备战"]
	var threshold := int(GameData.ERA_UPGRADE_SCORE.get(current_era, 999999))
	score_label.text = "击杀积分 %d / %d" % [kill_score, threshold]

func _update_tower_ui() -> void:
	if ally_tower_bar == null:
		return
	var ally_max := GameData.tower_hp(current_era)
	var enemy_max := GameData.tower_hp(current_era)
	ally_tower_bar.value = ally_tower_hp / ally_max * 100.0
	enemy_tower_bar.value = enemy_tower_hp / enemy_max * 100.0
	ally_tower_label.text = "%d / %d" % [int(ally_tower_hp), int(ally_max)]
	enemy_tower_label.text = "%d / %d" % [int(enemy_tower_hp), int(enemy_max)]
