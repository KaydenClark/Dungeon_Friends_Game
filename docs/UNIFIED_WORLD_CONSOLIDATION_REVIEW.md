# Unified-World Branch Consolidation Review

**Date:** 2026-07-11
**Branch:** `codex/unified-world-consolidation`
**Sources:** `origin/codex/unified-world-pivot` (Sol) and
`origin/claude/unified-world-pivot` (Fable), based on the latest fetched
`origin/integration`.

## Consolidation decision

Fable's D-024..D-035 canon remains authoritative, with Kayden's D-036/D-037
playtest refinements and T-096/T-097 revision gates now added.
They are the more complete expression of the approved reboot and match the
repository's current agent rules. Sol's competing task numbering is not
promoted into the active queue.

Both implementations are retained because they answer different questions:

- Sol's spikes are compact, annotated specification harnesses. Keep their pure
  elevation and follower models, tests, one-cell choke proof, follower
  non-occupancy proof, and leader-switch proof.
- Fable's spikes are the stronger playable thesis candidate. Keep the real
  `RoomGrid`/`GridActor` movement, same-room encounter continuity, exact intent
  previews, deterministic cancellation rules, and scripted screenshot tours.

## Do not promote yet

- Neither visual spike is production art or a production room layout. Sol's
  version reads like a diagnostic board; Fable's version exposes large black
  voids, overlapping actors/labels, and prototype-only staging.
- Fable's `three_quarter_spike.gd` -> `unified_encounter_spike.gd` ->
  `intent_prototype_spike.gd` inheritance chain is useful for fast experiments,
  but it is too scene-specific and too large to become the production combat
  architecture unchanged.
- The inherited v1 combat-readability and DungeonStoneHall work is preserved
  as a green fallback/reference only. It belongs to the retired separate-arena
  direction and should not consume more design time unless needed for A/B
  comparison.
- Do not combine Sol's render-only follower model and Fable's encounter model
  into a generalized party system before the owner verdicts below. That would
  turn two reversible spikes into premature infrastructure.

## Owner verdicts (2026-07-11)

1. **Perspective accepted:** Sol's elevation reads without explanatory labels.
   Preserve the logic and geometry; recut colors/palette only.
2. **Four visible followers accepted:** both demos felt good; Fable felt better
   because the controlled leader could move through follower positions.
   Exploration followers remain pass-through.
3. **Selectable formations required:** line, square, and spaced postures should
   let the player choose grouping and preferred encounter deployment. Chokes
   compress temporarily; combat occupancy/body-blocking then becomes tactical.
4. **Continuity clarified:** keep the room/camera/rules/world state, but add a
   strong BG3-like encounter-entry beat - brief input freeze, original stinger,
   and turn-based UI/menu reveal before player control.
5. **D-027 resolved:** intent rounds are the production direction. Enemy plans
   keep a rolling future-verb forecast (prototype horizon 3), hide future
   target/location details, expose exact current intent, and rebuild when the
   current state invalidates the plan.
6. **Body protection is a real tactic:** spacing must support abilities such as
   a directional shield/guard field that protects the front and adjacent cells
   from a line-shaped breath. The prototype proves generic guarded cells; it
   does not lock a specific friend or dragon implementation.

## Recommended next step

T-096 and T-097 are merged on `codex/unified-world-consolidation`; Fable's
encounter now consumes Sol's real four-member formation snapshot, and the
combined automated battery is green. Kayden should replay the five owner gates
in `docs/planning/SOL_FABLE_PIVOT_FIX_HANDOFF.md`. If accepted, split T-093 by
dependency: first build the pure shared reaction entry point and matrix, then
build one gray-box room that consumes that exact code path in exploration and
encounter contexts. If that room is not fun, revisit D-031 before adding
persistence, roster content, or production art.
