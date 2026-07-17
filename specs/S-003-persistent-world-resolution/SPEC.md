# S-003 - Persistent World Resolution

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-003
**Status:** active
**Priority:** 1
**Owner:** unassigned
**Updated:** 2026-07-17
**Catalog description:** Persist resolved encounters and environmental changes across leave, save, quit, relaunch, and load without losing soft-lock recovery.
**Blockers:** S-009 production world state; S-011 production reaction vocabulary; S-012 production encounter resolution
**Latest event:** Canon reconciliation separated dev-scene reaction proof from the production world and encounter state this persistence contract must serialize.
**Next gate:** Complete the production-state contracts in S-009, S-011, and S-012, then claim TK-001 and prove the two-process battery red.

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
| TK-001 | Add a failing two-process battery for resolved encounter, environment, and movable reset. | ready | S-009; S-011; S-012 | pending |
| TK-002 | Persist stable encounter IDs and neutral environmental state with fail-closed loading. | ready | TK-001 | pending |
| TK-003 | Run the full suite and owner-visible persistence demo. | ready | TK-002 | pending |

## Acceptance Criteria

- [ ] A resolved encounter stays resolved after leave and re-entry.
- [ ] The same result survives save, quit, relaunch, and load.
- [ ] Intentional environmental state survives the same cycle.
- [ ] Wedged movable blocks reset without resurrecting encounters or deleting
  intentional state.
- [ ] Existing save compatibility fails safely and the full suite stays green.

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

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- Production-room rollout belongs to `S-009`; production reaction and combat
  state belong to `S-011` and `S-012`.

## Supersession

- Supersedes: D-009 routine enemy respawn behavior when implemented
- Superseded by: none
