extends "res://tests/gd_test.gd"
## Unit tests for GridActor.try_step -- the movement contract shared by the
## player and every overworld enemy. All state the step mutates (facing,
## occupancy reservation, cell, moving flag) is set synchronously *before* the
## tween awaits, so these assert that state right after the call without
## waiting out the animation.

var _grid: RoomGrid


func _make_grid(w := 5, h := 4) -> RoomGrid:
	var g := RoomGrid.new()
	add_child(g)
	g.setup_grid(w, h)
	return g


func _actor(g: RoomGrid, c: Vector2i) -> GridActor:
	var a := GridActor.new()
	g.register(a, c)   # register() calls attach() for GridActors
	return a


func test_step_into_free_cell_reserves_and_moves() -> void:
	var g := _make_grid()
	var a := _actor(g, Vector2i(1, 1))
	var target := Vector2i(1, 2)
	var started: bool = a.try_step(Vector2i.DOWN)
	ok(started, "step into a free walkable cell starts")
	eq(a.cell, target, "logical cell advances immediately")
	eq(a.facing, Vector2i.DOWN, "facing set to step direction")
	ok(a.moving, "moving flag set for the tween")
	eq(g.get_occupant(target), a, "occupancy reserved at the destination")
	is_null(g.get_occupant(Vector2i(1, 1)), "origin cell released")
	g.queue_free()


func test_step_into_wall_is_refused() -> void:
	var g := _make_grid()
	var a := _actor(g, Vector2i(1, 1))
	g.set_blocked(Vector2i(1, 0), true)
	var started: bool = a.try_step(Vector2i.UP)
	not_ok(started, "step into a wall is refused")
	eq(a.cell, Vector2i(1, 1), "actor stays put")
	eq(a.facing, Vector2i.UP, "still turns to face the wall")
	g.queue_free()


func test_step_off_grid_is_refused() -> void:
	var g := _make_grid()
	var a := _actor(g, Vector2i(0, 1))
	var started: bool = a.try_step(Vector2i.LEFT)
	not_ok(started, "step off the grid edge is refused")
	eq(a.cell, Vector2i(0, 1), "actor stays on the grid")
	g.queue_free()


func test_step_into_occupant_bumps_not_moves() -> void:
	var g := _make_grid()
	var mover: GridActor = load("res://tests/doubles/bumping_actor.gd").new()
	g.register(mover, Vector2i(1, 1))
	var blocker := _actor(g, Vector2i(1, 2))
	var started: bool = mover.try_step(Vector2i.DOWN)
	not_ok(started, "step into an occupied cell does not move")
	eq(mover.cell, Vector2i(1, 1), "bumper stays put")
	eq(mover.bumped, blocker, "_on_bump fired with the blocking occupant")
	g.queue_free()


func test_moving_actor_ignores_new_step() -> void:
	var g := _make_grid()
	var a := _actor(g, Vector2i(1, 1))
	a.moving = true   # simulate a tween already in flight
	var started: bool = a.try_step(Vector2i.DOWN)
	not_ok(started, "a second step is refused while already moving")
	eq(a.cell, Vector2i(1, 1), "cell unchanged during an in-flight move")
	g.queue_free()


func test_detached_actor_cannot_step() -> void:
	var a := GridActor.new()
	add_child(a)   # in tree but never attached to a room
	not_ok(a.try_step(Vector2i.DOWN), "an actor with no room can't step")
	a.queue_free()
