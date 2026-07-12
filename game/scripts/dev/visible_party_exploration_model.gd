class_name VisiblePartyExplorationModel
extends RefCounted
## Pure T-087 party-following state for the isolated exploration prototype.
##
## Only the selected leader contributes gameplay occupancy or interactions.
## Followers replay valid leader breadcrumbs as render-only positions, so they
## cannot block, push puzzle objects, or hold plates by construction.

const HeightLayout = preload("res://scripts/dev/three_quarter_height_layout.gd")

const MEMBER_IDS := [&"hero", &"buddy", &"friend_c", &"friend_d"]
const START_CELLS := {
	&"hero": Vector2i(1, 5),
	&"buddy": Vector2i(0, 5),
	&"friend_c": Vector2i(0, 6),
	&"friend_d": Vector2i(1, 6),
}

const PLATE_CELL := Vector2i(2, 5)
const DOOR_CELL := Vector2i(6, 5)
const BLOCK_CELL := Vector2i(0, 7)
const GOAL_CELL := Vector2i(10, 3)
const INVALID_CELL := Vector2i(-1, -1)
const MAX_TRAIL := 64

const CORRIDOR_WALL_CELLS := [
	Vector2i(1, 4),
	Vector2i(5, 4),
	Vector2i(2, 6),
	Vector2i(3, 6),
	Vector2i(4, 6),
	Vector2i(5, 6),
]
const CHOKE_CELLS := [
	Vector2i(2, 5),
	Vector2i(3, 5),
	Vector2i(4, 5),
	Vector2i(5, 5),
	DOOR_CELL,
	Vector2i(6, 4),
	Vector2i(6, 3),
]
const GOAL_FOLLOWER_OFFSETS := [
	Vector2i(-2, -1),
	Vector2i(-3, -1),
	Vector2i(-4, -1),
]

var layout = HeightLayout.new()
var successful_steps := 0

var _leader_id: StringName = &"hero"
var _follower_order: Array[StringName] = []
var _cells: Dictionary = {}
var _trail: Array[Vector2i] = []
var _formation_state: StringName = &"spread"


func _init() -> void:
	reset()


func reset() -> void:
	_leader_id = &"hero"
	_follower_order = [&"buddy", &"friend_c", &"friend_d"]
	_cells.clear()
	for member_id in MEMBER_IDS:
		_cells[member_id] = START_CELLS[member_id]
	successful_steps = 0
	_formation_state = &"spread"
	_seed_trail()


func member_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for member_id in MEMBER_IDS:
		ids.append(member_id)
	return ids


func leader_id() -> StringName:
	return _leader_id


func follower_ids() -> Array[StringName]:
	return _follower_order.duplicate()


func cell_for(member_id: StringName) -> Vector2i:
	return _cells.get(member_id, INVALID_CELL)


func member_cells() -> Dictionary:
	return _cells.duplicate(true)


func follower_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for member_id in _follower_order:
		cells.append(cell_for(member_id))
	return cells


func formation_state() -> StringName:
	return _formation_state


func is_walkable(cell: Vector2i) -> bool:
	return (
		layout.is_walkable(cell)
		and not CORRIDOR_WALL_CELLS.has(cell)
		and cell != BLOCK_CELL
	)


