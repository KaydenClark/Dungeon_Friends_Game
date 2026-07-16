# Paladin Sprite Generation Brief

Status: ready to generate. Written 2026-07-12 (Cowork session). The Druid,
Rogue, and Wizard packages under `game/assets/art/sprites/source/<class>/`
established the format; this brief produces the missing Paladin package in
that exact format so `build_character_kit.py` can finish it in one command.

Why a brief instead of finished art: the existing masters were generated with
Codex imagegen (see PROMPT-007 in `IMAGE_PROMPTS.md`); the Cowork session that
wrote this brief has no image-generation tool. Run the four generations below
through the same tool, save the outputs to the listed paths, then run the two
commands at the bottom. Record final provenance in `IMAGE_PROMPTS.md` as
PROMPT-008..011 per house convention.

## Identity lock (from `game/assets/art/character_concept_art/paladin/`)

Synthesized from all five concept images (armored crusader with halo
`jKYt5H4Z...`, red-caped commander `CENpxWmO...`, comic-style knight
`U6o8k-XN...`, gold-white sentinel `ayp2j2nv...`, sword-and-shield man-at-arms
`ec6fc5a1...`):

- Broad, stocky heroic proportions matching the druid/rogue/wizard masters
  (chunky readable fantasy-adventure silhouette, oversized head OK)
- Polished silver/steel plate armor with bright gold trim and a gold sun/
  radiance emblem on the chest
- Crimson cape falling from both pauldrons (strong back-view read for _n rows)
- Bare head: short blond hair and trimmed beard, warm confident face
  (faces read better at 128px for a recruitable friend; keeps him distinct
  from the red-plumed helmeted Hero knight)
- Longsword with gold crossguard; deep-red kite shield with a pale sword
  emblem (concept `ec6fc5a1...`) on the left arm
- Holy-magic accent color: warm golden-white light (vs. wizard gold-violet,
  druid green-teal)
- Restrained palette, crisp hand-pixeled clusters, same rendering style and
  scale feel as the druid/rogue/wizard master sheets

## Shared prompt scaffold (applies to all four generations)

> Authentic hand-pixeled production sprite art with crisp pixel clusters,
> identical proportions, scale, palette, and bottom-center baseline in every
> frame. Orthogonal square-grid presentation (not isometric). Render on a
> perfectly flat solid green chroma background with no scenery, labels,
> dividers, extra characters, shadows, checkerboard, or cropped character or
> effect parts.

Negative prompt / exclusions (house standard): no true/diamond isometric view,
scenery, labels, text, numbers, borders, slot dividers, poster layout, extra
characters, enemies, portraits, realistic painting, 3D rendering, blur,
vector-like smoothing, watermark, baked checkerboard, cast/contact shadow,
frame overlap, or cropped hair/swords/shields/capes/feet/effects.

Reference inputs for every generation: the five paladin concept images (or as
many as the tool's reference limit allows, prioritizing `jKYt5H4Z`,
`CENpxWmO`, `ec6fc5a1`), plus the seed image once it exists.

## Generation 1 - identity seed

Output: `game/assets/art/sprites/source/paladin/paladin_seed_chroma.png`
(alpha copy after keying: `paladin_seed_alpha.png`)

> Create one full-body pixel-art character study of a paladin for Dungeon
> Friends, matching the supplied concept art: [identity lock paragraph].
> Single character, three-quarter front-right stance, sword hand relaxed,
> kite shield on the left arm, cape visible behind the shoulders.
> [shared scaffold]

## Generation 2 - master sheet A (idles + walk north)

Output: `game/assets/art/sprites/source/paladin/paladin_master_a_chroma.png`
1254x1254 or larger, exactly four columns by four rows, one animation per row,
four frame beats per row:

