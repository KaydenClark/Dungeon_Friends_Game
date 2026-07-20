extends Node
## S-003 two-process world-persistence battery (TK-001). Proves DISK
## persistence of the v2 resolved world - not one-process memory:
##
##   save phase: resolve the fixture encounter through the unified seam, burn
##   the authored vine through the reaction seam, wedge the pushable block,
##   rebuild the room in-process (resolved encounter stays resolved, burn
##   stays burned, the wedged block still resets - the D-023 escape valve
##   survives D-028), then write slot 1 into a scratch dir.
##
##   load phase: a fresh process loads the slot, rebuilds the room, and the
##   resolved encounter and environmental state are still there while the
##   movable block is reset.
##
## Run (both must exit 0):
##   cd game
##   Godot --headless --path . scenes/dev/world_persistence_battery.tscn -- --phase=save
##   Godot --headless --path . scenes/dev/world_persistence_battery.tscn -- --phase=load

const FIXTURE := "res://assets/levels/entity_test_room.ldtk"
const SAVE_DIR := "user://saves_world_battery"

var _passed := 0
var _failed := 0


func check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("CHECK FAILED: ", label)


func _ready() -> void:
	var phase := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	match phase:
		"save":
			_run_save()
		"load":
			_run_load()
		_:
			print("WORLD PERSISTENCE BATTERY: unknown phase '%s'" % phase)
			get_tree().quit(1)


func _build_room() -> LdtkRoom:
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	return room


func _enemy_at(room: LdtkRoom, cell: Vector2i) -> OverworldEnemy:
	for enemy in room.enemies:
		if is_instance_valid(enemy) and enemy.cell == cell:
			return enemy
	return null


func _finish(phase: String) -> void:
	var total := _passed + _failed
	if _failed == 0:
		print("WORLD PERSISTENCE BATTERY %s PHASE: PASS (%d/%d checks)"
				% [phase.to_upper(), _passed, total])
		get_tree().quit(0)
	else:
		print("WORLD PERSISTENCE BATTERY %s PHASE: FAIL (%d/%d checks)"
				% [phase.to_upper(), _passed, total])
		get_tree().quit(1)


func _run_save() -> void:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	var room := _build_room()
	await get_tree().process_frame
	# 1. Resolve the encounter through the real seam.
	var enemy := _enemy_at(room, Vector2i(9, 5))
	check(enemy != null, "fixture enemy present")
	if enemy != null:
		check(room.begin_room_encounter(enemy) == "", "encounter begins")
		check(room.resolve_room_encounter(true) == "", "victory resolves")
	check(_enemy_at(room, Vector2i(9, 5)) == null, "enemy defeated in place")
	# 2. Intentional environmental change through the reaction seam.
	var fire := AbilityData.new()
	fire.reaction_verb = "fire"
	check(ReactionCaster.cast(room, fire, Vector2i(5, 1)).get("valid") == true,
			"vine burned through the seam")
	# 3. Wedge the movable block (the escape valve must keep working).
	var block: PushableBlock = room.blocks[0]
	check(block.try_push(Vector2i.LEFT), "block wedged one cell left")
	# 4. Rebuild in-process: resolution and environment persist, block resets.
	room.free()
	await get_tree().process_frame
	var rebuilt := _build_room()
	await get_tree().process_frame
	check(_enemy_at(rebuilt, Vector2i(9, 5)) == null,
			"resolved encounter stays resolved on rebuild (D-028)")
	check(rebuilt.material_state["cells"][Vector2i(5, 1)]["tags"].has("fire"),
			"environmental burn survives the rebuild")
	check(rebuilt.blocks[0].cell == Vector2i(3, 5),
			"the wedged block still resets on rebuild (D-023 escape valve)")
	# 5. Write the save to the scratch dir.
	var data := SaveManager.capture(SceneManager.state, "battery",
			rebuilt.player.cell)
	check(SaveManager.write(1, data, SAVE_DIR), "slot written to scratch dir")
	_finish("save")


func _run_load() -> void:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	var data := SaveManager.load_slot(1, SAVE_DIR)
	check(data != null, "scratch slot loads in a fresh process")
	if data == null:
		_finish("load")
		return
	SceneManager.state = data.to_game_state()
	var room := _build_room()
	await get_tree().process_frame
	check(_enemy_at(room, Vector2i(9, 5)) == null,
			"resolved encounter survives quit/relaunch/load (D-028)")
	check(room.material_state["cells"][Vector2i(5, 1)]["tags"].has("fire"),
			"environmental burn survives quit/relaunch/load")
	check(room.blocks[0].cell == Vector2i(3, 5),
			"the movable block is reset after load")
	# Scratch cleanup on success.
	if _failed == 0:
		var dir := DirAccess.open(SAVE_DIR)
		if dir != null:
			for f in dir.get_files():
				dir.remove(f)
			DirAccess.open("user://").remove(SAVE_DIR.trim_prefix("user://"))
	_finish("load")
