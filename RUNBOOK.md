# Dungeon Friends - Runbook

> Generated from LLM Workbench v2.3. See Upgrading The Harness below.

**Last reviewed:** 2026-07-17
**Runtime owner:** Kayden (solo developer)
**Environment:** local (macOS development machine; builds also target Windows
and Android)

This file explains how to operate, verify, recover, and evaluate the project.
It should be boring, exact, and executable.

> **Pivot note (2026-07-11):** the project's design rebooted to v2 (see
> `BLUEPRINT.md` -> V2 Systems and D-024..D-037). Every procedure below still
> applies - it operates the v1 code on disk, which stays in place until the
> linked stable specs replace each piece. Follow the dependency chain rendered
> in `TASKBOARD.md`, beginning with `S-008/TK-001`. Update
> the relevant procedure rows as v1 systems (d10 combat, arena selection,
> zoom transition, enemy respawns, single avatar) are retired. Android export
> material remains valid but is deprioritized (D-032: Steam-first, mobile
> postponed).

## Spec Workflow

Run from the repository root:

```bash
node tools/spec-workbench.mjs doctor
node tools/spec-workbench.mjs next --json
node tools/spec-workbench.mjs show S-008
node tools/spec-workbench.mjs claim S-008 --agent codex
node tools/spec-workbench.mjs close S-008 \
  --proof "named verification result" \
  --docs "updated RUNBOOK.md" \
  --remaining-gap "owner acceptance"
node tools/spec-workbench.mjs complete S-008
node tools/spec-workbench.mjs render
node tools/spec-workbench.mjs doctor
```

`next` returns only an eligible active slice. `show` loads one stable packet.
`render` changes only the marked Blueprint catalog and Taskboard projection.
Completion requires finished slices, checked acceptance, a non-pending result,
and execution evidence.

## Prerequisites

Required tools:

- Godot 4.7.x - confirmed installed at `/Applications/Godot.app`
  (`/Applications/Godot.app/Contents/MacOS/Godot --version` ->
  `4.7.stable.official`). Upgraded from 4.6.x on 2026-07-07 (Kayden's call);
  `project.godot` declares `4.7` and the whole suite verifies clean on it.
- Git.

Required accounts/services:

- GitHub (`KaydenClark/Dungeon_Friends_Game`) for push/PR.
- Later, for Android export only: OpenJDK 17, Android SDK Platform-Tools
  >=35.0.0, NDK - not required for current desktop gameplay work.

Required local files:

- None. This project has no backend, no accounts, and no API keys, so there
  are no `.env`-style secrets. The one sensitive-file category is Android
  release keystores (`.jks`/`.keystore`) - never required until a real
  Android release build, and never committed (see `.gitignore`).

## Install

```bash
git clone https://github.com/KaydenClark/Dungeon_Friends_Game.git
cd Dungeon_Friends_Game
```

Expected result: the repository is present locally with `game/`, `docs/`, and
the control docs at root.

For a disposable remote-recovery check, clone the exact branch under test and
run the lifecycle doctor:

```bash
recovery_dir="$(mktemp -d /tmp/dungeon-friends-recovery.XXXXXX)"
checkpoint_branch="$(git branch --show-current)"
git clone --branch "$checkpoint_branch" --single-branch \
  https://github.com/KaydenClark/Dungeon_Friends_Game.git "$recovery_dir"
git -C "$recovery_dir" rev-parse HEAD
(cd "$recovery_dir" && node tools/spec-workbench.mjs doctor)
```

Expected result: `HEAD` matches the pushed checkpoint and doctor prints
`ok - spec workbench doctor passed`. The temporary clone can then be discarded.

## Run Locally

Open in the editor:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path game
```

Or run the main scene directly without opening the editor UI:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path game scenes/main.tscn
```

Expected result: a 1280x720 window opens (flexible HD/ultrawide `canvas_items`/
`expand` scaling, revised 2026-07-05 - see `BLUEPRINT.md` -> Design Decisions)
showing the first-playable forest slice with placeholder-generated tile and
sprite art. No console errors.

Playing the slice (updated 2026-07-10 after the latest playthrough; on-screen
prompts show keyboard keys only until T-079 supplies controller glyphs):

- WASD / arrow keys: grid-snapped movement. E: talk, interact, and confirm.
  Q: cancel/back. The controller equivalents remain D-pad, A, and X.
- Party controls (S-010/TK-003): **G** (controller L1) cycles the exploration
  formation line -> square -> spaced with a short confirmation toast; **F**
  (controller Y, the D-019 character action) switches the controlled leader
  to the next visible party member - control, camera, and sprites swap in
  place. Both persist for the session; the formation choice also persists
  into saves (older saves default to line). **5** (controller R1) casts the
  LEADER's field verb (S-013: Wren's Verdant Growth grows a vine) at the
  faced cell, spending MP - switch leaders with F to switch verbs.
- **Combat (v2 default since S-012/TK-004):** bumping an enemy enters the
  unified in-room encounter - same room, same camera, banner cue, party
  deployed in your selected formation, and the enemy's exact current intent
  plus verbs-only forecast in the top-right panel. WASD/arrows step the
  active unit (budgeted), **1** attack, **2** bash (stun-cancels the
  intention), **3** shove (push-cancels), **4** guard (protects front +
  flanks for a round), **Z** undoes un-acted movement, **Tab** switches the
  acting unit, **5** (controller R1) casts the acting unit's field verb at
  the cell toward the enemy, **Q** ends the party phase (the intention resolves, the
  environment ticks, the next round declares). Victory pays the usual
  rewards in place; a party wipe hands over to the T-041 checkpoint-defeat
  rules. The v1 arena route remains reachable via
  `SceneManager.unified_encounters = false` (the slice smoke test runs it)
  until the S-004 replay accepts retirement.
