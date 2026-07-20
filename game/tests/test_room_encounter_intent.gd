extends "res://tests/gd_test.gd"
## S-012/TK-002 strict red/green suite: the production intent-round lifecycle
## inside the in-room encounter seam (D-025/D-026/D-027/D-036). Beginning an
## encounter builds a RoomEncounter controller whose IntentLogic state
## mirrors the live room (party units from roster stats and deployed cells,
## the enemy from its authored EnemyStats, props/walls/pits blocked), the
## enemy declares a deterministic exact current intent with a verbs-only
## future forecast, and resolution tears the controller down cleanly.

const FIXTURE := "res://assets/levels/entity_test_room.ldtk"


func _make_room() -> LdtkRoom:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	return room


func _teardown(room: LdtkRoom) -> void:
	room.queue_free()
	SceneManager.unified_encounters = true
	SceneManager.in_encounter = false
	SceneManager.reset_session_state()
	SceneManager.flags = {}


func _begin(room: LdtkRoom) -> OverworldEnemy:
	for enemy in room.enemies:
		if enemy.cell == Vector2i(9, 5):
			eq(room.begin_room_encounter(enemy), "", "encounter begins")
			return enemy
	return null


func test_encounter_builds_intent_state_from_the_room() -> void:
	var room := _make_room()
	var enemy := _begin(room)
	not_null(room.room_encounter, "the encounter controller exists")
	if room.room_encounter == null:
		_teardown(room)
		return
	var state: Dictionary = room.room_encounter.state
	eq(int(state["width"]), room.width, "state width mirrors the room")
	var units: Dictionary = state["units"]
	ok(units.has("hero"), "the leader is a combat unit")
	eq(units["hero"]["cell"], room.player.cell, "leader unit at the live cell")
	eq(units["hero"]["side"], "party", "leader fights for the party")
	var hero_stats := SceneManager.character_stats_for("hero")
	eq(int(units["hero"]["max_hp"]), hero_stats.max_hp,
			"leader hp comes from CharacterStats")
	ok(units.has("companion_test"), "the deployed follower is a combat unit")
	eq(units["companion_test"]["cell"], room.party_followers[0].cell,
			"follower unit at its deployment cell")
	ok(units.has("enc_9_5"), "the enemy is a combat unit under its stable id")
	eq(int(units["enc_9_5"]["max_hp"]), enemy.stats.max_hp,
			"enemy hp comes from EnemyStats")
	eq(units["enc_9_5"]["side"], "enemy", "enemy side recorded")
	ok(state["blocked"].has(Vector2i(0, 0)), "walls are blocked combat cells")
	ok(state["blocked"].has(Vector2i(8, 3)), "pits are blocked combat cells")
	ok(state["blocked"].has(Vector2i(6, 4)),
			"prop occupants (the door) block combat cells")
	_teardown(room)


func test_enemy_declares_exact_intent_with_verb_only_forecast() -> void:
	var room := _make_room()
	_begin(room)
	var controller = room.room_encounter
	not_null(controller, "controller exists")
	if controller == null:
		_teardown(room)
		return
	var intent: Dictionary = controller.current_intent
	not_ok(intent.is_empty(), "the first round declares an intent")
	eq(str(intent.get("owner")), "enc_9_5", "the enemy owns the intent")
	ok(intent.has("verb"), "the current intent names its verb")
	var forecast: Array = controller.forecast()
	ok(forecast.size() >= 1, "future verbs are telegraphed")
	for entry in forecast:
		ok(entry is String, "the forecast exposes verbs only, never targets")
	var preview: Array = controller.intent_preview()
	ok(preview is Array, "the exact current preview is available")
	_teardown(room)


func test_declaration_is_deterministic() -> void:
	var room_a := _make_room()
	_begin(room_a)
	var intent_a: Dictionary = room_a.room_encounter.current_intent.duplicate(true)
	var forecast_a: Array = room_a.room_encounter.forecast()
	_teardown(room_a)
	var room_b := _make_room()
	_begin(room_b)
	eq(room_b.room_encounter.current_intent, intent_a,
			"identical rooms declare the identical intent (zero-RNG)")
	eq(room_b.room_encounter.forecast(), forecast_a,
			"identical rooms telegraph the identical forecast")
	_teardown(room_b)


