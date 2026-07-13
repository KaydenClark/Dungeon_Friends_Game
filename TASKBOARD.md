# Dungeon Friends - Taskboard

> Generated from LLM Workbench v2.3.

This is a hot projection of active stable specs, not a hand-maintained queue or
proof ledger. Run `node tools/spec-workbench.mjs next --json` to select work and
`node tools/spec-workbench.mjs render` after spec metadata changes.

## Hot Execution Projection

<!-- hot-specs:start -->
| Spec | Current slice | Owner | Blocker | Latest meaningful event | Next gate |
|---|---|---|---|---|---|
| [S-002](specs/S-002-shared-material-reaction-vocabulary/SPEC.md) | TK-003: Record the owner fun, revise, or stop verdict. (blocked) | Kayden | Kayden played fun/not-fun verdict | The shared core and gray-box room are merged, automated green, and visually checked at two resolutions. | Kayden plays the reaction room and records fun, revise, or stop. |
| [S-003](specs/S-003-persistent-world-resolution/SPEC.md) | TK-001: Add a failing two-process battery for resolved encounter, environment, and movable reset. (ready) | unassigned | S-002 | Capability migrated from legacy T-091; implementation waits on the reaction-vocabulary owner gate. | Complete S-002, then claim TK-001 and prove the two-process persistence battery red. |
<!-- hot-specs:end -->

## Collision And Owner Gates

- `S-002` requires Kayden's played fun/not-fun verdict before the pivot scales.
- `S-003` remains dependency-blocked until that owner gate is accepted.
- A future agent must verify branch activity before reclaiming a claim older
  than one working day.

## Cold History

- The complete pre-v2.3 queue and proof ledger is preserved at
  [`docs/archive/TASKBOARD_V2_1_2026-07-13.md`](docs/archive/TASKBOARD_V2_1_2026-07-13.md).
- Completed capability evidence remains at its stable path under `specs/` and
  does not return to this projection.
