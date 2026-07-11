extends "res://tests/gd_test.gd"
## T-073/T-074: load the actual editable LDtk templates through the production
## loader, not a copied test grid or a parallel hand-written topology.

const IDS := [
	"forest_open_glade",
	"forest_sunlit_meadow",
	"forest_split_grove",
	"forest_winding_copse",
	"forest_crossroads",
	"forest_thorn_choke",
	"forest_old_growth_maze",
]


func _has_tile_map(root: Node) -> bool:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is TileMapLayer:
			return true
		for child in node.get_children():
			stack.append(child)
	return false


func _free_visual(arena: Dictionary) -> void:
	var visual := arena.get("visual") as Node2D
	if visual != null:
		visual.free()


func test_all_seven_shipped_ldtk_arenas_load_and_validate() -> void:
	ArenaLibrary.clear_cache()
	var registry := ArenaLibrary.registry()
	eq(registry.all().size(), 7, "library registers exactly the first forest pool")
	eq(ArenaSelector.ticket_count(registry.all()), 18,
			"production records retain the 5/2/1 weighted ticket total")
	for arena_id in IDS:
		var record := registry.resolve(arena_id)
		not_null(record, "%s record resolves" % arena_id)
		if record == null:
			continue
		var loaded := AuthoredArenaLoader.load_record(record, true)
		ok(bool(loaded.get("ok", false)), "%s LDtk level loads: %s"
				% [arena_id, str(loaded.get("error", ""))])
		if not bool(loaded.get("ok", false)):
			continue
		var board: Dictionary = loaded["arena"]
		eq(board["w"], 17, "%s board width" % arena_id)
		eq(board["h"], 7, "%s board height" % arena_id)
		eq(board["party_zone"].size(), 8, "%s has eight party deployment markers" % arena_id)
		eq(board["enemy_zone"].size(), 8, "%s has eight enemy deployment markers" % arena_id)
		ok(_has_tile_map(board["visual"]), "%s visual comes from imported TileMapLayer" % arena_id)
		eq(ArenaValidator.validate(board).size(), 0,
				"%s production board passes the shared validator" % arena_id)
		_free_visual(board)


func test_contact_side_orients_deployment_and_only_mirrors_safe_templates() -> void:
	var registry := ArenaLibrary.registry()
	var safe := registry.resolve("forest_open_glade")
	var unsafe := registry.resolve("forest_sunlit_meadow")
	var safe_left: Dictionary = AuthoredArenaLoader.load_record(safe, true)["arena"]
	var safe_right: Dictionary = AuthoredArenaLoader.load_record(safe, false)["arena"]
	eq(safe_left["party_zone"][0], Vector2i(1, 1), "left contact uses authored party side")
	eq(safe_right["party_zone"][0], Vector2i(15, 1), "right contact flips party side")
	ok(safe_right["mirrored"], "mirror-safe template flips its visual/topology")
	var unsafe_right: Dictionary = AuthoredArenaLoader.load_record(unsafe, false)["arena"]
	eq(unsafe_right["party_zone"][0], Vector2i(15, 1),
			"non-mirror-safe template still swaps deployment ownership")
	not_ok(unsafe_right["mirrored"], "non-mirror-safe topology is not flipped")
	_free_visual(safe_left)
	_free_visual(safe_right)
	_free_visual(unsafe_right)
