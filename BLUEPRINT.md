# Dungeon Friends - Blueprint

> Generated from LLM Workbench v2.1. See `RUNBOOK.md` -> Upgrading The
> Harness.

**Last reviewed:** 2026-07-11
**Status:** unified-world pivot approved; migration prototype is next
**Source root:** `/Users/kayden/GPT_OS/Projects/Dungeon_Friends_Game`

This file is the canonical product and architecture reference for Dungeon
Friends. Kayden's 2026-07-11 unified-world direction supersedes the former
single-overworld-avatar, separate battle-arena, d10 combat, automatic enemy
respawn, private-audience, and strictly top-down design. Git history and the
append-only `TASKBOARD.md` proof log preserve the old design as evidence; it
is not active product authority.

The current executable remains a healthy migration baseline. Do not confuse
"the old build still runs" with "the old design is still the target."

## Product Vision

Dungeon Friends is a party-based 2D adventure RPG where the goddess Selena
asks the player to assemble an expedition capable of removing the dragon that
has landed atop the mountain overlooking the city. The player explores a
hand-authored three-quarter-view world, recruits a roster of distinctive
Dungeon Friends, chooses an active party of four, and combines their abilities
to solve environmental problems and deterministic tactical encounters.

The game has one world and one rules vocabulary. Combat does not load a new
arena. It begins directly in the room where the threat was encountered, using
the same characters, terrain, height, surfaces, hazards, objects, and abilities
that exploration uses. Enemies and other problems are visible, avoidable when
appropriate, and permanently resolved when completed.

Working pitch:

> Recruit a team of Dungeon Friends, combine their powers to reshape the
> world, and prepare an expedition against the dragon looming above the city.

## Audience And Release Goal

Dungeon Friends is intended for a public commercial release, with Steam as the
first target. The primary audience is players who enjoy party building,
exploration, environmental puzzles, readable tactical combat, and compact
retro-inspired RPGs.

The PC version targets keyboard and controller first. Google Play or another
mobile release may follow only after the PC interface, performance, market fit,
and production scope are proven. Do not make early gameplay or UI decisions
carry mobile-specific costs.

## Design Pillars

1. **Adventure First.** Exploration, discovery, people, problems, shortcuts,
   and a visible destination give every session forward momentum.
2. **Friends Are The Progression.** Recruiting a friend adds a personality, a
   field verb, a tactical role, and new combinations with the existing roster.
3. **One World, One Vocabulary.** Abilities and environmental reactions work
   the same way during exploration, puzzles, dialogue encounters, and combat.
4. **Deterministic Tactical Encounters.** Outcomes are previewable; enemies
   telegraph intentions; positioning, combinations, and interruption matter
   more than random hit rolls.
5. **Problems Stay Solved.** A completed encounter changes the world. Routine
   enemies do not automatically return when a room rebuilds.
6. **Dense, Authored Scope.** A smaller world with memorable friends and
   reusable systemic interactions is better than a large shallow world or a
   huge roster of one-off mechanics.

## Core Loop

1. **Adventure:** explore, discover a route, meet someone, or identify a
   problem.
2. **Party progression:** recruit, swap, equip, or develop Dungeon Friends.
3. **Encounter:** resolve a threat through combat, environmental manipulation,
   delivery, escort, assistance, or dialogue.
4. **World consequence:** the threat remains defeated, the NPC is satisfied,
   the environment changes, or a route opens.
5. **Continue toward the mountain:** use the new relationship, tool, or ability
   to reach the next problem.

Combat is the most common encounter type, not the definition of every
encounter.

## Story Spine

A dragon has landed atop the mountain overlooking the city. The goddess Selena
selects the player to lead the mission to remove it. The player is not expected
to become a lone chosen-one superweapon; their gift is the ability to assemble
and coordinate people whose skills are stronger together.

Each major local problem should do at least two jobs:

- demonstrate a consequence of the dragon's arrival or the world's response;
- introduce, test, or deepen a Dungeon Friend relationship;
- teach a reusable world interaction;
- open a route or obtain a tool needed for the mountain expedition.

