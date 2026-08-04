class_name AiSpawnConfig
extends RefCounted

## AI 常规出兵的全部可调参数集中在这里。
## 数值调参请只改本文件的 PROFILES / 常量，函数签名保持稳定（另有 Devin 专精调参）。
##
## 常规出兵模型：每 tick_interval 秒一次 tick，成功率 spawn_chance 出 1 个普通兵；
## 场上敌人数达到 field_soft_cap（或硬顶 ENEMY_UNIT_CAP）时不再掷骰。
## Boss 不再由「维持人数」带出，只走 boss_pending + boss_tick_chance 的稀疏规则。

const DEFAULT_DIFFICULTY := "normal"

## 每个难度一套参数：
## - tick_interval: 掷骰间隔（秒）
## - spawn_chance: 基础出兵概率（每 tick）
## - chance_per_wave: 每过一波额外增加的概率
## - chance_max: 概率上限
## - soft_cap_base / soft_cap_step / soft_cap_max: 软顶 = clamp(base + wave/step, base, max)
## - boss_tick_chance: boss 待出场时，每 tick 出 boss 的概率（稀疏出场）
## - phase_boss_chance: 敌方进入新时代阶段后，该阶段首波挂上 boss 待出场的概率
const PROFILES := {
	"easy": {
		"tick_interval": 1.2,
		"spawn_chance": 0.42,
		"chance_per_wave": 0.008,
		"chance_max": 0.70,
		"soft_cap_base": 6,
		"soft_cap_step": 6,
		"soft_cap_max": 12,
		"boss_tick_chance": 0.22,
		"phase_boss_chance": 0.30,
	},
	"normal": {
		"tick_interval": 1.0,
		"spawn_chance": 0.55,
		"chance_per_wave": 0.010,
		"chance_max": 0.85,
		"soft_cap_base": 8,
		"soft_cap_step": 4,
		"soft_cap_max": 16,
		"boss_tick_chance": 0.25,
		"phase_boss_chance": 0.40,
	},
	"hard": {
		"tick_interval": 0.8,
		"spawn_chance": 0.72,
		"chance_per_wave": 0.012,
		"chance_max": 0.95,
		"soft_cap_base": 10,
		"soft_cap_step": 3,
		"soft_cap_max": 22,
		"boss_tick_chance": 0.30,
		"phase_boss_chance": 0.50,
	},
}

static func profile(difficulty_key: String) -> Dictionary:
	if PROFILES.has(difficulty_key):
		return PROFILES[difficulty_key]
	return PROFILES[DEFAULT_DIFFICULTY]

## 掷骰间隔（秒）
static func tick_interval(difficulty_key: String) -> float:
	return maxf(0.05, float(profile(difficulty_key).get("tick_interval", 1.0)))

## 单次 tick 的出兵概率（随波次缓慢增长，受 chance_max 限制）
static func spawn_chance(difficulty_key: String, wave_number: int) -> float:
	var p: Dictionary = profile(difficulty_key)
	var base := float(p.get("spawn_chance", 0.55))
	var growth := float(p.get("chance_per_wave", 0.0)) * float(maxi(0, wave_number - 1))
	return clampf(base + growth, 0.0, float(p.get("chance_max", 1.0)))

## 场上敌人软顶（硬顶仍由 main.gd 的 ENEMY_UNIT_CAP 保证）
static func field_soft_cap(difficulty_key: String, wave_number: int) -> int:
	var p: Dictionary = profile(difficulty_key)
	var base := int(p.get("soft_cap_base", 8))
	var step := maxi(1, int(p.get("soft_cap_step", 4)))
	var cap_max := int(p.get("soft_cap_max", 16))
	return clampi(base + maxi(0, wave_number) / step, base, cap_max)

## boss 待出场时每 tick 的出场概率
static func boss_tick_chance(difficulty_key: String) -> float:
	return clampf(float(profile(difficulty_key).get("boss_tick_chance", 0.25)), 0.0, 1.0)

## 新阶段（敌塔被打爆、敌方升时代）后首波挂上 boss 待出场的概率
static func phase_boss_chance(difficulty_key: String) -> float:
	return clampf(float(profile(difficulty_key).get("phase_boss_chance", 0.4)), 0.0, 1.0)
