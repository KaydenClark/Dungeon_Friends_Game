# S-014 - Opening Player Experience

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-014
**Status:** planned
**Priority:** 2
**Owner:** Kayden
**Updated:** 2026-07-17
**Catalog description:** Make the opening unified-world journey readable, controllable, recoverable, controller-complete, and understandable without coaching.
**Blockers:** S-003, S-009, S-010, S-011, S-012, S-013
**Latest event:** Legacy visual, movement, input, save, combat-UX, asset, and bug rows were consolidated under one production experience owner.
**Next gate:** Complete the production capability chain, then an Engineer claims TK-001; Kayden owns the blocked TK-006 opening-journey verdict.

## Outcome

A first-time PC player can start, move, understand party/formation/reaction and
encounter states, recover from mistakes, save/continue, and finish the opening
route with keyboard or controller and without developer coaching.

## Why It Matters

The thesis systems are only evidence for a Steam game if players can perceive
and operate them. Legacy work scattered this responsibility across asset
batches, bugs, combat acceptance, and deferred menus.

## Current Verified State

The v1 tutorial is smoke-green and has keyboard/controller glyph switching,
save failure boundaries, dialogue, movement, and debug tours. Remaining evidence
includes facing/aggro ambiguity, viewport layout, move undo, focus/blocked
feedback, party cohesion, save recovery language, incomplete assets/audio, and
no production unified-world onboarding.

## Desired Behavior

- Every important state change has readable board, HUD, audio, and prompt cues.
- Keyboard and controller complete the same route with coherent navigation.
- Tutorial teaching introduces one idea at a time and never requires dev keys.
- Save/load/defeat/downed-member failures explain recovery without data loss.
- Supported resolutions remain legible and capture proof fails closed.

## Decisions And Contracts

- D-019, D-022, D-023, D-029, D-030, D-032, D-036, and D-037 govern.
- Mobile/touch remains postponed.
- Player-facing text never tells players to inspect logs.
- Visual/audio assets must respect provenance and release gating in `S-015`.

## Non-Goals

- Final marketing polish, every accessibility option, mobile controls, full
  settings suite, or content beyond the opening journey.

## Dependencies And Blockers

- Production state, formations, reactions, combat, persistence, and progression:
  `S-003`, `S-009` through `S-013`.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Build the production readability/accessibility matrix for party, height, materials, intents, HUD, and supported resolutions. | ready | S-003, S-009, S-010, S-011, S-012, S-013 | pending |
| TK-002 | Implement the shortest no-coaching onboarding for controls, formation, friend verb, puzzle, and encounter entry. | ready | TK-001 | pending |
| TK-003 | Close movement/facing/aggro, move-undo, focus/blocked-input, save failure, defeat, and party-status recovery gaps. | ready | TK-002 | pending |
| TK-004 | Complete controller navigation/glyph parity and the minimum coherent visual/audio asset pass for the opening route. | ready | TK-003 | pending |
| TK-005 | Run and capture keyboard and controller first-session replays at the supported resolutions. | ready | TK-004 | pending |
| TK-006 | Record Kayden's complete opening-journey verdict. | blocked | TK-005 | pending |

## Acceptance Criteria

- [ ] Important world, party, reaction, intent, and recovery states are legible.
- [ ] Keyboard and controller complete the same route.
- [ ] No required action depends on dev-only input or prior explanation.
- [ ] Failure and recovery preserve data and communicate next action.
- [ ] 1280x720, 1920x1080, and 3440x1440 checks pass where applicable.
- [ ] Kayden accepts the complete opening journey.

## Testing Seams

- Input/prompt/UI layout tests.
- Production tutorial smoke with keyboard and controller events.
- Save/corrupt/recovery and transition race tests.
- Deterministic capture tours plus human visual inspection.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

## Documentation Impact

- Update Blueprint experience constraints, Runbook controls/recovery/demo,
  README player-facing route, and asset plan/provenance.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | spec | Legacy T-028/T-051..T-059 and B-08..B-19 UX residue consolidated | source, tests, asset plans, playtests, and bug rows inspected | new stable player-experience spec | dependencies and all slices |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- External discovery evidence belongs to `S-005`.

## Supersession

- Supersedes: fragmented production readability, input, recovery, and polish backlog
- Superseded by: none
