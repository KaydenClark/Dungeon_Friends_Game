# S-009 - Unified World Runtime

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-009
**Status:** active
**Priority:** 1
**Owner:** claude-engineer
**Updated:** 2026-07-19
**Catalog description:** Replace the split production world/battle spine with one neutral room-state and party/encounter lifecycle without deleting the green v1 fallback early.
**Blockers:** none
**Latest event:** S-002's fun gate passed (2026-07-19) and D-038 consolidated intermediate owner verdicts into the S-004 replay; this spec is now the active head of the production chain.
**Next gate:** Engineer claims TK-001 and proves the neutral world-state contract red, then green.

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
| TK-001 | Define the neutral production world-state contract with failing parity/validation tests. | ready | none | pending |
| TK-002 | Extend RoomGrid/LDtk authoring with elevation, materials, stable encounter IDs, and fail-closed adapters. | ready | TK-001 | pending |
| TK-003 | Graduate leader plus visible pass-through followers into the production room lifecycle. | ready | TK-002 | pending |
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

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- `S-010` through `S-012` consume this runtime; `S-003` persists it.

## Supersession

- Supersedes: production split-world lifecycle when implemented
- Superseded by: none
