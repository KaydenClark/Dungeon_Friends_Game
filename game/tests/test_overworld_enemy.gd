extends "res://tests/gd_test.gd"
## Unit tests for the deterministic slices of OverworldEnemy: its Manhattan
## distance helper (the basis of the TRACK_RADIUS / leash checks) and the
## defeated() cleanup that removes a beaten enemy from both the occupancy map
## and the room's enemy list. The timer-driven wander/track AI is covered end
## to end by the slice smoke test, not re-simulated here.


func test_manhattan_distance() -> void:
	var e := OverworldEnemy.new()   # not in tree -> _ready visuals skipped
	eq(e._manhattan(Vector2i(0, 0), Vector2i(3, 4)), 7, "3+4 = 7")
	eq(e._manhattan(Vector2i(2, 2), Vector2i(2, 2)), 0, "same cell = 0")
	eq(e._manhattan(Vector2i(5, 1), Vector2i(2, 1)), 3, "horizontal only")
	e.free()


func test_defeated_clears_occupancy_and_roster() -> void:
	var g := RoomGrid.new()
	add_child(g)
	g.setup_grid(5, 4)
	var e := OverworldEnemy.new()
	e.stats = load("res://data/enemies/forest_slime.tres")
	var c := Vector2i(2, 2)
	g.register(e, c)
	g.enemies.append(e)
	eq(g.get_occupant(c), e, "enemy occupies its cell before defeat")

	e.defeated()
	is_null(g.get_occupant(c), "cell freed after defeat")
	ok(g.is_walkable(c), "cell walkable after the enemy is removed")
	not_ok(g.enemies.has(e), "enemy dropped from the room roster")
	g.queue_free()
