class_name LdtkRoom
extends RoomGrid
## Runtime base for a room authored in LDtk (T-031, locked decision D-002:
## levels are all-in LDtk entities). Instantiates the imported .ldtk world,
## scales the 16px art to the 64px runtime cell (M1.1 grid unit), feeds the
## Wall/Pit IntGrid layers into the RoomGrid model, and adopts every game
## object the entities_post_import hook spawned - reparenting it out of the
## scaled art space into the grid and wiring occupancy, refs, and puzzle
## signals. Room subclasses set `level_path` (and `level_name` for
## multi-level worlds) and override the _room_* hooks.

const ART_SCALE := 4.0
const ART_GRID := 16

var level_path := ""
## Which level to use from a multi-level world ("" = the first level).
var level_name := ""

var player: Player
var npc: NPC          # first quest (non-healer) NPC, if any
var healer: NPC       # first healer NPC, if any
var boss: OverworldEnemy
var door: LockedDoor  # first door, if any (forest-slice compatibility ref)
var doors: Array = []
var plates: Array = []
var blocks: Array = []
var chests: Array = []
var levers: Array = []
var crystals: Array = []
## Doorway marker cells -> their LDtk fields ({TargetRoom, SpawnX, SpawnY}).
var doorways := {}
var spawn_cell := Vector2i.ZERO
## Set before enter_room() to spawn the player somewhere other than the
## level's PlayerSpawn (e.g. entering a room through its far door).
var spawn_override := Vector2i(-1, -1)
var puzzle: PuzzleController


func _ready() -> void:
	_build()
	_room_ready()


## Post-build hook for room subclasses (welcome dialogue, extra wiring).
func _room_ready() -> void:
	pass


## Player stepped onto a doorway marker cell. Subclasses decide what the
## TargetRoom field means (enter a sub-room, exit, warp).
func _on_doorway(_fields: Dictionary) -> void:
	pass


func _build() -> void:
	var world: Node2D = (load(level_path) as PackedScene).instantiate()
	world.scale = Vector2(ART_SCALE, ART_SCALE)
	add_child(world)
	var level := _pick_level(world)
	if level == null:
		push_error("LdtkRoom: no LDTKLevel found in %s" % level_path)
		return
	# Align the picked level's origin with the room's origin and hide siblings
	# (multi-level worlds place levels at world offsets).
	world.position = -Vector2(level.position) * ART_SCALE
	for other in world.get_children():
		if other is LDTKLevel and other != level:
			other.visible = false
			other.process_mode = Node.PROCESS_MODE_DISABLED
	setup_grid(level.size.x / ART_GRID, level.size.y / ART_GRID)
	for c in _intgrid_cells(level, "Wall-values"):
		set_blocked(c, true)
	for c in _intgrid_cells(level, "Pit-values"):
		set_pit(c, true)
	_adopt_entities(level)
	_spawn_player()
	puzzle = PuzzleController.new()
	puzzle.plates = plates
	puzzle.doors = doors
	add_child(puzzle)
	puzzle.wire()


func _pick_level(world: Node) -> LDTKLevel:
	var first: LDTKLevel = null
	for child in world.get_children():
		if child is LDTKLevel:
			if first == null:
				first = child
			if level_name == "" or String(child.name) == level_name:
				return child
	return first


func _intgrid_cells(level: Node, layer_name: String) -> Array:
	var layer := _find_tile_layer(level, layer_name)
	return layer.get_used_cells() if layer else []


func _find_tile_layer(root: Node, name_part: String) -> TileMapLayer:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is TileMapLayer and String(n.name).contains(name_part):
			return n
		for c in n.get_children():
			stack.append(c)
	return null


## Walk the level's entity layers and move every post-import-spawned game
## object into the runtime grid. Opened doors and opened chests restore
## their persisted state from SceneManager.flags (rooms are freed and
## rebuilt on re-entry); enemies always respawn on a rebuild (D-009/T-048).
func _adopt_entities(level: Node) -> void:
	var adoptable: Array[Node2D] = []
	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node2D and n.has_meta("ldtk_identifier"):
			adoptable.append(n)
			continue
		for c in n.get_children():
			stack.append(c)
	for node in adoptable:
		var ident: String = node.get_meta("ldtk_identifier")
		var cell: Vector2i = node.get_meta("ldtk_cell")
		var fields: Dictionary = node.get_meta("ldtk_fields", {})
		node.get_parent().remove_child(node)
		match ident:
			"PlayerSpawn":
				spawn_cell = cell
				node.free()
			"Doorway":
				doorways[cell] = fields
				# The doorway AND its approach cells are block-free: a block on
				# the gap plugs the exit, and one parked on the only approach
				# cell is just as fatal (found by the soft-lock solver - see
				# tests/test_tutorial_softlock.gd). Blocks stay in their room.
				no_block_cells[cell] = true
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					no_block_cells[cell + d] = true
				node.free()
			"Npc":
				var p_npc: NPC = node
				p_npc.room = self
				p_npc.cell = cell
				register(p_npc, cell)
				if p_npc.heals and healer == null:
					healer = p_npc
				elif not p_npc.heals and npc == null:
					npc = p_npc
			"Enemy":
				# D-009 (T-048): enemies ALWAYS respawn on a freed-and-rebuilt
				# room, uniques and bosses included - the room-reset escape
				# valve applies to fights too. Loot dedup prevents duplicate
				# key drops; suspended rooms keep their in-visit state because
				# they are never rebuilt.
				var enemy: OverworldEnemy = node
				enemy.home_cell = cell
				register(enemy, cell)
				enemies.append(enemy)
				if enemy.is_boss and boss == null:
					boss = enemy
			"LockedDoor":
				var d: LockedDoor = node
				if d.link_id != "" \
						and SceneManager.flags.get("door_%s_opened" % d.link_id, false):
					node.free()
					continue
				d.room = self
				d.cell = cell
				set_blocked(cell, true)
				register(d, cell)
				doors.append(d)
				if door == null:
					door = d
			"PushableBlock":
				register(node, cell)
				blocks.append(node)
			"PressurePlate":
				var plate: PressurePlate = node
				plate.room = self
				plate.cell = cell
				add_child(plate)
				plate.watch_room()
				plates.append(plate)
			"Chest":
				var chest: Chest = node
				chest.room = self
				chest.cell = cell
				register(chest, cell)
				chest.restore_state()
				chests.append(chest)
			"Lever":
				var lever: Lever = node
				lever.room = self
				lever.cell = cell
				register(lever, cell)
				levers.append(lever)
			"SaveCrystal":
				var crystal: SaveCrystal = node
				crystal.room = self
				crystal.cell = cell
				register(crystal, cell)
				crystals.append(crystal)
			_:
				node.free()


func _spawn_player() -> void:
	if spawn_override != Vector2i(-1, -1):
		spawn_cell = spawn_override
	entry_cell = spawn_cell   # where a pit fall walks you back to (T-047)
	player = Player.new()
	register(player, spawn_cell)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = width * TILE
	player.camera.limit_bottom = height * TILE
	player.move_finished.connect(_on_player_moved)
	for e in enemies:
		e.target_player = player


func _on_player_moved() -> void:
	if SceneManager.transitioning:
		return
	if doorways.has(player.cell):
		_on_doorway(doorways[player.cell])
	player_moved.emit()
