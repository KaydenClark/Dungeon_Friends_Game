extends "res://tests/gd_test.gd"
## Unit tests for PushableBlock (T-023) - the one-cell push contract and the
## block-fills-pit rule (T-025). Like GridActor.try_step, all state a push
## mutates (cell, occupancy, moving) is set synchronously before the tween
## awaits, so these assert right after the call.


func _make_grid(w := 6, h := 6) -> RoomGrid:
	var g := RoomGrid.new()
	add_child(g)
	g.setup_grid(w, h)
	return g


func _block(g: RoomGrid, c: Vector2i) -> PushableBlock:
	var b := PushableBlock.new()
	g.register(b, c)
	return b


func test_push_into_free_cell_moves_block() -> void:
	var g := _make_grid()
	var b := _block(g, Vector2i(2, 2))
	ok(b.try_push(Vector2i.RIGHT), "push into a free cell succeeds")
	eq(b.cell, Vector2i(3, 2), "block cell advances one cell")
	eq(g.get_occupant(Vector2i(3, 2)), b, "occupancy follows the block")
	is_null(g.get_occupant(Vector2i(2, 2)), "origin cell released")
	g.queue_free()


func test_push_into_wall_is_refused() -> void:
	var g := _make_grid()
	var b := _block(g, Vector2i(2, 2))
	g.set_blocked(Vector2i(3, 2), true)
	not_ok(b.try_push(Vector2i.RIGHT), "push into a wall is refused")
	eq(b.cell, Vector2i(2, 2), "block stays put")
	g.queue_free()


func test_push_into_occupant_is_refused() -> void:
	var g := _make_grid()
	var b := _block(g, Vector2i(2, 2))
	var other := _block(g, Vector2i(3, 2))
	not_ok(b.try_push(Vector2i.RIGHT), "push into another occupant is refused")
	eq(b.cell, Vector2i(2, 2), "block stays put")
	eq(other.cell, Vector2i(3, 2), "no chain-pushing: the second block never moves")
	g.queue_free()


func test_fixed_brick_refuses_every_push() -> void:
	# movable=false (the hub's Oracle-style wall, 2026-07-07): identical
	# look, occupies its cell, but never budges in any direction.
	var g := _make_grid()
	var b := _block(g, Vector2i(2, 2))
	b.movable = false
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		not_ok(b.try_push(d), "fixed brick refuses push %s" % str(d))
	eq(b.cell, Vector2i(2, 2), "fixed brick never moves")
	eq(g.get_occupant(Vector2i(2, 2)), b, "fixed brick still occupies its cell")
	g.queue_free()


func test_push_off_grid_is_refused() -> void:
	var g := _make_grid()
	var b := _block(g, Vector2i(0, 2))
	not_ok(b.try_push(Vector2i.LEFT), "push off the grid edge is refused")
	eq(b.cell, Vector2i(0, 2), "block stays on the grid")
	g.queue_free()


func test_player_bump_pushes_but_never_overlaps() -> void:
	var g := _make_grid()
	var p := Player.new()
	g.register(p, Vector2i(1, 2))
	var b := _block(g, Vector2i(2, 2))
	var stepped: bool = p.try_step(Vector2i.RIGHT)
	not_ok(stepped, "the bump frame never steps the player")
	eq(p.cell, Vector2i(1, 2), "player stays put while the block moves")
	eq(b.cell, Vector2i(3, 2), "bump pushed the block one cell")
	ne(p.cell, b.cell, "player and block never share a cell")
	g.queue_free()


func test_push_into_pit_sinks_and_fills() -> void:
	var g := _make_grid()
	var b := _block(g, Vector2i(2, 2))
	g.set_pit(Vector2i(3, 2), true)
	not_ok(g.is_walkable(Vector2i(3, 2)), "pit cell unwalkable before the fill")
	ok(b.try_push(Vector2i.RIGHT), "push into a pit succeeds (the block sinks)")
	is_null(g.get_occupant(Vector2i(2, 2)), "origin cell released")
	is_null(g.get_occupant(Vector2i(3, 2)), "sunk block is floor, not an occupant")
	# The fill lands when the sink tween ends; wait for it.
	await b.move_finished
	ok(b.sunk, "block marked sunk")
	not_ok(g.is_pit(Vector2i(3, 2)), "pit is gone")
	ok(g.is_walkable(Vector2i(3, 2)), "filled pit is walkable floor")
	not_ok(b.try_push(Vector2i.RIGHT), "a sunk block can never be pushed again")
	g.queue_free()


func test_reset_returns_block_to_start() -> void:
	var g := _make_grid()
	var b := _block(g, Vector2i(2, 2))
	b.try_push(Vector2i.RIGHT)
	b.moving = false   # cut the tween short; logical state is already at (3,2)
	g.reset_puzzle()
	eq(b.cell, Vector2i(2, 2), "reset returns the block to its starting cell")
	eq(g.get_occupant(Vector2i(2, 2)), b, "occupancy follows the reset")
	is_null(g.get_occupant(Vector2i(3, 2)), "pushed-to cell released by the reset")
	g.queue_free()
