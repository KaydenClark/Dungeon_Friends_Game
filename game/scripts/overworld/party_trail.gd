class_name PartyTrail
extends RefCounted
## S-009/TK-003 pure production party-trail model (D-029). Followers replay
## the leader's breadcrumbs as render-only cells: always walkable, always
## distinct from the leader and each other, never contributing occupancy.
## A non-adjacent leader move (teleport, room restore, pit-fall respawn)
## reseeds the trail beside the leader. snapshot_cells() projects follower
## positions into the neutral world state deterministically: the render cell
## when free, else the nearest free walkable cell, else {} (fail closed).
##
## Kept free of Node/scene dependencies so tests/test_party_trail.gd drives
## the real placement logic; LdtkRoom owns the node wiring.

const INVALID_CELL := Vector2i(-1, -1)
const MAX_TRAIL := 64
## Deterministic neighbor priority everywhere in this model.
const CARDINALS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## BFS visit bound: placement never scans more than this many cells, so a
## degenerate walkability callable cannot hang a frame.
const MAX_SEARCH := 256

var _walkable := Callable()
var _follower_ids: Array = []
var _cells := {}              # follower id -> render cell
var _trail: Array = []        # [0] = leader's cell, then older breadcrumbs
var _leader_cell := INVALID_CELL


func setup(follower_ids: Array, leader_cell: Vector2i,
		walkable: Callable) -> void:
	_follower_ids = follower_ids.duplicate()
	_walkable = walkable
	_reseed(leader_cell)


func leader_cell() -> Vector2i:
	return _leader_cell


func follower_cells() -> Dictionary:
	return _cells.duplicate()


## Advance the trail after a leader move. An adjacent step replays
## breadcrumbs; anything larger is a teleport-class move and reseeds.
func leader_moved(new_leader_cell: Vector2i) -> void:
	if new_leader_cell == _leader_cell:
		return
	var dist := absi(new_leader_cell.x - _leader_cell.x) \
			+ absi(new_leader_cell.y - _leader_cell.y)
	if _leader_cell == INVALID_CELL or dist != 1:
		_reseed(new_leader_cell)
		return
	_trail.push_front(new_leader_cell)
	if _trail.size() > MAX_TRAIL:
		_trail.resize(MAX_TRAIL)
	_leader_cell = new_leader_cell
	_place_followers()


## Deterministic world-state projection. `occupied` holds every cell already
## claimed by a real actor (leader, enemies, NPCs, objects). Returns
## {follower id -> distinct free walkable cell}, or {} when any follower
## cannot be placed (the adapter fails closed on that).
func snapshot_cells(occupied: Dictionary) -> Dictionary:
	var out := {}
	var claimed := occupied.duplicate()
	for id in _follower_ids:
		var current: Vector2i = _cells.get(id, INVALID_CELL)
		var chosen := INVALID_CELL
		if current != INVALID_CELL and _is_open(current) \
				and not claimed.has(current):
			chosen = current
		else:
			chosen = _nearest_free(current if current != INVALID_CELL \
					else _leader_cell, claimed)
		if chosen == INVALID_CELL:
			return {}
		out[id] = chosen
		claimed[chosen] = true
	return out


func _reseed(new_leader_cell: Vector2i) -> void:
	_leader_cell = new_leader_cell
	_cells.clear()
	var claimed := {new_leader_cell: true}
	for id in _follower_ids:
		var cell := _nearest_free(new_leader_cell, claimed)
		if cell == INVALID_CELL:
			# Degenerate geometry: render at the leader (visual overlap);
			# snapshot_cells resolves or refuses when it matters.
			cell = new_leader_cell
		_cells[id] = cell
		claimed[cell] = true
	_trail = [new_leader_cell]
	for id in _follower_ids:
		_trail.append(_cells[id])


func _place_followers() -> void:
	var claimed := {_leader_cell: true}
	var cursor := 1
	for id in _follower_ids:
		var current: Vector2i = _cells[id]
		var chosen := INVALID_CELL
		for trail_index in range(cursor, _trail.size()):
			var candidate: Vector2i = _trail[trail_index]
			if _is_open(candidate) and not claimed.has(candidate) \
					and (candidate == current or _adjacent(current, candidate)):
				chosen = candidate
				cursor = trail_index + 1
				break
		if chosen == INVALID_CELL:
			if _is_open(current) and not claimed.has(current):
				chosen = current
			else:
				chosen = _first_safe_neighbor(current, claimed)
				if chosen == INVALID_CELL:
					chosen = _nearest_free(_leader_cell, claimed)
				if chosen == INVALID_CELL:
					# Visual overlap beats an off-grid teleport; followers
					# carry no occupancy so this can never trap the leader.
					chosen = current
		_cells[id] = chosen
		claimed[chosen] = true


func _first_safe_neighbor(cell: Vector2i, claimed: Dictionary) -> Vector2i:
	for direction: Vector2i in CARDINALS:
		var candidate: Vector2i = cell + direction
		if _is_open(candidate) and not claimed.has(candidate):
			return candidate
	return INVALID_CELL


## Deterministic breadth-first search for the nearest free walkable cell,
## excluding `claimed`, bounded by MAX_SEARCH visits.
func _nearest_free(from: Vector2i, claimed: Dictionary) -> Vector2i:
	if from == INVALID_CELL:
		return INVALID_CELL
	var queue: Array = [from]
	var visited := {from: true}
	var visits := 0
	while not queue.is_empty() and visits < MAX_SEARCH:
		var cell: Vector2i = queue.pop_front()
		visits += 1
		for direction: Vector2i in CARDINALS:
			var next: Vector2i = cell + direction
			if visited.has(next) or not _is_open(next):
				continue
			if not claimed.has(next):
				return next
			visited[next] = true
			queue.append(next)
	return INVALID_CELL


func _is_open(cell: Vector2i) -> bool:
	return _walkable.is_valid() and bool(_walkable.call(cell))


static func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1
