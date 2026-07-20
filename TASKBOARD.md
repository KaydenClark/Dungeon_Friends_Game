# Dungeon Friends - Taskboard

> Generated from LLM Workbench v2.3.

This is a hot projection of active stable specs, not a hand-maintained queue or
proof ledger. Run `node tools/spec-workbench.mjs next --json` to select work and
`node tools/spec-workbench.mjs render` after spec metadata changes.

## Hot Execution Projection

<!-- hot-specs:start -->
| Spec | Current slice | Owner | Blocker | Latest meaningful event | Next gate |
|---|---|---|---|---|---|
| [S-003](specs/S-003-persistent-world-resolution/SPEC.md) | TK-002: Persist stable encounter IDs and neutral environmental state with fail-closed loading. (ready) | claude-engineer | TK-001 | TK-001 closed with proof. | Complete TK-002. |
| [S-010](specs/S-010-production-party-formations/SPEC.md) | Acceptance / owner gate | claude-engineer | none | TK-004 closed with proof. | Complete TK-005. |
| [S-011](specs/S-011-production-reaction-vocabulary/SPEC.md) | Acceptance / owner gate | claude-engineer | none | TK-004 closed with proof. | Complete TK-005. |
| [S-012](specs/S-012-production-deterministic-combat/SPEC.md) | Acceptance / owner gate | claude-engineer | none | TK-005 closed with proof. | Complete TK-006. |
<!-- hot-specs:end -->

## Collision And Owner Gates

- `S-002` requires Kayden's played fun/not-fun verdict before the pivot scales.
- `S-003` remains dependency-blocked on production state from `S-009`, `S-011`,
  and `S-012`.
- The complete human-gate ledger lives in
  `docs/planning/CANON_TO_SPEC_COVERAGE_2026-07-17.md`; agent evidence cannot
  close those gates.
- A future agent must verify branch activity before reclaiming a claim older
  than one working day.

## Cold History

- The complete pre-v2.3 queue and proof ledger is preserved at
  [`docs/archive/TASKBOARD_V2_1_2026-07-13.md`](docs/archive/TASKBOARD_V2_1_2026-07-13.md).
- Completed capability evidence remains at its stable path under `specs/` and
  does not return to this projection.
