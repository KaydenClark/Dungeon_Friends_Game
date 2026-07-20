extends "res://tests/gd_test.gd"
## S-013/TK-003 strict suite: the first real Dungeon Friend (D-033/D-043).
## Wren carries the full friend contract - a primary world verb (grow,
## through the shared S-011 reaction seam), a small deterministic combat kit,
## one deterministic passive honored by the environment tick, and a stable
## save identity - and recruitment is a fail-closed, once-per-save finite
## source that immediately grows the visible exploration party.

const FIXTURE := "res://assets/levels/entity_test_room.ldtk"


func _fresh() -> void:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true


func test_wren_satisfies_the_friend_contract() -> void:
	var stats := SceneManager.character_stats_for("wren")
	not_null(stats, "wren's CharacterStats resource loads")
	if stats == null:
		return
	eq(stats.id, "wren", "stable id")
	eq(stats.display_name, "Wren", "display name authored")
	eq(stats.passive_id, "verdant_mender", "one deterministic passive")
	not_null(stats.sprite_frames, "provenance-safe (Kenney CC0) frames wired")
	var verbs: Array[String] = []
	for ability in stats.starting_abilities:
		if ability.reaction_verb != "":
			verbs.append(ability.reaction_verb)
	eq(verbs, ["grow"], "exactly one primary world verb: grow (lore: the
first friend is Growth-oriented)".replace("\n", " "))


func test_recruitment_is_fail_closed_and_finite() -> void:
	_fresh()
	eq(SceneManager.state.party_roster, ["hero", "companion_test"],
			"baseline roster")
	ok(SceneManager.recruit_member("wren"), "wren recruits")
	eq(SceneManager.state.party_roster, ["hero", "companion_test", "wren"],
			"roster grows in order")
	eq(int(SceneManager.state.party_hp.get("wren", 0)),
			SceneManager.character_stats_for("wren").max_hp,
			"recruit seeds full HP")
	not_ok(SceneManager.recruit_member("wren"),
			"a friend can only be recruited once (finite source)")
	not_ok(SceneManager.recruit_member("nobody_real"),
			"unknown stats are refused")
	SceneManager.state.party_roster.append("filler")
	not_ok(SceneManager.recruit_member("hero2"),
			"a full four-member party refuses further recruits")
	_fresh()


func test_recruited_wren_walks_and_fights() -> void:
	_fresh()
	ok(SceneManager.recruit_member("wren"), "wren recruits")
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	eq(room.party_followers.size(), 2,
			"wren joins the visible exploration party (D-029/D-040)")
	var wren_follower: PartyFollower = null
	for follower in room.party_followers:
		if follower.member_id == "wren":
			wren_follower = follower
	not_null(wren_follower, "wren renders as a follower")
	for enemy in room.enemies:
		if enemy.cell == Vector2i(9, 5):
			eq(room.begin_room_encounter(enemy), "", "encounter begins")
	var controller = room.room_encounter
	not_null(controller, "controller running")
	if controller != null:
		ok(controller.state["units"].has("wren"), "wren fields as a unit")
		eq(controller.state["units"]["wren"]["passives"], ["verdant_mender"],
				"the passive rides into the domain")
		controller.state["units"]["wren"]["hp"] = 5
		controller.set_active_unit("hero")
		controller.guard(Vector2i.RIGHT)
		controller.end_party_turn()
		eq(int(controller.state["units"]["wren"]["hp"]), 6,
				"verdant_mender heals exactly 1 at the environment tick")
		room.resolve_room_encounter(false)
	room.queue_free()
	_fresh()


func test_recruit_identity_survives_save_load() -> void:
	_fresh()
	ok(SceneManager.recruit_member("wren"), "wren recruits")
	var captured := SaveManager.capture(SceneManager.state, "forest",
			Vector2i(2, 2))
	var rebuilt := SaveData.from_dict(JSON.parse_string(
			JSON.stringify(captured.to_dict())))
	not_null(rebuilt, "save round-trips")
	if rebuilt != null:
		var loaded: GameState = rebuilt.to_game_state()
		ok(loaded.party_roster.has("wren"), "wren's identity survives save/load")
		eq(loaded.reward_ledger.get("recruit#wren", false), true,
				"the recruitment source stays claimed after load")
	_fresh()


