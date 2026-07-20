extends "res://tests/gd_test.gd"
## Unit tests for MapRegistry (T-038). The contract: one place maps stable
## map ids to room factories; every registered id actually builds its room
## headless; id_for() reverses a live room back to its id (what a save file
## stores); unknown ids/rooms answer null/"" instead of crashing. The load
## flow (T-040), dev warps (T-049), and SaveData.current_map all resolve
## through this.


func test_ids_are_the_built_rooms() -> void:
	# S-004/TK-002 added the Withered Grove (D-044 thesis route).
	eq(MapRegistry.ids(), ["forest", "withered_grove", "tutorial_hub",
			"tutorial_chest", "tutorial_pit", "tutorial_fight"],
			"registry lists the built rooms in stable order")


func test_every_registered_id_builds_its_room() -> void:
	for id in MapRegistry.ids():
		SceneManager.flags = {}
		var room := MapRegistry.build(id)
		not_null(room, "%s builds a room" % id)
		if room == null:
			continue
		add_child(room)   # _ready runs the full LDtk build
		ok(room is LdtkRoom, "%s is an LdtkRoom" % id)
		ok(room.width > 0 and room.height > 0, "%s built a real grid" % id)
		not_null(room.player, "%s spawned a player" % id)
		room.free()
	SceneManager.flags = {}


func test_id_for_reverses_a_live_room() -> void:
	for id in MapRegistry.ids():
		SceneManager.flags = {}
		var room := MapRegistry.build(id)
		eq(MapRegistry.id_for(room), id, "id_for round-trips %s" % id)
		room.free()
	SceneManager.flags = {}


func test_unknowns_never_crash() -> void:
	is_null(MapRegistry.build("no_such_map"), "unknown id builds null")
	var stranger := Node2D.new()
	eq(MapRegistry.id_for(stranger), "", "foreign node has no id")
	stranger.free()
	eq(MapRegistry.id_for(null), "", "null room has no id")


func test_labels_exist_for_the_warp_menu() -> void:
	for id in MapRegistry.ids():
		ne(MapRegistry.label(id), "", "%s has a human label" % id)
