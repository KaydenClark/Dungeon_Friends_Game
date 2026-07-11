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
