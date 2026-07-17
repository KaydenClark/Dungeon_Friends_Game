# Dungeon Friends Canon-To-Spec Coverage

**Date:** 2026-07-17
**Planning base:** `origin/claude/t-093-reaction-room` at
`feab45398b55e162b73503b02a2c860d862c5c5c`
**Purpose:** adoption evidence and coverage audit, not a second work queue

The canonical work remains in stable specs. This matrix proves where current
canon, live-source gaps, legacy open work, owner gates, and release evidence
landed during the authorized conversion.

## Coverage Summary

- Inspected current state: 6 stable specs with 16 tickets.
- Inspected legacy archive: 99 unique `T-###`/`T-093A`/`T-093B` task tokens
  and 23 `B-##` bug tokens, plus the surviving stretch rows.
- Added: 9 stable specs with 35 dependency-aware tickets.
- Result: 15 stable specs with 51 tickets.
- Required canon domains: 10 of 10 covered.
- Non-closed legacy task/bug records: 34 of 34 mapped.
- Surviving legacy stretch records: 7 of 7 mapped or explicitly kept cold.
- Uncovered items: 0.
- Unjustified uncovered items: 0.

Closed and superseded implementation proof remains verbatim in
`docs/archive/TASKBOARD_V2_1_2026-07-13.md`; it is not copied back into hot
execution state.

## Required Domain Matrix

| Domain | Verified source/canon | Stable owner | Agent-safe next work | Kayden-only or human gate |
|---|---|---|---|---|
| Unified-world direction | D-024..D-037; production still uses `SceneManager` plus separate `CombatScene` while dev spikes prove continuity | `S-009` | Neutral production world-state seam, then production party/encounter lifecycle | Final production continuity replay |
| Formations | `PartyFormationLayout` and `VisiblePartyExplorationModel` are green but dev-only | `S-010` | Promote the pure planner unchanged, then integrate selection and legal deployment | Formation/choke/deployment feel replay |
| Reactions | `ReactionCore.calculate` and the same-path room are green; Kayden verdict missing | `S-002`, gate preparation in `S-008`, production in `S-011` | Readability recut, then production promotion and LDtk/material integration | Fun/revise/stop verdict and production replay |
| Persistence | v1 JSON save battery is green; schema 1 explicitly omits resolved encounters/material state | `S-003` | Two-process red battery after production reaction/combat seams exist | Persistent-world demo acceptance |
| Readability | Height/intent/reaction captures exist; fire/smoke, focus, formation cohesion, and production UI remain weak | `S-008` for the blocking prototype gate; `S-014` for production experience | Exact reaction-gate visual recut; later resolution/input/accessibility matrix | Owner visual and first-session verdicts |
| Combat | Production is still d10, separate arena, per-unit initiative; dev intent core proves v2 contract | `S-012` | Promote deterministic intent domain after world/formations/reactions | Played combat-feel acceptance |
| Progression | v1 XP/defeat/items exist; finite-XP, revive, equipment, currency, and real recruit growth are unresolved | `S-013` | Implementation follows the owner progression fork | Defeat/revive/economy decisions and balance verdict |
| Player experience | v1 tutorial/save UX is playable; unified-world onboarding, recovery, move undo, and full controller journey are incomplete | `S-014` | Production onboarding and UX tickets after system dependencies | Full opening-route replay |
| Playtesting | Agent and owner prototype evidence exists; no external v2 thesis sessions exist | `S-005` | Prepare repeatable build, neutral script, consent boundary, and notes | Two or more external first sessions and Kayden synthesis |
| Release proof | No export presets or release candidate; Steam-first is canon, mobile postponed | `S-015` | Export/repro/license/performance/recovery proof after thesis playtest | Release-candidate approval; publishing remains separately authorized |

## Current Stable Spec Disposition

| Current spec | Disposition |
|---|---|
| `S-001` | Preserve complete prototype foundation and evidence; production graduation is split into `S-009` through `S-012`. |
| `S-002` | Preserve as the reaction fun gate; `S-008` supplies the missing readability preparation and `S-011` owns later production integration. |
| `S-003` | Preserve as persistence owner; dependency corrected from prototype-only `S-002` to production reaction/combat seams. |
| `S-004` | Preserve as thesis integrator; dependency expanded to the production capability chain. |
| `S-005` | Preserve as external-playtest owner. |
| `S-006` | Preserve completed v2.3 migration evidence; current Factory/tool drift is recorded in `S-007` rather than rewriting completed proof. |

