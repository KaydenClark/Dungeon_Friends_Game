extends Node
## S-014/TK-005: the first-session replay, windowed. Drives the opening
## unified-world loop through REAL parsed input events (Input.parse_input_event
## feeds the same global state the Player polls): walk, cycle formation, bump
## the slime into the in-room encounter, fight through the encounter surface,
## win, and write a real save - once per input layout. --input=keyboard uses
## the D-019 keys; --input=controller synthesizes the joypad buttons for the
## identical route. Two captures per run; exits 1 on any FAIL.
##
##   cd game
##   Godot --path . scenes/dev/first_session_replay.tscn -- --input=keyboard --out=/abs/dir
##   Godot --path . scenes/dev/first_session_replay.tscn -- --input=controller --out=/abs/dir

var out_dir := "user://screenshots"
var input_mode := "keyboard"
var _failed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--input="):
			input_mode = arg.trim_prefix("--input=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: %s" % label)
	else:
		_failed = true
		print("FAIL: %s" % label)


func _press_move(dir: Vector2i, frames_held: int) -> void:
	# Movement rides the bound actions on both layouts (WASD / D-pad).
	var action: String = {Vector2i.RIGHT: "move_right", Vector2i.LEFT: "move_left",
			Vector2i.UP: "move_up", Vector2i.DOWN: "move_down"}[dir]
	Input.action_press(action)
	await _frames(frames_held)
	Input.action_release(action)
	await _frames(4)


func _tap(key_code: int, joy_button: int) -> void:
	if input_mode == "controller" and joy_button >= 0:
		var press := InputEventJoypadButton.new()
		press.button_index = joy_button
		press.pressed = true
		Input.parse_input_event(press)
		await _frames(2)
		var release := InputEventJoypadButton.new()
		release.button_index = joy_button
		release.pressed = false
		Input.parse_input_event(release)
	else:
		var press := InputEventKey.new()
		press.physical_keycode = key_code
		press.pressed = true
		Input.parse_input_event(press)
		await _frames(2)
		var release := InputEventKey.new()
		release.physical_keycode = key_code
		release.pressed = false
		Input.parse_input_event(release)
	await _frames(3)


func _run() -> void:
	# _ready is still setting up children; defer one frame so add_child works.
	await get_tree().process_frame
	print("FIRST SESSION REPLAY (%s): begin" % input_mode)
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)
	await _frames(15)
	# 1. Real movement input walks the leader (the first-session basics).
	var start: Vector2i = room.player.cell
	await _press_move(Vector2i.DOWN, 6)
	_check(room.player.cell != start, "movement input walks the leader")
	# 2. Formation control (G / L1 via the bound action path in Player).
	# The tween step may still be in flight and Player gates formation on
	# `not moving`; a just_pressed tap lasts one frame, so wait it out first.
	var settle := 0
	while room.player.moving and settle < 60:
		await _frames(1)
		settle += 1
	var formation_before: StringName = room.party_formation()
	if input_mode == "controller":
		var press := InputEventJoypadButton.new()
		press.button_index = JOY_BUTTON_LEFT_SHOULDER
		press.pressed = true
		Input.parse_input_event(press)
		await _frames(3)
		var release := InputEventJoypadButton.new()
		release.button_index = JOY_BUTTON_LEFT_SHOULDER
		release.pressed = false
		Input.parse_input_event(release)
	else:
		await _tap(KEY_G, -1)
	await _frames(5)
	_check(room.party_formation() != formation_before,
			"the formation control answers this layout")
	# 3. Walk into the slime: the bump enters the in-room encounter.
	room.teleport(room.player, Vector2i(8, 5))
	await _frames(5)
	await _press_move(Vector2i.RIGHT, 4)
	var guard_frames := 0
	while room.active_encounter_id == "" and guard_frames < 60:
		await _press_move(Vector2i.RIGHT, 4)
		guard_frames += 1
	_check(room.active_encounter_id != "", "the bump entered the encounter")
	await _frames(45)   # ENTER beat: panel visible for the capture
	await _shot("1-%s-encounter" % input_mode)
	# 4. Fight through the encounter surface with this layout's buttons.
	var rounds := 0
	while room.active_encounter_id != "" and rounds < 40:
		await _tap(KEY_1, JOY_BUTTON_A)          # attack
		if room.active_encounter_id == "":
			break
		await _tap(KEY_Q, JOY_BUTTON_X)          # end turn (cancel action)
		rounds += 1
	_check(room.active_encounter_id == "", "the fight ends in victory")
	await _frames(8)
	await _shot("2-%s-victory" % input_mode)
	# 5. A real save write completes the first session.
	var data := SaveManager.capture(SceneManager.state, "replay",
			room.player.cell)
	_check(SaveManager.write(1, data, "user://saves_replay"), "session saved")
	var dir := DirAccess.open("user://saves_replay")
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)
		DirAccess.open("user://").remove("saves_replay")
	SceneManager.unified_encounters = true
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	print("FIRST SESSION REPLAY (%s): %s"
			% [input_mode, "FAIL" if _failed else "done"])
	get_tree().quit(1 if _failed else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	# Non-black + exact-size verification: a replay capture that is black
	# or resized is not proof (T-085/T-093B precedent, same as the matrix).
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
