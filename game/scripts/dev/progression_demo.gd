extends Node
## S-013/TK-005 demo: finite progression and recruitment, windowed. Recruits
## Wren mid-session (party of three walking), casts her field verb, wins the
## slime encounter exactly once, and PROVES the finite accounting: the
## victory source and the recruitment source can never pay twice, defeat
## costs no XP under the v2 default (D-043), and the ledger and roster
## survive a real save round trip. Exits 1 on any FAIL.
##
##   cd game
##   Godot --path . scenes/dev/progression_demo.tscn -- --out=/abs/dir

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
	print("PROGRESSION DEMO: begin")
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	_check(SceneManager.recruit_member("wren"), "Wren joins the expedition")
	_check(not SceneManager.recruit_member("wren"),
			"recruitment is a one-shot finite source")
	SceneManager.state.party_leader = "wren"
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)
	await _frames(15)
	SceneManager.ui_busy = true
	_check(room.party_followers.size() == 2, "a party of three walks")
	await _shot("1-wren-recruited")

	var cast: Dictionary = room.cast_leader_reaction()
	_check(cast.get("valid") == true, "Wren grows a vine in the field")
	await _frames(8)
	await _shot("2-field-verb")

	var xp_before: int = SceneManager.total_xp
	for enemy in room.enemies:
		if enemy.cell == Vector2i(9, 5):
			_check(room.begin_room_encounter(enemy) == "", "encounter begins")
			_check(room.resolve_room_encounter(true) == "", "victory")
	var gained := SceneManager.total_xp - xp_before
	_check(gained > 0, "the finite victory paid XP once (+%d)" % gained)
	var source := "%s#enc_9_5" % room.world_key()
	_check(not SceneManager.claim_reward_source(source),
			"the same victory can never pay again (ledger)")
	_check(SceneManager.apply_defeat_xp_penalty() == 0,
			"defeat costs no XP under the finite economy (D-043)")
	await _frames(8)
	await _shot("3-victory-ledger")

	var captured := SaveManager.capture(SceneManager.state, "demo",
			Vector2i(2, 2))
	var rebuilt := SaveData.from_dict(JSON.parse_string(
			JSON.stringify(captured.to_dict())))
	_check(rebuilt != null, "save round-trips")
	if rebuilt != null:
		var loaded: GameState = rebuilt.to_game_state()
		_check(loaded.party_roster.has("wren"), "Wren survives save/load")
		_check(loaded.reward_ledger.get(source, false) == true,
				"the claimed victory survives save/load")

	SceneManager.ui_busy = false
	SceneManager.unified_encounters = true
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	print("PROGRESSION DEMO: %s" % ("FAIL" if _failed else "done"))
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
