class_name AiSpawnConfig
extends RefCounted

## AI 常规出兵的全部可调参数集中在这里（纯配置，不含出兵引擎逻辑）。
## 调参请只改本文件的 PROFILES / 常量，静态函数签名保持稳定（引擎侧 scripts/ai_spawn.gd 依赖它们）。
##
## 常规出兵模型：每 tick_interval 秒一次 tick，成功率 spawn_chance 出 1 个普通兵；
## 场上敌人数达到 field_soft_cap（或硬顶 ENEMY_UNIT_CAP）时不再掷骰。
## 期望出兵速率 = spawn_chance / tick_interval（个/秒）。
## Boss 不再由「维持人数」带出，只走 boss_pending（波次/阶段）+ 稀疏骰 + 最小间隔。
##
## 时代内时间曲线：time_in_era_norm = clamp(era_elapsed / ERA_DURATION, 0, 1)，
## 从时代初（少）线性过渡到时代末（多）。跨时代兵种只靠主流程时间推进，不在此表预生成。

const DEFAULT_DIFFICULTY := "normal"

## 每个时代持续时间（秒），与 main.gd::ERA_DURATION_SEC 保持一致。
const ERA_DURATION_SEC := [300.0, 480.0, 900.0, 1200.0, 1800.0]

## 时代内时间曲线：norm=0 → 起始倍率，norm=1 → 时代末倍率。
## p / 软顶从低到高；tick 从疏到密（倍率越小 tick 越短）。
const TIME_IN_ERA_P_START := 0.35
const TIME_IN_ERA_P_END := 1.15
const TIME_IN_ERA_TICK_START := 1.25
const TIME_IN_ERA_TICK_END := 0.90
const TIME_IN_ERA_CAP_START := 0.55
const TIME_IN_ERA_CAP_END := 1.15
## 同时代内单位属性成长（main.gd::_spawn_enemy 使用）：1.0 + STAT_GROWTH * norm
const TIME_IN_ERA_STAT_GROWTH := 0.25

## 每个难度一套参数：
## - tick_interval: 掷骰间隔（秒）
## - spawn_chance: 基础出兵概率（每 tick）
## - chance_per_wave: 每过一波额外增加的概率（默认 0 = 关闭，节奏成长交给时代倍率）
## - soft_cap_base / soft_cap_per_era / soft_cap_wave_step / soft_cap_max:
##   软顶 = clamp(base + era_index * per_era + wave / wave_step, base, max)，wave_step<=0 时不看波号
## - boss_tick_chance: boss 已安排出场（boss_pending）时，每 tick 出 boss 的概率
## - boss_ambient_chance: 未安排 boss 时，每次成功出普通兵后追加一只 boss 的稀疏概率
## - boss_min_gap: 两只 boss 之间的最小间隔（秒），对上面两条都生效
## - phase_boss_chance: 敌方打爆一阶段升时代后，该阶段首波挂上 boss_pending 的概率
const PROFILES := {
	"easy": {
		"tick_interval": 1.6,
		"spawn_chance": 0.30,
		"chance_per_wave": 0.0,
		"soft_cap_base": 8,
		"soft_cap_per_era": 1,
		"soft_cap_wave_step": 0,
		"soft_cap_max": 14,
		"boss_tick_chance": 0.22,
		"boss_ambient_chance": 0.04,
		"boss_min_gap": 75.0,
		"phase_boss_chance": 0.30,
	},
	"normal": {
		"tick_interval": 1.1,
		"spawn_chance": 0.45,
		"chance_per_wave": 0.0,
		"soft_cap_base": 14,
		"soft_cap_per_era": 1,
		"soft_cap_wave_step": 0,
		"soft_cap_max": 22,
		"boss_tick_chance": 0.25,
		"boss_ambient_chance": 0.07,
		"boss_min_gap": 55.0,
		"phase_boss_chance": 0.40,
	},
	"hard": {
		"tick_interval": 0.9,
		"spawn_chance": 0.60,
		"chance_per_wave": 0.0,
		"soft_cap_base": 16,
		"soft_cap_per_era": 1,
		"soft_cap_wave_step": 0,
		"soft_cap_max": 26,
		"boss_tick_chance": 0.30,
		"boss_ambient_chance": 0.10,
		"boss_min_gap": 40.0,
		"phase_boss_chance": 0.50,
	},
}

