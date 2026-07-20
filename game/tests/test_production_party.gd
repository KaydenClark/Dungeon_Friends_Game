extends "res://tests/gd_test.gd"
## S-009/TK-003 strict red/green suite: the visible pass-through party in the
## production room lifecycle (D-029). The roster's leader is the existing
## Player; every other roster member becomes a render-only PartyFollower that
## never touches grid occupancy, never presses plates, never blocks the
## leader, and appears in the neutral WorldState snapshot as a party actor at
## a deterministic distinct cell.

const WorldState := preload("res://scripts/world/world_state.gd")
const FIXTURE := "res://assets/levels/entity_test_room.ldtk"


func _make_room() -> LdtkRoom:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	return room


func _teardown(room: LdtkRoom) -> void:
	room.queue_free()
	SceneManager.reset_session_state()
	SceneManager.flags = {}


func _step(room: LdtkRoom, dir: Vector2i) -> void:
	room.player.try_step(dir)
	await room.player.move_finished


func test_followers_spawn_with_the_room() -> void:
	var room := _make_room()
	eq(room.party_leader_id, "hero", "roster leader identity recorded")
	eq(room.party_followers.size(), 1,
			"one follower per non-leader roster member")
	if room.party_followers.size() == 1:
		var follower: PartyFollower = room.party_followers[0]
		eq(follower.member_id, "companion_test", "follower keyed by roster id")
		ok(follower.is_inside_tree(), "follower node lives in the room")
		not_null(follower.body, "follower has a visible body")
		ok(room.party_trail != null, "party trail model attached")
	_teardown(room)


func test_followers_never_occupy_the_grid() -> void:
	var room := _make_room()
	for cell in room.occupants:
		not_ok(room.occupants[cell] is PartyFollower,
				"no follower in the occupancy map at %s" % cell)
	if room.party_followers.size() == 1:
		var follower: PartyFollower = room.party_followers[0]
		ok(room.is_walkable(follower.cell),
				"the follower's render cell stays walkable (pass-through)")
	_teardown(room)


func test_leader_walks_through_follower_cells() -> void:
	var room := _make_room()
	# Step right then immediately back: the follower's breadcrumb is the
	# vacated spawn cell, and walking straight back through it must succeed.
	await _step(room, Vector2i.RIGHT)
	var follower: PartyFollower = room.party_followers[0]
	eq(follower.cell, Vector2i(2, 2),
			"follower trails on the leader's vacated cell")
	await _step(room, Vector2i.LEFT)
	eq(room.player.cell, Vector2i(2, 2),
			"leader steps back through the follower's rendered cell")
	_teardown(room)


func test_follower_on_plate_does_not_press_it() -> void:
	var room := _make_room()
	var plate: PressurePlate = room.plates[0]
	# Walk the leader across the plate at (2, 5) and one step off it: the
	# follower breadcrumb lands on the plate while the leader stands aside.
	await _step(room, Vector2i.DOWN)   # (2,3)
	await _step(room, Vector2i.DOWN)   # (2,4)
	await _step(room, Vector2i.DOWN)   # (2,5) leader on plate
	ok(plate.pressed, "the leader (a real occupant) presses the plate")
	await _step(room, Vector2i.LEFT)   # leader to (1,5), follower to (2,5)
	var follower: PartyFollower = room.party_followers[0]
	eq(follower.cell, Vector2i(2, 5), "follower rendered on the plate cell")
	not_ok(plate.pressed,
			"a pass-through follower never presses the plate (D-029)")
	_teardown(room)


