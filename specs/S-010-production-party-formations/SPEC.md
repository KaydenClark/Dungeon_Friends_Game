# S-010 - Production Party Formations

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-010
**Status:** planned
**Priority:** 1
**Owner:** Kayden
**Updated:** 2026-07-17
**Catalog description:** Graduate line, square, and spaced party formations into production exploration, leader switching, save state, and legal encounter deployment.
**Blockers:** S-009
**Latest event:** T-096's pure planner and visible-party model are green but explicitly dev-only.
**Next gate:** Complete S-009, then an Engineer claims TK-001; the owner feel verdict batches into the S-004 thesis replay per D-038.

## Outcome

Players select a formation that survives movement and leader switching,
compresses safely through chokes, reforms afterward, and supplies deterministic
legal production encounter deployment.

## Why It Matters

Formation choice turns ally occupancy from accidental congestion into a
deliberate tactical setup and makes the visible party usable in authored rooms.

## Current Verified State

`PartyFormationLayout.plan_deployment` and
`VisiblePartyExplorationModel` prove three formations, four-facing rotation,
reachable fallback, choke recovery, leader switching, and follower
non-interaction. They live under `scripts/dev` and are not saved or wired to
production rooms.

## Desired Behavior

- The pure planner graduates unchanged behind a production namespace/API.
- Selection persists across movement, leader changes, room changes, and save.
- Production UI exposes exactly the accepted choices without dev-only keys.
- Deployment uses current authored legality and becomes occupying combat state.

## Decisions And Contracts

- D-029 and D-037 govern.
- Formation choice and transient movement state remain distinct.
- Followers never hold plates, push blocks, interact, or block exploration.
- Combat occupancy begins only after legal deployment.

## Non-Goals

- Mid-combat free reformation, final menu art, cover/high-ground bonuses, or
  bespoke character formations.

## Dependencies And Blockers

- `S-009` production party and world-state lifecycle.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Promote the pure formation/deployment planner with dev-parity tests and no algorithm change. | ready | S-009 | pending |
| TK-002 | Integrate selection, leader switching, choke compression, and reformation into production exploration. | ready | TK-001 | pending |
| TK-003 | Persist formation identity and expose the smallest production selector/control surface. | ready | TK-002 | pending |
| TK-004 | Consume legal deployment in the production encounter seam and capture the formation/choke/deployment demo. | ready | TK-003 | pending |
| TK-005 | Owner formation/choke/deployment-feel verdict - consolidated into the S-004 thesis replay per D-038 (2026-07-19); TK-004's demo artifact feeds that batch review. | deferred | S-004 | owner verdict batches at S-004 per D-038 |

## Acceptance Criteria

- [ ] Dev parity remains exact for the three formations.
- [ ] Followers remain pass-through and effect-free outside encounters.
- [ ] Selection survives leader, room, and save transitions.
- [ ] Deployment returns four distinct reachable legal cells.
- [ ] Formation/choke/deployment demo captured for the S-004 batch review; the owner spacing-feel verdict rides that replay (D-038).

## Testing Seams

- Pure planner parity and invalid input.
- Production party movement/interaction.
- Save round-trip.
- Windowed choke and deployment replay.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

## Documentation Impact

- Update Blueprint party/data contracts, Runbook controls/demo, and README when
  production selection is visible.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | spec | Legacy T-096 promoted into a production capability | planner/model/tests and prior 36-suite/244-test proof inspected | new stable formation spec | all slices and owner verdict |
| 2026-07-19 | TK-005 | D-038 owner-approval consolidation: the feel verdict batches into the S-004 thesis replay; TK-005 deferred to that gate | Kayden chat directive 2026-07-19; Blueprint D-038 row | this spec, Blueprint | TK-001 through TK-004 |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- Production tactical consumption continues in `S-012`.

## Supersession

- Supersedes: T-096 owner-replay remainder and dev-only formation ownership
- Superseded by: none
