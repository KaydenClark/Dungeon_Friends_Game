# Dungeon Friends - Taskboard

> Generated from LLM Workbench v2.1. See `RUNBOOK.md` -> Upgrading The
> Harness.

**Current focus:** **Complete Phase 1, then build Phase 2's tutorial dungeon.**
Phase 0 is done except M0.3 export presets (T-002, Backlog per Kayden). Phase
1 remaining: movement feel polish to the Zelda/Pokemon "grid-locked but never
feels locked" bar (T-021, Kayden's #1 movement priority - subsumes B-04's
open feel review), the content pipeline (T-003 art, T-004 LDtk importer,
T-011 forest map, T-020 real-art scaling check), and the boss-door room
transition into the tutorial dungeon (T-022). **Phase 2 is now concretely
planned (2026-07-06, Kayden's spec):** a 3-room tutorial dungeon behind the
boss door - a hub room (block+plate puzzle, visible locked chest), a
2-wide-pit room (block-into-pit + jump the remaining cell - new MVP jump
mechanic), and a key-drop fight room, looping back to open the chest for the
**shield** (a plain inventory item for now - D-001 resolved). Death now
respawns (old man outside the dungeon; Room 1 + full puzzle reset inside -
T-029). Primitives land as T-023 (PushableBlock), T-024 (PressurePlate),
T-025 (jump + pits), T-026 (chest/key flow), T-029 (respawn), integrated by
T-027. Full spec: `BLUEPRINT.md` -> Phase 2 Target: Tutorial Dungeon.
Dash/roll and swim are Deferred (S-009/S-010); enemy aggro telegraph is
Backlog (T-028) until sprites exist. **Building has started: T-021 (movement
feel) is in progress.**
**Owner:** Kayden
**Last updated:** 2026-07-06 (round 2 - building started)

This is the live work queue and proof ledger. Agents use it to decide what to
work on next. Keep strategy and long-term direction in `BLUEPRINT.md`; keep
commands and verification procedures in `RUNBOOK.md`.

## Executive Brief

- **Shipping now:** The first-playable forest slice (Kayden's 2026-07-05
  walking-skeleton scenario, see `BLUEPRINT.md` -> Current Product Shape),
  playable from `main.tscn`: grid-snapped movement with camera follow, one
  NPC with dialogue, a visible slime that moves when you move, bump-to-fight
  turn-based d10 combat on a small grid arena with fade transition and exact
  position return, a key drop, a locked door, and a goal path behind it. All
  placeholder ColorRect art (real art is T-003; LDtk authoring is T-004/
  T-011).
- **Health:** green - verified on Kayden's actual Mac (Godot 4.6.3): headless
  `--import`, `main.tscn --quit-after`, and a 26/26-check end-to-end smoke
  test (`scenes/dev/slice_smoke_test.tscn`) all exit 0 with no errors, on
  both `integration` and, after the fast-forward merge, `main`. Kayden has
  also completed his windowed play-check. The prior session's pending
  T-005/T-006/T-007 re-verification was run for real too (see Proof Log).
- **Decision needed:** none open. Note: T-013 was deliberately built past its
  "empty shell" scope (a real minimal battle, not just a transition) on
  Kayden's explicit "get to play-testable" instruction. `integration` was
  fast-forwarded into `main` with Kayden's explicit go-ahead once his
  windowed play-check passed - no conflicts, no rebase needed.
- **Blocked on:** nothing.
- **Phase status (2026-07-06):** Phase 0 done except M0.3 export presets (T-002,
  moved to Backlog per Kayden). Phase 1's M1.3 (grid movement) is already done
  (T-010). Phase 1 remaining = movement feel polish (T-021), the real content
  pipeline (T-003 art, T-004 LDtk importer, T-011 LDtk forest map, T-020
  real-art scaling re-validation), and the boss-door room transition (T-022).
- **Next milestone:** T-021 (movement feel - Kayden's top movement priority,
  no dependencies) and M1.1 (T-003 - real test tileset + Aseprite
  batch-export), then M1.2 (T-004 - LDtk importer), which unblocks T-011/T-020.
- **Design update (2026-07-06):** Kayden locked in the movement-state roadmap
  (walk/face feel -> transitions/ledges -> push/pull -> dash/roll -> swim),
  added a contextual 1-cell jump to MVP scope, defined momentary
  pressure-plate semantics, and specified Phase 2's deliverable as a 3-room
  tutorial dungeon ending in a shield reward. See `BLUEPRINT.md` -> Movement-
  State Roadmap, Phase 2 Target: Tutorial Dungeon, and the 2026-07-06 Design
  Decisions rows.
- **Design update (2026-07-05):** Kayden locked in the visual language
  (GBA-fantasy-adventure look, 8x8/16x16 tile logic), confirmed the general
  explore -> interact -> act -> consequence loop, and defined combat as
  grid-based with per-unit movement/range, strict per-character initiative
  order (never team-phase), and a d10 percentage resolution system. See
  `BLUEPRINT.md` -> Design Decisions (2026-07-05 rows) and -> Core Logic And
  Invariants. Doesn't change what's next (still M0.3) - informs Phase 1 art
  (M1.1 tile grid) and the eventual Phase 4 combat build (T-013 and beyond).

## Pending Decisions

The architecture/toolchain decisions were resolved in the original research
audit (2026-06-11); the 2026-07-05/06 creative-direction additions were folded
directly into `BLUEPRINT.md` - see Design Decisions there. One small decision
is open from the Phase 2 tutorial-dungeon spec:

| ID | Decision | Options | Recommendation | Cost / impact | Owner | Status |
|---|---|---|---|---|---|---|
| D-001 | What does the tutorial **shield** actually do when the chest opens? | (a) Trophy/inventory item at Phase 2, real stats when Phase 3 `ItemData` + S-001 equipment land; (b) minimal hardcoded +defense now | (a) - keeps the "no balance numbers in scene scripts" invariant and doesn't pull the S-001 equipment stretch goal forward | Low - purely affects T-026/T-027 scope; the chest/key flow is identical either way | Kayden | **resolved 2026-07-06: (a)** - "Right now the shield is just an inventory item. It will be a thing we use later" |

## How To Use This Board

1. Read `BLUEPRINT.md` for context.
2. Pick the highest-priority `ready` task that is in scope and unclaimed.
3. Move it to `claimed` or `in-progress` before editing.
4. Do the smallest correct change.
5. Run the task's required proof and the relevant `RUNBOOK.md` checks.
6. Move the task to `done`, `blocked`, `deferred`, or `needs-review`.
7. Append one proof row with the actual result.

Do not rewrite existing proof rows. Append only.

## Status Values

| Status | Meaning |
|---|---|
| `ready` | Clear enough for the next agent to start. |
| `claimed` | An agent has picked it but has not edited yet. |
| `in-progress` | Work is underway. |
| `gated` | Implementation is done and waiting on verification, review, or merge. |
| `needs-review` | Needs human or manager review before more work. |
| `blocked` | Cannot proceed until the blocker is resolved. |
| `deferred` | Valid work, intentionally not next. |
| `done` | Proof exists and docs impact is resolved. |

A `claimed` or `in-progress` task that has gone stale (no update past one
working day) may be reclaimed per the reclaim rule in `AGENTS.md` -> Long
Session Control.

## Ready

Priorities 1-7 finish **Phase 1** (M1.3 grid movement is already done - T-010,
Done lane); priorities 8-12 are the planned **Phase 2 tutorial dungeon** (full
spec: `BLUEPRINT.md` -> Phase 2 Target: Tutorial Dungeon). Phase 2 rows are
`ready` in the sense of fully specified - respect their listed dependencies.
M0.3 export presets (T-002) is a Phase-0 leftover intentionally in Backlog.

| ID | Priority | Task | Source / why now | Touches | Proof required | Docs impact | Owner | Status | Last update |
|---|---:|---|---|---|---|---|---|---|---|
| T-021 | 1 | Movement feel polish to the Zelda/Pokemon bar (`BLUEPRINT.md` -> Core Logic, feel bar): held movement chains steps with no inter-step hitch; a tap turns the player to face first, continued press steps (turn-in-place); facing locks during interactions; tune B-04's repeat delay/cadence (**subsumes B-04's open `needs-review` feel pass**). Grid-snap invariant unchanged - this is feel, not physics | Kayden 2026-07-06: movement priority #1, "never feels like I am clicking into place"; no dependencies, testable on placeholder art | `game/scripts/overworld/player.gd`, `game/scripts/overworld/grid_actor.gd` | Unit tests still pass; smoke test 34/34; **Kayden's windowed feel-check is the real gate** (hold-walk, side-to-side taps, turn-in-place) | `TASKBOARD.md` proof row + close B-04; `BLUEPRINT.md` already carries the feel bar | Claude | **gated** - implemented + headless-verified on `feature/movement-feel`; Kayden's windowed feel-check is the gate | 2026-07-06 |
| T-003 | 2 | **M1.1**: draw a test tileset (floor, wall, 1 character) in Aseprite against the flexible HD/ultrawide design reference (grid unit narrowed to 8x8/16x16 GBA-style units by the Visual Language decision - exact pixel size still decided at this milestone; see `BLUEPRINT.md` -> Visual Language, 2026-07-05); set up the Aseprite batch-export script | Gameplan.md §15 Phase 1; first uncompleted Phase 1 milestone | `game/assets/art/`, `game/assets/art/_scripts/` | Exported sprite sheet imports into Godot with no errors | `TASKBOARD.md` proof row | agent | ready | 2026-07-06 |
| T-004 | 3 | **M1.2**: install `heygleeson/godot-ldtk-importer`; build a minimal one-room LDtk project with a Wall IntGrid layer; confirm `TileMapLayer` + collision import correctly | Gameplan.md §15 Phase 1; unblocks T-011/T-020 | `game/addons/`, `game/assets/levels/` | Headless import succeeds; `TileMapLayer` + collision visible in editor | `BLUEPRINT.md` Architecture row (LDtk "not yet installed" note) | agent | ready | 2026-07-06 |
| T-011 | 4 | Forest map: build the first test room/map using the LDtk pipeline (replaces the code-built placeholder room in `game/scripts/dev/forest_slice.gd` - keep the entities/RoomGrid logic, swap the layout authoring) | Gameplan.md §15 Phase 1; depends on T-004 (LDtk importer) | `game/assets/levels/forest_test.ldtk` + imported `TileMapLayer` | Headless import succeeds; player (T-010) can walk the room and collide with walls | `TASKBOARD.md` proof row | agent | ready | 2026-07-06 |
| T-020 | 5 | **M1.4**: re-validate the `canvas_items`/`expand` HD/ultrawide stretch settings with the **real** M1.1 tileset (not the T-007 placeholder ColorRects) at 1280x720, 1920x1080, and 3440x1440 - windowed run, confirm the tile grid reads undistorted and shows an acceptable amount of world at 21:9 | Gameplan.md §15 Phase 1 (M1.4); depends on T-003 (real tileset) | `game/scenes/dev/display_scaling_spike.tscn` (swap placeholder tiles for real art) | Windowed run at all 3 resolutions shows an undistorted grid; if `expand` reads poorly at 21:9, note the `keep`+letterbox fallback | `RUNBOOK.md` display-spike expectation; `BLUEPRINT.md` ultrawide-risk row if fallback chosen | agent | ready | 2026-07-06 |
| T-022 | 6 | Boss-door room transition: walking through the unlocked east door transitions the player into the tutorial dungeon's Room 1 (stub room acceptable until T-027 builds the real one). Pulls the Gameplan M2.3 transition mechanism forward per Kayden; use the `SceneManager` context-passing pattern (return position preserved), fade acceptable now, camera-pan polish can come with M2.3 proper | Kayden 2026-07-06: "the room we should transition is after we unlock the door after defeating the boss slime"; depends on T-010 (done) + the existing door unlock | `game/scripts/autoload/scene_manager.gd`, `game/scripts/overworld/`, new room scene/script | Headless: smoke test extended to walk through the door and assert the new room loads + player spawns at its entry cell; windowed check of the transition feel | `TASKBOARD.md` proof row; `BLUEPRINT.md` scene-contract row for the new room | agent | ready | 2026-07-06 |
| T-008 | 7 | Folder structure: establish/maintain clean Godot folders under `game/` (`scenes/`, `scripts/`, `data/`, `assets/`, `addons/`, `tests/`) | Hygiene baseline as the art/LDtk pipeline lands on top of it | `game/` directory tree | Folder tree matches the `BLUEPRINT.md` Toolchain table; no stray files at `game/` root | `BLUEPRINT.md` Toolchain table confirmed or updated if paths change | agent | ready | 2026-07-06 |
| T-023 | 8 | **Phase 2 - M2.1a**: `PushableBlock` entity - grid-snapped push (player walks into it while pressing toward it; block tweens one cell if the destination is free), blocked by walls/entities/other blocks, occupies its cell for pathing. Push-only at MVP (pull is not in Kayden's spec) | Kayden 2026-07-06: "I really want pushable blocks... my favorite tool for puzzles"; movement roadmap row 3 | `game/scripts/puzzles/pushable_block.gd`, overworld interaction | Unit tests: push into free cell moves block, push into wall/occupied cell doesn't, player never overlaps block; smoke-test extension | `TASKBOARD.md` proof row | agent | ready | 2026-07-06 |
| T-024 | 9 | **Phase 2 - M2.1b**: `PressurePlate` + per-room `PuzzleController` wiring (`BLUEPRINT.md` semantics, 2026-07-06): plate pressed while any occupant (player or block) is on its cell, released on vacate; plate-driven doors open while pressed, re-lock on release; controller wires plate->door signals at `_ready()` | Kayden 2026-07-06 plate spec; depends on T-023 (block is one of the two pressers) | `game/scripts/puzzles/pressure_plate.gd`, `game/scripts/puzzles/puzzle_controller.gd`, door script | Unit tests: press/release transitions for player and block, door re-locks on step-off; smoke-test extension | `TASKBOARD.md` proof row | agent | ready | 2026-07-06 |
| T-025 | 10 | **Phase 2**: jump + pits/ledges - pit tile type (blocks walking, not lethal); contextual grid-snapped jump at pit/ledge edges (Tween arc, **max exactly 1 cell** - the locked limit); `PushableBlock` pushed into a pit fills it into walkable floor permanently. The tutorial's pit is **2 cells wide** (round 2): unjumpable as-is, crossed by filling one cell with the block then jumping the remaining 1-cell gap from the filled cell | Kayden 2026-07-06: jump over ledges/pits; movement roadmap row 2; round 2: pit widened so the block push is mandatory; depends on T-023 for block-fills-pit | `game/scripts/overworld/player.gd`/`grid_actor.gd`, `room_grid.gd` (pit cells), `pushable_block.gd` | Unit tests: 1-cell pit jumpable, 2-cell not, filled pit walkable + jumpable-from, unfilled pit blocks pathing; windowed feel-check of the jump arc | `TASKBOARD.md` proof row; `BLUEPRINT.md` already carries the jump invariant | agent | ready | 2026-07-06 |
| T-026 | 11 | **Phase 2**: `Chest` interactable + chest-key flow - locked chest (opens only with its matching key item, reusing the locked-door key-check pattern), **visible in the room from the start** (no reveal trigger - round 2), enemy loot can carry the chest key, opening grants the shield as a plain inventory item (D-001 resolved) | Kayden 2026-07-06 tutorial spec (Rooms 1+3); round 2 dropped the ceiling-drop reveal | `game/scripts/puzzles/` or `overworld/` chest script, loot flow in `scene_manager.gd` | Unit tests: locked chest refuses without key, opens with key, reward granted once; smoke-test extension | `TASKBOARD.md` proof row | agent | ready | 2026-07-06 |
| T-029 | 12 | **Phase 2**: death/respawn system - party defeat outside the dungeon respawns at the old man (healer NPC); defeat inside the dungeon respawns in Room 1 with the dungeon's puzzle state fully reset ("you have to redo it all"). Replaces whatever combat-defeat dead-end exists today. **TBD at build time (flag to Kayden): does the chest key survive an in-dungeon death?** (classic Zelda keeps keys; a literal "redo it all" loses it) | Kayden 2026-07-06 round 2 respawn spec; needed before T-027 makes the dungeon survivable | `game/scripts/autoload/scene_manager.gd`, combat defeat path, dungeon room state | Unit tests: defeat-outside respawns at healer with state intact; defeat-inside respawns in Room 1 with puzzles reset; smoke-test extension covering a deliberate loss | `TASKBOARD.md` proof row; `BLUEPRINT.md` already carries the respawn rule | agent | ready | 2026-07-06 |
| T-027 | 13 | **Phase 2 integration**: build the 3-room tutorial dungeon per `BLUEPRINT.md` -> Phase 2 Target (Room 1 **hub**: lock-behind + block 2-forward-1-right onto plate + visible locked chest, connected to the two other rooms; Room 2: full-width **2-wide** pit, block-then-jump crossing; Room 3: enemy drops chest key; loop back -> open chest -> shield). Author rooms via the LDtk pipeline if T-011 has landed, code-built otherwise. **This is Phase 2's "done" condition** | Kayden 2026-07-06: "a good tutorial, and a good place to call phase 2"; depends on T-022..T-026 + T-029 | `game/assets/levels/` or `game/scripts/dev/`, room scenes, smoke test | End-to-end smoke test through all 3 rooms (solve plate puzzle, fill pit + jump, kill key enemy, loop back, open chest, shield granted; plus a death-and-respawn pass) and Kayden's windowed playthrough | `TASKBOARD.md` proof row + demo artifact; `BLUEPRINT.md` Current Product Shape status | agent | ready | 2026-07-06 |

## Backlog

Valid, scoped work that is not a stretch goal but is intentionally not next.
Distinct from Deferred (which is Gameplan §17 stretch goals gated behind the
whole MVP).

| ID | Priority | Task | Why deprioritized | Revisit trigger | Status |
|---|---:|---|---|---|---|
| T-002 | low | M0.3: set up export presets for macOS, Windows, Android (debug); produce one trivial build per platform (`game/export_presets.cfg`) | The only remaining Phase 0 item, but Kayden's 2026-07-05 call is that per-platform distribution is premature while the game is still placeholder art - it doesn't block any Phase 1 work. Proof when done: one exported build per platform runs and shows the current scene | Once Phase 1 real-art/LDtk pipeline (T-003/T-004/T-011) has produced something worth building for a device, or Kayden wants an Android smoke test | deferred |
| T-028 | low | Enemy aggro telegraph: when an ooze/slime spots the player (crosses the notice radius and switches from wander to chase), show it - visibly "angry" (sprite/animation change), faster step cadence, and/or another clear cue. The player should always know they've been spotted | Kayden 2026-07-06 (his real meaning behind the movement table's "attack lock-in"): "the oozes being angry and getting faster and some other visible cue to let me know I've been spotted" - explicitly "a task for later"; needs real sprites to telegraph with | After T-003 lands real enemy sprites (a speed-up alone could ship sooner if wanted) | deferred |

