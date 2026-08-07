# 牌桌远征：多时代进阶设计文档

## 1. 设计目标

《牌桌远征》是一款竖屏、Q 版粗描边风格的“凌乱牌堆取卡 → 三合一英雄 → 横版自动战斗”游戏。玩家通过整理牌堆组成英雄，派遣英雄守护己方防御塔，并用击杀积分推动文明从石器时代进阶到未来时代。

本项目的唯一玩法数据源是 `data/heroes.json`。时代、职业、英雄、卡牌、动画名与基础数值均从该 manifest 读取，代码不重复维护英雄清单。

## 2. 核心循环

1. 在当前时代牌池生成凌乱、互相覆盖的卡牌。
2. 点击没有被更高层卡牌完全覆盖的卡，卡牌飞入 7 格合成台。
3. 三张同名卡自动合成一个对应英雄。
4. 英雄进入己方战线；点击“开战”后敌方从右侧防御塔持续出兵。
5. 英雄自动移动、索敌、攻击或治疗，双方防御塔承受突破前线的英雄攻击。
6. 击杀敌方英雄获得弱化后的职业积分（不再发放可刷金币）。
7. 牌堆取空进入本关下一轮，牌池按轮次阈值混入更高时代的卡，继续打同一座敌塔。
8. 打爆敌方防御塔即过关并按速度发放金币与关卡/速度分，进入下一关；己方防御塔被打爆即失败。

## 2.1 关卡制（当前实现）

一局共 5 关，关卡与时代一一对应：第 1 关石器 → 第 2 关铁器 → 第 3 关工业 → 第 4 关现代 → 第 5 关未来。内部仍用 `enemy_era_index` / `GameData.ERAS` 表达关卡（`main.gd::_stage_number()` / `_stage_name()`），但玩法与 UI 均为关卡语义。

- **过关条件**：摧毁敌方防御塔。选完三选一增益后立即进入下一关（`main.gd::_enter_next_stage()`）。
- **过关重置**：牌堆与合成台当前轮次剩牌直接丢弃；双方小兵与投射物全部消失；双方防御塔按新关时代满血重建；从新关第 1 轮重新发牌。
- **过关保留**：金币与永久加成（`run_*` / `run_hero_mult` / `run_tower_hp_mult` / `free_reshuffles` / `free_clear_tokens`）；当轮修饰 `round_*` 重置。
- **同关多轮**：本关牌堆取空只推进轮次（不跨关），但玩家牌池时代按 `ERA_UP_ROUNDS := [2, 4, 7, 10]` 在本关时代下限 `base_era_index` 上逐级上升（只升不降）；敌方关卡/敌塔时代仍只靠拆塔推进。
- **每关独立数值**：出兵沿用 `AiSpawnConfig` 时代倍率，塔血沿用 `GameData.tower_hp` / `ally_tower_hp`。
- **终局**：打爆第 5 关敌塔获胜；己方塔被摧毁失败。

冒烟测试：`godot --headless --path . --script tools/stage_progression_smoke.gd`。

## 3. 五时代（= 五关）

时代顺序和中文名称来自 `heroes.json` 的 `eras` / `era_names`：

| 顺序 | ID | 名称 | 强度倍率 |
|---:|---|---|---:|
| 1 | stone | 石器时代 | 1.0 |
| 2 | iron | 铁器时代 | 1.7 |
| 3 | industrial | 工业时代 | 2.8 |
| 4 | modern | 现代 | 4.5 |
| 5 | future | 未来时代 | 7.2 |

每个时代固定包含 5 个职业：肉盾（tank）、战士（warrior）、刺客（assassin）、远程（ranged）、BOSS领袖（boss）。

## 4. 英雄职业矩阵

下表由 `data/heroes.json` 的 25 条英雄记录整理而来：

| 时代 | 肉盾 | 战士 | 刺客 | 远程 | BOSS领袖 |
|---|---|---|---|---|---|
| 石器时代 | 兽皮盾兵 `stone_tank` | 棒兵 `stone_warrior` | 骨刃猎手 `stone_assassin` | 投石手 `stone_ranged` | 部落酋长 `stone_boss` |
| 铁器时代 | 铁甲卫兵 `iron_tank` | 剑士 `iron_warrior` | 双刀刺客 `iron_assassin` | 弓箭手 `iron_ranged` | 铁王 `iron_boss` |
| 工业时代 | 铆钉重甲 `ind_tank` | 蒸汽拳手 `ind_warrior` | 烟雾刺客 `ind_assassin` | 火枪手 `ind_ranged` | 蒸汽机甲男爵 `ind_boss` |
| 现代 | 防暴盾警 `mod_tank` | 机枪兵 `mod_warrior` | 特工 `mod_assassin` | 狙击手 `mod_ranged` | 钢铁将军 `mod_boss` |
| 未来 | 护盾机甲 `fut_tank` | 激光剑士 `fut_warrior` | 赛博忍者 `fut_assassin` | 等离子炮手 `fut_ranged` | AI巨型机甲 `fut_boss` |

