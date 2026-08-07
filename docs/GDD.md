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
6. 击杀敌方英雄获得职业对应积分与金币。
7. 牌堆取空进入下一轮，牌池按轮次阈值混入更高时代的卡，继续同一局。
8. 摧毁敌方防御塔获得大量金币并重建敌塔；己方防御塔被打爆即失败。时代随战斗时间自动推进。

## 2.1 时间轴时代（当前实现）

**不要关卡制**。一局为连续生存：石器 → 铁器 → 工业 → 现代 → 未来，由战斗时间推进（`era_elapsed` / `battle_elapsed`），暂停与奖励遮罩不累计。时长表：`ERA_DURATION_SEC := [300, 480, 900, 1200, 1800]`（石器 5 分 / 铁器 8 分 / 工业 15 分 / 现代 20 分 / 未来 30 分；`main.gd` / `AiSpawnConfig`）。

- **毁塔奖励**：摧毁敌塔直接发放 `TOWER_DESTROY_GOLD_BASE := 200`（×时代）金币，并计入 `TOWER_DESTROY_SCORE_BASE := 100`（×时代）积分到本局 score；toast/hint 提示即可，**不弹**奖励面板。敌塔按**当前时代**满血重建；清除敌方小兵、保留己方单位与牌堆/合成台。
- **时代推进**：`era_elapsed` 到期 → `enemy_era_index += 1`（封顶未来），切换 `enemy_era`，重建敌塔血量，`ai_spawn.on_phase_start()`，`era_elapsed = 0`，提示「进入铁器时代」等。玩家牌池下限 `max(player, enemy)` 上提，不削弱已有进度。
- **同局多轮**：牌堆取空只推进轮次；玩家牌池按 `ERA_UP_ROUNDS := [2, 4, 7, 10]` 混入更高时代卡（只升不降）。
- **AI 出兵**：在难度与 `enemy_era_index` 之外，按 `time_in_era_norm = clamp(era_elapsed/ERA_DURATION, 0, 1)` 从少到多（频率/软顶/单位属性），详见 `docs/ai-spawn-probability.md`。
- **失败**：仅己方塔被摧毁（或玩家退出）。未来时代毁塔也只给金币并重建，不强制通关胜利。
- **起始入口**：主菜单「起始时代」可选开局时代/难度入口，不是选关。

冒烟测试：`godot --headless --path . --script tools/time_era_smoke.gd`。

## 3. 五时代

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

牌池时代 = 下限 `base_era_index`（与敌方时代对齐取高）+ 轮次升级（`ERA_UP_ROUNDS`），发牌走 `GameData.blended_deck_counts(era_index)`（当前时代为主、旧时代卡混入）。同局每刷完一轮牌池会混入更高时代的卡，且不会回退；毁塔与时间推进时代均不丢弃牌堆/合成台。

## 7. 防御塔与胜负

战场左端为己方塔，右端为敌方塔，双方均显示名称、当前 HP 和血条。英雄在战线中自动寻找最近敌方单位；敌方全灭后可继续推进并攻击敌塔，己方同理。进入塔攻击范围后单位停止移动并持续造成伤害。

- 己方塔 HP 归零：失败。
- 敌方塔 HP 归零：发放大量金币并按当前时代满血重建（详见 2.1）；未来时代同样只给金币，不强制胜利。
- 己方全灭或敌人突破己方塔前线：失败（作为次要保护判定）。
- 敌方单位全灭但敌塔尚存时，战斗波次继续从敌塔生成。

塔基础生命随时代倍率提升，避免高时代只依赖单位瞬间结束战斗。

## 8. 击杀积分与时代推进

本局积分（`kill_score`）由两项累计，供结算与排行榜：

1. **消灭敌方小兵**：沿用英雄职业 `kill_score` 入账（塔炮击杀给金币但不给这项击杀分）。
2. **摧毁敌方防御塔次数**：每次拆塔额外加 `TOWER_DESTROY_SCORE_BASE := 100`，按敌方当前时代倍率放大（`_era_amount_for`）。

拆塔**金币**（`TOWER_DESTROY_GOLD_BASE := 200`×时代）直接发放，无奖励面板；拆塔**积分**计入本局 score。信息栏显示「时代：石器时代 · 第 R 轮 · 状态」，倒计时为时代剩余。敌方时代靠战斗时间推进。排行榜按积分排序；`stage_reached` 复用为时代进度，UI 显示时代名（不用「第 N 关」）。

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
