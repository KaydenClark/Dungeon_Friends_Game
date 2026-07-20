extends Node
## S-009/TK-002 demo probe: builds the LDtk authoring fixture room and prints
## its neutral WorldState snapshot - authored elevation, materials, stable
## encounter identities, and the fail-closed check on the bad fixture - as a
## one-command, under-a-minute review artifact. Exits 1 on any FAIL line.
##
##   cd game
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##     scenes/dev/world_snapshot_probe.tscn

const WorldState := preload("res://scripts/world/world_state.gd")

var _failed := false


func _ready() -> void:
	print("WORLD SNAPSHOT PROBE: begin")
	SceneManager.flags = {}
	await _probe_good_fixture()
	await _probe_bad_fixture()
	SceneManager.flags = {}
	print("WORLD SNAPSHOT PROBE: %s" % ("FAIL" if _failed else "done"))
	get_tree().quit(1 if _failed else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: %s" % label)
	else:
		_failed = true
		print("FAIL: %s" % label)


func _probe_good_fixture() -> void:
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)
	await get_tree().process_frame
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	_check(not data.has("error"), "fixture room snapshots without error")
	if data.has("error"):
		room.queue_free()
		return
	_check(WorldState.validate(data) == "", "snapshot validates")
	print("  room: %dx%d, %d contract cells" % [int(data["width"]),
			int(data["height"]), data["cells"].size()])
	var elevated := []
	var tagged := []
	for cell in data["cells"]:
		if int(data["cells"][cell]["elevation"]) > 0:
			elevated.append("%s=%d" % [cell, data["cells"][cell]["elevation"]])
		if not data["cells"][cell]["tags"].is_empty():
			tagged.append("%s=%s" % [cell, data["cells"][cell]["tags"]])
	print("  authored elevation: %s" % ", ".join(elevated))
	print("  authored materials: %s" % ", ".join(tagged))
	print("  party: leader=%s members=%s" % [data["party"]["leader"],
			data["party"]["members"]])
	for id in data["encounters"]:
		print("  encounter %s: %s at %s" % [id,
				data["encounters"][id]["status"],
				data["encounters"][id]["cells"]])
	_check(elevated.size() == 2, "two authored elevation cells")
	_check(tagged.size() == 4, "four authored material cells")
	_check(data["encounters"].size() == 2, "two stable encounters")
	# Defeat one enemy: its encounter resolves in place, identity kept.
	for enemy in room.enemies.duplicate():
		if enemy.world_encounter_id == "enc_9_5":
			enemy.defeated()
	var after: Dictionary = WorldState.snapshot_ldtk_room(room)
	_check(not after.has("error"), "snapshot after defeat has no error")
	if not after.has("error"):
		print("  after defeat: encounter enc_9_5 -> %s at %s"
				% [after["encounters"]["enc_9_5"]["status"],
				after["encounters"]["enc_9_5"]["cells"]])
		_check(after["encounters"]["enc_9_5"]["status"] == "resolved",
				"defeated encounter resolved under its stable id")
	room.queue_free()


func _probe_bad_fixture() -> void:
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_bad_authoring_room.ldtk"
	add_child(room)
	await get_tree().process_frame
	print("  bad fixture authoring_errors: %s" % [room.authoring_errors])
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	_check(data.has("error"), "bad-authored room is refused (fail closed)")
	if data.has("error"):
		print("  adapter error: %s" % data["error"])
	_check(room.elevation.is_empty() and room.materials.is_empty(),
			"no partial authoring adopted")
	_check(room.enemies.size() == 2, "v1 room build still works")
	room.queue_free()
