#!/usr/bin/env python3
"""Convert a flat green chroma master sheet to real alpha.

Companion to clean_generated_strip.py (which handles baked checkerboards).
Only edge-connected strong-green pixels are removed, then a bounded fringe
pass clears the soft green halo without eating green costume pixels that are
enclosed by the sprite (druid leaves, gem glints, etc.). A final despill pass
tames residual green edging on kept boundary pixels.

Usage:
  python3 key_green_chroma.py --input ..._chroma.png --output ..._alpha.png
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


def _strong_green(rgb: np.ndarray) -> np.ndarray:
    r = rgb[:, :, 0].astype(int)
    g = rgb[:, :, 1].astype(int)
    b = rgb[:, :, 2].astype(int)
    return (g > 120) & (g > r + 50) & (g > b + 50)


def _soft_green(rgb: np.ndarray) -> np.ndarray:
    r = rgb[:, :, 0].astype(int)
    g = rgb[:, :, 1].astype(int)
    b = rgb[:, :, 2].astype(int)
    return (g > 80) & (g > r + 20) & (g > b + 20)


def _edge_connected(mask: np.ndarray) -> np.ndarray:
    height, width = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    queue: deque[int] = deque()

    def seed(y: int, x: int) -> None:
        if mask[y, x] and not seen[y, x]:
            seen[y, x] = True
            queue.append(y * width + x)

    for x in range(width):
        seed(0, x)
        seed(height - 1, x)
    for y in range(height):
        seed(y, 0)
        seed(y, width - 1)

    while queue:
        index = queue.popleft()
        y, x = divmod(index, width)
        if x > 0:
            seed(y, x - 1)
        if x + 1 < width:
            seed(y, x + 1)
        if y > 0:
            seed(y - 1, x)
        if y + 1 < height:
            seed(y + 1, x)
    return seen


def _grow_fringe(background: np.ndarray, fringe: np.ndarray, passes: int) -> np.ndarray:
    for _ in range(passes):
        adjacent = np.zeros_like(background)
        adjacent[1:] |= background[:-1]
        adjacent[:-1] |= background[1:]
        adjacent[:, 1:] |= background[:, :-1]
        adjacent[:, :-1] |= background[:, 1:]
        added = fringe & adjacent & ~background
        if not added.any():
            break
        background |= added
    return background


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--fringe-passes", type=int, default=6)
    parser.add_argument("--key-enclosed", action="store_true",
                        help="also key strong-green pockets fully enclosed by the "
                             "sprite (safe only when the costume has no flat green)")
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    pixels = np.asarray(image).copy()
    rgb = pixels[:, :, :3]

    strong = _strong_green(rgb)
    background = strong if args.key_enclosed else _edge_connected(strong)
    background = _grow_fringe(background, _soft_green(rgb), args.fringe_passes)
    pixels[:, :, 3] = np.where(background, 0, 255).astype(np.uint8)

    # despill: kept pixels bordering removed background lose excess green
    border = np.zeros_like(background)
    border[1:] |= background[:-1]
    border[:-1] |= background[1:]
    border[:, 1:] |= background[:, :-1]
    border[:, :-1] |= background[:, 1:]
    border &= ~background
    r = pixels[:, :, 0].astype(int)
    g = pixels[:, :, 1].astype(int)
    b = pixels[:, :, 2].astype(int)
    cap = np.maximum(r, b)
    spill = border & (g > cap)
    pixels[:, :, 1] = np.where(spill, cap, g).astype(np.uint8)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(pixels, "RGBA").save(output)
    removed = int(background.sum())
    print(f"keyed {args.input}: {removed} background px -> alpha")


if __name__ == "__main__":
    main()
