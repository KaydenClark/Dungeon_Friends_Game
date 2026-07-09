"""Generate the first Batch D item/save icon sheet.

This deterministic generator covers the Phase 3 item ids and the first save
object visual. It keeps the source asset reproducible until hand-authored
Aseprite files replace it.

Run from game/:
  python assets/art/_scripts/generate_item_save_icons.py

Output:
  assets/art/icons/item_save_icons.png
"""

from __future__ import annotations

import os
import struct
import zlib
from pathlib import Path


TILE = 16
COLS = 4
ROWS = 2
OUT_PATH = Path("assets/art/icons/item_save_icons.png")

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (29, 30, 36, 255)
SHADOW = (36, 38, 47, 180)
GOLD = (238, 185, 68, 255)
GOLD_DARK = (162, 106, 35, 255)
GOLD_LIGHT = (255, 225, 105, 255)
SILVER = (179, 189, 194, 255)
SILVER_DARK = (91, 103, 112, 255)
SILVER_LIGHT = (229, 237, 238, 255)
GREEN = (72, 172, 79, 255)
GREEN_DARK = (43, 104, 54, 255)
BLUE = (84, 168, 232, 255)
BLUE_DARK = (47, 88, 158, 255)
CRYSTAL = (93, 220, 217, 255)
CRYSTAL_DARK = (45, 125, 151, 255)
CRYSTAL_LIGHT = (211, 255, 245, 255)
WOOD = (143, 86, 46, 255)
WOOD_DARK = (85, 50, 31, 255)
PARCHMENT = (229, 201, 139, 255)
PARCHMENT_DARK = (173, 130, 71, 255)