## Bugs

From Kayden's windowed playtests of the slice (2026-07-05, third session).
Fixes implemented on branch `fix/playtest-bugs` (off `integration`),
headless-verified (26/26 smoke test), and **opened as a PR into
`integration`** ([#2](https://github.com/KaydenClark/Dungeon_Friends_Game/pull/2)).
Kayden confirmed B-01/B-02/B-03 in windowed play; B-04 movement is "good
enough" and left `needs-review` for a later feel-tuning pass.

| ID | Priority | Bug (reported) | Root cause | Fix | Touches | Status |
|---|---:|---|---|---|---|---|
| B-01 | 1 | NPC dialogue was hard to exit - "no gap or pause"; and (2nd report) still couldn't exit unless walking away as the last line ended | (1) No per-line advance debounce. (2) Deeper cause: the player *polls* interact each frame, so the same press that closed the box re-opened it the next frame (walking away worked because movement out-prioritizes interact) | (1) Per-line `ADVANCE_COOLDOWN_MS` (220ms). (2) `SceneManager.last_ui_close_ms` + a 250ms interact lockout in `player.gd` after any dialogue closes | `game/scripts/ui/dialogue_box.gd`, `game/scripts/autoload/scene_manager.gd`, `game/scripts/overworld/player.gd` | gated |
| B-02 | 2 | Slime "moved opposite of me" and engaged too soon; and (2nd report) it only moves when the player moves - freezes when you stand still | (1) Pure random-walker (the "opposite" was coincidence). (2) It stepped only on `player_moved` (the synchronized-turn model), so it froze whenever the player did | (1)+(2) Autonomous timer-driven movement (`STEP_INTERVAL` 0.35s): wander until player within `TRACK_RADIUS` (4 tiles), then A*-chase continuously; spawn moved (9,4)->(14,4). **Retires the documented synchronized-turn invariant** (BLUEPRINT updated) | `game/scripts/overworld/overworld_enemy.gd`, `game/scripts/dev/forest_slice.gd` | gated |
| B-04 | 1 | Walking sometimes moved two cells from a single tap | Player read movement with `is_action_pressed` (held) and re-stepped the instant the 0.15s move tween finished, so any tap held longer than ~0.15s produced a second step | Delayed-auto-shift: a fresh press is always exactly one step; continuous walking only engages after the direction is held past `MOVE_REPEAT_DELAY` (0.2s), then repeats at move cadence. Kayden: "good enough" - **left flagged for a later feel-review pass** (repeat delay/cadence may want tuning). *2026-07-06: that feel pass happened - T-021 reworked the input layer (hold matures through the tween, turn-in-place, last-pressed-wins) with the tap=one-step contract now unit-tested; gate moved to T-021's windowed check* | `game/scripts/overworld/player.gd` | gated (via T-021) |
| B-03 | 3 | Combat felt "auto" / hard to track | Only input was a tiny bottom-left Attack/Defend toggle; everything else auto-ran on fixed timers, so it read as a cutscene | Pokemon-style two-tier menu ("What will Hero do?" -> Fight/Defend; Fight -> Swing Sword / Back) with a panel + prompt; hero now steps in, swings, and returns to their side each turn | `game/scripts/combat/combat.gd` | gated |

## In Progress

| ID | Priority | Task | Owner | Started | Touches | Current note | Proof required | Status |
|---|---:|---|---|---|---|---|---|---|
| - | - | none in progress | - | - | - | - | - | - |

## Blocked

Use this lane for roadblocks, slowdowns, and risks that affect current or
near-term work. If a blocker becomes a stable architectural risk, summarize it
in `BLUEPRINT.md`.

| ID | Task / area | Blocked on | Evidence | Next action | Owner | Status |
|---|---|---|---|---|---|---|
| - | none blocked | - | - | - | - | - |

## Deferred

Valid work that should not be started yet - the Gameplan §17 stretch goals,
sequenced. Equipment and elemental/magic are flagged highest-priority-after-
MVP given this project's emphasis on weapon variety and magic (see
`BLUEPRINT.md` -> Design Decisions), but none of these start before the MVP
(Phases 0-6) is complete - see `AGENTS.md` -> Work Selection.

| ID | Task | Deferred until | Why it matters | Revisit trigger |
|---|---|---|---|---|
| S-001 | Equipment system: extend `ItemData` (`equip_slot`, `stat_modifiers`) + an equipment menu | MVP (Phases 0-6) complete | Highest-priority stretch given the founding vision's weapon-variety emphasis; pure UI+data work on existing `CharacterStats` | After M6.5 polish pass |
| S-002 | Elemental counter-system: populate `AbilityData.element` + enemy weaknesses; damage-multiplier checks | MVP (Phases 0-6) complete | Highest-priority stretch given the founding vision's magic emphasis; additive to the existing damage formula | After M6.5 polish pass |
| S-003 | Telegraphed combat UI (show enemy intended target/action before the player commits) | MVP (Phases 0-6) complete | Mostly UI + an extra "decide enemy actions" sub-phase; doesn't change the Battle FSM's shape | After M6.5 polish pass |
| S-004 | Traversal/Psynergy-style abilities (mark `AbilityData.overworld_use`, interact with tagged overworld objects) | MVP (Phases 0-6) complete | Builds on the Phase 2 puzzle primitives | After M6.5 polish pass |
| S-005 | Ikari/Djinn-style resource-gauge mechanics tied to equipment/party collection | MVP (Phases 0-6) complete | Most architecturally involved stretch item - tackle only after S-001 to S-004 are stable | After S-001 to S-004 land |
| S-006 | More dungeons + full overworld map (castle city, mountains, rivers) | MVP (Phases 0-6) complete | Pure content work on the established pipeline; ties directly to the founding vision's world-progression arc | After M6.5 polish pass |
| S-007 | Cosmetic CRT/scanline/color-grading shader (optional, screen-space post-process) | MVP (Phases 0-6) complete | Purely optional polish, never load-bearing; test per-platform with a settings toggle | After M6.5 polish pass |
| S-008 | Roguelike postgame (randomized dungeon generator, stripped-stats mode) | Core game feature-complete | Large, separate system - long-tail replayability only | Once core game is feature-complete |
| S-009 | Dash/roll overworld movement (movement-state roadmap row 4, Kayden 2026-07-06) | Phase 2 tutorial dungeon (T-027) shipped and T-021 movement feel confirmed in windowed play | "Makes overworld feel better" - but it's polish on top of the core walk feel, which must be right first | After T-027 lands and Kayden signs off on T-021 feel |
| S-010 | Swim / water traversal (movement-state roadmap row 5, Kayden 2026-07-06) | Post-MVP world expansion | "First major traversal upgrade" - pairs naturally with the rivers region of the world-progression arc (forest -> castle city -> mountains -> rivers) | When S-006 world expansion reaches the rivers region |

## Done

| ID | Task | Completed | Result | Proof row |
|---|---|---|---|---|
| T-001 | M0.2: Godot project scaffold - Mobile renderer, Nearest filter, 240x160 viewport/integer scale, `main.tscn` with `SceneManager` autoload + placeholder background | 2026-07-05 | pass | See Proof Log row 2026-07-05 |
| T-005 | Repo doc update: replace fixed 240x160/GBA-locked resolution language with flexible HD/ultrawide display language | 2026-07-05 | pass (docs); resolution switch confirmed by a real headless run in the second session | See Proof Log rows 2026-07-05 (T-005/T-006/T-007) and (T-005/T-006/T-007 follow-up) |
| T-006 | Project settings: `game/project.godot` updated to `canvas_items`/`expand`/`fractional` at a 1280x720 design reference (Nearest filter unchanged) | 2026-07-05 | pass - confirmed by a real headless run in the second session (`--import` + `main.tscn --quit-after 1` both exit 0) | See Proof Log rows 2026-07-05 (T-005/T-006/T-007) and (T-005/T-006/T-007 follow-up) |
| T-007 | Display test scene: `game/scenes/dev/display_scaling_spike.tscn` + `game/scripts/dev/display_scaling_spike.gd` - placeholder tile grid + resolution label, sized dynamically to `get_viewport_rect().size` | 2026-07-05 | pass - confirmed by a real headless run at all 3 resolutions in the second session; note headless mode can't actually validate per-resolution viewport sizing (see RUNBOOK caveat) | See Proof Log rows 2026-07-05 (T-005/T-006/T-007) and (T-005/T-006/T-007 follow-up) |
| T-015 | Design clarification: lock in GBA-fantasy-adventure visual language (8x8/16x16 tile logic), confirm the general explore -> interact -> act -> consequence loop, and define grid-based/per-unit-initiative/d10 combat | 2026-07-05 | pass (docs only, no code touched) | See Proof Log row 2026-07-05 (T-015) |
| T-009 | Input map: 8 actions (`move_up/down/left/right`, `interact`, `confirm`, `cancel`, `menu`) with keyboard bindings in `game/project.godot` | 2026-07-05 | pass - smoke test asserts all 8 exist with >=1 binding | See Proof Log row 2026-07-05 (T-009) |
| T-010 | Grid-snapped player movement, wall collision, camera follow (`GridActor`/`Player` + `RoomGrid`, Tween-based, AStarGrid2D no-diagonal pathfinding) | 2026-07-05 | pass - headless smoke-verified | See Proof Log row 2026-07-05 (T-010) |
| T-012 | Interaction system: faced-cell `interact` (NPC dialogue via `DialogueBox`, locked door), bump-contact enemy encounter trigger. Cell-occupancy checks used instead of `Area2D` (fits the everything-rests-on-grid invariant); revisit if free-positioned triggers are ever needed | 2026-07-05 | pass - headless smoke-verified | See Proof Log row 2026-07-05 (T-012) |
| T-013 | Combat scene + transition - deliberately built past the "empty shell" scope on Kayden's play-testable instruction: minimal but real grid battle (initiative by speed, AStarGrid2D movement, melee-adjacent, d10 rolls, Attack/Defend) with fade transition and exact-position overworld restore | 2026-07-05 | pass - headless smoke-verified; formulas are placeholders pending Phase 3/4 red/green | See Proof Log row 2026-07-05 (T-013) |
| T-014 | Proof log rows for the completed task batch | 2026-07-05 | pass - rows appended below | This row |
| T-016 | First-playable slice integration (forest room + NPC + enemy + combat + key + door + goal) with end-to-end headless smoke test | 2026-07-05 | pass - 26/26 checks, exit 0; Kayden's windowed play-check also passed | See Proof Log row 2026-07-05 (T-016) |
| T-017 | Promote `integration` -> `main`: committed the slice to a new `integration` branch, Kayden play-checked it, then fast-forward-merged into `main` on his explicit go-ahead | 2026-07-05 | pass - `main` at `097ced0`, all 3 headless checks re-confirmed post-merge | See Proof Log row 2026-07-05 (T-017) |
| T-018 | Expanded ~5-minute playtest (Kayden's request, fourth session): 34x20 tree-filled forest, 7 roaming slimes + leashed Boss Slime holding the key by the door, red-triangle enemy art (overworld + combat), healer NPC, HP/XP/key HUD, boss/regular loot split (`boss_slime.tres` / `forest_slime.tres`) | 2026-07-05 | pass (headless) - smoke test rebuilt to 34 checks, 5/5 consecutive PASS runs; Kayden's windowed play-check pending | See Proof Log row 2026-07-05 (T-018) |
| T-019 | First-party headless unit-test layer under `game/tests/` (base `gd_test.gd`, reflective runner `run_tests.tscn`, 9 suites) covering pure/deterministic logic (combat d10 math, `RoomGrid`, `GridActor.try_step`, `.tres` data + boss-key/door invariant, dialogue advance/cooldown, enemy AI branches, SceneManager victory rewards/heal); test-the-real-path refactors extracted `CombatScene.hit_threshold`/`needed_roll`/`attack_damage` and `SceneManager.apply_victory_rewards`/`heal_hero_to_full` | 2026-07-05 | pass (headless) - `UNIT TESTS: PASS` (9 suites, 54 tests, 149 checks, 0 failed); negative control gates (exit 1); slice smoke test still 34/34. On branch `test/automated-test-suite` | See Proof Log rows 2026-07-05 (T-019) and (T-019 cont.) |

## Documentation Check

Documentation is part of done. Before marking a task complete, check:

| If the task changed... | Update or confirm |
|---|---|
| Vision, architecture, data model, invariants, design decisions | `BLUEPRINT.md` |
| Task queue, blockers, deferred work, proof of completed work | `TASKBOARD.md` |
| Setup, run, build/export, verification procedure | `RUNBOOK.md` |
| Public-facing usage, project description | `README.md` |
| Agent rules, scope, authority, verification policy | `AGENTS.md` |

If no docs need edits, record `Docs checked; no update needed` in the final
response and in the proof row's `Docs` field.

## Proof Log

Append a row when a task changes durable project state or produces durable
verification evidence. Use actual results, not stale claims. Milestone tasks
must fill the Demo column with a <1-minute demo artifact; non-milestone rows
may use `n/a`.

**Archival policy.** The proof log is append-only, but it should not grow
without bound. When it passes ~30 rows, move the oldest rows (keep the most
recent ~30 here) into `TASKBOARD_ARCHIVE.md`, preserving them verbatim under a
dated heading.

| Date | Task ID | Agent | Proof | Demo | Result | Docs | Remaining gap |
|---|---|---|---|---|---|---|---|
| 2026-07-05 | T-001 | Claude | `Godot --headless --path . --import` (exit 0, no errors) + `Godot --headless --path . scenes/main.tscn --quit-after 1` (exit 0, no errors, `SceneManager ready.` printed) | Placeholder `main.tscn` scene (dark background, 240x160 integer-scaled) confirmed via headless run log | pass | updated (`BLUEPRINT.md`, `AGENTS.md`, `CLAUDE.md`, `RUNBOOK.md`, `TASKBOARD.md`, `HARNESS_FEEDBACK.md`, `README.md`, `.claude/settings.json` created via Adoption; old `AGENTS.md`/`CLAUDE.md` archived to `docs/LEGACY_HARNESS.md`; `docs/planning/Gameplan.md`/`docs/research/audited_research.md` kept as linked references) | Export presets (M0.3) not yet configured - next task (T-002) |
| 2026-07-05 | T-005/T-006/T-007 | Claude | Commands to run (not yet run by an agent - see Result): `cd game && Godot --headless --path . --import` ; `Godot --headless --path . scenes/main.tscn --quit-after 1` ; `Godot --headless --path . scenes/dev/display_scaling_spike.tscn --resolution 1280x720 --quit-after 1` ; `Godot --headless --path . scenes/dev/display_scaling_spike.tscn --resolution 1920x1080 --quit-after 1` ; `Godot --headless --path . scenes/dev/display_scaling_spike.tscn --resolution 3440x1440 --quit-after 1`. What Claude actually verified: (1) `grep -rni "240x160\|GBA\|Game ?Boy" BLUEPRINT.md Gameplan.md TASKBOARD.md README.md AGENTS.md RUNBOOK.md` returns no hits except the explicitly-marked superseded/historical rows in `BLUEPRINT.md`/`Gameplan.md`; (2) manual review of the edited `project.godot`, `main.tscn`, `display_scaling_spike.tscn`/`.gd` for syntax correctness | n/a - no screenshot/recording possible without a display or Godot runtime in this environment | **pending** - this sandbox has no Godot binary and no macOS runtime, so the 5 commands above have not actually been executed. Do not treat this as a passing headless run. Kayden: please run the 5 commands on your Mac and append the real exit codes/output as a follow-up proof row (or tell an agent to) before trusting this settings change | updated (`BLUEPRINT.md`, `docs/planning/Gameplan.md`, `README.md`, `TASKBOARD.md`, `AGENTS.md`, `RUNBOOK.md`; new files `game/scenes/dev/display_scaling_spike.tscn`, `game/scripts/dev/display_scaling_spike.gd`; edited `game/project.godot`, `game/scenes/main.tscn`) | Real headless verification of the resolution switch on Kayden's Mac; grid-unit decision still TBD at M1.1; folder-structure task (T-008) untouched |
| 2026-07-05 | T-015 | Claude | Read `BLUEPRINT.md`, `TASKBOARD.md`, `docs/planning/Gameplan.md` in full; checked Kayden's visual-language table, first-playable-loop statement, and combat-loop statement against locked decisions (flexible-HD rendering, two-layer combat FSM) - confirmed no contradiction; the only stale detail was the Battle FSM's `PlayerPhase`/`EnemyPhase` state names, which had drifted out of sync with the `TurnManager`'s always-described sort-all-combatants-by-speed behavior, now corrected to match | n/a - docs-only change, no runnable demo | pass | updated (`BLUEPRINT.md`: What This Project Is, new Visual Language section, Current Product Shape, Core Logic And Invariants, Data Model note, Known Risks, Design Decisions, Non-Goals; `TASKBOARD.md`: this row, Executive Brief, T-003/T-013 descriptions, Done lane; `docs/planning/Gameplan.md`: short revision-pointer note only, matching the precedent set by the 2026-07-05 resolution-switch revision line) | Exact d10 threshold/damage formula, move/attack-range numeric values, and combat-grid arena sizing all remain open for Phase 3/4 implementation (flagged as TBD, not invented here); Gameplan.md §2/§7 prose itself not rewritten, pointer only |
| 2026-07-05 | T-005/T-006/T-007 (follow-up) | Claude | Ran all 5 pending commands for real on Kayden's Mac (Godot 4.6.3.stable.official.7d41c59c4): `--import` exit 0; `main.tscn --quit-after 1` exit 0 with `SceneManager ready.`; spike scene at `--resolution` 1280x720 / 1920x1080 / 3440x1440 all exit 0, no ERROR/SCRIPT ERROR lines. Caveat discovered: headless mode has no real window, so `--resolution` is ignored and the spike prints `viewport=(1280.0, 1280.0)` at all three sizes - the RUNBOOK's "viewport matches requested resolution" expectation is only checkable in a windowed run | n/a (headless) | pass (settings valid, no errors); windowed visual confirmation of the three resolutions still Kayden's to do | RUNBOOK spike expectation corrected | Windowed multi-resolution visual check |
| 2026-07-05 | T-009 | Claude | Smoke test (`scenes/dev/slice_smoke_test.tscn`) asserts `InputMap.has_action` + at least one bound event for all 8 actions - 8/8 ok, part of the 26/26 pass | n/a | pass | `BLUEPRINT.md` Commands table already matched; no update needed | Controller/touch bindings deferred (keyboard only so far) |
| 2026-07-05 | T-010 | Claude | Smoke test: player walked exactly 3 grid steps up from spawn, was blocked by the tree wall at y=1, `player.position == room.cell_to_pos(player.cell)` after movement (rests exactly on grid), camera is current. Movement is Tween-based (0.15s/step) via `GridActor`; `RoomGrid` wraps AStarGrid2D (DIAGONAL_MODE_NEVER, Manhattan) | Run `main.tscn` and walk around (WASD/arrows) | pass | `BLUEPRINT.md` scene contracts updated | Held-key repeat feel needs Kayden's windowed judgment |
| 2026-07-05 | T-012 | Claude | Smoke test: NPC dialogue opened via faced-cell interact and closed after advancing; locked-door interact shows locked/unlock dialogues; enemy bump started an encounter. Implementation is grid-occupancy-based (`interact` targets `cell + facing`), not `Area2D` - simpler and consistent with the everything-on-grid invariant | Walk to the NPC and press E | pass | Done-lane note records the Area2D deviation | Chest pickup as a distinct interactable type not yet built (key comes from combat loot) |
| 2026-07-05 | T-013 | Claude | Smoke test: enemy contact faded into `CombatScene` (CanvasLayer, camera-independent), battle ran per-unit initiative with AStarGrid2D approach movement and d10 rolls (log lines printed each roll), victory returned to the overworld with the player at the exact pre-combat cell and 19-20/20 HP carried back. Scope note: built as a real minimal battle, not an empty shell, per Kayden's instruction | Bump the slime in `main.tscn` | pass | `BLUEPRINT.md` combat scene row updated; formulas marked placeholder for Phase 3/4 | Real Phase 4 combat: two-layer FSM states as classes, Ability/Item commands, multi-unit parties, camera-zoom transition |
| 2026-07-05 | T-016 | Claude | `Godot --headless --path game scenes/dev/slice_smoke_test.tscn` -> `SLICE SMOKE TEST: PASS (26/26 checks)`, exit 0 (seeded RNG 1234; covers input map, movement/collision, NPC dialogue, encounter, combat victory, key drop, enemy removal, HP carry-back, world restore, door unlock, goal completion flag). Known noise: benign `ObjectDB instances leaked` warning at test exit (quit mid-coroutines). Also re-ran `--import` (exit 0) and `main.tscn --quit-after 3` (exit 0, no errors) | One command, ~15s: `cd game && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn` | pass | `TASKBOARD.md`, `BLUEPRINT.md`, `RUNBOOK.md`, `README.md` updated this session | Kayden's windowed play-check (feel, readability, combat pacing); no save/load, single party member, one enemy type - all later phases |
| 2026-07-05 | B-04 + copy | Claude | Third round from Kayden's playtest: fixed double-step movement (B-04) with delayed-auto-shift in `player.gd`, and changed the slice-complete line from "First playable slice complete - thanks for testing, Kayden!" to "The adventure continues...". Re-verified headless on `fix/playtest-bugs`: `--import` clean; `slice_smoke_test.tscn` PASS 26/26 across 3 runs (movement change doesn't touch the test path, which drives `try_step` directly - runs confirm no syntax/load regressions). | `Godot --headless --path . scenes/dev/slice_smoke_test.tscn` -> 26/26 | pass (headless); windowed feel-check still Kayden's | `TASKBOARD.md` Bugs lane B-04 + this row; no `BLUEPRINT.md` change (input-feel tuning, not a contract/invariant) | Windowed confirmation that single taps now move one cell and hold-to-walk still feels right |
| 2026-07-05 | B-01/B-02 (round 2) | Claude | Second-pass fixes after Kayden re-tested: B-03 combat confirmed good by Kayden and closed. B-01 dialogue still couldn't be exited by pressing E (root cause was the player re-opening it via same-frame interact polling, not the dialogue box) - fixed with a 250ms post-close interact lockout. B-02 slime was freezing when the player stood still - reworked to autonomous timer-driven movement (retires the synchronized-turn invariant, BLUEPRINT updated). Re-verified headless on `fix/playtest-bugs`: `--import` clean, `main.tscn --quit-after 3` clean, and `slice_smoke_test.tscn` PASS 26/26 across **5 consecutive runs** (checked for timing flakiness since enemy movement is now real-time). | `for i in 1 2 3 4 5; do Godot --headless --path . scenes/dev/slice_smoke_test.tscn; done` -> 5/5 PASS (26/26) | pass (headless); windowed feel-check still Kayden's | `BLUEPRINT.md` invariant + Design Decisions row updated (synchronized -> autonomous); `TASKBOARD.md` Bugs lane B-01/B-02 rows + this row | Windowed confirmation of dialogue exit + slime wander/chase feel; then promote to `integration` |
| 2026-07-05 | B-01/B-02/B-03 | Claude | Bug-fix pass from Kayden's playtest, on branch `fix/playtest-bugs` off `integration`. Headless re-verified on the branch: `--import` clean (no script errors); `main.tscn --quit-after 3` boots clean (`SceneManager ready.`, no ERROR lines); `slice_smoke_test.tscn` -> `SLICE SMOKE TEST: PASS (26/26 checks)`, exit 0 (seeded RNG 1234). B-01 dialogue debounce, B-02 slime hybrid random-then-track AI + spawn moved to (14,4), B-03 Pokemon-style two-tier combat menu + swing-and-return. | `cd game && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn` (26/26) | pass (headless); windowed feel-check is Kayden's | `TASKBOARD.md` Bugs lane + Executive Brief updated; scene contracts unchanged (no `BLUEPRINT.md` edit needed - combat is still the same MVP shape, just clearer UI) | Windowed confirmation of dialogue feel, slime approach, and combat menu/readability; then promote `fix/playtest-bugs` -> `integration` |
| 2026-07-05 | T-018 | Claude | Expanded playtest on `feature/expanded-playtest` (stacked on `fix/playtest-bugs`). Map layout pre-validated with a scratchpad BFS script (row widths, connectivity, goal sealed until door opens, no dead pockets). Headless on the branch (Godot 4.6.3): `--import` exit 0; `main.tscn --quit-after 3` exit 0, no errors; rebuilt `slice_smoke_test.tscn` -> `PASS (34/34 checks)` on **5/5 consecutive runs** (covers: roster of 8 enemies, only the boss carries the key, regular-fight XP-but-no-key, healer full restore, boss kill -> key -> door -> goal; navigation is encounter-tolerant since slimes roam autonomously) | `cd game && for i in 1 2 3 4 5; do /Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn; done` -> 5/5 PASS (34/34) | pass (headless); windowed ~5-min feel-check is Kayden's | `BLUEPRINT.md` Current Product Shape status para; `RUNBOOK.md` smoke-test expectation (34/34 + rerun advice); `TASKBOARD.md` this row + Done lane + Executive Brief | Windowed play-check: pacing (is it actually ~5 min?), boss difficulty (16 HP / atk 3 vs hero 20 HP), triangle readability; combat is still 1v1-only; balance numbers are placeholders pending Phase 3/4 |
| 2026-07-05 | T-019 | Claude | Added a first-party headless unit-test layer under `game/tests/` (base `gd_test.gd`, reflective runner `run_tests.tscn`, 6 suites) covering the pure/deterministic logic: combat math, `RoomGrid` (bounds/blocking/occupancy/AStar/avoid-occupants), `GridActor.try_step`, the shipped `.tres` data + boss-key/door invariant, `DialogueBox` advancement, `OverworldEnemy._manhattan`/`defeated()`. To test the *real* path (not a copy), extracted combat's d10 math into static `CombatScene.hit_threshold`/`needed_roll`/`attack_damage` that `_attack` now calls (behavior-identical). Verified on Godot 4.6.3: `tests/run_tests.tscn` -> `UNIT TESTS: PASS` (6 suites, 38 tests, 129 checks, 0 failed), exit 0; negative control (corrupt one expected value) -> `UNIT TESTS: FAIL`, exit 1, so the harness genuinely gates; existing `slice_smoke_test.tscn` still `PASS (34/34)` after the combat refactor. | `cd game && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn` -> `UNIT TESTS: PASS` (~1-2s) | pass (headless) | `RUNBOOK.md` new "Unit tests" section + rewritten "Test Coverage Policy" (three verification layers, test-the-real-path rule); `TASKBOARD.md` this row. No `BLUEPRINT.md` change (the combat extraction is behavior-identical, not a contract/invariant change) | Async/timer-driven paths (SceneManager encounter loot loop, enemy wander/track AI, DialogueBox input cooldown) remain covered only by the E2E smoke test, not unit-isolated; no XP-curve/leveling logic exists yet to test |
| 2026-07-05 | T-019 (cont.) | Claude | Extended the unit layer to the async/timer-driven gaps flagged in the first pass, on branch `test/automated-test-suite`. Added `test_scene_manager` (victory XP accrual, loot added + de-duplicated, lootless enemy drops nothing, banner text, heal-to-full), `test_enemy_ai` (deterministic `_act`/`_step_toward`/`_step_home`/`_wander` branches: closes distance in range, contacts-not-steps when adjacent, returns home when leashed+strayed, idles at zero leash), and `test_dialogue_cooldown` (real `_unhandled_input` debounce via a controlled `_last_input_ms` clock - swallow within window, advance after, burst advances once, cancel action also gated). To test the real path, extracted `SceneManager.apply_victory_rewards`/`heal_hero_to_full` (the latter now also used by the healer NPC, de-duplicating an inline copy). Runner now `await`s each test so coroutine tests are possible. Verified on Godot 4.6.3: `UNIT TESTS: PASS` (9 suites, 54 tests, 149 checks, 0 failed) on 3/3 consecutive runs; negative control on `test_scene_manager` -> exit 1; slice smoke test still `PASS (34/34)` after the SceneManager/NPC refactor. | `cd game && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn` -> `UNIT TESTS: PASS` | pass (headless) | `RUNBOOK.md` Unit tests section (suite list + counts + await note); `TASKBOARD.md` this row | Two mid-work test-side bugs were caught by the harness and fixed (a default `home_cell` making a "strayed" enemy already-home; a flaky wall-clock timer replaced by a controlled clock). The full fade/combat/return encounter loop is still only covered E2E by the smoke test, not unit-isolated |
| 2026-07-05 | T-017 | Claude | Kayden completed his windowed play-check of the first-playable slice and confirmed it's ready. Committed the slice to a new `integration` branch (commit `097ced0`), then fast-forward-merged `integration` -> `main` (`git merge --ff-only integration`, 199561c..097ced0, no conflicts) on Kayden's explicit "promote integration" instruction. Re-ran all 3 headless checks (`--import`, `main.tscn --quit-after 3`, `slice_smoke_test.tscn`) on `main` post-merge - all exit 0, smoke test still 26/26 | Local `main` now at 097ced0, matches what Kayden play-tested on `integration` | pass | `AGENTS.md`/`RUNBOOK.md`/`BLUEPRINT.md` branch-flow rows updated to the `integration`-staging convention prior to this merge; this row | `main` is 5 commits ahead of `origin/main` - not yet pushed, pending Kayden's confirmation |
| 2026-07-06 | T-021 | Claude | Movement feel rework on `feature/movement-feel` (stacked on `test/automated-test-suite`, whose unit harness it needs). Rewrote `player.gd`'s input layer around a pure `_movement_intent(dir, delta)` state machine the real `_process` calls: (1) hold time now matures *through* the move tween, killing the 0.2s dead stop after the first held step (residual tap-safety beat: ~0.08s, tunable); (2) Pokemon-style turn-in-place - tapping a new direction faces it without stepping, holding past `TURN_DELAY` (0.1s) walks, and the turn time counts toward the walk so there's no second pause; (3) last-pressed-wins direction stack (rolling between keys mid-walk is seamless, releasing falls back to the still-held key); (4) fresh same-direction presses during a tween are buffered to land the frame the move ends; (5) B-04's tap=exactly-one-step contract preserved and now unit-tested. New suite `test_player_movement` (12 tests, 27 checks) drives the real intent function with hand-fed deltas + `Input.action_press` rollover. Verified (Godot 4.6.3): unit tests `PASS` **3/3 consecutive runs** (10 suites, 65 tests, 176 checks, exit 0); negative control (corrupt the tap=one-step expectation) -> `CHECK FAILED`/suite FAIL, then restored; `--import` exit 0, 0 error lines; `main.tscn --quit-after 3` exit 0; `slice_smoke_test.tscn` `PASS (34/34)` **5/5 consecutive runs** | `cd game && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn` (~2s) then walk around in `main.tscn`: tap to turn, hold to walk, roll between directions | pass (headless); **windowed feel-check is Kayden's gate** - tuning knobs are `MOVE_REPEAT_DELAY` (0.2) and `TURN_DELAY` (0.1) in `player.gd` | `RUNBOOK.md` unit-test counts + suite list; `TASKBOARD.md` this row + T-021 gated + B-04 -> gated-via-T-021; no `BLUEPRINT.md` change (implements the already-documented feel bar) | Windowed judgment: does turn-in-place feel right at 0.1s, is the ~0.08s first-step beat perceptible, does hold-walk cadence read smooth? Camera smoothing untouched; deliberate swallow: a tap *released* mid-tween is dropped (anti-double-step) - flag if quick double-taps feel eaten |
