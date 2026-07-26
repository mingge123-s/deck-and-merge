#!/usr/bin/env python3
"""Dump every gameplay number into Markdown + CSV tables.

Reads data/heroes.json (source of truth for heroes/eras/roles) and the
constants mirrored from scripts/main.gd below. Run from the repo root:

    python3 tools/dump_balance_tables.py
"""
import csv
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs", "balance")

# Mirrored from scripts/main.gd + scripts/game_data.gd + scripts/save_manager.gd
TOWER_BASE_HP = 1800.0
TOWER_ATTACK = 30.0
TOWER_ATTACK_CD = 1.1
TOWER_ATTACK_RANGE = 420.0
TOWER_MELEE_RANGE = 82.0
TOWER_REPAIR_RATIO = 0.25
VICTORY_REWARD_BASE = 120
REINFORCEMENT_PRICE_BASE = 200
REPAIR_PRICE_BASE = 150
CLEAR_TRAY_PRICE_BASE = 120
DIFFICULTIES = {
    "easy": {"name": "简单", "wave_interval": 12.0, "first_delay": 6.0, "count_base": 1, "count_step": 5, "count_max": 3, "enemy_mult": 0.7},
    "normal": {"name": "普通", "wave_interval": 9.0, "first_delay": 4.0, "count_base": 2, "count_step": 4, "count_max": 5, "enemy_mult": 1.0},
    "hard": {"name": "困难", "wave_interval": 6.0, "first_delay": 3.0, "count_base": 3, "count_step": 3, "count_max": 7, "enemy_mult": 1.3},
}
ECONOMY = [
    ("初始金币（存档默认）", 300),
    ("英雄/塔击杀敌人金币", "敌方定位击杀积分 × 时代倍率（塔击杀不给击杀积分）"),
    ("战斗胜利", "120 × 时代倍率"),
    ("商店：召唤援军（当前时代随机英雄）", "200 × 时代倍率"),
    ("商店：修复我方塔（+25% 最大生命）", "150 × 时代倍率"),
    ("商店：清理合成台（移除 3 张牌）", "120 × 时代倍率"),
    ("商店：时代进阶", "石器→铁器 200；铁器→工业 360；工业→现代 600；现代→未来 950"),
]
BOARD = [
    ("逻辑分辨率", "720 × 1280（竖屏）"),
    ("合成台槽位", 7),
    ("合成规则", "3 张同名卡 → 1 个当前时代英雄"),
    ("初始牌堆张数", 45),
    ("补牌触发线", "剩余 ≤ 33 张"),
    ("补牌目标", "补回 45 张，同名 3 张一组，落在被覆盖率最高处的最底层"),
    ("战场世界宽度", "1680（可视 648，可横移）"),
    ("我方塔 X / 敌方塔 X", "96 / 1584"),
    ("单位近塔攻击距离", TOWER_MELEE_RANGE),
]


def fmt(value):
    if isinstance(value, float):
        return f"{value:g}" if value == int(value) else f"{value:.2f}".rstrip("0").rstrip(".")
    return str(value)


def table(headers, rows):
    out = ["| " + " | ".join(headers) + " |",
           "| " + " | ".join("---" for _ in headers) + " |"]
    for row in rows:
        out.append("| " + " | ".join(fmt(cell) for cell in row) + " |")
    return "\n".join(out)


