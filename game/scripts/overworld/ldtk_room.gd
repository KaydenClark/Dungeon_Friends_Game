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

## S-009/TK-002 authoring contract for the neutral world-state seam.
## An optional `Elevation` IntGrid layer authors integer cell elevation: its
## values MUST be declared ascending from 1, so the imported atlas.x index
## maps as elevation = index + 1 (the importer stores only the value index -
## see addons/ldtk-importer/src/layer.gd create_intgrid_layer).
## An optional `Material` IntGrid layer authors initial material tags: its
## values MUST be declared in MATERIAL_TAGS order (vine, flammable, channel,
## smoke - the authorable subset of the D-031 ReactionCore vocabulary;
## transient states like wet/fire/ice are never authored).
## Any unknown value or duplicate encounter id is recorded in
## `authoring_errors` and the world-state adapter fails closed; the v1 room
## build itself stays green (S-009: v1 remains runnable until replacement).
const MATERIAL_TAGS := ["vine", "flammable", "channel", "smoke"]
const MAX_ELEVATION := 8

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
## Named authoring failures (unknown material value, invalid elevation value,
## duplicate encounter id). Non-empty means the world-state adapter refuses
## this room; the v1 build continues regardless.
var authoring_errors: Array[String] = []
## Stable encounter id -> the authored (spawn) cell it was declared at.
## Survives defeats: a resolved encounter keeps its authored identity.
var authored_encounters := {}


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
	_apply_authoring_layers(level)
	_adopt_entities(level)
	_spawn_player()
	puzzle = PuzzleController.new()
	puzzle.plates = plates
	puzzle.doors = doors
	puzzle.levers = levers
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


## IntGrid value *index* per painted cell: the importer stores each cell as
## atlas coords (value_index, 0), so atlas.x recovers the authored value's
## position in the layer's declared value list.
func _intgrid_value_indices(level: Node, layer_name: String) -> Dictionary:
	var layer := _find_tile_layer(level, layer_name)
	if layer == null:
		return {}
	var indices := {}
	for cell in layer.get_used_cells():
		indices[cell] = layer.get_cell_atlas_coords(cell).x
	return indices


## Maps an imported Elevation IntGrid value index to its integer elevation,
## or -1 for an index outside the supported authoring range (fail closed).
static func elevation_for_index(index: int) -> int:
	if index < 0 or index + 1 > MAX_ELEVATION:
		return -1
	return index + 1


## Maps an imported Material IntGrid value index to its D-031 material tag,
## or "" for an unknown index (fail closed).
static func material_for_index(index: int) -> String:
	if index < 0 or index >= MATERIAL_TAGS.size():
		return ""
	return MATERIAL_TAGS[index]


## The stable encounter identity for an authored Enemy: its UniqueId when
## set, else a deterministic id from the authored cell. Both are stable
## across room rebuilds because both come from the authored level data.
static func encounter_id_for(unique_id: String, cell: Vector2i) -> String:
	if unique_id != "":
		return unique_id
	return "enc_%d_%d" % [cell.x, cell.y]


## Adopts the optional Elevation/Material IntGrid layers into the RoomGrid
## world-state extensions. Fail closed: any invalid authored value voids BOTH
## stores (no partial or guessed adoption) and records a named error; the v1
## room build continues unaffected.
func _apply_authoring_layers(level: Node) -> void:
	var errors: Array[String] = []
	var elevation_indices := _intgrid_value_indices(level, "Elevation-values")
	for cell: Vector2i in elevation_indices:
		if not in_bounds(cell):
			errors.append("elevation_out_of_bounds:%s" % cell)
			continue
		var value := elevation_for_index(int(elevation_indices[cell]))
		if value < 0:
			errors.append("invalid_elevation_value:%s" % cell)
			continue
		set_elevation(cell, value)
	var material_indices := _intgrid_value_indices(level, "Material-values")
	for cell: Vector2i in material_indices:
		if not in_bounds(cell):
			errors.append("material_out_of_bounds:%s" % cell)
			continue
		var tag := material_for_index(int(material_indices[cell]))
		if tag == "":
			errors.append("unknown_material_value:%s" % cell)
			continue
		add_material(cell, tag)
	if not errors.is_empty():
		elevation.clear()
		materials.clear()
		for error in errors:
			push_error("LdtkRoom authoring (%s): %s" % [level_path, error])
		authoring_errors.append_array(errors)


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
				# S-009/TK-002: stable encounter identity from authored data.
				enemy.world_encounter_id = encounter_id_for(enemy.unique_id, cell)
				if authored_encounters.has(enemy.world_encounter_id):
					var dup := "duplicate_encounter_id:%s" % enemy.world_encounter_id
					push_error("LdtkRoom authoring (%s): %s" % [level_path, dup])
					authoring_errors.append(dup)
				else:
					authored_encounters[enemy.world_encounter_id] = cell
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
