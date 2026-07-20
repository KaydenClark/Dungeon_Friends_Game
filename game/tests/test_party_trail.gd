extends "res://tests/gd_test.gd"
## S-009/TK-003 strict red/green suite for the pure production party-trail
## model (D-029). Followers replay leader breadcrumbs as render-only cells:
## always walkable, always distinct from each other and the leader, never
## contributing occupancy. A non-adjacent leader move (teleport, room restore,
## pit-fall respawn) reseeds the whole trail near the leader. snapshot_cells()
## is the deterministic world-state projection: render cells when free, else
## nearest free walkable cells, else a named refusal ({} - fail closed).

const PartyTrailModel := preload("res://scripts/overworld/party_trail.gd")

var _walls := {}


func _walkable(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < 8 and cell.y < 6 \
			and not _walls.has(cell)


func _make_trail(follower_ids: Array, leader_cell: Vector2i) -> RefCounted:
	var trail := PartyTrailModel.new()
	trail.setup(follower_ids, leader_cell, _walkable)
	return trail


func _distinct(cells: Dictionary, leader_cell: Vector2i) -> bool:
	var seen := {leader_cell: true}
	for id in cells:
		if seen.has(cells[id]):
			return false
		seen[cells[id]] = true
	return true


func test_setup_seeds_distinct_walkable_cells() -> void:
	_walls = {}
	var trail := _make_trail(["companion_test"], Vector2i(3, 3))
	var cells: Dictionary = trail.follower_cells()
	eq(cells.size(), 1, "one follower seeded")
	ok(_walkable(cells["companion_test"]), "seed cell is walkable")
	ne(cells["companion_test"], Vector2i(3, 3), "seed cell is not the leader")
	var full := _make_trail(["a", "b", "c"], Vector2i(3, 3))
	ok(_distinct(full.follower_cells(), Vector2i(3, 3)),
			"three followers seed on distinct cells")


func test_breadcrumb_replay_on_adjacent_steps() -> void:
	_walls = {}
	var trail := _make_trail(["companion_test"], Vector2i(1, 1))
	trail.leader_moved(Vector2i(2, 1))
	eq(trail.follower_cells()["companion_test"], Vector2i(1, 1),
			"follower takes the leader's vacated breadcrumb")
	trail.leader_moved(Vector2i(3, 1))
	eq(trail.follower_cells()["companion_test"], Vector2i(2, 1),
			"follower keeps trailing one breadcrumb behind")


func test_followers_stay_off_walls() -> void:
	_walls = {Vector2i(1, 1): true}
	var trail := _make_trail(["a", "b"], Vector2i(2, 1))
	var cells: Dictionary = trail.follower_cells()
	for id in cells:
		ok(_walkable(cells[id]), "follower %s avoids walls at seed" % id)
	trail.leader_moved(Vector2i(3, 1))
	trail.leader_moved(Vector2i(3, 2))
	cells = trail.follower_cells()
	for id in cells:
		ok(_walkable(cells[id]), "follower %s avoids walls while trailing" % id)
	ok(_distinct(cells, Vector2i(3, 2)), "trailing cells stay distinct")


func test_single_file_through_choke() -> void:
	# Corridor row y=2: walls above and below leave a one-cell channel.
	_walls = {}
	for x in range(0, 8):
		_walls[Vector2i(x, 1)] = true
		_walls[Vector2i(x, 3)] = true
	_walls.erase(Vector2i(0, 1))   # entry pocket so setup has room
	var trail := _make_trail(["a", "b"], Vector2i(1, 2))
	for x in range(2, 6):
		trail.leader_moved(Vector2i(x, 2))
	var cells: Dictionary = trail.follower_cells()
	eq(cells["a"], Vector2i(4, 2), "first follower single-files behind")
	eq(cells["b"], Vector2i(3, 2), "second follower single-files further back")


func test_non_adjacent_leader_move_reseeds() -> void:
	_walls = {}
	var trail := _make_trail(["a", "b"], Vector2i(1, 1))
	trail.leader_moved(Vector2i(2, 1))
	trail.leader_moved(Vector2i(6, 4))   # teleport-sized jump
	var cells: Dictionary = trail.follower_cells()
	for id in cells:
		ok(_walkable(cells[id]), "reseeded cell walkable for %s" % id)
		var dist: int = absi(cells[id].x - 6) + absi(cells[id].y - 4)
		ok(dist <= 2, "reseeded follower %s is near the leader" % id)
	ok(_distinct(cells, Vector2i(6, 4)), "reseeded cells distinct")


func test_snapshot_cells_prefers_render_cells() -> void:
	_walls = {}
	var trail := _make_trail(["companion_test"], Vector2i(1, 1))
	trail.leader_moved(Vector2i(2, 1))
	var render_cell: Vector2i = trail.follower_cells()["companion_test"]
	var snapshot: Dictionary = trail.snapshot_cells({Vector2i(2, 1): true})
	eq(snapshot["companion_test"], render_cell,
			"free render cell is used verbatim")


func test_snapshot_cells_resolves_collisions_deterministically() -> void:
	_walls = {}
	var trail := _make_trail(["companion_test"], Vector2i(1, 1))
	trail.leader_moved(Vector2i(2, 1))
	var render_cell: Vector2i = trail.follower_cells()["companion_test"]
	# An occupant (e.g. a wandering enemy actor) sits on the render cell.
	var occupied := {Vector2i(2, 1): true, render_cell: true}
	var snapshot: Dictionary = trail.snapshot_cells(occupied)
	ne(snapshot["companion_test"], render_cell,
			"occupied render cell is not reused")
	ok(_walkable(snapshot["companion_test"]), "resolved cell is walkable")
	not_ok(occupied.has(snapshot["companion_test"]),
			"resolved cell avoids occupied cells")
	var again: Dictionary = trail.snapshot_cells(occupied)
	eq(again, snapshot, "resolution is deterministic")


func test_snapshot_cells_fails_closed_when_unplaceable() -> void:
	# Wall off everything except the leader's cell and one occupied cell.
	_walls = {}
	for x in range(0, 8):
		for y in range(0, 6):
			_walls[Vector2i(x, y)] = true
	_walls.erase(Vector2i(1, 1))
	_walls.erase(Vector2i(2, 1))
	var trail := _make_trail(["companion_test"], Vector2i(1, 1))
	var snapshot: Dictionary = trail.snapshot_cells(
			{Vector2i(1, 1): true, Vector2i(2, 1): true})
	eq(snapshot, {}, "unplaceable follower refuses the snapshot (fail closed)")
