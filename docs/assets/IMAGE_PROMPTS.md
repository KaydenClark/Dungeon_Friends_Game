# Dungeon Friends - Image Prompt Log

**Last updated:** 2026-07-10
**Status:** active prompt ledger; three supplied source sheets need provenance completion

This file records prompts used to generate image assets for Dungeon Friends.
Do not treat a generated image as usable project source unless the prompt that
created it is logged here.

Use one entry per generated image or generated sheet. If a result is
regenerated, append a new entry instead of replacing history.

## Prompt Rules

- Use project-owned style language from `BLUEPRINT.md` and
  `docs/assets/ASSET_PLAN.md`.
- Do not request a direct copy of copyrighted game art, characters, logos, or
  named franchise assets.
- Do not name living artists as style targets.
- Prefer precise asset specs: top-down pixel art, 16x16 tile units, transparent
  background, readable silhouette, nearest-neighbor-friendly edges.
- Record negative prompts and exclusions when they matter.
- Record the generated output path once the image is accepted into
  `game/assets/art/`.

## Entry Template

```text
### PROMPT-000 - Short asset name

- Date:
- Task id:
- Asset batch:
- Intended runtime path:
- Source/reference inputs:
- Tool/model:
- Settings:
- Prompt:
- Negative prompt / exclusions:
- Result path:
- Acceptance notes:
- Follow-up needed:
```

## Entries

### PROMPT-001 - Armored knight source sheet

- Date: 2026-07-10 (accepted into the repository)
- Task id: Asset intake / T-055
- Asset batch: E - Combat MVP Assets
- Intended runtime path: Unassigned; source sheet only
- Source/reference inputs: Supplied directly by Kayden in the 2026-07-10 Codex task
- Tool/model: OpenAI image generation; exact model not available in this task
- Settings: Not available in this task
- Prompt: Not available in this task; recover from the originating image-generation task before runtime use
- Negative prompt / exclusions: Not available in this task
- Result path: `game/assets/art/sprites/exec-7334668b-51d1-4c41-a327-81a9a6c52958.png`
- Acceptance notes: Accepted as a concept/source sheet only. The 1254x1254 PNG is RGB with a baked checkerboard, not transparent RGBA, and frames are not normalized to a runtime grid.
- Follow-up needed: Recover the exact prompt/model, assign the character role, remove the baked background, crop and normalize frames, then verify animation at game scale.

### PROMPT-002 - Wizard source sheet

- Date: 2026-07-10 (accepted into the repository)
- Task id: Asset intake / T-055 or T-056 pending role assignment
- Asset batch: E/F - Combat MVP or Party And Progression Assets
- Intended runtime path: Unassigned; source sheet only
- Source/reference inputs: Supplied directly by Kayden in the 2026-07-10 Codex task
- Tool/model: OpenAI image generation; exact model not available in this task
- Settings: Not available in this task
- Prompt: Not available in this task; recover from the originating image-generation task before runtime use
- Negative prompt / exclusions: Not available in this task
- Result path: `game/assets/art/sprites/exec-a240fce0-1b0e-4464-ae8f-75f7ae64f5de.png`
- Acceptance notes: Accepted as a concept/source sheet only. The 1254x1254 PNG is RGB with a baked checkerboard, not transparent RGBA, and frames are not normalized to a runtime grid.
- Follow-up needed: Recover the exact prompt/model, assign the character role, remove the baked background, crop and normalize frames, then verify animation at game scale.

### PROMPT-003 - Red ooze source sheet

- Date: 2026-07-10 (accepted into the repository)
- Task id: Asset intake / T-053 and T-055
- Asset batch: C/E - Overworld Enemies and Combat MVP Assets
- Intended runtime path: Unassigned; source sheet only
- Source/reference inputs: Supplied directly by Kayden in the 2026-07-10 Codex task
- Tool/model: OpenAI image generation; exact model not available in this task
- Settings: Not available in this task
- Prompt: Not available in this task; recover from the originating image-generation task before runtime use
- Negative prompt / exclusions: Not available in this task
- Result path: `game/assets/art/sprites/exec-deeef55a-1ac6-4d45-bd50-69eb9aacfd2b.png`
- Acceptance notes: Accepted as a concept/source sheet only. The 1448x1086 PNG is RGB with a baked checkerboard, not transparent RGBA, and frames are not normalized to a runtime grid.
- Follow-up needed: Recover the exact prompt/model, decide which slime/ooze variants use it, remove the baked background, crop and normalize frames, then verify idle/move/aggro readability at game scale.

### PROMPT-004 - Hero knight runtime idle strip

