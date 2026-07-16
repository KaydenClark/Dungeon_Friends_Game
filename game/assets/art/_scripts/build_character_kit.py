#!/usr/bin/env python3
"""Build a gameplay-complete character sprite kit from three 4x4 master sheets.

Pipeline (matches the accepted PROMPT-007 Buddy wizard v2 process, extended to
the full T-056 twelve-animation contract in test_character_sprite_resources.gd):

  1. Gap-aware recut: each 1254x1254 *_alpha master is segmented on its real
     transparent gutters (rows first, then columns per row), never on an equal
     grid, so hats/staves/effects are not clipped.
  2. All 48 frames are normalized together: one shared scale chosen so every
     frame fits 128x128, bottom-center anchor on a common baseline.
  3. Outputs per class:
       game/assets/art/sprites/runtime/<class>_complete.png   (512x1536 atlas)
       game/data/sprites/<class>_complete.tres                (SpriteFrames)
       docs/assets/previews/<class>_complete_preview.png      (labeled review)

Master row -> animation mapping (fixed across all classes):
  master_a: idle_n, idle_e, idle_s, walk_n
  master_b: walk_e, walk_s, combat_idle, attack
  master_c: ability, defend, hurt, ko

Usage:
  python3 build_character_kit.py --class druid
  python3 build_character_kit.py --class paladin   # once its masters exist
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[3]  # -> game/
SOURCE = REPO / "assets/art/sprites/source"
RUNTIME = REPO / "assets/art/sprites/runtime"
DATA = REPO / "data/sprites"
PREVIEWS = REPO.parent / "docs/assets/previews"

FRAME = 128
MARGIN = 2          # keep at least this many empty px inside a frame edge
BASELINE = 125      # bottom anchor row inside each 128px frame

MASTER_ROWS = {
    "a": ["idle_n", "idle_e", "idle_s", "walk_n"],
    "b": ["walk_e", "walk_s", "combat_idle", "attack"],
    "c": ["ability", "defend", "hurt", "ko"],
}

# Contract from game/tests/test_character_sprite_resources.gd
ANIMATIONS = [
    ("idle_n", True, 4.0),
    ("idle_e", True, 4.0),
    ("idle_s", True, 4.0),
    ("walk_n", True, 8.0),
    ("walk_e", True, 8.0),
    ("walk_s", True, 8.0),
    ("combat_idle", True, 4.0),
    ("attack", False, 8.0),
    ("ability", False, 8.0),
    ("defend", False, 8.0),
    ("hurt", False, 8.0),
    ("ko", False, 6.0),
]


def _bands(occupied: np.ndarray, expected: int, min_gap: int = 4) -> list[tuple[int, int]]:
    """Return (start, end) spans of consecutive True with gaps >= min_gap merged over."""
    spans: list[list[int]] = []
    run_start = None
    for i, v in enumerate(occupied):
        if v and run_start is None:
            run_start = i
        elif not v and run_start is not None:
            spans.append([run_start, i])
            run_start = None
    if run_start is not None:
        spans.append([run_start, len(occupied)])
    # merge spans separated by tiny gaps (anti-speckle)
    merged: list[list[int]] = []
    for s in spans:
        if merged and s[0] - merged[-1][1] < min_gap:
            merged[-1][1] = s[1]
        else:
            merged.append(s)
    return [tuple(s) for s in merged] if len(merged) == expected else []


def slice_master(path: Path) -> list[list[Image.Image]]:
    """Gap-aware 4x4 recut. Returns rows of 4 frame images (tight bboxes NOT applied)."""
    im = Image.open(path).convert("RGBA")
    alpha = np.asarray(im)[:, :, 3] > 8

    row_bands = _bands(alpha.any(axis=1), 4)
    if not row_bands:
        # fallback: equal quarters vertically
        h = im.height // 4
        row_bands = [(i * h, (i + 1) * h) for i in range(4)]
        print(f"  WARN {path.name}: row gaps not found, equal-quarter rows used")

    rows: list[list[Image.Image]] = []
    for r0, r1 in row_bands:
        band = alpha[r0:r1]
        col_bands = _bands(band.any(axis=0), 4)
        if not col_bands:
            w = im.width // 4
            col_bands = [(i * w, (i + 1) * w) for i in range(4)]
            print(f"  WARN {path.name} row {r0}-{r1}: col gaps not found, equal quarters used")
        rows.append([im.crop((c0, r0, c1, r1)) for c0, c1 in col_bands])
    return rows


def build(cls: str) -> None:
    masters = {k: SOURCE / cls / f"{cls}_master_{k}_alpha.png" for k in "abc"}
    missing = [p.name for p in masters.values() if not p.exists()]
    if missing:
        raise SystemExit(f"{cls}: missing master sheets: {missing}")

    # collect frames in contract order
    frames: dict[str, list[Image.Image]] = {}
    for key, path in masters.items():
        rows = slice_master(path)
        for anim, row in zip(MASTER_ROWS[key], rows):
            frames[anim] = row

    # tight bboxes and one shared scale so every frame fits FRAME-2*MARGIN
    tight: dict[str, list[Image.Image]] = {}
    max_dim = 0
    for anim, imgs in frames.items():
        cut = []
        for f in imgs:
            bbox = f.getbbox()
            f = f.crop(bbox) if bbox else f
            cut.append(f)
            max_dim = max(max_dim, f.width, f.height)
        tight[anim] = cut
    scale = (FRAME - 2 * MARGIN) / max_dim
    print(f"{cls}: shared scale {scale:.4f} (largest source frame {max_dim}px)")

    atlas = Image.new("RGBA", (4 * FRAME, len(ANIMATIONS) * FRAME), (0, 0, 0, 0))
    for row_i, (anim, _loop, _speed) in enumerate(ANIMATIONS):
        for col_i, f in enumerate(tight[anim]):
            w = max(1, round(f.width * scale))
            h = max(1, round(f.height * scale))
            f = f.resize((w, h), Image.LANCZOS)
            x = col_i * FRAME + (FRAME - w) // 2
            y = row_i * FRAME + (BASELINE - h)
            atlas.alpha_composite(f, (max(col_i * FRAME, x), max(row_i * FRAME, y)))

    RUNTIME.mkdir(parents=True, exist_ok=True)
    atlas_path = RUNTIME / f"{cls}_complete.png"
    atlas.save(atlas_path)

    _write_tres(cls)
    _write_preview(cls, atlas)
    print(f"{cls}: wrote {atlas_path.relative_to(REPO.parent)}, "
          f"{(DATA / (cls + '_complete.tres')).relative_to(REPO.parent)}, preview")


def _write_tres(cls: str) -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    n_frames = len(ANIMATIONS) * 4
    lines = [
        f'[gd_resource type="SpriteFrames" load_steps={n_frames + 2} format=3]',
        "",
        f'[ext_resource type="Texture2D" path="res://assets/art/sprites/runtime/{cls}_complete.png" id="1_texture"]',
        "",
    ]
    idx = 1
    for row_i in range(len(ANIMATIONS)):
        for col_i in range(4):
            lines += [
                f'[sub_resource type="AtlasTexture" id="AtlasTexture_{idx:02d}"]',
                'atlas = ExtResource("1_texture")',
                f"region = Rect2({col_i * FRAME}, {row_i * FRAME}, {FRAME}, {FRAME})",
                "",
            ]
            idx += 1
    lines.append("[resource]")
    anim_blocks = []
    idx = 1
    for anim, loop, speed in ANIMATIONS:
        texs = ", ".join(
            f'{{"duration": 1.0, "texture": SubResource("AtlasTexture_{idx + i:02d}")}}'
            for i in range(4)
        )
        idx += 4
        anim_blocks.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
            % (texs, "true" if loop else "false", anim, speed)
        )
    lines.append("animations = [" + ", ".join(anim_blocks) + "]")
    (DATA / f"{cls}_complete.tres").write_text("\n".join(lines) + "\n")


def _write_preview(cls: str, atlas: Image.Image) -> None:
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    label_w = 120
    out = Image.new("RGB", (label_w + atlas.width, atlas.height), (40, 40, 48))
    out.paste(atlas, (label_w, 0), atlas)
    draw = ImageDraw.Draw(out)
    for row_i, (anim, loop, speed) in enumerate(ANIMATIONS):
        y = row_i * FRAME
        draw.line([(0, y), (out.width, y)], fill=(70, 70, 84))
        draw.text((8, y + 8), anim, fill=(235, 235, 235))
        draw.text((8, y + 24), f"{'loop' if loop else 'once'} @ {speed}",
                  fill=(160, 160, 170))
    out.save(PREVIEWS / f"{cls}_complete_preview.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--class", dest="cls", required=True,
                        help="character folder name under sprites/source, e.g. druid")
    args = parser.parse_args()
    build(args.cls)


if __name__ == "__main__":
    main()
