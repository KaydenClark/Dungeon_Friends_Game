extends "res://tests/gd_test.gd"
## Unit tests for the player jump (T-025, locked rule): a deliberate button
## press that hops exactly one cell over a jumpable gap in the facing
## direction. Max jump distance is exactly 1 cell - a 1-cell pit is the
## definitional jumpable gap, 2+ cells is never jumpable. Refused jumps
## (wall ahead, too-wide pit, plain floor) stay in place.


func _make_grid(w := 8, h := 5) -> RoomGrid:
	var g := RoomGrid.new()
	add_child(g)
	g.setup_grid(w, h)
	return g


func _player(g: RoomGrid, c: Vector2i, face := Vector2i.RIGHT) -> Player:
	var p := Player.new()
	g.register(p, c)
	p.set_facing(face)
	return p


func test_one_cell_pit_is_jumpable() -> void:
	var g := _make_grid()
	g.set_pit(Vector2i(3, 2), true)
	var p := _player(g, Vector2i(2, 2))
	ok(p.try_jump(), "jump over a 1-cell pit succeeds")
	eq(p.cell, Vector2i(4, 2), "player lands on the far side")
	eq(g.get_occupant(Vector2i(4, 2)), p, "occupancy reserved at the landing cell")
	is_null(g.get_occupant(Vector2i(2, 2)), "takeoff cell released")
	g.queue_free()


func test_two_cell_pit_is_never_jumpable() -> void:
	var g := _make_grid()
	g.set_pit(Vector2i(3, 2), true)
	g.set_pit(Vector2i(4, 2), true)
	var p := _player(g, Vector2i(2, 2))
	not_ok(p.try_jump(), "a 2-cell pit is beyond the jump limit")
	eq(p.cell, Vector2i(2, 2), "player stays put (in-place hop)")
	g.queue_free()


func test_jump_into_wall_is_refused() -> void:
	var g := _make_grid()
	g.set_pit(Vector2i(3, 2), true)
	g.set_blocked(Vector2i(4, 2), true)   # wall on the landing cell
	var p := _player(g, Vector2i(2, 2))
	not_ok(p.try_jump(), "jump with a wall on the landing cell is refused")
	eq(p.cell, Vector2i(2, 2), "player stays put")
	g.queue_free()


func test_jump_on_plain_floor_is_refused() -> void:
	var g := _make_grid()
	var p := _player(g, Vector2i(2, 2))
	not_ok(p.try_jump(), "jump succeeds only over a gap, not on plain floor")
	eq(p.cell, Vector2i(2, 2), "player stays put")
	g.queue_free()


func test_jump_onto_occupant_is_refused() -> void:
	var g := _make_grid()
	g.set_pit(Vector2i(3, 2), true)
	var blocker := PushableBlock.new()
	g.register(blocker, Vector2i(4, 2))
	var p := _player(g, Vector2i(2, 2))
	not_ok(p.try_jump(), "jump onto an occupied landing cell is refused")
	eq(p.cell, Vector2i(2, 2), "player stays put")
	g.queue_free()


func test_unfilled_pit_blocks_walking_and_pathing() -> void:
	# T-047 supersedes the old "stepping into a pit is refused" player rule -
	# the player now FALLS (see test_pit_fall.gd); walkability and pathing
	# still treat pits as solid.
	var g := _make_grid()
	g.set_pit(Vector2i(3, 2), true)
	not_ok(g.is_walkable(Vector2i(3, 2)), "pit cell is not walkable")
	# Pathing must route around the pit column, never through it.
	for y in g.height:
		g.set_pit(Vector2i(3, y), true)
	var path := g.find_path(Vector2i(2, 2), Vector2i(4, 2))
	eq(path.size(), 0, "a full pit column is impassable to pathfinding")
	g.queue_free()


func test_filled_pit_is_walkable_and_jumpable_from() -> void:
	var g := _make_grid()
	# The tutorial Room 2 shape: a 2-wide pit, one cell filled by the block.
	g.set_pit(Vector2i(3, 2), true)
	g.set_pit(Vector2i(4, 2), true)
	var b := PushableBlock.new()
	g.register(b, Vector2i(2, 2))
	var p := _player(g, Vector2i(1, 2))
	b.try_push(Vector2i.RIGHT)   # sink into the near pit cell
	await b.move_finished
	ok(g.is_walkable(Vector2i(3, 2)), "filled pit cell is walkable floor")
	ok(p.try_step(Vector2i.RIGHT), "player can walk toward the gap")
	p.moving = false
	ok(p.try_step(Vector2i.RIGHT), "player can stand on the filled cell")
	p.moving = false
	eq(p.cell, Vector2i(3, 2), "player stands where the pit used to be")
	ok(p.try_jump(), "the remaining 1-cell gap is jumpable from the filled cell")
	eq(p.cell, Vector2i(5, 2), "player lands beyond the pit")
	g.queue_free()