- Space/B remains reserved for a future traversal item, but no shipped room
  requires manual jumping. The tutorial route uses mechanisms instead.
- Loop: talk to the quest NPC -> bump a slime to enter an authored,
  biome-consistent tactical arena selected from the editable forest pool
  (D-018), controlling Hero + Buddy (D-013). WASD/arrows move
  the combat cursor or menu; E confirms; Q cancels or stays
  put. On each party turn, choose a highlighted destination, then
  Attack/Ability/Item/Defend (Defend appears only after earning the shield) or
  Wait. Beat the leashed Boss Slime by the east
  door for the Forest Key -> open the door and step through into the
  four-room tutorial dungeon: the entry locks behind you; a wall of 13
  bricks spans the hub and exactly one pushes free (walk into bricks to
  test them; the optional reset lever is only for returning a stuck loose
  brick to its starting cell); through the east gap, step on the brass floor
  plate to open the north gate, step off to see it close, then push the heavy
  block left onto that same plate to hold the gate open; beat the Dungeon Slime for the Dungeon
  Key; loop back through the west shortcut; unlock the hub's north door and
  open the side room's chest for the shield - the entry unbolts and you
  walk back out to the forest. The room is one continuous floor with no pits;
  its east-side lever only resets a wedged block.
- Saving and dying (Phase 3, built 2026-07-10): the cyan **save crystal**
  beside the healer's campfire writes slot 1 on interact; booting with a
  save shows a minimal Continue (E) / New Game (Q) prompt
  (D-011). If New Game was chosen while slot 1 already exists, the first
  crystal interaction asks before overwriting it; Q keeps the existing save.
  **Walking into a pit** is a Zelda-style fall: 10 HP party-wide and a walk
  back to the room's last-used entrance (T-047).
  **Party defeat** is a checkpoint, not a restart (T-041, tuned per D-014/
  D-015): keep inventory, lose 25% of your progress toward the next level,
  come back at 80% HP; in the dungeon you wake at the
  hub entrance (rooms between reset - enemies respawn on every rebuilt
  room per D-009), outside you wake by the healer. Defeat never touches
  save files.
- Dev tools (T-030, debug builds only - running from the editor or CLI
  counts; excluded from release exports): press F1 for the overlay, then
  1-5 warp to any registered map (the list IS the T-038 MapRegistry -
  T-049), R reset the room puzzle,
  6-8 grant forest_key / dungeon_key / shield, 9 heal, 0 toggle skip-combat
  (touch an enemy = instant win), P grant 3 potions (consumables have no
  in-world source yet - a T-069/Phase 5 design call; this is how to
  exercise the combat Item command meanwhile). Off by default every
  session.
- Save files live at `user://saves/slot_N.json` - on macOS:
  `~/Library/Application Support/Godot/app_userdata/Dungeon Friends/saves/`.
  To wipe saves, delete that `saves/` directory (automated runs use
  scratch dirs - `saves_smoke_test`, `saves_battery`, `saves_test*` - and
  clean up after themselves).

## Test And Build

The project has a first-party headless GDScript unit harness, a full-slice
smoke test, import/boot checks, and manual play gates. A completed gameplay
task uses all relevant layers; an import-only pass is not sufficient.

Fast check (resource/project validity):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Full verification (import + one real frame of the main scene, which also
exercises the `SceneManager` autoload):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/main.tscn --quit-after 1
```

Expected result: both commands exit `0` with no `ERROR:`/`SCRIPT ERROR:` lines;
the second command's output includes `SceneManager ready.`, confirming the
autoload initialized.

### First-playable slice smoke test (T-016)

End-to-end scripted run of the whole slice (input map, movement/collision,
NPC dialogue, enemy encounters, seeded d10 combat, key/door, then the full
Phase 2 tutorial dungeon in its current layout: hub lock-in, the
13-brick wall's one loose brick (fixed bricks refuse the push), the north
door locked without its key, step-on/step-off momentary plate demonstration,
block-held north gate with reset lever and no pits/jump, key-guardian fight -> dungeon_key, west loop back,
north door unlock, chest room -> shield -> entry unbolts, return to the
preserved forest, plus the Phase 3 save/load slice: a save-crystal write by
the campfire, forced defeats
proving the T-041 checkpoint respawns (dungeon -> fresh hub entrance,
outside -> the healer), and a final load leg rolling back to the crystal
save):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

Expected result: exit `0` and a final `SLICE SMOKE TEST: PASS (134/134
checks)` line (~40-80s; the watchdog fails the run at 180s). A benign `ObjectDB instances leaked` warning
at exit is known noise from quitting mid-coroutines; any `CHECK FAILED:` line
or exit `1` is a real failure. Because roaming enemies move on real-time
timers, run it a few times in a row when touching enemy AI or movement (`for
i in 1 2 3 4 5; do ...; done`). Run this after any change to movement,
interaction, combat, room transitions, puzzles, the LDtk pipeline, or
SceneManager.

Gotcha: `--path .` must point at `game/` (hence the `cd game`). Pointed at the
repo root by mistake, Godot finds no `project.godot` and can hang around
rather than exiting - if a headless run seems stuck forever, check the cwd
before debugging the game.

### Screenshot tour (demo artifacts)

Boots each room in a real windowed run and saves one PNG per room
(`forest/hub/pit/fight/chest.png`) - the quick per-room demo artifact for
proof rows. Needs a display: under `--headless` the dummy renderer produces
black images, so run it windowed (a window flashes up for a few seconds).

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/screenshot_tour.tscn -- --out=/tmp/dungeon_shots
```

Expected result: exit `0`, five `wrote .../<room>.png` lines and a final
`SCREENSHOT TOUR: done`. Omitting `--out=` writes into the project's
`user://screenshots` directory.

### Kenney visual-skeleton proof (T-080..T-084)

