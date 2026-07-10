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


## Fraction of above-floor progress lost on defeat (T-041/D-008). Kayden's
## 2026-07-10 tuning: "lose some % of how much you have left to lose so it
## never feels too harsh" - 25% of above-floor progress, replacing the
## lose-it-all first cut. Still TUNABLE ("we can make it feel worse if we
## need to later"; money loss may join/replace this once currency exists).
const DEFEAT_XP_LOSS := 0.25


## XP after a defeat: lose DEFEAT_XP_LOSS of the progress past the current
## level's floor, and never end below that floor - "not having to do things
## over again is never the punishment" (Kayden, D-008).
static func xp_after_defeat(current_xp: int, level: int) -> int:
	var floor_xp := total_xp_for_level(level)
	var progress := maxi(current_xp - floor_xp, 0)
	return floor_xp + int(round(progress * (1.0 - DEFEAT_XP_LOSS)))