> Row 1 idle_n (back view, cape dominant): neutral stance; slow breath with
> subtle cape sway; shoulder shift, sword tip settles; return toward neutral.
> Row 2 idle_e (right-facing side profile): neutral ready; breath, cape lift;
> shield arm adjusts, gold trim glints; settle.
> Row 3 idle_s (three-quarter front): neutral ready; breath, head turn hint;
> sun emblem glint, grip flex; settle.
> Row 4 walk_n (back view walking away): right foot lead; passing pose, cape
> swings; left foot lead; passing pose.
> Same paladin identity in all 16 frames. [shared scaffold]

## Generation 3 - master sheet B (side/front walks, combat idle, attack)

Output: `game/assets/art/sprites/source/paladin/paladin_master_b_chroma.png`

> Row 1 walk_e (right-facing side walk): right lead; passing pose; left lead;
> passing pose - cape and scabbard follow-through.
> Row 2 walk_s (three-quarter front walk toward viewer): right lead; passing;
> left lead; passing.
> Row 3 combat_idle (three-quarter right battle stance): low guard with sword
> and raised shield; weight shift; faint golden glint runs along the blade;
> settle back to guard.
> Row 4 attack (three-quarter right): windup, sword drawn back over shoulder;
> forward step; horizontal slash with a thin white-gold arc trail; recover to
> guard.
> Same paladin identity in all 16 frames. [shared scaffold]

## Generation 4 - master sheet C (ability, defend, hurt, ko)

Output: `game/assets/art/sprites/source/paladin/paladin_master_c_chroma.png`

> Row 1 ability (holy smite, three-quarter right): raise sword skyward; gather
> a compact ball of warm golden-white radiance at the blade tip; slam release
> with a contained burst of light rays; recoil with drifting gold embers.
> Row 2 defend (three-quarter right): raise the kite shield; brace low behind
> it; a golden translucent barrier shimmer blooms across the shield face;
> settle braced.
> Row 3 hurt (three-quarter right): alert guard; recoil from an implied hit
> with a tiny impact spark, cape whipping; stagger step, pained face; regain
> stance.
> Row 4 ko (three-quarter right): stagger, sword arm drops; sink to one knee;
> slump kneeling, propped on the sword like a cane, head bowed; still, eyes
> closed, cape pooled.
> Same paladin identity in all 16 frames. [shared scaffold]

## Finishing commands (after the four PNGs exist)

```bash
cd game/assets/art/_scripts
for s in seed master_a master_b master_c; do
  python3 key_green_chroma.py --key-enclosed \
    --input  ../sprites/source/paladin/paladin_${s}_chroma.png \
    --output ../sprites/source/paladin/paladin_${s}_alpha.png
done   # --key-enclosed is safe: no flat green in the paladin costume
python3 build_character_kit.py --class paladin
```

Outputs: `game/assets/art/sprites/runtime/paladin_complete.png` (512x1536,
4 frames x 12 rows of 128px), `game/data/sprites/paladin_complete.tres`
(all 12 contract animations with correct loop flags and speeds), and
`docs/assets/previews/paladin_complete_preview.png` for review.

## Acceptance checklist

- [ ] All 16 frames per master keep one identity, full swords/shields/capes
- [ ] Real row/column gaps between frames (the slicer cuts on gaps)
- [ ] Preview sheet eyeballed: no clipped parts, consistent scale/baseline
- [ ] `test_character_sprite_resources.gd` contract satisfied (register the
      suite in `run_tests.gd` only once all four classes are complete)
- [ ] Windowed check in Godot; record PROMPT-008..011 in `IMAGE_PROMPTS.md`

## Known follow-ups for the whole batch (not paladin-specific)

- Rogue still needs `rogue_master_c` generated (ability/defend/hurt/ko) -
  reuse the Generation 4 template with the rogue identity; its
  `rogue_master_b_alpha.png` was produced 2026-07-12 by `key_green_chroma.py`
- Side-row native facing is inconsistent across classes (wizard faces right,
  druid/rogue lean left/front). `GridActor.set_facing` flips assuming
  right-facing native art - verify per class at wiring time, flip frames in
  the pipeline if needed
- Wizard ko row reads weak (he stays mostly upright); consider a regenerate
  pass before final acceptance
