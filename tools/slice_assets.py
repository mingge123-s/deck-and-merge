#!/usr/bin/env python3
"""Slice the generated art sheets into transparent, tightly-cropped sprites."""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path
from statistics import median

from PIL import Image, ImageOps


SHEETS = {
    "cards_sheet.png": ("cards", 4, 2, (
        "stone_axe", "club", "spear", "sling",
        "bone", "campfire", "gold", "pelt",
    )),
    "units_sheet.png": ("units", 3, 2, (
        "clubber", "shield", "spearman",
        "slinger", "shaman", "healer",
    )),
    "enemies_sheet.png": ("enemies", 3, 2, (
        "sabertooth", "mammoth", "bear",
        "raptor", "boar", "enemy_caveman",
    )),
}


def color_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def remove_connected_background(image: Image.Image, tolerance: float = 33.0) -> Image.Image:
    """Remove connected near-beige/near-white background, preserving artwork."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    sample_points = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    # A foreground element can touch one of the four corners. Median is robust
    # to that outlier; averaging it would shift the key and miss the whole bg.
    key = tuple(int(median(rgba.getpixel(p)[channel] for p in sample_points))
                for channel in range(3))

    def is_background(pixel: tuple[int, int, int, int]) -> bool:
        rgb = pixel[:3]
        spread = max(rgb) - min(rgb)
        return color_distance(rgb, key) <= tolerance or (
            min(rgb) >= 200 and spread <= 70
        )

    seen: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(1, height - 1):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        pixel = pixels[x, y]
        if not is_background(pixel):
            continue
        pixels[x, y] = (pixel[0], pixel[1], pixel[2], 0)
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    return rgba


def remove_enclosed_flat_white(
    image: Image.Image,
    min_pixels: int = 100,
    white_floor: int = 245,
    max_spread: int = 6,
    max_stddev: float = 4.0,
) -> Image.Image:
    """Remove flat neutral-white holes enclosed by line art.

    The regular border flood-fill cannot reach white areas inside closed
    outlines.  Restrict this pass to very flat, neutral white components so
    highlights and colored white artwork remain intact.
    """
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    rgb = [
        [
            (pixels[x, y][0], pixels[x, y][1], pixels[x, y][2])
            for x in range(width)
        ]
        for y in range(height)
    ]

    def is_flat_white(x: int, y: int) -> bool:
        red, green, blue = rgb[y][x]
        return min(red, green, blue) >= white_floor and max(red, green, blue) - min(red, green, blue) <= max_spread

    mask = [[is_flat_white(x, y) and pixels[x, y][3] > 0 for x in range(width)] for y in range(height)]
    seen: set[tuple[int, int]] = set()
    for start_y in range(height):
        for start_x in range(width):
            if not mask[start_y][start_x] or (start_x, start_y) in seen:
                continue
            queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
            seen.add((start_x, start_y))
            component: list[tuple[int, int]] = []
            touches_edge = False
            while queue:
                x, y = queue.popleft()
                component.append((x, y))
                if x in (0, width - 1) or y in (0, height - 1):
                    touches_edge = True
                for next_x, next_y in (
                    (x - 1, y),
                    (x + 1, y),
                    (x, y - 1),
                    (x, y + 1),
                ):
                    if (
                        0 <= next_x < width
                        and 0 <= next_y < height
                        and mask[next_y][next_x]
                        and (next_x, next_y) not in seen
                    ):
                        seen.add((next_x, next_y))
                        queue.append((next_x, next_y))
            if touches_edge or len(component) < min_pixels:
                continue
            values = [rgb[y][x] for x, y in component]
            mean = sum(sum(value) for value in values) / (3.0 * len(values))
            variance = sum(
                (channel - mean) ** 2
                for value in values
                for channel in value
            ) / (3.0 * len(values))
            if mean < white_floor or variance ** 0.5 > max_stddev:
                continue
            for x, y in component:
                red, green, blue, _alpha = pixels[x, y]
                pixels[x, y] = (red, green, blue, 0)
    # A one-pixel neutral-white fringe can remain where the source background
    # was antialiased against the cutout.  Only remove pixels directly beside
    # transparency; colored or shaded artwork does not satisfy the predicate.
    halo: list[tuple[int, int]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y][x] or pixels[x, y][3] == 0:
                continue
            if any(
                0 <= next_x < width
                and 0 <= next_y < height
                and pixels[next_x, next_y][3] == 0
                for next_x, next_y in (
                    (x - 1, y),
                    (x + 1, y),
                    (x, y - 1),
                    (x, y + 1),
                    (x - 1, y - 1),
                    (x + 1, y - 1),
                    (x - 1, y + 1),
                    (x + 1, y + 1),
                )
            ):
                halo.append((x, y))
    for x, y in halo:
        red, green, blue, _alpha = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)
    return rgba


def slice_sheet(source: Path, output_root: Path, tolerance: float) -> list[Path]:
    image = Image.open(source).convert("RGB")
    category, columns, rows, names = SHEETS[source.name]
    cell_width, cell_height = image.width // columns, image.height // rows
    output_dir = output_root / category
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []

    for index, name in enumerate(names):
        column, row = index % columns, index // columns
        cell = image.crop((
            column * cell_width, row * cell_height,
            (column + 1) * cell_width, (row + 1) * cell_height,
        ))
        transparent = remove_connected_background(cell, tolerance)
        alpha = transparent.getchannel("A")
        bbox = alpha.getbbox()
        if bbox is None:
            raise ValueError(f"{source.name} cell {name!r} contains no foreground")
        # A one-pixel transparent margin prevents edge antialiasing from being clipped.
        left = max(0, bbox[0] - 1)
        top = max(0, bbox[1] - 1)
        right = min(cell_width, bbox[2] + 1)
        bottom = min(cell_height, bbox[3] + 1)
        # Keep a transparent antialiasing margin even when artwork touches a
        # source-cell edge, guaranteeing transparent output corners.
        output = ImageOps.expand(
            transparent.crop((left, top, right, bottom)),
            border=1,
            fill=(0, 0, 0, 0),
        )
        destination = output_dir / f"{name}.png"
        output.save(destination, "PNG", optimize=True)
        written.append(destination)
    return written


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--art", type=Path, default=Path(__file__).parents[2] / "game_design" / "art")
    parser.add_argument("--output", type=Path, default=Path(__file__).parents[1] / "assets")
    parser.add_argument("--tolerance", type=float, default=33.0)
    parser.add_argument(
        "--anim",
        nargs="*",
        metavar="PATH",
        help="Clean existing animation PNGs in assets/anim (paths or role names).",
    )
    parser.add_argument("--min-enclosed-pixels", type=int, default=1000)
    args = parser.parse_args()

    if args.anim is not None:
        anim_root = args.output / "anim"
        requested = args.anim or [str(path) for path in sorted(anim_root.rglob("*.png"))]
        skipped_roles = {"fut_tank", "mod_tank"}
        for item in requested:
            path = Path(item)
            if not path.is_absolute():
                path = anim_root / path
            if path.is_dir():
                paths = sorted(path.glob("*.png"))
            else:
                paths = [path]
            for png_path in paths:
                if not png_path.exists() or png_path.parent.name in skipped_roles:
                    continue
                cleaned = remove_enclosed_flat_white(
                    Image.open(png_path),
                    min_pixels=args.min_enclosed_pixels,
                )
                cleaned.save(png_path, "PNG", optimize=True)
                print(png_path)
        return

    for filename in SHEETS:
        paths = slice_sheet(args.art / filename, args.output, args.tolerance)
        print(f"{filename}: {len(paths)} sprites")

    # Backgrounds (bg_board.png / bg_battle.png) are hand-authored empty scenes
    # that live in assets/. Do NOT regenerate them from the concept mockup here:
    # that image has baked-in cards/units/enemies and would clobber the clean
    # runtime backgrounds.


if __name__ == "__main__":
    main()
