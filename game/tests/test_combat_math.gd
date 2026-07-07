extends "res://tests/gd_test.gd"
## Unit tests for the pure d10 combat math in CombatScene (hit_threshold /
## needed_roll / attack_damage). These call the *same* static functions the
## live _attack() path uses, so a balance/formula change that breaks the rules
## fails here. See combat.gd -> _attack for the caller.


func test_hit_threshold_base_case() -> void:
	# 5 + attack - defense, no bracing.
	eq(CombatScene.hit_threshold(4, 2, false), 7, "5+4-2 = 70% tier")
	eq(CombatScene.hit_threshold(1, 0, false), 6, "5+1-0 = 60% tier")


func test_hit_threshold_defending_subtracts_two() -> void:
	# Hero(atk4) vs Slime(def1) drops from 8 to 6 when the slime braces.
	eq(CombatScene.hit_threshold(4, 1, false), 8, "undefended tier")
	eq(CombatScene.hit_threshold(4, 1, true), 6, "bracing costs 2 tiers")


func test_hit_threshold_clamped_to_band() -> void:
	# Never a guaranteed hit or a certain miss: clamp to 1..9 (10%..90%).
	eq(CombatScene.hit_threshold(20, 0, false), 9, "clamped to 90% max")
	eq(CombatScene.hit_threshold(0, 20, false), 1, "clamped to 10% min")


func test_needed_roll_is_inverse_of_threshold() -> void:
	# roll-high-good: 70% tier means "roll a 4 or higher".
	eq(CombatScene.needed_roll(7), 4, "70% -> need 4+")
	eq(CombatScene.needed_roll(9), 2, "90% -> need 2+")
	eq(CombatScene.needed_roll(1), 10, "10% -> need a 10")


func test_needed_roll_probability_matches_tier() -> void:
	# For every tier, the count of winning d10 faces (>= needed) must equal the
	# threshold's tens digit -- i.e. threshold really is the percent-to-hit.
	for threshold in range(1, 10):
		var needed := CombatScene.needed_roll(threshold)
		var winning_faces := 0
		for face in range(1, 11):
			if face >= needed:
				winning_faces += 1
		eq(winning_faces, threshold, "tier %d has %d winning faces" % [threshold, threshold])


func test_attack_damage_subtracts_half_defense() -> void:
	eq(CombatScene.attack_damage(5, 4, false), 3, "5 - floor(4/2) = 3")
	eq(CombatScene.attack_damage(4, 2, false), 3, "hero vs slime: 4 - 1 = 3")


func test_attack_damage_floor_is_one() -> void:
	# A big defender never fully absorbs a hit -- a landed blow always stings.
	eq(CombatScene.attack_damage(1, 10, false), 1, "min 1 damage despite armor")


func test_attack_damage_defending_halves_min_one() -> void:
	# 6 - floor(2/2) = 5, then halved (floor) to 2 while bracing.
	eq(CombatScene.attack_damage(6, 2, true), 2, "bracing halves to 2")
	# 3 - 0 = 3, halved (floor) to 1 -- still at least 1.
	eq(CombatScene.attack_damage(3, 0, true), 1, "bracing floors at 1")
