#!/usr/bin/env python3
"""Downscale built animation frames to a sane on-disk size.

In battle the units render ~100px tall, but AI frames are generated ~1200px
tall, bloating the exported pck. Each hero's 6 frames share one aligned canvas
and a meta.json {anchor,char_height,canvas}; scaling every frame AND the meta by
the same factor is render-invariant (BattleUnit derives anim.scale from
char_height, and offset from anchor). We cap canvas height at MAX_H.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

MAX_H = 420
FRAMES = ["idle", "walk_a", "walk_b", "atk_a", "atk_b", "die"]


def shrink(hero_dir: Path) -> None:
    meta_path = hero_dir / "meta.json"
    if not meta_path.exists():
        return
    meta = json.loads(meta_path.read_text())
    canvas_h = int(meta["canvas"][1])
    if canvas_h <= MAX_H:
        print(f"{hero_dir.name}: already {canvas_h}px, skip")
        return
    factor = MAX_H / canvas_h
    for name in FRAMES:
        p = hero_dir / f"{name}.png"
        if not p.exists():
            continue
        img = Image.open(p).convert("RGBA")
        new_size = (max(1, round(img.width * factor)), max(1, round(img.height * factor)))
        img.resize(new_size, Image.LANCZOS).save(p, "PNG", optimize=True)
    meta["anchor"] = [round(meta["anchor"][0] * factor), round(meta["anchor"][1] * factor)]
    meta["char_height"] = round(meta["char_height"] * factor)
    meta["canvas"] = [round(meta["canvas"][0] * factor), round(meta["canvas"][1] * factor)]
    meta_path.write_text(json.dumps(meta, indent=2))
    print(f"{hero_dir.name}: x{factor:.3f} -> canvas {meta['canvas']}")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    anim_root = root / "assets" / "anim"
    names = sys.argv[1:] or [p.name for p in sorted(anim_root.iterdir()) if p.is_dir()]
    for name in names:
        shrink(anim_root / name)


if __name__ == "__main__":
    main()
