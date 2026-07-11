extends "res://tests/gd_test.gd"
## Unit tests for pit falls (T-047, D-008 part 4 - supersedes "pits are
## impassable" for the PLAYER only). Walking into a pit is a Zelda-style
## fall: 10 HP to every party member (Kayden's 2026-07-10 windowed-playtest
## correction) and a respawn at the room's entry cell
## (the last entrance the player came through). Jumping is unchanged and
## never falls; enemies and pathfinding still treat pits as solid; a fall
## that reaches 0 HP chains into the T-041 defeat flow.


func _make_grid(w := 8, h := 5) -> RoomGrid:
	var g := RoomGrid.new()
	add_child(g)
	g.setup_grid(w, h)
	g.entry_cell = Vector2i(1, 2)
	return g


func _player(g: RoomGrid, c: Vector2i, face := Vector2i.RIGHT) -> Player:
	var p := Player.new()
	g.register(p, c)
	p.set_facing(face)
	return p


func _settle(p: Player, max_frames := 240) -> void:
	for i in max_frames:
		if not p.moving:
			return
		await get_tree().process_frame


func test_walking_into_a_pit_falls_and_respawns_at_entry() -> void:
	SceneManager.reset_session_state()
	var g := _make_grid()
	g.set_pit(Vector2i(3, 2), true)
	var p := _player(g, Vector2i(2, 2))
	SceneManager.state.party_hp["companion_test"] = 14
	var hp_before: int = SceneManager.hero_hp
	ok(p.try_step(Vector2i.RIGHT), "stepping at a pit is accepted (as a fall)")
	await _settle(p)
	eq(p.cell, g.entry_cell, "player respawns at the room's entry cell")
	eq(g.get_occupant(g.entry_cell), p, "occupancy follows the respawn")
	is_null(g.get_occupant(Vector2i(2, 2)), "takeoff cell released")
	is_null(g.get_occupant(Vector2i(3, 2)), "the pit cell was never claimed")
	eq(SceneManager.hero_hp, hp_before - p.fall_damage(), "the fall costs 10 HP")
	eq(SceneManager.state.party_hp["companion_test"], 4,
			"the single overworld avatar's fall injures Buddy too")
	eq(p.fall_damage(), 10, "pit falls deal a flat, consequential 10 HP")
	ok(g.is_pit(Vector2i(3, 2)), "the pit itself is unchanged")
	g.queue_free()
	SceneManager.reset_session_state()


func test_jump_still_crosses_without_damage() -> void:
	SceneManager.reset_session_state()
	var g := _make_grid()
	g.set_pit(Vector2i(3, 2), true)
	var p := _player(g, Vector2i(2, 2))
	var hp_before: int = SceneManager.hero_hp
	ok(p.try_jump(), "jumping the 1-cell pit still works")
	await _settle(p)
	eq(p.cell, Vector2i(4, 2), "jump lands on the far side - no fall")
	eq(SceneManager.hero_hp, hp_before, "a jump never costs HP")
	g.queue_free()
	SceneManager.reset_session_state()


func test_enemies_still_treat_pits_as_solid() -> void:
	var g := _make_grid()
	g.set_pit(Vector2i(3, 2), true)
	var e := OverworldEnemy.new()
	e.stats = load("res://data/enemies/forest_slime.tres")
	g.register(e, Vector2i(2, 2))
	e.set_facing(Vector2i.RIGHT)
	not_ok(e.try_step(Vector2i.RIGHT), "an enemy is refused at the pit edge")
	eq(e.cell, Vector2i(2, 2), "enemy stays put")
	g.queue_free()


func test_fall_to_zero_hp_chains_into_the_defeat_flow() -> void:
	SceneManager.reset_session_state()
	SceneManager.current_room = null   # unregistered room -> legacy restart
	var g := _make_grid()
	g.set_pit(Vector2i(3, 2), true)
	var p := _player(g, Vector2i(2, 2))
	SceneManager.hero_hp = 1
	SceneManager.total_xp = 30
	ok(p.try_step(Vector2i.RIGHT), "the fatal step is accepted")
	await _settle(p)
	for i in 60:   # let the unawaited defeat coroutine run out
		if SceneManager.total_xp == 0:
			break
		await get_tree().process_frame
	eq(SceneManager.total_xp, 0, "0 HP fall triggered the defeat flow")
	eq(SceneManager.hero_hp, SceneManager.hero_stats.max_hp,
			"defeat recovery restored HP")
	g.queue_free()
	SceneManager.reset_session_state()
