# Unified-World Branch Consolidation Review

**Date:** 2026-07-11
**Branch:** `codex/unified-world-consolidation`
**Sources:** `origin/codex/unified-world-pivot` (Sol) and
`origin/claude/unified-world-pivot` (Fable), based on the latest fetched
`origin/integration`.

## Consolidation decision

Fable's D-024..D-035 canon and T-088..T-095 sequence remain authoritative.
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

## Owner review gates

1. **Perspective:** does Fable's playable room make height and legal movement
   readable without Sol's explanatory callouts? If not, recut the visual
   language before production LDtk/elevation work.
2. **Party movement:** does a four-member breadcrumb party feel charming or
   noisy in motion, especially through doors and stairs? Confirm switching the
   leader is worth keeping.
3. **Encounter continuity:** does entering combat in place feel like the same
   adventure room becoming tactical, or merely like combat UI appearing on an
   overworld mockup?
4. **D-027 turn structure:** play the intent-round prototype and compare it
   with the retained v1 alternating initiative. Choose intent rounds or
   alternating initiative before production combat architecture begins.
5. **Scope and readability:** decide whether body-blocking by all four party
   members adds useful tactics or makes the narrow board visually and spatially
   congested.

## Recommended next step

Do not begin the thesis slice or production migration yet. After the five
owner verdicts, build T-093 as one gray-box reaction room using a single shared
effect entry point in exploration and encounter contexts. If that room is not
fun, revisit D-031 before adding persistence, roster content, or production art.