Regenerate the promoted runtime crops after changing the manifest, import
them, then render the 1280x720 contact sheet and combat showcase:

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/assets/prepare_kenney_assets.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/kenney_contact_sheet.tscn -- --out=/tmp/kenney-contact.png
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/runtime_sprite_showcase.tscn -- --out=/tmp/kenney-combat.png
```

The manifest suite checks unique names, source bounds, promoted-file presence,
and the 16px/4x/nearest contract. Windowed scenes are required for meaningful
screenshots; the headless renderer produces black visual proof.

For an under-one-second combat-art proof with Hero, Buddy, a normal slime, and
the boss slime on the tactical grid, run the dedicated runtime-sprite showcase:

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/runtime_sprite_showcase.tscn --resolution 1280x720 -- --out=/tmp/dungeon-runtime-sprites.png
```

Expected result: exit `0`, `RUNTIME SPRITE SHOWCASE: wrote ...`, and a rendered
PNG with four animated-resource units. This must be windowed; headless output
uses the dummy renderer and is not visual proof.

### Authored battle-arena gallery (T-072..T-075)

The arena pool lives in `game/assets/levels/battle_arenas.ldtk`: seven forest
levels plus `DungeonStoneHall`, all named 17x7 LDtk levels with editable `Wall` IntGrid terrain, `ArenaMetadata`,
and eight `PartyDeployment`/`EnemyDeployment` marker slots per side. The
gallery renders the actual imported levels, their metadata, deployment slots,
and the shared validator result; the showcase proves the same level reaches
the live `CombatScene` renderer.

From the current Windows checkout:

```powershell
$godot = 'E:\Godot\godot.cmd'
& $godot --headless --path game --import
& $godot --path game scenes/dev/arena_gallery.tscn -- --out="$PWD\docs\screenshots\authored_arena_gallery.png"
& $godot --path game scenes/dev/authored_arena_showcase.tscn -- --out="$PWD\docs\screenshots\authored_arena_combat.png"
```

Expected result: both windowed commands exit `0` and print `AUTHORED ARENA
GALLERY: wrote ...` / `AUTHORED ARENA COMBAT SHOWCASE: wrote ...`. Inspect the
gallery after any LDtk edit. It must show eight `VALID` cards: the forest cards
retain the 2/3/2 empty/mid/hard split and 5/2/1 per-template weights, and the
dungeon stone hall remains biome-isolated. Green/red overlays are the authored
party/enemy deployment zones. Run it windowed; headless image output is not
visual proof.

For the T-085 readability matrix, capture every deterministic combat state at
both supported review sizes:

```powershell
$godot = 'E:\Godot\godot.cmd'
& $godot --path game scenes/dev/combat_readability_tour.tscn --resolution 1280x720 -- --out="$PWD\docs\screenshots\combat-readability-1280"
& $godot --path game scenes/dev/combat_readability_tour.tscn --resolution 1920x1080 -- --out="$PWD\docs\screenshots\combat-readability-1920"
```

Each run writes seven captures covering turn start, root menu, Item submenu,
movement destination, attack result, forest battle, and dungeon battle.

### Three-quarter perspective spike (archived T-089; `S-001` proof)

The accepted foundation's readability proof:
one dev room with two integer elevation levels, a stair ramp, a tall north
wall face, and a four-member party (controlled leader + three non-blocking
breadcrumb followers). Interactive check: run the scene windowed and walk
the party up and down the stairs with WASD/arrows. Scripted proof shots:

```powershell
$godot = 'E:\Godot\godot.cmd'
& $godot --path game scenes/dev/three_quarter_spike.tscn --resolution 1280x720 -- --out="$PWD\docs\screenshots\t089-three-quarter-spike\1280"
& $godot --path game scenes/dev/three_quarter_spike.tscn --resolution 1920x1080 -- --out="$PWD\docs\screenshots\t089-three-quarter-spike\1920"
```

Each run prints `THREE-QUARTER SPIKE: ready ...`, writes four captures
(lower floor, ascending ramp, party spanning both elevations, plateau at
the chest), then `THREE-QUARTER SPIKE: done`. Run windowed; headless image
output renders black. This is throwaway spike code (`game/scenes/dev/`,
`game/scripts/dev/`) - graduating it into production is its own decision.

### Unified in-room encounter spike (T-090)

Pivot step 3's proof: an encounter that starts, plays, and resolves inside
the T-089 room with no scene change or zoom. Interactive: run
`scenes/dev/unified_encounter_spike.tscn` windowed, push the block, walk
onto the plateau near the slime (detection range 2 or direct bump starts
the fight), bump the slime to attack; the friend fights alongside and the
other two followers stand as blockers. Scripted proof:

```powershell
$godot = 'E:\Godot\godot.cmd'
& $godot --path game scenes/dev/unified_encounter_spike.tscn --resolution 1280x720 -- --out="$PWD\docs\screenshots\t090-unified-encounter\1280"
& $godot --path game scenes/dev/unified_encounter_spike.tscn --resolution 1920x1080 -- --out="$PWD\docs\screenshots\t090-unified-encounter\1920"
```

Each run writes four captures (block pushed, encounter start, attack
exchange, victory with the world continuous), prints eight `PASS:`
continuity assertions (encounter in-room, followers snap into/out of the
occupancy map, no scene change, pushed block and chest state preserved),
and exits `0`; any `FAIL:` line exits `1`. The turn model inside is a
throwaway step-tick - D-027's real turn structure is decided by T-092, not
this spike.

### Deterministic intent prototype (T-092, revised by T-097)

