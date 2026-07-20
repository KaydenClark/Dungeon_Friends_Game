extends Node
## S-014/TK-001: the production readability/accessibility matrix, windowed.
## Captures every reviewable production state - visible party in formation,
## the leader's cast toast, the in-room encounter (banner, intent panel,
## cell highlights, party status lines), material state (debug overlay
## stand-in until S-004 art), and the exploration HUD - at both supported
## review sizes. Every capture is verified non-black and exactly the
## requested dimensions. Known presentation gaps are printed as explicit
## GAP lines so the matrix is an honest audit, not a highlight reel.
##
##   cd game
##   Godot --path . scenes/dev/opening_readability_matrix.tscn --resolution 1280x720 -- --out=/abs/dir/1280
##   Godot --path . scenes/dev/opening_readability_matrix.tscn --resolution 1920x1080 -- --out=/abs/dir/1920

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
	print("READABILITY MATRIX: begin (%s)" % str(get_viewport().size))
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	SceneManager.recruit_member("wren")
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)
	await _frames(15)
	SceneManager.ui_busy = true

	room.set_party_formation(&"spaced")
	await _frames(8)
	await _shot("1-party-formation")

	SceneManager.state.party_leader = "wren"
	# Rebuild so Wren leads (leader identity applies at room build).
	room.free()
	await _frames(3)
	room = LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)
	await _frames(12)
	SceneManager.ui_busy = true
	var cast: Dictionary = room.cast_leader_reaction()
	_check(cast.get("valid") == true, "leader cast readable via toast")
	await _frames(5)
	await _shot("2-cast-toast")

	room.teleport(room.player, Vector2i(8, 5))
	await _frames(3)
	room.player.try_step(Vector2i.RIGHT)
	await _frames(50)   # past the ENTER beat: full intent panel visible
	_check(room.room_encounter != null, "encounter running for the matrix")
	await _shot("3-encounter-intent-hud")
	if room.room_encounter != null:
		room.resolve_room_encounter(true)
	await _frames(8)
	await _shot("4-post-victory-world")

	print("GAP: integer elevation has no production presentation lift yet",
			" (logic-only; the three-quarter lift remains spike-only - S-004)")
	print("GAP: material state renders via the debug overlay in demos only",
			" (production VFX owned by the S-004 art pass)")
	print("GAP: on-screen prompts are keyboard-only until T-079 glyphs")

	SceneManager.ui_busy = false
	SceneManager.unified_encounters = true
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	print("READABILITY MATRIX: %s" % ("FAIL" if _failed else "done"))
	get_tree().quit(1 if _failed else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	# Non-black + exact-size verification: a readability capture that is
	# black or resized is not proof (T-085/T-093B precedent).
	var expected: Vector2i = get_viewport().size
	_check(img.get_size() == expected,
			"%s is exactly %s" % [name, expected])
	var lit := false
	for probe in [Vector2i(expected.x / 2, expected.y / 2),
			Vector2i(expected.x / 4, expected.y / 4),
			Vector2i(3 * expected.x / 4, 3 * expected.y / 4)]:
		if img.get_pixelv(probe).get_luminance() > 0.02:
			lit = true
	_check(lit, "%s is not a black frame" % name)
	print("  wrote ", path)
