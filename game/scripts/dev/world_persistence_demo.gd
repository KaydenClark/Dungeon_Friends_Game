extends Node
## S-003/TK-003 owner demo: persistent world resolution, windowed. Defeats
## the fixture slime through the unified seam and burns the vine through the
## reaction seam, rebuilds the room (capture 1: slime gone, burn standing,
## wedged block reset), then writes a real save, wipes the session, loads it
## back, and rebuilds again (capture 2: the resolved world came back from
## disk). The material overlay renders live tags; exits 1 on any FAIL.
##
##   cd game
##   Godot --path . scenes/dev/world_persistence_demo.tscn -- --out=/abs/dir

const SAVE_DIR := "user://saves_world_demo"
const TAG_COLORS := {
	"vine": Color(0.28, 0.62, 0.30, 0.85),
	"flammable": Color(0.75, 0.45, 0.18, 0.85),
	"channel": Color(0.25, 0.47, 0.66, 0.85),
	"smoke": Color(0.45, 0.45, 0.45, 0.8),
	"fire": Color(0.95, 0.45, 0.10, 0.9),
}

var out_dir := "user://screenshots"
var _failed := false
var _room: LdtkRoom
var _overlay: Node2D


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


func _build() -> void:
	_room = LdtkRoom.new()
	_room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(_room)
	_overlay = Node2D.new()
	_overlay.z_index = 30
	_room.add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)


func _teardown_room() -> void:
	if _room != null and is_instance_valid(_room):
		_room.free()
	_room = null
	_overlay = null


func _slime_alive() -> bool:
	for enemy in _room.enemies:
		if is_instance_valid(enemy) and enemy.cell == Vector2i(9, 5):
			return true
	return false


func _run() -> void:
	print("WORLD PERSISTENCE DEMO: begin")
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	_build()
	await _frames(12)
	SceneManager.ui_busy = true
	for enemy in _room.enemies:
		if enemy.cell == Vector2i(9, 5):
			_check(_room.begin_room_encounter(enemy) == "", "encounter begins")
			_check(_room.resolve_room_encounter(true) == "", "slime defeated")
	var fire := AbilityData.new()
	fire.reaction_verb = "fire"
	_check(ReactionCaster.cast(_room, fire, Vector2i(5, 1)).get("valid") == true,
			"vine burned")
	_check(_room.blocks[0].try_push(Vector2i.LEFT), "block wedged")
	_teardown_room()
	await _frames(3)
	_build()
	await _frames(12)
	_check(not _slime_alive(), "rebuild: the resolved slime stays gone (D-028)")
	_check(_room.material_state["cells"][Vector2i(5, 1)]["tags"].has("fire"),
			"rebuild: the burn still stands")
	_check(_room.blocks[0].cell == Vector2i(3, 5),
			"rebuild: the wedged block reset (escape valve)")
	_overlay.queue_redraw()
	await _frames(5)
	await _shot("1-rebuilt-persisted")

	# Real disk cycle: write, wipe the session, load, rebuild.
	var data := SaveManager.capture(SceneManager.state, "demo", Vector2i(2, 2))
	_check(SaveManager.write(1, data, SAVE_DIR), "save written")
	SceneManager.reset_session_state()
	var loaded := SaveManager.load_slot(1, SAVE_DIR)
	_check(loaded != null, "save loads back")
	if loaded != null:
		SceneManager.state = loaded.to_game_state()
	_teardown_room()
	await _frames(3)
	_build()
	await _frames(12)
	_check(not _slime_alive(), "after load: the resolved slime stays gone")
	_check(_room.material_state["cells"][Vector2i(5, 1)]["tags"].has("fire"),
			"after load: the burn came back from disk")
	_overlay.queue_redraw()
	await _frames(5)
	await _shot("2-loaded-persisted")

	var dir := DirAccess.open(SAVE_DIR)
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)
		DirAccess.open("user://").remove(SAVE_DIR.trim_prefix("user://"))
	SceneManager.ui_busy = false
	SceneManager.unified_encounters = true
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	print("WORLD PERSISTENCE DEMO: %s" % ("FAIL" if _failed else "done"))
	get_tree().quit(1 if _failed else 0)


func _draw_overlay() -> void:
	if _room == null or not _room.material_state.get("cells") is Dictionary:
		return
	for cell in _room.material_state["cells"]:
		var tags: Array = _room.material_state["cells"][cell]["tags"]
		var offset := 0
		for tag in tags:
			_overlay.draw_rect(Rect2(_room.cell_to_pos(cell)
					+ Vector2(-20 + offset * 14, 14), Vector2(12, 12)),
					TAG_COLORS.get(tag, Color(1, 0, 1, 0.8)))
			offset += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	print("  wrote ", path)
