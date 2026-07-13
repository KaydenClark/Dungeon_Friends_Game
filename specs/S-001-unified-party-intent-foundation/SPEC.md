# S-001 - Unified Party And Intent Foundation

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-001
**Status:** complete
**Priority:** 0
**Owner:** Kayden
**Updated:** 2026-07-12
**Catalog description:** Prove same-room encounters, a visible formed party, deterministic intent rounds, and exact previews on the orthogonal grid.
**Blockers:** none
**Latest event:** Formation, encounter-cue, four-unit intent, and guard-field prototypes were consolidated and replayed green.
**Next gate:** none

## Outcome

The v2 combat identity has a verified foundation: the active party remains
visible, deployment follows a selected formation, encounter mode starts clearly
inside the current room, all four members act in any order, and intent previews
match resolution.

## Why It Matters

This retired the largest structural unknowns before production migration and
gave the reaction vocabulary one neutral party/encounter seam to build on.

## Current Verified State

The development spikes for three-quarter height, visible-party movement,
formation/deployment, unified encounters, and deterministic intent are merged in
`integration`. They are bounded proof surfaces, not production architecture.

## Desired Behavior

- Exploration followers are pass-through and recover through one-cell chokes.
- Line, square, and spaced formations produce deterministic legal deployment.
- Combat starts in the current room after a clear local encounter cue.
- Four party units act in any order during intent rounds.
- Normal forecast refill preserves shown verbs; invalidation rebuilds the plan.
- Guard preview, affected cells, duration, and result are exact.

## Decisions And Contracts

- D-025, D-026, D-027, D-029, D-030, D-036, and D-037 remain authoritative.
- The logic grid stays orthogonal; elevation and perspective are presentation
  plus integer cell metadata.
- Dev spike code graduates only through a later explicit production spec.

## Non-Goals

- Production-room migration, authored roster content, persistence, final art,
  balance, or broad encounter content.

## Dependencies And Blockers

- none

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Prove elevation, visible party, formation, and legal deployment. | done | none | formation and height suites plus captured formation states passed |
| TK-002 | Prove same-room encounter entry and deterministic four-unit intent rounds. | done | TK-001 | combined cue and intent replay passed with exact preview checks |
| TK-003 | Prove generic guard-field protection without bespoke pair logic. | done | TK-002 | guard preview, duration, cancellation, and target-leak checks passed |

## Acceptance Criteria

- [x] Height and legal movement read on the orthogonal grid.
- [x] Exploration followers remain pass-through and formation-aware.
- [x] Encounter entry is unmistakable without a scene swap.
- [x] Four units act in any order under deterministic intent rounds.
- [x] Forecast and guard previews equal their results.

## Testing Seams

- Pure formation layout, visible-party exploration model, and intent logic.
- Scripted dev-scene tours at 1280x720 and 1920x1080.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/intent_prototype_spike.tscn --resolution 1280x720 -- --out=/tmp/dungeon-intent
```

## Documentation Impact

- Blueprint decisions and Runbook proof commands were updated during the
  original slices.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-12 | TK-001 | Formation foundation consolidated | pure formation and visible-party suites green; formation and recovery captures reviewed | Blueprint and Runbook already updated | none |
| 2026-07-12 | TK-002 | Encounter cue and intent recut consolidated | automated combined replay green with real four-member deployment snapshot | Blueprint and Runbook already updated | none |
| 2026-07-12 | TK-003 | Generic guard field proven | exact guard preview, duration, cancellation, and replay checks green | Docs checked; no update needed because existing decisions own the contract | none |

## Completion Result

The bounded v2 foundation is accepted and available to dependent specs. It does
not claim production migration or final game feel.

## Remaining Limitations Or Follow-Up Specs

- `S-002` tests whether the shared vocabulary is fun.
- `S-003` adds persistent resolution after that owner gate.

## Supersession

- Supersedes: legacy split-mode prototype direction
- Superseded by: none