- Date: 2026-07-10
- Task id: T-053 / T-055
- Asset batch: C/E - Overworld Characters and Combat MVP Assets
- Intended runtime path: `game/assets/art/sprites/runtime/hero_knight_idle.png`
- Source/reference inputs: `game/assets/art/sprites/exec-7334668b-51d1-4c41-a327-81a9a6c52958.png`
- Tool/model: OpenAI image generation through Codex imagegen; model identifier not exposed
- Settings: One image edit; four-frame horizontal strip
- Prompt: Create a candidate production spritesheet for Dungeon Friends, a 2D top-down tactical adventure RPG. Edit the provided armored knight concept into a single horizontal 4-frame idle/breathing animation strip. Preserve the exact same knight identity: white-and-gold plate armor, red plume and cape, sword, shield, stocky heroic proportions, readable helmet silhouette, same palette. Facing three-quarter right, suitable for a tactical grid unit. Frame beats: 1 neutral ready pose, 2 subtle weight shift and cape lift, 3 slight shield/sword breathing motion, 4 return toward neutral. Transparent background with real alpha, exactly one row of 4 equal frame slots, consistent bottom-center anchor and scale, no scenery, no checkerboard, no labels, no borders, no extra characters, no shadows outside the sprite. Authentic crisp pixel-art production asset with restrained palette and clean pixel clusters, not concept art or a poster. Every frame must fit fully inside its slot without overlap.
- Negative prompt / exclusions: No scenery, checkerboard, labels, borders, extra characters, external shadows, concept-art composition, or frame overlap
- Result path: Raw edit at `game/assets/art/sprites/source/hero_knight_idle_raw.png`; normalized runtime atlas at `game/assets/art/sprites/runtime/hero_knight_idle.png`
- Acceptance notes: Background cleaned to real alpha; four 128x128 frames share one scale and bottom-center anchor; wired to Hero in overworld and combat.
- Follow-up needed: Add directional overworld walk strips and attack/defend animations in later art passes.

### PROMPT-005 - Buddy wizard runtime idle strip

- Date: 2026-07-10
- Task id: T-055 / T-056
- Asset batch: E/F - Combat MVP and Party And Progression Assets
- Intended runtime path: `game/assets/art/sprites/runtime/buddy_wizard_idle.png`
- Source/reference inputs: `game/assets/art/sprites/exec-a240fce0-1b0e-4464-ae8f-75f7ae64f5de.png`
- Tool/model: OpenAI image generation through Codex imagegen; model identifier not exposed
- Settings: One image edit; four-frame horizontal strip
- Prompt: Create a candidate production spritesheet for Dungeon Friends, a 2D top-down tactical adventure RPG. Edit the provided elderly wizard concept into a single horizontal 4-frame idle/casting-ready animation strip. Preserve the exact same wizard identity: short elderly white-bearded wizard, deep blue and purple star-and-moon robe and hat with gold trim, wooden staff with amber gem, warm readable face, same stocky proportions and palette. Facing three-quarter left, suitable for the Hero's allied tactical grid companion. Frame beats: 1 neutral staff-ready pose, 2 beard and robe lift subtly, 3 staff gem glows and free hand raises slightly, 4 settle toward neutral. Transparent background with real alpha, exactly one row of 4 equal frame slots, consistent bottom-center anchor and scale, no scenery, no checkerboard, no labels, no borders, no extra characters, no shadows outside the sprite. Authentic crisp pixel-art production asset with restrained palette and clean pixel clusters, not concept art or a poster. Every frame must fit fully inside its slot without overlap.
- Negative prompt / exclusions: No scenery, checkerboard, labels, borders, extra characters, external shadows, concept-art composition, or frame overlap
- Result path: Raw edit at `game/assets/art/sprites/source/buddy_wizard_idle_raw.png`; normalized runtime atlas at `game/assets/art/sprites/runtime/buddy_wizard_idle.png`
- Acceptance notes: Background cleaned to real alpha; four 128x128 frames share one scale and bottom-center anchor; wired to the temporary Buddy companion in combat.
- Follow-up needed: Confirm whether this wizard becomes the first authored recruit, then add directional/ability animations.

### PROMPT-006 - Red ooze runtime idle strip

- Date: 2026-07-10
- Task id: T-053 / T-055
- Asset batch: C/E - Overworld Enemies and Combat MVP Assets
- Intended runtime path: `game/assets/art/sprites/runtime/red_ooze_idle.png`
- Source/reference inputs: `game/assets/art/sprites/exec-deeef55a-1ac6-4d45-bd50-69eb9aacfd2b.png`
- Tool/model: OpenAI image generation through Codex imagegen; model identifier not exposed
- Settings: One image edit; four-frame horizontal strip
- Prompt: Create a candidate production spritesheet for Dungeon Friends, a 2D top-down tactical adventure RPG. Edit the provided red ooze/octopus-like slime concept into a single horizontal 4-frame idle/scuttle animation strip. Preserve the exact same creature identity: bright red glossy ooze body, two large yellow eyes, curling tentacle-like pseudopods, mischievous readable silhouette, same palette and pixel-art proportions. Facing three-quarter left, suitable for both an overworld enemy and a tactical grid foe. Frame beats: 1 low idle crouch, 2 body rises and front tentacles lift, 3 short forward scuttle with trailing tentacles, 4 squash and settle toward neutral. Transparent background with real alpha, exactly one row of 4 equal frame slots, consistent bottom-center anchor and scale, no scenery, no checkerboard, no labels, no borders, no extra creatures, no shadows outside the sprite. Authentic crisp pixel-art production asset with restrained palette and clean pixel clusters, not concept art or a poster. Every frame must fit fully inside its slot without overlap.
- Negative prompt / exclusions: No scenery, checkerboard, labels, borders, extra creatures, external shadows, concept-art composition, or frame overlap
- Result path: Raw edit at `game/assets/art/sprites/source/red_ooze_idle_raw.png`; normalized runtime atlas at `game/assets/art/sprites/runtime/red_ooze_idle.png`
- Acceptance notes: Background cleaned to real alpha; four 128x128 frames share one scale and bottom-center anchor; wired to all current slime variants with a larger boss scale.
- Follow-up needed: Create palette/silhouette variants for forest, boss, and dungeon slimes plus a dedicated aggro state for T-028.
