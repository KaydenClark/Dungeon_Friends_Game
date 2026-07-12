extends "res://tests/gd_test.gd"
## T-092: red/green for the deterministic intent-round core (D-026/D-027).
## The pinned contract is preview=result and exact cancellation/status
## behavior - the damage numbers themselves are tunables.

const IntentLogic := preload("res://scripts/dev/intent_logic.gd")


## Hero at (2,2), friend at (3,4), slime at (8,2) on a 12x8 open field.
func _state() -> Dictionary:
	return {
		"width": 12, "height": 8, "blocked": {},
		"units": {
			"hero": {"id": "hero", "cell": Vector2i(2, 2), "hp": 20,
					"max_hp": 20, "atk": 5, "df": 2, "side": "party",
					"statuses": {}},
			"friend": {"id": "friend", "cell": Vector2i(3, 4), "hp": 14,
					"max_hp": 14, "atk": 4, "df": 1, "side": "party",
					"statuses": {}},
			"slime": {"id": "slime", "cell": Vector2i(8, 2), "hp": 12,
					"max_hp": 12, "atk": 3, "df": 1, "side": "enemy",
					"statuses": {}},
		},
	}


## --- plan ---------------------------------------------------------------------

func test_plan_is_deterministic_by_distance() -> void:
	var far := _state()
	eq(IntentLogic.make_plan(far, "slime"), ["move", "move", "spit"],
			"far plan (d=6)")
	eq(IntentLogic.make_plan(far, "slime"),
			IntentLogic.make_plan(far, "slime"),
			"same state -> same plan")
	var mid := _state()
	mid["units"]["slime"]["cell"] = Vector2i(4, 2)
	eq(IntentLogic.make_plan(mid, "slime"), ["move", "spit", "slam"],
			"mid plan (d=2)")
	var near := _state()
	near["units"]["slime"]["cell"] = Vector2i(3, 2)
	eq(IntentLogic.make_plan(near, "slime"), ["slam", "spit", "move"],
			"adjacent plan (d=1)")


func test_plan_refills_rolling_window() -> void:
	var state := _state()
	var plan: Array = IntentLogic.make_plan(state, "slime")
	plan.pop_front()
	plan = IntentLogic.refill_plan(state, "slime", plan)
	eq(plan.size(), IntentLogic.PLAN_LENGTH, "window stays at 3 verbs")


func test_slam_declare_invalid_when_not_adjacent_forces_replan() -> void:
	var state := _state()
	var intent: Dictionary = IntentLogic.declare(state, "slime", "slam")
	ok(intent.get("invalid", false),
			"slam with no adjacent target is invalid (caller replans)")


## --- preview = result ------------------------------------------------------------

func test_spit_preview_equals_result_when_target_stays() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(5, 2)
	var intent: Dictionary = IntentLogic.declare(state, "slime", "spit")
	eq(intent["verb"], "spit", "spit declares")
	eq(intent["cells"], [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2)],
			"line locks toward the hero")
	var shown: Array = IntentLogic.preview(state, intent)
	eq(shown.size(), 1, "preview shows exactly one victim")
	eq(shown[0]["id"], "hero", "preview names the hero")
	eq(shown[0]["damage"], IntentLogic.SPIT_DAMAGE, "preview shows exact damage")
	var results: Array = IntentLogic.resolve(state, intent)
	eq(results, shown, "RESULT EQUALS PREVIEW - the D-026 contract")
	eq(state["units"]["hero"]["hp"], 20 - IntentLogic.SPIT_DAMAGE,
			"hp applied exactly as shown")
	eq(state["units"]["hero"]["statuses"].get("burn", 0),
			IntentLogic.SPIT_BURN_ROUNDS, "burn applied at exact duration")


func test_spit_misses_when_target_moves_out() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(5, 2)
	var intent: Dictionary = IntentLogic.declare(state, "slime", "spit")
	state["units"]["hero"]["cell"] = Vector2i(2, 3)  # step out of the line
	eq(IntentLogic.preview(state, intent), [], "moved target previews safe")
	eq(IntentLogic.resolve(state, intent), [], "moved target takes nothing")
	eq(state["units"]["hero"]["hp"], 20, "hero unharmed after dodging")


func test_spit_hits_blocker_first() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(5, 2)
	var intent: Dictionary = IntentLogic.declare(state, "slime", "spit")
	state["units"]["friend"]["cell"] = Vector2i(4, 2)  # step into the line
	var results: Array = IntentLogic.resolve(state, intent)
	eq(results.size(), 1, "line stops at the first body")
	eq(results[0]["id"], "friend", "the blocker takes the hit")
	eq(state["units"]["friend"]["hp"], 14 - IntentLogic.SPIT_DAMAGE,
			"blocker damage matches the telegraph")
	eq(state["units"]["hero"]["hp"], 20, "the shielded hero is untouched")


func test_slam_hits_whoever_remains_in_the_cell() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(3, 2)  # adjacent to hero
	var intent: Dictionary = IntentLogic.declare(state, "slime", "slam")
	eq(intent["cells"], [Vector2i(2, 2)], "slam locks the hero's cell")
	# Hero steps out; friend steps INTO the locked cell.
	state["units"]["hero"]["cell"] = Vector2i(2, 1)
	state["units"]["friend"]["cell"] = Vector2i(2, 2)
	var results: Array = IntentLogic.resolve(state, intent)
	eq(results.size(), 1, "the cell is what is hit, not the old target")
	eq(results[0]["id"], "friend", "whoever stands in the cell takes it")


