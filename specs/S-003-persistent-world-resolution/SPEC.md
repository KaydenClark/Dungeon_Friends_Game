# S-003 - Persistent World Resolution

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-003
**Status:** complete
**Priority:** 1
**Owner:** claude-engineer
**Updated:** 2026-07-20
**Catalog description:** Persist resolved encounters and environmental changes across leave, save, quit, relaunch, and load without losing soft-lock recovery.
**Blockers:** none
**Latest event:** Spec completed and removed from the hot board.
**Next gate:** none

## Outcome

Defeated encounters and intentional environmental changes remain resolved after
leaving a room and after a full save/quit/relaunch/load cycle, while wedged
puzzle blocks still reset safely on room rebuild.

## Why It Matters

Persistent resolution is the world-side half of the v2 identity. It replaces
routine enemy respawning without giving up the existing puzzle escape valve.

## Current Verified State

The v1 save/load foundation and two-process battery exist. The current schema
preserves inventory, flags, map, and player state, but D-009 still expects
rebuilt rooms to respawn enemies and does not serialize the reaction vocabulary's
environmental state.

## Desired Behavior

- Save stable resolved-encounter identifiers.
- Save intentional environmental/material state needed by D-031.
- Leaving and re-entering does not resurrect a resolved encounter.
- Quit/relaunch/load restores the resolved encounter and environment.
- Wedged movable puzzle state resets without erasing intentional world changes.

## Decisions And Contracts

- D-028 supersedes D-009's routine-respawn contract.
- Persistence consumes the neutral reaction contract proven by `S-002` and
  productionized by `S-011`; it does not fork a second reaction model.
- The two-process check must prove disk persistence, not one-process memory.

## Non-Goals

- General save-slot UI, cloud saves, production content expansion, or broad
  migration of every legacy flag in one slice.

## Dependencies And Blockers

- `S-009` must define stable production room and encounter identifiers.
- `S-011` must expose production reaction state in a neutral serializable form.
- `S-012` must define the deterministic production encounter-resolution state.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Add a failing two-process battery for resolved encounter, environment, and movable reset. | done | none | battery exists and fails red for exactly the expected reasons: save phase 8/10 with 'resolved encounter stays resolved on rebuild (D-028)' and 'environmental burn survives the rebuild' failing while the D-023 block-reset escape valve passes; resolution/burn are produced through the real seams (begin/resolve_room_encounter, ReactionCaster); --import clean |
| TK-002 | Persist stable encounter IDs and neutral environmental state with fail-closed loading. | done | TK-001 | battery flipped green: save phase 10/10 and fresh-process load phase 4/4 (resolved encounter + burn from disk, block reset); unit 47 suites/370 tests/2494 checks PASS with 0 script errors; fail-closed loading pinned (malformed and out-of-bounds persisted entries refused wholesale, authored state stands); legacy saves default safely; JSON round-trip pinned through real stringify/parse |
| TK-003 | Run the full suite and owner-visible persistence demo. | done | TK-002 | full suite green: unit 47 suites/370 tests/2494 checks; slice smoke 134/134 (v1 fallback); v1 saveload battery 10/10 + 11/11; world persistence battery 10/10 + 4/4 across two processes; main boot clean; windowed world_persistence_demo 11/11 PASS with 2 captures docs/screenshots/s003-persistence (rebuilt-persisted, loaded-persisted with material overlay); S-012 review C1 fixed in the same window (plates freeze during encounters, re-evaluate on release, tested) and C2 fixed (group-authored victory pays only the fought enemy, tested) |

## Acceptance Criteria

- [x] A resolved encounter stays resolved after leave and re-entry.
- [x] The same result survives save, quit, relaunch, and load.
- [x] Intentional environmental state survives the same cycle.
- [x] Wedged movable blocks reset without resurrecting encounters or deleting
  intentional state.
- [x] Existing save compatibility fails safely and the full suite stays green.

