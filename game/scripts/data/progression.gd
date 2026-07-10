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
