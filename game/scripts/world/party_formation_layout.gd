class_name PartyFormationLayout
extends RefCounted
## Pure selectable formation and encounter-deployment planner (D-029/D-037).
##
## S-010/TK-001 promoted this planner unchanged from the T-096 dev spike into
## the production world namespace: tests/test_party_formation_layout.gd pins
## the algorithm (three formations, four-facing rotation, deterministic legal
## deployment with reachable fallback) and the parity test pins that dev
## consumers route through this exact script - no divergent copy.
##
## The planner owns no scene or input state. Callers provide walkable cells and
## blockers; the returned neutral snapshot is consumed by exploration
## formation selection (S-010/TK-002+) and encounter deployment (S-012).

const FORMATION_IDS: Array[StringName] = [&"line", &"square", &"spaced"]
const FOLLOWER_OFFSETS_RIGHT := {
	&"line": [Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(-3, 0)],
	&"square": [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1)],
	&"spaced": [Vector2i(-2, 0), Vector2i(-2, -2), Vector2i(0, -2)],
}
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
]
const PARTY_SIZE := 4
const MAX_ELEVATION_STEP := 1
const MAX_FALLBACK_DISTANCE := 12


func formation_ids() -> Array[StringName]:
	return FORMATION_IDS.duplicate()


func is_valid_formation(formation_id: StringName) -> bool:
	return FORMATION_IDS.has(formation_id)


func preferred_offsets(formation_id: StringName, facing: Vector2i) -> Array[Vector2i]:
	if not is_valid_formation(formation_id) or not CARDINAL_DIRECTIONS.has(facing):
		return []
	return rotate_offsets(FOLLOWER_OFFSETS_RIGHT[formation_id], facing)


func rotate_offsets(offsets: Array, facing: Vector2i) -> Array[Vector2i]:
	if not CARDINAL_DIRECTIONS.has(facing):
		return []
	var rotated: Array[Vector2i] = []
	for value in offsets:
		var offset: Vector2i = value
		match facing:
			Vector2i.RIGHT:
				rotated.append(offset)
			Vector2i.DOWN:
				rotated.append(Vector2i(-offset.y, offset.x))
			Vector2i.LEFT:
				rotated.append(Vector2i(-offset.x, -offset.y))
			Vector2i.UP:
				rotated.append(Vector2i(offset.y, -offset.x))
	return rotated


func preferred_member_cells(
		formation_id: StringName,
		leader_id: StringName,
		leader_cell: Vector2i,
		facing: Vector2i,
		member_ids: Array) -> Dictionary:
	var offsets := preferred_offsets(formation_id, facing)
	if offsets.size() < member_ids.size() - 1 \
			or not _valid_member_ids(member_ids, leader_id):
		return {}
	var preferred := {leader_id: leader_cell}
	var follower_index := 0
	for value in member_ids:
		var member_id: StringName = value
		if member_id == leader_id:
			continue
		preferred[member_id] = leader_cell + offsets[follower_index]
		follower_index += 1
	return preferred


func plan_deployment(
		formation_id: StringName,
		leader_id: StringName,
		facing: Vector2i,
		member_ids: Array,
		member_cells: Dictionary,
		walkable_cells: Array,
		blocked_cells: Array = [],
		enemy_cells: Array = [],
		prop_cells: Array = [],
		elevation_by_cell: Dictionary = {},
		allowed_elevation_transitions: Array = []) -> Dictionary:
	if not is_valid_formation(formation_id):
		return {}
	if not CARDINAL_DIRECTIONS.has(facing) or not _valid_member_ids(member_ids, leader_id):
		return {}
	for value in member_ids:
		var member_id: StringName = value
		if not member_cells.has(member_id) or not member_cells[member_id] is Vector2i:
			return {}
	var leader_cell: Vector2i = member_cells[leader_id]
	var legal := _legal_cell_set(walkable_cells, blocked_cells, enemy_cells, prop_cells)
	if not legal.has(leader_cell):
		return {}
	var reachable := _reachable_cells(
			leader_cell, legal, elevation_by_cell, allowed_elevation_transitions)
	if reachable.size() < member_ids.size():
		return {}
	var preferred := preferred_member_cells(
			formation_id, leader_id, leader_cell, facing, member_ids)
	if preferred.is_empty():
		return {}
	var deployment := {leader_id: leader_cell}
	var claimed := {leader_cell: true}
	for value in member_ids:
		var member_id: StringName = value
		if member_id == leader_id:
			continue
		var ideal: Vector2i = preferred[member_id]
		var chosen := ideal
		if not reachable.has(chosen) or claimed.has(chosen):
			chosen = _nearest_unclaimed(ideal, leader_cell, reachable, claimed)
		if chosen == Vector2i(999999, 999999):
			return {}
		deployment[member_id] = chosen
		claimed[chosen] = true
	return {
		"formation_id": formation_id,
		"leader_id": leader_id,
		"facing": facing,
		"member_cells": member_cells.duplicate(true),
		"deployment_cells": deployment,
	}


