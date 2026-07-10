class_name RoomGrid
extends Node2D
## Base class for a grid-logic room: walkability, occupancy, pits, and
## AStarGrid2D pathfinding (no diagonals, Manhattan heuristic - locked
## decision, see /BLUEPRINT.md -> Core Logic And Invariants). Level *layout*
## authoring lives in LDtk (see LdtkRoom); this class stays as the runtime
## grid model.

const TILE := 64

var width := 0
var height := 0
var blocked := {}    # Vector2i -> true (static geometry: walls, closed doors)
var pits := {}       # Vector2i -> true (block walking, jumpable, fillable - T-025)
var occupants := {}  # Vector2i -> Node2D (player, enemies, NPCs, doors, blocks)
## Cells a PushableBlock may never be pushed onto (doorway gaps - a block
## plugging the room's exit would be an unrecoverable soft-lock; blocks stay
## in their room, classic Zelda).
var no_block_cells := {}
var enemies: Array = []
var astar := AStarGrid2D.new()
## The last entrance the player came through into this room (T-047): the
## spawn cell on build, re-stamped by SceneManager when the room is restored
## off the stack. Pit falls respawn the player here - "you just walk back
## through the last entrance you came through" (Kayden, D-008 part 4).
var entry_cell := Vector2i.ZERO

signal player_moved
## Emitted whenever a cell gains or loses an occupant (register, unregister,
## or a move touching that cell). Pressure plates listen to this (T-024).
signal cell_occupancy_changed(cell: Vector2i)


func setup_grid(w: int, h: int) -> void:
	width = w
	height = h
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func set_blocked(c: Vector2i, v: bool) -> void:
	if v:
		blocked[c] = true
	else:
		blocked.erase(c)
	if in_bounds(c):
		astar.set_point_solid(c, v)


## Pit cells block walking and pathing (like walls) but are distinct: a
## 1-cell pit can be jumped over, and a PushableBlock shoved in fills it
## (see fill_pit). Pits are impassable, not lethal (locked decision).
func set_pit(c: Vector2i, v: bool) -> void:
	if v:
		pits[c] = true
	else:
		pits.erase(c)
	if in_bounds(c):
		astar.set_point_solid(c, v)


func is_pit(c: Vector2i) -> bool:
	return pits.has(c)


## A block pushed into a pit permanently converts it to walkable floor
## (classic Zelda; locked decision - see BLUEPRINT.md puzzle primitives).
func fill_pit(c: Vector2i) -> void:
	set_pit(c, false)


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and not blocked.has(c) and not pits.has(c) \
			and not occupants.has(c)


func get_occupant(c: Vector2i) -> Node2D:
	return occupants.get(c)


## Adds a node to the scene tree and the occupancy map. GridActors get their
## room/cell wired via attach(); static occupants (NPC, door) must have their
## `room`/`cell` fields set by the builder before registering.
func register(node: Node2D, c: Vector2i) -> void:
	occupy(node, c)
	if node is GridActor:
		node.attach(self, c)
	else:
		node.position = cell_to_pos(c)
	add_child(node)


func unregister(node: Node2D) -> void:
	vacate(node)


## Occupancy-map-only claim (no reparenting/positioning) - used by doors that
## re-lock while already in the tree (T-024) and by register() above.
func occupy(node: Node2D, c: Vector2i) -> void:
	occupants[c] = node
	cell_occupancy_changed.emit(c)


func vacate(node: Node2D) -> void:
	for k in occupants.keys():
		if occupants[k] == node:
			occupants.erase(k)
			cell_occupancy_changed.emit(k)


func move_occupant(node: Node2D, from: Vector2i, to: Vector2i) -> void:
	if occupants.get(from) == node:
		occupants.erase(from)
		cell_occupancy_changed.emit(from)
	occupants[to] = node
	cell_occupancy_changed.emit(to)


func cell_to_pos(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5


## Instantly relocate a registered occupant (room-restore repositioning and
## dev-tools warps - normal movement always tweens instead).
func teleport(node: Node2D, to: Vector2i) -> void:
	vacate(node)
	occupy(node, to)
	if node is GridActor:
		node.cell = to
	elif "cell" in node:
		node.cell = to
	node.position = cell_to_pos(to)


## Reset the room's puzzle state (dev tools + the hub's reset lever): every
## un-sunk PushableBlock returns to its starting cell. Filled pits stay
## filled (permanent by design); rooms with richer reset needs override.
func reset_puzzle() -> void:
	for child in get_children():
		if child is PushableBlock and not child.sunk:
			child.reset_to_start()


## Path over static geometry; with avoid_occupants, other occupants' cells
## are treated as solid too (the from/to cells are always left open, so a
## path *to* an occupant - e.g. walking into an enemy - still resolves).
func find_path(from: Vector2i, to: Vector2i, avoid_occupants := false) -> Array[Vector2i]:
	if not in_bounds(from) or not in_bounds(to):
		return []
	var toggled: Array[Vector2i] = []
	if avoid_occupants:
		for c in occupants.keys():
			if c != from and c != to and not astar.is_point_solid(c):
				astar.set_point_solid(c, true)
				toggled.append(c)
	var path := astar.get_id_path(from, to)
	for c in toggled:
		astar.set_point_solid(c, false)
	return path
