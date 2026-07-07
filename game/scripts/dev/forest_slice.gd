class_name ForestSlice
extends RoomGrid
## Expanded first-playable forest area (placeholder art, code-authored layout):
## a ~5-minute run through a tree-cluttered forest with several roaming slimes,
## a healer NPC mid-map, and a Boss Slime guarding the locked east door with
## the key in its belly. Layout authoring moves to LDtk when T-004/T-011 land -
## only this MAP constant and the visual tiles get replaced; the entities and
## RoomGrid logic stay.
##
## Markers: P player, N quest NPC, H healer NPC, E slime, B boss slime,
## D locked door, X goal tiles, T tree (blocked).

const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"T.....TT......T..........TXXXXTTTT",
	"T..N..TT......T....E.....TXXXXTTTT",
	"T.....TT..TT..............TTDTTTTT",
	"T.P.......TT....TT..........B....T",
	"T.....TT........TT.....TT........T",
	"TT.TTTTT..TT........E..TT...TT...T",
	"T.........TT..TT........T...TT...T",
	"T..TT.........TT...TTT...........T",
	"T..TT...E......T...T......E....TTT",
	"T...............TTTT.........TTTTT",
	"TTTT...TT...........T........TTTTT",
	"T......TT....E......T...TT.....TTT",
	"T...T...........TTT.T...TT.......T",
	"T...T....TT.....T......H.........T",
	"T.TTT....TT.....T....TTTT..TT..TTT",
	"T........E......T....TTTT..TT..TTT",
	"T....TT........TT..............TTT",
	"T.....T........T....E......TT..TTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

var player: Player
var npc: NPC
var healer: NPC
var boss: OverworldEnemy
var door: LockedDoor
var goal_cells := {}


func _ready() -> void:
	setup_grid(MAP[0].length(), MAP.size())
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	add_child(tiles)
	var player_cell := Vector2i.ZERO
	var npc_cell := Vector2i.ZERO
	var healer_cell := Vector2i.ZERO
	var boss_cell := Vector2i.ZERO
	var door_cell := Vector2i.ZERO
	var enemy_cells: Array[Vector2i] = []
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
				"H":
					healer_cell = c
				"E":
					enemy_cells.append(c)
				"B":
					boss_cell = c
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
		"Slimes have overrun the whole forest, and their big boss",
		"squats by the old east door with the key in its belly.",
		"Bonk the little ones or slip past them - but that boss",
		"won't budge. If you get hurt, my friend by the fire can help!",
	])
	register(npc, npc_cell)

	healer = NPC.new()
	healer.room = self
	healer.cell = healer_cell
	healer.heals = true
	healer.color = Color(0.45, 0.85, 0.75)
	healer.lines = PackedStringArray([
		"You look roughed up, adventurer.",
		"Sit by my fire a moment... there. Right as rain!",
		"(HP fully restored.)",
	])
	register(healer, healer_cell)

	for c in enemy_cells:
		_spawn_enemy("res://data/enemies/forest_slime.tres", c, false)
	boss = _spawn_enemy("res://data/enemies/boss_slime.tres", boss_cell, true)

	door = LockedDoor.new()
	door.room = self
	door.cell = door_cell
	set_blocked(door_cell, true)
	register(door, door_cell)


func _spawn_enemy(stats_path: String, c: Vector2i, is_boss: bool) -> OverworldEnemy:
	var enemy := OverworldEnemy.new()
	enemy.stats = load(stats_path)
	enemy.is_boss = is_boss
	if is_boss:
		# The boss guards the door: it wanders at most 2 tiles from its spawn
		# and walks back home when the player leaves.
		enemy.leash_radius = 2
	enemy.home_cell = c
	register(enemy, c)
	enemy.target_player = player  # enemies move autonomously; need the player ref
	enemies.append(enemy)
	return enemy


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
	# Enemies move on their own clock (see OverworldEnemy._process), so this
	# only reacts to where the player lands - here, stepping into the opened
	# doorway, which leads into the tutorial dungeon (T-022; stub room until
	# T-027 builds the real hub). The goal tiles beyond are now the cave mouth.
	if player.cell == door.cell and not SceneManager.transitioning:
		SceneManager.flags["entered_dungeon"] = true
		SceneManager.enter_room(DungeonStubRoom.new())