def main() -> None:
    img = _new_image(COLS * TILE, ROWS * TILE, TRANSPARENT)
    icons = [
        _forest_key,
        _dungeon_key,
        _shield,
        _save_crystal,
        _inventory_slot_empty,
        _inventory_slot_selected,
        _continue_prompt_badge,
        _new_game_prompt_badge,
    ]
    for index, drawer in enumerate(icons):
        drawer(img, (index % COLS) * TILE, (index // COLS) * TILE)
    _write_png(OUT_PATH, img)
    print(f"wrote {OUT_PATH}")


def _new_image(width: int, height: int, color: tuple[int, int, int, int]) -> list[list[tuple[int, int, int, int]]]:
    return [[color for _ in range(width)] for _ in range(height)]


def _set(img: list[list[tuple[int, int, int, int]]], x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = color


def _rect(img, x: int, y: int, w: int, h: int, color) -> None:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            _set(img, xx, yy, color)


def _circle(img, cx: float, cy: float, radius: float, color) -> None:
    r2 = radius * radius
    for y in range(int(cy - radius - 1), int(cy + radius + 2)):
        for x in range(int(cx - radius - 1), int(cx + radius + 2)):
            if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2:
                _set(img, x, y, color)


def _diamond(img, cx: int, cy: int, radius: int, color) -> None:
    for y in range(cy - radius, cy + radius + 1):
        for x in range(cx - radius, cx + radius + 1):
            if abs(x - cx) + abs(y - cy) <= radius:
                _set(img, x, y, color)


def _forest_key(img, ox: int, oy: int) -> None:
    _rect(img, ox + 4, oy + 12, 9, 2, SHADOW)
    _circle(img, ox + 5.5, oy + 6.5, 3.5, OUTLINE)
    _circle(img, ox + 5.5, oy + 6.5, 2.4, GOLD)
    _circle(img, ox + 5.5, oy + 6.5, 1.1, TRANSPARENT)
    _rect(img, ox + 8, oy + 6, 6, 3, OUTLINE)
    _rect(img, ox + 8, oy + 7, 5, 1, GOLD)
    _rect(img, ox + 11, oy + 8, 2, 3, OUTLINE)
    _rect(img, ox + 12, oy + 8, 1, 2, GOLD_DARK)
    _rect(img, ox + 10, oy + 5, 1, 1, GREEN)
    _set(img, ox + 4, oy + 4, GOLD_LIGHT)


def _dungeon_key(img, ox: int, oy: int) -> None:
    _rect(img, ox + 3, oy + 12, 10, 2, SHADOW)
    _circle(img, ox + 5.5, oy + 6.5, 3.5, OUTLINE)
    _circle(img, ox + 5.5, oy + 6.5, 2.4, SILVER)
    _circle(img, ox + 5.5, oy + 6.5, 1.1, TRANSPARENT)
    _rect(img, ox + 8, oy + 6, 6, 3, OUTLINE)
    _rect(img, ox + 8, oy + 7, 5, 1, SILVER)
    _rect(img, ox + 11, oy + 8, 1, 3, OUTLINE)
    _rect(img, ox + 13, oy + 8, 1, 3, OUTLINE)
    _rect(img, ox + 12, oy + 8, 1, 2, SILVER_DARK)
    _rect(img, ox + 9, oy + 5, 2, 1, BLUE)
    _set(img, ox + 4, oy + 4, SILVER_LIGHT)


def _shield(img, ox: int, oy: int) -> None:
    _rect(img, ox + 3, oy + 13, 10, 2, SHADOW)
    _rect(img, ox + 4, oy + 2, 8, 2, OUTLINE)
    _rect(img, ox + 3, oy + 4, 10, 5, OUTLINE)
    _rect(img, ox + 4, oy + 9, 8, 2, OUTLINE)
    _rect(img, ox + 6, oy + 11, 4, 2, OUTLINE)
    _rect(img, ox + 5, oy + 4, 6, 5, BLUE_DARK)
    _rect(img, ox + 6, oy + 3, 4, 1, BLUE)
    _rect(img, ox + 6, oy + 9, 4, 2, BLUE_DARK)
    _rect(img, ox + 7, oy + 11, 2, 1, BLUE_DARK)
    _rect(img, ox + 7, oy + 4, 2, 7, SILVER_LIGHT)
    _rect(img, ox + 5, oy + 5, 1, 3, SILVER)
    _rect(img, ox + 10, oy + 5, 1, 3, SILVER_DARK)


def _save_crystal(img, ox: int, oy: int) -> None:
    _rect(img, ox + 4, oy + 13, 8, 2, SHADOW)
    _rect(img, ox + 5, oy + 11, 6, 3, OUTLINE)
    _rect(img, ox + 6, oy + 10, 4, 4, SILVER_DARK)
    _diamond(img, ox + 8, oy + 6, 5, OUTLINE)
    _diamond(img, ox + 8, oy + 6, 4, CRYSTAL_DARK)
    _diamond(img, ox + 8, oy + 6, 3, CRYSTAL)
    _rect(img, ox + 7, oy + 3, 2, 5, CRYSTAL_LIGHT)
    _set(img, ox + 10, oy + 6, CRYSTAL_DARK)


def _inventory_slot_empty(img, ox: int, oy: int) -> None:
    _rect(img, ox + 2, oy + 2, 12, 12, OUTLINE)
    _rect(img, ox + 3, oy + 3, 10, 10, (57, 54, 68, 255))
    _rect(img, ox + 4, oy + 4, 8, 1, (86, 81, 99, 255))
    _rect(img, ox + 4, oy + 12, 8, 1, (39, 38, 49, 255))


def _inventory_slot_selected(img, ox: int, oy: int) -> None:
    _inventory_slot_empty(img, ox, oy)
    _rect(img, ox + 1, oy + 1, 14, 2, GOLD)
    _rect(img, ox + 1, oy + 13, 14, 2, GOLD_DARK)
    _rect(img, ox + 1, oy + 3, 2, 10, GOLD)
    _rect(img, ox + 13, oy + 3, 2, 10, GOLD_DARK)


def _continue_prompt_badge(img, ox: int, oy: int) -> None:
    _rect(img, ox + 3, oy + 3, 10, 10, OUTLINE)
    _rect(img, ox + 4, oy + 4, 8, 8, PARCHMENT)
    _rect(img, ox + 5, oy + 6, 6, 1, PARCHMENT_DARK)
    _rect(img, ox + 5, oy + 9, 5, 1, PARCHMENT_DARK)
    _rect(img, ox + 11, oy + 3, 2, 10, WOOD_DARK)


def _new_game_prompt_badge(img, ox: int, oy: int) -> None:
    _rect(img, ox + 3, oy + 3, 10, 10, OUTLINE)
    _rect(img, ox + 4, oy + 4, 8, 8, GREEN_DARK)
    _rect(img, ox + 7, oy + 5, 2, 6, GREEN)
    _rect(img, ox + 5, oy + 7, 6, 2, GREEN)
    _set(img, ox + 6, oy + 6, CRYSTAL_LIGHT)


def _write_png(path: Path, img: list[list[tuple[int, int, int, int]]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    width = len(img[0])
    height = len(img)
    raw = bytearray()
    for row in img:
        raw.append(0)
        for r, g, b, a in row:
            raw.extend((r, g, b, a))
    png = b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
            _chunk(b"IDAT", zlib.compress(bytes(raw), level=9)),
            _chunk(b"IEND", b""),
        ]
    )
    path.write_bytes(png)


def _chunk(kind: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    )


if __name__ == "__main__":
    os.chdir(Path(__file__).resolve().parents[3])
    main()
