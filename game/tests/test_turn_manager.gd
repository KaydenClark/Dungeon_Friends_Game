extends "res://tests/gd_test.gd"
## Unit tests for TurnManager (T-061, strict red/green - pure logic). The
## pinned contract: all combatants sorted together by speed each round
## (never team-phase), deterministic tie-breaks (players first, then setup
## order), dead units skipped, order recalculated on every round refill.


func _unit(id: String, speed: int, is_player: bool, hp := 10) -> CombatUnit:
	var u := CombatUnit.new()
	u.unit_id = id
	u.display_name = id
	u.speed = speed
	u.max_hp = hp
	u.hp = hp
	u.is_player = is_player
	return u


func _ids(order: Array[CombatUnit]) -> Array:
	return order.map(func(u: CombatUnit) -> String: return u.unit_id)


func test_initiative_interleaves_teams_by_speed() -> void:
	# hero(5) slime_a(4) buddy(3) slime_b(2): strict per-unit speed order,
	# never "all players then all enemies".
	var tm := TurnManager.new()
	tm.setup([_unit("hero", 5, true), _unit("slime_a", 4, false),
			_unit("buddy", 3, true), _unit("slime_b", 2, false)])
	eq(_ids(tm.build_order()), ["hero", "slime_a", "buddy", "slime_b"],
			"speed order interleaves the two sides")


func test_speed_tie_player_acts_first_then_setup_order() -> void:
	var tm := TurnManager.new()
	tm.setup([_unit("slime_a", 4, false), _unit("buddy", 4, true),
			_unit("slime_b", 4, false)])
	eq(_ids(tm.build_order()), ["buddy", "slime_a", "slime_b"],
			"tied speed: player first, then enemies keep setup order")


func test_dead_units_are_not_in_the_order() -> void:
	var tm := TurnManager.new()
	var dead := _unit("slime_a", 9, false)
	dead.hp = 0
	tm.setup([_unit("hero", 5, true), dead])
	eq(_ids(tm.build_order()), ["hero"], "dead units never appear")


func test_next_unit_cycles_rounds_and_recalculates() -> void:
	var tm := TurnManager.new()
	var hero := _unit("hero", 5, true)
	var slime := _unit("slime", 3, false)
	tm.setup([hero, slime])
	eq(tm.next_unit().unit_id, "hero", "round 1: hero first")
	eq(tm.round_number, 1, "first pull starts round 1")
	eq(tm.next_unit().unit_id, "slime", "round 1: slime second")
	# Kill the slime between rounds: the refill must drop it.
	slime.hp = 0
	eq(tm.next_unit().unit_id, "hero", "round 2 refill skips the dead slime")
	eq(tm.round_number, 2, "round counter advanced on refill")


func test_next_unit_skips_units_killed_mid_round() -> void:
	var tm := TurnManager.new()
	var hero := _unit("hero", 5, true)
	var a := _unit("slime_a", 4, false)
	var b := _unit("slime_b", 3, false)
	tm.setup([hero, a, b])
	eq(tm.next_unit().unit_id, "hero", "hero opens the round")
	a.hp = 0  # hero's turn killed slime_a before it acted
	eq(tm.next_unit().unit_id, "slime_b", "mid-round death is skipped")


func test_next_unit_returns_null_when_everyone_is_dead() -> void:
	var tm := TurnManager.new()
	var hero := _unit("hero", 5, true)
	hero.hp = 0
	var slime := _unit("slime", 3, false)
	slime.hp = 0
	tm.setup([hero, slime])
	ok(tm.next_unit() == null, "no living units -> null, no infinite loop")


func test_battle_over_and_side_liveness() -> void:
	var tm := TurnManager.new()
	var hero := _unit("hero", 5, true)
	var slime := _unit("slime", 3, false)
	tm.setup([hero, slime])
	not_ok(tm.battle_over(), "both sides alive -> battle continues")
	slime.hp = 0
	ok(tm.battle_over(), "enemies wiped -> battle over")
	ok(tm.players_alive(), "players still standing")
	not_ok(tm.enemies_alive(), "no enemies standing")
