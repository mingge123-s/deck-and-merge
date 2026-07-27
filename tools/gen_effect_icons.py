#!/usr/bin/env python3
"""Generate the 64x64 transparent buff icons for the shop random effects.

Each icon is drawn at 4x with a dark outline + flat fills (matching the
game's chunky cartoon art), then downscaled. Run from the repo root:

    python3 tools/gen_effect_icons.py
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "icons", "effects")
SIZE = 64
SCALE = 4
S = SIZE * SCALE
OUTLINE = (43, 26, 18, 255)
STROKE = 3 * SCALE


def poly(draw, points, fill):
    draw.polygon([(x * SCALE, y * SCALE) for x, y in points], fill=fill, outline=OUTLINE, width=STROKE)


def line(draw, points, fill, width=5):
    draw.line([(x * SCALE, y * SCALE) for x, y in points], fill=fill, width=width * SCALE, joint="curve")


def ellipse(draw, box, fill):
    x0, y0, x1, y1 = [v * SCALE for v in box]
    draw.ellipse((x0, y0, x1, y1), fill=fill, outline=OUTLINE, width=STROKE)


def star(cx, cy, outer, inner, points=6, rotation=-90.0):
    result = []
    for index in range(points * 2):
        radius = outer if index % 2 == 0 else inner
        angle = math.radians(rotation + index * 180.0 / points)
        result.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return result


def boss_call(draw):
    # skull with a summoning arc
    ellipse(draw, (14, 12, 50, 44), (238, 232, 214, 255))
    poly(draw, [(22, 40), (42, 40), (39, 54), (25, 54)], (238, 232, 214, 255))
    ellipse(draw, (21, 22, 30, 33), OUTLINE)
    ellipse(draw, (34, 22, 43, 33), OUTLINE)
    line(draw, [(28, 46), (28, 52)], OUTLINE, 2)
    line(draw, [(36, 46), (36, 52)], OUTLINE, 2)


def field_aid(draw):
    poly(draw, [(26, 8), (38, 8), (38, 25), (55, 25), (55, 39), (38, 39),
                (38, 56), (26, 56), (26, 39), (9, 39), (9, 25), (26, 25)],
         (126, 214, 126, 255))


def freeze(draw):
    for index in range(3):
        angle = math.radians(90 + index * 60)
        dx, dy = math.cos(angle) * 24, math.sin(angle) * 24
        line(draw, [(32 - dx, 32 - dy), (32 + dx, 32 + dy)], (46, 120, 156, 255), 6)
    for index in range(3):
        angle = math.radians(90 + index * 60)
        dx, dy = math.cos(angle) * 24, math.sin(angle) * 24
        line(draw, [(32 - dx, 32 - dy), (32 + dx, 32 + dy)], (185, 232, 252, 255), 3)
    for index in range(6):
        angle = math.radians(index * 60)
        bx, by = 32 + math.cos(angle) * 15, 32 + math.sin(angle) * 15
        for side in (-32, 32):
            branch = math.radians(index * 60 + side)
            line(draw, [(bx, by), (bx + math.cos(branch) * 8, by + math.sin(branch) * 8)],
                 (185, 232, 252, 255), 3)


def frenzy(draw):
    # curved war horn, narrow tip bottom-left, flared mouth top-right
    upper = [(10, 46), (12, 32), (20, 20), (32, 12), (46, 8), (52, 6)]
    lower = [(56, 24), (46, 24), (34, 28), (24, 36), (18, 46), (16, 52)]
    poly(draw, upper + lower, (232, 156, 66, 255))
    poly(draw, [(52, 6), (58, 10), (56, 24), (46, 24), (46, 8)], (176, 96, 40, 255))
    line(draw, [(22, 40), (34, 26)], (255, 214, 140, 255), 2)


def morale(draw):
    line(draw, [(16, 8), (16, 58)], (120, 76, 44, 255), 4)
    poly(draw, [(16, 10), (52, 18), (40, 26), (52, 34), (16, 30)],
         (226, 78, 66, 255))
    poly(draw, star(30, 22, 7, 3, 5), (255, 214, 110, 255))


def bulwark(draw):
    poly(draw, [(32, 6), (54, 14), (54, 34), (32, 58), (10, 34), (10, 14)],
         (128, 158, 192, 255))
    poly(draw, [(32, 14), (46, 19), (46, 33), (32, 48), (18, 33), (18, 19)],
         (196, 216, 238, 255))


def haste(draw):
    poly(draw, [(38, 6), (18, 34), (30, 34), (24, 58), (46, 28), (34, 28)],
         (120, 224, 236, 255))
    line(draw, [(6, 18), (18, 18)], (120, 224, 236, 255), 3)
    line(draw, [(4, 30), (14, 30)], (120, 224, 236, 255), 3)
    line(draw, [(8, 42), (18, 42)], (120, 224, 236, 255), 3)


def lifesteal(draw):
    # totem post with a blood drop
    poly(draw, [(20, 20), (44, 20), (44, 58), (20, 58)], (140, 84, 156, 255))
    poly(draw, [(14, 12), (50, 12), (44, 20), (20, 20)], (108, 60, 124, 255))
    poly(draw, [(32, 26), (42, 40), (38, 50), (26, 50), (22, 40)],
         (222, 66, 92, 255))
    ellipse(draw, (27, 40, 37, 50), (255, 150, 168, 255))


def thorns(draw):
    poly(draw, [(32, 8), (52, 16), (52, 34), (32, 56), (12, 34), (12, 16)],
         (110, 158, 100, 255))
    for angle_deg in range(0, 360, 60):
        angle = math.radians(angle_deg - 90)
        bx, by = 32 + math.cos(angle) * 12, 32 + math.sin(angle) * 12
        tx, ty = 32 + math.cos(angle) * 26, 32 + math.sin(angle) * 26
        side = math.radians(angle_deg)
        poly(draw, [(bx + math.cos(side) * 5, by + math.sin(side) * 5),
                    (tx, ty),
                    (bx - math.cos(side) * 5, by - math.sin(side) * 5)],
             (232, 236, 214, 255))


def tower_repair(draw):
    poly(draw, [(20, 22), (44, 22), (41, 58), (23, 58)], (198, 168, 132, 255))
    poly(draw, [(16, 10), (24, 10), (24, 16), (30, 16), (30, 10), (38, 10),
                (38, 16), (44, 16), (48, 10), (48, 22), (16, 22)],
         (170, 138, 102, 255))
    poly(draw, [(27, 30), (37, 30), (37, 42), (43, 42), (32, 56), (21, 42), (27, 42)],
         (126, 214, 126, 255))


def tower_power(draw):
    poly(draw, [(20, 34), (44, 34), (41, 58), (23, 58)], (198, 168, 132, 255))
    poly(draw, [(16, 22), (24, 22), (24, 28), (30, 28), (30, 22), (38, 22),
                (38, 28), (44, 28), (44, 22), (48, 22), (48, 34), (16, 34)],
         (170, 138, 102, 255))
    poly(draw, [(32, 1), (48, 17), (39, 17), (39, 26), (25, 26), (25, 17), (16, 17)],
         (255, 206, 92, 255))


def bounty(draw):
    ellipse(draw, (8, 8, 56, 56), (255, 206, 92, 255))
    ellipse(draw, (15, 15, 49, 49), (238, 176, 60, 255))
    poly(draw, star(32, 32, 15, 6, 5), (255, 236, 176, 255))


ICONS = {
    "boss_call": boss_call,
    "field_aid": field_aid,
    "freeze": freeze,
    "frenzy": frenzy,
    "morale": morale,
    "bulwark": bulwark,
    "haste": haste,
    "lifesteal": lifesteal,
    "thorns": thorns,
    "tower_repair": tower_repair,
    "tower_power": tower_power,
    "bounty": bounty,
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
