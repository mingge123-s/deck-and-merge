# 开发日志

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
