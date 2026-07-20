extends "res://tests/gd_test.gd"
## S-013/TK-002 strict suite: finite no-grind reward accounting (D-028/D-043).
## Every finite source pays exactly once through the reward ledger, the
## unified victory path claims its stable source id, defeat under the v2
## default keeps XP (D-043 retires the 25% loss - finite XP cannot absorb a
## loss-based penalty), and the v1 fallback keeps its tuned penalty for the
## smoke-tested legacy route. The ledger rides the save schema.

const FIXTURE := "res://assets/levels/entity_test_room.ldtk"


func _fresh() -> void:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true


func test_reward_sources_pay_exactly_once() -> void:
	_fresh()
	ok(SceneManager.claim_reward_source("forest#enc_9_5"),
			"a fresh finite source claims")
	not_ok(SceneManager.claim_reward_source("forest#enc_9_5"),
			"the same source never claims twice (no grind, no double pay)")
	not_ok(SceneManager.claim_reward_source(""),
			"an empty source id is refused")
	ok(SceneManager.claim_reward_source("forest#enc_1_1"),
			"a different source still claims")
	_fresh()


func test_unified_victory_claims_its_stable_source() -> void:
	_fresh()
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	var xp_before: int = SceneManager.total_xp
	for enemy in room.enemies:
		if enemy.cell == Vector2i(9, 5):
			eq(room.begin_room_encounter(enemy), "", "encounter begins")
			eq(room.resolve_room_encounter(true), "", "victory resolves")
	ok(SceneManager.total_xp > xp_before, "victory paid once")
	var source := "%s#enc_9_5" % room.world_key()
	ok(SceneManager.state.reward_ledger.get(source, false),
			"the victory claimed its stable finite source id")
	not_ok(SceneManager.claim_reward_source(source),
			"the claimed source can never pay again")
	room.queue_free()
	_fresh()


func test_defeat_keeps_xp_under_the_v2_default() -> void:
	_fresh()
	SceneManager.state.party_xp = {"hero": 30, "companion_test": 30}
	eq(SceneManager.apply_defeat_xp_penalty(), 0,
			"D-043: defeat costs no XP under the finite economy")
	eq(int(SceneManager.state.party_xp["hero"]), 30, "hero XP untouched")
	_fresh()


func test_v1_fallback_keeps_the_tuned_penalty() -> void:
	_fresh()
	SceneManager.unified_encounters = false
	SceneManager.state.party_xp = {"hero": 30, "companion_test": 30}
	SceneManager.state.party_levels = {"hero": 1, "companion_test": 1}
	ok(SceneManager.apply_defeat_xp_penalty() > 0,
			"the v1 fallback keeps the D-014 penalty for the legacy route")
	_fresh()


func test_ledger_rides_the_save_schema() -> void:
	_fresh()
	SceneManager.claim_reward_source("k#enc")
	var captured := SaveManager.capture(SceneManager.state, "forest",
			Vector2i(2, 2))
	var rebuilt := SaveData.from_dict(JSON.parse_string(
			JSON.stringify(captured.to_dict())))
	not_null(rebuilt, "save round-trips")
	if rebuilt != null:
		var loaded: GameState = rebuilt.to_game_state()
		eq(loaded.reward_ledger.get("k#enc", false), true,
				"claimed sources survive save/load")
	var legacy := SaveData.from_dict({"schema_version": 1,
			"current_map": "forest"})
	if legacy != null:
		eq(legacy.to_game_state().reward_ledger, {},
				"legacy saves default to an empty ledger")
	_fresh()
