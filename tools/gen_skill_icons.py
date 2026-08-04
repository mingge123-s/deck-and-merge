#!/usr/bin/env python3
"""Generate the 64x64 transparent skill icons for the era hero skills.

Same chunky cartoon look as tools/gen_effect_icons.py: drawn at 4x with a
dark outline + flat fills, then downscaled. Run from the repo root:

    python3 tools/gen_skill_icons.py
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "icons", "skills")
SIZE = 64
SCALE = 4
S = SIZE * SCALE
OUTLINE = (43, 26, 18, 255)
STROKE = 3 * SCALE


def poly(draw, points, fill, outline=OUTLINE):
    draw.polygon([(x * SCALE, y * SCALE) for x, y in points], fill=fill, outline=outline, width=STROKE)


def line(draw, points, fill, width=5):
    draw.line([(x * SCALE, y * SCALE) for x, y in points], fill=fill, width=width * SCALE, joint="curve")


def ellipse(draw, box, fill, outline=OUTLINE):
    x0, y0, x1, y1 = [v * SCALE for v in box]
    draw.ellipse((x0, y0, x1, y1), fill=fill, outline=outline, width=STROKE)


def arc(draw, box, start, end, fill, width=4):
    x0, y0, x1, y1 = [v * SCALE for v in box]
    draw.arc((x0, y0, x1, y1), start, end, fill=fill, width=width * SCALE)


def star(cx, cy, outer, inner, points=6, rotation=-90.0):
    result = []
    for index in range(points * 2):
        radius = outer if index % 2 == 0 else inner
        angle = math.radians(rotation + index * 180.0 / points)
        result.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return result


def fan(cx, cy, radius, half_angle_deg, direction_deg=0.0, steps=10):
    result = [(cx, cy)]
    for index in range(steps + 1):
        angle = math.radians(
            direction_deg - half_angle_deg + 2.0 * half_angle_deg * index / steps
        )
        result.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    return result


# --- 工业时代 ------------------------------------------------------------


def overpressure_steam(draw):
    # riveted tower shield venting steam
    poly(draw, [(22, 12), (46, 12), (46, 38), (34, 56), (22, 38)], (176, 138, 76, 255))
    poly(draw, [(28, 20), (40, 20), (40, 36), (34, 46), (28, 36)], (226, 196, 128, 255))
    for cx, cy in ((25, 16), (43, 16), (25, 36), (43, 36)):
        ellipse(draw, (cx - 2, cy - 2, cx + 2, cy + 2), (120, 90, 48, 255), None)
    ellipse(draw, (4, 10, 20, 26), (232, 238, 240, 255))
    ellipse(draw, (8, 26, 20, 38), (206, 216, 220, 255))


def piston_charge(draw):
    # mechanical fist punching right with speed lines
    poly(draw, [(26, 18), (48, 18), (52, 26), (52, 40), (48, 48), (26, 48)],
         (206, 140, 62, 255))
    poly(draw, [(38, 24), (50, 24), (50, 42), (38, 42)], (240, 196, 110, 255))
    poly(draw, [(18, 24), (28, 24), (28, 42), (18, 42)], (150, 100, 44, 255))
    for cy in (26, 33, 40):
        ellipse(draw, (44, cy - 3, 50, cy + 3), (176, 118, 50, 255), None)
    line(draw, [(2, 22), (14, 22)], (240, 214, 150, 255), 3)
    line(draw, [(2, 33), (12, 33)], (240, 214, 150, 255), 3)
    line(draw, [(2, 44), (14, 44)], (240, 214, 150, 255), 3)


def smoke_raid(draw):
    # dagger wrapped in a smoke cloud
    ellipse(draw, (6, 30, 34, 54), (198, 204, 201, 255))
    ellipse(draw, (24, 24, 54, 50), (176, 184, 182, 255))
    poly(draw, [(44, 6), (52, 12), (30, 40), (24, 36)], (222, 230, 236, 255))
    poly(draw, [(24, 36), (30, 40), (22, 50), (18, 44)], (140, 100, 60, 255))


def shotgun_blast(draw):
    # blunderbuss muzzle with a spreading pellet fan
    poly(draw, fan(12, 32, 46, 30.0, 0.0), (240, 196, 110, 255))
    for angle_deg in (-22, -8, 8, 22):
        angle = math.radians(angle_deg)
        px, py = 12 + math.cos(angle) * 40, 32 + math.sin(angle) * 40
        ellipse(draw, (px - 4, py - 4, px + 4, py + 4), (96, 78, 58, 255))
    poly(draw, [(2, 26), (16, 26), (16, 38), (2, 38)], (128, 92, 48, 255))


def overpressure_burst(draw):
    # boiler exploding outwards
    poly(draw, star(32, 32, 30, 14, 8), (244, 168, 74, 255))
    ellipse(draw, (18, 18, 46, 46), (252, 220, 138, 255))
    poly(draw, [(28, 24), (36, 24), (36, 32), (42, 32), (30, 46), (30, 36), (24, 36)],
         (176, 96, 40, 255))


# --- 现代 ----------------------------------------------------------------


def shield_wall(draw):
    # riot shield row
    poly(draw, [(6, 16), (26, 16), (26, 44), (16, 54), (6, 44)], (74, 104, 152, 255))
    poly(draw, [(38, 16), (58, 16), (58, 44), (48, 54), (38, 44)], (74, 104, 152, 255))
    poly(draw, [(22, 10), (42, 10), (42, 40), (32, 52), (22, 40)], (146, 182, 226, 255))
    line(draw, [(26, 22), (38, 22)], (240, 248, 255, 255), 3)


def suppress_fire(draw):
    # assault rifle silhouette with tracer bursts
    poly(draw, [(6, 26), (44, 26), (44, 34), (6, 34)], (72, 76, 70, 255))
    poly(draw, [(16, 34), (24, 34), (20, 50), (12, 50)], (56, 60, 56, 255))
    poly(draw, [(28, 34), (36, 34), (36, 44), (28, 44)], (56, 60, 56, 255))
    poly(draw, [(44, 24), (58, 30), (44, 36)], (252, 214, 120, 255))
    line(draw, [(46, 12), (58, 16)], (252, 214, 120, 255), 3)
    line(draw, [(46, 50), (58, 46)], (252, 214, 120, 255), 3)


def decap_strike(draw):
    # combat knife lunging with a crosshair
    poly(draw, [(10, 50), (18, 42), (46, 12), (52, 18), (22, 46), (14, 54)],
         (214, 222, 228, 255))
    poly(draw, [(10, 50), (16, 44), (22, 50), (16, 56)], (60, 62, 66, 255))
    ellipse(draw, (36, 6, 60, 30), (0, 0, 0, 0))
    line(draw, [(48, 2), (48, 12)], (226, 92, 76, 255), 3)
    line(draw, [(48, 24), (48, 34)], (226, 92, 76, 255), 3)
    line(draw, [(34, 18), (44, 18)], (226, 92, 76, 255), 3)
    line(draw, [(52, 18), (62, 18)], (226, 92, 76, 255), 3)


def lethal_snipe(draw):
    # scope reticle with a piercing shot line
    ellipse(draw, (10, 10, 54, 54), (226, 236, 240, 255))
    ellipse(draw, (18, 18, 46, 46), (86, 104, 92, 255))
    line(draw, [(32, 12), (32, 52)], (240, 248, 250, 255), 2)
    line(draw, [(12, 32), (52, 32)], (240, 248, 250, 255), 2)
    ellipse(draw, (28, 28, 36, 36), (226, 92, 76, 255), None)


def artillery_support(draw):
    # falling shell over a target circle
    ellipse(draw, (8, 40, 56, 60), (0, 0, 0, 0), (226, 118, 76, 255))
    poly(draw, [(32, 4), (40, 14), (40, 34), (24, 34), (24, 14)], (108, 116, 92, 255))
    poly(draw, [(24, 34), (40, 34), (36, 44), (28, 44)], (176, 148, 84, 255))
    line(draw, [(14, 12), (20, 20)], (252, 214, 120, 255), 3)
    line(draw, [(50, 12), (44, 20)], (252, 214, 120, 255), 3)


# --- 未来 ----------------------------------------------------------------


def force_field(draw):
    # hexagonal energy shield with an inner core
    poly(draw, [(32, 4), (56, 18), (56, 46), (32, 60), (8, 46), (8, 18)],
         (110, 214, 238, 255))
    poly(draw, [(32, 16), (46, 24), (46, 40), (32, 48), (18, 40), (18, 24)],
         (206, 244, 252, 255))
    poly(draw, star(32, 32, 10, 4, 6), (58, 160, 216, 255))


def laser_slash(draw):
    # sweeping laser arc plus blade
    poly(draw, fan(8, 46, 52, 26.0, -34.0), (110, 208, 255, 255))
    poly(draw, [(18, 50), (44, 12), (50, 18), (24, 56)], (232, 248, 255, 255))
    poly(draw, [(14, 54), (20, 48), (26, 54), (20, 60)], (58, 106, 156, 255))


def phase_execute(draw):
    # phasing ninja blade with afterimage
    poly(draw, [(16, 52), (44, 10), (50, 16), (22, 58)], (212, 168, 255, 255))
    poly(draw, [(8, 48), (30, 16), (34, 20), (12, 52)], (160, 116, 216, 120), None)
    poly(draw, [(12, 56), (18, 50), (24, 56), (18, 62)], (74, 48, 108, 255))
    line(draw, [(44, 8), (56, 4)], (238, 214, 255, 255), 3)


def plasma_lance(draw):
    # charged plasma beam piercing right
    poly(draw, [(4, 26), (46, 26), (46, 38), (4, 38)], (78, 224, 138, 255))
    poly(draw, [(46, 20), (62, 32), (46, 44)], (198, 252, 214, 255))
    ellipse(draw, (2, 22, 22, 42), (36, 168, 96, 255))
    line(draw, [(10, 12), (24, 20)], (198, 252, 214, 255), 3)
    line(draw, [(10, 52), (24, 44)], (198, 252, 214, 255), 3)


def overload_barrage(draw):
    # mech shoulder cannon barrage with EMP ring
    poly(draw, [(8, 20), (34, 20), (34, 32), (8, 32)], (196, 74, 96, 255))
    poly(draw, [(8, 36), (34, 36), (34, 48), (8, 48)], (196, 74, 96, 255))
    poly(draw, [(34, 22), (44, 26), (34, 30)], (252, 214, 120, 255))
    poly(draw, [(34, 38), (44, 42), (34, 46)], (252, 214, 120, 255))
    arc(draw, (34, 8, 62, 56), -70, 70, (126, 232, 255, 255), 4)
    arc(draw, (42, 18, 60, 46), -70, 70, (198, 246, 255, 255), 3)


ICONS = {
    "overpressure_steam": overpressure_steam,
    "piston_charge": piston_charge,
    "smoke_raid": smoke_raid,
    "shotgun_blast": shotgun_blast,
    "overpressure_burst": overpressure_burst,
    "shield_wall": shield_wall,
    "suppress_fire": suppress_fire,
    "decap_strike": decap_strike,
    "lethal_snipe": lethal_snipe,
    "artillery_support": artillery_support,
    "force_field": force_field,
    "laser_slash": laser_slash,
    "phase_execute": phase_execute,
    "plasma_lance": plasma_lance,
    "overload_barrage": overload_barrage,
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
