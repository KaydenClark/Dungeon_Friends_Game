extends Node
## S-009/TK-004 demo: the production in-room encounter mode seam, windowed.
## Boots the LDtk fixture room with the visible party, walks the leader into
## the enemy with unified encounters enabled, and captures three PNGs:
## 1-exploration (block pushed, party visible), 2-encounter (same room, same
## camera, banner up, input gated), 3-victory (enemy gone, encounter resolved,
## pushed block and room state intact). Prints PASS/FAIL continuity
## assertions and exits 1 on any FAIL.
##
## Run windowed (headless renders black):
##   cd game
##   Godot --path . scenes/dev/unified_seam_demo.tscn -- --out=/abs/dir

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
	print("UNIFIED SEAM DEMO: begin")
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)
	await _frames(15)
	# Freeze ambient enemy AI (real-time wander timers) so the scripted walk
	# is deterministic; direct try_step calls below bypass this gate, and the
	# bump -> start_encounter path only checks in_encounter/transitioning.
	SceneManager.ui_busy = true

	# Puzzle state before the fight: push the block onto the plate.
	var block: PushableBlock = room.blocks[0]
	block.try_push(Vector2i.LEFT)
	await _frames(10)
	_check(block.cell == Vector2i(2, 5), "block pushed pre-encounter")
	_check(room.door.held_open, "plate-held door open pre-encounter")
	await _shot("1-exploration")

	# Walk into the enemy through the real bump path.
	room.teleport(room.player, Vector2i(8, 5))
	await _frames(5)
	var camera := room.player.camera
	room.player.try_step(Vector2i.RIGHT)
	await _frames(10)
	_check(room.active_encounter_id == "enc_9_5",
			"bump entered the in-room encounter")
	_check(SceneManager.in_encounter, "exploration input gated")
	_check(room.player.cell == Vector2i(8, 5), "leader never moved")
	_check(room.player.camera == camera, "same camera node, no zoom")
	# Wait out the D-036 ENTER beat so the S-012 intent panel and cell
	# highlights are visible in the capture.
	await _frames(45)
	_check(room.room_encounter != null, "intent controller running")
	if room.room_encounter != null:
		_check(not room.room_encounter.current_intent.is_empty(),
				"enemy intent declared")
	await _shot("2-encounter")

	_check(room.resolve_room_encounter(true) == "", "victory resolves in place")
	await _frames(10)
	_check(not SceneManager.in_encounter, "input gate released")
	_check(block.cell == Vector2i(2, 5), "pushed block survived")
	_check(room.door.held_open, "held door survived")
	var enemy_gone := true
	for enemy in room.enemies:
		if is_instance_valid(enemy) and enemy.cell == Vector2i(9, 5):
			enemy_gone = false
	_check(enemy_gone, "defeated enemy left the same room instance")
	await _shot("3-victory")

	SceneManager.ui_busy = false
	SceneManager.unified_encounters = false
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	print("UNIFIED SEAM DEMO: %s" % ("FAIL" if _failed else "done"))
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
