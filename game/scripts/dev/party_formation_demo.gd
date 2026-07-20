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

	_check(room.set_party_formation(&"spaced"), "spaced formation selected")
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

	SceneManager.ui_busy = false
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
