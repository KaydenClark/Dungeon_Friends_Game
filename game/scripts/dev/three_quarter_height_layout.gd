class_name ThreeQuarterHeightLayout
extends RefCounted
## Pure T-086 metadata for the isolated three-quarter readability room.
##
## Grid coordinates stay orthogonal. Elevation only shifts a cell upward on
## screen; it does not skew x, alter AStarGrid2D, or enter production rooms.

const GRID_SIZE := Vector2i(13, 8)
const CELL_SIZE := Vector2(64, 46)
const BOARD_ORIGIN := Vector2(224, 150)
const ELEVATION_RISE := 38
const INVALID_ELEVATION := -1
const INVALID_SCREEN_POSITION := Vector2(-1, -1)

const STAIR_CELL := Vector2i(6, 4)
const BACKGROUND_ACTOR_CELL := Vector2i(3, 3)
const OCCLUSION_WALL_CELL := Vector2i(3, 4)
const FOREGROUND_ACTOR_CELL := Vector2i(3, 5)

const DEPTH_ACTOR := 20
const DEPTH_WALL := 40
const DEPTH_STRIDE := 100

const PLATFORM_MIN := Vector2i(6, 0)
const PLATFORM_MAX := Vector2i(11, 3)

var _elevation_by_cell: Dictionary = {}
var _walkable_by_cell: Dictionary = {}
var _transitions: Dictionary = {}
var _wall_cells: Array[Vector2i] = [
	Vector2i(2, 4),
	OCCLUSION_WALL_CELL,
	Vector2i(4, 4),
]
var _actors: Array[Dictionary] = [
	{
		"name": "Hero",
		"role": "foreground",
		"cell": FOREGROUND_ACTOR_CELL,
		"texture": "res://assets/art/sprites/runtime/kenney/hero.png",
		"accent": Color("62d9ff"),
	},
	{
		"name": "Buddy",
		"role": "stairs",
		"cell": Vector2i(6, 5),
		"texture": "res://assets/art/sprites/runtime/kenney/buddy.png",
		"accent": Color("c69cff"),
	},
	{
		"name": "Friend C",
		"role": "behind wall",
		"cell": BACKGROUND_ACTOR_CELL,
		"texture": "res://assets/art/sprites/runtime/kenney/quest_npc.png",
		"accent": Color("ffb85c"),
	},
	{
		"name": "Friend D",
		"role": "upper level",
		"cell": Vector2i(9, 2),
		"texture": "res://assets/art/sprites/runtime/kenney/healer.png",
		"accent": Color("7ef0a4"),
	},
]


func _init() -> void:
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			var on_platform := (
				x >= PLATFORM_MIN.x and x <= PLATFORM_MAX.x
				and y >= PLATFORM_MIN.y and y <= PLATFORM_MAX.y
			)
			_elevation_by_cell[cell] = 1 if on_platform else 0
			_walkable_by_cell[cell] = not _wall_cells.has(cell)
	_transitions[STAIR_CELL] = {
		"kind": "stairs",
		"from_elevation": 0,
		"to_elevation": 1,
		"upper_cell": Vector2i(STAIR_CELL.x, STAIR_CELL.y - 1),
		"lower_cell": Vector2i(STAIR_CELL.x, STAIR_CELL.y + 1),
	}


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


func elevation_at(cell: Vector2i) -> int:
	if not is_in_bounds(cell):
		return INVALID_ELEVATION
	return int(_elevation_by_cell.get(cell, INVALID_ELEVATION))


func elevation_levels() -> Array[int]:
	var levels: Array[int] = []
	for value in _elevation_by_cell.values():
		var level := int(value)
		if not levels.has(level):
			levels.append(level)
	levels.sort()
	return levels


func is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and bool(_walkable_by_cell.get(cell, false))


func transition_at(cell: Vector2i) -> Dictionary:
	var transition: Dictionary = _transitions.get(cell, {})
	return transition.duplicate(true)


func project_cell(cell: Vector2i, elevation_override := INVALID_ELEVATION) -> Vector2:
	if not is_in_bounds(cell):
		return INVALID_SCREEN_POSITION
	var level := elevation_at(cell) if elevation_override == INVALID_ELEVATION \
			else maxi(0, int(elevation_override))
	return BOARD_ORIGIN + Vector2(cell.x * CELL_SIZE.x,
			cell.y * CELL_SIZE.y - level * ELEVATION_RISE)


func depth_key(cell: Vector2i, layer_bias := 0) -> int:
	if not is_in_bounds(cell):
		return -1
	# Logical row, rather than projected y, keeps the square-grid overlap rule
	# stable when an elevated actor is shifted upward for presentation.
	return cell.y * DEPTH_STRIDE + int(layer_bias)


func all_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(GRID_SIZE.y):
		for x in range(GRID_SIZE.x):
			cells.append(Vector2i(x, y))
	return cells


func wall_cells() -> Array[Vector2i]:
	return _wall_cells.duplicate()


func actor_specs() -> Array[Dictionary]:
	return _actors.duplicate(true)