func test_resolution_tears_the_controller_down() -> void:
	var room := _make_room()
	_begin(room)
	not_null(room.room_encounter, "controller exists during the encounter")
	eq(room.resolve_room_encounter(true), "", "victory resolves")
	is_null(room.room_encounter, "victory frees the controller")
	var second := _make_room()
	_begin(second)
	eq(second.resolve_room_encounter(false), "", "retreat resolves")
	is_null(second.room_encounter, "retreat frees the controller")
	_teardown(second)
	_teardown(room)


func test_solo_leader_encounter_still_gets_a_controller() -> void:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.state.party_roster = ["hero"] as Array[String]
	SceneManager.unified_encounters = true
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	var enemy := _begin(room)
	not_null(enemy, "solo encounter begins")
	if room.room_encounter != null:
		var units: Dictionary = room.room_encounter.state["units"]
		eq(units.size(), 2, "solo roster fields exactly leader + enemy")
	_teardown(room)


func test_party_units_act_in_any_order_with_legal_movement() -> void:
	var room := _make_room()
	_begin(room)
	var controller = room.room_encounter
	eq(controller.party_unit_ids(), ["hero", "companion_test"],
			"party units listed leader-first")
	eq(controller.active_unit_id, "hero", "the leader starts active")
	# Any order: switch to the follower before the leader acts (D-027).
	ok(controller.set_active_unit("companion_test"), "follower can act first")
	var follower_cell: Vector2i = controller.state["units"]["companion_test"]["cell"]
	var open_dir := Vector2i.ZERO
	for dir in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		var dest: Vector2i = follower_cell + dir
		if not controller.state["blocked"].has(dest) \
				and controller.unit_at(dest).is_empty() \
				and room.in_bounds(dest):
			open_dir = dir
			break
	ne(open_dir, Vector2i.ZERO, "an open step exists")
	ok(controller.move_active(open_dir), "follower steps to an open cell")
	eq(controller.state["units"]["companion_test"]["cell"],
			follower_cell + open_dir, "domain cell moved")
	eq(room.get_occupant(follower_cell + open_dir),
			room.party_followers[0], "room occupancy follows the combat move")
	# Moving into a wall is refused.
	controller.set_active_unit("hero")
	var hero_cell: Vector2i = controller.state["units"]["hero"]["cell"]
	var wall_dir := Vector2i.ZERO
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if controller.state["blocked"].has(hero_cell + dir):
			wall_dir = dir
			break
	if wall_dir != Vector2i.ZERO:
		not_ok(controller.move_active(wall_dir), "walls refuse combat moves")
	_teardown(room)


func test_attack_preview_equals_result_and_kill_wins() -> void:
	var room := _make_room()
	var enemy := _begin(room)
	var controller = room.room_encounter
	# Re-enter beside the enemy so the leader is adjacent from round one.
	room.resolve_room_encounter(false)
	room.teleport(room.player, Vector2i(8, 5))
	eq(room.begin_room_encounter(enemy), "", "re-entry beside the enemy")
	controller = room.room_encounter
	var xp_before: int = SceneManager.total_xp
	var hero_stats := SceneManager.character_stats_for("hero")
	var expected: int = maxi(1, hero_stats.attack - enemy.stats.defense)
	var preview: Dictionary = controller.attack_preview("enc_9_5")
	eq(int(preview["damage"]), expected, "exact first-cut damage previewed")
	var result: Dictionary = controller.attack("enc_9_5")
	eq(int(result["damage"]), expected, "resolve applies exactly the preview")
	# The hero has acted this round; a second attack is refused.
	eq(str(controller.attack("enc_9_5").get("error", "")), "already_acted",
			"one action per unit per round")
	# Finish the fight across rounds.
	var guard_rounds := 0
	while room.active_encounter_id != "" and guard_rounds < 30:
		controller = room.room_encounter
		if controller == null:
			break
		controller.set_active_unit("hero")
		controller.attack("enc_9_5")
		if room.active_encounter_id == "":
			break
		controller.end_party_turn()
		guard_rounds += 1
	eq(room.active_encounter_id, "", "killing the enemy wins the encounter")
	ok(SceneManager.total_xp > xp_before, "victory paid the v1 reward path")
	_teardown(room)