Pivot step 4: intent rounds on the same spike room, built to Kayden's
2026-07-11 spec and recut per the T-097 handoff. The slime keeps a rolling
3-verb plan - future steps serialize through `IntentLogic.future_verbs`
(verb only, never targets/cells), the current action telegraphs its locked
cells, exact damage, and exact status, and resolves against whoever remains
in those cells. Plan entries carry private planning context; ordinary refill
preserves already-telegraphed verbs, and a dead/changed target or illegal
head verb rebuilds the whole horizon. Encounter entry is an explicit ENTER
phase (D-036): input gates immediately (local flags, never
`SceneTree.paused`), a synthesized sting plays under an ENCOUNTER/TURN-BASED
banner, then the combat UI reveals and the first round declares. All four
visible members get move/ability budgets and act in any order. Interactive:
run `scenes/dev/intent_prototype_spike.tscn` windowed; in an encounter
WASD/arrows step the active unit, `1` Strike / `2` Bash (stun-cancels the
intention) / `3` Shove (push-cancels) / `4` Guard (guarded_cells intercepts
the spit line for an exact duration), `E` confirms with the exact damage
shown first, `Tab` switches units, `Q` ends the turn. Scripted proof:

```powershell
$godot = 'E:\Godot\godot.cmd'
& $godot --path game scenes/dev/intent_prototype_spike.tscn --resolution 1280x720 -- --out="$PWD\docs\screenshots\t097-intent-recut\1280"
& $godot --path game scenes/dev/intent_prototype_spike.tscn --resolution 1920x1080 -- --out="$PWD\docs\screenshots\t097-intent-recut\1920"
```

Each run writes ten captures (encounter cue, first intent, four-units
any-order, spit telegraph, guard-vs-line, replan-after-invalidation, stun,
victory-continuous) and prints 45 `PASS:` assertions, exiting `0`; any
`FAIL:` exits `1`. The pure rules live in `game/scripts/dev/intent_logic.gd`
with red/green coverage in `tests/test_intent_logic.gd`; the encounter builds
Sol's real T-096 four-member deployment snapshot through
`party_formation_layout.gd`, then passes it through the tiny
`game/scripts/dev/sol_snapshot_adapter.gd` seam. Keys `1`/`2`/`3` select
line/square/spaced before encounter entry; the scripted combined proof uses
square. **D-027 is resolved in
favor of intent rounds.** The pre-recut T-092 captures remain under
`docs/screenshots/t092-intent-prototype/` as history. The v1 initiative
combat remains on disk as historical comparison only.

### Alternative isolated pivot proofs (Sol branch)

The consolidation branch also retains two narrower, presentation-first dev
proofs from `codex/unified-world-pivot`:

```powershell
$godot = 'E:\Godot\godot.cmd'
& $godot --path game scenes/dev/three_quarter_height_spike.tscn
& $godot --path game scenes/dev/visible_party_exploration_spike.tscn
```

The height scene is an annotated orthogonal-grid/elevation/occlusion diagram.
The party scene exercises a leader plus three render-only followers through a
one-cell choke, including regrouping, leader switching, and proof that
followers do not occupy plates or push blocks. Their pure models are covered
by `test_three_quarter_height_layout.gd` and
`test_visible_party_exploration_model.gd`. Treat these as focused comparison
harnesses, not production architecture; T-089/T-090/T-092 remain the playable
combined-room candidate.

### Selectable formation/deployment proof (T-096)

T-096 revises Sol's isolated party proof without promoting it to production
architecture. Run `visible_party_exploration_spike.tscn` windowed; WASD/arrows
move, `1` selects line, `2` square, `3` spaced, `F`/controller Y switches the
leader, and R/Q resets. The visible `selected` label is intentionally separate
from transient `spread` / `single file` / `recovered` movement state. No new
InputMap action was added.

From `game/`, reproduce the 1280x720 proof set:

```bash
mkdir -p ../docs/screenshots/t096-party-formations
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/visible_party_exploration_spike.tscn --resolution 1280x720 -- --out="$PWD/../docs/screenshots/t096-party-formations/line.png" --formation=line --state=recovered
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/visible_party_exploration_spike.tscn --resolution 1280x720 -- --out="$PWD/../docs/screenshots/t096-party-formations/square.png" --formation=square --state=recovered
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/visible_party_exploration_spike.tscn --resolution 1280x720 -- --out="$PWD/../docs/screenshots/t096-party-formations/spaced.png" --formation=spaced --state=recovered
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/visible_party_exploration_spike.tscn --resolution 1280x720 -- --out="$PWD/../docs/screenshots/t096-party-formations/choke.png" --formation=spaced --state=choke
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/visible_party_exploration_spike.tscn --resolution 1280x720 -- --out="$PWD/../docs/screenshots/t096-party-formations/recovered.png" --formation=square --state=recovered
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/three_quarter_height_spike.tscn --resolution 1280x720 -- --out="$PWD/../docs/screenshots/t096-party-formations/height-palette.png"
```

Each command must exit `0`. The three formation images must show distinct
party cells; `choke.png` must show `SPACED / SINGLE FILE`; `recovered.png`
must show `SQUARE / RECOVERED`. The capture guard rejects incomplete Metal
frames by sampling the board, header badges, side callouts, and all three
bottom proof cards before writing.

The neutral pure seam is `PartyFormationLayout.plan_deployment()` (promoted
unchanged to `game/scripts/world/party_formation_layout.gd` by S-010/TK-001;
the dev spikes consume the production script), returning
`formation_id`, `leader_id`, `facing`, `member_cells`, and
`deployment_cells`. `test_party_formation_layout.gd` proves four-facing
rotation, deterministic nearest-valid fallback, unique reachable placement,
and wall/enemy/prop/elevation-transition exclusions. It does not claim combat
occupancy or production save/menu/LDtk integration.

### Shared reaction core (T-093A)

The pure preview-first API is `ReactionCore.calculate(state, request)` in
`game/scripts/dev/reaction_core.gd`. Exploration and encounter callers use the
same entry point; `request.context` is metadata only. The exact state/request/
result schemas, deterministic reaction rules, propagation order, 32-cell
cascade boundary, commit pattern, and Fable examples are documented in
`docs/planning/T093_REACTION_CORE_API.md`.

