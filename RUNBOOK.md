# Dungeon Friends - Runbook

> Generated from LLM Workbench v2.1. See Upgrading The Harness below.

**Last reviewed:** 2026-07-05
**Runtime owner:** Kayden (solo developer)
**Environment:** local (macOS development machine; builds also target Windows
and Android)

This file explains how to operate, verify, recover, and evaluate the project.
It should be boring, exact, and executable.

## Prerequisites

Required tools:

- Godot 4.6.x - confirmed installed at `/Applications/Godot.app`
  (`/Applications/Godot.app/Contents/MacOS/Godot --version` ->
  `4.6.3.stable.official`).
- Git.

Required accounts/services:

- GitHub (`KaydenClark/Dungeon_Friends_Game`) for push/PR.
- Later, for Android export only: OpenJDK 17, Android SDK Platform-Tools
  >=35.0.0, NDK - not required for Phase 0/1 work.

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
showing the first-playable forest slice (placeholder ColorRect art). No
console errors.

Playing the slice (2026-07-05 second session; controls are the T-009 input
map):

- WASD / arrow keys: grid-snapped movement. E / Space: talk & interact;
  Enter / Space advances dialogue.
- Loop: talk to the yellow NPC -> walk into the purple slime -> turn-based
  battle (Up/Down selects Attack/Defend, Enter confirms) -> win the Forest
  Key -> open the brown door on the east side -> step onto the gold tiles.

## Test And Build

There is no traditional automated test suite yet - at this stage (Phase 0),
the verification *is* "does the project open headlessly with zero errors."

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
NPC dialogue, enemy encounter, seeded d10 combat, key/door/goal):

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

Expected result: exit `0` and a final `SLICE SMOKE TEST: PASS (34/34 checks)`
line (~20-40s; the expanded forest walk and multiple fights take longer than
the original 26-check slice). A benign `ObjectDB instances leaked` warning at
exit is known noise from quitting mid-coroutines; any `CHECK FAILED:` line or
exit `1` is a real failure. Because roaming enemies move on real-time timers,
run it a few times in a row when touching enemy AI or movement (`for i in 1 2
3 4 5; do ...; done`). Run this after any change to movement, interaction,
combat, or SceneManager.

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

### Test Coverage Policy

Until GUT (Godot Unit Test) or an equivalent GDScript test framework is
introduced (a Stretch-adjacent decision, not yet made), the headless
import/run check above is the project's baseline verification, backed up by a
concrete manual check of whatever feature actually changed (open the project
and exercise it directly).

Introduce automated unit tests starting with Phase 3 (Data Model) -
`Resource` classes and combat-math functions (the `AttackCommand` damage
formula, the XP curve) are the highest-value first candidates since they're
pure logic with no scene/rendering dependency. Once that framework exists,
use red/green/refactor for that code: write the failing test first, confirm
it fails for the expected reason, then implement the smallest fix.

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

- Export `.exe` directly from macOS - Godot 4.6 cross-compiles natively.
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
  `feat/pushable-block`, or the Gameplan milestone ID where applicable, e.g.
  `m2.1/pushable-block`).
- Commit messages: imperative subject <= 72 chars, referencing the Gameplan
  milestone where relevant (e.g. "M2.1: implement PushableBlock +
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
| Godot editor opens the project but behaves unexpectedly / editor UI looks wrong | Wrong Godot version installed (this project targets 4.6.x specifically) | `/Applications/Godot.app/Contents/MacOS/Godot --version` | Install/switch to Godot 4.6.x |
| Headless `--import` run is slow the first time | Expected - first import scans the filesystem and builds the global script class cache from scratch | Re-run the same command | Subsequent runs are faster; not a bug |
| `--quit-after 1` output has no `SceneManager ready.` line | `SceneManager` autoload not registered, or `main.tscn` isn't the scene passed | Check `game/project.godot` -> `[autoload]` section and the command's scene path | Fix the autoload path or the invoked scene |

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
