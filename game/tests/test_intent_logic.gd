extends "res://tests/gd_test.gd"
## T-092: red/green for the deterministic intent-round core (D-026/D-027).
## The pinned contract is preview=result and exact cancellation/status
## behavior - the damage numbers themselves are tunables.
## T-097 recut adds: plan entries with a public verb + private planning
## context, ordinary rolling refill that preserves telegraphed verbs, full
## rebuild on target/head invalidation, party_ids, the generic guarded_cells
## effect, and the Sol deployment-snapshot adapter seam.

const IntentLogic := preload("res://scripts/dev/intent_logic.gd")
const SolAdapter := preload("res://scripts/dev/sol_snapshot_adapter.gd")


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
	eq(IntentLogic.future_verbs(IntentLogic.make_plan(far, "slime")),
			["move", "move", "spit"], "far plan (d=6)")
	eq(IntentLogic.make_plan(far, "slime"),
			IntentLogic.make_plan(far, "slime"),
			"same state -> same plan")
	var mid := _state()
	mid["units"]["slime"]["cell"] = Vector2i(4, 2)
	eq(IntentLogic.future_verbs(IntentLogic.make_plan(mid, "slime")),
			["move", "spit", "slam"], "mid plan (d=2)")
	var near := _state()
	near["units"]["slime"]["cell"] = Vector2i(3, 2)
	eq(IntentLogic.future_verbs(IntentLogic.make_plan(near, "slime")),
			["slam", "spit", "move"], "adjacent plan (d=1)")


func test_plan_entries_expose_verb_and_keep_target_private() -> void:
	var state := _state()
	var plan: Array = IntentLogic.make_plan(state, "slime")
	eq(plan.size(), IntentLogic.PLAN_LENGTH, "plan spans the whole horizon")
	for entry: Dictionary in plan:
		ok(entry.has("verb"), "every entry exposes a public verb")
		ok(entry.has("target_id"), "every entry keeps its private planning context")
	eq(plan[0]["target_id"], "hero", "the plan is built around the nearest unit")


func test_future_verbs_serialize_only_verb_strings() -> void:
	var state := _state()
	var shown: Array = IntentLogic.future_verbs(IntentLogic.make_plan(state, "slime"))
	eq(shown, ["move", "move", "spit"], "future UI feed is the verb sequence")
	for v: Variant in shown:
		ok(v is String, "future UI serialization is verb strings only - no "
				+ "targets, destinations, or cells")


func test_ordinary_refill_preserves_telegraphed_verbs() -> void:
	var state := _state()
	var plan: Array = IntentLogic.make_plan(state, "slime")  # [move, move, spit]
	plan.pop_front()
	var shown_before: Array = IntentLogic.future_verbs(plan)  # [move, spit]
	# The enemy advanced meanwhile, so a fresh plan would differ - the two
	# already-telegraphed verbs must survive anyway.
	state["units"]["slime"]["cell"] = Vector2i(6, 2)
	plan = IntentLogic.refill_plan(state, "slime", plan)
	eq(plan.size(), IntentLogic.PLAN_LENGTH, "window refills to 3 verbs")
	eq(IntentLogic.future_verbs(plan).slice(0, 2), shown_before,
			"already-shown verbs remain trustworthy through ordinary refill")
	eq(IntentLogic.refill_plan(state, "slime", plan.duplicate(true)), plan,
			"refill of a full plan appends nothing")


func test_plan_rebuilds_when_target_dies() -> void:
	var state := _state()
	var plan: Array = IntentLogic.make_plan(state, "slime")
	not_ok(IntentLogic.plan_needs_rebuild(state, "slime", plan),
			"a fresh plan in an unchanged state stays valid")
	state["units"]["hero"]["hp"] = 0
	ok(IntentLogic.plan_needs_rebuild(state, "slime", plan),
			"a dead plan target invalidates the whole plan")
	var rebuilt: Array = IntentLogic.make_plan(state, "slime")
	eq(rebuilt[0]["target_id"], "friend", "the rebuild retargets from current state")
	eq(rebuilt, IntentLogic.make_plan(state, "slime"),
			"the rebuild is deterministic")


func test_plan_rebuilds_when_nearest_target_changes() -> void:
	var state := _state()
	var plan: Array = IntentLogic.make_plan(state, "slime")  # target: hero
	state["units"]["friend"]["cell"] = Vector2i(7, 2)  # friend is now nearest
	ok(IntentLogic.plan_needs_rebuild(state, "slime", plan),
			"a changed nearest target invalidates the plan")


func test_plan_rebuilds_when_head_verb_becomes_illegal() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(3, 2)  # adjacent -> [slam, ...]
	var plan: Array = IntentLogic.make_plan(state, "slime")
	not_ok(IntentLogic.plan_needs_rebuild(state, "slime", plan),
			"adjacent slam head is legal")
	state["units"]["slime"]["cell"] = Vector2i(8, 2)  # same target, slam now illegal
	ok(IntentLogic.plan_needs_rebuild(state, "slime", plan),
			"an illegal head verb invalidates the plan")


func test_empty_move_cannot_consume_a_round() -> void:
	var boxed := _state()
	for c: Vector2i in [Vector2i(7, 2), Vector2i(9, 2), Vector2i(8, 1), Vector2i(8, 3)]:
		boxed["blocked"][c] = true
	var stalled: Dictionary = IntentLogic.declare(boxed, "slime", "move")
	ok(stalled.get("invalid", false),
			"a zero-length move is invalid - never a silently consumed action")
	var near := _state()
	near["units"]["slime"]["cell"] = Vector2i(3, 2)  # already adjacent
	var noop: Dictionary = IntentLogic.declare(near, "slime", "move")
	ok(noop.get("invalid", false),
			"an already-adjacent move is invalid too (caller replans)")


