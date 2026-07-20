# S-011 - Production Reaction Vocabulary

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-011
**Status:** active
**Priority:** 1
**Owner:** claude-engineer
**Updated:** 2026-07-20
**Catalog description:** Graduate the accepted preview-first material/effect engine into production world cells, authored data, friend verbs, and encounter callers.
**Blockers:** none
**Latest event:** TK-003 closed with proof.
**Next gate:** Complete TK-004.

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
| TK-001 | Promote ReactionCore schemas and rules behind a production API with exact dev-parity red/green coverage. | done | S-009 | red: test_reaction_core failed to load against the production path pre-move; green: unit 43 suites/339 tests/2307 checks PASS with 0 script errors; slice smoke 134/134; --import clean; main boot clean; parity test pins the gray-box consumer loads the exact production script, the retired dev path stays absent, and a golden fire-on-vine result is unchanged |
| TK-002 | Add validated material/effect state to RoomGrid and the LDtk authoring/import path. | done | TK-001 | red: 6 targeted failures pre-implementation; green: unit 44 suites/345 tests/2338 checks PASS with 0 script errors; slice smoke 134/134; main boot clean; live material_state seeded from validated authoring, preview-first ReactionCore seam with fail-closed wholesale commit, snapshot carries live state (burned vine stays burned, cleared cells drop out), context parity pinned, pre-authoring rooms seed clean |
| TK-003 | Route production friend abilities and puzzle/encounter callers through one preview/commit seam. | done | TK-002 | red: test_reaction_caster failed to load pre-implementation; green: unit 45 suites/350 tests/2361 checks PASS with 0 script errors; slice smoke 134/134; main boot clean; AbilityData.reaction_verb routes any ability through ReactionCaster preview/cast with fail-closed refusals, air direction plumbing, and identical committed state across exploration/encounter contexts; S-010 review C1 fixed (plate cells excluded from deployment; invariant test) and C2 fixed (refused deployment shows a dialogue instead of silent dead input) |
| TK-004 | Capture and verify a production same-state exploration/encounter replay. | ready | TK-003 | pending |
| TK-005 | Owner production shared-vocabulary verdict - consolidated into the S-004 thesis replay per D-038 (2026-07-19); TK-004's replay capture feeds that batch review. | deferred | S-004 | owner verdict batches at S-004 per D-038 |

## Acceptance Criteria

- [ ] Production and dev parity cover every accepted reaction.
- [ ] One API serves exploration and encounter callers.
- [ ] Preview and commit match including state, damage, movement, and cancels.
- [ ] Authoring/load failures are explicit and fail closed.
- [ ] Production same-state replay captured for the S-004 batch review; the owner vocabulary verdict rides that replay (D-038).

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
| 2026-07-19 | TK-005 | S-002 fun verdict cleared the prototype blocker; D-038 batches the production-vocabulary verdict into the S-004 thesis replay; TK-005 deferred to that gate | Kayden chat directive 2026-07-19; Blueprint D-038 row | this spec, Blueprint | TK-001 through TK-004 |
| 2026-07-20 | TK-001 | Ticket closed | red: test_reaction_core failed to load against the production path pre-move; green: unit 43 suites/339 tests/2307 checks PASS with 0 script errors; slice smoke 134/134; --import clean; main boot clean; parity test pins the gray-box consumer loads the exact production script, the retired dev path stays absent, and a golden fire-on-vine result is unchanged | RUNBOOK tally; reaction_core.gd header records the promotion contract | TK-002 RoomGrid/LDtk material-effect state (S-009 authoring covers initial tags; live effect state pending), TK-003 ability/puzzle callers, TK-004 same-state replay |
| 2026-07-20 | TK-002 | Ticket closed | red: 6 targeted failures pre-implementation; green: unit 44 suites/345 tests/2338 checks PASS with 0 script errors; slice smoke 134/134; main boot clean; live material_state seeded from validated authoring, preview-first ReactionCore seam with fail-closed wholesale commit, snapshot carries live state (burned vine stays burned, cleared cells drop out), context parity pinned, pre-authoring rooms seed clean | RUNBOOK tally; seam contracts documented in ldtk_room.gd material-state section and world_state.gd overlay comment | TK-003 ability/puzzle/encounter callers, TK-004 production same-state replay; live-state persistence stays owned by S-003 |
| 2026-07-20 | TK-003 | Ticket closed | red: test_reaction_caster failed to load pre-implementation; green: unit 45 suites/350 tests/2361 checks PASS with 0 script errors; slice smoke 134/134; main boot clean; AbilityData.reaction_verb routes any ability through ReactionCaster preview/cast with fail-closed refusals, air direction plumbing, and identical committed state across exploration/encounter contexts; S-010 review C1 fixed (plate cells excluded from deployment; invariant test) and C2 fixed (refused deployment shows a dialogue instead of silent dead input) | RUNBOOK tally; caster contract in reaction_caster.gd header; AbilityData field doc | TK-004 same-state replay capture; player-facing cast UI/kit allocation lands with S-012 combat and S-004 content; review C3 (hero-keyed defeat with switched leader) routed to S-012/S-013 defeat rework |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- `S-003` persists the resulting state; `S-012` owns combat timing.

## Supersession

- Supersedes: production reaction work implicit in T-093/T-094
- Superseded by: none
