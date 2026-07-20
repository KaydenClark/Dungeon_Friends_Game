class_name PartyTrail
extends RefCounted
## S-009/TK-003 + S-010/TK-002 pure production party model (D-029/D-037).
## Followers are render-only cells: always walkable, always distinct from the
## leader and each other, never contributing occupancy. Placement prefers the
## selected formation's rotated offsets (line/square/spaced via the promoted
## PartyFormationLayout); a blocked offset compresses onto the leader's
## breadcrumb trail and reforms when the offset frees up. A follower stranded
## off-trail by a direction change catches up deterministically once it falls
## more than CATCH_UP_DISTANCE behind. A non-adjacent leader move (teleport,
## room restore, pit-fall respawn) reseeds the trail beside the leader.
## snapshot_cells() projects follower positions into the neutral world state
## deterministically: the render cell when free, else the nearest free
## walkable cell, else {} (fail closed).
##
## Kept free of Node/scene dependencies so tests/test_party_trail.gd drives
## the real placement logic; LdtkRoom owns the node wiring.

const FormationLayout := preload("res://scripts/world/party_formation_layout.gd")

const INVALID_CELL := Vector2i(-1, -1)
const MAX_TRAIL := 64
## Deterministic neighbor priority everywhere in this model.
const CARDINALS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## BFS visit bound: placement never scans more than this many cells, so a
## degenerate walkability callable cannot hang a frame.
const MAX_SEARCH := 256
## A follower parked further than this (Manhattan) from the leader abandons
## its cell and catches up beside the leader instead of stalling forever.
const CATCH_UP_DISTANCE := 3

var _walkable := Callable()
var _follower_ids: Array = []
var _cells := {}              # follower id -> render cell
var _trail: Array = []        # [0] = leader's cell, then older breadcrumbs
var _leader_cell := INVALID_CELL
var _formation: StringName = &"line"
var _facing := Vector2i.RIGHT
var _layout := FormationLayout.new()


func setup(follower_ids: Array, leader_cell: Vector2i,
		walkable: Callable) -> void:
	_follower_ids = follower_ids.duplicate()
	_walkable = walkable
	_reseed(leader_cell)


func leader_cell() -> Vector2i:
	return _leader_cell


func follower_cells() -> Dictionary:
	return _cells.duplicate()


func selected_formation() -> StringName:
	return _formation


## Selects a formation from the promoted planner's accepted set. Followers
## reform immediately onto any open offset cells; blocked offsets keep their
## current (possibly compressed) cells until movement frees them.
func set_formation(formation_id: StringName) -> bool:
	if not _layout.is_valid_formation(formation_id):
		return false
	_formation = formation_id
	_reform()
	return true


## &"formed" when every follower sits on its preferred rotated offset,
## &"compressed" while any follower is on a trail/catch-up fallback cell
## (choke compression, blocked offsets, mid-reform).
func formation_state() -> StringName:
	var desired := _desired_cells()
	for id in _follower_ids:
		if _cells.get(id, INVALID_CELL) != desired.get(id, INVALID_CELL):
			return &"compressed"
	return &"formed"


## Wholesale authority handoff (leader switching): adopt the given leader
## cell, follower order, and follower cells verbatim, and restart the trail
## from them. The caller owns legality of the handed cells.
func assume(new_leader_cell: Vector2i, new_follower_cells: Dictionary,
		follower_order: Array) -> void:
	_follower_ids = follower_order.duplicate()
	_leader_cell = new_leader_cell
	_cells = new_follower_cells.duplicate()
	_trail = [new_leader_cell]
	for id in _follower_ids:
		_trail.append(_cells.get(id, new_leader_cell))


## The follower cells the selected formation prefers at the current leader
## cell and facing (first N offsets for N followers).
func _desired_cells() -> Dictionary:
	var offsets: Array = _layout.preferred_offsets(_formation, _facing)
	var out := {}
	for i in _follower_ids.size():
		if i < offsets.size():
			out[_follower_ids[i]] = _leader_cell + offsets[i]
	return out


## Immediate reform onto open formation offsets (selection changes).
func _reform() -> void:
	if _leader_cell == INVALID_CELL:
		return
	var claimed := {_leader_cell: true}
	var desired := _desired_cells()
	for id in _follower_ids:
		var target: Vector2i = desired.get(id, INVALID_CELL)
		if target != INVALID_CELL and _is_open(target) \
				and not claimed.has(target):
			_cells[id] = target
		claimed[_cells[id]] = true
	_trail = [_leader_cell]
	for id in _follower_ids:
		_trail.append(_cells[id])


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
	_facing = new_leader_cell - _leader_cell
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
	var desired := _desired_cells()
	# Fallback seeding chains from the PREVIOUS member, not the leader: a
	# leader-anchored search can seed a follower in FRONT of the party (the
	# only free neighbor), which then leapfrogs ahead forever on the march.
	var anchor := new_leader_cell
	for id in _follower_ids:
		var cell: Vector2i = desired.get(id, INVALID_CELL)
		if cell == INVALID_CELL or not _is_open(cell) or claimed.has(cell):
			cell = _nearest_free(anchor, claimed)
		if cell == INVALID_CELL:
			# Degenerate geometry: render at the leader (visual overlap);
			# snapshot_cells resolves or refuses when it matters.
			cell = new_leader_cell
		_cells[id] = cell
		claimed[cell] = true
		anchor = cell
	_trail = [new_leader_cell]
	for id in _follower_ids:
		_trail.append(_cells[id])


func _place_followers() -> void:
	var claimed := {_leader_cell: true}
	var desired := _desired_cells()
	var cursor := 1
	for id in _follower_ids:
		var current: Vector2i = _cells[id]
		var chosen := INVALID_CELL
		# 1. The selected formation's offset cell, when open and one smooth
		#    step away (or already held).
		var target: Vector2i = desired.get(id, INVALID_CELL)
		if target != INVALID_CELL and _is_open(target) \
				and not claimed.has(target) \
				and (target == current or _adjacent(current, target)):
			chosen = target
		# 2. Breadcrumb trail compression (chokes, blocked offsets).
		if chosen == INVALID_CELL:
			for trail_index in range(cursor, _trail.size()):
				var candidate: Vector2i = _trail[trail_index]
				if _is_open(candidate) and not claimed.has(candidate) \
						and (candidate == current or _adjacent(current, candidate)):
					chosen = candidate
					cursor = trail_index + 1
					break
		# 3. Stay put while still near the leader; otherwise catch up
		#    deterministically instead of stalling off-trail forever.
		if chosen == INVALID_CELL:
			var leader_dist := absi(current.x - _leader_cell.x) \
					+ absi(current.y - _leader_cell.y)
			if _is_open(current) and not claimed.has(current) \
					and leader_dist <= CATCH_UP_DISTANCE:
				chosen = current
			else:
				chosen = _nearest_free(_leader_cell, claimed)
			if chosen == INVALID_CELL:
				chosen = _first_safe_neighbor(current, claimed)
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
