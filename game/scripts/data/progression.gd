class_name Progression
extends Object
## Pure XP/level math (T-045). Data shape only - level-up *mechanics* (stat
## growth, combat integration) are Phase 5 (M5.3); nothing calls level_for()
## in earnest until then. PLACEHOLDER curve numbers, clearly tunable.


## XP required to go from `level` to `level + 1`. Placeholder curve
## (20, 50, 90, 140, ...): quadratic-ish so early levels come fast and
## later ones stretch out. Tune at the Phase 5 leveling pass.
static func xp_to_next(level: int) -> int:
	return 20 * level + 10 * level * (level - 1)


## Total XP required to *reach* `level` from level 1.
static func total_xp_for_level(level: int) -> int:
	var total := 0
	for l in range(1, level):
		total += xp_to_next(l)
	return total


## Fraction of above-floor progress lost on defeat (T-041/D-008). 1.0 = the
## whole "progress toward the next level" first cut - TUNABLE, flagged for
## Kayden's playtest (money loss may join/replace this once currency exists).
const DEFEAT_XP_LOSS := 1.0


## XP after a defeat: lose DEFEAT_XP_LOSS of the progress past the current
## level's floor, and never end below that floor - "not having to do things
## over again is never the punishment" (Kayden, D-008).
static func xp_after_defeat(current_xp: int, level: int) -> int:
	var floor_xp := total_xp_for_level(level)
	var progress := maxi(current_xp - floor_xp, 0)
	return floor_xp + int(round(progress * (1.0 - DEFEAT_XP_LOSS)))
