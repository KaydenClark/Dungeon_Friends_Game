# S-007 - Canon-To-Spec Conversion

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-007
**Status:** complete
**Priority:** 0
**Owner:** Codex Planner
**Updated:** 2026-07-17
**Catalog description:** Reconcile the settled unified-world canon, live source, legacy queue, owner gates, and release proof into complete stable capability specs.
**Blockers:** none
**Latest event:** Auditor remediation normalized every blocker field and split agent-produced proof from owner-only verdict tickets without changing coverage.
**Next gate:** none

## Outcome

Dungeon Friends has one dependency-aware stable-spec portfolio covering the
settled v2 direction and every non-closed legacy work record without reviving
the archived Taskboard as a live queue.

## Why It Matters

The first v2.3 migration captured only the immediate pivot chain. Formation
graduation, production reactions/combat, readability, progression, player
experience, and release proof still lived across legacy rows and source
comments, so future agents could select incomplete or superseded work.

## Current Verified State

- Canonical source repo: `https://github.com/KaydenClark/Dungeon_Friends_Game.git`.
- Planning base: `origin/claude/t-093-reaction-room` at
  `feab45398b55e162b73503b02a2c860d862c5c5c`, one descendant commit beyond
  `origin/integration`.
- The production boot path is v1; accepted v2 formation, intent, and reaction
  contracts remain under `game/scripts/dev/`.
- Baseline: Godot 4.7 import and main boot passed; 38 suites / 280 tests /
  1781 checks passed; slice smoke passed 134/134; save/load battery passed
  10/10 save and 11/11 load.
- Project helper checksum:
  `c601eef543e28d5bc0a4050f5f96be5f38b2b64aa5f4eb95e05d414032acf114`.
- Current Workbench Factory helper checksum:
  `ef31d219c092d8c9b1c595734d933de9560c1d099967daf212b7481040acd672`.
  Both doctors pass; helper upgrade is intentionally outside this planning
  checkpoint.

## Desired Behavior

- Every required domain has one explicit stable owner and schedulable slices.
- Completed proof stays immutable and cold history stays cold.
- Agent-safe work and Kayden-only gates are unmistakable.
- Every blocker field uses only comma-separated exact spec IDs or same-spec
  ticket IDs; human conditions live in blocked status, ownership, and next-gate
  language.
- Live source contradictions are recorded rather than hidden by aspirational
  canon.
- Render and doctor deterministically project the correct hot state.

## Decisions And Contracts

- Coverage evidence lives at
  `docs/planning/CANON_TO_SPEC_COVERAGE_2026-07-17.md`; it is not a queue.
- `S-001` and `S-006` remain completed history.
- Existing `S-002` through `S-005` retain their capability ownership.
- `S-008` through `S-015` own the missing gate, production, experience, and
  release capabilities.
- The latest descendant of `origin/integration` is the source snapshot because
  it contains the current character-kit pipeline and all earlier pivot work.

## Non-Goals

- Gameplay implementation, owner verdicts, public release, helper upgrade,
  branch merging, or deletion of v1 fallback code.

## Dependencies And Blockers

- none

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Inventory canon/source/history, persist the coverage matrix and cohesive specs, render, doctor, and publish the planning checkpoint. | done | none | baseline and lifecycle verification recorded; docs/spec-only branch pushed |

## Acceptance Criteria

- [x] All 10 required canon domains have stable owners.
- [x] All 34 non-closed legacy task/bug rows are mapped.
- [x] All 7 surviving stretch rows are mapped or explicitly cold.
- [x] Agent-safe tickets and 10 owner/human gates are distinguished.
- [x] All 72 blocker fields pass exact syntax and reference checks with zero
  unsupported values.
- [x] Agent-produced demos and owner verdicts are separate tickets.
- [x] The smallest eligible Engineer ticket is explicit.
- [x] Render, both project/current-Factory doctors, and static doc checks pass.
- [x] The canonical dirty `game/project.godot` override remains byte-identical.

## Testing Seams

- Coverage counts and ID scans against the archived board.
- `spec-workbench` render/doctor/next using both helper versions.
- Placeholder, legacy-route, dependency, generated-region, and diff checks.
- Git status, worktree, remote-ref, and canonical override SHA-256 checks.

## Verification Procedure

```bash
node tools/spec-workbench.mjs render
node tools/spec-workbench.mjs doctor
node "/Users/kayden/GPT_OS/Workbench Factory/tools/spec-workbench.mjs" doctor
node tools/spec-workbench.mjs next --json
git diff --check
```

## Documentation Impact

- Added `LEXICON.md`, the coverage evidence, and `S-007` through `S-015`.
- Updated the incomplete specs and root controls that owned stale routing,
  provenance, vocabulary, or build-order claims.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | TK-001 | Canon-to-spec inventory and planning conversion completed | 10/10 domains; 34/34 non-closed rows; 7/7 stretch rows; baseline 38/280/1781, smoke 134/134, save/load 10/10 + 11/11 | coverage, lexicon, specs, controls, render | none |
| 2026-07-17 | audit | Auditor blocker and owner-gate remediation completed | 15 specs; 57 tickets; 72/72 blocker fields valid; 0 unsupported; both doctors and next passed; protected `project.godot` SHA-256 before/after `a7e45ecc35bee1768705d18343735a96708b86ed3283c5b90cb532a70508579f` | specs, coverage, and generated projections updated | none |

## Completion Result

The project now has complete stable ownership, machine-resolvable blockers, and
separate agent-proof and owner-verdict handoffs without implementing gameplay.

## Remaining Limitations Or Follow-Up Specs

- Product work begins with `S-008 / TK-001`.
- Workbench helper drift may be handled by a later explicit harness update.

## Supersession

- Supersedes: incomplete live-work extraction from the archived v2.1 board
- Superseded by: none
