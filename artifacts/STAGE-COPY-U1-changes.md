# STAGE-COPY U1 — 过关奖励文案 off-by-one 修复

## 问题
打爆第 N 关后，奖励标题显示「随后进入第 N 关」，与玩家预期矛盾。

## 根因
`scripts/main.gd::_show_reward("stage_clear")` 使用 `_stage_name(enemy_era_index + 1)`。
而 `_stage_number()` 已是 `enemy_era_index + 1`（当前关），因此标题实际显示当前关而非下一关。

## 改动
1. `scripts/main.gd`：改为 `_stage_name(_stage_number() + 1)`（等价 `enemy_era_index + 2`），并加注释说明时机。
2. `tools/stage_progression_smoke.gd`：断言过关标题提示进入 `stage_before + 2`（即 N+1 关）。

## 未改动（纪律边界）
- `_enter_next_stage` 推进逻辑与 toast（advance 之后 `_stage_number()` 已正确）
- 玩法数值 / 其他 UI / 重排 / 摇一摇 / 打塔 / 清空 / 排行榜 / 索敌