## S-010/TK-004 generalization (D-040): the roster grows from two members to
## four as friends are recruited, so deployment accepts 2..PARTY_SIZE members
## (first N-1 formation offsets apply). Four-member behavior is unchanged and
## stays pinned by the original T-096 suite.
func _valid_member_ids(member_ids: Array, leader_id: StringName) -> bool:
	if member_ids.size() < 2 or member_ids.size() > PARTY_SIZE \
			or not member_ids.has(leader_id):
		return false
	var unique := {}
	for value in member_ids:
		if not value is StringName or unique.has(value):
			return false
		unique[value] = true
	return true


func _legal_cell_set(
		walkable_cells: Array,
		blocked_cells: Array,
		enemy_cells: Array,
		prop_cells: Array) -> Dictionary:
	var legal := {}
	for value in walkable_cells:
		if value is Vector2i:
			legal[value] = true
	for exclusions in [blocked_cells, enemy_cells, prop_cells]:
		for value in exclusions:
			legal.erase(value)
	return legal


func _reachable_cells(
		leader_cell: Vector2i,
		legal: Dictionary,
		elevation_by_cell: Dictionary,
		allowed_elevation_transitions: Array) -> Dictionary:
	var reachable := {leader_cell: true}
	var frontier: Array[Vector2i] = [leader_cell]
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		for direction in CARDINAL_DIRECTIONS:
			var candidate := current + direction
			if not legal.has(candidate) or reachable.has(candidate):
				continue
			if not _can_cross_elevation(
					current, candidate, elevation_by_cell, allowed_elevation_transitions):
				continue
			reachable[candidate] = true
			frontier.append(candidate)
	return reachable


func _can_cross_elevation(
		from_cell: Vector2i,
		to_cell: Vector2i,
		elevation_by_cell: Dictionary,
		allowed_elevation_transitions: Array) -> bool:
	var from_elevation := int(elevation_by_cell.get(from_cell, 0))
	var to_elevation := int(elevation_by_cell.get(to_cell, 0))
	if from_elevation == to_elevation:
		return true
	if absi(to_elevation - from_elevation) > MAX_ELEVATION_STEP:
		return false
	for value in allowed_elevation_transitions:
		if not value is Dictionary:
			continue
		var edge: Dictionary = value
		var edge_from: Vector2i = edge.get("from", Vector2i(999999, 999999))
		var edge_to: Vector2i = edge.get("to", Vector2i(999999, 999999))
		if (
				(edge_from == from_cell and edge_to == to_cell)
				or (edge_from == to_cell and edge_to == from_cell)
		):
			return true
	return false


func _nearest_unclaimed(
		ideal: Vector2i,
		leader_cell: Vector2i,
		reachable: Dictionary,
		claimed: Dictionary) -> Vector2i:
	var invalid := Vector2i(999999, 999999)
	var best := invalid
	var best_ideal_distance := MAX_FALLBACK_DISTANCE + 1
	var best_leader_distance := MAX_FALLBACK_DISTANCE + 1
	for value in reachable.keys():
		var candidate: Vector2i = value
		if claimed.has(candidate):
			continue
		var ideal_distance := _manhattan(candidate, ideal)
		if ideal_distance > MAX_FALLBACK_DISTANCE:
			continue
		var leader_distance := _manhattan(candidate, leader_cell)
		if (
				ideal_distance < best_ideal_distance
				or (ideal_distance == best_ideal_distance and leader_distance < best_leader_distance)
				or (ideal_distance == best_ideal_distance
						and leader_distance == best_leader_distance
						and _cell_before(candidate, best))
		):
			best = candidate
			best_ideal_distance = ideal_distance
			best_leader_distance = leader_distance
	return best


func _cell_before(candidate: Vector2i, current: Vector2i) -> bool:
	return candidate.y < current.y or (candidate.y == current.y and candidate.x < current.x)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