## Legacy Non-Closed Work Disposition

| Legacy records | Count | Canonical destination |
|---|---:|---|
| `T-084` | 1 | Prototype/visual verdict in `S-008`; production cohesion in `S-014`. |
| `T-096` | 1 | `S-010` formations; prior automated proof stays in `S-001`. |
| `T-097` | 1 | `S-012` combat; cue/readability edges also feed `S-014`. |
| `T-093` | 1 | `S-002` owner gate, `S-008` recut, `S-011` production reactions. |
| `T-091` | 1 | `S-003` persistence. |
| `T-094` | 1 | `S-004` thesis integration, with recruit progression supplied by `S-013`. |
| `T-095` | 1 | `S-005` external playtest. |
| `T-002`, `B-21` | 2 | Explicitly cold in `S-015`: Steam-first desktop proof; mobile/touch postponed by D-032. |
| `T-028`, `T-059` | 2 | Aggro and movement feedback in `S-014`. |
| `T-051`..`T-055`, `T-057`, `T-058` | 7 | Production readability/audio/polish in `S-014`; shipping/provenance gates in `S-015`. |
| `T-056` | 1 | Recruit/progression art in `S-013`, used by `S-004`; source references remain non-shipping until provenance passes `S-015`. |
| `T-070`, `T-071`, `T-076` | 3 | Finite loot, currency/equipment, and character menu in `S-013`; the old respawn/RNG drop model is not revived. |
| `B-03`, `B-09`, `B-13`, `B-17` | 4 | Deterministic combat flow and move-undo in `S-012`, player-facing copy/feedback in `S-014`. |
| `B-08`, `B-11`, `B-16`, `B-19` | 4 | Facing, viewport layout, party status, and dialogue affordances in `S-014`. |
| `B-10` | 1 | Revive/downed-member product decision and behavior in `S-013`. |
| `B-12` | 1 | Production encounter/room-transition race proof in `S-009`, with UX replay in `S-014`. |
| `B-14`, `B-18` | 2 | Save failure and player-facing recovery language in `S-014`. |

The 34 mapped records above are the full set of legacy rows whose archive
status was not closed, done, accepted, or explicitly superseded.
`T-069` is intentionally not revived: D-024/D-025 superseded its separate-arena
acceptance target. Its surviving readability and tutorial concerns are covered
by `S-008` and `S-014`.

## Surviving Stretch Disposition

| Legacy stretch | Disposition |
|---|---|
| `S-001` equipment | Owned by `S-013`; activates only after the finite progression fork is settled. |
| `S-005` resource-gauge mechanics | Remains cold; requires a future linked spec after thesis/playtest evidence. |
| `S-006` world expansion | Remains cold until `S-004` and `S-005` prove the opening thesis. |
| `S-007` CRT/color grading | Remains optional cold polish under the release non-goals in `S-015`. |
| `S-008` roguelike postgame | Remains cold until the core game is feature-complete. |
| `S-009` dash/roll | Remains cold player-experience evidence; may become a linked successor to `S-014` after the opening route is accepted. |
| `S-010` swim/traversal | Remains cold until an authored water-region spec exists. |

## Owner And Human Gates

1. Kayden plays the recut reaction room and records fun, revise, or stop
   (`S-008` -> `S-002`).
2. Kayden accepts production formation/choke/deployment feel (`S-010`).
3. Kayden accepts the production shared-vocabulary replay (`S-011`).
4. Kayden accepts deterministic same-room combat feel (`S-012`).
5. Kayden resolves defeat penalty, revive, currency, and equipment scope
   (`S-013`).
6. Kayden accepts progression balance and the real-recruit loop (`S-013`).
7. Kayden accepts the complete opening player journey (`S-014`).
8. Kayden accepts the integrated thesis slice (`S-004`).
9. At least two external players run first sessions; Kayden accepts the
   synthesis (`S-005`).
10. Kayden approves the release candidate (`S-015`); publication remains a
    separate explicit action.

Agent or automated playthroughs can prepare evidence for these gates but cannot
close them.

## Smallest Engineer Handoff

`S-008/TK-001` is the smallest eligible implementation slice. It starts with
failing readability and cue assertions, then makes the bounded fire/smoke,
hint-visibility, and blocked/focus-feedback recut without changing reaction
results or graduating the dev room into production architecture.
