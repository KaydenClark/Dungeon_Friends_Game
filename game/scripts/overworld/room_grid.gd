class_name RoomGrid
extends Node2D
## Base class for a grid-logic room: walkability, occupancy, and AStarGrid2D
## pathfinding (no diagonals, Manhattan heuristic - locked decision, see
## /BLUEPRINT.md -> Core Logic And Invariants). Level *layout* authoring moves
## to LDtk once T-004/T-011 land; this class stays as the runtime grid model.

const TILE := 64

var width := 0
var height := 0
var blocked := {}    # Vector2i -> true (static geometry: walls, closed doors)
var occupants := {}  # Vector2i -> Node2D (player, enemies, NPCs, doors)
var enemies: Array = []
var astar := AStarGrid2D.new()

signal player_moved


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


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and not blocked.has(c) and not occupants.has(c)


func get_occupant(c: Vector2i) -> Node2D:
	return occupants.get(c)


## Adds a node to the scene tree and the occupancy map. GridActors get their
## room/cell wired via attach(); static occupants (NPC, door) must have their
## `room`/`cell` fields set by the builder before registering.
func register(node: Node2D, c: Vector2i) -> void:
	occupants[c] = node
	if node is GridActor:
		node.attach(self, c)
	else:
		node.position = cell_to_pos(c)
	add_child(node)


func unregister(node: Node2D) -> void:
	for k in occupants.keys():
		if occupants[k] == node:
			occupants.erase(k)


func move_occupant(node: Node2D, from: Vector2i, to: Vector2i) -> void:
	if occupants.get(from) == node:
		occupants.erase(from)
	occupants[to] = node


func cell_to_pos(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5


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
