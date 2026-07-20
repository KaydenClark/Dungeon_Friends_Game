extends Node
## S-010/TK-002 demo: production formation selection and leader switching,
## windowed. Boots the LDtk fixture room, walks in spaced formation, then
## switches the leader: control moves to Buddy's cell with swapped visuals
## while the demoted hero becomes the follower. Captures 2 PNGs and prints
## PASS/FAIL assertions; exits 1 on any FAIL.
##
##   cd game
##   Godot --path . scenes/dev/party_formation_demo.tscn -- --out=/abs/dir

var out_dir := "user://screenshots"
var _failed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: %s" % label)
	else:
		_failed = true
		print("FAIL: %s" % label)


func _run() -> void:
	print("PARTY FORMATION DEMO: begin")
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)
	await _frames(15)
	SceneManager.ui_busy = true   # freeze ambient enemy AI for determinism

	# TK-003: drive the production selector (G/L1 cycles) rather than the raw
	# API, so the capture shows the player-facing toast.
	_check(room.cycle_party_formation() == &"square", "cycle reaches square")
	_check(room.cycle_party_formation() == &"spaced", "cycle reaches spaced")
	_check(str(SceneManager.state.party_formation) == "spaced",
			"selection persisted to session state")
	for dir in [Vector2i.DOWN, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT]:
		room.player.try_step(dir)
		await room.player.move_finished
		await _frames(3)
	var follower: PartyFollower = room.party_followers[0]
	var dist: int = absi(follower.cell.x - room.player.cell.x) \
			+ absi(follower.cell.y - room.player.cell.y)
	_check(dist >= 1 and dist <= 3, "spaced follower trails the leader")
	await _frames(8)
	await _shot("1-spaced-formation")

	var leader_cell := room.player.cell
	var follower_cell := follower.cell
	var switched := room.switch_party_leader()
	_check(switched == "companion_test", "leader switch promotes Buddy")
	_check(room.player.cell == follower_cell, "control moved to Buddy's cell")
	_check(follower.cell == leader_cell, "hero follows from the old cell")
	_check(follower.member_id == "hero", "the demoted hero is the follower")
	await _frames(8)
	await _shot("2-leader-switched")

	# Choke compression: walk up beside the top wall, then step down - the
	# spaced offset (two cells behind the DOWN facing) lands in the wall row,
	# so the follower compresses onto the breadcrumb trail.
	room.teleport(room.player, Vector2i(6, 1))
	await _frames(5)
	room.player.try_step(Vector2i.DOWN)
	await room.player.move_finished
	await _frames(5)
	_check(room.party_trail.formation_state() == &"compressed",
			"walled offset compresses the spaced formation")
	await _shot("3-choke-compressed")

	# Encounter deployment: bump the slime - the follower snaps to a legal
	# deployment cell and becomes a real occupant (D-037).
	SceneManager.unified_encounters = true
	room.teleport(room.player, Vector2i(8, 5))
	await _frames(5)
	room.player.try_step(Vector2i.RIGHT)
	await _frames(10)
	_check(room.active_encounter_id == "enc_9_5", "bump entered the encounter")
	_check(room.party_deployed, "party deployed on entry")
	var deployed_follower: PartyFollower = room.party_followers[0]
	_check(room.get_occupant(deployed_follower.cell) == deployed_follower,
			"follower occupies its deployment cell")
	await _shot("4-deployed")

	_check(room.resolve_room_encounter(true) == "", "victory resolves")
	_check(not room.party_deployed, "deployment released")
	_check(room.get_occupant(deployed_follower.cell) == null,
			"follower is pass-through again")
	await _frames(8)
	await _shot("5-victory-passthrough")

	SceneManager.ui_busy = false
	SceneManager.unified_encounters = false
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	print("PARTY FORMATION DEMO: %s" % ("FAIL" if _failed else "done"))
	get_tree().quit(1 if _failed else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	print("  wrote ", path)
