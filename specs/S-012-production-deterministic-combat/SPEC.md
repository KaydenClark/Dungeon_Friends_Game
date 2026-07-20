# S-012 - Production Deterministic Combat

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-012
**Status:** planned
**Priority:** 1
**Owner:** Kayden
**Updated:** 2026-07-17
**Catalog description:** Replace v1 d10 arena combat with production same-room intent rounds, exact previews, four-unit any-order actions, and environmental resolution.
**Blockers:** S-009, S-010, S-011
**Latest event:** Intent/guard/cue behavior is proven in dev; production CombatScene still rolls d10 and swaps to authored arenas.
**Next gate:** Complete S-009 through S-011, then an Engineer claims TK-001; the owner combat-feel/retirement verdict batches into the S-004 thesis replay per D-038.

## Outcome

Production encounters begin clearly in the current room, expose trustworthy
future verbs and exact current intent, let four party members act in any order,
and resolve deterministic combat and environmental effects without a scene,
arena, camera, or ruleset swap.

## Why It Matters

This is the v2 tactical identity and retires the largest remaining contradiction
between accepted canon and the default playable build.

## Current Verified State

Dev `IntentLogic` proves rolling horizon, invalidation rebuild, exact cells and
damage, four-unit actions, stun/push cancellation, and guarded cells. Production
`CombatScene` is 1057 lines, selects authored arenas, rolls d10, uses per-unit
initiative, and zooms away from the world.

## Desired Behavior

- A production pure intent domain preserves every accepted dev invariant.
- Encounter `ENTER` gates input, cues turn-based mode, and stays local.
- Four occupying party members act in any order with exact actions.
- Enemy and environment resolution use production reactions.
- V1 combat retires only after parity, smoke, and owner proof pass.

## Decisions And Contracts

- D-025, D-026, D-027, D-036, and D-037 govern.
- Future forecast exposes verbs only; current intent exposes exact outcomes.
- No hit, crit, target, or AI outcome RNG.
- Authored arena assets may be salvaged as in-world rooms, not a production
  battle selector.

## Non-Goals

- Full roster balance, every enemy family, final audio/art, high ground/cover,
  or public release tuning.

## Dependencies And Blockers

- `S-009` unified runtime.
- `S-010` production formation/deployment.
- `S-011` production reaction vocabulary.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Promote the pure intent/preview domain with dev-parity and zero-RNG tests. | ready | S-009, S-010, S-011 | pending |
| TK-002 | Implement local ENTER, forecast, exact current intent, and encounter-mode lifecycle in a production room. | ready | TK-001 | pending |
| TK-003 | Integrate four-unit any-order actions, occupancy, movement, push/stun, and guarded-cell counterplay. | ready | TK-002 | pending |
| TK-004 | Integrate environmental resolution, move undo, rewards, defeat, and staged retirement of d10/arena/zoom code. | ready | TK-003 | pending |
| TK-005 | Run and capture the full production encounter replay with deterministic proof. | ready | TK-004 | pending |
| TK-006 | Owner combat-feel and v1-retirement verdict - consolidated into the S-004 thesis replay per D-038 (2026-07-19); retired v1 code stays recoverable in git history until that replay accepts. | deferred | S-004 | owner verdict batches at S-004 per D-038 |

## Acceptance Criteria

- [ ] Production intent behavior matches the accepted dev contract.
- [ ] No random hit/crit/outcome path remains in the v2 encounter.
- [ ] Same room, camera, positions, puzzle state, and world state survive.
- [ ] All four party members act in any order with legal occupancy.
- [ ] Preview equals result for combat and environment.
- [ ] Deterministic full-encounter replay captured for the S-004 batch review; the owner feel/retirement verdict rides that replay (D-038), and retired v1 code remains recoverable via git until it passes.

## Testing Seams

- Intent domain parity and zero-RNG scan.
- Production encounter lifecycle and occupancy.
- Full production room smoke and deterministic replay.
- Windowed cue/forecast/action/result captures.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

## Documentation Impact

- Update Blueprint combat/runtime truth, Runbook controls and proof, README
  playable-state summary, and remove stale d10/arena user guidance only when
  the default route changes.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | spec | Production combat migration extracted from T-090/T-092/T-097 and live source | CombatScene, TurnManager, SceneManager, IntentLogic, and tests inspected | new stable combat spec | dependencies and all slices |
| 2026-07-19 | TK-006 | D-038 owner-approval consolidation: the combat-feel/retirement verdict batches into the S-004 thesis replay; TK-006 deferred to that gate; retired v1 code stays git-recoverable until it passes | Kayden chat directive 2026-07-19; Blueprint D-038 row | this spec, Blueprint | TK-001 through TK-005 |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- Balance and player onboarding continue in `S-013` and `S-014`.

## Supersession

- Supersedes: v1 CombatScene/d10/arena/initiative production path when complete
- Superseded by: none