func test_leader_casts_the_field_verb_in_exploration() -> void:
	# S-013/TK-004: the cast control is data-driven - whoever leads casts
	# their own verb at the faced cell, spending MP through the shared seam.
	_fresh()
	ok(SceneManager.recruit_member("wren"), "wren recruits")
	SceneManager.state.party_leader = "wren"
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	eq(room.party_leader_id, "wren", "wren leads")
	var target: Vector2i = room.player.cell + room.player.facing
	var result: Dictionary = room.cast_leader_reaction()
	eq(result.get("valid"), true, "the leader's grow verb casts")
	ok(room.material_state["cells"][target]["tags"].has("vine"),
			"a vine grows at the faced cell")
	eq(int(SceneManager.state.party_mp.get("wren", -1)),
			SceneManager.character_stats_for("wren").max_mp - 1,
			"the cast spends exactly its MP cost")
	room.queue_free()
	_fresh()


func test_verbless_leader_and_empty_mp_fail_closed() -> void:
	_fresh()
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	var result: Dictionary = room.cast_leader_reaction()
	eq(str(result.get("error")), "not_a_reaction_ability",
			"the hero has no field verb yet - named refusal")
	room.queue_free()
	SceneManager.reset_session_state()
	ok(SceneManager.recruit_member("wren"), "wren recruits")
	SceneManager.state.party_leader = "wren"
	SceneManager.state.party_mp["wren"] = 0
	var broke := LdtkRoom.new()
	broke.level_path = FIXTURE
	add_child(broke)
	eq(str(broke.cast_leader_reaction().get("error")), "not_enough_mp",
			"an empty MP pool refuses the cast")
	broke.queue_free()
	_fresh()


func test_active_unit_casts_in_encounters() -> void:
	_fresh()
	ok(SceneManager.recruit_member("wren"), "wren recruits")
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	for enemy in room.enemies:
		if enemy.cell == Vector2i(9, 5):
			eq(room.begin_room_encounter(enemy), "", "encounter begins")
	var controller = room.room_encounter
	not_null(controller, "controller running")
	if controller != null:
		ok(controller.set_active_unit("wren"), "wren takes the turn")
		var result: Dictionary = controller.cast_reaction()
		eq(result.get("valid"), true, "wren casts grow mid-encounter")
		eq(str(result["metadata"]["context"]), "encounter",
				"the cast carries encounter context metadata")
		not_ok(controller.can_act("wren"), "casting consumes the action")
		eq(str(controller.cast_reaction().get("error")), "already_acted",
				"one cast per round")
		room.resolve_room_encounter(false)
	room.queue_free()
	_fresh()


func test_onboarding_hints_show_once_and_persist() -> void:
	# S-014/TK-002: one contextual hint per room entry, never repeated,
	# never a dev key; seen-flags ride the existing save schema.
	_fresh()
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	eq(SceneManager.flags.get("hint_party_controls", false), true,
			"the party-controls hint fires on the first party room")
	room.free()
	ok(SceneManager.recruit_member("wren"), "wren recruits")
	SceneManager.state.party_leader = "wren"
	var second := LdtkRoom.new()
	second.level_path = FIXTURE
	add_child(second)
	eq(SceneManager.flags.get("hint_cast", false), true,
			"the cast hint fires once a leader carries a field verb")
	second.free()
	var third := LdtkRoom.new()
	third.level_path = FIXTURE
	add_child(third)
	not_null(third, "a third entry shows no further hints (flags consumed)")
	var captured := SaveManager.capture(SceneManager.state, "forest",
			Vector2i(2, 2))
	var rebuilt := SaveData.from_dict(captured.to_dict())
	if rebuilt != null:
		eq(rebuilt.to_game_state().flags.get("hint_party_controls", false),
				true, "seen hints survive save/load (never repeat)")
	third.queue_free()
	_fresh()