func can_step(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if absi(to_cell.x - from_cell.x) + absi(to_cell.y - from_cell.y) != 1:
		return false
	if not is_walkable(from_cell) or not is_walkable(to_cell):
		return false
	var from_elevation := layout.elevation_at(from_cell)
	var to_elevation := layout.elevation_at(to_cell)
	if from_elevation == to_elevation:
		return true
	var transition := layout.transition_at(layout.STAIR_CELL)
	var upper_cell: Vector2i = transition.get("upper_cell", INVALID_CELL)
	return (
		(from_cell == layout.STAIR_CELL and to_cell == upper_cell)
		or (from_cell == upper_cell and to_cell == layout.STAIR_CELL)
	)


func try_step_leader(direction: Vector2i) -> bool:
	if absi(direction.x) + absi(direction.y) != 1:
		return false
	var from_cell := cell_for(_leader_id)
	var target := from_cell + direction
	if not can_step(from_cell, target):
		return false
	var previous_cells := member_cells()
	_trail.push_front(target)
	if _trail.size() > MAX_TRAIL:
		_trail.resize(MAX_TRAIL)
	_cells[_leader_id] = target
	_place_followers_from_trail()
	successful_steps += 1
	_formation_state = _derive_formation_state()
	if target == GOAL_CELL and _all_members_on_elevation(1):
		_form_up_at_goal(previous_cells)
	return true


func cycle_leader() -> StringName:
	var index := MEMBER_IDS.find(_leader_id)
	if index < 0:
		reset()
		return _leader_id
	_leader_id = MEMBER_IDS[(index + 1) % MEMBER_IDS.size()]
	_follower_order.clear()
	for member_id in MEMBER_IDS:
		if member_id != _leader_id:
			_follower_order.append(member_id)
	# Switching transfers authority without moving anyone, so retain the visible
	# formation label until a real grid step changes the party positions.
	_seed_trail()
	return _leader_id


func gameplay_occupant_at(cell: Vector2i) -> StringName:
	return _leader_id if cell_for(_leader_id) == cell else StringName()


func can_interact(member_id: StringName) -> bool:
	return member_id == _leader_id and MEMBER_IDS.has(member_id)


func plate_active() -> bool:
	return cell_for(_leader_id) == PLATE_CELL


func follower_on_plate() -> bool:
	return follower_cells().has(PLATE_CELL)


func follower_plate_holds() -> int:
	return 0


func follower_block_pushes() -> int:
	return 0


func _seed_trail() -> void:
	_trail.clear()
	_trail.append(cell_for(_leader_id))
	for member_id in _follower_order:
		_trail.append(cell_for(member_id))


func _place_followers_from_trail() -> void:
	var claimed := {cell_for(_leader_id): true}
	var cursor := 1
	for member_id in _follower_order:
		var chosen := INVALID_CELL
		var current := cell_for(member_id)
		for trail_index in range(cursor, _trail.size()):
			var candidate := _trail[trail_index]
			if (
					is_walkable(candidate)
					and not claimed.has(candidate)
					and (candidate == current or can_step(current, candidate))
			):
				chosen = candidate
				cursor = trail_index + 1
				break
		if chosen == INVALID_CELL:
			if is_walkable(current) and not claimed.has(current):
				chosen = current
			else:
				chosen = _first_safe_neighbor(current, claimed)
				if chosen == INVALID_CELL:
					# Visual overlap is safer than an off-grid teleport. Followers
					# never contribute gameplay occupancy, so this cannot trap the leader.
					chosen = current
		_cells[member_id] = chosen
		claimed[chosen] = true


func _first_safe_neighbor(cell: Vector2i, claimed: Dictionary) -> Vector2i:
	var directions: Array[Vector2i] = [
		Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
	]
	for direction in directions:
		var candidate: Vector2i = cell + direction
		if can_step(cell, candidate) and not claimed.has(candidate):
			return candidate
	return INVALID_CELL


func _derive_formation_state() -> StringName:
	for cell in _cells.values():
		if CHOKE_CELLS.has(cell):
			return &"single_file"
	return &"spread"


func _all_members_on_elevation(level: int) -> bool:
	for cell in _cells.values():
		if layout.elevation_at(cell) != level:
			return false
	return true


func _form_up_at_goal(previous_cells: Dictionary) -> void:
	var targets: Array[Vector2i] = []
	for offset in GOAL_FOLLOWER_OFFSETS:
		var target: Vector2i = GOAL_CELL + offset
		if not is_walkable(target) or targets.has(target):
			return
		targets.append(target)
	for index in range(_follower_order.size()):
		var member_id: StringName = _follower_order[index]
		var visible_from: Vector2i = previous_cells.get(member_id, INVALID_CELL)
		if not can_step(visible_from, targets[index]):
			return
	for index in range(_follower_order.size()):
		_cells[_follower_order[index]] = targets[index]
	_formation_state = &"recovered"
	_seed_trail()