## 敌方时代对节奏的修正（索引 = GameData.ERAS 下标：0 石器 → 4 未来）。
## 高时代温和加压：p 最多 +20%，tick 最多缩短 8%（单位强度已由难度的 enemy_mult / 时代倍率承担）。
## 石器（下标 0）在 s5 抬到 p×1.20 / tick×0.95 后仍偏弱（玩家「越快推塔越容易输」）；
## s11 再抬一档：p 倍率 1.70、tick 收到 0.86，普通档石器期望速率 0.52→0.81 个/秒（约 +56%），
## 让开局塔更难被秒推、场上常规兵更多。铁器同步略抬（1.08→1.20 / 0.99→0.96，0.45→0.51 个/秒）
## 衔接石器，避免石器→铁器断层；工业及以后保持不变，不把后期抬到离谱。
const ERA_P_MULT := [1.70, 1.20, 1.10, 1.15, 1.20]
const ERA_TICK_MULT := [0.86, 0.96, 0.97, 0.95, 0.92]

## 上下限夹紧，防止倍率叠加出极端值（p=1 等价于旧的必出兵）。
const P_MIN := 0.05
const P_MAX := 0.85
const TICK_MIN := 0.4
const TICK_MAX := 3.0

## 敌方拼死反扑窗口：只乘 p、不动 tick，便于叠乘与回退。
const RALLY_P_MULT := 1.8
const RALLY_DURATION := 6.0
## 残血爆兵一次性数量，按敌方当前时代分档（索引 = GameData.ERAS 下标：0 石器 → 4 未来）。
## 石器开局压力最弱，给最多的爆兵；后期单位已更强，逐级收敛：
## 石器 12 / 铁器 8 / 工业 7 / 现代 6 / 未来 6（s11 石器 10→12 略抬残血爆兵，
## 但石器加压主手段是上面的常规 tick 速率，不是只靠残血爆兵）。
const RALLY_BURST_BY_ERA := [12, 8, 7, 6, 6]
## 玩家刚打爆一座敌塔（阶段击破）后的喘息窗：降低出兵速率作为正反馈奖励。
const TOWER_BREAK_P_MULT := 0.5
const TOWER_BREAK_DURATION := 4.0

## 调试开关：打开后引擎每次掷骰调用 debug_log()
static var debug_spawn_log := false

static func profile(difficulty_key: String) -> Dictionary:
	if PROFILES.has(difficulty_key):
		return PROFILES[difficulty_key]
	return PROFILES[DEFAULT_DIFFICULTY]

static func _era_mult(table: Array, era_index: int) -> float:
	if table.is_empty():
		return 1.0
	return float(table[clampi(era_index, 0, table.size() - 1)])

## 时代时长（秒）；未知 index 回退到 90。
static func era_duration(era_index := 0) -> float:
	if ERA_DURATION_SEC.is_empty():
		return 90.0
	return float(ERA_DURATION_SEC[clampi(era_index, 0, ERA_DURATION_SEC.size() - 1)])

static func time_in_era_norm(era_elapsed: float, era_index := 0) -> float:
	var duration := era_duration(era_index)
	if duration <= 0.0:
		return 1.0
	return clampf(era_elapsed / duration, 0.0, 1.0)

static func _time_curve(start_mult: float, end_mult: float, norm: float) -> float:
	return lerpf(start_mult, end_mult, clampf(norm, 0.0, 1.0))

## 掷骰间隔（秒）
static func tick_interval(difficulty_key: String, era_index := 0, time_norm := 0.0) -> float:
	var base := float(profile(difficulty_key).get("tick_interval", 1.1))
	var era_tick := _era_mult(ERA_TICK_MULT, era_index)
	var time_tick := _time_curve(TIME_IN_ERA_TICK_START, TIME_IN_ERA_TICK_END, time_norm)
	return clampf(base * era_tick * time_tick, TICK_MIN, TICK_MAX)

