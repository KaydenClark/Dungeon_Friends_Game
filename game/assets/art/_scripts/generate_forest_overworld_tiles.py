"""Generate the first Batch A forest overworld tile sheet.

This is a deterministic source-art generator for the post-Phase-2 forest
asset pass. It keeps the first real forest sheet reproducible until Aseprite
source files are drawn and exported through export_sheets.lua.

Run from game/:
  python assets/art/_scripts/generate_forest_overworld_tiles.py

Output:
  assets/art/tilesets/forest_overworld_tiles.png
"""

from __future__ import annotations

import os
import struct
import zlib
from pathlib import Path


TILE = 16
COLS = 4
ROWS = 4
OUT_PATH = Path("assets/art/tilesets/forest_overworld_tiles.png")

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (28, 32, 26, 255)
GRASS = (88, 183, 65, 255)
GRASS_DARK = (63, 142, 48, 255)
GRASS_LIGHT = (143, 216, 87, 255)
PATH = (206, 170, 103, 255)
PATH_DARK = (160, 125, 75, 255)
PATH_LIGHT = (232, 200, 130, 255)
CANOPY = (42, 111, 48, 255)
CANOPY_DARK = (24, 72, 31, 255)
CANOPY_LIGHT = (77, 153, 64, 255)
TRUNK = (118, 75, 34, 255)
TRUNK_DARK = (76, 47, 22, 255)
STONE = (111, 112, 103, 255)
STONE_DARK = (74, 76, 70, 255)
STONE_LIGHT = (151, 151, 134, 255)
WOOD = (156, 95, 43, 255)
WOOD_DARK = (91, 52, 26, 255)
FIRE = (245, 110, 38, 255)
FIRE_LIGHT = (255, 207, 81, 255)
MOUTH = (37, 34, 42, 255)


