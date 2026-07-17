# S-008 - Reaction Gate Readability

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-008
**Status:** complete
**Priority:** 0
**Owner:** codex-engineer
**Updated:** 2026-07-17
**Catalog description:** Make the reaction-room payoff legible and prove the recut with repeatable two-resolution tours.
**Blockers:** none
**Latest event:** Spec completed and removed from the hot board.
**Next gate:** none

## Outcome

The existing gray-box room communicates reaction changes on the board, keeps
combat information unobscured, and produces repeatable two-resolution proof
that the readability defects are closed.

## Why It Matters

`S-002` is the pivot's owner risk gate. Its verdict should consume a proven
readability build rather than test nearly invisible fire and smoke.

## Current Verified State

The remediated room passes 111/111 scripted assertions with exact 1280x720 and
1920x1080 physical PNGs; the consequence panel is disjoint from the main HUD
and every world-attached unit HP label. Claude's
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
| TK-001 | Add failing readability/cue assertions, then recut fire/smoke marks, encounter-only hints, and blocked/focus feedback without changing reaction results. | done | none | Auditor GREEN on immutable 493b40a..16c2c1d; 38 suites / 286 tests / 1811 checks; exact 1280x720 and 1920x1080 tours 111/111; import, main boot, and 134/134 slice smoke |
| TK-002 | Run the full suite and both resolution tours, inspect the artifacts, and record the readability proof. | done | TK-001 | Thirteen exact PNGs at each review size inspected; fire/smoke, focus, blocked aim, encounter hint suppression, preview/HUD separation, and every unit HP label are independently visible |

## Acceptance Criteria

- [x] Distinct fire and smoke remain readable when combined.
- [x] Exploration hints never cover active encounter information.
- [x] Blocked aim and focus state do not look like a frozen game.
- [x] Both resolution tours and the full unit suite remain green.
- [x] Captured tour artifacts make the recut independently inspectable.

## Testing Seams

- `test_reaction_room_logic.gd`.
- Scripted reaction-room tours at 1280x720 and 1920x1080.
- Artifact inspection at both review resolutions.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/reaction_room_spike.tscn --resolution 1280x720 -- --out=/tmp/dungeon-reaction-gate-1280 --expected-size=1280x720
/Applications/Godot.app/Contents/MacOS/Godot --fullscreen --path . scenes/dev/reaction_room_spike.tscn --resolution 1920x1080 -- --out=/tmp/dungeon-reaction-gate-1920 --expected-size=1920x1080
```

## Documentation Impact

- Update this spec and Runbook if the proof procedure changes; `S-002` consumes
  the completed result without duplicating its verdict here.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | spec | Legacy T-084/T-093 readability evidence promoted | source, tests, captures, and Claude playtest notes inspected | new stable gate-preparation spec | two agent-produced proof tickets |
| 2026-07-17 | TK-001 | Added shape-distinct fire/smoke marks, encounter-only exploration hints, and explicit aim/focus recovery feedback without changing reaction outcomes | expected red: reaction-room suite could not load four missing presentation seams; green: 38 suites / 283 tests / 1791 checks, import, main boot, 1280x720 and 1920x1080 tours at 90/90 each, 134/134 slice smoke; inspected burned, spread, and encounter captures at both sizes | S-008 and Runbook updated | immutable pushed-head Auditor review; TK-002 remains ready |
| 2026-07-17 | TK-001 | Remediated Auditor findings with reserved combat-label rectangles, exact-size fail-closed captures, and live scripted hint/focus/aim proof | expected red: missing layout and capture-size seams; reproduced nominal 1920 run as rejected 1920x928; green: 38 suites / 285 tests / 1808 checks, import, main boot, exact 1280x720 and fullscreen 1920x1080 tours at 111/111 each, 134/134 slice smoke; inspected focus, recovery, blocked aim, encounter cue, and consequence-panel captures at both sizes | S-008 and Runbook updated | push immutable checkpoint and exact-head Auditor re-review; TK-002 remains ready |
| 2026-07-17 | TK-001 | Published the remediated Engineer checkpoint at `c803f0d` | remote branch resolved to the exact implementation checkpoint after push | spec header and generated Taskboard handed off | exact-head Auditor re-review; TK-002 remains ready |
| 2026-07-17 | TK-001 | Remediated the exact-head audit finding that world-attached HP labels were absent from the panel collision contract | expected red: reaction-room suite could not load the missing HP-label shift seam; green: 38 suites / 286 tests / 1811 checks, import, main boot, exact 1280x720 and fullscreen 1920x1080 tours at 111/111 each, 134/134 slice smoke; inspected both `11-spark-cancel-preview` captures with Blocker1 and every HP label visible outside the panel | S-008 and Runbook updated | push immutable checkpoint and exact-head Auditor re-review; TK-002 remains ready |
| 2026-07-17 | TK-001 | Published the HP-label collision remediation at `a218d25` | remote branch resolved to the exact implementation checkpoint after push | spec header and generated Taskboard handed off | exact-head Auditor re-review; TK-002 remains ready |
| 2026-07-17 | TK-001 | Ticket closed | Auditor GREEN on immutable 493b40a..16c2c1d; 38 suites / 286 tests / 1811 checks; exact 1280x720 and 1920x1080 tours 111/111; import, main boot, and 134/134 slice smoke | S-008, RUNBOOK.md, and generated TASKBOARD.md updated | TK-002 proof recording and spec completion |
| 2026-07-17 | TK-002 | Ticket closed | Thirteen exact PNGs at each review size inspected; fire/smoke, focus, blocked aim, encounter hint suppression, preview/HUD separation, and every unit HP label are independently visible | S-008 and RUNBOOK.md record the repeatable proof | Kayden fun, revise, or stop verdict remains in S-002/TK-003; none for S-008 |
| 2026-07-17 | spec | Spec completed | Acceptance gates satisfied | Documentation impact recorded above | none |

## Completion Result

Completed. Fire and smoke now have distinct board silhouettes; exploration
hints yield to the encounter HUD; aim and focus refusals have recovery feedback;
and the consequence panel remains disjoint from the main HUD and every unit HP
label. The exact two-resolution tours, full automated gates, artifact inspection,
and immutable-head Auditor review are green. The remaining fun, revise, or stop
decision belongs exclusively to `S-002 / TK-003`.

## Remaining Limitations Or Follow-Up Specs

- Production presentation belongs to `S-014`.

## Supersession

- Supersedes: reaction-readability fragments in T-084, T-093, and B-22
- Superseded by: none