## Testing Seams

- `SaveData` serialization and validation.
- Stable encounter identifier lookup.
- Pure environmental state round-trip.
- Existing two-process save/load battery pattern.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/saveload_battery.tscn -- --phase=save \
&& /Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/saveload_battery.tscn -- --phase=load
```

## Documentation Impact

- Update Blueprint data-model and persistence truth, Runbook battery details,
  and README current-state text if the production loop changes.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-13 | spec | Migrated from legacy T-091 | existing v1 save/load battery and current schema inspected | v2.3 controls and spec created | S-002 owner gate and all implementation slices |
| 2026-07-17 | spec | Reconciled persistence with the production capability chain | source and current schema inspected; dev-only proof kept distinct from production state | dependencies corrected to S-009, S-011, and S-012 | all implementation slices |
| 2026-07-20 | TK-001 | Ticket closed | battery exists and fails red for exactly the expected reasons: save phase 8/10 with 'resolved encounter stays resolved on rebuild (D-028)' and 'environmental burn survives the rebuild' failing while the D-023 block-reset escape valve passes; resolution/burn are produced through the real seams (begin/resolve_room_encounter, ReactionCaster); --import clean | battery header documents the two-process contract; Docs checked; no other update needed (red slice) | TK-002 persists stable encounter ids + material state with fail-closed loading and turns this battery green; TK-003 full suite + owner demo |
| 2026-07-20 | TK-002 | Ticket closed | battery flipped green: save phase 10/10 and fresh-process load phase 4/4 (resolved encounter + burn from disk, block reset); unit 47 suites/370 tests/2494 checks PASS with 0 script errors; fail-closed loading pinned (malformed and out-of-bounds persisted entries refused wholesale, authored state stands); legacy saves default safely; JSON round-trip pinned through real stringify/parse | GameState/SaveData field docs; ldtk_room.gd persistence hooks documented | TK-003 full-suite run + owner demo capture |
| 2026-07-20 | TK-003 | Ticket closed | full suite green: unit 47 suites/370 tests/2494 checks; slice smoke 134/134 (v1 fallback); v1 saveload battery 10/10 + 11/11; world persistence battery 10/10 + 4/4 across two processes; main boot clean; windowed world_persistence_demo 11/11 PASS with 2 captures docs/screenshots/s003-persistence (rebuilt-persisted, loaded-persisted with material overlay); S-012 review C1 fixed in the same window (plates freeze during encounters, re-evaluate on release, tested) and C2 fixed (group-authored victory pays only the fought enemy, tested) | RUNBOOK gains battery + demo commands and tally; README/Blueprint unchanged (D-028 already canon) | encounter groups spawning as in-room units (S-012 noted gap) will extend resolution ids per member |
| 2026-07-20 | spec | Spec completed | Acceptance gates satisfied | Documentation impact recorded above | none |

## Completion Result

Persistent world resolution is live (D-028 supersedes D-009's routine
respawn). Victories through the unified seam record their stable encounter
id under the room's authored world key; rebuilt rooms skip resolved spawns
while keeping the identity visible to world snapshots, and committed
reaction state persists as the room's material truth. Both travel through
GameState and the save schema with tolerant defaults for older saves and
fail-closed loading for malformed data, while wedged movable blocks still
reset on rebuild (the D-023 escape valve). Proven by the two-process
world_persistence_battery (save 10/10, fresh-process load 4/4), the
test_world_persistence suite inside the 47-suite/2494-check unit run, the
green v1 saveload battery, and the windowed owner demo under
docs/screenshots/s003-persistence. Owner batch review rides S-004 per
D-038.

## Remaining Limitations Or Follow-Up Specs

- Production-room rollout belongs to `S-009`; production reaction and combat
  state belong to `S-011` and `S-012`.

## Supersession

- Supersedes: D-009 routine enemy respawn behavior when implemented
- Superseded by: none
