#!/usr/bin/env python3
"""Generate the 128x128 transparent reward icons for the round-reward cards.

Each icon is drawn at 4x with a dark outline + flat fills (matching the
game's chunky cartoon art / assets/icons/effects), then downscaled. One icon
per reward id in main.gd's _reward_pool(). Run from the repo root:

    python3 tools/gen_reward_icons.py
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "icons", "rewards")
SIZE = 128
SCALE = 4
S = SIZE * SCALE
OUTLINE = (43, 26, 18, 255)
STROKE = 3 * SCALE

STONE = (198, 168, 132, 255)
STONE_DARK = (170, 138, 102, 255)
GOLD = (255, 206, 92, 255)
GOLD_DARK = (238, 176, 60, 255)
BLADE = (206, 220, 236, 255)
BLADE_DARK = (150, 170, 196, 255)
BLOOD = (222, 66, 92, 255)
GREEN = (126, 214, 126, 255)
PURPLE = (156, 118, 216, 255)
PURPLE_DARK = (120, 84, 176, 255)
CYAN = (120, 224, 236, 255)
SHIELD = (128, 158, 192, 255)
SHIELD_LIGHT = (196, 216, 238, 255)


def poly(draw, points, fill, outline=OUTLINE, width=STROKE):
    draw.polygon([(x * SCALE, y * SCALE) for x, y in points], fill=fill, outline=outline, width=width)


def line(draw, points, fill, width=5):
    draw.line([(x * SCALE, y * SCALE) for x, y in points], fill=fill, width=width * SCALE, joint="curve")


def ellipse(draw, box, fill, outline=OUTLINE, width=STROKE):
    x0, y0, x1, y1 = [v * SCALE for v in box]
    draw.ellipse((x0, y0, x1, y1), fill=fill, outline=outline, width=width)


def star(cx, cy, outer, inner, points=5, rotation=-90.0):
    result = []
    for index in range(points * 2):
        radius = outer if index % 2 == 0 else inner
        angle = math.radians(rotation + index * 180.0 / points)
        result.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return result


def up_arrow(draw, cx, top, bottom, half=13, stem=8, fill=GREEN):
    poly(draw, [(cx, top), (cx + half, top + 18), (cx + stem, top + 18),
                (cx + stem, bottom), (cx - stem, bottom),
                (cx - stem, top + 18), (cx - half, top + 18)], fill)


def tower(draw, top=54):
    # crenellated stone tower base, occupying the lower part of the icon
    poly(draw, [(40, top + 18), (88, top + 18), (82, 116), (46, 116)], STONE)
    poly(draw, [(34, top), (46, top), (46, top + 9), (58, top + 9), (58, top),
                (70, top), (70, top + 9), (82, top + 9), (82, top),
                (94, top), (94, top + 18), (34, top + 18)], STONE_DARK)


def card(draw, box, fill, outline=OUTLINE):
    x0, y0, x1, y1 = [v * SCALE for v in box]
    draw.rounded_rectangle((x0, y0, x1, y1), radius=8 * SCALE, fill=fill, outline=outline, width=STROKE)


# ---------------------------------------------------------------- tower rewards

def tower_wall(draw):
    poly(draw, [(24, 40), (104, 40), (104, 116), (24, 116)], STONE)
    for row, y in enumerate((40, 66, 92)):
        offset = 0 if row % 2 == 0 else 20
        for bx in range(-1, 4):
            x = 24 + offset + bx * 40
            line(draw, [(max(24, x), y), (min(104, x), y)], STONE_DARK, 2)
        line(draw, [(24, y), (104, y)], STONE_DARK, 2)
    for x in (44, 64, 84):
        line(draw, [(x, 53), (x, 66)], STONE_DARK, 2)
        line(draw, [(x - 20 if x > 44 else 54, 79), (x - 20 if x > 44 else 54, 92)], STONE_DARK, 2)
    poly(draw, [(40, 12), (64, 4), (88, 12), (88, 40), (40, 40)], SHIELD)
    poly(draw, [(52, 18), (64, 14), (76, 18), (76, 34), (64, 40), (52, 34)], SHIELD_LIGHT)


def tower_repair(draw):
    tower(draw)
    poly(draw, [(56, 18), (72, 18), (72, 34), (88, 34), (88, 50), (72, 50),
                (72, 66), (56, 66), (56, 50), (40, 50), (40, 34), (56, 34)], GREEN)


def tower_cannon(draw):
    tower(draw)
    ellipse(draw, (52, 30, 76, 54), (70, 70, 78, 255))
    ellipse(draw, (58, 36, 68, 46), (120, 120, 128, 255))
    line(draw, [(64, 42), (64, 8)], (70, 70, 78, 255), 8)
    ellipse(draw, (56, 2, 72, 18), (100, 100, 108, 255))


def tower_thorns(draw):
    tower(draw)
    for angle_deg in range(0, 360, 45):
        angle = math.radians(angle_deg - 90)
        bx, by = 64 + math.cos(angle) * 16, 34 + math.sin(angle) * 16
        tx, ty = 64 + math.cos(angle) * 30, 34 + math.sin(angle) * 30
        side = math.radians(angle_deg)
        poly(draw, [(bx + math.cos(side) * 6, by + math.sin(side) * 6),
                    (tx, ty),
                    (bx - math.cos(side) * 6, by - math.sin(side) * 6)],
             (110, 158, 100, 255))
    ellipse(draw, (52, 22, 76, 46), (150, 190, 130, 255))


def tower_regen(draw):
    tower(draw)
    poly(draw, [(64, 22), (74, 12), (86, 14), (90, 26), (64, 52),
                (38, 26), (42, 14), (54, 12)], BLOOD)
    ellipse(draw, (54, 20, 64, 30), (255, 150, 168, 255))


def tower_overload(draw):
    tower(draw)
    poly(draw, [(64, 4), (86, 30), (72, 30), (72, 40), (56, 40), (56, 30), (42, 30)], GOLD)
    poly(draw, [(58, 30), (48, 44), (56, 44), (52, 60), (72, 40), (64, 40), (68, 30)],
         (255, 138, 60, 255))


# ---------------------------------------------------------------- deck rewards

def deck_boost(draw):
    card(draw, (30, 34, 74, 96), (108, 152, 214, 255))
    card(draw, (44, 22, 88, 84), (140, 180, 236, 255))
    up_arrow(draw, 66, 30, 76, half=15, stem=8, fill=GOLD)


def deck_remove(draw):
    card(draw, (36, 24, 92, 104), (150, 120, 110, 255))
    line(draw, [(46, 38), (82, 90)], BLOOD, 6)
    line(draw, [(82, 38), (46, 90)], BLOOD, 6)


def deck_elite(draw):
    poly(draw, [(28, 84), (28, 44), (44, 62), (64, 30), (84, 62), (100, 44),
                (100, 84)], GOLD)
    poly(draw, [(28, 84), (100, 84), (100, 100), (28, 100)], GOLD_DARK)
    for x in (40, 64, 88):
        ellipse(draw, (x - 5, 68, x + 5, 78), BLOOD)


def effect_harvest(draw):
    card(draw, (24, 30, 60, 104), PURPLE)
    card(draw, (54, 22, 96, 100), (176, 140, 232, 255))
    poly(draw, star(75, 60, 16, 7, 5), GOLD)


def deck_purge(draw):
    ellipse(draw, (36, 30, 92, 86), (232, 240, 250, 255))
    ellipse(draw, (48, 42, 80, 74), (150, 200, 236, 255))
    for angle_deg in range(0, 360, 60):
        angle = math.radians(angle_deg)
        cx, cy = 64 + math.cos(angle) * 44, 58 + math.sin(angle) * 44
        poly(draw, star(cx, cy, 7, 3, 4, rotation=angle_deg), GOLD)


# ---------------------------------------------------------------- utility rewards

def free_reshuffle(draw):
    for flip in (False, True):
        pts = [(30, 46), (54, 46), (54, 36), (74, 56), (54, 76), (54, 66), (30, 66)]
        if flip:
            pts = [(128 - x, 118 - y) for x, y in pts]
        poly(draw, pts, CYAN)


def bloodline(draw):
    poly(draw, [(64, 14), (86, 44), (90, 74), (64, 100), (38, 74), (42, 44)], BLOOD)
    ellipse(draw, (52, 40, 68, 56), (255, 150, 168, 255))
    up_arrow(draw, 64, 56, 92, half=11, stem=6, fill=(255, 236, 176, 255))


def tray_expand(draw):
    for row in range(2):
        for col in range(2):
            card(draw, (30 + col * 30, 30 + row * 30, 54 + col * 30, 54 + row * 30),
                 (200, 170, 128, 255))
    up_arrow(draw, 94, 60, 92, half=13, stem=7, fill=GREEN)
    line(draw, [(84, 100), (104, 100)], GREEN, 6)
    line(draw, [(94, 90), (94, 110)], GREEN, 6)


def free_clear(draw):
    poly(draw, [(20, 40), (108, 40), (108, 88), (20, 88)], GOLD)
    poly(draw, [(20, 40), (108, 40), (108, 88), (20, 88)], None, outline=(238, 176, 60, 255), width=2 * SCALE)
    for y in (40, 88):
        for x in range(28, 108, 12):
            ellipse(draw, (x - 3, y - 3, x + 3, y + 3), (0, 0, 0, 0))
    line(draw, [(64, 40), (64, 88)], (238, 176, 60, 255), 2)
    poly(draw, star(44, 64, 9, 4, 5), (255, 236, 176, 255))
    line(draw, [(78, 58), (96, 58)], (238, 176, 60, 255), 3)
    line(draw, [(78, 70), (96, 70)], (238, 176, 60, 255), 3)


def coin_bag(draw):
    poly(draw, [(40, 40), (88, 40), (104, 108), (24, 108)], (150, 108, 66, 255))
    poly(draw, [(44, 30), (84, 30), (88, 42), (40, 42)], (120, 84, 50, 255))
    ellipse(draw, (50, 62, 78, 90), GOLD)
    line(draw, [(64, 68), (64, 84)], GOLD_DARK, 3)
    line(draw, [(58, 72), (70, 72)], GOLD_DARK, 3)
    line(draw, [(58, 80), (70, 80)], GOLD_DARK, 3)


def loot_boost(draw):
    ellipse(draw, (28, 52, 76, 100), GOLD)
    ellipse(draw, (36, 60, 68, 92), GOLD_DARK)
    poly(draw, star(52, 76, 12, 5, 5), (255, 236, 176, 255))
    up_arrow(draw, 92, 20, 56, half=15, stem=8, fill=GREEN)


# ---------------------------------------------------------------- army buffs

def atk_up(draw):
    poly(draw, [(58, 8), (70, 8), (70, 74), (58, 74)], BLADE)
    poly(draw, [(58, 8), (70, 8), (64, 2)], BLADE_DARK)
    poly(draw, [(44, 74), (84, 74), (84, 84), (44, 84)], (150, 108, 66, 255))
    poly(draw, [(60, 84), (68, 84), (68, 108), (60, 108)], (120, 84, 50, 255))
    up_arrow(draw, 98, 60, 100, half=12, stem=6, fill=GREEN)


def hp_up(draw):
    poly(draw, [(58, 20), (80, 8), (100, 22), (100, 46), (58, 82), (16, 46), (16, 22),
                (36, 8)], BLOOD)
    ellipse(draw, (34, 26, 54, 46), (255, 150, 168, 255))
    up_arrow(draw, 58, 40, 74, half=11, stem=6, fill=(255, 236, 176, 255))


def aspd_up(draw):
    for flip in (False, True):
        pts = [(24, 12), (36, 12), (76, 84), (86, 78), (86, 100), (64, 100),
               (72, 92), (28, 20)]
        if flip:
            pts = [(128 - x, y) for x, y in pts]
        poly(draw, pts, BLADE)
    line(draw, [(96, 20), (110, 20)], CYAN, 3)
    line(draw, [(98, 32), (112, 32)], CYAN, 3)


def move_up(draw):
    poly(draw, [(40, 60), (72, 60), (78, 74), (88, 74), (94, 90), (94, 104),
                (34, 104), (30, 78)], (150, 108, 66, 255))
    poly(draw, [(40, 60), (58, 60), (58, 78), (36, 78)], (120, 84, 50, 255))
    for i, y in enumerate((44, 56, 68)):
        line(draw, [(6 + i * 4, y), (28 + i * 4, y)], CYAN, 4)


def crit(draw):
    ellipse(draw, (24, 24, 104, 104), BLOOD)
    ellipse(draw, (38, 38, 90, 90), (245, 240, 232, 255))
    ellipse(draw, (52, 52, 76, 76), BLOOD)
    for angle_deg in range(0, 360, 90):
        angle = math.radians(angle_deg)
        line(draw, [(64 + math.cos(angle) * 12, 64 + math.sin(angle) * 12),
                    (64 + math.cos(angle) * 46, 64 + math.sin(angle) * 46)], OUTLINE[:3] + (255,), 3)


def lifesteal(draw):
    poly(draw, [(20, 20), (54, 20), (54, 60), (48, 96), (26, 96), (20, 60)], PURPLE)
    poly(draw, [(64, 30), (84, 58), (88, 82), (64, 104), (40, 82)], BLOOD)
    ellipse(draw, (56, 54, 72, 70), (255, 150, 168, 255))


def tank_guard(draw):
    poly(draw, [(64, 10), (104, 26), (104, 62), (64, 112), (24, 62), (24, 26)], SHIELD)
    poly(draw, [(64, 24), (90, 34), (90, 58), (64, 94), (38, 58), (38, 34)], SHIELD_LIGHT)
    poly(draw, [(56, 44), (72, 44), (72, 56), (84, 56), (64, 82), (44, 56), (56, 56)],
         SHIELD)


def ranged_up(draw):
    draw.arc((30 * SCALE, 24 * SCALE, 74 * SCALE, 104 * SCALE), start=-70, end=70,
             fill=(120, 84, 50, 255), width=6 * SCALE)
    line(draw, [(38, 34), (38, 94)], (198, 168, 132, 255), 2)
    line(draw, [(30, 64), (100, 64)], (198, 168, 132, 255), 3)
    poly(draw, [(100, 64), (86, 58), (86, 70)], BLADE)
    line(draw, [(58, 64), (86, 64)], BLADE_DARK, 3)


def assassin_crit(draw):
    poly(draw, [(46, 10), (58, 10), (54, 74), (50, 74)], BLADE)
    poly(draw, [(46, 10), (58, 10), (52, 4)], BLADE_DARK)
    poly(draw, [(38, 74), (66, 74), (62, 84), (42, 84)], (120, 84, 50, 255))
    line(draw, [(52, 84), (52, 104)], (90, 62, 40, 255), 4)
    poly(draw, star(90, 40, 12, 5, 4), BLOOD)


def energy_start(draw):
    poly(draw, [(48, 30), (80, 30), (80, 24), (88, 24), (88, 36), (80, 36),
                (80, 108), (48, 108), (48, 36), (40, 36), (40, 24), (48, 24)],
         (90, 90, 100, 255))
    poly(draw, [(70, 40), (50, 72), (62, 72), (56, 100), (78, 64), (66, 64)],
         GOLD)


def stun_boost(draw):
    ellipse(draw, (40, 46, 88, 82), (245, 240, 232, 255))
    for angle_deg, r in ((-90, 40), (-30, 44), (30, 44), (90, 40), (150, 44), (210, 44)):
        angle = math.radians(angle_deg)
        cx, cy = 64 + math.cos(angle) * r, 40 + math.sin(angle) * r * 0.7
        poly(draw, star(cx, cy, 10, 4, 5, rotation=angle_deg), GOLD)


def call_reinforce(draw):
    line(draw, [(30, 14), (30, 112)], (120, 84, 50, 255), 5)
    poly(draw, [(30, 16), (100, 26), (84, 40), (100, 54), (30, 44)], BLOOD)
    poly(draw, star(52, 32, 7, 3, 5), (255, 236, 176, 255))
    ellipse(draw, (54, 82, 74, 102), SHIELD_LIGHT)
    ellipse(draw, (78, 88, 94, 104), SHIELD)
    ellipse(draw, (36, 88, 52, 104), SHIELD)


ICONS = {
    "tower_wall": tower_wall,
    "tower_repair": tower_repair,
    "tower_cannon": tower_cannon,
    "tower_thorns": tower_thorns,
    "tower_regen": tower_regen,
    "tower_overload": tower_overload,
    "deck_boost": deck_boost,
    "deck_remove": deck_remove,
    "deck_elite": deck_elite,
    "effect_harvest": effect_harvest,
    "deck_purge": deck_purge,
    "free_reshuffle": free_reshuffle,
    "bloodline": bloodline,
    "tray_expand": tray_expand,
    "free_clear": free_clear,
    "coin_bag": coin_bag,
    "loot_boost": loot_boost,
    "atk_up": atk_up,
    "hp_up": hp_up,
    "aspd_up": aspd_up,
    "move_up": move_up,
    "crit": crit,
    "lifesteal": lifesteal,
    "tank_guard": tank_guard,
    "ranged_up": ranged_up,
    "assassin_crit": assassin_crit,
    "energy_start": energy_start,
    "stun_boost": stun_boost,
    "call_reinforce": call_reinforce,
}


def assert_transparent_corners(image):
    width, height = image.size
    for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        if image.getpixel((x, y))[3] != 0:
            raise AssertionError("corner (%d,%d) is not transparent" % (x, y))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, painter in ICONS.items():
        canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        painter(ImageDraw.Draw(canvas))
        icon = canvas.resize((SIZE, SIZE), Image.LANCZOS)
        assert_transparent_corners(icon)
        path = os.path.join(OUT_DIR, name + ".png")
        icon.save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
