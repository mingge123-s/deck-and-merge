class_name GameData
extends RefCounted

const MANIFEST_PATH := "res://data/heroes.json"
const TOWER_BASE_HP := 1800.0
const LEGACY_CARD_TEXTURES := {
	"兽皮": "pelt",
	"木棒": "club",
	"投石": "sling",
}

static var _manifest: Dictionary = {}
static var _initialized := false
static var ERAS: Array[String] = []
static var ERA_NAMES: Dictionary = {}
static var ERA_MULT: Dictionary = {}
static var ERA_UPGRADE_COST: Dictionary = {}
static var ERA_TEMPO: Dictionary = {}
static var ERA_RANGE_MULT: Dictionary = {}
static var ROLES: Array[String] = []
static var ROLE_NAMES: Dictionary = {}
static var ROLE_BASE: Dictionary = {}
static var ROLE_SCALE: Dictionary = {}
static var HEROES: Dictionary = {}
static var HEROES_BY_ERA: Dictionary = {}
static var CARDS: Dictionary = {}

static func initialize() -> void:
	if _initialized:
		return
	_manifest = _load_manifest()
	ERAS = _string_array(_manifest.get("eras", []))
	ERA_NAMES = _manifest.get("era_names", {})
	ERA_MULT = _manifest.get("era_mult", {})
	ERA_UPGRADE_COST = _manifest.get("era_upgrade_cost", {})
	ERA_TEMPO = _manifest.get("era_tempo", {})
	ERA_RANGE_MULT = _manifest.get("era_range_mult", {})
	ROLES = _string_array(_manifest.get("roles", []))
	ROLE_NAMES = _manifest.get("role_names", {})
	ROLE_BASE = _manifest.get("role_base", {})
	ROLE_SCALE = _manifest.get("role_scale", {})
	HEROES = _build_heroes(_manifest.get("heroes", []))
	HEROES_BY_ERA = _build_heroes_by_era(HEROES)
	CARDS = _build_cards(HEROES)
	_initialized = true

