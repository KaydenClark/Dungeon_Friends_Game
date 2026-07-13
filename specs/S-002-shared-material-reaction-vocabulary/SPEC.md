# S-002 - Shared Material Reaction Vocabulary

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-002
**Status:** needs-review
**Priority:** 0
**Owner:** Kayden
**Updated:** 2026-07-12
**Catalog description:** Prove one preview-first material and effect vocabulary across exploration and encounters, then pass the owner fun gate.
**Blockers:** Kayden played fun/not-fun verdict
**Latest event:** The shared core and gray-box room are merged, automated green, and visually checked at two resolutions.
**Next gate:** Kayden plays the reaction room and records fun, revise, or stop.

## Outcome

One deterministic reaction engine handles grow/vine/fire, water/flood/cold,
wet-cell spark conduction, directional fire spread, and connected-smoke clearing
through the same caller path inside and outside encounters.

## Why It Matters

D-031 is the riskiest assumption in the v2 pivot. Passing tests is insufficient;
the vocabulary must be understandable and fun before roster or world scale-up.

## Current Verified State

`ReactionCore.calculate` returns neutral before/after cell diffs, tags,
statuses, hazards, damage, cancellations, propagation order, and `state_after`.
The gray-box room uses one `cast()` path for both contexts, displays complete
pre-commit consequences, and maps generic owner-hit disruption without bespoke
character pairs. Automation is green; Kayden's played verdict is missing.

## Desired Behavior

- Preview and result match for every reaction.
- Exploration and encounter callers use the same neutral API.
- Propagation order and cascade limits are deterministic.
- The room communicates affected cells, damage, hazards, status/tag changes,
  forced movement, exact units hit, and intent cancellation before commit.
- Kayden judges the vocabulary fun enough to continue, or the pivot stops for
  revision.

## Decisions And Contracts

- D-031 owns the shared-vocabulary invariant.
- Invalid input fails closed and reaction cascades remain bounded.
- Character kits may expose subsets later; the core stays character-neutral.

## Non-Goals

- Persistence, production-map migration, final art/audio, authored friend kits,
  costs/cooldowns, or long-term balance.

## Dependencies And Blockers

- Completed foundation: `S-001`.
- Owner blocker: Kayden's played fun/not-fun verdict.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Build the pure preview-first reaction matrix and neutral API. | done | S-001 | reaction core 55 checks; full unit and smoke suites green |
| TK-002 | Build and verify the same-path gray-box room in both contexts. | done | TK-001 | 90/90 scripted tour assertions at 1280x720 and 1920x1080 |
| TK-003 | Record the owner fun, revise, or stop verdict. | blocked | Kayden played fun/not-fun verdict | pending |

## Acceptance Criteria

- [x] Every vocabulary row is deterministic and preview-first.
- [x] Exploration and encounter contexts call one shared engine.
- [x] The pre-commit consequence panel is readable at both review resolutions.
- [ ] Kayden records a fun/not-fun verdict and the resulting product decision.

## Testing Seams

- `test_reaction_core.gd` for the pure matrix and cascade boundary.
- `test_reaction_room_logic.gd` for caller parity, consequence layout, unit
  mapping, forced movement, and intent cancellation.
- Scripted and interactive reaction-room tours.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/reaction_room_spike.tscn --resolution 1280x720 -- --out=/tmp/dungeon-reactions-1280
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/dev/reaction_room_spike.tscn --resolution 1920x1080 -- --out=/tmp/dungeon-reactions-1920
```

For the owner gate, run the same scene without `--out` and play both exploration
and encounter casts.

## Documentation Impact

- On verdict, update this spec and any resulting Blueprint decision. Render the
  hot board after the status or gate changes.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-12 | TK-001 | Shared reaction core completed | strict red/green; 55 core checks; 38 suites and slice smoke green | Runbook and API contract updated | gray-box consumer and owner verdict |
| 2026-07-12 | TK-002 | Gray-box room and consequence panel completed | 38 suites, 280 tests, 1781 checks; 90/90 tours at both resolutions; representative frames inspected | Runbook and playtest report updated | Kayden played verdict |

## Completion Result

Pending owner verdict.

## Remaining Limitations Or Follow-Up Specs

- Exploration aggro/damage policy, duration/decay, costs, ranges, and authored
  per-friend kits remain product decisions for later specs.

## Supersession

- Supersedes: none
- Superseded by: none
