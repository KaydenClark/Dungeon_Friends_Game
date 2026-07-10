# Dungeon Friends - World Lore

**Status:** living story spine
**Purpose:** track the regional story flow, villages, dungeons, legendary items,
and final dragon arc without overloading `BLUEPRINT.md`.

`BLUEPRINT.md` remains the canonical product and architecture reference. This
file expands the story/content layer. If a lore decision changes build order,
mechanics, data shape, or locked technical decisions, reconcile that change
back into `BLUEPRINT.md` and `TASKBOARD.md`.

## Story Spine

Dungeon Friends is a compact regional quest. The party starts in the Forest
Village, learns that a very large dragon is the final threat, and gathers four
legendary items before confronting it.

The repeated regional loop is:

> village hub -> local problem -> dungeon access -> legendary item -> clue or
> gate to the next region

The four-item rule is intentional for the current story shape: four heroes /
players, four legendary items. Keep that count unless Kayden explicitly expands
the quest.

## Region Progression

| Order | Region | Hub | Dungeon | Story function | Legendary item | Next gate |
|---:|---|---|---|---|---|---|
| 1 | Forest | Forest Village | Forest Dungeon | Starts the journey and teaches the village-to-dungeon loop. This is the first full dungeon arc after the current tutorial work. | Working assignment: Sword of Slaying or Shield of Protecting. Not locked yet because the current tutorial already uses a shield reward as a prototype/early item. | The forest resolution opens the route to the River Valley. |
| 2 | River Valley | River village | River dungeon | Establishes the second regional hub and a water/river problem that must be solved locally before the world opens further. | Working assignment: Ring of Magic. | The river dungeon reward or village aftermath points the party toward the mountain. |
| 3 | Mountain | Mountain village | Mountain dungeon | Raises the stakes with climb, stone, endurance, and dragon-foreshadowing themes. | Working assignment: Circlet of Strength. | The mountain resolution reveals the road or reason to go to the city. |
| 4 | City | Castle city or central city | City dungeon, fortress, or undercity | Pulls the wider world into the dragon threat and lets the party assemble the final piece before the finale. | Working assignment: whichever of Sword/Shield remains after Forest is locked. | The completed set opens the final dragon route. |
| 5 | Dragon Lair | Staging camp, ruined fortress, or no normal village | Final lair | Finale region. The four legendary items matter together here. | All four legendary items together. | Final boss: the dragon. |

## Legendary Items

Working names:

- **Sword of Slaying** - the offensive dragon-killing relic.
- **Shield of Protecting** - the defensive survival relic. Decide later whether
  this is the same shield as the tutorial reward, an upgraded version, or a
  separate legendary shield.
- **Ring of Magic** - the magic or spell-access relic.
- **Circlet of Strength** - the strength, resolve, or party-power relic.

These names are placeholders. Rename them once the regions and party roles have
clearer identities.

## Open Story Questions

- Which exact region awards each legendary item?
- Is the City the fourth item region, the final staging hub, or both?
- Is the current tutorial shield a lesser shield, the legendary Shield of
  Protecting, or just a prototype reward that later changes?
- What local problem does each village have before its dungeon opens?
- What clue, gate, or ability points from each completed dungeon to the next
  region?

## Implementation Guardrails

- This story outline does not change the current MVP build order. The Phase 6
  forest dungeon remains the first complete content target; River Valley,
  Mountain, City, and Dragon Lair are later content expansion.
- Keep every region dense and authored, not procedural.
- Keep enemies visible on the map and dungeons puzzle-driven.
- Use this file for ongoing story shaping. Use `TASKBOARD.md` only when a story
  decision becomes actionable implementation work.
