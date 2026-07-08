extends "res://tests/gd_test.gd"
## Unit tests for the pure d10 combat math in CombatScene. Rewritten for the
## shared CombatStats block (T-052, Kayden's 2026-07-07 direction): hit is
## skill vs speed, physical damage is power + might vs guard, focus damage
## and status chance are focus vs focus. Presentation stays roll-HIGH-good
## (the 2026-07-05 playtest flip) and Defend keeps its two effects (-2 hit
## tiers, damage halved) on top of the new stats. These call the *same*
## static functions the live _attack() path uses.


func test_hit_threshold_is_skill_vs_speed() -> void:
	# 7 + skill - speed: the baseline exchange is 70%.
	eq(CombatScene.hit_threshold(4, 4, false), 7, "evenly matched = 70% tier")
	eq(CombatScene.hit_threshold(4, 1, false), 9, "hero vs slow slime caps at 90%")
	eq(CombatScene.hit_threshold(2, 4, false), 5, "slime vs nimble hero = 50%")


func test_hit_threshold_defending_subtracts_two() -> void:
	eq(CombatScene.hit_threshold(4, 2, false), 9, "undefended tier")
	eq(CombatScene.hit_threshold(4, 2, true), 7, "bracing costs 2 tiers")


func test_hit_threshold_clamped_to_band() -> void:
	# Never a guaranteed hit or a certain miss: 2..9 (20%..90%, per the
	# adopted scale - the floor rose from 10% to 20%).
	eq(CombatScene.hit_threshold(20, 0, false), 9, "clamped to 90% max")
	eq(CombatScene.hit_threshold(0, 20, false), 2, "clamped to 20% min")


func test_needed_roll_is_inverse_of_threshold() -> void:
	# roll-high-good: 70% tier means "roll a 4 or higher".
	eq(CombatScene.needed_roll(7), 4, "70% -> need 4+")
	eq(CombatScene.needed_roll(9), 2, "90% -> need 2+")
	eq(CombatScene.needed_roll(2), 9, "20% -> need 9+")


func test_needed_roll_probability_matches_tier() -> void:
	# For every tier, the count of winning d10 faces (>= needed) must equal
	# the threshold's tens digit - i.e. threshold really is the percent-to-hit.
	for threshold in range(2, 10):
		var needed := CombatScene.needed_roll(threshold)
		var winning_faces := 0
		for face in range(1, 11):
			if face >= needed:
				winning_faces += 1
		eq(winning_faces, threshold, "tier %d has %d winning faces" % [threshold, threshold])


func test_attack_damage_is_power_plus_might_minus_guard() -> void:
	eq(CombatScene.attack_damage(2, 4, 1, false), 5, "swing(2) + might 4 - guard 1")
	eq(CombatScene.attack_damage(0, 3, 2, false), 1, "bare power still lands")


func test_attack_damage_floor_is_one() -> void:
	# A big defender never fully absorbs a hit - a landed blow always stings.
	eq(CombatScene.attack_damage(0, 1, 10, false), 1, "min 1 damage despite armor")


func test_attack_damage_defending_halves_min_one() -> void:
	eq(CombatScene.attack_damage(2, 4, 2, true), 2, "bracing halves 4 to 2")
	eq(CombatScene.attack_damage(0, 2, 1, true), 1, "bracing floors at 1")


func test_focus_damage_mirrors_physical() -> void:
	eq(CombatScene.focus_damage(2, 5, 1), 6, "spell(2) + focus 5 - focus 1")
	eq(CombatScene.focus_damage(0, 0, 6), 1, "min 1 focus damage")


func test_status_threshold_is_focus_vs_focus() -> void:
	# 6 + attacker focus - defender focus, clamped to the same 2..9 band.
	eq(CombatScene.status_threshold(3, 3), 6, "even focus = 60%")
	eq(CombatScene.status_threshold(6, 0), 9, "capped at 90%")
	eq(CombatScene.status_threshold(0, 6), 2, "floored at 20%")