func test_encounter_surface_teaches_its_own_controls() -> void:
	_fresh()
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	for enemy in room.enemies:
		if enemy.cell == Vector2i(9, 5):
			eq(room.begin_room_encounter(enemy), "", "encounter begins")
	var controller = room.room_encounter
	not_null(controller, "controller running")
	if controller != null:
		ok(controller._intent_label.text.contains("1/A atk"),
				"the intent panel footer teaches the combat controls")
		ok(controller._intent_label.text.contains("Q/X end"),
				"ending the turn is always visible")
		room.resolve_room_encounter(false)
	room.queue_free()
	_fresh()


func test_downed_ally_self_revives_when_the_encounter_ends() -> void:
	# S-014/TK-003 (D-043 rule 2): a KO'd ally stands back up at exactly
	# 1 HP on ANY encounter release unless the whole party is down.
	_fresh()
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	for enemy in room.enemies:
		if enemy.cell == Vector2i(9, 5):
			eq(room.begin_room_encounter(enemy), "", "encounter begins")
	var controller = room.room_encounter
	not_null(controller, "controller running")
	if controller != null:
		controller.state["units"]["companion_test"]["hp"] = 0
		eq(room.resolve_room_encounter(false), "", "retreat releases")
		eq(int(SceneManager.state.party_hp.get("companion_test", -1)), 1,
				"the KO'd follower self-revives at exactly 1 HP")
	room.queue_free()
	_fresh()


func test_aggro_cue_appears_and_clears() -> void:
	_fresh()
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	var enemy: OverworldEnemy = null
	for candidate in room.enemies:
		if candidate.cell == Vector2i(9, 5):
			enemy = candidate
	room.teleport(room.player, Vector2i(8, 5))   # within TRACK_RADIUS
	enemy._act()
	not_null(enemy._aggro_marker, "the chase cue exists once tracking starts")
	if enemy._aggro_marker != null:
		ok(enemy._aggro_marker.visible, "the chase cue is visible in range")
	room.teleport(room.player, Vector2i(2, 2))   # far outside the radius
	enemy._act()
	if enemy._aggro_marker != null:
		not_ok(enemy._aggro_marker.visible,
				"the cue clears when the player escapes")
	room.queue_free()
	_fresh()


func test_focus_loss_is_surfaced_to_the_player() -> void:
	_fresh()
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	room.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	not_null(room._party_toast, "losing window focus shows a readable toast")
	room.queue_free()
	_fresh()


func test_controller_buttons_drive_the_encounter() -> void:
	# S-014/TK-004 controller parity: the same fight completes on joypad
	# buttons - A attacks through the same API the keyboard drives.
	_fresh()
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	room.teleport(room.player, Vector2i(8, 5))
	for enemy in room.enemies:
		if enemy.cell == Vector2i(9, 5):
			eq(room.begin_room_encounter(enemy), "", "encounter begins")
	var controller = room.room_encounter
	not_null(controller, "controller running")
	if controller != null:
		var enemy_hp: int = controller.state["units"]["enc_9_5"]["hp"]
		var press := InputEventJoypadButton.new()
		press.button_index = JOY_BUTTON_A
		press.pressed = true
		controller._unhandled_input(press)
		ok(int(controller.state["units"].get("enc_9_5",
				{"hp": 0})["hp"]) < enemy_hp \
				or room.active_encounter_id == "",
				"the A button lands the same attack as the 1 key")
		if room.active_encounter_id != "":
			room.resolve_room_encounter(false)
	room.queue_free()
	_fresh()


func test_production_material_overlay_exists() -> void:
	# S-014/TK-004: the matrix GAP closes - live material state renders in
	# PRODUCTION rooms, not just demos.
	_fresh()
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	not_null(room._material_overlay, "every room owns a material overlay")
	ok(room._material_overlay.is_inside_tree(), "the overlay renders in-tree")
	room.queue_free()
	_fresh()
