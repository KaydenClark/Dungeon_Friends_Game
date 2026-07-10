extends Node
## Headless end-to-end smoke test of the playable slice. Drives the real game
## (main.tscn) through the whole loop with a seeded RNG:
## input map -> wall collision -> NPC dialogue -> regular slime fight (no key)
## -> healer restore -> boss slime fight (key drop) -> unlock door -> the
## Phase 2 tutorial dungeon (T-027, 2026-07-07 rework): hub (door locks
## behind, 13-brick wall where only one brick budges) -> pit room (two 1-wide
## ledges jumped, 2-wide chasm unjumpable, block fills one cell) -> fight
## room (key guardian drops the dungeon key) -> west loop back to the hub ->
## dungeon key opens the north door -> chest room (shield) -> entry door
## unbolts -> back to the forest with state intact -> forced defeats prove
## the T-041 checkpoint respawns (dungeon -> fresh hub entrance; outside ->
## the healer's campfire; inventory kept, XP clamped, saves untouched).
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
	# Scratch save dir BEFORE main boots: a real save in user://saves would
	# otherwise pop the T-040 Continue/New Game prompt and stall the run.
	SceneManager.save_dir = "user://saves_smoke_test"
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

	# 5. Phase 4 integration: a real LDtk EncounterId resolves to its authored
	# two-enemy group, then returns its summed rewards to the exact overworld.
	var encounter_enemy := _nearest_regular(player)
	check(encounter_enemy != null and encounter_enemy.encounter != null,
			"regular forest enemy carries EncounterData from LDtk")
	check(encounter_enemy != null and encounter_enemy.encounter.enemy_group.size() == 2,
			"EncounterData builds the authored two-enemy party")
	var xp_before := SceneManager.total_xp
	var beaten: int = await _hunt_regular(player)
	check(beaten > 0, "regular slime fight ended in victory")
	check(SceneManager.total_xp == xp_before + 10,
			"EncounterData group granted 10 XP (got %d)" % SceneManager.total_xp)
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

	# 6b. Save crystal (T-039): interacting writes slot 1 with the live
	# position and flags (into the scratch dir set at boot).
	check(room.crystals.size() == 1, "a save crystal stands by the campfire")
	var crystal: SaveCrystal = room.crystals[0]
	check(await _go(player, crystal.cell + Vector2i.RIGHT), "reached the save crystal")
	player.set_facing(Vector2i.LEFT)
	player.interact()
	await get_tree().process_frame
	await _pump_dialogue()
	var saved := SaveManager.load_slot(1, SceneManager.save_dir)
	check(saved != null, "the crystal wrote save slot 1")
	if saved != null:
		check(saved.current_map == "forest", "save records the forest map id")
		check(saved.player_position == player.cell, "save records the player cell")
		check(saved.flags == SceneManager.state.flags, "save snapshots the flags")
		check(saved.inventory == SceneManager.state.inventory,
				"save snapshots the inventory")
	# Remembered for the load leg at the end of the run (T-042).
	var save_cell: Vector2i = player.cell
	var save_xp: int = SceneManager.total_xp

	# 7. Boss fight: hunt the boss until it falls; it drops the key.
	var boss_ok: bool = await _hunt_boss(player)
	check(boss_ok, "boss slime defeated")
	check(SceneManager.inventory.has("forest_key"), "boss dropped the forest key")
	check(not SceneManager.flags.has("defeated_forest_boss"),
			"no stay-dead flag is written (D-009: enemies respawn on rebuild)")

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

	# 10. Hub brick wall (2026-07-07 rework): 13 identical bricks, only one
	# budges; fixed bricks refuse the push. The north chest-room door stays
	# locked without its key. No pressure plate anywhere (on hold).
	check(hub.blocks.size() == 13, "hub wall has its 13 bricks")
	check(hub.plates.size() == 0, "no pressure plate in the hub (on hold)")
	check(hub.chests.size() == 0, "no chest in the hub (moved to the side room)")
	var brick: PushableBlock = null
	var fixed: PushableBlock = null
	var movable_count := 0
	for b: PushableBlock in hub.blocks:
		if b.movable:
			movable_count += 1
			brick = b
		elif fixed == null:
			fixed = b
	check(movable_count == 1, "exactly one brick is movable")
	check(brick != null and brick.cell == Vector2i(6, 8),
			"the loose brick sits in the wall at (6,8)")
	var fixed_cell: Vector2i = fixed.cell
	check(await _go_grid(hub, hub_player, fixed_cell + Vector2i.DOWN),
			"stood under a fixed brick")
	await _push(hub_player, fixed, Vector2i.UP)
	check(fixed.cell == fixed_cell, "fixed brick refuses the push")
	check(await _go_grid(hub, hub_player, Vector2i(6, 9)), "stood under the loose brick")
	await _push(hub_player, brick, Vector2i.UP)
	check(brick.cell == Vector2i(6, 7), "loose brick pushed out of the wall")
	await _step(hub_player, Vector2i.UP)   # into the gap
	await _push(hub_player, brick, Vector2i.UP)
	check(brick.cell == Vector2i(6, 6) and hub_player.cell == Vector2i(6, 8),
			"brick pushed clear, player standing in the wall gap")
	var chest_door := _hub_door(hub, "chest_door")
	check(chest_door != null and not chest_door.opened,
			"north chest-room door present and locked")
	check(await _go_grid(hub, hub_player, Vector2i(7, 1)), "reached the north door")
	hub_player.set_facing(Vector2i.UP)
	hub_player.interact()
	await get_tree().process_frame
	await _pump_dialogue()
	check(not chest_door.opened, "north door stays locked without the dungeon key")

	# 11. Pit room (T-025 rework): two 1-wide ledges teach the jump, the
	# 2-wide chasm refuses it; sink the block, cross on the filled cell.
	check(await _go_grid(hub, hub_player, Vector2i(13, 6)), "reached the east gap")
	await _step(hub_player, Vector2i.RIGHT)
	check(await _until(func() -> bool: return SceneManager.current_room is TutorialPitRoom),
			"east gap entered the pit room")
	var pit: TutorialPitRoom = SceneManager.current_room
	await _pump_dialogue()
	var pit_player: Player = pit.player
	var pit_block: PushableBlock = pit.blocks[0]
	check(pit_player.cell == Vector2i(5, 11), "player at the pit-room entry")
	check(pit_block.movable and pit_block.cell == Vector2i(3, 5),
			"block waits on the chasm's near bank")
	check(await _go_grid(pit, pit_player, Vector2i(5, 10)), "walked to the first ledge")

	# 11b. Pit fall (T-047): stepping into the ledge pit is a fall, not a
	# refusal - 10% of max HP and a walk of shame back to the room's entrance.
	var hp_before_fall: int = SceneManager.hero_hp
	check(await _step(pit_player, Vector2i.UP), "stepped into the ledge pit")
	check(pit_player.cell == Vector2i(5, 11),
			"fall respawned at the pit-room entrance")
	check(SceneManager.hero_hp == hp_before_fall - pit_player.fall_damage(),
			"the fall cost 10% of max HP (%d)" % pit_player.fall_damage())
	check(await _go_grid(pit, pit_player, Vector2i(5, 10)),
			"walked back to the first ledge")
	pit_player.set_facing(Vector2i.UP)
	check(pit_player.try_jump(), "jumped the first 1-wide ledge")
	await _until(func() -> bool: return not pit_player.moving)
	check(pit_player.cell == Vector2i(5, 8), "landed between the ledges")
	pit_player.set_facing(Vector2i.UP)
	check(pit_player.try_jump(), "jumped the second ledge")
	await _until(func() -> bool: return not pit_player.moving)
	check(pit_player.cell == Vector2i(5, 6), "landed on the chasm's near bank")
	await _pump_dialogue()   # chasm hint
	check(await _go_grid(pit, pit_player, Vector2i(5, 5)), "walked to the chasm edge")
	await _pump_dialogue()
	pit_player.set_facing(Vector2i.UP)
	check(not pit_player.try_jump(), "the 2-wide chasm is not jumpable (T-025 limit)")
	await _until(func() -> bool: return not pit_player.moving)
	check(await _go_grid(pit, pit_player, Vector2i(3, 6)), "stood behind the block")
	await _push(pit_player, pit_block, Vector2i.UP)
	await _until(func() -> bool: return pit_block.sunk)
	check(pit_block.sunk, "block sank into the chasm")
	check(pit.is_walkable(Vector2i(3, 4)), "filled chasm cell is walkable floor")
	check(await _go_grid(pit, pit_player, Vector2i(3, 4)), "stood on the filled cell")
	pit_player.set_facing(Vector2i.UP)
	check(pit_player.try_jump(), "jumped the remaining 1-cell gap")
	await _until(func() -> bool: return not pit_player.moving)
	check(pit_player.cell == Vector2i(3, 2), "landed on the far side of the chasm")

	# 12. Fight room: the key guardian drops the dungeon key; the west door
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
	check(SceneManager.inventory.has("dungeon_key"), "guardian dropped the dungeon key")
	check(not SceneManager.flags.has("defeated_key_guardian"),
			"no stay-dead flag for the guardian (D-009: rebuilt rooms respawn it)")
	check(await _go_grid(fight, fight_player, Vector2i(1, 4)), "reached the west door")
	await _step(fight_player, Vector2i.LEFT)
	check(await _until(func() -> bool: return SceneManager.current_room == hub),
			"west loop returned to the SAME hub instance")
	await _pump_dialogue()   # west-door-opens lines
	check(hub_player.cell == TutorialHubRoom.WEST_ENTRY,
			"loop-back placed the player at the hub's west door")
	var west_door := _hub_door(hub, "hub_west")
	check(west_door == null or west_door.opened, "west shortcut door opened for good")
	check(brick.cell == Vector2i(6, 6), "hub brick-wall state preserved across the loop")

	# 13. The dungeon key opens the north door; the side room's chest gives
	# the shield; the entry door unbolts (dungeon complete).
	check(await _go_grid(hub, hub_player, Vector2i(7, 1)), "back at the north door")
	hub_player.set_facing(Vector2i.UP)
	hub_player.interact()
	await get_tree().process_frame
	await _pump_dialogue()
	check(chest_door.opened, "north door opened with the dungeon key")
	await _step(hub_player, Vector2i.UP)
	check(await _until(func() -> bool: return SceneManager.current_room is TutorialChestRoom),
			"north doorway entered the chest room")
	var vault: TutorialChestRoom = SceneManager.current_room
	await _pump_dialogue()
	var vault_player: Player = vault.player
	check(vault_player.cell == Vector2i(3, 5), "player at the chest-room entry")
	check(vault.chests.size() == 1, "the shield chest is in the side room")
	check(await _go_grid(vault, vault_player, Vector2i(3, 3)), "reached the chest")
	vault_player.set_facing(Vector2i.UP)
	vault_player.interact()
	await get_tree().process_frame
	await _pump_dialogue()
	check(SceneManager.inventory.has("shield"), "chest opened: shield acquired (D-001)")
	check(SceneManager.flags.get("chest_tutorial_chest_opened", false),
			"chest opened state persisted in flags")
	check(await _go_grid(vault, vault_player, Vector2i(3, 5)), "back at the vault exit")
	await _step(vault_player, Vector2i.DOWN)
	check(await _until(func() -> bool: return SceneManager.current_room == hub),
			"vault exit returned to the SAME hub instance")
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

	# 14. Party defeat inside the dungeon (T-041, D-004/D-008): checkpoint
	# respawn at the hub entrance on a FRESH hub, forest kept beneath,
	# inventory intact, XP clamped to the level floor, full HP.
	await _step(room.player, Vector2i.DOWN)  # off the doorway cell...
	await _step(room.player, Vector2i.UP)    # ...and back on: re-enter the hub
	check(await _until(func() -> bool: return SceneManager.current_room is TutorialHubRoom),
			"re-entered the tutorial hub for the defeat check")
	var old_hub_id: int = SceneManager.current_room.get_instance_id()
	SceneManager.hero_hp = 1
	var xp_before_defeat: int = SceneManager.total_xp
	SceneManager.handle_defeat()
	await _pump_dialogue()
	check(await _until(func() -> bool:
			return SceneManager.current_room is TutorialHubRoom \
			and SceneManager.current_room.get_instance_id() != old_hub_id),
			"dungeon defeat respawned into a FRESH hub")
	var respawn_hub: TutorialHubRoom = SceneManager.current_room
	check(await _until(func() -> bool: return respawn_hub.player != null),
			"respawn hub spawned a player")
	check(respawn_hub.player.cell == Vector2i(7, 11),
			"respawned at the dungeon entrance (hub spawn)")
	check(respawn_hub.blocks.size() > 0, "brick wall reset with the fresh hub")
	check(SceneManager.room_stack.size() == 1 \
			and SceneManager.room_stack[0] == room,
			"the suspended forest survives the dungeon defeat")
	check(SceneManager.inventory.has("shield"), "inventory kept on defeat (D-008)")
	check(SceneManager.total_xp == Progression.xp_after_defeat(xp_before_defeat, 1),
			"defeat cost 25% of above-floor XP (%d -> %d)"
			% [xp_before_defeat, SceneManager.total_xp])
	check(SceneManager.hero_hp == int(round(
			SceneManager.hero_stats.max_hp * SceneManager.RESPAWN_HP_FRACTION)),
			"party respawns at 80% HP (%d)" % SceneManager.hero_hp)
	check(SceneManager.flags.get("hub_seen", false),
			"flags NOT wiped - checkpoints, not restarts")

	# 15. Defeat outside (T-041): walk out, then respawn by the healer's
	# campfire in the SAME forest instance.
	check(await _go_grid(respawn_hub, respawn_hub.player, Vector2i(7, 11)),
			"standing on the hub exit approach")
	await _step(respawn_hub.player, Vector2i.DOWN)
	check(await _until(func() -> bool: return SceneManager.current_room == room),
			"walked back out to the suspended forest")
	SceneManager.hero_hp = 1
	SceneManager.handle_defeat()
	await _pump_dialogue()
	check(SceneManager.current_room == room,
			"outside defeat keeps the same forest instance")
	var healer_dist: int = absi(room.player.cell.x - room.healer.cell.x) \
			+ absi(room.player.cell.y - room.healer.cell.y)
	check(healer_dist == 1, "respawned beside the healer's campfire")
	check(SceneManager.inventory.has("shield"), "inventory still intact")
	check(SceneManager.hero_hp == int(round(
			SceneManager.hero_stats.max_hp * SceneManager.RESPAWN_HP_FRACTION)),
			"80% HP after the outside respawn")

	# 16. Load leg (T-040/T-042): the crystal save from 6b restores position,
	# XP, and inventory through the real load path - rolling back everything
	# that happened since (shield, keys, dungeon flags).
	check(SceneManager.load_game(1), "load_game read the crystal save back")
	check(await _until(func() -> bool:
			return SceneManager.current_room is ForestRoom \
			and SceneManager.current_room != room \
			and SceneManager.current_room.player != null),
			"load booted a fresh forest with a player")
	var lforest: ForestRoom = SceneManager.current_room
	check(lforest.player.cell == save_cell, "player back at the save-point cell")
	check(SceneManager.total_xp == save_xp,
			"XP rolled back to the save point (%d)" % save_xp)
	check(not SceneManager.inventory.has("shield"),
			"post-save loot rolled back (no shield yet at the crystal)")
	check(SceneManager.room_stack.is_empty(), "load cleared the room stack")

	# Clean up the scratch save dir so smoke runs leave no residue.
	var scratch := DirAccess.open("user://")
	if scratch != null and scratch.dir_exists("saves_smoke_test"):
		for f in DirAccess.open("user://saves_smoke_test").get_files():
			DirAccess.open("user://saves_smoke_test").remove(f)
		scratch.remove("saves_smoke_test")
	SceneManager.save_dir = SaveManager.DEFAULT_DIR

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
