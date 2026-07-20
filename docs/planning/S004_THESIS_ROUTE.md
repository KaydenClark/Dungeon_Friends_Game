# S-004 Thesis Route - The Withered Grove (TK-001 specification)

> Product call flagged per D-038 and recorded as Blueprint D-044; Kayden's
> batch verdict lands at S-004/TK-004. This document is the implementation
> contract for S-004/TK-002 (tracer bullet) and TK-003 (authored loop + demo).

## Purpose

One short authored route that joins the already-proven production contracts -
unified world (S-009), visible party/formations (S-010), reaction vocabulary
(S-011), deterministic in-room combat (S-012), finite progression and the real
recruit (S-013), readable opening experience (S-014), persistent world
resolution (S-003) - into the playable v2 thesis loop:

adventure -> recruit -> non-combat resolution -> shared-vocabulary puzzle ->
tactical fight -> permanent world change.

## The Authored Recruit: Wren

Wren's data contract shipped in S-013/TK-003 (`game/data/characters/wren.tres`:
grow world verb through the shared seam, Strike + Verdant Growth kit,
`verdant_mender` passive, stable save identity, fail-closed finite
`recruit_member`). This route places her in the world and gives her the D-033
role and personality hook:

- **Role:** the Growth friend of the Foothills/Forest (WORLD_LORE anchor).
- **Hook:** a quiet forager-botanist who stayed behind when the forest started
  withering under the dragon's shadow. She will not bonk slimes for sport -
  "things want to live, mostly" - but she joins an expedition that regrows
  what the dragon's presence ruins.
- **The temporary Buddy contract does not graduate:** Buddy remains the D-013
  production pair member; Wren joins as the third, roster-driven member
  (D-040). `companion_test` stays a test double only.

## The Route

New room: **The Withered Grove** (`grove.ldtk`, map id `withered_grove`,
~17x10), reached by a new `Doorway` on the forest's south edge. A new room
keeps the v1 tutorial slice (pinned by the 134-check smoke) untouched; the
forest delta is exactly one Doorway entity.

Steps, in player order (each independently demonstrable in under one minute):

| # | Loop beat | What happens | Contract exercised |
|---|---|---|---|
| 1 | Adventure | Walk the forest south doorway into the grove: withered cells, visible party trail follows | S-009 unified world, S-010 party, S-014 readability |
| 2 | Recruit | Wren kneels at a withered seedbed by the entrance. Dialogue (3-5 lines, her hook) ends with her joining: `recruit_member("wren")`, toast, party of three, her NPC actor leaves the board; a persisted flag keeps her recruited across saves | S-013 finite recruit, D-040 roster growth |
| 3 | Non-combat NPC resolution | Moss the forager stands by his dead herb bed and asks for help no sword answers. Casting grow (5/R1) on the marked bed cell regrows it: his dialogue flips to gratitude, `grove_herbs_grown` flag set, no combat involved | S-013 field cast, S-011 vocabulary, D-035 local-consequence problem |
| 4 | Shared-vocabulary puzzle | A **vine gate** bars the inner grove: a trellis cell beside it must carry a grown vine. Cast grow at the trellis -> the gate opens and stays open (persisted). Wrong-target casts give the existing named refusals | S-011 reaction seam, D-039 authored materials, S-014 no-coaching readability |
| 5 | Tactical fight | The grove heart is squatted by one authored slime (`UniqueId: grove_guardian`). Bumping it enters the D-036 in-room encounter; win with intents/preview-equals-result combat; victory pays its finite XP source exactly once | S-012 combat, D-036 cue, S-013 ledger |
| 6 | Permanent world change | Victory regrows the grove heart (authored vine cells commit around it) and sets `grove_restored`; the resolved encounter never respawns; save/quit/relaunch/load keeps the recruit, flags, gate, herb bed, grove heart, and resolved fight | S-003 persistence, D-028 resolved-stays-resolved |

## New Mechanics TK-002 Must Build (smallest set)

1. **GroveRoom** - `grove.ldtk` with D-039 `Material` layer authoring the
   trellis/bed/heart cells' *initial* state, plus a `LdtkRoom` subclass and one
   `MapRegistry` row (`withered_grove`). Invalid authoring fails closed per
   D-039.
2. **Recruit-on-dialogue** - extend the `Npc` entity with an optional
   `RecruitId` field: when dialogue ends, `recruit_member(RecruitId)`; on
   success the NPC despawns and a flag suppresses respawn. Fail-closed: an
   unknown id records an authoring error and the NPC stays a plain talker.
3. **Watched-cell NPC resolution** - extend `Npc` with optional `WatchCell` +
   `ResolvedLines`: when the watched cell gains the `vine` tag the NPC swaps
   lines and sets its flag. No new dialogue system.
4. **VineGate** - new LDtk entity blocking like a wall while closed; opens
   (and persists open via flag + world snapshot) when its trellis cell gains
   `vine`. Closed gates are visibly vine-lattice so the grow answer reads
   without coaching (S-014).
5. **Victory regrowth hook** - on the `grove_guardian` resolution, commit the
   authored heart cells' vine tags and set `grove_restored`.

Everything else on the route already exists and is only *placed* here.

## Determinism, Testing Seams, And Demo

- All casts route through the existing `ReactionCore`/`ReactionCaster` seam;
  no new reaction rules. The encounter uses the existing deterministic intent
  combat. No randomness is introduced anywhere on the route.
- Unit seams: recruit-on-dialogue (success/unknown-id/dup), watched-cell line
  swap, VineGate open/persist/fail-closed authoring, victory regrowth commit,
  save round-trip of every route flag.
- Slice seam: a scripted grove tracer (TK-002) drives doorway -> recruit ->
  grow bed -> open gate -> win fight -> save/load and asserts each beat;
  TK-003 adds the windowed under-one-minute captured demo artifact for the
  TK-004 batch review.

## Risks

- The v1 smoke pins the forest layout: keep the forest delta to one Doorway
  and rerun the full battery; if the smoke pins entity counts, update the
  smoke's expectation with the route evidence, never the other way.
- Room-transition persistence must ride the existing S-003 snapshot path; the
  tracer asserts leave/return before save/relaunch.

## Out Of Scope

Final art/audio for the grove (S-004 non-goal; placeholder Kenney set),
additional recruits, currency/shops (D-043), mobile (D-032), and any lore
answer to the dragon's open questions (WORLD_LORE: no incidental canon).
