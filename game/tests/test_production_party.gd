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
