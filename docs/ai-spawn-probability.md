# 敌方概率制出兵：参数表与手感曲线

实现：`scripts/ai_spawn_config.gd`（`AiSpawnConfig`，全部数值）+ `scripts/ai_spawn.gd`（`AiSpawn`，tick 引擎）。
本文只描述数值与曲线；引擎行为见 `AiSpawn` 的注释。

## 1. 模型

旧「补位制」：每 `SPAWN_STAGGER=0.6s`，只要 `alive < _wave_field_target()` 就必补 1 个 → 同屏长期贴满，玩家清场没有正反馈。

现在：

```gdscript
# AiSpawn.tick(delta)，每 tick_interval 秒一次
if alive >= field_soft_cap(): return          # 软顶（<= 硬顶 ENEMY_UNIT_CAP）不掷骰
if boss_pending and boss_gap_elapsed and randf() < boss_tick_chance(): spawn_boss(); return
if randf() < spawn_chance(): spawn_one(false) # 失败则本 tick 不出兵
```

其中

```
time_in_era_norm = clamp(era_elapsed / ERA_DURATION_SEC[era], 0, 1)
tick_interval  = profile.tick_interval * ERA_TICK_MULT[era]
                 * lerp(TIME_IN_ERA_TICK_START, TIME_IN_ERA_TICK_END, norm)
spawn_chance   = clamp((profile.spawn_chance + chance_per_wave*(wave-1))
                       * ERA_P_MULT[era]
                       * lerp(TIME_IN_ERA_P_START, TIME_IN_ERA_P_END, norm)
                       * pressure_mult, P_MIN, P_MAX)
field_soft_cap = round((soft_cap_base + era * soft_cap_per_era + wave/step)
                       * lerp(TIME_IN_ERA_CAP_START, TIME_IN_ERA_CAP_END, norm))
期望出兵速率   = spawn_chance / tick_interval   （个/秒）
```

`era` 为敌方当前时代在 `GameData.ERAS` 中的下标（`AiSpawn.era_index()`）。**升时代由主流程战斗时间驱动**（`main.gd::_tick_era_timer`），本表只提供时代内少→多曲线；跨时代兵种不在此预生成。单位属性另乘 `1.0 + 0.25*norm`（`AiSpawnConfig.time_stat_mult`）。

## 2. 难度基准（`PROFILES`，石器时代、第 1 波）

| 难度 | tick(秒) | p | p 每波增长 | p 上限 | 期望速率 | 软顶 base→max |
|---|---|---|---|---|---|---|
| 简单 | 1.2 | 0.42 | +0.008 | 0.70 | 0.35/s | 6 → 12 |
| 普通 | 1.0 | 0.55 | +0.010 | 0.85 | 0.55/s | 8 → 16 |
| 困难 | 0.8 | 0.72 | +0.012 | 0.95 | 0.90/s | 10 → 22 |

对照：旧补位制的补位速率约 `1/0.6 = 1.67 个/秒`，困难档也只有它的 54%，简单档约 21% —— 不再「杀一个补一个」。

## 3. 时代曲线（`ERA_P_MULT` / `ERA_TICK_MULT` / `ERA_SOFT_CAP_STEP`）

| 敌方时代 | 石器 | 铁器 | 工业 | 现代 | 未来 |
|---|---|---|---|---|---|
| p 倍率 | 1.70 | 1.20 | 1.10 | 1.15 | 1.20 |
| tick 倍率 | 0.86 | 0.96 | 0.97 | 0.95 | 0.92 |
| 软顶加成 | +0 | +1 | +2 | +3 | +4 |

**石器加压（s11）**：石器（下标 0）从 s5 的 `p×1.20 / tick×0.95`（普通档 0.52 个/秒）再抬到 `p×1.70 / tick×0.86`，普通档石器第 1 波 `p = 0.45*1.70 = 0.765`，`tick = 1.1*0.86 = 0.946s` → `0.81 个/秒`（约 +56%），让开局塔更难被秒推、场上常规兵更多；残血爆兵石器档 10→12。铁器同步略抬（`p×1.20 / tick×0.96` → 0.51 个/秒）衔接石器，避免石器→铁器断层；工业及以后不变。

普通档未来时代第 1 波：`p = 0.55*1.20 = 0.66`，`tick = 1.0*0.92 = 0.92s` → `0.717 个/秒`（约基准的 1.3 倍；简单 0.457、困难 1.174）。
刻意温和：单位强度本身已由 `GameData.ERA_MULT` 承担；时代加压过猛会让后期又回到「永远满屏」。`p` 仍受各档 `chance_max` 夹紧（困难档高时代会撞到 0.95 上限）。

## 4. 手感曲线（稳态同屏人数）

单兵平均存活 `L` 秒时，软顶未触发的稳态同屏 ≈ `期望速率 × L`：

| 难度（石器 / 未来，第 1 波） | L=6s | L=9s |
|---|---|---|
| 简单 0.35 / 0.46 | 2.1 / 2.7 | 3.2 / 4.1 |
| 普通 0.55 / 0.72 | 3.3 / 4.3 | 5.0 / 6.5 |
| 困难 0.90 / 1.17 | 5.4 / 7.0 | 8.1 / 10.6 |

目标手感：普通档多数时间有压力但有空档 —— 泊松式到达会自然造出数秒空窗，玩家借此推进拆塔；简单档空窗更长；困难档压力持续但仍有呼吸点。后期靠 `chance_per_wave` 与软顶上抬缓慢加压，撞到 `chance_max` 后不再变快，避免回到满屏。

## 5. 与反扑 / 拆塔奖励的关系

