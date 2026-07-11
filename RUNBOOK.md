# Dungeon Friends - Runbook

> Generated from LLM Workbench v2.1. See Upgrading The Harness below.

**Last reviewed:** 2026-07-09
**Runtime owner:** Kayden (solo developer)
**Environment:** local (macOS development machine; builds also target Windows
and Android)

This file explains how to operate, verify, recover, and evaluate the project.
It should be boring, exact, and executable.

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
- Space/B remains reserved for a future traversal item, but no shipped room
  requires manual jumping. The tutorial route uses mechanisms instead.
- Loop: talk to the quest NPC -> bump a slime to enter the local-terrain
  tactical arena (D-012), controlling Hero + Buddy (D-013). WASD/arrows move
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
  (D-011). **Walking into a pit** is a Zelda-style fall: 10 HP party-wide and a walk
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
per-suite tally (currently `UNIT TESTS: 27 suites, 176 tests, 642 checks, 0
failed`). Any `CHECK FAILED:` line or exit `1` is a real failure. Runs in a
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
fill vs solids, ability MP/target gating, mend/potion execution, the D-012
arena connectivity seed, and a seeded 2v2 auto-battle to completion),
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
delegation). Add a suite path to the `SUITES` list in `run_tests.gd` to
register new tests.

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

Automated proof is the unit command above plus the slice smoke test: at the
T-068 gate that was 22 suites / 140 tests / 490 checks and **111/111 smoke
checks on 5/5 consecutive runs** (2026-07-09; counts refreshed same day after
the dev potion grant and the smoke test's freed-lambda-capture fix); the
Phase 3 save/load, T-069 playtest recut, and the first runtime sprite pass grew
the totals to 27 suites / 173 tests / 644 checks and 138/138 smoke
(2026-07-10). `test_combat_scene` covers a seeded
2v2 battle, D-012 local-terrain connectivity, range refusal, MP/item
bookkeeping, support actions, shield-gated Defend, and the live turn-order HUD
format. The smoke test proves a regular forest Enemy's LDtk `EncounterId`
builds the authored two-enemy group, grants both XP rewards, and restores the
exact overworld position after the zoom transition.

For the windowed T-069 acceptance gate:

1. Run `main.tscn` and touch several slimes in different forest positions.
2. Confirm the combat arena resembles the terrain around each contact point
   and never traps either party (D-012).
3. Control both Hero and the temporary Buddy companion; confirm initiative is
   per-unit, move/attack highlights are readable, and blocked cells refuse
   movement.
4. Exercise Attack, Strike/Mend, named Potion selection (quantity + acting
   unit shown before confirmation), Defend after obtaining the shield,
   and Wait. Judge the d10 odds, ranges, healing, damage, and first-read
   difficulty rather than treating the current numbers as final.
5. After T-065/T-067, judge the zoom transition, exact-position return,
   HP/MP and turn-order HUD, prompts, and damage/heal feedback.
6. Record Kayden's verdict in `TASKBOARD.md`; accepted behavior closes T-069,
   while specific recuts become new scoped tasks.

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
Export), not a CLI build script, at this stage of the project. Export presets
are set up in Milestone M0.3 (see `TASKBOARD.md`).

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
  kept here for history. Branch-per-task/milestone naming still applies for
  work branched off of `integration`: `type/short-description` (e.g.
  `feat/pushable-block`, or the TASKBOARD task/milestone ID where applicable,
  e.g. `t-023/pushable-block`).
- Commit messages: imperative subject <= 72 chars, referencing the TASKBOARD
  task/milestone where relevant (e.g. "T-023: implement PushableBlock +
  PressurePlate"). One logical change per commit.
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

These control docs were generated from LLM Workbench v2.1, recorded in the
`Generated from LLM Workbench v2.1` stamp at the top of each doc. That stamp
lets you tell when this project is running an older harness than the current
one.

To upgrade:

1. Check the `KaydenClark/LLM_Workbench` repo's releases/changelog for what
   changed since v2.1.
2. Re-copy only the changed template sections; keep this project's filled-in
   specifics. Never let `[BRACKETED]` placeholders leak back into filled docs.
3. Update each doc's version stamp to the new version.
4. Re-run the full verification suite (above) and record the upgrade as a
   proof-log row in `TASKBOARD.md`.

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
4. Update `TASKBOARD.md` with the result and remaining gap.

Do not delete save data, rewrite history, or rotate anything unless Kayden
explicitly approves.

## Operational Proof

If a command in this runbook changed durable project state, append a row to
the `TASKBOARD.md` proof log. For routine local runs that do not change state,
a final response note is enough.