## --- counterplay ------------------------------------------------------------------

func test_stun_cancels_intent_and_skips_exactly_one_declare() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(5, 2)
	var intent: Dictionary = IntentLogic.declare(state, "slime", "spit")
	IntentLogic.stun_enemy(state, intent)
	ok(intent["canceled"], "stun cancels the declared intention")
	eq(IntentLogic.resolve(state, intent), [], "canceled intent resolves to nothing")
	# Environment ticks never eat stun - only a skipped declare consumes it,
	# so the skip is exact no matter when in the round the stun landed.
	IntentLogic.environment_tick(state)
	eq(state["units"]["slime"]["statuses"].get("stun", 0), 1,
			"stun survives the environment tick")
	var next: Dictionary = IntentLogic.declare(state, "slime", "spit")
	eq(next["verb"], "stunned", "stunned enemy skips its next declare")
	eq(state["units"]["slime"]["statuses"].has("stun"), false,
			"the skipped declare consumes the stun")
	var after: Dictionary = IntentLogic.declare(state, "slime", "spit")
	eq(after["verb"], "spit", "enemy acts again the round after")


func test_push_moves_enemy_and_cancels_its_intent() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(5, 2)
	var intent: Dictionary = IntentLogic.declare(state, "slime", "spit")
	var pushed: bool = IntentLogic.push_unit(state, "slime", Vector2i.RIGHT, intent)
	ok(pushed, "push into a free cell succeeds")
	eq(state["units"]["slime"]["cell"], Vector2i(6, 2), "enemy moved one cell")
	ok(intent["canceled"], "pushed owner's intention is canceled")
	eq(IntentLogic.resolve(state, intent), [], "canceled spit resolves to nothing")


func test_push_into_wall_fails_and_cancels_nothing() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(5, 2)
	state["blocked"][Vector2i(6, 2)] = true
	var intent: Dictionary = IntentLogic.declare(state, "slime", "spit")
	var pushed: bool = IntentLogic.push_unit(state, "slime", Vector2i.RIGHT, intent)
	not_ok(pushed, "push into a wall is refused")
	not_ok(intent["canceled"], "a failed push cancels nothing")


## --- exact statuses ---------------------------------------------------------------

func test_burn_ticks_exactly_its_duration() -> void:
	var state := _state()
	state["units"]["hero"]["statuses"]["burn"] = 2
	var tick1: Array = IntentLogic.environment_tick(state)
	eq(tick1.size(), 1, "round 1: one burn tick")
	eq(state["units"]["hero"]["hp"], 19, "round 1: exactly 1 damage")
	var tick2: Array = IntentLogic.environment_tick(state)
	eq(tick2.size(), 1, "round 2: one burn tick")
	eq(state["units"]["hero"]["hp"], 18, "round 2: exactly 1 damage")
	var tick3: Array = IntentLogic.environment_tick(state)
	eq(tick3.size(), 0, "round 3: burn is over - no third tick")
	eq(state["units"]["hero"]["hp"], 18, "no damage after expiry")


## --- player side -------------------------------------------------------------------

func test_player_attack_preview_equals_result() -> void:
	var state := _state()
	var strike := {"power": 0, "status": {}}
	var shown: Dictionary = IntentLogic.player_attack_preview(
			state, "hero", "slime", strike)
	eq(shown["damage"], 4, "max(1, 0+5-1) = 4 shown")
	eq(shown["target_hp_after"], 8, "hp-after shown")
	var applied: Dictionary = IntentLogic.player_attack_resolve(
			state, "hero", "slime", strike)
	eq(applied, shown, "RESULT EQUALS PREVIEW on the player side too")
	eq(state["units"]["slime"]["hp"], 8, "hp landed exactly as shown")


func test_player_stun_ability_applies_exact_duration() -> void:
	var state := _state()
	var bash := {"power": -2, "status": {"stun": 1}}
	var shown: Dictionary = IntentLogic.player_attack_resolve(
			state, "hero", "slime", bash)
	eq(shown["damage"], 2, "max(1, -2+5-1) = 2")
	eq(state["units"]["slime"]["statuses"].get("stun", 0), 1,
			"stun lands at exactly the stated duration")


## --- enemy movement ----------------------------------------------------------------

func test_move_is_deterministic_and_respects_occupancy() -> void:
	var state := _state()
	var intent: Dictionary = IntentLogic.declare(state, "slime", "move")
	eq(intent["verb"], "move", "move executes at declare")
	eq(intent["path"], [Vector2i(7, 2), Vector2i(6, 2)],
			"two greedy steps along the primary axis")
	eq(state["units"]["slime"]["cell"], Vector2i(6, 2), "enemy cell updated")
	var again := _state()
	var repeat: Dictionary = IntentLogic.declare(again, "slime", "move")
	eq(repeat["path"], intent["path"], "same state -> same path")


func test_move_never_steps_onto_a_unit() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(4, 2)  # 2 cells from hero
	IntentLogic.declare(state, "slime", "move")
	ne(state["units"]["slime"]["cell"], Vector2i(2, 2),
			"never lands on the hero")
	eq(state["units"]["slime"]["cell"], Vector2i(3, 2),
			"stops adjacent instead")
