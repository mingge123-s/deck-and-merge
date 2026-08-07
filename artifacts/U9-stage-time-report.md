# U9 关卡时限调整报告

## 变更
- `scripts/main.gd` `STAGE_TIME_LIMIT`：
  - easy `[240, 480, 240, 240, 240]`
  - normal `[180, 360, 180, 180, 180]`
  - hard `[150, 300, 150, 150, 150]`
- 第 2 关 = 第 1 关 ×2；第 3–5 关与第 1 关相同。
- `tools/stage_time_limit_smoke.gd`：过关进第 2 关后断言 `stage_time_limit == 第1关 * 2`。
- 教程未写死「每关相同时长」，仅更新常量注释。

## 验证
```bash
godot --headless --path . --import
godot --headless --path . --script tools/stage_time_limit_smoke.gd
```
结果：`stage_time_limit_smoke: OK`（exit 0）  
Godot：4.7.1.stable  
日志：`artifacts/stage_time_limit_smoke.log`

## PR
https://github.com/mingge123-s/deck-and-merge/pull/68
