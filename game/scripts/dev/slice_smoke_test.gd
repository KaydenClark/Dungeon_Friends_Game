extends Node
## Headless end-to-end smoke test of the playable slice. Drives the real game
## (main.tscn) through the whole loop with a seeded RNG:
## input map -> wall collision -> NPC dialogue -> regular slime fight (no key)
## -> healer restore -> boss slime fight (key drop) -> unlock door -> the
## Phase 2 tutorial dungeon (T-027): hub (door locks behind, push the block
## onto the plate, plate-door opens) -> pit room (2-wide pit unjumpable,
## block fills one cell, jump the rest) -> fight room (key guardian drops the
## chest key) -> west loop back to the hub -> open the chest (shield) ->
## entry door unbolts -> back to the forest with state intact -> forced
## defeat restarts from the beginning of the game (T-029).
## The forest has several autonomous enemies, so navigation is tolerant:
## any unplanned encounter is fought to completion and the walk resumes.
## Run: Godot --headless --path . scenes/dev/slice_smoke_test.tscn
## Exits 0 and prints "SLICE SMOKE TEST: PASS" on success, exits 1 on failure.

var room: ForestRoom
var passes := 0
var fails: Array[String] = []
var done := false


func _ready() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await get_tree().create_timer(180.0).timeout
	if not done:
		print("SLICE SMOKE TEST: FAIL (timeout after 180s; %d/%d checks passed)"
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

	# 1. Input map (T-009 + T-025): all 9 actions exist with >= 1 binding.
	for a in ["move_up", "move_down", "move_left", "move_right",
			"interact", "confirm", "cancel", "menu", "jump"]:
		check(InputMap.has_action(a) and InputMap.action_get_events(a).size() > 0,
				"input action bound: " + a)

	room = SceneManager.world_container.get_child(0)
	check(room is ForestRoom, "forest boots through the LDtk pipeline (T-011)")
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
	check(SceneManager.flags.get("defeated_forest_boss", false),
			"unique boss defeat recorded in flags")

	# 8. Locked door + key (reward flow): unlock, then walk into the doorway.
	var door: LockedDoor = room.door
	check(await _go(player, door.cell + Vector2i.DOWN), "reached the locked door")
	player.set_facing(Vector2i.UP)
	player.interact()
	await get_tree().process_frame
	await _pump_dialogue()
	check(door.opened, "door opened with the forest key")
	check(room.is_walkable(door.cell), "door cell is walkable after opening")

	# 9. Into the dungeon (T-022/T-027): the doorway enters the tutorial hub;
	# the forest is suspended, not freed.
	SceneManager.heal_hero_to_full()   # top up for the dungeon fight (de-flake)
	await _step(player, Vector2i.UP)
	check(await _until(func() -> bool: return SceneManager.current_room is TutorialHubRoom),
			"doorway transitioned into the tutorial hub")
	check(SceneManager.flags.get("entered_dungeon", false), "entered_dungeon flag set")
	var hub: TutorialHubRoom = SceneManager.current_room
	await _pump_dialogue()   # hub welcome lines
	var hub_player: Player = hub.player
	check(hub_player != null and hub_player.cell == Vector2i(7, 11),
			"player spawned just inside the hub entry")
	check(hub_player.camera.is_current(), "camera switched to the hub player")
	check(not room.visible, "forest room hidden while in the dungeon")
	check(is_instance_valid(room) and room.get_parent() != null,
			"forest room preserved in the tree, not freed")
	var entry_door := _hub_door(hub, "hub_entry")
	check(entry_door != null and not entry_door.opened,
			"entry door locked behind the player")

	# 10. Hub puzzle (T-023/T-024): L-shaped push onto the center plate opens
	# the plate-driven east door; stepping off would re-lock it, the parked
	# block holds it open.
	var block: PushableBlock = hub.blocks[0]
	var plate: PressurePlate = hub.plates[0]
	var east_door := _hub_door(hub, "room2_door")
	check(block.cell == Vector2i(4, 4), "block starts in the 3x3 corner")
	check(not east_door.held_open, "east door starts locked")
	check(await _go_grid(hub, hub_player, Vector2i(3, 4)), "walked behind the block")
	hub_player.set_facing(Vector2i.RIGHT)
	await _push(hub_player, block, Vector2i.RIGHT)
	check(block.cell == Vector2i(5, 4), "block pushed right into the 3x3 middle column")
	check(await _go_grid(hub, hub_player, Vector2i(5, 3)), "circled above the block")
	await _push(hub_player, block, Vector2i.DOWN)
	check(block.cell == Vector2i(5, 5), "L-shaped push landed the block on the plate")
	check(plate.pressed, "plate pressed by the parked block")
	check(east_door.held_open, "plate-driven door held open")
	check(hub.is_walkable(east_door.cell), "east doorway walkable while held")

	# 11. Pit room (T-025): the 2-wide pit can't be jumped; sink the block,
	# then jump the remaining 1-cell gap from the filled cell.
	check(await _go_grid(hub, hub_player, Vector2i(13, 6)), "reached the east door")
	await _step(hub_player, Vector2i.RIGHT)
	check(await _until(func() -> bool: return SceneManager.current_room is TutorialPitRoom),
			"east doorway entered the pit room")
	var pit: TutorialPitRoom = SceneManager.current_room
	await _pump_dialogue()
	var pit_player: Player = pit.player
	var pit_block: PushableBlock = pit.blocks[0]
	check(pit_player.cell == Vector2i(5, 11), "player at the pit-room entry")
	check(await _go_grid(pit, pit_player, Vector2i(5, 8)), "walked to the pit edge")
	pit_player.set_facing(Vector2i.UP)
	check(not pit_player.try_jump(), "the 2-wide pit is not jumpable (T-025 limit)")
	await _until(func() -> bool: return not pit_player.moving)
	check(await _go_grid(pit, pit_player, Vector2i(5, 10)), "walked behind the block")
	await _push(pit_player, pit_block, Vector2i.UP)
	check(pit_block.cell == Vector2i(5, 8), "block pushed to the pit edge")
	check(await _go_grid(pit, pit_player, Vector2i(5, 9)), "followed the block")
	await _push(pit_player, pit_block, Vector2i.UP)
	await _until(func() -> bool: return pit_block.sunk)
	check(pit_block.sunk, "block sank into the pit")
	check(pit.is_walkable(Vector2i(5, 7)), "filled pit cell is walkable floor")
	check(await _go_grid(pit, pit_player, Vector2i(5, 7)), "stood on the filled cell")
	pit_player.set_facing(Vector2i.UP)
	check(pit_player.try_jump(), "jumped the remaining 1-cell gap")
	await _until(func() -> bool: return not pit_player.moving)
	check(pit_player.cell == Vector2i(5, 5), "landed on the far side of the pit")

	# 12. Fight room: the key guardian drops the chest key; the west door
	# loops straight back to the hub.
	check(await _go_grid(pit, pit_player, Vector2i(5, 1)), "crossed to the north door")
	await _step(pit_player, Vector2i.UP)
	check(await _until(func() -> bool: return SceneManager.current_room is TutorialFightRoom),
			"north doorway entered the fight room")
	var fight: TutorialFightRoom = SceneManager.current_room
	await _pump_dialogue()
	var fight_player: Player = fight.player
	check(fight.enemies.size() == 1, "the key guardian awaits")
	var guardian_ok := await _hunt_all(fight, fight_player)
	check(guardian_ok, "key guardian defeated")
	check(SceneManager.inventory.has("chest_key"), "guardian dropped the chest key")
	check(SceneManager.flags.get("defeated_key_guardian", false),
			"guardian defeat recorded (won't respawn)")
	check(await _go_grid(fight, fight_player, Vector2i(1, 4)), "reached the west door")
	await _step(fight_player, Vector2i.LEFT)
	check(await _until(func() -> bool: return SceneManager.current_room == hub),
			"west loop returned to the SAME hub instance")
	await _pump_dialogue()   # west-door-opens lines
	check(hub_player.cell == TutorialHubRoom.WEST_ENTRY,
			"loop-back placed the player at the hub's west door")
	var west_door := _hub_door(hub, "hub_west")
	check(west_door == null or west_door.opened, "west shortcut door opened for good")
	check(block.cell == Vector2i(5, 5) and plate.pressed,
			"hub puzzle state preserved across the loop (block still on plate)")

	# 13. Chest -> shield -> the entry door unbolts (dungeon complete).
	check(await _go_grid(hub, hub_player, Vector2i(10, 4)), "reached the chest")
	hub_player.set_facing(Vector2i.UP)
	hub_player.interact()
	await get_tree().process_frame
	await _pump_dialogue()
	check(SceneManager.inventory.has("shield"), "chest opened: shield acquired (D-001)")
	check(SceneManager.flags.get("chest_tutorial_chest_opened", false),
			"chest opened state persisted in flags")
	await _step(hub_player, Vector2i.DOWN)   # any step triggers the completion check
	await _pump_dialogue()
	check(entry_door.opened, "entry door unbolted once the dungeon is complete")
	check(await _go_grid(hub, hub_player, Vector2i(7, 11)), "walked back to the entry")
	await _step(hub_player, Vector2i.DOWN)
	check(await _until(func() -> bool: return SceneManager.current_room == room),
			"stepping out returned to the forest")
	check(room.visible, "forest visible again after returning")
	check(room.player.cell == door.cell, "player back at the exact doorway cell")
	check(room.player.camera.is_current(), "camera restored to the forest player")
	check(not is_instance_valid(room.boss) or room.boss.is_queued_for_deletion(),
			"forest state preserved across the trip (boss still defeated)")
	check(door.opened, "door still open after the round trip")

	# 14. Party defeat (T-029, D-004): restart from the beginning of the game.
	var old_room: Node2D = SceneManager.current_room
	SceneManager.handle_defeat()
	await _pump_dialogue()
	check(await _until(func() -> bool:
			return SceneManager.current_room != old_room \
			and SceneManager.current_room is ForestRoom),
			"defeat rebooted a fresh forest")
	check(SceneManager.total_xp == 0, "XP reset to zero")
	check(SceneManager.inventory.size() == 0, "inventory wiped")
	check(SceneManager.flags.size() == 0, "flags wiped (dungeon fully resets)")
	check(SceneManager.hero_hp == SceneManager.hero_stats.max_hp,
			"hero restored to full for the fresh start")
	var fresh: ForestRoom = SceneManager.current_room
	check(await _until(func() -> bool: return fresh.player != null), "fresh player spawned")
	check(fresh.player.cell == Vector2i(2, 4), "fresh start at the forest spawn cell")
	check(fresh.boss != null and is_instance_valid(fresh.boss),
			"boss respawned in the fresh world")

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


## Wait until `pred` returns true (room transitions run over a few fade
## frames). Returns whether it became true within the frame budget.
func _until(pred: Callable, max_frames := 300) -> bool:
	for i in max_frames:
		if pred.call():
			return true
		await get_tree().process_frame
	return pred.call()


func _hub_door(hub: TutorialHubRoom, link: String) -> LockedDoor:
	for d: LockedDoor in hub.doors:
		if d.link_id == link:
			return d
	return null


func _step(player: Player, dir: Vector2i) -> bool:
	if SceneManager.in_encounter:
		return false
	var ok: bool = player.try_step(dir)
	if ok:
		await player.move_finished
	else:
		await get_tree().process_frame
	return ok


## Bump-push the block one cell and wait out its tween.
func _push(player: Player, block: PushableBlock, dir: Vector2i) -> void:
	player.try_step(dir)   # bump -> push
	await _until(func() -> bool: return not block.moving)
	await get_tree().process_frame


## Walk to a target cell on `grid`, re-planning around moving occupants.
func _navigate(grid: RoomGrid, player: Player, target: Vector2i, max_steps := 160) -> bool:
	var steps := 0
	while player.cell != target and steps < max_steps:
		if SceneManager.in_encounter:
			return false
		var path := grid.find_path(player.cell, target, true)
		if path.size() < 2:
			await get_tree().process_frame
		else:
			await _step(player, path[1] - player.cell)
		steps += 1
	return player.cell == target


## Encounter-tolerant navigation on the forest grid.
func _go(player: Player, target: Vector2i, max_rounds := 8) -> bool:
	for i in max_rounds:
		if await _navigate(room, player, target):
			return true
		if SceneManager.in_encounter:
			await SceneManager.encounter_finished
			await _pump_dialogue()
	return player.cell == target


## Encounter-tolerant navigation on an arbitrary grid (dungeon rooms).
func _go_grid(grid: RoomGrid, player: Player, target: Vector2i, max_rounds := 8) -> bool:
	for i in max_rounds:
		if await _navigate(grid, player, target):
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


## Fight every enemy on `grid` until none remain (the tutorial fight room).
func _hunt_all(grid: RoomGrid, player: Player) -> bool:
	var tries := 0
	while grid.enemies.size() > 0 and tries < 600:
		if SceneManager.in_encounter:
			await SceneManager.encounter_finished
			await _pump_dialogue()
		else:
			var target: OverworldEnemy = null
			for e in grid.enemies:
				if is_instance_valid(e):
					target = e
					break
			if target == null:
				break
			var path := grid.find_path(player.cell, target.cell, true)
			if path.size() >= 2:
				await _step(player, path[1] - player.cell)
			else:
				await get_tree().process_frame
		tries += 1
	return grid.enemies.size() == 0


## Advance any open dialogue until the UI is free again.
func _pump_dialogue(max_frames := 600) -> void:
	for i in max_frames:
		if SceneManager.current_dialogue:
			SceneManager.current_dialogue.advance()
		elif not SceneManager.ui_busy:
			return
		await get_tree().process_frame
