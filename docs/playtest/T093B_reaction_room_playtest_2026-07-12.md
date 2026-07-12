# T-093B Reaction Room - Played Playtest Notes (2026-07-12)

**Tester:** Claude (Cowork), driving the running game as a player.
**Build:** `scenes/dev/reaction_room_spike.tscn`, run interactively (F6) in Godot
4.7 on the on-disk working tree. Window 1280x720.
**Scope:** Reaction room only (per Kayden's pick). Exploration casting and the
in-room encounter/intent counterplay.
**Verdict gate:** This is the "played fun/not-fun" pass the taskboard was
waiting on. Read the fun section at the bottom.

## Result summary

| Area | Status |
|---|---|
| Boots and runs | Pass, no crashes |
| Exploration casting (grow/fire/air/water/cold) | Pass, all previews matched commit |
| Air-fed fire cascade down brush chain | Pass, logic correct |
| Encounter trigger + intent telegraph + forecast | Pass |
| Reaction cancels declared intention (spark on wet slime) | Pass, promised pre-commit and delivered |
| Functional bugs | None found |
| Board readability of reaction state | Weak (see friction) |
| Runtime errors | None (12 flagged items are parse warnings) |

## What I did

Exploration: grew the soil to a vine, burned the vine (vine consumed, cell to
[soil, fire, smoke], 2 fire dmg), air-fed the fire down the full flammable
brush chain (10,5 to 13,5, each flammable consumed), flooded a channel cell
([channel, wet, flooded]) then froze it to ice (both water effects consumed).
Every preview panel matched the committed result exactly.

Encounter: walked the leader up to the slime, cue fired once, party deployed
via formation. Round 1 the slime declared MOVE and forecast "spit, slam." I
wet the slime's cell (a cast spends the unit's action). Ended all four turns.
Round 2 the slime declared SPIT exactly as forecast ("3 dmg + Burn(2), would
hit: Hero"). I sparked the wet slime cell; the panel promised "WOULD CANCEL
the slime's declared intention!" before commit, and on commit the slime took
exactly 2 and the intention was canceled. Slime 12/12 to 10/12.

This all matches the RUNBOOK T-093B expectations.

## Friction (ranked)

1. **Fire and smoke are nearly invisible on the board.** A burning cell renders
   as a muddy brown square almost identical to plain soil/floor; smoke (full
   gray overlay) washes out the orange fire inset. The air-fed chain reaction,
   the most impressive mechanic, produces four identical brown tiles with no
   visible payoff. All the drama lives in the text panel. Ice, by contrast,
   reads clearly (pale fill, white border), and wet/channel read okay. This is
   the single biggest thing holding the room back.

2. **Persistent hint text overlaps the combat HUD.** The exploration
   instruction block (T-097/T-093B keys and tips) stays on screen during the
   encounter and overlaps the Round/Intent labels and the unit HP tags (Slime,
   Blocker1/2), so both are hard to read. Recommend hiding the exploration hint
   once an encounter starts.

3. **Low-contrast panels.** The preview panel and the materials legend are
   white text placed over the light-brown upper-room tiles. Legible only when I
   zoomed. A dark semi-transparent backing box behind both would fix it.

4. **Input is ignored until you click inside the game window.** My first keypress
   did nothing; movement and casting only started working after I clicked in the
   viewport. A real player may think the game is frozen. (Partly an embedded-run
   quirk, but worth a click-to-focus prompt or auto-grab.)

5. **Party cohesion reads oddly in exploration.** Only the leader roams while
   the other three sit at the campfire, then they trail single-file when the
   leader enters the corridor. Functionally fine, visually disjointed for a
   "visible party" pitch.

6. **Blocked aim directions fail silently.** WASD aim clamps to range 3 and to
   targetable cells; when a direction is rejected (wall/range) there is no cue,
   so it feels like a dropped input. Minor.

## Bugs

- No functional bugs, crashes, or preview/commit mismatches in the reaction
  room. The "preview always equals commit" contract held on every cast.
- The editor's "Errors (12)" are all GDScript parse warnings, project-wide, not
  reaction-room-specific and not runtime failures:
  - signal `player_moved` declared but never used
  - several "Integer division. Decimal part will be discarded"
  - `for` iterator variable `door` shadows a variable at line 23 in base class
    `LdtkRoom`
  Low priority, but worth a hygiene sweep since they clutter the debugger.

## Fun / not-fun read

The systems are fun. The full pre-commit preview makes every cast feel
trustworthy and deliberate, and using the environment to cancel a telegraphed
attack is a genuinely satisfying tactical beat, the clear standout of the room.
The intent forecast plus exact telegraph gives real "I see it coming, now I
counter it" agency.

The presentation undersells the systems. Because the board barely shows what a
reaction did (especially fire and smoke), the payoff is delivered by a
low-contrast wall of text rather than by the scene reacting in front of you. My
recommendation before calling the fun question settled: do one readability pass
(distinct fire/smoke marks, dark backing on the panel and legend, hide the
exploration hint during combat). With that, the room should land as clearly fun
rather than fun-once-you-read-the-panel.
