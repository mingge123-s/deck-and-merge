# 分队 U6 验收报告：身后近战可还击（方案 A）

**分支：** 见本 PR head  
**仓库：** https://github.com/mingge123-s/deck-and-merge

## 实现摘要

单位受到来自身后的**近战英雄伤害**（`source == "hero"` 且攻击者 `range < PROJECTILE_RANGE_THRESHOLD`，且攻击者不在前方半区）时：

1. 注册短时还击仇恨：`backstab_retaliate_by` + `backstab_retaliate_time`
2. 基础窗口 `BACKSTAB_RETALIATE_DURATION = 2.0s`
3. 若攻击者当时 `untargetable`（如 `phase_execute` 1.5s），窗口延长为 `untargetable_time + 2.0s`，保证不可选中结束后仇恨仍生效
4. `_find_target`：嘲讽之后、坦克拉仇恨/前方优先之前，优先选还击目标
5. `_is_front_candidate`：对该攻击者临时关闭前方过滤（其余目标仍前方优先）

**未改动：** 塔优先 / 摇一摇 / UI / 排行榜。

## 验收用例

| # | 用例 | 期望 | 结果 |
|---|------|------|------|
| 1 | 身后近战打中 + 前方有 decoy | 注册窗口并优先还击身后攻击者 | OK |
| 2 | 前方近战打中 | 不注册背后还击 | OK |
| 3 | 身后远程英雄伤害 | 不注册（仅近战） | OK |
| 4 | 塔伤害 | 不注册 | OK |
| 5 | `phase_execute` 瞬身后 + untargetable | 保留 1.5s untargetable；结束后优先还击刺客；窗口覆盖 untargetable+2s | OK |
| 6 | 无背后仇恨 | 前方优先仍生效 | OK |

## Headless 证据

```text
$ godot --headless --path . --import
EXIT:0
NO_SCRIPT_ERROR

$ godot --headless --path . --script tools/backstab_aggro_smoke.gd
backstab_aggro_smoke: OK
EXIT:0
（无 SCRIPT ERROR / Parse Error）
```

完整日志：`artifacts/godot_import.log`、`artifacts/backstab_aggro_smoke.log`