## 单次 tick 的出兵概率。extra_mult 供反扑 / 拆塔喘息等临时窗口叠乘。
static func spawn_chance(difficulty_key: String, wave_number := 0, era_index := 0, extra_mult := 1.0, time_norm := 0.0) -> float:
	var p: Dictionary = profile(difficulty_key)
	var base := float(p.get("spawn_chance", 0.45))
	var growth := float(p.get("chance_per_wave", 0.0)) * float(maxi(0, wave_number - 1))
	var time_p := _time_curve(TIME_IN_ERA_P_START, TIME_IN_ERA_P_END, time_norm)
	return clampf((base + growth) * _era_mult(ERA_P_MULT, era_index) * time_p * extra_mult, P_MIN, P_MAX)

## 场上敌人软顶（硬顶仍由 main.gd 的 ENEMY_UNIT_CAP 保证）
static func field_soft_cap(difficulty_key: String, wave_number := 0, era_index := 0, time_norm := 0.0) -> int:
	var p: Dictionary = profile(difficulty_key)
	var base := int(p.get("soft_cap_base", 12))
	var cap := float(base + era_index * int(p.get("soft_cap_per_era", 0)))
	var wave_step := int(p.get("soft_cap_wave_step", 0))
	if wave_step > 0:
		cap += float(maxi(0, wave_number) / wave_step)
	cap *= _time_curve(TIME_IN_ERA_CAP_START, TIME_IN_ERA_CAP_END, time_norm)
	return clampi(int(round(cap)), 1, int(p.get("soft_cap_max", 20)))

## 期望出兵速率（个/秒），供调参与文档核对
static func expected_rate(difficulty_key: String, wave_number := 0, era_index := 0, time_norm := 0.0) -> float:
	return spawn_chance(difficulty_key, wave_number, era_index, 1.0, time_norm) / tick_interval(difficulty_key, era_index, time_norm)

## 同时代内单位属性成长倍率
static func time_stat_mult(time_norm := 0.0) -> float:
	return 1.0 + TIME_IN_ERA_STAT_GROWTH * clampf(time_norm, 0.0, 1.0)

## boss 已安排出场时，每 tick 的出场概率
static func boss_tick_chance(difficulty_key: String) -> float:
	return clampf(float(profile(difficulty_key).get("boss_tick_chance", 0.25)), 0.0, 1.0)

## 未安排 boss 时，每次成功出普通兵后追加 boss 的稀疏概率
static func boss_ambient_chance(difficulty_key: String) -> float:
	return clampf(float(profile(difficulty_key).get("boss_ambient_chance", 0.07)), 0.0, 1.0)

## 两只 boss 之间的最小间隔（秒）
static func boss_min_gap(difficulty_key: String) -> float:
	return maxf(0.0, float(profile(difficulty_key).get("boss_min_gap", 55.0)))

## 新阶段（敌塔被打爆、敌方升时代）后首波挂上 boss_pending 的概率
static func phase_boss_chance(difficulty_key: String) -> float:
	return clampf(float(profile(difficulty_key).get("phase_boss_chance", 0.4)), 0.0, 1.0)

## 残血爆兵一次性数量（按敌方当前时代分档），main.gd::_enemy_rally_surge 调用
static func rally_burst(era_index := 0) -> int:
	if RALLY_BURST_BY_ERA.is_empty():
		return 6
	return int(RALLY_BURST_BY_ERA[clampi(era_index, 0, RALLY_BURST_BY_ERA.size() - 1)])

## 统一掷骰入口，便于日志集中
static func roll(rng: RandomNumberGenerator, chance: float) -> bool:
	if rng == null:
		return randf() < chance
	return rng.randf() < chance

static func debug_log(difficulty_key: String, era_index: int, chance: float, hit: bool, living: int, time_norm := 0.0) -> void:
	if not debug_spawn_log:
		return
	print("[ai_spawn] diff=%s era=%d t=%.2f tick=%.2f p=%.2f roll=%s living=%d/%d" % [
		difficulty_key,
		era_index,
		time_norm,
		tick_interval(difficulty_key, era_index, time_norm),
		chance,
		"hit" if hit else "miss",
		living,
		field_soft_cap(difficulty_key, 0, era_index, time_norm),
	])
