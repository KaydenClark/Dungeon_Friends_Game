extends Node
## Phase 3 (M3.2/M3.3) acceptance battery (T-042): the literal
## "save -> quit -> relaunch -> load" done condition as a TWO-PROCESS proof.
##
## Run (one command, documented in /RUNBOOK.md -> Test And Build):
##   Godot --headless --path . scenes/dev/saveload_battery.tscn -- --phase=save \
##   && Godot --headless --path . scenes/dev/saveload_battery.tscn -- --phase=load
##
## Save phase (process 1): boots the real main scene, opens the tutorial
## chest and the forest boss door through their real interact() paths (an
## opened door + items in inventory), then saves at the save crystal - the
## real T-039 path. Exits 0 with the slot on disk.
## Load phase (process 2): boots the real main scene again; the T-040 boot
## prompt appears (a save exists), Continue is chosen through a real input
## event, and the loaded world is asserted: position, flags, inventory, the
## re-opened door staying open, and the chest room's solved state (M3.3).
## Exits 0 and wipes the battery save dir.
##
## Saves land in user://saves_battery, never in the real user://saves.

const DIR := "user://saves_battery"

var passes := 0
var fails: Array[String] = []
var done := false


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  ok: ", msg)
	else:
		fails.append(msg)
		print("  CHECK FAILED: ", msg)


func _ready() -> void:
	_watchdog()
	var phase := "save"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.trim_prefix("--phase=")
	SceneManager.save_dir = DIR
	SceneManager.auto_combat = true
	if phase == "load":
		await _load_phase()
	else:
		await _save_phase()
	_finish(phase.to_upper())


func _watchdog() -> void:
	await get_tree().create_timer(120.0).timeout
	if not done:
		print("SAVELOAD BATTERY: FAIL (timeout after 120s; %d/%d checks passed)"
				% [passes, passes + fails.size()])
		get_tree().quit(1)


func _finish(phase: String) -> void:
	done = true
	var total := passes + fails.size()
	if fails.is_empty():
		print("SAVELOAD BATTERY %s PHASE: PASS (%d/%d checks)"
				% [phase, passes, total])
		get_tree().quit(0)
	else:
		print("SAVELOAD BATTERY %s PHASE: FAIL (%d/%d checks passed)"
				% [phase, passes, total])
		for f in fails:
			print("  failed: ", f)
		get_tree().quit(1)


func _save_phase() -> void:
	print("SAVELOAD BATTERY: save phase begin")
	_wipe_dir()   # a fresh run must not inherit an old battery save
	add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	await get_tree().process_frame
	check(SceneManager.current_room is ForestRoom,
			"no battery save yet -> main booted straight into the forest")

	# M3.3 puzzle state, through the real interact path: open the tutorial
	# chest (shield + chest_tutorial_chest_opened flag).
	_warp("tutorial_chest")
	await get_tree().process_frame
	var vault: LdtkRoom = SceneManager.current_room
	check(vault.chests.size() == 1, "chest room has its chest")
	vault.chests[0].interact()
	await _pump_dialogue()
	check(SceneManager.inventory.has("shield"), "chest granted the shield")
	check(SceneManager.flags.get("chest_tutorial_chest_opened", false),
			"chest solved-state flag recorded")

	# An opened door, through the real key + interact path.
	_warp("forest")
	await get_tree().process_frame
	var forest: ForestRoom = SceneManager.current_room
	SceneManager.add_item("forest_key")
	check(forest.door != null and forest.door.link_id == "forest_door",
			"forest boss door present before opening")
	forest.door.interact()
	await _pump_dialogue()
	check(SceneManager.flags.get("door_forest_door_opened", false),
			"door opened and its flag recorded")

	# Save at the crystal - the real T-039 path.
	check(forest.crystals.size() == 1, "save crystal present")
	var crystal: SaveCrystal = forest.crystals[0]
	forest.teleport(forest.player, crystal.cell + Vector2i.RIGHT)
	crystal.interact()
	await _pump_dialogue()
	var saved := SaveManager.load_slot(1, DIR)
	check(saved != null, "slot 1 exists on disk for the relaunch")
	if saved != null:
		check(saved.current_map == "forest", "snapshot: map id")
		check(saved.player_position == crystal.cell + Vector2i.RIGHT,
				"snapshot: player cell beside the crystal")


func _load_phase() -> void:
	print("SAVELOAD BATTERY: load phase begin")
	check(SaveManager.any_save_exists(DIR),
			"the save-phase file survived the process exit")
	add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())
	await get_tree().process_frame
	check(SceneManager.current_room == null,
			"boot prompt is up - no room booted before the choice (D-011)")
	# Choose Continue through a real input event, same as a keypress.
	var ev := InputEventAction.new()
	ev.action = "confirm"
	ev.pressed = true
	Input.parse_input_event(ev)
	check(await _until(func() -> bool:
			return SceneManager.current_room is ForestRoom \
			and SceneManager.current_room.player != null),
			"Continue loaded the saved forest")
	var forest: ForestRoom = SceneManager.current_room

	check(forest.crystals.size() == 1, "loaded forest has its crystal")
	check(forest.player.cell == forest.crystals[0].cell + Vector2i.RIGHT,
			"player restored beside the crystal (saved position)")
	check(SceneManager.inventory.has("shield"), "inventory: shield survived")
	check(SceneManager.inventory.has("forest_key"), "inventory: key survived")
	check(SceneManager.flags.get("chest_tutorial_chest_opened", false),
			"flags: chest solved-state survived")
	check(SceneManager.flags.get("door_forest_door_opened", false),
			"flags: door-opened survived")
	var door_rebuilt := false
	for d in forest.doors:
		if d.link_id == "forest_door":
			door_rebuilt = true
	check(not door_rebuilt, "the opened boss door STAYS open in the rebuilt room")

	# M3.3: the solved chest persists across the full cycle.
	_warp("tutorial_chest")
	await get_tree().process_frame
	var vault: LdtkRoom = SceneManager.current_room
	check(vault.chests.size() == 1 and vault.chests[0].opened,
			"the tutorial chest is still open after quit + relaunch + load")
	_wipe_dir()


## Dev-warp teardown (same moves as the debug overlay): free the room graph,
## boot a registry room fresh.
func _warp(map_id: String) -> void:
	for r in SceneManager.room_stack:
		r.queue_free()
	SceneManager.room_stack.clear()
	if SceneManager.current_room:
		SceneManager.current_room.queue_free()
		SceneManager.current_room = null
	SceneManager.boot_room(MapRegistry.build(map_id))


func _wipe_dir() -> void:
	var root := DirAccess.open("user://")
	if root == null or not root.dir_exists("saves_battery"):
		return
	for f in DirAccess.open(DIR).get_files():
		DirAccess.open(DIR).remove(f)
	root.remove("saves_battery")


func _pump_dialogue(max_frames := 600) -> void:
	for i in max_frames:
		if SceneManager.current_dialogue:
			SceneManager.current_dialogue.advance()
		elif not SceneManager.ui_busy:
			return
		await get_tree().process_frame


func _until(pred: Callable, max_frames := 300) -> bool:
	for i in max_frames:
		if pred.call():
			return true
		await get_tree().process_frame
	return false