Detailed working lore lives in `docs/WORLD_LORE.md`. The former mandatory
four-legendary-item structure is superseded. Tools and legendary equipment may
exist, but the expedition and its people are the story's progression spine.

## World And Party Model

### Active party

- The active party contains up to four characters.
- All active characters are visible during exploration and encounters.
- The player directly controls a selected leader during exploration.
- Followers use a breadcrumb path or loose formation and do not block the
  leader, doors, narrow corridors, or puzzle objects while following.
- The player may switch the leader or choose a friend's field ability without
  individually marching every character through routine traversal.
- When an encounter begins, every participating unit snaps to a nearby valid
  cell and becomes a real occupying tactical unit. Normal collision and
  positioning rules then apply.

This preserves the party fantasy without turning exploration into four-unit
micromanagement or recreating follower softlocks.

### Roster scope

- Migration thesis slice: Hero plus two real Dungeon Friends.
- Steam demo target: five to six recruitable friends, active party of four.
- Full-game planning ceiling: approximately ten to twelve excellent friends
  before any roster expansion is considered.

Each friend needs:

- one primary field verb;
- a small deterministic combat kit;
- one passive or reaction;
- one personality and recruitment hook;
- at least one meaningful interaction with another friend's verb.

Friends may share world verbs with different tactical expression. Do not build
a bespoke subsystem for every character.

## Shared Environmental Vocabulary

World objects and cells expose material/state tags. Abilities apply effects.
Reactions belong to the material/effect system, not pairwise hard-coded friend
checks.

| State or material | Required baseline reactions |
|---|---|
| Flammable vegetation | ignite from fire; extinguish from water |
| Grown vine | create climb/bridge/restraint; burn from fire |
| Water | fill or douse; freeze; conduct electricity later if Spark is in scope |
| Ice | become walkable/cover; melt from fire; break from force |
| Fire | damage/ignite/melt; create smoke; extinguish from water |
| Smoke or gas | obscure vision; clear from air; ignition is optional until proven |
| Heavy object | move from strength; hold plates; break tagged weak surfaces |
| Plate or switch | activate from weight, an actor, an object, or an authored effect |
| Fragile/blocked route | solve through one or more authored effects, never an invisible guess |
| Delivery/escort target | resolve through inventory, presence, protection, or assistance |

Initial prototype vocabulary is deliberately narrow: **Force, Flame, Water,
Growth, and Air**. Frost or Spark may be expressed as friend-specific
transformations later, but they do not justify new global subsystems before
the first three reactions are fun.

## Unified Encounter Model

An encounter is a persistent world problem with authored participants,
objectives, available resolutions, rewards, and a stable ID.

Possible resolutions include:

- defeat a threat;
- reach or hold a location;
- protect or escort someone;
- break, move, activate, extinguish, grow, flood, or freeze something;
- deliver an item;
- satisfy an NPC through an authored condition;
- discover or open an alternate route.

Encounter rules:

- Combat occurs in the current `LdtkRoom`; no separate `CombatScene` arena.
- Existing terrain, elevation, hazards, objects, and orientation remain visible.
- Threats are visible and avoidable unless a clearly authored story moment
  prevents avoidance.
- A resolved encounter writes a persistent state flag and does not respawn on
  an ordinary room rebuild.
- Critical-path encounters must not require the player to predict the correct
  roster before entering a long one-way route. Offer advance telegraphing,
  nearby party swapping, multiple solutions, or a baseline Hero tool.
- Repeat tactical fights are not a content substitute.

Auto-resolve is a long-term option for optional encounters the party clearly
outclasses or enemy families already mastered. It is not part of the migration
prototype.

## Deterministic Combat Direction

Random hit and damage rolls are removed from the target design.

- An attack hits if its target remains in the affected cell or area and the
  action is not blocked or interrupted.
- The UI previews exact damage, forced movement, status, affected cells, and
  duration before commitment.
- Critical or bonus effects come from positioning, height, exposed states, or
  authored combinations rather than chance.
- Enemy intent shows movement, target, affected cells, damage, and status soon
  enough for the player to respond.
- Reactions such as pushing, stunning, freezing, blocking, obscuring, or
  changing terrain can alter or cancel an enemy plan.

