extends "res://tests/gd_test.gd"
## Unit tests for the pure XP curve (T-045, strict red/green per RUNBOOK ->
## Test Coverage Policy). The curve numbers are placeholders, but the *shape*
## rules pinned here are the contract: positive costs, monotonically
## non-decreasing steps, and a pinned level-1 base so accidental rebalances
## fail loudly.


func test_level_one_base_cost_is_pinned() -> void:
	eq(Progression.xp_to_next(1), 20, "level 1 -> 2 costs 20 XP (placeholder, tunable)")


func test_costs_are_positive() -> void:
	for level in range(1, 21):
		ok(Progression.xp_to_next(level) > 0,
				"level %d cost is positive" % level)


func test_costs_never_decrease() -> void:
	for level in range(1, 20):
		ok(Progression.xp_to_next(level + 1) >= Progression.xp_to_next(level),
				"cost is monotonic at level %d" % level)


func test_total_xp_accumulates_the_steps() -> void:
	eq(Progression.total_xp_for_level(1), 0, "level 1 is the start - 0 total XP")
	eq(Progression.total_xp_for_level(2), Progression.xp_to_next(1),
			"level 2 total = the first step")
	var by_hand := Progression.xp_to_next(1) + Progression.xp_to_next(2) \
			+ Progression.xp_to_next(3)
	eq(Progression.total_xp_for_level(4), by_hand, "level 4 total sums steps 1-3")


## D-008 defeat penalty (T-041): lose progress toward the next level, never
## below the current level's floor. First cut loses ALL above-floor progress
## (DEFEAT_XP_LOSS = 1.0, a tunable flagged for Kayden's playtest).
func test_defeat_drops_xp_to_the_level_floor() -> void:
	eq(Progression.xp_after_defeat(15, 1), 0,
			"level 1 (floor 0): mid-progress XP drops to 0")
	var floor_2 := Progression.total_xp_for_level(2)
	eq(Progression.xp_after_defeat(floor_2 + 13, 2), floor_2,
			"level 2: above-floor progress is lost, floor kept")


func test_defeat_never_drops_below_the_floor() -> void:
	var floor_3 := Progression.total_xp_for_level(3)
	eq(Progression.xp_after_defeat(floor_3, 3), floor_3,
			"exactly at the floor: nothing to lose")
	ok(Progression.xp_after_defeat(floor_3 - 5, 3) >= floor_3,
			"an (impossible) below-floor value is clamped up, never down")