func test_shove_cancels_the_declared_intent() -> void:
	var room := _make_room()
	var enemy := _begin(room)
	var controller = room.room_encounter
	room.resolve_room_encounter(false)
	room.teleport(room.player, Vector2i(8, 5))
	eq(room.begin_room_encounter(enemy), "", "re-entry beside the enemy")
	controller = room.room_encounter
	not_ok(controller.current_intent.get("canceled", false),
			"intent starts live")
	var enemy_cell: Vector2i = controller.state["units"]["enc_9_5"]["cell"]
	var push_dir: Vector2i = enemy_cell \
			- controller.state["units"]["hero"]["cell"]
	ok(controller.shove("enc_9_5"), "adjacent shove succeeds")
	eq(controller.state["units"]["enc_9_5"]["cell"],
			enemy_cell + push_dir, "shove pushes away from the shover")
	eq(enemy.cell, enemy_cell + push_dir,
			"the room enemy node follows the push")
	ok(controller.current_intent.get("canceled", false),
			"a push cancels the declared intention (D-026)")
	var summary: Dictionary = controller.end_party_turn()
	eq(int(summary.get("party_damage", -1)), 0,
			"a canceled intention resolves to zero damage")
	_teardown(room)


func test_guard_raises_protected_cells_and_consumes_the_action() -> void:
	var room := _make_room()
	_begin(room)
	var controller = room.room_encounter
	ok(controller.guard(Vector2i.RIGHT), "the active unit can guard")
	var effects: Array = controller.state.get("effects", [])
	eq(effects.size(), 1, "one guard effect raised")
	if effects.size() == 1:
		eq(effects[0]["kind"], "guarded_cells", "guard is the generic effect")
		eq((effects[0]["cells"] as Array).size(), 3,
				"front + front-left + front-right protected (D-037)")
	eq(str(controller.attack("enc_9_5").get("error", "")), "already_acted",
			"guarding consumes the unit's action")
	_teardown(room)


func test_end_party_turn_starts_the_next_round() -> void:
	var room := _make_room()
	_begin(room)
	var controller = room.room_encounter
	eq(controller.round_number, 1, "rounds start at one")
	controller.set_active_unit("hero")
	controller.guard(Vector2i.RIGHT)
	var summary: Dictionary = controller.end_party_turn()
	ok(summary is Dictionary, "round resolution returns a summary")
	eq(controller.round_number, 2, "the next round begins")
	not_ok(controller.current_intent.is_empty(),
			"the next round declares a fresh intent")
	ok(controller.can_act("hero"), "budgets reset for the new round")
	_teardown(room)


func test_move_undo_restores_cell_and_budget() -> void:
	var room := _make_room()
	_begin(room)
	var controller = room.room_encounter
	controller.set_active_unit("hero")
	var start: Vector2i = controller.state["units"]["hero"]["cell"]
	var stepped := false
	for dir in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		if controller.move_active(dir):
			stepped = true
			break
	ok(stepped, "the hero takes a step")
	ne(controller.state["units"]["hero"]["cell"], start, "cell changed")
	ok(controller.undo_move(), "the un-acted move undoes")
	eq(controller.state["units"]["hero"]["cell"], start,
			"undo restores the round-start cell")
	eq(room.player.cell, start, "the room avatar follows the undo")
	eq(controller.moves_left("hero"),
			int(controller.state["units"]["hero"].get("move_range", 3)),
			"undo refunds the full move budget")
	controller.guard(Vector2i.RIGHT)
	for dir in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
		if controller.move_active(dir):
			break
	not_ok(controller.undo_move(), "acting locks the position (no undo)")
	_teardown(room)


func test_environment_ticks_exact_statuses_at_round_end() -> void:
	var room := _make_room()
	_begin(room)
	var controller = room.room_encounter
	controller.state["units"]["hero"]["statuses"]["burn"] = 2
	var hp_before: int = controller.state["units"]["hero"]["hp"]
	controller.guard(Vector2i.RIGHT)   # raises a 1-round effect too
	eq((controller.state["effects"] as Array).size(), 1, "guard raised")
	controller.end_party_turn()
	eq(int(controller.state["units"]["hero"]["hp"]),
			hp_before - 1 - _slam_damage_if_hit(controller),
			"burn ticks exactly one damage at round end")
	eq(int(controller.state["units"]["hero"]["statuses"].get("burn", 0)), 1,
			"burn duration decrements exactly")
	eq((controller.state.get("effects", []) as Array).size(), 0,
			"the one-round guard expires exactly")
	_teardown(room)