def main() -> None:
    img = _new_image(COLS * TILE, ROWS * TILE, TRANSPARENT)
    tiles = [
        _grass,
        _path_center,
        _path_edge_north,
        _path_corner_ne,
        _tree,
        _shrub,
        _rock,
        _stump,
        _cave_mouth,
        _campfire,
        _sign,
        _flowers,
        _dirt_variant,
        _shadow_patch,
        _grass,
        _grass,
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


def _circle(img, cx: float, cy: float, radius: float, color) -> None:
    r2 = radius * radius
    for y in range(int(cy - radius - 1), int(cy + radius + 2)):
        for x in range(int(cx - radius - 1), int(cx + radius + 2)):
            if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2:
                _set(img, x, y, color)


def _grass(img, ox: int, oy: int) -> None:
    _rect(img, ox, oy, TILE, TILE, GRASS)
    for x, y in [(2, 3), (6, 2), (11, 4), (14, 7), (4, 11), (9, 13), (1, 14)]:
        _set(img, ox + x, oy + y, GRASS_DARK)
    for x, y in [(4, 5), (8, 6), (13, 2), (6, 12), (12, 13)]:
        _set(img, ox + x, oy + y, GRASS_LIGHT)


def _path_base(img, ox: int, oy: int) -> None:
    _rect(img, ox, oy, TILE, TILE, PATH)
    for x, y in [(2, 2), (7, 3), (12, 4), (4, 9), (10, 11), (14, 14)]:
        _set(img, ox + x, oy + y, PATH_DARK)
    for x, y in [(3, 5), (9, 7), (13, 9), (5, 13)]:
        _set(img, ox + x, oy + y, PATH_LIGHT)


def _path_center(img, ox: int, oy: int) -> None:
    _path_base(img, ox, oy)


def _path_edge_north(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    _rect(img, ox, oy + 4, TILE, 12, PATH)
    for x in range(TILE):
        if x % 3 != 1:
            _set(img, ox + x, oy + 4, PATH_DARK)


def _path_corner_ne(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    _rect(img, ox, oy + 4, 12, 12, PATH)
    _rect(img, ox, oy, 8, 8, PATH)
    for x, y in [(10, 4), (11, 5), (12, 7), (7, 2), (4, 3)]:
        _set(img, ox + x, oy + y, PATH_DARK)


def _tree(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    _rect(img, ox + 6, oy + 10, 4, 6, TRUNK_DARK)
    _rect(img, ox + 7, oy + 10, 2, 5, TRUNK)
    _circle(img, ox + 7.5, oy + 5.5, 6.4, CANOPY_DARK)
    _circle(img, ox + 7.5, oy + 5.5, 5.2, CANOPY)
    _circle(img, ox + 5.5, oy + 3.5, 2.3, CANOPY_LIGHT)
    _set(img, ox + 2, oy + 9, CANOPY_DARK)
    _set(img, ox + 13, oy + 8, CANOPY_DARK)


def _shrub(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    for cx, cy, r in [(5.0, 9.5, 3.5), (8.5, 8.0, 4.0), (11.5, 10.0, 3.0)]:
        _circle(img, ox + cx, oy + cy, r, CANOPY_DARK)
    for cx, cy, r in [(5.0, 9.5, 2.6), (8.5, 8.0, 3.1), (11.5, 10.0, 2.2)]:
        _circle(img, ox + cx, oy + cy, r, CANOPY)
    _set(img, ox + 7, oy + 6, CANOPY_LIGHT)
    _set(img, ox + 10, oy + 8, CANOPY_LIGHT)


def _rock(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    _circle(img, ox + 7.5, oy + 9.0, 5.2, STONE_DARK)
    _circle(img, ox + 7.5, oy + 8.2, 4.4, STONE)
    _rect(img, ox + 5, oy + 6, 5, 2, STONE_LIGHT)
    _set(img, ox + 11, oy + 11, STONE_DARK)


def _stump(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    _rect(img, ox + 4, oy + 7, 8, 6, WOOD_DARK)
    _rect(img, ox + 5, oy + 6, 6, 6, WOOD)
    _rect(img, ox + 6, oy + 7, 4, 1, (199, 136, 69, 255))
    _set(img, ox + 8, oy + 9, WOOD_DARK)


def _cave_mouth(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    _rect(img, ox + 2, oy + 7, 12, 8, STONE_DARK)
    _rect(img, ox + 3, oy + 6, 10, 4, STONE)
    _rect(img, ox + 5, oy + 8, 6, 7, MOUTH)
    _rect(img, ox + 4, oy + 5, 8, 1, STONE_LIGHT)
    _set(img, ox + 3, oy + 10, STONE_LIGHT)
    _set(img, ox + 12, oy + 10, STONE_DARK)


def _campfire(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    _rect(img, ox + 3, oy + 12, 10, 2, WOOD_DARK)
    _rect(img, ox + 5, oy + 11, 8, 1, WOOD)
    _rect(img, ox + 7, oy + 5, 3, 7, FIRE)
    _rect(img, ox + 8, oy + 3, 2, 7, FIRE_LIGHT)
    _set(img, ox + 6, oy + 8, FIRE_LIGHT)
    _set(img, ox + 10, oy + 8, FIRE)


def _sign(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    _rect(img, ox + 7, oy + 8, 2, 7, WOOD_DARK)
    _rect(img, ox + 4, oy + 4, 8, 6, WOOD_DARK)
    _rect(img, ox + 5, oy + 5, 6, 4, WOOD)
    _rect(img, ox + 6, oy + 6, 4, 1, (212, 146, 78, 255))


def _flowers(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    for x, y, c in [
        (4, 5, (246, 110, 151, 255)),
        (10, 6, (255, 232, 107, 255)),
        (6, 11, (133, 190, 255, 255)),
        (12, 12, (246, 110, 151, 255)),
    ]:
        _set(img, ox + x, oy + y, c)
        _set(img, ox + x + 1, oy + y, c)
        _set(img, ox + x, oy + y + 1, c)


def _dirt_variant(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    for y in range(5, 12):
        for x in range(3, 13):
            if (x + y) % 3 != 0:
                _set(img, ox + x, oy + y, PATH_DARK if y in (5, 11) else PATH)


def _shadow_patch(img, ox: int, oy: int) -> None:
    _grass(img, ox, oy)
    for y in range(5, 12):
        for x in range(2, 14):
            if ((x - 8) * (x - 8)) / 34.0 + ((y - 8) * (y - 8)) / 10.0 <= 1.0:
                _set(img, ox + x, oy + y, (44, 94, 43, 255))


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