static func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("找不到英雄 manifest: %s" % MANIFEST_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		return parsed
	push_error("英雄 manifest 不是有效 JSON")
	return {}

static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	for item in value:
		result.append(str(item))
	return result

static func _build_heroes(raw_heroes: Variant) -> Dictionary:
	var result: Dictionary = {}
	for raw in raw_heroes:
		if not raw is Dictionary:
			continue
		var role := str(raw.get("role", "warrior"))
		var era := str(raw.get("era", "stone"))
		var base: Dictionary = ROLE_BASE.get(role, {})
		var mult := float(ERA_MULT.get(era, 1.0))
		var hero: Dictionary = raw.duplicate(true)
		hero["role"] = role
		hero["era"] = era
		hero["color_value"] = Color(str(raw.get("color", "#888888")))
		hero["scale"] = float(raw.get("scale", ROLE_SCALE.get(role, 1.0)))
		hero["hp"] = float(base.get("hp", 100.0)) * mult
		hero["attack"] = float(base.get("attack", 10.0)) * mult * float(raw.get("attack_mult", 1.0))
		var tempo := float(ERA_TEMPO.get(era, 1.0))
		var range_mult := float(ERA_RANGE_MULT.get(era, 1.0))
		hero["range"] = float(raw.get("range", base.get("range", 46.0))) * range_mult
		hero["move_speed"] = float(base.get("move_speed", 40.0)) * tempo
		hero["cooldown"] = float(base.get("cooldown", 1.0)) * float(raw.get("cooldown_mult", 1.0)) / maxf(0.1, tempo)
		hero["attack_speed"] = 1.0 / maxf(0.1, hero["cooldown"])
		hero["kill_score"] = int(base.get("kill_score", 10))
		hero["deck_count"] = int(base.get("deck_count", 9))
		hero["role_name"] = str(ROLE_NAMES.get(role, role))
		hero["era_name"] = str(ERA_NAMES.get(era, era))
		result[str(raw.get("id", ""))] = hero
	return result

static func _build_heroes_by_era(heroes: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for era in ERAS:
		result[era] = []
	for hero_id in heroes:
		var hero: Dictionary = heroes[hero_id]
		var era := str(hero.get("era", "stone"))
		if not result.has(era):
			result[era] = []
		result[era].append(hero_id)
	return result

static func _build_cards(heroes: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for hero_id in heroes:
		var hero: Dictionary = heroes[hero_id]
		var card_id := str(hero.get("card", hero_id))
		result[card_id] = {
			"name": card_id,
			"hero": hero_id,
			"unit": hero_id,
			"era": hero.get("era", "stone"),
			"color": hero.get("color_value", Color("#888888")),
		}
	return result

static func heroes_for_era(era: String) -> Array[String]:
	var result: Array[String] = []
	for hero_id in HEROES_BY_ERA.get(era, []):
		result.append(str(hero_id))
	return result

static func cards_for_era(era: String) -> Array[String]:
	var result: Array[String] = []
	for hero_id in heroes_for_era(era):
		result.append(str(HEROES[hero_id].get("card", hero_id)))
	return result

static func deck_counts_for_era(era: String) -> Dictionary:
	var result: Dictionary = {}
	for hero_id in heroes_for_era(era):
		var hero: Dictionary = HEROES[hero_id]
		result[str(hero.get("card", hero_id))] = int(hero.get("deck_count", 9))
	return result

static func deck_total_for_era(era: String) -> int:
	var total := 0
	for count in deck_counts_for_era(era).values():
		total += int(count)
	return total

static func blended_deck_counts(era_index: int) -> Dictionary:
	var result: Dictionary = {}
	if era_index < 0:
		return result
	for i in range(era_index + 1):
		var era := ERAS[i]
		var behind := era_index - i
		for hero_id in heroes_for_era(era):
			var hero: Dictionary = HEROES[hero_id]
			var card_id := str(hero.get("card", hero_id))
			var base := int(hero.get("deck_count", 9))
			var count := base if behind == 0 else maxi(1, int(round(float(base) * pow(0.4, float(behind)))))
			result[card_id] = int(result.get(card_id, 0)) + count
	return result

static func blended_deck_total(era_index: int) -> int:
	var total := 0
	for count in blended_deck_counts(era_index).values():
		total += int(count)
	return total

static func hero_for_card(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	return HEROES.get(card.get("hero", ""), {})

static func card_texture_path(card_id: String) -> String:
	var hero: Dictionary = hero_for_card(card_id)
	var hero_id := str(hero.get("id", ""))
	if hero_id != "":
		var card_path := "res://assets/cards/%s.png" % hero_id
		if ResourceLoader.exists(card_path):
			return card_path
	var legacy_id: String = LEGACY_CARD_TEXTURES.get(card_id, "")
	if legacy_id != "":
		var legacy_path := "res://assets/cards/%s.png" % legacy_id
		if ResourceLoader.exists(legacy_path):
			return legacy_path
	var anim_id := str(hero.get("anim", ""))
	if anim_id != "":
		var idle_path := "res://assets/anim/%s/idle.png" % anim_id
		if ResourceLoader.exists(idle_path):
			return idle_path
	return ""

static func hero_texture_path(hero_id: String) -> String:
	var hero: Dictionary = HEROES.get(hero_id, {})
	var anim_id := str(hero.get("anim", ""))
	var static_path := "res://assets/units/%s.png" % anim_id
	if ResourceLoader.exists(static_path):
		return static_path
	return ""

static func unit_portrait_path(hero_id: String) -> String:
	var hero: Dictionary = HEROES.get(hero_id, {})
	var anim_id := str(hero.get("anim", ""))
	if anim_id != "":
		var idle_path := "res://assets/anim/%s/idle.png" % anim_id
		if ResourceLoader.exists(idle_path):
			return idle_path
	var static_path := hero_texture_path(hero_id)
	if static_path != "":
		return static_path
	var fallback := "res://assets/units/%s.png" % hero_id
	if ResourceLoader.exists(fallback):
		return fallback
	return ""

static func tower_hp(era: String) -> float:
	return TOWER_BASE_HP * float(ERA_MULT.get(era, 1.0))
