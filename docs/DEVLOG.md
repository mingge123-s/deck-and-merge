# 开发日志

## 2026-08-07：方案甲 速度金币与积分改版

- 取消超时失败：`STAGE_TIME_LIMIT` 改为目标用时（第 2 关 = 第 1 关 ×2），信息栏显示已用时间 + 速度评级；暂停/奖励面板仍冻结计时。
- 玩家击杀/塔击杀金币归零；开局金币 300→400。过关金币按 `base × clamp(target/elapsed, 0.35, 1.6)`；击杀积分 ×0.25，过关追加关卡分+速度分。
- 悬赏令改为「疾战悬赏」（即时金币 + 过关金加成）；战利品增益改为过关金币 +30%。教程/GDD/balance 文案同步。
- 冒烟：`tools/economy_a_smoke.gd` 新增；`tools/stage_time_limit_smoke.gd` / `stage_progression_smoke.gd` 更新。

## 2025-07-23：多时代进阶改造启动

- 确认 `data/heroes.json` 为英雄、时代、职业、卡牌、动画和数值的唯一数据源。
- 完成 5 时代 × 5 职业的英雄矩阵设计文档。
- 规划从牌堆合成、镜像敌人波次、双塔攻防到击杀积分升时代的完整循环。
- 约定缺少美术资源时由动画回退到静态贴图，再回退到纯色占位，不阻塞玩法开发。

## 2025-07-23：数据驱动战斗系统

- 将英雄运行时属性改为由职业基础值与时代倍率计算。
- 设计当前时代牌池和升时代后的渐进式换牌机制。
- 将旧的野兽敌人波次替换为同一英雄池的镜像敌人。
- 将胜负核心从基地线/全灭升级为双方防御塔 HP。

## 2025-07-23：文档与验证计划

- 新增多时代 GDD，记录核心循环、职业矩阵、公式、塔规则、动画约定和 Godot 节点结构。
- 约定每个里程碑单独提交并推送到 `origin main`。
- 验证重点：`godot --headless --import`、`--check-only`、主场景加载及 DISPLAY 实机回归。

## 2026-07-23：多时代 MVP 实现与回归

- `GameData` 改为从 `heroes.json` 初始化 25 名英雄、5 个时代、5 个职业和卡牌映射。
- 主流程改为当前时代牌池，三张同名卡合成 manifest 英雄；升级后保留旧卡并把新时代卡放入牌堆底部。
- 战场加入己方塔、敌方塔、塔血条、镜像英雄波次、击杀积分和时代进阶提示。
- `BattleUnit` 按 `hero.anim` 复用帧动画并按职业倍率调整体型；缺少美术时回退为静态贴图或纯色英雄名占位。
- 通过 `godot --headless --path . --import`、`--check-only` 和主场景运行检查。
- DISPLAY 实跑使用临时调试入口生成石器时代英雄并开战，确认战斗可进入失败结算；截图留存于 `/tmp/deck_and_merge_era_battle.png`。

## 2026-07-23：补齐后期时代英雄帧动画

- 为此前缺动画的 11 名英雄补齐 idle/walk/attack/die 帧动画：工业 BOSS（蒸汽机甲男爵）、现代全职业（防暴盾警/机枪兵/特工/狙击手/钢铁将军）、未来全职业（护盾机甲/激光剑士/赛博忍者/等离子炮手/AI 巨型机甲）。至此 5 时代 × 5 职业共 25 名英雄均有真实帧动画，敌我共用。
- 生成管线：以 idle 帧为参考图（图生图）重摆姿势生成其余 5 帧，角色跨帧一致性显著提升；再经 `build_anim.py` 去背/紧裁/脚部对齐输出到 `assets/anim/<id>/` 并写 `meta.json`。
- 新增 `tools/shrink_anim.py`：将每个英雄的动画画布高度上限压到 420px，帧与 `meta.json`（anchor/char_height/canvas）按同一比例缩放，属渲染等价变换。导出 pck 从 139MB 降到 84MB。
- 验证：`godot --headless --import` 全部 66 张新图生成 `.import`；单线程 Web 导出成功；部署到 `https://mingge.asia/deck-and-merge/`，本地/远端 pck sha256 一致，HTTPS 200。

## 2026-07-24：宽版可横移战场 + 右上角小地图