func test_snapshot_includes_party_actors() -> void:
	var room := _make_room()
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "party room snapshots without error")
	if data.has("error"):
		_teardown(room)
		return
	eq(WorldState.validate(data), "", "party snapshot validates")
	eq(data["party"]["leader"], "hero", "leader keyed by roster id")
	eq(data["party"]["members"], ["hero", "companion_test"],
			"members are the full roster in order")
	eq(data["actors"]["hero"]["kind"], "party", "leader actor is party kind")
	eq(data["actors"]["hero"]["cell"], Vector2i(2, 2),
			"leader actor at the player's cell")
	eq(data["actors"]["companion_test"]["kind"], "party",
			"follower actor is party kind")
	ne(data["actors"]["companion_test"]["cell"], Vector2i(2, 2),
			"follower snapshot cell distinct from the leader")
	_teardown(room)


func test_teleport_reseeds_followers() -> void:
	var room := _make_room()
	room.teleport(room.player, Vector2i(9, 1))
	var follower: PartyFollower = room.party_followers[0]
	var dist: int = absi(follower.cell.x - 9) + absi(follower.cell.y - 1)
	ok(dist >= 1 and dist <= 2,
			"follower reseeds beside the teleported leader (got %s)"
			% str(follower.cell))
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "post-teleport snapshot has no error")
	if not data.has("error"):
		eq(data["actors"]["hero"]["cell"], Vector2i(9, 1),
				"leader actor at the teleport target")
	_teardown(room)


func test_room_formation_selection() -> void:
	var room := _make_room()
	eq(room.party_formation(), &"line", "rooms start on the default formation")
	not_ok(room.set_party_formation(&"wedge"), "unknown formation refused")
	ok(room.set_party_formation(&"spaced"), "known formation accepted")
	eq(room.party_formation(), &"spaced", "room reports the selection")
	# Walk down open floor; the follower must keep trailing near the leader
	# whatever mix of formation and catch-up placement applies.
	await _step(room, Vector2i.DOWN)   # (2,3)
	await _step(room, Vector2i.DOWN)   # (2,4)
	var follower: PartyFollower = room.party_followers[0]
	var dist: int = absi(follower.cell.x - room.player.cell.x) \
			+ absi(follower.cell.y - room.player.cell.y)
	ok(dist >= 1 and dist <= 3, "spaced follower stays near the leader")
	ok(room.is_walkable(follower.cell), "follower cell stays walkable")
	_teardown(room)


func test_leader_switch_swaps_control_and_identity() -> void:
	var room := _make_room()
	var follower: PartyFollower = room.party_followers[0]
	var leader_cell := room.player.cell
	var follower_cell := follower.cell
	var switched := room.switch_party_leader()
	eq(switched, "companion_test", "cycle promotes the next roster member")
	eq(room.party_leader_id, "companion_test", "room leader identity updated")
	eq(room.player.cell, follower_cell,
			"control moves to the new leader's cell")
	eq(follower.member_id, "hero", "the old leader becomes a follower")
	eq(follower.cell, leader_cell, "the demoted follower holds the old cell")
	eq(room.get_occupant(follower_cell), room.player,
			"occupancy follows the controlled avatar")
	ok(room.is_walkable(leader_cell),
			"the demoted follower stays pass-through")
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "post-switch snapshot has no error")
	if not data.has("error"):
		eq(data["party"]["leader"], "companion_test",
				"snapshot leader follows the switch")
		eq(data["actors"]["companion_test"]["cell"], follower_cell,
				"new leader actor at the control cell")
	var back := room.switch_party_leader()
	eq(back, "hero", "cycling again returns the original leader")
	eq(room.party_leader_id, "hero", "leader identity restored")
	_teardown(room)


func test_leader_switch_refused_during_encounter() -> void:
	var room := _make_room()
	SceneManager.unified_encounters = true
	for enemy in room.enemies:
		if enemy.cell == Vector2i(9, 5):
			room.begin_room_encounter(enemy)
	eq(room.switch_party_leader(), "",
			"leader switching is refused inside an encounter")
	eq(room.party_leader_id, "hero", "identity unchanged after refusal")
	room.resolve_room_encounter(false)
	SceneManager.unified_encounters = false
	_teardown(room)
