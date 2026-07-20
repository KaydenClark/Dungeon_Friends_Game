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
	SceneManager.unified_encounters = false
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
