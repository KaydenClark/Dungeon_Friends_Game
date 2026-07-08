extends "res://tests/gd_test.gd"
## Red/green suite for T-045 (M3.1): the pure xp_to_next(level) curve -
## Phase 3 only pins the *data shape* so SaveData carries progression from
## day one; level-up mechanics (stat growth, combat integration) stay
## Phase 5 (M5.3). The numbers are placeholders (clearly marked in
## progression.gd) - these tests pin the curve's contract, not its tuning:
## a known level-1 base, strictly rising cost, strictly rising deltas
## (each level costs more than the last), and safe handling of out-of-range
## input.


func test_level_one_base() -> void:
	eq(Progression.xp_to_next(1), 10,
			"level 1 -> 2 costs the placeholder base of 10 XP")


func test_curve_is_strictly_monotonic() -> void:
	for level in range(1, 50):
		ok(Progression.xp_to_next(level + 1) > Progression.xp_to_next(level),
				"xp_to_next(%d) rises past xp_to_next(%d)" % [level + 1, level])


func test_deltas_are_positive_and_rising() -> void:
	# "Positive deltas": not just a rising curve, but a rising *cost step* -
	# each level-up must ask more than the one before it.
	var prev_delta := 0
	for level in range(1, 30):
		var delta := Progression.xp_to_next(level + 1) - Progression.xp_to_next(level)
		ok(delta > 0, "delta at level %d is positive" % level)
		ok(delta >= prev_delta, "delta at level %d never shrinks" % level)
		prev_delta = delta


func test_out_of_range_levels_clamp_to_level_one() -> void:
	eq(Progression.xp_to_next(0), Progression.xp_to_next(1),
			"level 0 clamps to the level-1 cost instead of going weird")
	eq(Progression.xp_to_next(-3), Progression.xp_to_next(1),
			"negative levels clamp too")
