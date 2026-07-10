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


## D-008 defeat penalty (T-041): lose a fraction of the progress toward the
## next level, never below the current level's floor. Kayden's 2026-07-10
## tuning: 25% of above-floor progress ("never feels too harsh"), replacing
## the lose-it-all first cut.
func test_defeat_costs_a_quarter_of_above_floor_progress() -> void:
	eq(Progression.DEFEAT_XP_LOSS, 0.25,
			"the tuned penalty fraction is pinned (Kayden, 2026-07-10)")
	eq(Progression.xp_after_defeat(20, 1), 15,
			"level 1 (floor 0): 20 XP keeps 75% -> 15")
	var floor_2 := Progression.total_xp_for_level(2)
	eq(Progression.xp_after_defeat(floor_2 + 12, 2), floor_2 + 9,
			"level 2: only above-floor progress pays the 25%")


func test_defeat_never_drops_below_the_floor() -> void:
	var floor_3 := Progression.total_xp_for_level(3)
	eq(Progression.xp_after_defeat(floor_3, 3), floor_3,
			"exactly at the floor: nothing to lose")
	ok(Progression.xp_after_defeat(floor_3 - 5, 3) >= floor_3,
			"an (impossible) below-floor value is clamped up, never down")
