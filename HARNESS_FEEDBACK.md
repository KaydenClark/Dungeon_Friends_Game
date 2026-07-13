# Dungeon Friends - Harness Feedback

> Generated from LLM Workbench v2.3. See `RUNBOOK.md` -> Upgrading The
> Harness.

This is the return channel from this project back to the LLM Workbench
harness. When the control docs themselves (`AGENTS.md`, `BLUEPRINT.md`,
`TASKBOARD.md`, `RUNBOOK.md`, `GENESIS.md`, `ADOPTION.md`) are unclear, wrong,
missing guidance, or actively slow the work down, record it here instead of
silently working around it. The owner carries these lessons back to LLM
Workbench, where a change is validated against `evals/` before it ships as
"better".

This log is append-only. Do not edit or delete prior rows; add a new one.

## How To Log

Add a row whenever the harness (not this project's own code or docs) caused
friction or could be improved. Keep it concrete: name the doc and section, say
what happened, and propose a change if you have one.

| Date | Doc / section | What happened | Impact | Proposed change | Status |
|---|---|---|---|---|---|
| 2026-07-05 | `ADOPTION.md` -> Phase 0 | Adoption assumes an existing runnable baseline to confirm green before migrating docs; this project had real planning docs but zero code, so there was nothing to baseline. Worked around by borrowing Genesis's "Phase 3: Scaffold" step inside the Adoption run instead of treating it as out of scope. | low | Note explicitly in `ADOPTION.md` that a docs-only target with no code yet should produce its "smallest thing that runs" using Genesis's scaffold step as part of Phase 0/1, rather than leaving that case unaddressed | new |

## What Belongs Here vs. Project Specs

- This project's own work, bugs, and tasks -> the owning stable spec; hot state
  projects into `TASKBOARD.md`.
- Problems with the *harness rules themselves* -> here.

If a harness problem is also blocking this project right now, log it here
**and** add a linked ticket or blocker to the owning spec.
