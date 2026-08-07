# 重排无响应 根因取证（U15）

## 点击路径

```
reshuffle_button.pressed / reshuffle_hit_pad.pressed
  → _on_reshuffle_pressed()
      → _reshuffle_block_reason() 非空？ → _notify_action_blocked（toast+hint+抖动）【禁止静默】
      →（旧）首次未看过提示 → 显示 reshuffle_confirm_overlay 后 return  【真机易表现为「没反应」】
      → _do_reshuffle() → 扣费/洗牌 → toast「已重排…」
```

摇一摇：`_try_shake_deck` → 同上入口（冷却/非战斗仍可能早退，与按钮分轨）。

## 遮罩与兄弟节点（触摸）

| 节点 | z | mouse_filter | 战斗中可见？ | 是否挡重排 |
|------|---|--------------|--------------|------------|
| pause_overlay | 4000 | 根 IGNORE；子 STOP 镂空 INFO_BAR | 暂停/整备 | 逻辑上不挡 info_bar；Android 镂空不可靠 → U8 已抬 info_bar |
| info_bar / reshuffle_button | 4005 | 默认可点 | 是 | 视觉按钮 |
| main_menu | **4010** | STOP 全屏 | 应否 | **高于 info_bar**；若误显示则 Class A |
| tutorial / result / card_info | 4090/4050/4095 | STOP | 模态 | 应挡 |
| toast | 4096 | IGNORE | 短暂 | 不挡 |
| **reshuffle_hit_pad（本修）** | **4080** | STOP 扩大热区 | 战斗中非模态 | 兜底接点击 |

## 失败分类（相对现网 v20 症状）

统帅反馈：**无 toast / 无扣费 / 无洗牌**。

| 类 | 含义 | 与本症状匹配度 | 证据 |
|----|------|----------------|------|
| **A** | 点击未进 `_on_reshuffle_pressed` | 高（若完全无反馈） | `main_menu.z > info_bar`；pause 镂空在部分 Android 不可靠；info 内 64×64 仍可能点空；smoke 注释已记录「_hide_tutorial 可能把主菜单又打开」 |
| **B** | 进回调被软挡且无可见反馈 | **高（首次确认）** | 旧路径 `hint_seen=false` 时只 `visible=true` 确认层后 `return`，**无 toast**；确认层若被挡/未感知 → 酷似死按钮。金币不足路径代码上有 `_notify_action_blocked`，但若属 A 则仍无反馈 |
| **C** | 执行了但无视觉变化 | 低 | `_do_reshuffle` 会扣费+toast；「无扣费」与 C 矛盾 |

**结论（择组合修）**：主因按 **B（首次确认层无感）+ A（触控未命中/高层遮罩）** 处理；非单纯 C。

## 修复要点

1. 取消首次确认层拦截 → 直接 `_do_reshuffle`，首次成功 toast 附「· 可解压住的牌」。
2. 根节点透明 `reshuffle_hit_pad`（z=4080，外扩 16px）战斗中兜底；模态时隐藏。
3. `_hide_tutorial`：`battle_active` 时不再拉回 main_menu。
4. 拦截路径保持 `_notify_action_blocked`（金币不足/牌不足/阶段）。

## 验证

- `tools/shake_reshuffle_smoke.gd`：paused/非 paused、金币不足、牌不足、正常扣费、首次无确认层、hit pad z。
- GUI：开战/整备或暂停下点重排应见 toast。
- 热更：v21（本站 `mingge.asia` 直链）。
