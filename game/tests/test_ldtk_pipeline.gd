extends "res://tests/gd_test.gd"
## T-031 proof: the LDtk entity post-import pipeline end to end. Imports the
## committed fixture (entity_test_room.ldtk - one of every entity type),
## builds an LdtkRoom on it, and asserts each game object landed at the right
## cell with its LDtk custom fields carried across and its grid wiring done.


func _make_room() -> LdtkRoom:
	SceneManager.flags = {}
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)   # _ready builds the grid and adopts entities
	return room


func test_grid_and_intgrid_layers() -> void:
	var room := _make_room()
	eq(room.width, 12, "grid width from level size")
	eq(room.height, 8, "grid height from level size")
	ok(room.blocked.has(Vector2i(0, 0)), "Wall IntGrid feeds blocking")
	ok(room.is_pit(Vector2i(8, 3)), "Pit IntGrid feeds pit cells")
	not_ok(room.is_walkable(Vector2i(8, 3)), "pit cell unwalkable")
	room.queue_free()
	SceneManager.flags = {}


func test_entities_adopted_at_cells() -> void:
	var room := _make_room()
	eq(room.spawn_cell, Vector2i(2, 2), "PlayerSpawn cell")
	not_null(room.player, "player spawned")
	eq(room.player.cell, Vector2i(2, 2), "player at spawn cell")
	not_null(room.healer, "healer NPC adopted (Heals=true)")
	eq(room.healer.cell, Vector2i(4, 2), "NPC at its LDtk cell")
	eq(room.healer.lines[0], "Hello from LDtk!", "NPC lines carried from LDtk")
	eq(room.enemies.size(), 1, "enemy adopted")
	var enemy: OverworldEnemy = room.enemies[0]
	eq(enemy.cell, Vector2i(9, 5), "enemy at its LDtk cell")
	eq(enemy.stats.id, "forest_slime", "enemy stats loaded from StatsId")
	not_null(enemy.encounter, "enemy encounter loaded from LDtk EncounterId")
	if enemy.encounter != null:
		eq(enemy.encounter.id, "forest_pair", "EncounterId selects the authored group")
	eq(enemy.leash_radius, 1, "leash radius carried")
	eq(enemy.target_player, room.player, "enemy wired to the player")
	eq(room.doors.size(), 1, "door adopted")
	eq(room.door.cell, Vector2i(6, 4), "door at its LDtk cell")
	eq(room.door.required_key, "test_key", "door key carried")
	ok(room.blocked.has(room.door.cell), "door cell blocked")
	eq(room.blocks.size(), 1, "block adopted")
	eq(room.blocks[0].link_id, "test_block", "block link id carried")
	eq(room.chests.size(), 1, "chest adopted")
	eq(room.chests[0].reward_item, "trinket", "chest reward carried")
	eq(room.levers.size(), 1, "lever adopted")
	ok(room.doorways.has(Vector2i(10, 6)), "doorway marker recorded")
	eq(str(room.doorways[Vector2i(10, 6)].get("TargetRoom")), "nowhere",
			"doorway fields carried")
	ok(room.no_block_cells.has(Vector2i(10, 6)),
			"doorway cell protected from block pushes")
	room.queue_free()
	SceneManager.flags = {}


func test_plate_door_wired_by_controller() -> void:
	var room := _make_room()
	eq(room.plates.size(), 1, "plate adopted")
	var plate: PressurePlate = room.plates[0]
	eq(plate.target_id, "test_door", "plate target carried")
	ok(room.door.plate_driven, "PuzzleController wired plate to door")
	# Push the block onto the plate: the door must open.
	var block: PushableBlock = room.blocks[0]
	eq(block.cell, Vector2i(3, 5), "block at its LDtk cell")
	block.try_push(Vector2i.LEFT)   # (3,5) -> (2,5), the plate cell
	ok(plate.pressed, "block pressed the adopted plate")
	ok(room.door.held_open, "plate press opened the adopted door")
	room.queue_free()
	SceneManager.flags = {}


## T-048 / D-009 (Kayden: "enemies respawn every time you leave the room"):
## a freed-and-rebuilt room respawns ALL its enemies, uniques and bosses
## included. Loot dedup (add_item) is what keeps re-kills from duplicating
## keys, not a stay-dead flag.
func test_unique_enemies_respawn_on_rebuild() -> void:
	SceneManager.reset_session_state()
	var room := TutorialFightRoom.new()
	add_child(room)
	eq(room.enemies.size(), 1, "the key guardian spawns")
	if room.enemies.size() == 1:
		var guardian: OverworldEnemy = room.enemies[0]
		SceneManager.apply_victory_rewards(guardian.stats)
		guardian.defeated()
	room.free()
	var rebuilt := TutorialFightRoom.new()
	add_child(rebuilt)
	eq(rebuilt.enemies.size(), 1, "the guardian respawns on rebuild (D-009)")
	if rebuilt.enemies.size() == 1:
		SceneManager.apply_victory_rewards(rebuilt.enemies[0].stats)
	eq(SceneManager.inventory.get("dungeon_key"), 1,
			"re-killing the guardian never duplicates its key")
	rebuilt.free()
	SceneManager.reset_session_state()


func test_persistence_flags_respected_on_build() -> void:
	var room := _make_room()
	eq(room.enemies.size(), 1, "enemy spawns on build")
	room.queue_free()
	# A door already opened stays open on rebuild.
	SceneManager.flags = {"door_test_door_opened": true}
	var reopened := LdtkRoom.new()
	reopened.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(reopened)
	eq(reopened.doors.size(), 0, "opened door not rebuilt")
	not_ok(reopened.blocked.has(Vector2i(6, 4)), "opened door cell stays clear")
	reopened.queue_free()
	SceneManager.flags = {}