## --- party round -------------------------------------------------------------

func test_party_ids_are_living_party_members_sorted() -> void:
	var state := _state()
	eq(IntentLogic.party_ids(state), ["friend", "hero"],
			"party ids are the party-side units, sorted")
	state["units"]["friend"]["hp"] = 0
	eq(IntentLogic.party_ids(state), ["hero"], "downed members drop out")


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


## --- guarded_cells (T-097 gray-box; T-093 absorbs it later) --------------------

func test_guard_cells_rotate_with_facing() -> void:
	var c := Vector2i(5, 5)
	eq(IntentLogic.guard_cells(c, Vector2i.UP),
			[Vector2i(5, 4), Vector2i(4, 4), Vector2i(6, 4)],
			"facing up: front, front-left, front-right")
	eq(IntentLogic.guard_cells(c, Vector2i.RIGHT),
			[Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 6)], "facing right rotates")
	eq(IntentLogic.guard_cells(c, Vector2i.DOWN),
			[Vector2i(5, 6), Vector2i(6, 6), Vector2i(4, 6)], "facing down rotates")
	eq(IntentLogic.guard_cells(c, Vector2i.LEFT),
			[Vector2i(4, 5), Vector2i(4, 6), Vector2i(4, 4)], "facing left rotates")


func test_guard_intercepts_line_before_allies_behind() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(5, 2)
	state["units"]["hero"]["cell"] = Vector2i(2, 2)    # in the line, farther back
	state["units"]["friend"]["cell"] = Vector2i(3, 3)  # south of the line
	var intent: Dictionary = IntentLogic.declare(state, "slime", "spit")
	eq(intent["cells"], [Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2)],
			"line locks toward the hero")
	IntentLogic.apply_guard(state, "friend", Vector2i.UP, 1)
	var shown: Array = IntentLogic.preview(state, intent)
	eq(shown.size(), 1, "preview reports exactly one blocked entry")
	if shown.size() == 1:
		eq(shown[0]["id"], "friend", "the guard owner reports the block")
		ok(shown[0].get("blocked", false), "the entry is a block, not a hit")
		eq(int(shown[0]["damage"]), 0, "a blocked line deals no damage")
	var results: Array = IntentLogic.resolve(state, intent)
	eq(results, shown, "GUARD PREVIEW EQUALS RESOLUTION - the D-026 contract")
	eq(state["units"]["hero"]["hp"], 20, "the ally behind the guard is untouched")
	eq(state["units"]["hero"]["statuses"].get("burn", 0), 0, "and takes no status")


func test_guard_protects_a_unit_standing_on_a_guarded_cell() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(5, 2)
	state["units"]["hero"]["cell"] = Vector2i(3, 2)    # standing inside the wall
	state["units"]["friend"]["cell"] = Vector2i(2, 3)  # guards from behind-left
	var intent: Dictionary = IntentLogic.declare(state, "slime", "spit")
	IntentLogic.apply_guard(state, "friend", Vector2i.UP, 1)  # covers (2,2)(1,2)(3,2)
	var results: Array = IntentLogic.resolve(state, intent)
	eq(results.size(), 1, "the line stops at the guarded cell")
	if results.size() == 1:
		eq(results[0]["id"], "friend", "reported as the guard's block")
		ok(results[0].get("blocked", false), "blocked, not a hit")
	eq(state["units"]["hero"]["hp"], 20,
			"a unit standing on a guarded cell is protected")


func test_guard_expires_after_exact_duration() -> void:
	var state := _state()
	state["units"]["slime"]["cell"] = Vector2i(5, 2)
	state["units"]["hero"]["cell"] = Vector2i(2, 2)
	state["units"]["friend"]["cell"] = Vector2i(3, 3)
	IntentLogic.apply_guard(state, "friend", Vector2i.UP, 2)
	var round1: Array = IntentLogic.resolve(state,
			IntentLogic.declare(state, "slime", "spit"))
	ok(round1.size() == 1 and round1[0].get("blocked", false), "round 1: blocked")
	IntentLogic.environment_tick(state)
	var round2: Array = IntentLogic.resolve(state,
			IntentLogic.declare(state, "slime", "spit"))
	ok(round2.size() == 1 and round2[0].get("blocked", false),
			"round 2: still blocked - duration is exact, not approximate")
	IntentLogic.environment_tick(state)
	var round3: Array = IntentLogic.resolve(state,
			IntentLogic.declare(state, "slime", "spit"))
	eq(round3.size(), 1, "round 3: the line goes through")
	if round3.size() == 1:
		eq(round3[0]["id"], "hero", "the hero takes the hit after expiry")
		not_ok(round3[0].get("blocked", false), "no stale guard lingers")


## --- Sol deployment-snapshot adapter seam (T-096/T-097) ------------------------

func test_sol_snapshot_adapter_maps_ids_to_cells() -> void:
	var snapshot := {
		"formation_id": "line",
		"leader_id": "hero",
		"facing": Vector2i.UP,
		"member_cells": {"hero": Vector2i(4, 4), "friend": Vector2i(4, 5)},
		"deployment_cells": {"friend": Vector2i(3, 4)},
	}
	var cells: Dictionary = SolAdapter.encounter_start_cells(
			snapshot, ["hero", "friend", "ghost"])
	eq(cells.get("hero"), Vector2i(4, 4), "member cell used when no deployment cell")
	eq(cells.get("friend"), Vector2i(3, 4), "deployment cell wins when present")
	not_ok(cells.has("ghost"), "ids missing from the snapshot are ignored")
	eq(SolAdapter.encounter_start_cells({}, ["hero"]), {},
			"an empty snapshot deploys nothing")
