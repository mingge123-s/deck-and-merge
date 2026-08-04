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
tick_interval  = profile.tick_interval * ERA_TICK_MULT[era]
spawn_chance   = clamp((profile.spawn_chance + chance_per_wave*(wave-1))
                       * ERA_P_MULT[era] * pressure_mult, 0, chance_max)
field_soft_cap = clamp(soft_cap_base + wave/soft_cap_step, base, soft_cap_max)
                 + era * ERA_SOFT_CAP_STEP
期望出兵速率   = spawn_chance / tick_interval   （个/秒）
```

`era` 为敌方当前时代在 `GameData.ERAS` 中的下标（`AiSpawn.era_index()` 提供，未知时传 -1 表示不套用时代修正）。**升时代只由拆塔驱动**，本表不参与时代推进。

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
| p 倍率 | 1.00 | 1.05 | 1.10 | 1.15 | 1.20 |
| tick 倍率 | 1.00 | 0.99 | 0.97 | 0.95 | 0.92 |
| 软顶加成 | +0 | +1 | +2 | +3 | +4 |

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
| 玩家打爆一座塔 | `TOWER_BREAK_P_MULT=0.5` | 4s | `begin_tower_break_relief()`（`main.gd::_ascend_enemy_era_phase`） |

- 反扑窗内普通档 `p = min(0.55*1.8, 0.85) = 0.85` → 0.85/s，短时接近旧补位强度，作为拆塔前最后一道压力（`RALLY_BURST` 的一次性爆发仍走 `spawn_one()`，不经过概率）。
- 拆塔奖励窗内普通档 `p = 0.275` → 0.275/s，给玩家一个喘息窗，让「拆塔 → 升时代」有正反馈。
- 两者先后触发时后者覆盖前者；结果始终被 `chance_max` 夹紧。

**BOSS 稀疏化**：boss 不由「维持人数」带出。`boss_pending` 由 ① 波号 `% boss_wave == 0`、② 新阶段首波以 `phase_boss_chance` 掷中 两处置位；置位后每 tick 以 `boss_tick_chance` 概率出场，且出场后 `BOSS_MIN_GAP` 秒内不再出 boss：

| 难度 | boss_tick_chance | phase_boss_chance | BOSS_MIN_GAP |
|---|---|---|---|
| 简单 | 0.22 | 0.30 | 75s |
| 普通 | 0.25 | 0.40 | 55s |
| 困难 | 0.30 | 0.50 | 40s |

普通档 pending 后平均约 `1/0.25 = 4` 个 tick（≈4s）内出场，位置随机；最小间隔保证两只 boss 不会挨着刷。

## 6. 调试 / 沙盒

设 `AiSpawnConfig.debug_spawn_log = true`，`AiSpawn.tick()` 每次掷骰打印：

```
[ai_spawn] diff=normal wave=3 era=2 tick=0.97 p=0.61 roll=hit spawn=yes alive=4/12
```

数值核对：`godot --headless --path . -s tools/ai_spawn_smoke.gd`（10 波 × 30s 模拟 + 满员不出兵断言 + 三难度 × 5 时代的 tick/p/速率/软顶 + 反扑与拆塔窗的 p）。
