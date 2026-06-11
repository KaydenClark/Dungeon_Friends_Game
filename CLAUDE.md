# Claude Instructions — Dungeon Friends

Read `AGENTS.md` first — it has the canonical project summary, repo layout, locked technical decisions, and conventions shared by all agents (Claude and Codex).

A few Claude-specific notes on top of that:

- For multi-step work (a milestone from `docs/planning/Gameplan.md` §15, or any task touching several files), use the task list (TaskCreate/TaskUpdate) to track progress.
- When a milestone involves new gameplay systems, sanity-check against `docs/planning/Gameplan.md` §16/§17 (MVP vs. Stretch) before building — see AGENTS.md "MVP vs. Stretch."
- If you're about to make an architectural change that contradicts a "locked technical decision" in AGENTS.md, stop and flag it to Kayden rather than proceeding — those decisions were made deliberately after an audit (`docs/research/audited_research.md`) and changing them has ripple effects across the data model, scene structure, and milestones.
- Source-of-truth order when in doubt: `AGENTS.md` (quick reference) → `docs/planning/Gameplan.md` (full rationale) → `docs/research/audited_research.md` (why the toolchain/architecture choices were made).
