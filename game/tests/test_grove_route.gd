extends "res://tests/gd_test.gd"
## S-004/TK-002 tracer suite: the Withered Grove route (D-044 contract,
## docs/planning/S004_THESIS_ROUTE.md). Covers every thesis beat at the seam
## level: registry/authoring, Wren's recruit-on-dialogue, Moss's watched-cell
## non-combat resolution, the vine gate, grove_guardian victory regrowth, and
## the full save round trip. The windowed under-one-minute demo is TK-003.

const FIXTURE := "res://assets/levels/grove.ldtk"
const GROW := preload("res://data/abilities/verdant_growth.tres")
const BED := Vector2i(7, 7)       # Moss's watched herb-bed cell
const TRELLIS := Vector2i(9, 4)   # the vine gate's authored trellis cell
const GATE := Vector2i(10, 5)     # the gate's own cell


func _fresh() -> void:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true


func _grove() -> GroveRoom:
	var room := GroveRoom.new()
	add_child(room)
	return room


func _npc_with_recruit(room: GroveRoom, id: String) -> NPC:
	for n in room.npcs:
		if n.recruit_id == id:
			return n
	return null


func _npc_watching(room: GroveRoom, cell: Vector2i) -> NPC:
	for n in room.npcs:
		if n.watch_cell == cell:
			return n
	return null


func test_registry_builds_the_grove() -> void:
	_fresh()
	var room := MapRegistry.build("withered_grove")
	not_null(room, "MapRegistry knows withered_grove")
	if room == null:
		return
	ok(room is GroveRoom, "the id builds a GroveRoom")
	add_child(room)
	eq(MapRegistry.id_for(room), "withered_grove", "id round-trips")
	room.queue_free()
	_fresh()


func test_grove_authors_cleanly() -> void:
	_fresh()
	var room := _grove()
	eq(room.authoring_errors, [], "no authoring errors")
	eq(room.npcs.size(), 2, "Wren and Moss stand in the grove")
	eq(room.enemies.size(), 1, "one grove guardian")
	ok(room.authored_encounters.has("grove_guardian"),
			"the guardian carries its authored identity")
	ok(room.doorways.has(Vector2i(1, 5)), "the way back to the forest exists")
	room.queue_free()
	_fresh()


func test_forest_south_doorway_targets_the_grove() -> void:
	_fresh()
	var forest := ForestRoom.new()
	add_child(forest)
	var found := false
	for cell in forest.doorways:
		if str(forest.doorways[cell].get("TargetRoom", "")) == "withered_grove":
			found = true
	ok(found, "the forest's south doorway leads to the grove")
	forest.queue_free()
	_fresh()


func test_wren_recruits_on_dialogue_and_despawns() -> void:
	_fresh()
	var room := _grove()
	var wren := _npc_with_recruit(room, "wren")
	not_null(wren, "Wren stands in the grove with her RecruitId")
	if wren == null:
		room.queue_free()
		_fresh()
		return
	eq(SceneManager.state.party_roster, ["hero", "companion_test"],
			"baseline roster before her dialogue")
	await wren.interact()
	eq(SceneManager.state.party_roster, ["hero", "companion_test", "wren"],
			"her dialogue ends with her joining the expedition")
	ok(not is_instance_valid(wren) or wren.is_queued_for_deletion(),
			"her NPC actor leaves the board")
	room.queue_free()
	await get_tree().process_frame
	var again := _grove()
	eq(_npc_with_recruit(again, "wren"), null,
			"a recruited Wren never re-spawns on rebuild")
	again.queue_free()
	_fresh()


func test_unknown_recruit_id_fails_closed() -> void:
	_fresh()
	var room := _grove()
	var npc := NPC.new()
	npc.room = room
	npc.cell = Vector2i(3, 3)
	npc.lines = PackedStringArray(["hello"])
	npc.recruit_id = "nobody_real"
	add_child(npc)
	var roster_before: Array = SceneManager.state.party_roster.duplicate()
	await npc.interact()
	eq(SceneManager.state.party_roster, roster_before,
			"an unknown recruit id recruits nobody")
	ok(is_instance_valid(npc) and not npc.is_queued_for_deletion(),
			"the NPC stays a plain talker")
	npc.queue_free()
	room.queue_free()
	_fresh()


