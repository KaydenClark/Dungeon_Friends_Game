extends Node
## S-012/TK-003 demo: a real production intent-round fight, windowed. Bumps
## the slime beside the plate corridor, shows the declared intent, cancels it
## with a shove, then attacks across rounds to victory - all through the
## RoomEncounter controller the player's keys drive. Exits 1 on any FAIL.
##
##   cd game
##   Godot --path . scenes/dev/combat_round_demo.tscn -- --out=/abs/dir

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
	print("COMBAT ROUND DEMO: begin")
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)
	await _frames(15)
	SceneManager.ui_busy = true

	room.teleport(room.player, Vector2i(8, 5))
	await _frames(5)
	room.player.try_step(Vector2i.RIGHT)
	await _frames(50)   # past the ENTER beat so the intent UI is visible
	var controller = room.room_encounter
	_check(controller != null, "the intent controller is running")
	if controller == null:
		get_tree().quit(1)
		return
	_check(not controller.current_intent.is_empty(), "round one declared")
	await _shot("1-intent-declared")

	_check(controller.shove("enc_9_5"), "shove connects")
	_check(controller.current_intent.get("canceled", false),
			"the shove cancels the declared intention")
	await _frames(8)
	await _shot("2-shove-canceled")

	var summary: Dictionary = controller.end_party_turn()
	_check(int(summary.get("party_damage", -1)) == 0,
			"the canceled intention resolved to zero damage")
	var rounds := 0
	while room.active_encounter_id != "" and rounds < 30:
		controller = room.room_encounter
		if controller == null:
			break
		controller.set_active_unit("hero")
		var hero_cell: Vector2i = controller.state["units"]["hero"]["cell"]
		var enemy_cell: Vector2i = controller.state["units"].get("enc_9_5",
				{}).get("cell", hero_cell)
		var dist: int = absi(hero_cell.x - enemy_cell.x) \
				+ absi(hero_cell.y - enemy_cell.y)
		if dist == 1:
			controller.attack("enc_9_5")
		else:
			var delta := enemy_cell - hero_cell
			var step := Vector2i(signi(delta.x), 0) if delta.x != 0 \
					else Vector2i(0, signi(delta.y))
			controller.move_active(step)
		if room.active_encounter_id == "" or controller == null \
				or not is_instance_valid(controller):
			break
		if not controller.can_act("hero") and controller.moves_left("hero") <= 0:
			controller.end_party_turn()
		elif not controller.can_act("hero"):
			controller.end_party_turn()
		rounds += 1
	_check(room.active_encounter_id == "", "the fight ends in victory")
	await _frames(10)
	await _shot("3-victory")

	SceneManager.ui_busy = false
	SceneManager.unified_encounters = false
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	print("COMBAT ROUND DEMO: %s" % ("FAIL" if _failed else "done"))
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
