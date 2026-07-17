# S-011 - Production Reaction Vocabulary

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-011
**Status:** planned
**Priority:** 1
**Owner:** unassigned
**Updated:** 2026-07-17
**Catalog description:** Graduate the accepted preview-first material/effect engine into production world cells, authored data, friend verbs, and encounter callers.
**Blockers:** S-002, S-009
**Latest event:** ReactionCore and its same-path gray-box consumer are green; production RoomGrid and AbilityData do not consume them.
**Next gate:** Accept S-002 and complete the S-009 state seam, then promote the pure core unchanged.

## Outcome

Production exploration, puzzles, friend abilities, and encounters call one
bounded deterministic material/effect engine and commit the same neutral state
the preview showed.

## Why It Matters

This is the scope guardrail that lets authored friends interact without
pairwise code and the shared state required by persistence.

## Current Verified State

The dev core supports grow, fire, water, cold, spark, air, bounded propagation,
neutral diffs, unit mapping, and intention cancellation. Production `RoomGrid`,
LDtk layers, `AbilityData`, and puzzle actors do not expose or commit this
state.

## Desired Behavior

- The pure core graduates with exact behavior and context parity.
- LDtk/RoomGrid expose validated tags, materials, effects, and stable cells.
- `AbilityData`/friend verbs use one preview and commit path everywhere.
- Existing puzzle primitives become vocabulary consumers rather than a second
  bespoke ruleset.

## Decisions And Contracts

- D-031 and preview-equals-result govern.
- Context remains metadata and never branches reaction rules.
- Invalid input fails closed; cascade order and limits stay deterministic.
- Tuning/kit allocation follows the accepted `S-002` verdict.

## Non-Goals

- Persistence, combat round order, final VFX/audio, broad balance, or bespoke
  friend-pair interactions.

## Dependencies And Blockers

- `S-002` owner-accepted vocabulary.
- `S-009` production world-state seam.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Promote ReactionCore schemas and rules behind a production API with exact dev-parity red/green coverage. | ready | S-002, S-009 | pending |
| TK-002 | Add validated material/effect state to RoomGrid and the LDtk authoring/import path. | ready | TK-001 | pending |
| TK-003 | Route production friend abilities and puzzle/encounter callers through one preview/commit seam. | ready | TK-002 | pending |
| TK-004 | Capture a production same-state exploration/encounter replay and record Kayden's vocabulary verdict. | blocked | TK-003 and Kayden played verdict | pending |

## Acceptance Criteria

- [ ] Production and dev parity cover every accepted reaction.
- [ ] One API serves exploration and encounter callers.
- [ ] Preview and commit match including state, damage, movement, and cancels.
- [ ] Authoring/load failures are explicit and fail closed.
- [ ] Kayden accepts the production vocabulary replay.

## Testing Seams

- Pure core parity and cascade limits.
- LDtk import/validation.
- Puzzle/ability caller parity.
- Production same-state replay.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

## Documentation Impact

- Update Blueprint data/material contracts, Runbook authoring/demo, and API
  documentation.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | spec | Production half split from S-002 prototype gate | live RoomGrid/AbilityData/puzzles compared with ReactionCore and room bridge | new stable production-reaction spec | dependencies and all slices |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- `S-003` persists the resulting state; `S-012` owns combat timing.

## Supersession

- Supersedes: production reaction work implicit in T-093/T-094
- Superseded by: none