The under-one-minute proof is the complete unit command:

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
```

The `test_reaction_core` tally must be green. It covers grow/vine/fire,
water/flood/cold, wet conduction, both air rules, context parity, exact
propagation order, cascade truncation, invalid inputs, repeat application, and
the no-mutation preview contract. This T-093A slice intentionally has no room
or visual demo; T-093B consumes this exact code path in the gray-box room
below and carries Kayden's fun/not-fun verdict.

### Gray-box reaction room (T-093B)

`scenes/dev/reaction_room_spike.tscn` is the playable proof that the shared
vocabulary works in BOTH contexts. It extends the T-097 intent prototype (same
room, party, encounter cue, and intent rounds) and adds the live reaction
world-state: a channel run, a soil patch, a flammable brush chain, and a smoke
pocket, plus six castable verbs - `5` grow, `6` fire, `7` water, `8` cold,
`9` spark, `0` air - available in exploration AND on any unit's encounter
turn. Casting opens a WASD-aimed cursor (range 3) and shows the complete
neutral result (affected cells in order, damage, hazards, cell tag/status
changes, consumed effects, forced movement, and exactly which units would be
hit, including a promised intention cancel) BEFORE `E` commits; `Q` cancels.
The dense preview is contained in a dark, viewport-aware panel. Main encounter
labels own explicit reservations, while each world-attached unit/HP label is
measured in viewport space and shifted to the panel's left gutter only when
needed, so every combat label remains visible at 1280x720 and 1920x1080.
Fire and smoke use separate board silhouettes (charcoal puffs below a bright
orange flame), and the material legend has its own dark backing. In interactive
play, exploration-only instruction layers hide while the encounter HUD is
active; rejected aim directions and lost window focus show a concrete recovery
message instead of silently dropping input.
Both contexts route through `ReactionRoomLogic.cast` ->
`ReactionCore.calculate`; the caller-side seams (unit mapping, intention
disruption, shove's forced-movement preview) are red/green in
`tests/test_reaction_room_logic.gd`.

One-command replay (macOS; writes thirteen inspected captures per size and
fails if any PNG does not match the declared physical dimensions):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --path . \
  scenes/dev/reaction_room_spike.tscn --resolution 1280x720 -- \
  --out=/tmp/dungeon-reaction-gate-1280 --expected-size=1280x720
/Applications/Godot.app/Contents/MacOS/Godot --fullscreen --path . \
  scenes/dev/reaction_room_spike.tscn --resolution 1920x1080 -- \
  --out=/tmp/dungeon-reaction-gate-1920 --expected-size=1920x1080
```

The scripted tour must print `REACTION ROOM: done` with zero `FAIL` lines
(111/111 assertions per run): exact PNG dimensions; focus-loss/recovery and
blocked-aim captures; exploration hints visible before the encounter and hidden
for its HUD; consequence-panel nonintersection with the main HUD and every
per-unit HP label; grow-then-burn;
air-fed fire spreading down the brush chain; flood-then-freeze; spark conduction
stopped by the ice; smoke clearing; exploration/encounter context parity from
identical state; and the round-2 spark that cancels the slime's declared spit
before it resolves. On macOS, the 1920 proof uses fullscreen because a nominal
1920x1080 window can expose only a 1920x928 drawable client area.
The capture path rejects partially populated Metal readbacks, forces a full
CanvasItem refresh, and retries instead of silently writing black-hole proof.
Run it interactively (no `--out=`) for Kayden's fun/not-fun verdict.

### Display-scaling spike (T-007)

Checks the flexible HD/ultrawide stretch settings (revised 2026-07-05, see
`BLUEPRINT.md` -> Design Decisions) at each target display case:

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/display_scaling_spike.tscn --resolution 1280x720 --quit-after 1
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/display_scaling_spike.tscn --resolution 1920x1080 --quit-after 1
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/display_scaling_spike.tscn --resolution 3440x1440 --quit-after 1
```

Expected result: each command exits `0` with no `ERROR:`/`SCRIPT ERROR:`
lines and prints a `DisplayScalingSpike: viewport=... tiles=...` line.
Caveat (verified 2026-07-05): in headless mode there is no real window, so
`--resolution` is ignored and the viewport reports the 1280-based design
reference at all three sizes - the "viewport matches the requested
resolution" confirmation only works in a *windowed* run (drop `--headless`,
keep `--resolution`, eyeball the label in the corner). This is a throwaway
diagnostic scene (`game/scenes/dev/`), not shipped gameplay.

### Unit tests

Headless unit suites for the pure/deterministic logic (combat math, the grid
model, movement, the data resources, dialogue advancement). No third-party
framework is pulled in - `game/tests/gd_test.gd` is a ~60-line assertion base
and `tests/run_tests.gd` a reflective runner, both first-party so nothing lands
in `game/addons/`.

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
```

Expected result: exit `0` and a final `UNIT TESTS: PASS` line, preceded by a
per-suite tally (currently `UNIT TESTS: 49 suites, 384 tests, 2559 checks, 0
failed`). The runner fails any test that records zero checks - a test aborted
by a runtime script error can no longer masquerade as a pass (S-009/TK-004
runner guard). Any `CHECK FAILED:` line or exit `1` is a real failure. Runs in a
few seconds (pure logic and controlled clocks, no real-time waits, unlike the
slice smoke test; the tutorial soft-lock solver adds a second or two). Run
this after any change to combat math, the grid/pathfinding model, `GridActor`
movement, the player input/feel state machine, the enemy AI, the `.tres`
data, `DialogueBox`, the puzzle primitives, the LDtk entity pipeline, or the
SceneManager reward/heal/restart rules.

