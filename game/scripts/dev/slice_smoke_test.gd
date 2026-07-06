extends Node
## Headless end-to-end smoke test of the first-playable slice. Drives the
## real game (main.tscn) through the whole loop with a seeded RNG:
## input map -> wall collision -> NPC dialogue -> enemy encounter -> combat
## victory -> key drop -> unlock door -> reach the goal tiles.
## Run: Godot --headless --path . scenes/dev/slice_smoke_test.tscn
## Exits 0 and prints "SLICE SMOKE TEST: PASS" on success, exits 1 on failure.

var room: ForestSlice
var passes := 0
var fails: Array[String] = []
var done := false


func _ready() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await get_tree().create_timer(90.0).timeout
	if not done:
		print("SLICE SMOKE TEST: FAIL (timeout after 90s; %d/%d checks passed)"
				% [passes, passes + fails.size()])
		get_tree().quit(1)


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  ok: ", msg)
	else:
		fails.append(msg)
		print("  CHECK FAILED: ", msg)


func _run() -> void:
	print("SLICE SMOKE TEST: begin")
	SceneManager.rng.seed = 1234
	SceneManager.auto_combat = true
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame

	# 1. Input map (T-009): all 8 actions exist with at least one binding.
	for a in ["move_up", "move_down", "move_left", "move_right",
			"interact", "confirm", "cancel", "menu"]:
		check(InputMap.has_action(a) and InputMap.action_get_events(a).size() > 0,
				"input action bound: " + a)

	room = SceneManager.world_container.get_child(0)
	var player: Player = room.player
	check(player != null, "player spawned")
	check(player.camera != null and player.camera.is_current(), "camera follows player")

	# 2. Grid movement + wall collision (T-010): walk up until a tree stops us.
	var moved_steps := 0
	for i in 10:
		var ok: bool = await _step(player, Vector2i.UP)
		if not ok:
			break
		moved_steps += 1
	check(moved_steps == 3, "walked 3 grid steps up from spawn (got %d)" % moved_steps)
	check(player.cell.y == 1, "blocked by tree wall at y=1 (at %s)" % str(player.cell))
	check(player.position == room.cell_to_pos(player.cell),
			"player rests exactly on the grid")

	# 3. NPC dialogue (T-012): stand under the NPC, face up, interact.
	check(await _navigate(player, room.npc.cell + Vector2i.DOWN), "reached the NPC")
	player.set_facing(Vector2i.UP)
	player.interact()
	await get_tree().process_frame
	check(SceneManager.ui_busy, "NPC dialogue opened")
	await _pump_dialogue()
	check(not SceneManager.ui_busy, "NPC dialogue closed after advancing")

	# 4. Enemy contact -> combat -> victory (T-013 + combat MVP).
	var enemy: OverworldEnemy = room.enemies[0]
	var tries := 0
	while not SceneManager.in_encounter and tries < 120 and is_instance_valid(enemy):
		var path := room.find_path(player.cell, enemy.cell, true)
		if path.size() >= 2:
			await _step(player, path[1] - player.cell)
		else:
			await get_tree().process_frame
		tries += 1
	check(SceneManager.in_encounter, "enemy contact started an encounter")
	if SceneManager.in_encounter:
		var victory: bool = await SceneManager.encounter_finished
		check(victory, "combat ended in victory")
		await _pump_dialogue()
	check(SceneManager.inventory.has("forest_key"), "forest key in inventory")
	check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(),
			"defeated enemy removed from the map")
	check(SceneManager.hero_hp > 0, "hero HP carried back: %d" % SceneManager.hero_hp)
	check(SceneManager.world_container.visible, "overworld restored after combat")

	# 5. Locked door + key (reward flow): unlock, walk through, reach goal.
	var door: LockedDoor = room.door
	check(await _navigate(player, door.cell + Vector2i.DOWN), "reached the locked door")
	player.set_facing(Vector2i.UP)
	player.interact()
	await get_tree().process_frame
	await _pump_dialogue()
	check(door.opened, "door opened with the forest key")
	check(room.is_walkable(door.cell), "door cell is walkable after opening")
	await _step(player, Vector2i.UP)
	await _step(player, Vector2i.UP)
	await _pump_dialogue()
	check(SceneManager.flags.get("slice_complete", false), "slice completion flag set")

	done = true
	var total := passes + fails.size()
	if fails.is_empty():
		print("SLICE SMOKE TEST: PASS (%d/%d checks)" % [passes, total])
		get_tree().quit(0)
	else:
		print("SLICE SMOKE TEST: FAIL (%d/%d checks passed)" % [passes, total])
		for f in fails:
			print("  failed: ", f)
		get_tree().quit(1)


func _step(player: Player, dir: Vector2i) -> bool:
	if SceneManager.in_encounter:
		return false
	var ok: bool = player.try_step(dir)
	if ok:
		await player.move_finished
	else:
		await get_tree().process_frame
	return ok


## Walk to a target cell, re-planning around moving occupants each step.
func _navigate(player: Player, target: Vector2i, max_steps := 80) -> bool:
	var steps := 0
	while player.cell != target and steps < max_steps:
		if SceneManager.in_encounter:
			return false
		var path := room.find_path(player.cell, target, true)
		if path.size() < 2:
			await get_tree().process_frame
		else:
			await _step(player, path[1] - player.cell)
		steps += 1
	return player.cell == target


## Advance any open dialogue until the UI is free again.
func _pump_dialogue(max_frames := 600) -> void:
	for i in max_frames:
		if SceneManager.current_dialogue:
			SceneManager.current_dialogue.advance()
		elif not SceneManager.ui_busy:
			return
		await get_tree().process_frame