- 战场由单屏定宽改为 `WORLD_WIDTH=1680` 的宽世界，双方防御塔拉远（己方 x=96、敌方 x=WORLD_WIDTH-96），一屏（视窗宽 648）装不下。
- 新增可滚动的 `world` 容器（`battlefield.clip_contents=true` 裁剪），背景、双塔、阴影、单位、抛射物、命中特效全部挂到 `world`；单位移动/寻敌/攻击逻辑沿用塔 X 常量，无需改动。
- 用户可在战场按下拖动横移镜头（`_on_battlefield_input` → `camera_x` 夹取到 `[0, WORLD_WIDTH-视窗]`，`_apply_camera` 更新 `world.position.x`）；每局开始 `_reset_camera`。
- 新增 `scripts/minimap.gd`（`BattleMinimap`，自绘 Control）：右上角小地图实时显示己方蓝点、敌方红点、两端塔标记和当前视窗白框；`main._update_minimap` 每帧按世界坐标映射刷新。
- HUD 重排：开战按钮移到左上，小地图占右上；塔血条面板保持固定角落 HUD 不随滚动。
- 验证：`godot --headless --import` 无脚本错误；DISPLAY 实跑确认横移露出远处敌塔、小地图视窗框同步、开战后蓝/红点实时显示并可拖动跟随战斗。

## 2026-08-05：敌方时代多阶段连续战改为关卡制

- 玩法：**摧毁敌方防御塔 = 过关**，选完三选一增益后立即进入下一关（新增 `main.gd::_enter_next_stage()`，替换旧的 `_ascend_enemy_era_phase`「敌方清场 + 己方重整」路径）。过关时牌堆与合成台当前轮次剩牌直接丢弃、双方小兵与投射物全清、双方防御塔按新关时代满血重建、从新关第 1 轮重新发牌；金币与 `run_*` / `run_hero_mult` / `run_tower_hp_mult` / `free_reshuffles` / `free_clear_tokens` 保留，`round_*` 当轮修饰重置。失败条件不变（己方塔被摧毁）。
- 关卡锁定卡池：移除 `ERA_UP_ROUNDS := [2,4,7,10]` 与 `_advance_era()`「靠抽牌轮次偷升时代」，`era_index` 由 `_sync_player_era_to_stage()` 恒等于当前关卡（`enemy_era_index`）。同关内牌堆取空仍走原「取空 → 下一轮发牌」，只推进 `round_number`。
- 起始关卡：主菜单「选择时代」改为「选择起始关卡」，选第 N 关时敌方与玩家时代同关锁定（原先敌方总是从石器开始）。
- 塔壁奖励改为永久：新增 `run_tower_hp_mult`，己方塔满血值统一走 `_ally_tower_target_hp()`，过关重建时仍保留塔血加成。
- UI 文案：信息栏改为「第 N 关（时代名）· 第 R 轮 · 状态」；敌塔血条阶段标签改为「第 N 关」；过关奖励面板标题提示即将进入的关卡；教程第 4 步改写为关卡说明；GDD / ai-spawn-probability 文档同步。
- 验证：`godot --headless --path . --import` 无 SCRIPT ERROR；新增 `tools/stage_progression_smoke.gd` 逐关走完 5 关，断言过关后关卡 +1、牌池时代锁定、轮次归 1、双方清场、双方塔满血、金币与永久加成保留、终关打爆敌塔进终局，结果 OK；`tools/ai_spawn_smoke.gd` 回归通过。

## 2026-08-05：恢复同关内轮次牌堆升级（关卡仍靠拆塔推进）

- 问题（#54 回归）：同关内牌堆取空后只发本关时代的牌，第 1 关多轮都是石器原牌堆，等于每轮回到起点。
- 恢复 `ERA_UP_ROUNDS := [2, 4, 7, 10]` 与 `_advance_era()`：`_spawn_next_batch` 按 `base_era_index + 本关轮次阈值` 推进玩家 `era_index` / `current_era`，再用 `GameData.blended_deck_counts(era_index)` 发牌，只升不降。
- `_sync_player_era_to_stage()` 改为「提下限」：`base_era_index = max(base_era_index, enemy_era_index)`，`era_index = max(era_index, base_era_index)`；过关后 `round_number = 0` 再发第 1 轮，新关第 1 轮至少是本关时代基底。
- 敌方关卡 / 敌塔时代仍只在打爆敌塔时推进；玩家牌池可按轮次超前于当前关卡（旧手感）。
- 文案：教程「同关多轮仍是本关时代牌」改为「牌堆取空后逐轮混入更高时代的卡」；GDD 同步。
- 验证：`tools/stage_progression_smoke.gd` OK（新增断言：第 1 关第 2 轮 `era_index>=1` 且牌堆同时含铁器与石器卡；每关第 1 轮 `era_index >= 关卡下限`）；`tools/ai_spawn_smoke.gd` 回归通过。