Coverage lives in `game/tests/`, one suite per area:
`test_combat_math` (T-060: the real d10 CombatMath statics the live combat
path calls - thresholds, roll inversion, ability power, heals),
`test_turn_manager` (T-061: interleaved-by-speed initiative, deterministic
tie-breaks, mid-round death skips, round refills), `test_combat_scene`
(T-068 core: the Defend shield gate, item stock gating, move-range flood
fill vs solids, ability MP/target gating, mend/potion execution, authored
deployment-zone placement, and a seeded 2v2 auto-battle to completion),
`test_arena_selector` (T-072 deterministic weighted tickets, biome/tag
filtering, fixed overrides, no-repeat refills, v1 save compatibility, and
save/load continuation), `test_authored_arena_loader` (T-073/T-074/T-087 all eight
LDtk levels, imported `TileMapLayer` visuals, contact-side deployment, and
live CombatScene attachment), `test_arena_validator` (T-075 negative safety
fixtures and cover budgets),
`test_progression` (T-045 XP curve shape + the T-041 defeat-penalty floor
clamp), `test_save_manager` (T-037: JSON round-trip, atomic write, tolerant
corrupt/missing loads, slot isolation, int re-coercion), `test_map_registry`
(T-038: every id builds its room headless, id_for round-trips, labels),
`test_load_flow` (T-040: save/load session restore + flag-honoring rebuilt
rooms, soft-failing empty/unknown loads), `test_defeat_respawn` (T-041:
fresh-hub dungeon respawn with the forest kept beneath, healer respawn,
party-wide XP penalty), `test_pit_fall` (T-047: fall damage + entry-cell
respawn, jump-crosses-free, enemies still refused, fatal-fall defeat
chain), `test_room_grid` (bounds, blocking, occupancy,
Manhattan pathfinding, avoid-occupants routing), `test_grid_actor`
(`try_step` reservation/bump/refusal), `test_data_resources` (the shipped
hero/slime/boss `.tres` values + the boss-key/locked-door invariant),
`test_item_data` (T-034: ItemLibrary id->ItemData lookup + display-name
fallback, key-items-never-stack vs consumables-stack, `remove_item`
decrement/erase/refusal, `inventory_summary`), `test_dialogue_box` (line
advancement + `finished`), `test_overworld_enemy`
(`_manhattan` + `defeated()` cleanup), `test_scene_manager` (victory XP/loot
dedup + heal-to-full + the T-029 session reset, the real
`apply_victory_rewards`/`heal_hero_to_full`/`reset_session_state` methods),
`test_game_state` (T-036: per-instance container isolation, SceneManager
property forwarding, reset swap),
`test_enemy_ai` (the deterministic `_act`/`_step_toward`/`_step_home`/
`_wander` decision branches), `test_dialogue_cooldown` (the real
`_unhandled_input` debounce, driven with a controlled input clock),
`test_player_movement` (the T-021 feel state machine - the real
`Player._movement_intent` tap/turn/hold/walk decisions driven with hand-fed
deltas, plus `_read_dir` last-pressed-wins rollover via `Input.action_press`),
`test_pushable_block` (T-023 push/refusal/sink-into-pit/reset),
`test_pressure_plate` (T-024 momentary press/release, plate-door open/re-lock,
deferred re-lock while the doorway is occupied, PuzzleController wiring),
`test_jump` (T-025: 1-cell gap jumpable, 2-cell never, filled pit walkable and
jumpable-from, refusals), `test_chest` (T-026 key gate, one-time reward, flag
persistence), `test_ldtk_pipeline` (T-031: the committed entity_test_room
fixture imports and adopts one of every entity type with fields carried),
`test_tutorial_softlock` (exhaustive BFS over every reachable block/player
state of the REAL shipped hub and pit rooms: solvable from the start, and
every wedged state can still reach the reset lever / the exit - the
can-the-player-wedge-it proof the Known Risks row demands), and
`test_debug_overlay` (T-030 hooks: hidden by default, grant dedup, reset
delegation), `test_party_formation_layout` (T-096 exact choices, four-facing
offsets, deterministic legal deployment/fallback, and authored elevation
transition edges), `test_visible_party_exploration_model` (T-087/T-096
leader-only occupancy, selectable formation persistence, choke compression,
and recovery), `test_world_state` (S-009/TK-001: the neutral production
world-state contract - fail-closed validation, deterministic round-trip,
RoomGrid parity without invented data, exact ReactionCore projection parity,
pure in-room encounter lifecycle), and `test_ldtk_world_authoring`
(S-009/TK-002: Elevation/Material IntGrid adoption, stable encounter ids
from UniqueId/authored-cell, the fail-closed `snapshot_ldtk_room` adapter,
no-invented-data on pre-TK-002 rooms, and the bad-authoring fixture refusing
partial adoption), `test_party_trail` (S-009/TK-003: the pure breadcrumb
model - distinct walkable follower cells, single-file chokes, teleport
reseeds, deterministic snapshot projection with fail-closed refusal), and
`test_production_party` (S-009/TK-003: roster-driven render-only followers
in the production LdtkRoom - never occupants, never pressing plates, leader
pass-through, party actors in the world snapshot, teleport reseeds), and
`test_room_encounter_seam` (S-009/TK-004: in-room encounter mode entry/
victory/retreat in the same room instance, input gating, v1-parity rewards,
puzzle-state continuity, snapshot mode projection, and the opt-in
`SceneManager.unified_encounters` flag staying false by default). Add a
suite path to the `SUITES` list in `run_tests.gd` to register new tests.

For the S-003 two-process world-persistence proof (resolved encounters and
environmental burns survive rebuild AND quit/relaunch/load from disk while
wedged blocks still reset; both phases must exit `0`):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/world_persistence_battery.tscn -- --phase=save \
&& /Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/world_persistence_battery.tscn -- --phase=load
```

For the windowed S-003 owner demo (two captures with the material overlay):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/world_persistence_demo.tscn -- --out=/tmp/world-persistence
```

