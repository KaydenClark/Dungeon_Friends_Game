extends Node
## S-011/TK-004 demo: the production same-state exploration/encounter replay,
## windowed. One fixture room, one live material_state, one ReactionCaster
## seam: fire burns the authored vine in exploration, water+spark run inside
## an active in-room encounter, and victory returns to exploration with every
## committed material change still standing. A second fresh room replays the
## identical casts with contexts swapped and must land on the identical
## state. A debug overlay renders the live tags (production has no material
## VFX until S-012); captures land per shot. Exits 1 on any FAIL.
##
##   cd game
##   Godot --path . scenes/dev/reaction_replay_demo.tscn -- --out=/abs/dir

const TAG_COLORS := {
	"vine": Color(0.28, 0.62, 0.30, 0.85),
	"flammable": Color(0.75, 0.45, 0.18, 0.85),
	"channel": Color(0.25, 0.47, 0.66, 0.85),
	"smoke": Color(0.45, 0.45, 0.45, 0.8),
	"fire": Color(0.95, 0.45, 0.10, 0.9),
	"wet": Color(0.35, 0.65, 0.95, 0.8),
	"flooded": Color(0.15, 0.35, 0.85, 0.85),
	"ice": Color(0.6, 0.9, 1.0, 0.9),
}

var out_dir := "user://screenshots"
var _failed := false
var _overlay: Node2D
var _room: LdtkRoom


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


func _cast_sequence(room: LdtkRoom, contexts: Array) -> void:
	var fire := AbilityData.new()
	fire.reaction_verb = "fire"
	var water := AbilityData.new()
	water.reaction_verb = "water"
	var spark := AbilityData.new()
	spark.reaction_verb = "spark"
	_check(ReactionCaster.cast(room, fire, Vector2i(5, 1), Vector2i.RIGHT,
			contexts[0]).get("valid") == true, "fire cast (%s)" % contexts[0])
	_check(ReactionCaster.cast(room, water, Vector2i(7, 1), Vector2i.RIGHT,
			contexts[1]).get("valid") == true, "water cast (%s)" % contexts[1])
	_check(ReactionCaster.cast(room, spark, Vector2i(7, 1), Vector2i.RIGHT,
			contexts[2]).get("valid") == true, "spark cast (%s)" % contexts[2])


func _run() -> void:
	print("REACTION REPLAY: begin")
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	_room = LdtkRoom.new()
	_room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(_room)
	await _frames(15)
	SceneManager.ui_busy = true
	_overlay = Node2D.new()
	_overlay.z_index = 30
	_room.add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	_refresh_overlay()
	await _frames(5)
	await _shot("1-authored-materials")

	var fire := AbilityData.new()
	fire.reaction_verb = "fire"
	_check(ReactionCaster.cast(_room, fire, Vector2i(5, 1)).get("valid") == true,
			"exploration fire cast commits")
	_check(_room.material_state["cells"][Vector2i(5, 1)]["tags"].has("fire"),
			"the vine burns in exploration")
	_refresh_overlay()
	await _frames(5)
	await _shot("2-exploration-burn")

	var enemy: OverworldEnemy = null
	for candidate in _room.enemies:
		if candidate.cell == Vector2i(9, 5):
			enemy = candidate
	_check(_room.begin_room_encounter(enemy) == "", "encounter begins in-room")
	var water := AbilityData.new()
	water.reaction_verb = "water"
	var spark := AbilityData.new()
	spark.reaction_verb = "spark"
	_check(ReactionCaster.cast(_room, water, Vector2i(7, 1), Vector2i.RIGHT,
			"encounter").get("valid") == true, "encounter water cast commits")
	_check(ReactionCaster.cast(_room, spark, Vector2i(7, 1), Vector2i.RIGHT,
			"encounter").get("valid") == true, "encounter spark cast commits")
	_check(_room.material_state["cells"][Vector2i(7, 1)]["tags"].has("flooded"),
			"the channel floods mid-encounter")
	_refresh_overlay()
	await _frames(5)
	await _shot("3-encounter-casts")

	_check(_room.resolve_room_encounter(true) == "", "victory resolves")
	_check(_room.material_state["cells"][Vector2i(5, 1)]["tags"].has("fire"),
			"the exploration burn survived the encounter")
	_check(_room.material_state["cells"][Vector2i(7, 1)]["tags"].has("flooded"),
			"the encounter flood survived the victory")
	_refresh_overlay()
	await _frames(5)
	await _shot("4-victory-continuity")

	# Same casts, contexts swapped, on a fresh room: identical state (D-031).
	var final_state: Dictionary = _room.material_state.duplicate(true)
	var mirror := LdtkRoom.new()
	mirror.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(mirror)
	await _frames(10)
	_cast_sequence(mirror, ["encounter", "exploration", "exploration"])
	_check(mirror.material_state == final_state,
			"context-swapped replay lands on the identical state (D-031)")
	mirror.queue_free()

	SceneManager.ui_busy = false
	SceneManager.unified_encounters = false
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	print("REACTION REPLAY: %s" % ("FAIL" if _failed else "done"))
	get_tree().quit(1 if _failed else 0)


func _refresh_overlay() -> void:
	if _overlay != null:
		_overlay.queue_redraw()


func _draw_overlay() -> void:
	if _room == null or not _room.material_state.get("cells") is Dictionary:
		return
	for cell in _room.material_state["cells"]:
		var tags: Array = _room.material_state["cells"][cell]["tags"]
		if tags.is_empty():
			continue
		var pos: Vector2 = _room.cell_to_pos(cell)
		var offset := 0
		for tag in tags:
			var color: Color = TAG_COLORS.get(tag, Color(1, 0, 1, 0.8))
			_overlay.draw_rect(Rect2(pos + Vector2(-20 + offset * 14, 14),
					Vector2(12, 12)), color)
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
