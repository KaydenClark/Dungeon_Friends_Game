# S-009 - Unified World Runtime

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-009
**Status:** active
**Priority:** 1
**Owner:** claude-engineer
**Updated:** 2026-07-20
**Catalog description:** Replace the split production world/battle spine with one neutral room-state and party/encounter lifecycle without deleting the green v1 fallback early.
**Blockers:** none
**Latest event:** TK-003 claimed by claude-engineer.
**Next gate:** Close TK-003 with verification and documentation proof.

## Outcome

Production rooms expose one deterministic world-state seam for orthogonal
cells, elevation, materials, party actors, stable encounter identity, and
in-place encounter lifecycle.

## Why It Matters

Formations, reactions, combat, and persistence otherwise risk graduating into
four incompatible copies of the prototype state.

## Current Verified State

`RoomGrid`, `LdtkRoom`, `SceneManager`, and `MapRegistry` are green v1
infrastructure. Production uses a single `Player`, room-rebuilt enemies, a
separate `CombatScene`, and arena selection. Dev scenes separately prove
height, party visibility, room continuity, intent, and reactions.

## Desired Behavior

- One typed neutral room snapshot owns cells, elevation, material/effect state,
  occupancy, party identity, and stable encounter IDs.
- Production rooms and dev-derived systems consume the same seam.
- The visible party exists in production exploration.
- Encounter entry/victory changes mode in the same room instance.
- The v1 route remains runnable until replacement acceptance passes.

## Decisions And Contracts

- D-024, D-025, D-029, and D-030 govern.
- `RoomGrid`, LDtk, `TileMapLayer`, `AStarGrid2D`, Tween movement, and the
  single `SceneManager` autoload survive.
- Reaction rules, formation planning, combat resolution, and disk persistence
  remain owned by `S-011`, `S-010`, `S-012`, and `S-003`.

## Non-Goals

- Final content/art, combat balance, reaction rules, save schema, or deletion
  of proven v1 systems before replacement proof.

## Dependencies And Blockers

- `S-002` accepted shared-vocabulary direction - **cleared 2026-07-19 (fun verdict recorded).**

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Define the neutral production world-state contract with failing parity/validation tests. | done | none | red: suite failed to load pre-implementation; green: test_world_state 69 checks; full unit 39 suites/292 tests/1880 checks PASS; --import 0 errors; slice smoke 134/134 |
| TK-002 | Extend RoomGrid/LDtk authoring with elevation, materials, stable encounter IDs, and fail-closed adapters. | done | TK-001 | red: test_ldtk_world_authoring failed to load pre-implementation; green: 218 checks in-suite; full unit 40 suites/299 tests/2098 checks PASS; --import 0 script errors; slice smoke 134/134; main boot SceneManager ready; demo probe scenes/dev/world_snapshot_probe.tscn all PASS, transcript docs/planning/S009_TK002_world_snapshot_demo.txt |
| TK-003 | Graduate leader plus visible pass-through followers into the production room lifecycle. | in-progress | TK-002 | pending |
| TK-004 | Add the in-room encounter mode seam and prove room/camera/positions/puzzle state survive entry and victory. | ready | TK-003 | pending |

## Acceptance Criteria

- [ ] One production state contract feeds every downstream capability.
- [ ] Existing rooms load without invented material/elevation data.
- [ ] The active party is visible and non-blocking during exploration.
- [ ] Encounter entry and victory preserve the same room instance and state.
- [ ] The v1 fallback remains green until the replacement is accepted.

## Testing Seams

- Pure state validation/round-trip.
- `RoomGrid`, LDtk pipeline, player/party lifecycle, and transition-race tests.
- Production-room continuity smoke.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

## Documentation Impact

- Update Blueprint architecture/data contracts, Runbook production demo, and
  README only when the default playable route changes.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | spec | Production gap extracted from D-024/D-025 and live source | SceneManager, RoomGrid, LDtk, main, and dev inheritance inspected | new stable runtime spec | all slices and S-002 |
| 2026-07-19 | spec | Activated: S-002 fun verdict recorded; D-038 owner-approval consolidation applied across the production chain | spec doctor green after activation and rerender | Blueprint D-038 row; hot board rerendered | TK-001 through TK-004 |
| 2026-07-20 | TK-001 | Ticket closed | red: suite failed to load pre-implementation; green: test_world_state 69 checks; full unit 39 suites/292 tests/1880 checks PASS; --import 0 errors; slice smoke 134/134 | contract documented in scripts/world/world_state.gd header; Blueprint/Runbook unchanged until the default route changes (per spec Documentation Impact) | TK-002 LDtk/RoomGrid authoring adapters, TK-003 production party, TK-004 encounter seam |
| 2026-07-20 | TK-002 | Ticket closed | red: test_ldtk_world_authoring failed to load pre-implementation; green: 218 checks in-suite; full unit 40 suites/299 tests/2098 checks PASS; --import 0 script errors; slice smoke 134/134; main boot SceneManager ready; demo probe scenes/dev/world_snapshot_probe.tscn all PASS, transcript docs/planning/S009_TK002_world_snapshot_demo.txt | Blueprint D-039 flagged authoring-contract row (per D-038); RUNBOOK unit-test tally + new suite coverage + probe command; contract docs in ldtk_room.gd/world_state.gd headers | TK-003 production party graduation, TK-004 in-room encounter seam; snapshot consumers (S-010..S-012, S-003) not yet wired |

| 2026-07-20 | TK-002 | Adversarial-review hardening: source-declaration validation (reordered/gapped Elevation/Material IntGrid values now fail closed instead of silently re-meaning painted cells) and adapter reserved-id collision guard (an authored UniqueId such as "player" can no longer overwrite another actor) | red: 7 targeted failures on the new bad-declaration fixture and collision test; green: unit 40 suites/301 tests/2107 checks PASS; slice smoke 134/134 | RUNBOOK tally; ldtk_room.gd header contract updated to match actual behavior | declaration check runs only where .ldtk sources exist (dev/CI; exported builds carry frozen validated data) |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- `S-010` through `S-012` consume this runtime; `S-003` persists it.

## Supersession

- Supersedes: production split-world lifecycle when implemented
- Superseded by: none
