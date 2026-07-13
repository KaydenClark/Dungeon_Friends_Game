# S-004 - V2 Thesis Slice

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-004
**Status:** planned
**Priority:** 2
**Owner:** unassigned
**Updated:** 2026-07-13
**Catalog description:** Build one authored recruit, non-combat resolution, shared-vocabulary puzzle, tactical fight, and persistent world change as a playable v2 loop.
**Blockers:** S-003
**Latest event:** Capability migrated from legacy T-094 without expanding its product scope.
**Next gate:** Complete S-003, refine the authored slice, and activate the first tracer bullet.

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

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Specify the authored recruit and the shortest end-to-end route. | ready | S-003 | pending |
| TK-002 | Build one thin adventure-to-world-change tracer bullet. | ready | TK-001 | pending |
| TK-003 | Complete the authored loop and capture the owner demo. | ready | TK-002 | pending |

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

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- External discovery and fun validation belongs to `S-005`.

## Supersession

- Supersedes: the old Phase 5/6 split as the next build target
- Superseded by: none

