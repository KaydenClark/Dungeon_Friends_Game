extends Node
## S-004/TK-003: the under-one-minute thesis demo. Boots the REAL game
## (main.tscn), walks the forest's south doorway into the Withered Grove,
## and drives the whole v2 loop through the production seams: recruit Wren
## on dialogue, resolve Moss's herb bed without combat, grow the vine gate's
## trellis, beat the grove guardian in the in-room encounter, watch the
## grove heart regrow, prove the save round trip, then walk out and back in
## to show it all persisted. Seven verified captures; exits 1 on any FAIL.
##
##   cd game
##   Godot --path . scenes/dev/thesis_demo.tscn -- --out=/abs/dir

var out_dir := "user://screenshots"
var _failed := false
var _done := false
var room: LdtkRoom


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_watchdog()
	_run()


func _watchdog() -> void:
	await get_tree().create_timer(120.0).timeout
	if not _done:
		print("THESIS DEMO: FAIL (timeout after 120s)")
		get_tree().quit(1)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: %s" % label)
	else:
		_failed = true
		print("FAIL: %s" % label)


func _run() -> void:
	print("THESIS DEMO: begin")
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	_clear_scratch_saves()
	SceneManager.save_dir = "user://saves_thesis_demo"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_check(await _until(func() -> bool:
		return SceneManager.world_container != null \
				and SceneManager.world_container.get_child_count() > 0),
			"the real game boots")
	room = SceneManager.world_container.get_child(0)
	_check(room is ForestRoom, "the forest is the opening room")

	# Beat 1 - adventure: the south doorway leads into the Withered Grove.
	room.teleport(room.player, Vector2i(10, 16))
	await _frames(5)
	await _step(Vector2i.DOWN)
	await _step(Vector2i.DOWN)
	_check(await _until(func() -> bool:
		return not SceneManager.transitioning \
				and SceneManager.current_room is GroveRoom),
			"the doorway walks the party into the grove")
	room = SceneManager.current_room
	await _frames(20)
	await _shot("1-grove-arrival")

	# Beat 2 - recruit: Wren joins when her dialogue ends.
	_check(await _navigate(Vector2i(4, 4)), "reached Wren")
	room.player.set_facing(Vector2i.UP)
	room.player.interact()
	await _pump_dialogue()
	_check(await _until(func() -> bool:
		return SceneManager.state.party_roster.has("wren")),
			"Wren joined the expedition on her own words")
	await _frames(10)
	await _shot("2-wren-joins")

	# Beat 3 - non-combat resolution: grow Moss's herb bed.
	while room.party_leader_id != "wren":
		room.switch_party_leader()
		await _frames(2)
	_check(await _navigate(Vector2i(7, 8)), "reached the herb bed")
	room.player.set_facing(Vector2i.UP)
	var bed_cast: Dictionary = room.cast_leader_reaction()
	_check(bed_cast.get("valid", false) == true, "Wren's grow answers the bed")
	_check(SceneManager.flags.get("grove_herbs_grown", false) == true,
			"Moss's problem resolved without a single swing")
	_check(await _navigate(Vector2i(6, 8)), "stepped over to Moss")
	room.player.set_facing(Vector2i.UP)
	room.player.interact()
	await _frames(10)
	await _shot("3-herbs-regrown")
	await _pump_dialogue()

	# Beat 4 - shared-vocabulary puzzle: the trellis opens the vine gate.
	_check(await _navigate(Vector2i(9, 5)), "reached the trellis")
	room.player.set_facing(Vector2i.UP)
	var trellis_cast: Dictionary = room.cast_leader_reaction()
	_check(trellis_cast.get("valid", false) == true,
			"grow answers the trellis")
	_check(not room.blocked.has(Vector2i(10, 5)),
			"the vine gate stands open")
	await _frames(10)
	await _shot("4-vine-gate-open")

	# Beat 5 - the tactical fight: bump the grove guardian.
	var guard_walk := 0
	while room.active_encounter_id == "" and guard_walk < 12:
		await _step(Vector2i.RIGHT)
		guard_walk += 1
	_check(room.active_encounter_id != "", "the guardian fight begins in-room")
	await _frames(45)
	await _shot("5-encounter")
	var rounds := 0
	while room.active_encounter_id != "" and rounds < 20:
		var controller = room.room_encounter
		for unit_slot in controller.party_unit_ids().size():
			if room.active_encounter_id == "":
				break
			await _fight_active_unit(controller)
			if room.active_encounter_id == "":
				break
			controller.cycle_active_unit()
			await _frames(2)
		if room.active_encounter_id != "":
			controller.end_party_turn()
			await _frames(5)
		rounds += 1
	_check(room.active_encounter_id == ""
			and SceneManager.state.resolved_encounters.get(room.world_key(),
					{}).get("grove_guardian", false),
			"the fight ends in victory")

	# Beat 6 - permanent world change: the heart regrows and it all saves.
	_check(SceneManager.flags.get("grove_restored", false) == true,
			"the grove heart regrows on victory")
	var green_hearts := true
	for cell in GroveRoom.HEART_CELLS:
		if not room.material_state["cells"][cell]["tags"].has("vine"):
			green_hearts = false
	_check(green_hearts, "every heart cell carries a living vine")
	await _frames(15)
	await _shot("6-grove-restored")
	var captured := SaveManager.capture(SceneManager.state, "withered_grove",
			room.player.cell)
	_check(SaveManager.write(1, captured, SceneManager.save_dir),
			"the session saves")
	var rebuilt := SaveData.from_dict(captured.to_dict())
	var loaded := rebuilt.to_game_state() if rebuilt != null else null
	_check(loaded != null and loaded.party_roster.has("wren")
			and loaded.resolved_encounters.get(room.world_key(),
					{}).get("grove_guardian", false),
			"Wren and the resolved fight survive the save round trip")

	# Beat 7 - walk out and back in: the world remembers. Leaving resumes
	# the suspended forest (the player stands on its doorway cell); stepping
	# off and back on rebuilds the grove fresh from persisted truth.
	_check(await _navigate(Vector2i(2, 5)), "walked back to the grove door")
	await _step(Vector2i.LEFT)
	_check(await _until(func() -> bool:
		return not SceneManager.transitioning \
				and SceneManager.current_room is ForestRoom),
			"the doorway returns to the forest")
	room = SceneManager.current_room
	await _frames(5)
	await _step(Vector2i.UP)
	await _step(Vector2i.DOWN)
	_check(await _until(func() -> bool:
		return not SceneManager.transitioning \
				and SceneManager.current_room is GroveRoom),
			"and the grove takes the party back")
	room = SceneManager.current_room
	_check(not room.blocked.has(Vector2i(10, 5)),
			"the gate is still open on the rebuilt room")
	_check(room.enemies.is_empty(), "the resolved guardian never respawns")
	var still_green := true
	for cell in GroveRoom.HEART_CELLS:
		if not room.material_state["cells"][cell]["tags"].has("vine"):
			still_green = false
	_check(still_green, "the regrown heart persists")
	await _frames(15)
	await _shot("7-return-persisted")

	_clear_scratch_saves()
	_done = true
	print("THESIS DEMO: %s" % ("FAIL" if _failed else "done"))
	get_tree().quit(1 if _failed else 0)