For the S-014/TK-001 production readability matrix (four verified non-black
exact-size captures per review size - party formation, cast toast, encounter
intent/HUD, post-victory world - plus explicit GAP lines for the known
presentation debts; run 1920 with --fullscreen per the macOS drawable note):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/opening_readability_matrix.tscn --resolution 1280x720 -- --out=/tmp/matrix-1280
/Applications/Godot.app/Contents/MacOS/Godot --fullscreen --path . scenes/dev/opening_readability_matrix.tscn --resolution 1920x1080 -- --out=/tmp/matrix-1920
```

For the S-013 finite-progression and recruitment demo (Wren recruits once,
casts her field verb, wins the slime exactly once, and the ledger refuses
every double-pay; three captures; exit `0` = all PASS):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/progression_demo.tscn -- --out=/tmp/progression-demo
```

For the S-012/TK-005 deterministic combat replay (two scripted fights on
fresh sessions must produce byte-identical event logs; four captures: ENTER
cue, intent+forecast, shove counterplay, victory; exit `0` = all PASS):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/encounter_replay_demo.tscn -- --out=/tmp/combat-replay
```

For the S-011/TK-004 same-state reaction replay (four captures: authored
materials, exploration burn, encounter casts through the same seam, victory
continuity; plus a context-swapped parity replay; exit `0` = all PASS):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/reaction_replay_demo.tscn -- --out=/tmp/reaction-replay
```

For the S-009/TK-004 windowed proof (three captures: exploration with pushed
block, in-room encounter with banner and gated input, victory with the same
room state; prints 12 PASS lines, exit `0`):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/unified_seam_demo.tscn -- --out=/tmp/seam-demo
```

For a one-command S-009/TK-002 world-state demo (prints the fixture room's
neutral snapshot - authored elevation/materials, stable encounters, a defeat
resolving in place, and the bad fixture failing closed; exit `0` = all PASS):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/world_snapshot_probe.tscn
```

The runner `await`s each test, so a suite method may be a coroutine when a test
genuinely needs to yield; most tests read state synchronously right after the
call (before the move tween or the next `_process` tick) and stay pure.

### Phase 3 save/load check (T-042)

The two-process acceptance battery - the literal "save -> quit -> relaunch
-> load" M3.2 done condition, plus M3.3's puzzle-state persistence (the
tutorial chest's solved state and an opened door surviving the cycle):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/saveload_battery.tscn -- --phase=save \
&& /Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/saveload_battery.tscn -- --phase=load
```

Expected result: both processes exit `0`, printing `SAVELOAD BATTERY SAVE
PHASE: PASS (10/10 checks)` then `... LOAD PHASE: PASS (11/11 checks)`. The
save phase opens the chest and the boss door through their real interact
paths and saves at the crystal; the load phase relaunches, answers the boot
prompt with a real confirm input event, and asserts position, flags,
inventory, and rebuilt-room door/chest state. Saves are confined to
`user://saves_battery` (wiped on success), never `user://saves`. Run after
any change to SaveData/SaveManager, MapRegistry, the load/boot flow, the
crystal, or flag-restored room state.

### Phase 4 combat check (T-068/T-069)

Automated proof is the unit command above plus the slice smoke test. The
 authored-arena lane is green at **32 suites / 200 tests / 958 checks** and
**134/134 smoke checks on 5/5 consecutive runs** (2026-07-11). The selector,
loader, validator, and CombatScene tests cover the actual seven-record 2/3/2
forest pool, 5/2/1 weighted tickets, biome/tag filtering, no immediate repeat,
save/load continuation, fixed overrides, 4v4-safe deployment zones, contact
side orientation, and imported LDtk rendering. The smoke test proves a regular
forest Enemy's LDtk `EncounterId` builds the authored two-enemy group, runs
through the production arena-selection path, grants both XP rewards, and
restores the exact overworld position after the zoom transition.

For the windowed T-069 acceptance gate:

1. Run `main.tscn` and touch several slimes in different forest positions.
2. Confirm each battle uses a readable, biome-consistent authored LDtk arena
   rather than a tiny copied contact patch; observe empty, mid, and hard boards
   through the gallery if normal draws do not show all three. Confirm neither
   party spawns trapped (D-018).
3. Control both Hero and the temporary Buddy companion; confirm initiative is
   per-unit, every legal move cell has a filled blue tile with a bright border,
   and the cursor/prompt and party status stay in their HUD bands rather than
   clipping over terrain. Confirm blocked cells refuse movement.
4. Exercise Attack, Strike/Mend, named Potion selection (quantity + acting
   unit shown before confirmation), Defend after obtaining the shield,
   and Wait. Judge the d10 odds, ranges, healing, damage, and first-read
   difficulty rather than treating the current numbers as final.
5. After T-065/T-067, judge the zoom transition, exact-position return,
   HP/MP and turn-order HUD, prompts, and damage/heal feedback.
6. Record Kayden's verdict in the owning stable spec; accepted behavior closes
   its owner gate, while specific recuts become linked specs or tickets.

### Test Coverage Policy

Verification has three layers, cheapest first: (1) the headless import/run
check above (project/resources valid, autoloads boot); (2) the unit suites
(`tests/run_tests.tscn`) for pure logic; (3) the slice smoke test
(`scenes/dev/slice_smoke_test.tscn`) for the end-to-end loop. All three plus a
concrete manual check of whatever feature changed are the standard for a
completed gameplay task.

The unit layer favors testing the *real* code path over a re-implementation:
for example, combat math lives in `CombatMath` statics called by both
`CombatScene` and `test_combat_math`, so a formula change cannot pass a copied
test implementation while breaking the game. Keep it that way - when a system
has pure logic worth testing, extract it to a callable function the game uses
rather than copying the formula into a test.
Use red/green/refactor: write the failing check first, confirm it fails for the
expected reason, then implement the smallest fix. The eventual move to GUT (or
an equivalent) remains a Stretch-adjacent decision; this first-party harness is
deliberately minimal until that call is made.

