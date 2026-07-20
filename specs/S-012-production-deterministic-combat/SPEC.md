# S-012 - Production Deterministic Combat

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-012
**Status:** active
**Priority:** 1
**Owner:** claude-engineer
**Updated:** 2026-07-20
**Catalog description:** Replace v1 d10 arena combat with production same-room intent rounds, exact previews, four-unit any-order actions, and environmental resolution.
**Blockers:** none
**Latest event:** TK-005 closed with proof.
**Next gate:** Complete TK-006.

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
| TK-001 | Promote the pure intent/preview domain with dev-parity and zero-RNG tests. | done | none | red: test_intent_logic failed to load against the production path pre-move; green: unit 45 suites/351 tests/2368 checks PASS with 0 script errors; slice smoke 134/134; --import clean; parity test pins the intent spike loads the exact production script, the retired dev path stays absent, and the domain source is structurally zero-RNG (no randi/randf/randomize/rand_range) |
| TK-002 | Implement local ENTER, forecast, exact current intent, and encounter-mode lifecycle in a production room. | done | TK-001 | red: 5 script-error aborts on missing room_encounter; green: unit 46 suites/356 tests/2407 checks PASS with 0 script errors; slice smoke 134/134; main boot clean; RoomEncounter mirrors the live room into the promoted IntentLogic state (roster units at deployed cells, authored enemy stats, props blocked), declares a deterministic exact intent with verbs-only forecast, ENTER-beat panel reveal per D-036, node sync for declared moves, fail-closed setup undoing deployment; windowed capture docs/screenshots/s012-tk002-intent shows FOREST SLIME INTENT: SLAM 4 dmg + NEXT verbs + highlighted target cell in the production room |
| TK-003 | Integrate four-unit any-order actions, occupancy, movement, push/stun, and guarded-cell counterplay. | done | TK-002 | red: 5 script-error aborts on the missing party-action APIs; green: unit 46 suites/361 tests/2442 checks PASS with 0 script errors; slice smoke 134/134; main boot clean; any-order unit switching, budgeted legal movement synced to room occupancy, exact preview-equals-result attacks, shove/bash canceling declared intents, one-round guard cells, end-of-turn resolution into the next declaration, and kill-to-victory through the seam's reward path; encounter-mode input map (WASD/1-4/Tab/Q); windowed combat_round_demo 6/6 PASS with 3 captures docs/screenshots/s012-tk003-combat |
| TK-004 | Integrate environmental resolution, move undo, rewards, defeat, and staged retirement of d10/arena/zoom code. | done | TK-003 | red: 3 targeted defeat-path failures pre-implementation (plus undo/environment additions); green: unit 46 suites/365 tests/2465 checks PASS with 0 script errors; slice smoke 134/134 now explicitly pinning the v1 fallback; main boot clean; environment_tick integrated at round end (exact burn ticks, exact effect expiry), move undo with budget refund locked by acting, party-wipe defeat releasing the encounter into the T-041 rules, HP write-back clamped at zero on every resolution, skip-combat reordered ahead of the seam, and unified_encounters flipped to the production default (D-042 staged retirement; v1 git-recoverable + flag-reachable) |
| TK-005 | Run and capture the full production encounter replay with deterministic proof. | done | TK-004 | windowed encounter_replay_demo: two scripted fights on fresh sessions produce byte-identical complete event logs (entry intent, per-round intents+forecasts, attack damage, resolution summaries, XP delta, final HP) proving D-026 zero-RNG end to end, with victory reached and 4 captures docs/screenshots/s012-tk005-replay (ENTER cue, intent+forecast panel, shove counterplay, victory); unit 46 suites/365 tests/2465 checks PASS; slice smoke 134/134; --import clean |
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
| 2026-07-20 | spec | Activated: S-009 complete; S-010 and S-011 build slices (TK-001..TK-004) closed with proof, their owner feel/vocabulary verdicts batched at the S-004 thesis replay per D-038 - TK-001's spec-level blockers cleared for build eligibility on that basis | S-009 completion evidence; S-010/S-011 ticket proofs; spec doctor green after activation and rerender | spec header + TK-001 blocker row updated; hot board rerendered | TK-001 through TK-006 |
| 2026-07-20 | TK-001 | Ticket closed | red: test_intent_logic failed to load against the production path pre-move; green: unit 45 suites/351 tests/2368 checks PASS with 0 script errors; slice smoke 134/134; --import clean; parity test pins the intent spike loads the exact production script, the retired dev path stays absent, and the domain source is structurally zero-RNG (no randi/randf/randomize/rand_range) | RUNBOOK tally; intent_logic.gd header records the promotion contract | TK-002 production ENTER/forecast lifecycle, TK-003 four-unit actions, TK-004 environmental resolution + v1 retirement, TK-005 deterministic replay |
| 2026-07-20 | TK-002 | Ticket closed | red: 5 script-error aborts on missing room_encounter; green: unit 46 suites/356 tests/2407 checks PASS with 0 script errors; slice smoke 134/134; main boot clean; RoomEncounter mirrors the live room into the promoted IntentLogic state (roster units at deployed cells, authored enemy stats, props blocked), declares a deterministic exact intent with verbs-only forecast, ENTER-beat panel reveal per D-036, node sync for declared moves, fail-closed setup undoing deployment; windowed capture docs/screenshots/s012-tk002-intent shows FOREST SLIME INTENT: SLAM 4 dmg + NEXT verbs + highlighted target cell in the production room | RUNBOOK tally; controller contract in room_encounter.gd header | TK-003 party actions/occupancy/counterplay, TK-004 resolution+rewards+v1 retirement, TK-005 deterministic replay; encounter groups still fight as the single touched enemy |
| 2026-07-20 | TK-003 | Ticket closed | red: 5 script-error aborts on the missing party-action APIs; green: unit 46 suites/361 tests/2442 checks PASS with 0 script errors; slice smoke 134/134; main boot clean; any-order unit switching, budgeted legal movement synced to room occupancy, exact preview-equals-result attacks, shove/bash canceling declared intents, one-round guard cells, end-of-turn resolution into the next declaration, and kill-to-victory through the seam's reward path; encounter-mode input map (WASD/1-4/Tab/Q); windowed combat_round_demo 6/6 PASS with 3 captures docs/screenshots/s012-tk003-combat | RUNBOOK tally; controller turn contract in room_encounter.gd | TK-004 environment ticks/reaction integration, move undo, defeat flow, HP write-back, and staged v1 retirement (default flip); TK-005 deterministic replay |
| 2026-07-20 | TK-004 | Ticket closed | red: 3 targeted defeat-path failures pre-implementation (plus undo/environment additions); green: unit 46 suites/365 tests/2465 checks PASS with 0 script errors; slice smoke 134/134 now explicitly pinning the v1 fallback; main boot clean; environment_tick integrated at round end (exact burn ticks, exact effect expiry), move undo with budget refund locked by acting, party-wipe defeat releasing the encounter into the T-041 rules, HP write-back clamped at zero on every resolution, skip-combat reordered ahead of the seam, and unified_encounters flipped to the production default (D-042 staged retirement; v1 git-recoverable + flag-reachable) | Blueprint D-042 flagged retirement row (per D-038); README default-route note; RUNBOOK v2 combat controls + tally; smoke header documents its v1-fallback role | TK-005 deterministic full-encounter replay capture; physical v1 code deletion waits for the S-004 verdict (TK-006); encounter groups still fight as the single touched enemy |
| 2026-07-20 | TK-005 | Ticket closed | windowed encounter_replay_demo: two scripted fights on fresh sessions produce byte-identical complete event logs (entry intent, per-round intents+forecasts, attack damage, resolution summaries, XP delta, final HP) proving D-026 zero-RNG end to end, with victory reached and 4 captures docs/screenshots/s012-tk005-replay (ENTER cue, intent+forecast panel, shove counterplay, victory); unit 46 suites/365 tests/2465 checks PASS; slice smoke 134/134; --import clean | RUNBOOK gains the replay command with the other demos; demo header documents the determinism contract | TK-006 owner combat-feel/retirement verdict batches at the S-004 thesis replay per D-038 |

| 2026-07-20 | TK-004 | Adversarial-review hardening: C1 - pressure plates freeze during in-room encounters and re-evaluate on release, so tactical repositioning can never mutate puzzle state mid-fight (D-025); C2 - a group-authored encounter's victory pays only the fought enemy's stats until groups spawn as in-room units | red-to-green tests test_combat_movement_never_presses_plates and test_group_authored_victory_pays_only_the_fought_enemy; unit 47 suites/370 tests/2494 checks PASS; slice smoke 134/134 | pressure_plate.gd + ldtk_room.gd comments document the freeze/release contract | S1 mutual-kill ordering noted (unreachable until environmental enemy damage lands); production defeat flow (B3) exercised only via v1-tested handle_defeat |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- Balance and player onboarding continue in `S-013` and `S-014`.

## Supersession

- Supersedes: v1 CombatScene/d10/arena/initiative production path when complete
- Superseded by: none
