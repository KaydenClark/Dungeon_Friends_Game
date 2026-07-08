"""Generate the first Batch B tutorial dungeon tile sheet.

This deterministic generator covers the objects the current four-room tutorial
dungeon needs. It is source art for review/import, not runtime wiring.

Run from game/:
  python assets/art/_scripts/generate_tutorial_dungeon_tiles.py

Output:
  assets/art/tilesets/tutorial_dungeon_tiles.png
"""

from __future__ import annotations

import os
import struct
import zlib
from pathlib import Path


TILE = 16
COLS = 4
ROWS = 4
OUT_PATH = Path("assets/art/tilesets/tutorial_dungeon_tiles.png")

TRANSPARENT = (0, 0, 0, 0)
FLOOR = (96, 91, 108, 255)
FLOOR_DARK = (70, 66, 83, 255)
FLOOR_LIGHT = (127, 119, 139, 255)
WALL = (67, 59, 84, 255)
WALL_DARK = (43, 38, 55, 255)
WALL_LIGHT = (100, 91, 118, 255)
BRICK = (110, 104, 123, 255)
BRICK_DARK = (72, 68, 84, 255)
BRICK_LIGHT = (150, 143, 158, 255)
LOOSE_BRICK = (126, 114, 118, 255)
PIT = (19, 17, 25, 255)
PIT_EDGE = (50, 45, 61, 255)
LEDGE = (151, 131, 102, 255)
LEDGE_DARK = (94, 75, 61, 255)
WOOD = (145, 86, 42, 255)
WOOD_DARK = (86, 48, 28, 255)
GOLD = (235, 178, 62, 255)
GOLD_DARK = (161, 108, 33, 255)
LOCK = (55, 45, 71, 255)
CHEST = (163, 92, 43, 255)
CHEST_DARK = (90, 50, 29, 255)
CHEST_LIGHT = (218, 145, 68, 255)
METAL = (173, 178, 181, 255)
METAL_DARK = (93, 101, 108, 255)
LEVER_RED = (184, 54, 59, 255)


def main() -> None:
    img = _new_image(COLS * TILE, ROWS * TILE, TRANSPARENT)
    tiles = [
        _floor,
        _wall,
        _fixed_brick,
        _loose_brick,
        _pit,
        _ledge_edge,
        _filled_pit,
        _locked_door,
        _open_door,
        _chest_closed,
        _chest_open,
        _lever_idle,
        _lever_used,
        _floor_cracked,
        _wall_shadow,
        _floor,
    ]
    for index, drawer in enumerate(tiles):
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


def _floor(img, ox: int, oy: int) -> None:
    _rect(img, ox, oy, TILE, TILE, FLOOR)
    for x, y in [(2, 2), (7, 3), (12, 1), (4, 8), (10, 9), (13, 14)]:
        _set(img, ox + x, oy + y, FLOOR_DARK)
    for x, y in [(5, 5), (11, 6), (3, 12), (9, 13)]:
        _set(img, ox + x, oy + y, FLOOR_LIGHT)


