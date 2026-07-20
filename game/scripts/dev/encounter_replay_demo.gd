extends Node
## S-012/TK-005: the full production encounter replay with deterministic
## proof, windowed. One scripted fight runs on a fresh session with captures
## (ENTER cue, intent+forecast, counterplay, victory), then the IDENTICAL
## scripted inputs run again on a second fresh session and the complete event
## logs - every declared intent, forecast, resolution summary, final HP, and
## XP delta - must match byte-for-byte (D-026: zero RNG anywhere). Exits 1 on
## any FAIL.
##
##   cd game
##   Godot --path . scenes/dev/encounter_replay_demo.tscn -- --out=/abs/dir

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
	print("ENCOUNTER REPLAY: begin")
	var first := await _play_fight(true)
	var second := await _play_fight(false)
	_check(not first.is_empty() and not second.is_empty(),
			"both scripted fights completed")
	_check(first.get("victory", false) == true, "the scripted fight ends in victory")
	_check(first == second,
			"identical inputs produce the identical complete event log (D-026)")
	print("ENCOUNTER REPLAY: %s" % ("FAIL" if _failed else "done"))
	get_tree().quit(1 if _failed else 0)


## Plays one deterministic scripted fight on a fresh session and returns the
## complete event log. Captures only on the first pass.
func _play_fight(capture: bool) -> Dictionary:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.unified_encounters = true
	var record := {"rounds": [], "xp_before": SceneManager.total_xp}
	var room := LdtkRoom.new()
	room.level_path = "res://assets/levels/entity_test_room.ldtk"
	add_child(room)
	await _frames(10)
	SceneManager.ui_busy = true
	room.teleport(room.player, Vector2i(8, 5))
	await _frames(3)
	room.player.try_step(Vector2i.RIGHT)   # the real bump entry
	await _frames(5)
	var controller = room.room_encounter
	if controller == null:
		_check(false, "encounter began")
		room.queue_free()
		return {}
	if capture:
		await _shot("1-enter-cue")
		await _frames(42)   # past the ENTER beat: intent UI visible
		await _shot("2-intent-forecast")
	record["entry_intent"] = _intent_record(controller)
	# Round 1: shove the slime (cancels its intention), end the turn.
	controller.set_active_unit("hero")
	controller.shove("enc_9_5")
	record["shove_canceled"] = controller.current_intent.get("canceled", false)
	if capture:
		await _frames(5)
		await _shot("3-counterplay-shove")
	record["rounds"].append(_summary_record(controller.end_party_turn()))
	# Every later round: hero walks in and attacks until victory.
	var rounds := 0
	while room.active_encounter_id != "" and rounds < 30:
		controller = room.room_encounter
		if controller == null or not is_instance_valid(controller):
			break
		controller.set_active_unit("hero")
		record["rounds"].append(_intent_record(controller))
		# Walk into reach (budgeted), strike if adjacent, then end the turn.
		var steps := 0
		while steps < 8 and controller.moves_left("hero") > 0 \
				and not _hero_adjacent(controller):
			var hero_cell: Vector2i = controller.state["units"]["hero"]["cell"]
			var enemy_unit: Dictionary = controller.state["units"].get(
					"enc_9_5", {})
			if enemy_unit.is_empty():
				break
			var delta: Vector2i = enemy_unit["cell"] - hero_cell
			var step := Vector2i(signi(delta.x), 0) if delta.x != 0 \
					else Vector2i(0, signi(delta.y))
			if not controller.move_active(step):
				break
			steps += 1
		if _hero_adjacent(controller) and controller.can_act("hero"):
			var result: Dictionary = controller.attack("enc_9_5")
			record["rounds"].append({"attack": int(result.get("damage", -1))})
		if room.active_encounter_id == "" or room.room_encounter == null:
			break
		record["rounds"].append(_summary_record(controller.end_party_turn()))
		rounds += 1
	record["victory"] = room.active_encounter_id == ""
	record["xp_gained"] = SceneManager.total_xp - int(record["xp_before"])
	record["hero_hp_after"] = int(SceneManager.state.party_hp.get("hero", -1))
	record.erase("xp_before")
	if capture:
		await _frames(8)
		await _shot("4-victory")
	SceneManager.ui_busy = false
	room.queue_free()
	await _frames(3)
	SceneManager.unified_encounters = true
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	return record


func _hero_adjacent(controller) -> bool:
	var enemy_unit: Dictionary = controller.state["units"].get("enc_9_5", {})
	if enemy_unit.is_empty():
		return false
	var hero_cell: Vector2i = controller.state["units"]["hero"]["cell"]
	return absi(hero_cell.x - enemy_unit["cell"].x) \
			+ absi(hero_cell.y - enemy_unit["cell"].y) == 1


func _intent_record(controller) -> Dictionary:
	var intent: Dictionary = controller.current_intent
	return {"verb": str(intent.get("verb", "")),
			"cells": var_to_str(intent.get("cells", [])),
			"damage": int(intent.get("damage", 0)),
			"forecast": controller.forecast()}


func _summary_record(summary: Dictionary) -> Dictionary:
	return {"party_damage": int(summary.get("party_damage", -1)),
			"round": int(summary.get("round", -1)),
			"environment": (summary.get("environment", []) as Array).size()}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	print("  wrote ", path)