The first prototype formula may start with:

`damage = max(1, ability_power + attacker_stat - target_defense)`

The formula is not yet locked; preview/result agreement is locked.

### Turn structure prototype

The recommended first prototype is an intent round:

1. Enemies declare movement, targets, and effects.
2. The player reviews all intentions.
3. Active friends act in any order.
4. Surviving enemy actions resolve.
5. Environmental reactions and end-of-round effects resolve.

This structure is a hypothesis to test, not permission to build a production
combat framework without a red/green prototype and windowed feel check. If it
fails, the fallback is deterministic alternating initiative with intents shown
one actionable turn ahead.

## Visual And Spatial Direction

The target is 2D orthogonal-grid gameplay rendered from a three-quarter
overhead perspective. It is **not** a true diamond-isometric conversion.

- Keep square-cell authoring, `TileMapLayer`, and grid pathfinding.
- Use three-quarter character sprites, vertical wall/cliff faces, stronger
  shadows, and explicit foreground/background layering.
- Add a small integer elevation to cells and authored transitions such as
  ramps, stairs, vines, and ledges.
- The migration prototype proves readable height before adding cover,
  ballistics, complicated line-of-sight, or multi-level pathfinding.
- Kenney assets remain a licensed placeholder skeleton. New production art
  must support the three-quarter direction and replace assets through existing
  resource/tileset seams rather than gameplay rewrites.

## Progression, Recovery, And Economy

- Progression comes from finite encounters, discoveries, quests, recruitment,
  equipment, and story milestones—not mandatory grinding.
- Defeated threats remain resolved, so encounter rewards must be authored and
  sufficient without farming.
- Long tactical encounters, persistent depletion, and frequent respawns must
  never coexist. The migration prototype will decide whether regular combat
  uses encounter recovery or shorter attrition-oriented fights.
- Party swapping should be available at a clear world affordance such as a
  Selena shrine, camp, or safe hub.
- Currency, shops, crafting, injuries, morale, and relationship bonuses are
  separate scope decisions. Do not import a guild-management game by accident.

## Architecture Migration

The current build is retained as a reversible baseline until each replacement
prototype passes. Do not delete old systems merely because the new docs
supersede them.

### Preserve

- Godot 4.7.x, GDScript, Mobile renderer, nearest filtering, and flexible
  HD/ultrawide scaling.
- LDtk importer and entity-authoring pipeline.
- `TileMapLayer`, `RoomGrid`, `AStarGrid2D`, grid-snapped Tween movement, map
  registry, and room transitions.
- Resource-backed character, ability, item, map, and encounter data.
- Blocks, plates, levers, doors, chests, dialogue, input prompts, debug tools,
  atomic JSON save/load, and the first-party test harness.
- Kenney assets and manifests as replaceable prototype presentation.

### Adapt

| Existing area | Migration target |
|---|---|
| `Player` | selectable party leader plus non-blocking exploration followers |
| `RoomGrid` | elevation plus material/state queries and persistent alterations |
| `AbilityData` | deterministic effects usable in world and encounter modes |
| `OverworldEnemy` | avoidable persistent encounter actor with readable detection |
| `TurnManager` | intent-round controller if the prototype validates it |
| `GameState` / `SaveData` | roster/bench plus resolved encounter and world-state IDs |
| LDtk entities | height, material, encounter objective, and reaction metadata |

### Retire after replacement proof

- Separate `CombatScene` battlefield presentation.
- Arena generation, arena shuffle bags, and zoom/fade combat handoff.
- d10 hit thresholds, hit rolls, and RNG-dependent damage.
- Automatic enemy respawn on room rebuild.
- Single-overworld-avatar assumptions.
- Strictly top-down art rules.

## Migration Roadmap

1. **Canon reset:** align control docs and stop old Phase 4/5 work selection.
2. **Three-quarter height spike:** one room, two elevations, ramp/stairs, tall
   wall, and four visible party members.
3. **Visible-party exploration spike:** leader switching and follower recovery
   through narrow paths without blocking puzzles.
