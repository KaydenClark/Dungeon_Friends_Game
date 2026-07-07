class_name DungeonStubRoom
extends RoomGrid
## Stub first room of the Phase 2 tutorial dungeon (T-022): the cave behind
## the Boss Slime's door. Placeholder content - T-027 replaces it with the
## real hub room (block + plate + locked chest) - but the *plumbing* is real:
## layout comes from the LDtk pipeline (cave_room.ldtk -> TileMapLayer at 4x,
## Wall IntGrid -> RoomGrid blocking), the first room to do so (T-011 applies
## the same wiring to the forest).
##
## The player enters at ENTRY (just inside the south doorway) and steps down
## onto EXIT (the doorway gap) to return to the forest exactly where they
## left it - SceneManager.exit_room() restores the preserved room.

const LEVEL := "res://assets/levels/cave_room.ldtk"
## LDtk art is 16px; runtime cells are 64px (M1.1 grid-unit decision).
const ART_SCALE := 4.0
const SIZE := Vector2i(20, 12)
const ENTRY := Vector2i(10, 10)
const EXIT := Vector2i(10, 11)

var player: Player


func _ready() -> void:
	setup_grid(SIZE.x, SIZE.y)
	var world: Node = (load(LEVEL) as PackedScene).instantiate()
	world.scale = Vector2(ART_SCALE, ART_SCALE)
	add_child(world)
	var walls := _find_tile_layer(world, "Wall-values")
	if walls:
		for c in walls.get_used_cells():
			set_blocked(c, true)
	player = Player.new()
	register(player, ENTRY)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = SIZE.x * TILE
	player.camera.limit_bottom = SIZE.y * TILE
	player.move_finished.connect(_on_player_moved)
	SceneManager.show_dialogue([
		"The air turns cool and still...",
		"(This cave becomes the tutorial dungeon in Phase 2.",
		"For now, the way back out is behind you.)",
	])


func _find_tile_layer(root: Node, name_part: String) -> TileMapLayer:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is TileMapLayer and String(n.name).contains(name_part):
			return n
		for c in n.get_children():
			stack.append(c)
	return null


func _on_player_moved() -> void:
	if player.cell == EXIT:
		SceneManager.exit_room()
