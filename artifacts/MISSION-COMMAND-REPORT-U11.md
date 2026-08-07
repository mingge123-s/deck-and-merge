# MISSION-COMMAND REPORT — U11 / 方案甲

分队：U11  
参谋长 Agent：见 OPORD  
本分队运行页：https://cursor.com/agents/bc-ca985766-4c61-456d-8bfc-20daedec46b0  
Draft PR：https://github.com/mingge123-s/deck-and-merge/pull/71

## 确认简报（已落地）

| 项 | 取值 |
| --- | --- |
| 击杀金币 | **归零（0）** |
| 开局金币 | **400** |
| 过关公式 | `clear_gold = base * clamp(target/max(elapsed,1), 0.35, 1.6)` |
| base | `180 × 关卡时代倍率 × 难度系数`（easy 1.15 / normal 1.0 / hard 0.9） |
| 目标用时 | 原表；第 2 关 = 第 1 关 ×2（不失败） |
| 倒计时归零判负 | **已移除** |
| 击杀分 | ×0.25；过关 + 关卡分 + 速度分 |
| 清空按钮 | **保留**（U12） |

## 变更要点

1. 计时改为累计已用 + 速度评级 UI；暂停/奖励面板仍冻结  
2. 击杀/塔击杀金币 = 0；悬赏→疾战悬赏；战利品→过关金 +30%  
3. 过关/终局发放速度金币与关卡/速度分；排行榜仍用本局总分  
4. 教程去掉倒计时判负与击杀磨兵表述，改为速度奖励说明  
5. smoke：`economy_a` / `stage_time_limit` / `stage_progression` / `leaderboard`

## 验证证据

```
economy_a_smoke: OK          → artifacts/economy_a_smoke.log
stage_time_limit_smoke: OK   → artifacts/stage_time_limit_smoke.log
stage_progression_smoke: OK  → artifacts/stage_progression_smoke.log
leaderboard_smoke: OK        → artifacts/leaderboard_smoke.log
```

简报：`artifacts/speed-economy-briefing.md`