4. **Material/reaction spike:** grow then burn a vine; douse a fire; create and
   remove a traversable state using shared code.
5. **Unified deterministic encounter spike:** fight one enemy directly in the
   room with exact previews and one telegraphed interruptible action.
6. **Persistence proof:** defeat the threat, alter the room, leave, reload, and
   confirm both resolutions remain.
7. **Thesis slice:** Hero plus two real friends, one NPC resolution, one
   environmental puzzle, one meaningful encounter, and one opened route.
8. **External playtest:** players outside the design process judge whether
   encounters deepen the adventure rather than interrupt it.
9. **Steam-demo production:** only after the thesis slice passes.

The live queue and proof requirements are in `TASKBOARD.md`.

## Non-Goals For The Migration

- True isometric rendering or a 3D conversion.
- A huge Pokémon-scale roster.
- Procedural worlds, procedural encounter maps, or random encounters.
- Full guild management, injuries, morale simulation, or relationship economy.
- Auto-resolve before the manual encounter loop is fun.
- Android/touch UI before the Steam-first PC experience is validated.
- Deleting the working legacy combat path before a proven replacement exists.
- Building every elemental reaction at once.

## Health Criteria

The pivot is healthy when:

- the current migration baseline still imports, boots, and passes its tests;
- the active party explores visibly without follower softlocks;
- one room communicates height clearly from the three-quarter perspective;
- the same ability changes the same material in and out of an encounter;
- exact previews match deterministic results;
- an enemy intention is visible and meaningfully interruptible;
- encounters happen in place and resolved threats remain gone after reload;
- the thesis slice is understandable without design-team explanation;
- external players want to continue exploring after the tactical encounter.

## Known Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Roster and ability combinatorics | High | Small shared verb/material system; 5-6 demo friends and 10-12 planning ceiling |
| Rewriting healthy combat too early | High | Preserve baseline; replace only behind prototype proof |
| Followers wedge puzzles or corridors | High | Non-blocking exploration followers; encounter-time valid-cell placement; dedicated tests |
| Three-quarter art becomes an isometric-engine rewrite | High | Orthogonal logic grid; prove height visually before changing pathfinding |
| Deterministic battles become rote | Medium-High | Enemy intents, terrain manipulation, objective variety, and authored combinations |
| Wrong roster creates hard locks | High | Telegraph needs, multiple solutions, nearby swapping, baseline Hero tools |
| Finite enemies break XP/economy | Medium | Story/encounter progression and authored reward budget; no grind dependency |
| Commercial scope expands platform burden | Medium | Steam-first; defer mobile, store work, and final release tooling until thesis proof |
| Generic story fails to carry the systems | Medium | Friends and the mountain expedition are the narrative spine; resolve open lore questions before content scale-up |

## Locked Decisions After The Pivot

Do not relitigate these without flagging the tradeoff to Kayden first:

- Godot 4.7.x and GDScript.
- 2D orthogonal grid rendered in three-quarter perspective; no true isometric
  or 3D conversion.
- `TileMapLayer`, LDtk authoring, `AStarGrid2D`, and grid-snapped Tween movement.
- Active party of up to four, visible during exploration and encounters.
- Same-room unified encounters; no separate battle arena in the target design.
- Deterministic outcomes and exact previews; no d10 hit rolls in the target.
- Visible, avoidable threats and persistent encounter resolution.
- Shared material/effect vocabulary across exploration and encounters.
- Dense authored content; no random encounters or procedural world.
- Steam-first PC target; mobile is deferred.
- Existing working systems remain until replacement proof exists.

Open prototype decisions are not locked: final turn structure, exact damage
formula, recovery model, elevation combat bonuses, party-swap location, final
roster size below the ceiling, and the first two real Dungeon Friends.

## Trust, Privacy, And Safety Boundaries

- No backend, user accounts, telemetry, or API keys are required.
- Never commit Android release keystores (`*.jks`, `*.keystore`) or signing
  passwords.
- Third-party assets must retain their licenses. Kenney runtime selections are
  CC0 and remain credited as a courtesy.
- A commercial release requires an explicit license decision for this
  repository before publication; do not edit `LICENSE` without Kayden's request.
