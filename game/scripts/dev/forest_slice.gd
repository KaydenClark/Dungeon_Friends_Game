class_name ForestSlice
extends RoomGrid
## First-playable forest test area (placeholder ColorRect art, code-authored
## layout). This is the walking-skeleton room from BLUEPRINT.md -> Current
## Product Shape: walk, talk to one NPC, bump a visible enemy, win a simple
## battle, take the key, open the locked door, reach the goal tiles.
## Layout authoring moves to LDtk when T-004/T-011 land - only this MAP
## constant and the visual tiles get replaced; the entities and RoomGrid
## logic stay.

const MAP := [
	"TTTTTTTTTTTTTTTTTTTT",
	"T..............TTTTT",
	"T...N..........TXXTT",
	"T..............TDTTT",
	"T..P.....E.........T",
	"T..................T",
	"T......TT..........T",
	"T......TT..........T",
	"T..................T",
	"T..................T",
	"T..................T",
	"TTTTTTTTTTTTTTTTTTTT",
]

var player: Player
var npc: NPC
var door: LockedDoor
var goal_cells := {}


func _ready() -> void:
	setup_grid(MAP[0].length(), MAP.size())
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	add_child(tiles)
	var player_cell := Vector2i.ZERO
	var npc_cell := Vector2i.ZERO
	var enemy_cell := Vector2i.ZERO
	var door_cell := Vector2i.ZERO
	for y in MAP.size():
		for x in MAP[y].length():
			var c := Vector2i(x, y)
			var ch: String = MAP[y][x]
			_add_tile(tiles, c, ch)
			match ch:
				"T":
					set_blocked(c, true)
				"P":
					player_cell = c
				"N":
					npc_cell = c
				"E":
					enemy_cell = c
				"D":
					door_cell = c
				"X":
					goal_cells[c] = true

	player = Player.new()
	register(player, player_cell)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = width * TILE
	player.camera.limit_bottom = height * TILE
	player.move_finished.connect(_on_player_moved)

	npc = NPC.new()
	npc.room = self
	npc.cell = npc_cell
	npc.lines = PackedStringArray([
		"Oh, hello there, friend!",
		"A grumpy slime swallowed the key to the old east door.",
		"Walk into it to give it a good bonk - and good luck!",
	])
	register(npc, npc_cell)

	var enemy := OverworldEnemy.new()
	enemy.stats = load("res://data/enemies/forest_slime.tres")
	register(enemy, enemy_cell)
	enemies.append(enemy)

	door = LockedDoor.new()
	door.room = self
	door.cell = door_cell
	set_blocked(door_cell, true)
	register(door, door_cell)


func _add_tile(parent: Node2D, c: Vector2i, ch: String) -> void:
	var rect := ColorRect.new()
	rect.position = Vector2(c) * TILE
	rect.size = Vector2(TILE, TILE)
	if ch == "T":
		rect.color = Color(0.13, 0.3, 0.16)
		var crown := ColorRect.new()
		crown.color = Color(0.18, 0.38, 0.2)
		crown.position = rect.position + Vector2(8, 8)
		crown.size = Vector2(TILE - 16, TILE - 16)
		parent.add_child(rect)
		parent.add_child(crown)
		return
	if ch == "X":
		rect.color = Color(0.72, 0.62, 0.3)
	else:
		rect.color = Color(0.42, 0.58, 0.32) if (c.x + c.y) % 2 == 0 else Color(0.45, 0.62, 0.35)
	parent.add_child(rect)


func _on_player_moved() -> void:
	# Synchronized turns: enemies step only when the player steps (locked
	# decision - see BLUEPRINT.md -> Core Logic And Invariants).
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.take_overworld_turn(player)
	if goal_cells.has(player.cell) and not SceneManager.flags.get("slice_complete", false):
		SceneManager.flags["slice_complete"] = true
		SceneManager.show_dialogue([
			"The path beyond the door is open!",
			"First playable slice complete - thanks for testing, Kayden!",
		])
