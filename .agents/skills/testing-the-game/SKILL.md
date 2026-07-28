---
name: testing-the-game
description: How to run and GUI-test the Deck & Merge (牌桌远征) Godot game, plus the art-asset invariants (transparent/trimmed sprites, empty runtime backgrounds) that testing must guard.
---

# 测试《牌桌远征》(Deck & Merge)

Godot 4.7.x 竖屏(720×1280)手机游戏。核心循环:凌乱牌堆点击取卡 → 7 格合成台 3 张同名自动合成 → 战场生成部落棋子 → 横版自动战斗 → 胜负结算 + 重开。

## 运行

```bash
# 桌面 GUI(需要 DISPLAY=:0)。用 setsid 让进程脱离当前 shell 存活
cd /home/ubuntu/repos/deck-and-merge
DISPLAY=:0 setsid nohup godot --path . >/tmp/godot_run.log 2>&1 < /dev/null & disown
sleep 12
DISPLAY=:0 wmctrl -a "牌桌远征" && DISPLAY=:0 wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz   # 录屏前最大化窗口

# 重新导入资源(改过 assets 后必须)
godot --headless --path . --import
```

- ALSA / Mesa(llvmpipe)警告是软件渲染下的正常噪音,可忽略。判断脚本缺陷时先滤掉:
  `grep -iE "SCRIPT ERROR|Parse Error" /tmp/godot_run.log`
- 关闭进程用 `pkill -f "godot --path"`。**注意**:不要把 `pkill` 和启动命令写在同一条 shell 语句里 —— `pkill -f "godot --path"` 会匹配到含该字符串的命令行本身,把自己的 shell 一起杀掉(表现为 exit code -1、游戏没起来)。分两次执行。
- 启动约需 10~14s 才会出现窗口;用 `DISPLAY=:0 wmctrl -l | grep 牌桌` 确认再继续。

## GUI 测试要点

- 用真实点击走完 T1–T4(点卡→合成→开战→胜负→重开),而不是只跑 headless。
- 全屏截图取证:`DISPLAY=:0 import -window root out.png`(或 computer 工具截图)。
- **随机牌堆 + 7 格合成台容易软锁**:手动收集特定单位时,若 7 格被 4 种以上单卡占满且无三连,就无法再取卡。要定向验证某个单位时,优先先凑齐它的三连(或用临时调试键生成)。
- 需要定向生成某单位做视觉验证时,可临时在 `main.gd` 加 `_unhandled_key_input` 按键生成(`_spawn_ally("shaman")` 等),**验证完务必删除临时代码**。
- 初始牌堆只有 `STARTER_TYPES = [stone_axe, club, spear, sling, bone]`,对应 clubber/spearman/slinger/shaman;`shield`(兽皮 pelt)、`healer`(篝火/金块)常规玩法不可达,需调试生成。

## 内部数值可观测性(强烈建议)

正式 UI **不显示**牌堆剩余/各卡张数、波次、敌人数量、单位 hp/攻击/移速、塔上限、buff 剩余秒数 —— 想验证任何数值断言几乎都必须临时插桩。推荐做法(验证完 `git checkout -- scripts/main.gd` 还原):

- 在牌堆区上方加 3 行白字黑描边调试 HUD,并在 `_process` 里调用刷新(牌堆变化不会走 `_update_progress_ui`,不刷新会看到陈旧值):
  - 行1 `牌堆N[各卡张数] 台N 波N 金N`
  - 行2 `我N[首个我方单位 名/hp/spd/dmg] 敌N[hp/x坐标] 塔hp/max 冻X.X 炮xN.NN`
- 加 `_unhandled_key_input` 热键:`1..9,0,Q,W` 依次触发 12 个随机效果(复用 `_apply_random_effect`、仅跳过扣费),`M` 加 5000 金币。**理由**:随机效果 260 金/次且 12 选 1,靠真实购买无法在合理时间内覆盖全部效果;真实购买路径另抽 2~3 次单独验证扣费与文案即可。
- 验证「冰冻是否真停 3 秒」这类断言,靠敌方 `x` 坐标在 HUD 里是否变化最可靠。
- 验证受伤/反弹/吸血/悬赏这类一次性数值,直接在对应分支加临时 `print` 比读 HUD 更稳。

## 测试这个游戏时容易踩的坑

- **自动整备会吞点击**:每 3 波结束弹出的整备面板会吸收正在进行的点击,常出现「点了 3 张牌但一张都没进合成台」。批量点卡后一定回读 HUD 确认牌堆/合成台真的变了,不要假设点击生效。整备面板还会遮住合成台与调试 HUD。
- **整备面板会叠在商店之上**:此时点「确认再战」无响应、战斗保持冻结,必须先点商店「关闭」。别误判为游戏崩溃。
- **「返回主界面」后结算面板不会关闭**,压住「开始游戏」且「重新开始」失效 → 一局之后就开不了新局,**只能重启进程**。安排测试顺序时把需要多局的用例排在一起,并优先用结算面板上的「重新开始」(在游戏内是有效的)而不是「返回主界面」。
- **顶栏金币显示重开后不刷新**(`_start_round` 未调 `_update_coin_ui`),会显示上一局残留值。要读真实金币请打开商店看「金币: N」,或用调试 HUD。
- **简单难度也会在第 4~5 波被打崩**:没能立刻凑出三连时塔会独自阵亡。做长流程/边界测试前,先在商店买几个「召唤援军」当保镖再慢慢测卡牌逻辑 —— 但注意援军可能抽到未来时代超模英雄,**买 5 个左右就足以快速通关**,想让对局持续久一点就别买太多。
- **补牌门槛是「缺口 ≥ 3」**:BOSS 卡目标仅 3 张,取走 1~2 张后缺口恒 <3 → 永不补回,牌堆也会稳定在 48 而非 51。测「牌堆耗尽」时要知道这个机制下很难真的抽干。
- **合成台满 7 格且无三连 = 直接判负**(`_check_stuck`),没有预警。想构造这个场景:收 图腾1+兽皮2+骨刃2+木棒2。想避免它:优先凑三连。

## 美术资源不变量(测试必须守住)

1. **精灵必须透明 + 紧裁**:`assets/{units,enemies,cards}/*.png` 四角 `alpha` 必须为 0,尺寸应按内容裁剪(不是整格 341×512)。否则单位身后会出现"白色卡片状方块"。快速校验:

```bash
python3 -c "
import glob
from PIL import Image
for f in sorted(glob.glob('assets/units/*.png')):
    im=Image.open(f).convert('RGBA'); w,h=im.size
    a=[im.getpixel(p)[3] for p in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]]
    print(f, im.size, a, 'BAD' if any(x>0 for x in a) else 'ok')
"
```

2. **运行时背景必须为空**:`assets/bg_board.png`、`assets/bg_battle.png` 是手绘的空场景,**不得**由 `concept_screen.png`(含烘焙卡牌/单位/敌人)重新裁剪。`tools/slice_assets.py` 只切精灵、不生成背景。改切图后务必确认这两张背景没被覆盖成拼图。

## 切图脚本

`tools/slice_assets.py`:median 四角基准色 + flood-fill 去连通近白/近背景色 + bbox 紧裁 + 1px 透明边距。跑完记得 `--import` 重新导入。
