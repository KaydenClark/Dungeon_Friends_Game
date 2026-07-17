# Dungeon Friends - Lexicon

> Generated from LLM Workbench v2.3.

**Last reviewed:** 2026-07-17
**Status:** active

This is the canonical lookup table for terms whose meaning is shared across
Dungeon Friends. Requirements and decisions remain in `BLUEPRINT.md` or the
owning stable spec.

## Ownership Rules

- Add a term only after its meaning is settled.
- Keep project-wide definitions here and capability-local schemas in their spec.
- Surface conflicts before changing an established meaning.
- Link to the owning decision or spec instead of copying its requirements.

## Workbench Terms

| Term | Definition | Distinction |
|---|---|---|
| **Blueprint** | The stable owner of product direction, cross-cutting architecture, invariants, and non-goals. | It is not a work queue or proof archive. |
| **Spec** | A stable capability record containing intent, requirements, decisions, slices, acceptance, verification, evidence, and completion. | It is not moved or replaced by its temporary tickets. |
| **Ticket** | A one-context tracer-bullet slice inside a spec. | It is execution structure, not durable capability history. |
| **Taskboard** | The generated hot projection of active specs and current gates. | It is not edited as a second tracker or proof ledger. |
| **Owner gate** | A decision or played verdict only Kayden can supply. | Automated checks and agent playthroughs may prepare evidence but cannot satisfy it. |

## Project Terms

| Term | Definition | Distinction / aliases to avoid |
|---|---|---|
| **Unified world** | One persistent room/world model used by exploration, puzzles, reactions, and encounters. | Not a separate overworld plus battle arena. |
| **One grid, one vocabulary** | The orthogonal grid and shared material/effect rules operate in every gameplay context. | Not duplicated exploration and combat rules. |
| **Dungeon Friend** | An authored recruit with one primary world verb, a small deterministic combat kit, one passive or reaction, and a story hook. | Not a disposable generic unit or the temporary Buddy test contract. |
| **Active party** | The selected leader plus up to three visible friends who explore together and become occupying tactical units in encounters. | Followers are pass-through outside encounters, not four independently marched avatars. |
| **Formation** | A player-selected line, square, or spaced grouping that guides exploration recovery and preferred encounter deployment. | Not the transient `spread`, `single_file`, or `recovered` movement state. |
| **Encounter** | A finite authored problem resolved by combat, delivery, escort, persuasion, assistance, environmental manipulation, or an alternate route. | Not synonymous with combat and not a repeatable XP dispenser. |
| **Intent round** | Enemies move or declare, exact current effects are shown, the party acts in any order, enemy actions resolve, then environmental reactions resolve. | Not v1 per-unit initiative or a whole-team phase system. |
| **Forecast** | The stable future sequence of enemy verbs. | Future entries expose verbs only; the current intent owns exact cells, damage, and status. |
| **Preview equals result** | A committed deterministic action produces exactly the cells, damage, statuses, movement, and cancellations shown before commit. | No random hit, crit, or hidden outcome roll. |
| **Reaction vocabulary** | The character-neutral tag/effect rules for grow, fire, water, cold, spark, air, materials, hazards, and bounded propagation. | Not bespoke pairwise friend code. |
| **Resolved world state** | Stable encounter and intentional environment changes that survive leave, save, quit, relaunch, and load. | Wedged movable puzzle state may still reset as a soft-lock escape valve. |
| **Three-quarter presentation** | Orthogonal square-grid logic rendered with vertical faces, overlap, and integer elevation. | Not true diamond-isometric logic or 3D navigation. |
| **Thesis slice** | The smallest authored route proving adventure, recruitment, non-combat resolution, shared-vocabulary puzzle, deterministic encounter, progression, and persistent world change. | Not a content-complete region or public release. |
| **Release proof** | A reproducible, license-safe, controller-checked Steam-first release candidate with recovery and owner approval. | Not authorization to publish, buy signing services, or ship mobile. |
