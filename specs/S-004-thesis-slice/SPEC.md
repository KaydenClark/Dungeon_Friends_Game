# S-004 - V2 Thesis Slice

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-004
**Status:** active
**Priority:** 2
**Owner:** claude-engineer
**Updated:** 2026-07-20
**Catalog description:** Build one authored recruit, non-combat resolution, shared-vocabulary puzzle, tactical fight, and persistent world change as a playable v2 loop.
**Blockers:** none
**Latest event:** TK-002 closed with proof.
**Next gate:** Complete TK-003.

## Outcome

One short playable route proves adventure, recruitment, party progression,
environmental problem-solving, tactical encounter resolution, and permanent
world change as one coherent game loop.

## Why It Matters

The prototypes prove mechanics separately; this proves the v2 thesis as a game
before roster, region, or content scale-up.

## Current Verified State

The repository contains the v1 forest/tutorial slice plus bounded v2 dev
prototypes. It does not yet contain one authored production path that joins the
new contracts end to end.

## Desired Behavior

- Recruit one authored friend with a real verb, role, and personality hook.
- Resolve one NPC problem without combat.
- Solve one environmental puzzle through the shared vocabulary.
- Win one meaningful deterministic tactical encounter in the current room.
- Persist the resulting world change.
- Demonstrate every loop step in under one minute.

## Decisions And Contracts

- D-025 through D-037 apply.
- The temporary Buddy contract does not silently become the authored recruit.
- Existing v1 code retires only after the replacement slice is proven.

## Non-Goals

- Full roster, complete region, final art/audio, economy, shops, or content
  production beyond the smallest coherent thesis route.

## Dependencies And Blockers

- `S-003` complete with persistent world resolution.
- `S-009` through `S-014` complete with the production world, party,
  vocabulary, combat, progression, and opening player-experience contracts.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Specify the authored recruit and the shortest end-to-end route. | done | none | docs-only slice: the route contract docs/planning/S004_THESIS_ROUTE.md specifies Wren as the authored recruit (S-013 contract placed in-world with the D-033 role/hook; Buddy does not graduate) and the shortest end-to-end route - the Withered Grove: doorway adventure, recruit-on-dialogue, Moss's non-combat herb-bed resolution via grow, vine-gate vocabulary puzzle, grove_guardian tactical fight, persistent grove-heart regrowth - each beat under a minute and mapped to its proven contract; the five smallest new mechanics TK-002 must build are named with fail-closed rules; flagged Blueprint row D-044 records the product call per D-038; referenced paths verified present; doctor green |
| TK-002 | Build one thin adventure-to-world-change tracer bullet. | done | TK-001 | red: the new tests/test_grove_route.gd suite aborted on the missing GroveRoom/VineGate/Npc route contract (suite failed to load, precedented red); green: unit 50 suites/401 tests/2632 checks PASS with 0 script errors; slice smoke 134/134 (the v1 forest route survives the one-doorway delta); boot clean; the tracer drives every thesis beat at the seam level - grove.ldtk authors cleanly under D-039 (fail-closed trellis and recruit-id validation tested), Wren recruits on dialogue end and her NPC departs/never respawns (roster-derived), Moss's herb bed resolves without combat via a grow cast and survives rebuild (persisted material truth), the vine gate blocks then opens on trellis growth and stays open, grove_guardian victory regrows the four heart cells through the same preview/commit seam plus grove_restored, and the full recruit+vines+victory state survives a JSON save round trip; forest south doorway and withered_grove registry row wired both ways; _spawn_party made reentrant for mid-room recruits |
| TK-003 | Complete the authored loop and capture the under-one-minute thesis demo artifact. | ready | TK-002 | pending |
| TK-004 | Record Kayden's thesis-direction acceptance or revision verdict. | blocked | TK-003 | pending |

## Acceptance Criteria

- [ ] One authored recruit replaces the placeholder contract in this slice.
- [ ] The slice includes non-combat, puzzle, and tactical resolutions.
- [ ] The world change persists.
- [ ] Every loop step is demonstrable in under one minute.
- [ ] Kayden accepts the slice as evidence for the v2 game direction.

## Testing Seams

- Pure friend verb and reaction contracts.
- Scene smoke from recruitment through persisted world change.
- Owner-visible one-command or short interactive demo.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

## Documentation Impact

- Update Blueprint current product shape and data/contracts, Runbook demo path,
  README playable-state summary, and world lore for authored content.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-13 | spec | Migrated from legacy T-094 | legacy scope reconciled against v2 decisions | v2.3 spec created | S-003 and all implementation slices |
| 2026-07-17 | spec | Positioned the thesis slice after the production capability chain | full canon-to-spec coverage matrix reviewed | dependencies linked to S-003 and S-009 through S-014 | all implementation slices |
| 2026-07-20 | spec | Dependency gate opened per D-038 (flagged product call, not a new decision): S-003 is complete, and S-009 through S-014 have every engineering ticket closed with proof - their only remaining tickets are the owner verdicts D-038 batches into TK-004 here, so treating those deferred verdicts as blockers would deadlock the chain Kayden ordered | spec statuses and ticket tables of S-003 and S-009..S-014 inspected via the workbench; doctor green | this spec's status/blockers; Taskboard rerendered | TK-001 route specification, TK-002 tracer, TK-003 demo artifact, TK-004 Kayden verdict |
| 2026-07-20 | TK-001 | Ticket closed | docs-only slice: the route contract docs/planning/S004_THESIS_ROUTE.md specifies Wren as the authored recruit (S-013 contract placed in-world with the D-033 role/hook; Buddy does not graduate) and the shortest end-to-end route - the Withered Grove: doorway adventure, recruit-on-dialogue, Moss's non-combat herb-bed resolution via grow, vine-gate vocabulary puzzle, grove_guardian tactical fight, persistent grove-heart regrowth - each beat under a minute and mapped to its proven contract; the five smallest new mechanics TK-002 must build are named with fail-closed rules; flagged Blueprint row D-044 records the product call per D-038; referenced paths verified present; doctor green | Blueprint D-044 flagged row; WORLD_LORE thesis-slice canon for Wren; route contract doc created | TK-002 tracer bullet builds the five mechanics; TK-003 authored loop + under-one-minute demo; TK-004 Kayden batch verdict |
| 2026-07-20 | TK-002 | Ticket closed | red: the new tests/test_grove_route.gd suite aborted on the missing GroveRoom/VineGate/Npc route contract (suite failed to load, precedented red); green: unit 50 suites/401 tests/2632 checks PASS with 0 script errors; slice smoke 134/134 (the v1 forest route survives the one-doorway delta); boot clean; the tracer drives every thesis beat at the seam level - grove.ldtk authors cleanly under D-039 (fail-closed trellis and recruit-id validation tested), Wren recruits on dialogue end and her NPC departs/never respawns (roster-derived), Moss's herb bed resolves without combat via a grow cast and survives rebuild (persisted material truth), the vine gate blocks then opens on trellis growth and stays open, grove_guardian victory regrows the four heart cells through the same preview/commit seam plus grove_restored, and the full recruit+vines+victory state survives a JSON save round trip; forest south doorway and withered_grove registry row wired both ways; _spawn_party made reentrant for mid-room recruits | entities_post_import authoring conventions extended; route contracts documented inline at each new site; D-044 route doc unchanged | TK-003 completes the authored loop windowed with the under-one-minute demo artifact; art/audio for the grove stays placeholder per S-004 non-goals |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- External discovery and fun validation belongs to `S-005`.

## Supersession

- Supersedes: the old Phase 5/6 split as the next build target
- Superseded by: none