## Play the active unit like a player would (the same controller functions
## the bound keys call): close toward the slime, attack when adjacent.
func _fight_active_unit(controller) -> void:
	for attempt in 5:
		var result: Dictionary = controller.attack(controller.enemy_id)
		if result.get("valid", false) or room.active_encounter_id == "":
			return
		var unit_cell: Vector2i = \
				controller.state["units"][controller.active_unit_id]["cell"]
		var enemy_cell: Vector2i = \
				controller.state["units"][controller.enemy_id]["cell"]
		var delta := enemy_cell - unit_cell
		var first := Vector2i(signi(delta.x), 0) \
				if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
		var second := Vector2i(0, signi(delta.y)) \
				if first.x != 0 else Vector2i(signi(delta.x), 0)
		if first == Vector2i.ZERO or not controller.move_active(first):
			if second == Vector2i.ZERO or not controller.move_active(second):
				return
		await _frames(2)


func _navigate(target: Vector2i, max_steps := 80) -> bool:
	var steps := 0
	while room.player.cell != target and steps < max_steps:
		if SceneManager.in_encounter:
			return false
		var path: Array = room.find_path(room.player.cell, target, true)
		if path.size() < 2:
			await get_tree().process_frame
		else:
			await _step(path[1] - room.player.cell)
		steps += 1
	return room.player.cell == target


func _step(dir: Vector2i) -> bool:
	if SceneManager.in_encounter:
		return false
	var ok: bool = room.player.try_step(dir)
	if ok:
		await room.player.move_finished
	else:
		await get_tree().process_frame
	return ok


func _tap(key_code: int) -> void:
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


func _pump_dialogue(max_frames := 600) -> void:
	for i in max_frames:
		if SceneManager.current_dialogue:
			SceneManager.current_dialogue.advance()
		elif not SceneManager.ui_busy:
			return
		await get_tree().process_frame


func _until(pred: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if pred.call():
			return true
		await get_tree().process_frame
	return pred.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _clear_scratch_saves() -> void:
	var scratch := DirAccess.open("user://")
	if scratch == null or not scratch.dir_exists("saves_thesis_demo"):
		return
	var saves := DirAccess.open("user://saves_thesis_demo")
	if saves != null:
		for f in saves.get_files():
			saves.remove(f)
	scratch.remove("saves_thesis_demo")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	# Fail-closed capture verification (T-085/T-093B precedent).
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