def _wall(img, ox: int, oy: int) -> None:
    _rect(img, ox, oy, TILE, TILE, WALL)
    for y in range(0, TILE, 4):
        _rect(img, ox, oy + y + 3, TILE, 1, WALL_DARK)
        _rect(img, ox, oy + y, TILE, 1, WALL_LIGHT)
    for y in range(TILE):
        offset = 4 if (y // 4) % 2 else 0
        for x in range(offset + 7, TILE, 8):
            _set(img, ox + x, oy + y, WALL_DARK)


def _brick_base(img, ox: int, oy: int, base, dark, light) -> None:
    _floor(img, ox, oy)
    _rect(img, ox + 2, oy + 4, 12, 9, dark)
    _rect(img, ox + 3, oy + 3, 10, 9, base)
    _rect(img, ox + 4, oy + 4, 8, 1, light)
    _rect(img, ox + 3, oy + 7, 10, 1, dark)
    _rect(img, ox + 7, oy + 3, 1, 9, dark)


def _fixed_brick(img, ox: int, oy: int) -> None:
    _brick_base(img, ox, oy, BRICK, BRICK_DARK, BRICK_LIGHT)


def _loose_brick(img, ox: int, oy: int) -> None:
    _brick_base(img, ox, oy, LOOSE_BRICK, BRICK_DARK, BRICK_LIGHT)
    _set(img, ox + 4, oy + 11, FLOOR_DARK)
    _set(img, ox + 12, oy + 8, FLOOR_DARK)


def _pit(img, ox: int, oy: int) -> None:
    _rect(img, ox, oy, TILE, TILE, PIT)
    for x in range(TILE):
        _set(img, ox + x, oy, PIT_EDGE)
        if x % 3 != 0:
            _set(img, ox + x, oy + 1, PIT_EDGE)
    for x, y in [(4, 5), (10, 7), (7, 11)]:
        _set(img, ox + x, oy + y, (31, 28, 40, 255))


def _ledge_edge(img, ox: int, oy: int) -> None:
    _floor(img, ox, oy)
    _rect(img, ox, oy + 9, TILE, 7, PIT)
    _rect(img, ox, oy + 7, TILE, 3, LEDGE_DARK)
    _rect(img, ox, oy + 6, TILE, 2, LEDGE)
    for x in range(0, TILE, 3):
        _set(img, ox + x, oy + 8, LEDGE_DARK)


def _filled_pit(img, ox: int, oy: int) -> None:
    _pit(img, ox, oy)
    _rect(img, ox + 2, oy + 5, 12, 8, WOOD_DARK)
    _rect(img, ox + 3, oy + 4, 10, 8, WOOD)
    _rect(img, ox + 3, oy + 7, 10, 1, WOOD_DARK)
    _rect(img, ox + 6, oy + 4, 1, 8, WOOD_DARK)


def _locked_door(img, ox: int, oy: int) -> None:
    _wall(img, ox, oy)
    _rect(img, ox + 4, oy + 4, 8, 12, WOOD_DARK)
    _rect(img, ox + 5, oy + 5, 6, 11, WOOD)
    _rect(img, ox + 6, oy + 8, 4, 4, GOLD_DARK)
    _rect(img, ox + 7, oy + 8, 2, 3, GOLD)
    _set(img, ox + 8, oy + 10, LOCK)


def _open_door(img, ox: int, oy: int) -> None:
    _wall(img, ox, oy)
    _rect(img, ox + 4, oy + 4, 8, 12, PIT)
    _rect(img, ox + 4, oy + 4, 1, 12, WALL_LIGHT)
    _rect(img, ox + 11, oy + 4, 1, 12, WALL_DARK)
    _rect(img, ox + 5, oy + 13, 6, 3, FLOOR_DARK)


def _chest_closed(img, ox: int, oy: int) -> None:
    _floor(img, ox, oy)
    _rect(img, ox + 3, oy + 7, 10, 6, CHEST_DARK)
    _rect(img, ox + 4, oy + 6, 8, 6, CHEST)
    _rect(img, ox + 4, oy + 6, 8, 2, CHEST_LIGHT)
    _rect(img, ox + 7, oy + 6, 2, 6, GOLD)
    _set(img, ox + 8, oy + 9, GOLD_DARK)


def _chest_open(img, ox: int, oy: int) -> None:
    _floor(img, ox, oy)
    _rect(img, ox + 3, oy + 9, 10, 5, CHEST_DARK)
    _rect(img, ox + 4, oy + 9, 8, 4, CHEST)
    _rect(img, ox + 4, oy + 5, 8, 3, CHEST_LIGHT)
    _rect(img, ox + 5, oy + 8, 6, 1, PIT)
    _rect(img, ox + 7, oy + 9, 2, 4, GOLD)


def _lever_idle(img, ox: int, oy: int) -> None:
    _floor(img, ox, oy)
    _rect(img, ox + 6, oy + 10, 5, 3, METAL_DARK)
    _rect(img, ox + 7, oy + 5, 2, 7, METAL)
    _rect(img, ox + 5, oy + 4, 4, 3, LEVER_RED)


def _lever_used(img, ox: int, oy: int) -> None:
    _floor(img, ox, oy)
    _rect(img, ox + 5, oy + 10, 5, 3, METAL_DARK)
    for i in range(6):
        _set(img, ox + 6 + i, oy + 10 - i, METAL)
    _rect(img, ox + 10, oy + 4, 4, 3, LEVER_RED)


def _floor_cracked(img, ox: int, oy: int) -> None:
    _floor(img, ox, oy)
    for x, y in [(4, 5), (5, 6), (6, 7), (8, 7), (9, 8), (10, 9), (7, 10)]:
        _set(img, ox + x, oy + y, FLOOR_DARK)


def _wall_shadow(img, ox: int, oy: int) -> None:
    _wall(img, ox, oy)
    _rect(img, ox, oy + 11, TILE, 5, WALL_DARK)


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