def write_csv(name, headers, rows):
    path = os.path.join(OUT_DIR, name)
    with open(path, "w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(headers)
        for row in rows:
            writer.writerow([fmt(cell) for cell in row])
    return path


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    data = json.load(open(os.path.join(ROOT, "data", "heroes.json"), encoding="utf-8"))
    eras = data["eras"]
    era_names = data["era_names"]
    era_mult = data["era_mult"]
    era_tempo = data["era_tempo"]
    era_range_mult = data["era_range_mult"]
    era_cost = data["era_upgrade_cost"]
    roles = data["roles"]
    role_names = data["role_names"]
    role_base = data["role_base"]
    role_scale = data["role_scale"]

    hero_headers = ["时代", "英雄", "卡牌", "定位", "生命", "攻击", "攻速(次／秒)", "DPS",
                    "射程", "移速", "攻击间隔", "击杀积分", "体型"]
    hero_rows = []
    for era in eras:
        for hero in [h for h in data["heroes"] if h["era"] == era]:
            base = role_base[hero["role"]]
            mult = era_mult[era]
            tempo = era_tempo[era]
            cd = base["cooldown"] / tempo
            attack = base["attack"] * mult
            move_speed = base["move_speed"] * tempo
            range_value = base["range"] * era_range_mult[era]
            hero_rows.append([
                era_names[era], hero["name"], hero["card"], role_names[hero["role"]],
                round(base["hp"] * mult), round(attack, 1), round(1.0 / cd, 2),
                round(attack / cd, 1), round(range_value, 1), round(move_speed, 1), cd,
                base["kill_score"], role_scale[hero["role"]],
            ])

    role_headers = ["定位", "基础生命", "基础攻击", "射程", "移速", "攻击间隔", "击杀积分", "体型缩放"]
    role_rows = [[role_names[r], role_base[r]["hp"], role_base[r]["attack"], role_base[r]["range"],
                  role_base[r]["move_speed"], role_base[r]["cooldown"], role_base[r]["kill_score"],
                  role_scale[r]] for r in roles]

    era_headers = ["时代", "数值倍率", "节奏系数", "射程系数", "进阶金币价格"]
    era_rows = [[era_names[e], era_mult[e],
                 era_tempo[e], era_range_mult[e],
                 "—（最终时代）" if e == eras[-1] else era_cost[e]] for e in eras]

    tower_headers = ["时代", "塔生命", "单次伤害", "攻击间隔", "DPS", "攻击射程", "抛射物外观",
                     "抛射速度", "修复一次回血(25%)"]
    tower_art = {"stone": "投石", "iron": "箭", "industrial": "子弹", "modern": "子弹", "future": "能量弹"}
    tower_rows = [[era_names[e], round(TOWER_BASE_HP * era_mult[e]), round(TOWER_ATTACK * era_mult[e], 1),
                   TOWER_ATTACK_CD, round(TOWER_ATTACK * era_mult[e] / TOWER_ATTACK_CD, 1),
                   TOWER_ATTACK_RANGE, tower_art[e], 300,
                   round(TOWER_BASE_HP * era_mult[e] * TOWER_REPAIR_RATIO)] for e in eras]

    diff_headers = ["难度", "敌方数值倍率", "首波延迟(秒)", "出兵间隔(秒)", "起始每波人数",
                    "每 N 波 +1 人", "每波人数上限", "BOSS 波"]
    diff_rows = [[d["name"], d["enemy_mult"], d["first_delay"], d["wave_interval"], d["count_base"],
                  d["count_step"], d["count_max"], "每 5 波必出 BOSS"]
                 for d in (DIFFICULTIES[k] for k in ("easy", "normal", "hard"))]

    enemy_headers = ["时代", "英雄", "定位", "简单(生命／攻击)", "普通(生命／攻击)", "困难(生命／攻击)"]
    enemy_rows = []
    for era in eras:
        for hero in [h for h in data["heroes"] if h["era"] == era]:
            base = role_base[hero["role"]]
            mult = era_mult[era]
            cells = []
            for key in ("easy", "normal", "hard"):
                m = DIFFICULTIES[key]["enemy_mult"]
                cells.append("%d / %.1f" % (round(base["hp"] * mult * m), base["attack"] * mult * m))
            enemy_rows.append([era_names[era], hero["name"], role_names[hero["role"]]] + cells)

    econ_headers = ["项目", "数值"]
    board_headers = ["项目", "数值"]

    sections = [
        ("英雄数值总表（我方合成 / 敌方同池）", hero_headers, hero_rows, "heroes.csv"),
        ("定位基础模板（乘时代倍率前）", role_headers, role_rows, "roles.csv"),
        ("时代倍率与进阶金币价格", era_headers, era_rows, "eras.csv"),
        ("防御塔数值（双方共用）", tower_headers, tower_rows, "towers.csv"),
        ("难度与出兵节奏", diff_headers, diff_rows, "difficulty.csv"),
        ("敌方实际数值（含难度倍率）", enemy_headers, enemy_rows, "enemies.csv"),
        ("经济与商店", econ_headers, ECONOMY, "economy.csv"),
        ("牌桌与战场参数", board_headers, BOARD, "board.csv"),
    ]

    lines = ["# 牌桌远征 · 数值总表", "",
             "> 由 `tools/dump_balance_tables.py` 从 `data/heroes.json` 与 `scripts/main.gd` 常量生成，改数值后重跑即可刷新。", ""]
    for title, headers, rows, csv_name in sections:
        lines += ["## " + title, "", table(headers, rows), ""]
        write_csv(csv_name, headers, rows)
    lines += ["## 计算公式", "",
              "- 英雄生命 = 定位基础生命 × 时代倍率；英雄攻击 = 定位基础攻击 × 时代倍率。",
            "- 移速与攻速乘节奏系数（攻击间隔除以节奏系数）；射程乘射程系数。",
              "- 敌方单位 = 上述数值 × 难度倍率（生命与攻击都乘）。",
              "- 防御塔生命 = 1800 × 时代倍率；塔伤害 = 30 × 时代倍率，间隔 1.1 秒，射程 420。",
              "- 击杀金币 = 敌方定位击杀积分 × 时代倍率；胜利奖励 = 120 × 时代倍率；商店价格均乘时代倍率。",
              "- 防御塔击杀敌人给金币但不给击杀积分；击杀积分只用于本局结算和最高分显示。",
              "- 时代进阶由商店花金币购买：石器→铁器 200、铁器→工业 360、工业→现代 600、现代→未来 950。",
              "- 暂停即整备时间：战斗、出兵、塔攻击和牌堆冻结，玩家可打开商店购买后确认再战。",
              "- 清理合成台移除 3 张同名数量最少的牌，价格 = 120 × 时代倍率。", ""]

    md_path = os.path.join(OUT_DIR, "README.md")
    with open(md_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))
    print("wrote", md_path)


if __name__ == "__main__":
    main()