## 5. 强度公式与战斗属性

`GameData` 从 manifest 读取 `role_base`、`era_mult`、`role_scale`，为每个英雄计算：

- `hp = role_base[role].hp × era_mult[era]`
- `attack = role_base[role].attack × era_mult[era]`
- `range`、`move_speed`、`cooldown`、`kill_score` 取 `role_base[role]`
- `scale = role_scale[role]`

肉盾具有最高生命和较低攻击；战士均衡；刺客高速高频；远程拥有较长射程；BOSS领袖体型、生命、攻击和击杀积分最高。英雄的 `anim` 用于查找 `assets/anim/<anim>/`。

## 6. 卡牌、合成与时代牌池

每个英雄的 `card` 字段就是其卡牌名称，卡牌到英雄是一对一映射。当前时代牌池只包含当前时代 5 名英雄的卡。每种卡牌按 3 的倍数生成，保证基础局面可解。

牌池时代 = 本关时代下限 `base_era_index` + 本关轮次升级（`ERA_UP_ROUNDS`），发牌走 `GameData.blended_deck_counts(era_index)`（当前时代为主、旧时代卡混入）。同关内每刷完一轮牌池会混入更高时代的卡，且不会回退到更低时代；过关时牌堆与合成台剩牌直接丢弃，`round_number` 归 0 后从新关第 1 轮重新发牌，时代下限提到新关。

## 7. 防御塔与胜负

战场左端为己方塔，右端为敌方塔，双方均显示名称、当前 HP 和血条。英雄在战线中自动寻找最近敌方单位；敌方全灭后可继续推进并攻击敌塔，己方同理。进入塔攻击范围后单位停止移动并持续造成伤害。

- 己方塔 HP 归零：失败。
- 敌方塔 HP 归零：过关（第 5 关则胜利）。
- 己方全灭或敌人突破己方塔前线：失败（作为次要保护判定）。
- 敌方单位全灭但敌塔尚存时，战斗波次继续从敌塔生成。
- 非终关敌塔归零：过关（详见 2.1）；第 5 关敌塔归零：胜利。

塔基础生命随时代倍率提升，避免高时代只依赖单位瞬间结束战斗。

## 8. 积分、金币与关卡推进

方案甲：玩家击杀/塔击杀金币归零；击杀积分按 `KILL_SCORE_MULT`（0.25）弱化计入本局总分。每关有目标用时（信息栏显示已用时间与速度评级），倒计时归零不失败；过关金币公式为 `base_by_stage_and_diff * clamp(target_time / max(elapsed, 1), 0.35, 1.6)`，并额外累加关卡分与速度分。排行榜仍提交本局总分（`kill_score` 字段名兼容 SaveManager）。信息栏显示「第 N 关（时代名）· 第 R 轮 · 状态」。关卡推进只看是否打爆敌塔。第 5 关（未来）为终点。

## 9. 美术与动画

整体风格为石器时代手绘场景叠加 Q 版粗描边角色。英雄动画标准为：

- `idle.png`
- `walk_a.png`、`walk_b.png`
- `atk_a.png`、`atk_b.png`
- `die.png`
- `meta.json`

`BattleUnit` 优先使用 `assets/anim/<hero.anim>/` 的 `AnimatedSprite2D`；资源缺失时回退到对应静态图，再缺失时显示带时代色的纯色占位块和英雄名。敌方复用同一动画资源，通过 `scale.x` 取负镜像。

## 10. Godot 节点结构

```text
Main (Node2D)
├── BoardTable (牌堆区域)
├── MergeTray (7格合成台)
├── Battlefield (横版战场、双方防御塔与单位)
├── UI (CanvasLayer：时代、积分、塔血条、状态与按钮)
└── Managers (预留数据/流程管理)
```

主视口为 720×1280，使用 `canvas_items` 拉伸和 `keep` 宽高比。`scripts/main.gd` 负责牌堆、合成、波次与战斗流程，`scripts/game_data.gd` 负责从 manifest 构建运行时数据，`scripts/battle_unit.gd` 负责单个英雄的视觉、属性和受击状态。
