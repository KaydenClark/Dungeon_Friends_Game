extends "res://tests/gd_test.gd"
## Unit tests for the deterministic decision branches of the overworld enemy AI
## (_act / _step_toward / _step_home / _wander). The real-time *cadence*
## (STEP_INTERVAL accumulation in _process) is timing-driven and covered by the
## slice smoke test; here we drive one decision at a time on a known board and
## assert where the enemy chooses to go. State is read synchronously right after
## the call, before the move tween or the next _process tick.

const SLIME := "res://data/enemies/forest_slime.tres"


func _board(enemy_cell: Vector2i, player_cell: Vector2i) -> Dictionary:
	var g := RoomGrid.new()
	add_child(g)
	g.setup_grid(9, 9)   # roomy and wall-free so pathing is unambiguous
	var player := Player.new()
	g.register(player, player_cell)
	var enemy := OverworldEnemy.new()
	enemy.stats = load(SLIME)
	enemy.home_cell = enemy_cell
	g.register(enemy, enemy_cell)
	enemy.target_player = player
	return {"grid": g, "player": player, "enemy": enemy}


func test_step_toward_closes_distance() -> void:
	var b := _board(Vector2i(2, 2), Vector2i(5, 2))
	b.enemy._step_toward(b.player)
	eq(b.enemy.cell, Vector2i(3, 2), "enemy steps one cell toward the player")
	b.grid.queue_free()


func test_step_toward_adjacent_contacts_without_stepping() -> void:
	# When already next to the player the enemy attacks (start_encounter) rather
	# than stepping onto them, so its own cell must not change.
	var b := _board(Vector2i(2, 2), Vector2i(3, 2))
	b.enemy._step_toward(b.player)
	eq(b.enemy.cell, Vector2i(2, 2), "adjacent enemy holds its cell (contacts, not steps)")
	b.grid.queue_free()


func test_act_tracks_player_in_radius() -> void:
	# dist 3 <= TRACK_RADIUS (4): _act should track, i.e. move closer.
	var b := _board(Vector2i(2, 2), Vector2i(5, 2))
	b.enemy.leash_radius = -1
	b.enemy._act()
	eq(b.enemy.cell, Vector2i(3, 2), "in-radius _act closes on the player")
	b.grid.queue_free()


func test_act_returns_home_when_leashed_and_strayed() -> void:
	# Player out of track range, enemy past its leash: _act walks it home.
	var b := _board(Vector2i(6, 2), Vector2i(8, 8))
	b.enemy.home_cell = Vector2i(2, 2)       # strayed: home dist is 4 > leash 2
	b.enemy.leash_radius = 2
	b.enemy._act()
	eq(b.enemy.cell, Vector2i(5, 2), "strayed leashed enemy steps back toward home")
	b.grid.queue_free()


func test_wander_idles_when_leash_is_zero() -> void:
	# A zero leash means every neighbour exceeds it, so _wander must idle in
	# place regardless of which direction the RNG picks.
	SceneManager.rng.seed = 42
	var b := _board(Vector2i(4, 4), Vector2i(0, 0))
	b.enemy.leash_radius = 0
	b.enemy._wander()
	eq(b.enemy.cell, Vector2i(4, 4), "zero-leash enemy stays put")
	b.grid.queue_free()


func test_step_home_moves_toward_home() -> void:
	var b := _board(Vector2i(5, 2), Vector2i(8, 8))
	b.enemy.home_cell = Vector2i(2, 2)
	b.enemy._step_home()
	eq(b.enemy.cell, Vector2i(4, 2), "enemy steps one cell toward home")
	b.grid.queue_free()
