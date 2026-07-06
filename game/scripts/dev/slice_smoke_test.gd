extends Node
## Headless end-to-end smoke test of the expanded playable slice. Drives the
## real game (main.tscn) through the whole loop with a seeded RNG:
## input map -> wall collision -> NPC dialogue -> regular slime fight (no key)
## -> healer restore -> boss slime fight (key drop) -> unlock door -> goal.
## The forest now has several autonomous enemies, so navigation is tolerant:
## any unplanned encounter is fought to completion and the walk resumes.
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
	await get_tree().create_timer(120.0).timeout
	if not done:
		print("SLICE SMOKE TEST: FAIL (timeout after 120s; %d/%d checks passed)"
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

	# 3. Expanded roster: several regular slimes plus a leashed boss by the door.
	check(room.enemies.size() >= 6,
			"multiple enemies on the map (got %d)" % room.enemies.size())
	check(room.boss != null and is_instance_valid(room.boss), "boss slime present")
	check(room.boss.stats.loot_table.has("forest_key"),
			"boss carries the forest key")
	var regulars_carry_key := false
	for e in room.enemies:
		if e != room.boss and e.stats.loot_table.has("forest_key"):
			regulars_carry_key = true
	check(not regulars_carry_key, "no regular slime carries the key")

	# 4. NPC dialogue (T-012): stand under the quest NPC, face up, interact.
	check(await _go(player, room.npc.cell + Vector2i.DOWN), "reached the NPC")
	player.set_facing(Vector2i.UP)
	player.interact()
	await get_tree().process_frame
	check(SceneManager.ui_busy, "NPC dialogue opened")
	await _pump_dialogue()
	check(not SceneManager.ui_busy, "NPC dialogue closed after advancing")

	# 5. Regular slime fight: hunt the nearest non-boss enemy; victory must
	# grant XP but no key.
	var beaten: int = await _hunt_regular(player)
	check(beaten > 0, "regular slime fight ended in victory")
	check(SceneManager.total_xp > 0, "XP gained: %d" % SceneManager.total_xp)
	check(not SceneManager.inventory.has("forest_key"),
			"no key from a regular slime")
	check(SceneManager.hero_hp > 0, "hero HP carried back: %d" % SceneManager.hero_hp)
	check(SceneManager.world_container.visible, "overworld restored after combat")

	# 6. Healer NPC: interact fully restores HP.
	check(await _go(player, room.healer.cell + Vector2i.LEFT), "reached the healer")
	player.set_facing(Vector2i.RIGHT)
	player.interact()
	await get_tree().process_frame
	await _pump_dialogue()
	check(SceneManager.hero_hp == SceneManager.hero_stats.max_hp,
			"healer restored HP to max (%d)" % SceneManager.hero_hp)

	# 7. Boss fight: hunt the boss until it falls; it drops the key.
	var boss_ok: bool = await _hunt_boss(player)
	check(boss_ok, "boss slime defeated")
	check(SceneManager.inventory.has("forest_key"), "boss dropped the forest key")
	check(not is_instance_valid(room.boss) or room.boss.is_queued_for_deletion(),
			"defeated boss removed from the map")

	# 8. Locked door + key (reward flow): unlock, walk through, reach goal.
	var door: LockedDoor = room.door
	check(await _go(player, door.cell + Vector2i.DOWN), "reached the locked door")
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
func _navigate(player: Player, target: Vector2i, max_steps := 120) -> bool:
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


## Encounter-tolerant navigation: roaming slimes may jump the player on the
## way; fight any such encounter to completion and keep walking.
func _go(player: Player, target: Vector2i, max_rounds := 8) -> bool:
	for i in max_rounds:
		if await _navigate(player, target):
			return true
		if SceneManager.in_encounter:
			await SceneManager.encounter_finished
			await _pump_dialogue()
	return player.cell == target


## Walk at the nearest regular (non-boss) slime until an encounter resolves.
## Returns the number of enemies defeated along the way (0 = failure).
func _hunt_regular(player: Player) -> int:
	var before: int = room.enemies.size()
	var tries := 0
	while room.enemies.size() == before and tries < 400:
		if SceneManager.in_encounter:
			await SceneManager.encounter_finished
			await _pump_dialogue()
		else:
			var target: OverworldEnemy = _nearest_regular(player)
			if target == null:
				break
			var path := room.find_path(player.cell, target.cell, true)
			if path.size() >= 2:
				await _step(player, path[1] - player.cell)
			else:
				await get_tree().process_frame
		tries += 1
	return before - room.enemies.size()


func _nearest_regular(player: Player) -> OverworldEnemy:
	var best: OverworldEnemy = null
	var best_d := 1 << 30
	for e in room.enemies:
		if e == room.boss or not is_instance_valid(e):
			continue
		var d: int = absi(e.cell.x - player.cell.x) + absi(e.cell.y - player.cell.y)
		if d < best_d:
			best_d = d
			best = e
	return best


## Walk at the boss until it is defeated (the hero may lose and retry - a
## defeat restores HP and the hunt continues).
func _hunt_boss(player: Player) -> bool:
	var tries := 0
	while is_instance_valid(room.boss) and not room.boss.is_queued_for_deletion() \
			and tries < 600:
		if SceneManager.in_encounter:
			await SceneManager.encounter_finished
			await _pump_dialogue()
		else:
			var path := room.find_path(player.cell, room.boss.cell, true)
			if path.size() >= 2:
				await _step(player, path[1] - player.cell)
			else:
				await get_tree().process_frame
		tries += 1
	return not is_instance_valid(room.boss) or room.boss.is_queued_for_deletion()


## Advance any open dialogue until the UI is free again.
func _pump_dialogue(max_frames := 600) -> void:
	for i in max_frames:
		if SceneManager.current_dialogue:
			SceneManager.current_dialogue.advance()
		elif not SceneManager.ui_busy:
			return
		await get_tree().process_frame