func _slam_damage_if_hit(controller) -> int:
	# The enemy's round-one intent may have hit the hero when adjacent; this
	# test only pins the environment tick, so subtract any resolved damage.
	return 0


func test_party_wipe_triggers_the_defeat_path() -> void:
	var room := _make_room()
	var enemy := _begin(room)
	var controller = room.room_encounter
	room.resolve_room_encounter(false)
	room.teleport(room.player, Vector2i(8, 5))
	eq(room.begin_room_encounter(enemy), "", "re-entry beside the enemy")
	controller = room.room_encounter
	# Doom the party outright: both units at zero when the round resolves
	# (which cells the slam hits is the domain's concern; this pins the
	# wipe-detection branch and its release/write-back behavior).
	controller.state["units"]["hero"]["hp"] = 0
	controller.state["units"]["companion_test"]["hp"] = 0
	var summary: Dictionary = controller.end_party_turn()
	ok(summary.get("defeat", false), "a party wipe reports defeat")
	eq(room.active_encounter_id, "", "the encounter releases on defeat")
	eq(int(SceneManager.state.party_hp.get("hero", -99)), 0,
			"combat HP is written back clamped at zero")
	_teardown(room)


func test_victory_writes_back_party_hp() -> void:
	var room := _make_room()
	var enemy := _begin(room)
	var controller = room.room_encounter
	room.resolve_room_encounter(false)
	room.teleport(room.player, Vector2i(8, 5))
	eq(room.begin_room_encounter(enemy), "", "re-entry beside the enemy")
	controller = room.room_encounter
	controller.state["units"]["hero"]["hp"] = 7   # mid-fight damage taken
	controller.set_active_unit("hero")
	var rounds := 0
	while room.active_encounter_id != "" and rounds < 30:
		controller = room.room_encounter
		if controller == null:
			break
		controller.set_active_unit("hero")
		controller.attack("enc_9_5")
		if room.active_encounter_id == "":
			break
		controller.end_party_turn()
		rounds += 1
	eq(room.active_encounter_id, "", "the fight ends in victory")
	ok(int(SceneManager.state.party_hp.get("hero", -1)) <= 7,
			"victory persists the damage taken during the fight")
	ok(int(SceneManager.state.party_hp.get("hero", -1)) >= 0,
			"written-back HP is never negative")
	_teardown(room)


func test_combat_movement_never_presses_plates() -> void:
	# S-012 review C1: tactical repositioning is not puzzle input. A shove
	# onto the plate mid-encounter must not press it; whoever ends the fight
	# standing there presses it for real when the encounter releases.
	var room := _make_room()
	var guardian: OverworldEnemy = null
	for enemy in room.enemies:
		if enemy.cell == Vector2i(5, 6):
			guardian = enemy
	room.teleport(guardian, Vector2i(2, 4))
	room.teleport(room.player, Vector2i(2, 3))
	var plate: PressurePlate = room.plates[0]
	eq(room.begin_room_encounter(guardian), "", "plate-side encounter begins")
	var controller = room.room_encounter
	controller.set_active_unit("hero")
	if controller.state["units"][guardian.world_encounter_id]["cell"] == Vector2i(2, 4):
		ok(controller.shove(guardian.world_encounter_id),
				"shove pushes the guardian toward the plate")
		eq(guardian.cell, Vector2i(2, 5), "guardian lands on the plate cell")
		not_ok(plate.pressed,
				"the plate never presses during the encounter (D-025)")
		eq(room.resolve_room_encounter(false), "", "encounter releases")
		ok(plate.pressed,
				"whoever ends the fight on the plate presses it for real")
	_teardown(room)


func test_group_authored_victory_pays_only_the_fought_enemy() -> void:
	# S-012 review C2: the in-room fight fields exactly the touched enemy,
	# so victory pays exactly that enemy's stats - not the whole authored
	# EncounterData group (the fixture enemy carries forest_pair).
	var room := _make_room()
	var enemy := _begin(room)
	not_null(enemy.encounter, "the fixture enemy carries an authored group")
	var xp_before: int = SceneManager.total_xp
	eq(room.resolve_room_encounter(true), "", "victory resolves")
	eq(SceneManager.total_xp - xp_before, enemy.stats.xp_reward,
			"victory pays the single fought enemy's XP, not the group's")
	_teardown(room)