临时压力窗只乘 `p`、不动 `tick`，便于叠乘与回退（`AiSpawn.apply_pressure_window(mult, duration)`，覆盖式生效）：

| 事件 | 倍率 | 时长 | 入口 |
|---|---|---|---|
| 敌塔残血拼死反扑 | `RALLY_P_MULT=1.8` | 6s | `begin_rally_pressure()`（`main.gd::_enemy_rally_surge`） |
| 玩家打爆敌塔 / 时间进入新时代 | `TOWER_BREAK_P_MULT=0.5` | 4s | `AiSpawn.on_phase_start()`（`main.gd` 毁塔重建或 `_advance_enemy_era_by_time`） |

- 反扑窗内普通档短时加压，作为拆塔前最后一道压力（`RALLY_BURST` 的一次性爆发仍走 `spawn_one()`，不经过概率）。
- 拆塔/换时代喘息窗降低 `p`，给玩家正反馈；与时代内时间曲线叠乘，结果始终被 `P_MIN`/`P_MAX` 夹紧。

## 5.1 时代内时间曲线（少→多）

| norm | 0（时代初） | 1（时代末） |
|---|---|---|
| p 倍率 | `TIME_IN_ERA_P_START=0.35` | `TIME_IN_ERA_P_END=1.15` |
| tick 倍率 | `TIME_IN_ERA_TICK_START=1.25` | `TIME_IN_ERA_TICK_END=0.90` |
| 软顶倍率 | `TIME_IN_ERA_CAP_START=0.55` | `TIME_IN_ERA_CAP_END=1.15` |
| 单位属性 | ×1.0 | ×1.25 |

时代时长：`ERA_DURATION_SEC = [90, 90, 100, 110, 120]`。普通档石器：时代初期望速率约基准的 0.35×，时代末约 1.0×～1.2×（再叠 `ERA_P_MULT`）。

**BOSS 稀疏化**：boss 不由「维持人数」带出。`boss_pending` 由 ① 波号 `% boss_wave == 0`、② 新阶段首波以 `phase_boss_chance` 掷中 两处置位；置位后每 tick 以 `boss_tick_chance` 概率出场，且出场后 `BOSS_MIN_GAP` 秒内不再出 boss：

| 难度 | boss_tick_chance | phase_boss_chance | BOSS_MIN_GAP |
|---|---|---|---|
| 简单 | 0.22 | 0.30 | 75s |
| 普通 | 0.25 | 0.40 | 55s |
| 困难 | 0.30 | 0.50 | 40s |

普通档 pending 后平均约 `1/0.25 = 4` 个 tick（≈4s）内出场，位置随机；最小间隔保证两只 boss 不会挨着刷。

## 5.5 石器时代开局加压（s5）

玩家反馈「石器阶段 AI 太弱」。原则：优先用「阶段内软顶 + 残血爆兵」加压，常规 `p` 只做温和上调，**不**回退到旧补位制，也**不**大幅抬高工业/现代/未来的长期 `p`（后期单位已更强）。

改动都在 `AiSpawnConfig`（+ `main.gd` 一处接线）：

| 项 | 改前 | 改后 |
|---|---|---|
| `ERA_P_MULT[0]`（石器 p 倍率） | 1.00 | **1.20** |
| `ERA_P_MULT[1]`（铁器，避免断层） | 1.05 | **1.08** |
| `ERA_TICK_MULT[0]`（石器 tick 倍率） | 1.00 | **0.95** |
| 普通档 `soft_cap_base` | 12 | **14** |
| 普通档 `soft_cap_max` | 20 | **22** |

普通档、石器、第 1 波的期望速率：

```
改前：p = 0.45 * 1.00 = 0.45，tick = 1.1 * 1.00 = 1.10s → 0.409 个/秒，软顶 12
改后：p = 0.45 * 1.20 = 0.54，tick = 1.1 * 0.95 = 1.045s → 0.517 个/秒，软顶 14
```

即约 `0.41/s → ~0.52/s`，软顶 `12 → 14`。铁器/工业/现代/未来仅铁器随之从 1.05 抬到 1.08，其余长期 `p` 不动。

### 残血爆兵按时代分档（`RALLY_BURST_BY_ERA` / `AiSpawnConfig.rally_burst(era_index)`）

敌塔血量 <10% 触发一次一次性爆兵（`main.gd::_enemy_rally_surge` → `AiSpawn.spawn_one()`，随后仍走 `on_rally()` 的概率窗）。原来全局固定 `RALLY_BURST := 6`，现按敌方当前时代分档：

| 敌方时代 | 石器 | 铁器 | 工业 | 现代 | 未来 |
|---|---|---|---|---|---|
| 一次性爆兵数 | **10** | **8** | **7** | **6** | **6** |

石器开局压力最弱，给最多的爆兵；后期单位已更强，逐级收敛到 6。爆兵仍受 `ENEMY_UNIT_CAP` 剩余空位夹紧。

## 6. 调试 / 沙盒

设 `AiSpawnConfig.debug_spawn_log = true`，`AiSpawn.tick()` 每次掷骰打印：

```
[ai_spawn] diff=normal wave=3 era=2 tick=0.97 p=0.61 roll=hit spawn=yes alive=4/12
```

数值核对：`godot --headless --path . -s tools/ai_spawn_smoke.gd`（10 波 × 30s 模拟 + 满员不出兵断言 + 三难度 × 5 时代的 tick/p/速率/软顶 + 时代内时间曲线 + 反扑与拆塔窗的 p）。  
流程核对：`godot --headless --path . --script tools/time_era_smoke.gd`。