## Build/Export

Godot exports are configured via the editor's Export dialog (Project ->
Export), not a CLI build script, at this stage of the project. The archived
v2.1 board retains the M0.3 export-presets history.

### macOS

- Export `.app` via Godot's macOS export preset.
- Ad-hoc signing is sufficient for local testing/sharing with friends.
- Distribution beyond direct file-sharing requires an Apple Developer ID
  ($99/year) + notarization - not required to develop/test, only to distribute
  without Gatekeeper warnings.

### Windows

- Export `.exe` directly from macOS - Godot 4.7 cross-compiles natively.
- Icon embedding works out of the box on Godot 4.5+; no Wine/rcedit steps
  needed.

### Android

- Requires OpenJDK 17 + Android SDK (Platform-Tools >=35.0.0) + NDK, configured
  in Godot Editor Settings -> Export -> Android.
- Generate a debug build first (uses Godot's debug keystore automatically) to
  validate the pipeline end to end.
- Release builds require a release keystore via `keytool` - never commit this
  file (see `.gitignore`); configure it per-export in the Android export
  preset, not pasted into `export_presets.cfg`.
- Test on a real Android device early (Milestone M0.3/M2.x) to validate touch
  input and Mobile-renderer performance.

Expected healthy state: one trivial exported build per platform runs and shows
the same placeholder scene as the editor.

## Version Control

- **`integration` is now the staging branch (revised 2026-07-05, supersedes
  the "no separate integration branch" row below)** - work lands on
  `integration` first; Kayden syncs `integration` -> `main` explicitly once
  he's happy with what's accumulated there. Do not commit directly to
  `main`, and do not merge `integration` into `main` without Kayden's
  explicit go-ahead.
~~No separate integration branch - PR directly into `main`~~ - superseded;
  kept here for history. Branch-per-spec/ticket naming applies to work branched
  off `integration`: `type/short-description` or `s-###/short-description`.
- Commit messages: imperative subject <= 72 chars, referencing the stable spec
  or ticket where useful. One logical change per commit.
- Run `git status` before committing.
- Never commit secrets, Android keystores (`.jks`/`.keystore`), local
  databases, logs, build output, or generated artifacts (see `.gitignore`).
- Kayden is the sole merger of anything into `main`; agents open PRs
  targeting `integration` (or push directly to `integration` when Kayden is
  driving in-session) and do not merge into `main` without explicit approval.
- Open a pull request when the task is complete and verified, even if it will
  be merged promptly, so there is a reviewable record. The PR description
  states what changed, why, risks, and how it was verified.
- Do not rewrite published history or force-push shared branches unless
  Kayden explicitly approves.

## Upgrading The Harness

These control docs were generated from LLM Workbench v2.3, recorded in the
`Generated from LLM Workbench v2.3` stamp at the top of each doc. That stamp
lets you tell when this project is running an older harness than the current
one.

To upgrade:

1. Verify the canonical local source at
   `/Users/kayden/GPT_OS/Workbench Factory`, its branch, remote, version, and
   dirty state; do not migrate from an assumed or retired template path.
2. Re-copy only the changed template sections; keep this project's filled-in
   specifics. Never let unresolved template markers leak back into filled docs.
3. Preserve stable spec paths and completed evidence. If the lifecycle contract
   changes, migrate active state deliberately and archive the superseded hot
   projection.
4. Copy the current `tools/spec-workbench.mjs` and any helper modules it imports
   (currently `tools/markdown-table.mjs`), update each control doc's version
   stamp, render, and run doctor.
5. Re-run the full verification suite above and record the upgrade in a
   dedicated stable spec, not in `TASKBOARD.md`.

If a downstream lesson should flow *back* to the harness, capture it in
`HARNESS_FEEDBACK.md`.

## Troubleshooting

| Symptom | Likely cause | Check | Fix |
|---|---|---|---|
| Godot editor opens the project but behaves unexpectedly / editor UI looks wrong | Wrong Godot version installed (this project targets 4.7.x as of 2026-07-07) | `/Applications/Godot.app/Contents/MacOS/Godot --version` | Install/switch to Godot 4.7.x |
| Headless `--import` run is slow the first time | Expected - first import scans the filesystem and builds the global script class cache from scratch | Re-run the same command | Subsequent runs are faster; not a bug |
| `--quit-after 1` output has no `SceneManager ready.` line | `SceneManager` autoload not registered, or `main.tscn` isn't the scene passed | Check `game/project.godot` -> `[autoload]` section and the command's scene path | Fix the autoload path or the invoked scene |
| Game boots to a dark "A saved adventure awaits." screen instead of the forest | Expected (T-040/D-011): a save exists in `user://saves`, so the Continue/New Game prompt is waiting | E/Space continues from the save; X/Esc starts fresh | To never see it, delete the saves dir (see Run Locally -> save files) |
| A save slot won't load / boot went to a fresh game after Continue | Corrupt or hand-edited slot JSON, or its `current_map` id is not in `MapRegistry` | Run with a console: `SaveManager:` warnings name the file and reason | Fix or delete `user://saves/slot_N.json`; loads are tolerant and never crash |

## Recovery And Rollback

If a change fails:

1. Identify the touched files and failing command.
2. Revert only the smallest change needed, preserving other work.
3. Rerun the failing verification command (Test And Build, above).
4. Update the owning stable spec with the result and remaining gap, then render.

Do not delete save data, rewrite history, or rotate anything unless Kayden
explicitly approves.

## Operational Proof

If a command in this runbook changed durable project state, append a row to the
owning stable spec. For routine local runs that do not change state, a final
response note is enough.
