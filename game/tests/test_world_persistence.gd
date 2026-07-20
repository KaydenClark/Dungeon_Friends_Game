extends "res://tests/gd_test.gd"
## S-003 strict suite: persistent world resolution (D-028 supersedes D-009's
## routine respawn; D-031 material truth survives). Resolved encounters and
## committed environmental state persist across in-process rebuilds and the
## save schema, wedged movables still reset, loading is fail-closed, and the
## world snapshot keeps reporting resolved encounters under their stable ids.
## The two-process disk proof lives in world_persistence_battery.tscn.

const WorldState := preload("res://scripts/world/world_state.gd")
const FIXTURE := "res://assets/levels/entity_test_room.ldtk"


func _make_room() -> LdtkRoom:
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	return room


func _fresh_session() -> void:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true


func _enemy_at(room: LdtkRoom, cell: Vector2i) -> OverworldEnemy:
	for enemy in room.enemies:
		if is_instance_valid(enemy) and enemy.cell == cell:
			return enemy
	return null


func test_resolution_and_environment_survive_rebuild() -> void:
	_fresh_session()
	var room := _make_room()
	var enemy := _enemy_at(room, Vector2i(9, 5))
	eq(room.begin_room_encounter(enemy), "", "encounter begins")
	eq(room.resolve_room_encounter(true), "", "victory resolves")
	var fire := AbilityData.new()
	fire.reaction_verb = "fire"
	eq(ReactionCaster.cast(room, fire, Vector2i(5, 1)).get("valid"), true,
			"vine burned")
	var block: PushableBlock = room.blocks[0]
	ok(block.try_push(Vector2i.LEFT), "block wedged")
	room.free()
	var rebuilt := _make_room()
	is_null(_enemy_at(rebuilt, Vector2i(9, 5)),
			"resolved encounter stays resolved on rebuild (D-028)")
	not_null(_enemy_at(rebuilt, Vector2i(5, 6)),
			"unresolved encounters still spawn")
	ok(rebuilt.material_state["cells"][Vector2i(5, 1)]["tags"].has("fire"),
			"the burn survives the rebuild")
	not_ok(rebuilt.material_state["cells"][Vector2i(5, 1)]["tags"].has("vine"),
			"the burned vine does not resurrect")
	eq(rebuilt.material_state["cells"][Vector2i(6, 1)]["tags"], ["flammable"],
			"untouched authored materials persist through the snapshot")
	eq(rebuilt.blocks[0].cell, Vector2i(3, 5),
			"the wedged block resets on rebuild (D-023 escape valve)")
	var data: Dictionary = WorldState.snapshot_ldtk_room(rebuilt)
	not_ok(data.has("error"), "rebuilt snapshot has no error")
	if not data.has("error"):
		eq(data["encounters"]["enc_9_5"]["status"], "resolved",
				"the snapshot reports the resolved identity")
	rebuilt.queue_free()
	_fresh_session()


func test_persisted_material_loading_fails_closed() -> void:
	_fresh_session()
	var probe := _make_room()
	var key := probe.world_key()
	probe.free()
	SceneManager.state.world_materials[key] = {"not-a-cell": 5}
	var room := _make_room()
	eq(room.material_state["cells"][Vector2i(5, 1)]["tags"], ["vine"],
			"malformed persisted state is ignored; authored state stands")
	room.free()
	SceneManager.state.world_materials[key] = {"99,99": {"tags": ["fire"],
			"statuses": {}}}
	var out_of_bounds := _make_room()
	eq(out_of_bounds.material_state["cells"][Vector2i(5, 1)]["tags"],
			["vine"], "out-of-bounds persisted cells are refused wholesale")
	out_of_bounds.queue_free()
	_fresh_session()


func test_save_schema_round_trips_world_state() -> void:
	_fresh_session()
	SceneManager.state.resolved_encounters = {"k#": {"enc_9_5": true}}
	SceneManager.state.world_materials = {"k#": {"5,1": {"tags": ["fire"],
			"statuses": {}}}}
	var captured := SaveManager.capture(SceneManager.state, "forest",
			Vector2i(2, 2))
	var rebuilt := SaveData.from_dict(JSON.parse_string(
			JSON.stringify(captured.to_dict())))
	not_null(rebuilt, "save survives a real JSON round trip")
	if rebuilt != null:
		var loaded: GameState = rebuilt.to_game_state()
		eq(loaded.resolved_encounters.get("k#", {}).get("enc_9_5", false),
				true, "resolved encounters survive save/load")
		eq(loaded.world_materials.get("k#", {}).get("5,1", {}).get("tags"),
				["fire"], "material truth survives save/load")
	var legacy := SaveData.from_dict({"schema_version": 1,
			"current_map": "forest"})
	not_null(legacy, "legacy saves still load")
	if legacy != null:
		eq(legacy.to_game_state().resolved_encounters, {},
				"legacy saves default to no resolved encounters")
	_fresh_session()
