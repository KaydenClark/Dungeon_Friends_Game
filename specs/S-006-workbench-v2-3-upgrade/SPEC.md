# S-006 - Workbench v2.3 Upgrade

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-006
**Status:** complete
**Priority:** 0
**Owner:** Codex
**Updated:** 2026-07-13
**Catalog description:** Migrate Dungeon Friends from the v2.1 proof-heavy board to the v2.3 stable-spec lifecycle without losing project truth or verification.
**Blockers:** none
**Latest event:** Spec completed and removed from the hot board.
**Next gate:** none

## Outcome

Dungeon Friends uses the v2.3 progressive-disclosure lifecycle: a small
always-loaded control plane, stable capability packets, a generated hot board,
and deterministic local tooling.

## Why It Matters

The 571-line Taskboard mixed queue, proof, decisions, bugs, backlog, and history.
It made cold-start selection expensive and encouraged the board to become a
second product document.

## Current Verified State

The migration branch was created in a separate worktree from current
`origin/integration`, preserving Kayden's dirty dev-scene override in the main
checkout. The pre-change baseline passed import, production boot, 38 suites / 280
tests / 1781 checks, and the 134/134 slice smoke test.

## Desired Behavior

- Root controls carry v2.3 stamps and no template placeholders.
- `AGENTS.md` selects one eligible spec through doctor/next/show.
- Blueprint catalogs stable specs; Taskboard projects only hot state.
- Legacy board history remains available but cannot select work.
- The local spec tool matches the canonical Workbench copy.
- Project behavior verification matches the pre-migration baseline.

## Decisions And Contracts

- Canonical source: `/Users/kayden/GPT_OS/workbench templates`.
- Migration base: current `origin/integration`, isolated from the dirty main
  checkout.
- Inventory map:
  - Port: `AGENTS.md`, `BLUEPRINT.md`, `README.md`, `RUNBOOK.md`,
    `HARNESS_FEEDBACK.md`.
  - Fold: `CLAUDE.md` becomes the thin `@AGENTS.md` bridge.
  - Keep: product research, world lore, asset docs, `.claude/` enforcement, and
    `docs/LEGACY_HARNESS.md` as evidence.
  - Retire: v2.1 `TASKBOARD.md` becomes a dated cold archive; its live pivot
    sequence becomes `S-001` through `S-005`.
- Completed proof is summarized in stable specs and preserved verbatim in the
  archived board.

## Non-Goals

- Gameplay changes, broad Blueprint redesign, rewriting historical evidence, or
  promoting any dev spike into production architecture.

## Dependencies And Blockers

- none

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Reconcile controls, archive the old board, seed stable specs, install the canonical tool, and verify the migration. | done | none | pre/post Godot import and main boot clean; 38 suites / 280 tests / 1781 checks; slice smoke 134/134; spec doctor passed; canonical tool exact-match; branch 06a9d45 pushed |

## Acceptance Criteria

- [x] Six root controls use the v2.3 ownership model and Claude remains a thin bridge.
- [x] Every old steering doc is classified and live content is preserved.
- [x] Stable specs represent the accepted foundation and actual next dependency chain.
- [x] Render, doctor, next, and placeholder/stale-routing checks pass.
- [x] Godot import, production boot, unit suite, and slice smoke match baseline.
- [x] The migration branch is committed and pushed for review into `integration`.

## Testing Seams

- `spec-workbench.mjs doctor`, deterministic render, and `next --json`.
- Exact comparison with the canonical Workbench tool.
- Placeholder, stale-stamp, legacy-routing, and control-file size checks.
- Existing Godot import, boot, unit, and slice smoke commands.

## Verification Procedure

```bash
node tools/spec-workbench.mjs render
node tools/spec-workbench.mjs doctor
node tools/spec-workbench.mjs next --json
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/main.tscn --quit-after 1
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

## Documentation Impact

- All root control files, `.claude/` scope enforcement, the archived v2.1
  board, and the new stable specs are part of this migration.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-13 | TK-001 | Baseline and migration started | baseline import and production boot passed; 38 suites / 280 tests / 1781 checks; slice smoke 134/134 | migration map recorded above | final verification, lifecycle close, commit, and push |
| 2026-07-13 | TK-001 | Ticket closed | pre/post Godot import and main boot clean; 38 suites / 280 tests / 1781 checks; slice smoke 134/134; spec doctor passed; canonical tool exact-match; branch 06a9d45 pushed | v2.3 controls, six stable specs, archived v2.1 board, and Claude scope updated | none |
| 2026-07-13 | spec | Spec completed | Acceptance gates satisfied | Documentation impact recorded above | none |

## Completion Result

Dungeon Friends now uses the Workbench v2.3 stable-spec lifecycle. The previous
board is cold history, the current dependency chain is represented without
invented readiness, project verification matches baseline, and commit `06a9d45`
is available on `origin/codex/workbench-v2-3` for review into `integration`.

## Remaining Limitations Or Follow-Up Specs

- Existing Blueprint depth remains intentional product reference; later
  pruning should be its own benchmarked harness change.

## Supersession

- Supersedes: Dungeon Friends Workbench v2.1 execution layout
- Superseded by: none