func test_moss_swaps_lines_when_the_bed_grows() -> void:
	_fresh()
	var room := _grove()
	var moss := _npc_watching(room, BED)
	not_null(moss, "Moss watches his herb-bed cell")
	if moss == null:
		room.queue_free()
		_fresh()
		return
	var problem_lines := moss.lines
	ok(not moss.resolved_lines.is_empty(), "his gratitude lines are authored")
	ok(problem_lines != moss.resolved_lines, "problem and gratitude differ")
	var result: Dictionary = ReactionCaster.cast(room, GROW, BED)
	eq(result.get("valid"), true, "grow answers the bed cell")
	eq(moss.lines, moss.resolved_lines,
			"his dialogue flips to gratitude - no combat involved")
	eq(SceneManager.flags.get("grove_herbs_grown", false), true,
			"the resolution flag is recorded")
	room.queue_free()
	_fresh()


func test_moss_resolution_survives_rebuild() -> void:
	_fresh()
	var room := _grove()
	ReactionCaster.cast(room, GROW, BED)
	room.queue_free()
	await get_tree().process_frame
	var again := _grove()
	var moss := _npc_watching(again, BED)
	not_null(moss, "Moss still stands after the rebuild")
	if moss != null:
		eq(moss.lines, moss.resolved_lines,
				"the persisted vine keeps his gratitude lines")
	again.queue_free()
	_fresh()


func test_vine_gate_blocks_then_opens_on_trellis_growth() -> void:
	_fresh()
	var room := _grove()
	eq(room.vine_gates.size(), 1, "one vine gate bars the inner grove")
	ok(room.blocked.has(GATE), "the closed gate blocks like a wall")
	var result: Dictionary = ReactionCaster.cast(room, GROW, TRELLIS)
	eq(result.get("valid"), true, "grow answers the trellis cell")
	ok(not room.blocked.has(GATE), "a grown trellis opens the gate")
	room.queue_free()
	await get_tree().process_frame
	var again := _grove()
	ok(not again.blocked.has(GATE),
			"the opened gate stays open on rebuild (persisted vine)")
	again.queue_free()
	_fresh()


func test_vine_gate_bad_authoring_fails_closed() -> void:
	_fresh()
	var room := _grove()
	eq(VineGate.authoring_error(Vector2i(-1, -1), room.width, room.height),
			"vine_gate_trellis_out_of_bounds",
			"an out-of-bounds trellis is a named authoring error")
	eq(VineGate.authoring_error(TRELLIS, room.width, room.height), "",
			"the authored trellis validates clean")
	room.queue_free()
	_fresh()


func test_grove_guardian_victory_regrows_the_heart() -> void:
	_fresh()
	var room := _grove()
	var guardian: OverworldEnemy = room.enemies[0]
	eq(room.begin_room_encounter(guardian), "", "the bump enters the fight")
	eq(room.resolve_room_encounter(true), "", "victory resolves in-room")
	for cell in GroveRoom.HEART_CELLS:
		ok(room.material_state["cells"][cell]["tags"].has("vine"),
				"heart cell %s regrows" % cell)
	eq(SceneManager.flags.get("grove_restored", false), true,
			"the grove-restored flag is recorded")
	ok(SceneManager.state.resolved_encounters.get(room.world_key(),
			{}).get("grove_guardian", false), "the fight stays resolved")
	room.queue_free()
	await get_tree().process_frame
	var again := _grove()
	eq(again.enemies.size(), 0, "the resolved guardian never respawns")
	for cell in GroveRoom.HEART_CELLS:
		ok(again.material_state["cells"][cell]["tags"].has("vine"),
				"heart cell %s stays green on rebuild" % cell)
	again.queue_free()
	_fresh()


func test_full_tracer_save_round_trip() -> void:
	_fresh()
	var room := _grove()
	var wren := _npc_with_recruit(room, "wren")
	if wren != null:
		await wren.interact()
	ReactionCaster.cast(room, GROW, BED)
	ReactionCaster.cast(room, GROW, TRELLIS)
	room.begin_room_encounter(room.enemies[0])
	room.resolve_room_encounter(true)
	var key := room.world_key()
	var captured := SaveManager.capture(SceneManager.state, "withered_grove",
			Vector2i(2, 5))
	var rebuilt := SaveData.from_dict(captured.to_dict())
	not_null(rebuilt, "the save round-trips through JSON")
	if rebuilt == null:
		room.queue_free()
		_fresh()
		return
	var loaded := rebuilt.to_game_state()
	ok(loaded.party_roster.has("wren"), "Wren survives save/load")
	ok(loaded.resolved_encounters.get(key, {}).get("grove_guardian", false),
			"the resolved fight survives save/load")
	var materials: Dictionary = loaded.world_materials.get(key, {})
	for cell in [BED, TRELLIS]:
		ok(materials.get("%d,%d" % [cell.x, cell.y], {}).get("tags",
				[]).has("vine"), "vine at %s survives save/load" % cell)
	eq(rebuilt.to_game_state().flags.get("grove_restored", false), true,
			"the grove-restored flag survives save/load")
	room.queue_free()
	_fresh()
