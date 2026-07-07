extends "res://tests/gd_test.gd"
## Unit tests for RoomGrid: bounds, static blocking, occupancy bookkeeping,
## cell<->pixel mapping, and AStarGrid2D pathfinding (no diagonals, avoid-
## occupants routing). This is the runtime grid model every overworld room
## sits on, so its invariants (never two occupants on a cell, walls block
## paths) are load-bearing.

var _grid: RoomGrid


func _make_grid(w := 5, h := 4) -> RoomGrid:
	var g := RoomGrid.new()
	add_child(g)          # in-tree so register()/add_child works
	g.setup_grid(w, h)
	return g


func _occupant() -> Node2D:
	# A plain (non-GridActor) occupant, e.g. an NPC or door.
	return Node2D.new()


func test_in_bounds() -> void:
	var g := _make_grid()
	ok(g.in_bounds(Vector2i(0, 0)), "origin in bounds")
	ok(g.in_bounds(Vector2i(4, 3)), "far corner in bounds")
	not_ok(g.in_bounds(Vector2i(5, 0)), "x past width is out")
	not_ok(g.in_bounds(Vector2i(0, 4)), "y past height is out")
	not_ok(g.in_bounds(Vector2i(-1, 0)), "negative is out")
	g.queue_free()


func test_walkable_and_blocking() -> void:
	var g := _make_grid()
	var c := Vector2i(2, 2)
	ok(g.is_walkable(c), "empty in-bounds cell is walkable")
	g.set_blocked(c, true)
	not_ok(g.is_walkable(c), "blocked cell is not walkable")
	g.set_blocked(c, false)
	ok(g.is_walkable(c), "unblocked cell is walkable again")
	not_ok(g.is_walkable(Vector2i(-1, 0)), "out-of-bounds is never walkable")
	g.queue_free()


func test_occupancy_register_and_query() -> void:
	var g := _make_grid()
	var c := Vector2i(1, 1)
	var occ := _occupant()
	g.register(occ, c)
	eq(g.get_occupant(c), occ, "registered occupant is found")
	not_ok(g.is_walkable(c), "occupied cell is not walkable")
	eq(occ.position, g.cell_to_pos(c), "static occupant snapped to cell centre")
	g.queue_free()


func test_move_occupant_updates_map() -> void:
	var g := _make_grid()
	var from := Vector2i(1, 1)
	var to := Vector2i(1, 2)
	var occ := _occupant()
	g.register(occ, from)
	g.move_occupant(occ, from, to)
	is_null(g.get_occupant(from), "old cell freed after move")
	eq(g.get_occupant(to), occ, "new cell holds the occupant")
	g.queue_free()


func test_unregister_removes_occupant() -> void:
	var g := _make_grid()
	var c := Vector2i(3, 1)
	var occ := _occupant()
	g.register(occ, c)
	g.unregister(occ)
	is_null(g.get_occupant(c), "unregistered occupant is gone")
	ok(g.is_walkable(c), "cell walkable again after unregister")
	g.queue_free()


func test_cell_to_pos_centres_on_tile() -> void:
	var g := _make_grid()
	# TILE is 64; cell (1,1) centre = (64,64) + (32,32).
	eq(g.cell_to_pos(Vector2i(0, 0)), Vector2(32, 32), "origin centre")
	eq(g.cell_to_pos(Vector2i(1, 1)), Vector2(96, 96), "cell (1,1) centre")
	g.queue_free()


func test_find_path_straight_line() -> void:
	var g := _make_grid()
	var path := g.find_path(Vector2i(0, 0), Vector2i(3, 0))
	eq(path.size(), 4, "4 cells from x=0 to x=3 inclusive")
	eq(path[0], Vector2i(0, 0), "path starts at origin")
	eq(path[path.size() - 1], Vector2i(3, 0), "path ends at target")
	g.queue_free()


func test_find_path_no_diagonals() -> void:
	# Manhattan-only: (0,0)->(1,1) must be 3 cells (one orthogonal detour),
	# never a 2-cell diagonal hop (locked decision: DIAGONAL_MODE_NEVER).
	var g := _make_grid()
	var path := g.find_path(Vector2i(0, 0), Vector2i(1, 1))
	eq(path.size(), 3, "diagonal target reached in 3 orthogonal cells")
	g.queue_free()


func test_find_path_routes_around_wall() -> void:
	var g := _make_grid()
	# Wall the whole column x=2 except the top row, forcing a detour up-and-over.
	g.set_blocked(Vector2i(2, 1), true)
	g.set_blocked(Vector2i(2, 2), true)
	g.set_blocked(Vector2i(2, 3), true)
	var path := g.find_path(Vector2i(0, 2), Vector2i(4, 2))
	ok(path.size() > 0, "a path exists around the wall")
	for c in path:
		not_ok(c == Vector2i(2, 1) or c == Vector2i(2, 2) or c == Vector2i(2, 3),
				"path never crosses a blocked cell")
	g.queue_free()


func test_find_path_out_of_bounds_is_empty() -> void:
	var g := _make_grid()
	eq(g.find_path(Vector2i(0, 0), Vector2i(9, 9)).size(), 0, "off-grid target -> empty")
	eq(g.find_path(Vector2i(-1, 0), Vector2i(0, 0)).size(), 0, "off-grid start -> empty")
	g.queue_free()


func test_find_path_avoids_occupants_but_keeps_endpoints_open() -> void:
	var g := _make_grid()
	# Occupy the direct corridor so avoid_occupants must detour, yet a path that
	# ends *on* an occupant (walking into an enemy) must still resolve.
	var blocker := _occupant()
	g.register(blocker, Vector2i(2, 2))
	var around := g.find_path(Vector2i(0, 2), Vector2i(4, 2), true)
	ok(around.size() > 0, "detours around a mid-corridor occupant")
	for c in around:
		not_ok(c == Vector2i(2, 2), "detour path skips the occupied cell")

	var target := _occupant()
	g.register(target, Vector2i(4, 2))
	var into := g.find_path(Vector2i(0, 2), Vector2i(4, 2), true)
	ok(into.size() > 0, "path *to* an occupant still resolves (endpoint stays open)")
	eq(into[into.size() - 1], Vector2i(4, 2), "path ends on the target occupant")
	g.queue_free()
