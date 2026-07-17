# S-008 - Reaction Gate Readability

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-008
**Status:** active
**Priority:** 0
**Owner:** codex-engineer
**Updated:** 2026-07-17
**Catalog description:** Make the reaction-room payoff legible and prove the recut with repeatable two-resolution tours.
**Blockers:** none
**Latest event:** TK-001 recut is green in the isolated Engineer worktree; immutable checkpoint review is pending.
**Next gate:** Push the verified checkpoint for an exact-head Auditor review before closing TK-001.

## Outcome

The existing gray-box room communicates reaction changes on the board, keeps
combat information unobscured, and produces repeatable two-resolution proof
that the readability defects are closed.

## Why It Matters

`S-002` is the pivot's owner risk gate. Its verdict should consume a proven
readability build rather than test nearly invisible fire and smoke.

## Current Verified State

The room passes 90/90 scripted assertions at 1280x720 and 1920x1080. Claude's
interactive pass called the system fun but found fire/smoke hard to distinguish,
the exploration hint overlapping combat HUD, and blocked/focus input unclear.
That is useful evidence, not Kayden's missing verdict.

## Desired Behavior

- Fire, smoke, wet, ice, and their combinations read from the board.
- Exploration instructions disappear when the encounter HUD is active.
- The legend and preview stay backed and viewport-contained.
- Ignored focus or blocked aim has visible feedback.
- Existing preview-equals-result and capture-completeness checks remain green.
- The two-resolution tour records inspectable artifacts and repeatable proof.

## Decisions And Contracts

- This is a bounded dev-proof recut, not production UI architecture.
- No reaction rule, balance constant, cast range, cost, or friend kit changes.
- `S-002` alone owns Kayden's fun, revise, or stop verdict.

## Non-Goals

- Production migration, persistence, final art/audio, ability balance, or broad
  accessibility/settings work.

## Dependencies And Blockers

- Completed `S-001` and automated `S-002 / TK-001..TK-002` proof.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Add failing readability/cue assertions, then recut fire/smoke marks, encounter-only hints, and blocked/focus feedback without changing reaction results. | in-progress | none | red missing-seam suite; green unit/tours/import/boot/smoke; Auditor pending |
| TK-002 | Run the full suite and both resolution tours, inspect the artifacts, and record the readability proof. | ready | TK-001 | pending |

## Acceptance Criteria

- [ ] Distinct fire and smoke remain readable when combined.
- [ ] Exploration hints never cover active encounter information.
- [ ] Blocked aim and focus state do not look like a frozen game.
- [ ] Both resolution tours and the full unit suite remain green.
- [ ] Captured tour artifacts make the recut independently inspectable.

## Testing Seams

- `test_reaction_room_logic.gd`.
- Scripted reaction-room tours at 1280x720 and 1920x1080.
- Artifact inspection at both review resolutions.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/reaction_room_spike.tscn --resolution 1280x720 -- --out=/tmp/dungeon-reaction-gate-1280
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/reaction_room_spike.tscn --resolution 1920x1080 -- --out=/tmp/dungeon-reaction-gate-1920
```

## Documentation Impact

- Update this spec and Runbook if the proof procedure changes; `S-002` consumes
  the completed result without duplicating its verdict here.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | spec | Legacy T-084/T-093 readability evidence promoted | source, tests, captures, and Claude playtest notes inspected | new stable gate-preparation spec | two agent-produced proof tickets |
| 2026-07-17 | TK-001 | Added shape-distinct fire/smoke marks, encounter-only exploration hints, and explicit aim/focus recovery feedback without changing reaction outcomes | expected red: reaction-room suite could not load four missing presentation seams; green: 38 suites / 283 tests / 1791 checks, import, main boot, 1280x720 and 1920x1080 tours at 90/90 each, 134/134 slice smoke; inspected burned, spread, and encounter captures at both sizes | S-008 and Runbook updated | immutable pushed-head Auditor review; TK-002 remains ready |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- Production presentation belongs to `S-014`.

## Supersession

- Supersedes: reaction-readability fragments in T-084, T-093, and B-22
- Superseded by: none
