extends "res://scripts/dev/unified_encounter_spike.gd"
## T-092/T-097 pivot spike: the deterministic intent-round prototype
## (D-026/D-027/D-036). Same room and party as T-089/T-090; the combat is
## intent rounds driven by the pure, unit-tested core in intent_logic.gd:
##
##   0. ENTER (T-097/D-036): exploration input gates immediately, a short
##      original placeholder sting plays with a strong ENCOUNTER/TURN-BASED
##      visual beat, the combat UI is revealed, and only then does the first
##      round declare and open player control. Local gating only - never
##      SceneTree.paused - so audio/tweens/coroutines cannot deadlock.
##   1. The enemy moves or declares its plan (rolling 3-verb queue - future
##      steps telegraph the VERB ONLY via IntentLogic.future_verbs; the
##      current action shows full detail: cells, exact damage, exact status).
##   2. The player sees every target and effect, live-updated as units move.
##   3. ALL party members (party_ids, not a hard-coded pair) act in any
##      order: Tab switches; each has a move budget + one ability.
##   4. Enemy actions resolve - hitting whoever REMAINS in the locked cells.
##   5. Environmental reactions resolve (burn ticks, guard expiry - exact).
##
## Counterplay on show: move out (dodge), body-block the line, Bash (stun
## cancels the intention), Shove (pushing the enemy cancels its aim), and the
## T-097 gray-box Guard (guarded_cells intercepts the spit line for an exact
## duration). Player-side previews always show exact damage first (D-026).
##
## Sol seam: when a T-096 deployment snapshot is provided, party members
## start the encounter on its cells (sol_snapshot_adapter.gd - tiny, isolated).
##
## Interactive keys in an encounter: WASD/arrows step the active unit,
## 1 Strike / 2 Bash / 3 Shove / 4 Guard (E confirms, Q cancels), Tab switch,
## Q end turn. Proof shots:
##   godot --path game scenes/dev/intent_prototype_spike.tscn \
##       --resolution 1280x720 -- --out=<dir>

const IntentLogic := preload("res://scripts/world/intent_logic.gd")
const SolSnapshotAdapter := preload("res://scripts/dev/sol_snapshot_adapter.gd")
const FormationLayoutScript := preload("res://scripts/world/party_formation_layout.gd")
const MOVE_BUDGET := 3
const PARTY_ORDER: Array[String] = ["hero", "friend", "blocker1", "blocker2"]
const FORMATION_MEMBER_IDS: Array[StringName] = [
	&"hero", &"friend", &"blocker1", &"blocker2",
]
const ABILITIES := {
	"strike": {"key": "1", "label": "Strike", "power": 0, "status": {}},
	"bash": {"key": "2", "label": "Bash", "power": -2, "status": {"stun": 1}},
	"shove": {"key": "3", "label": "Shove", "push": true},
	"guard": {"key": "4", "label": "Guard", "guard": true, "duration": 1},
}
const TELEGRAPH_FILL := Color(0.96, 0.16, 0.16, 0.34)
const TELEGRAPH_BORDER := Color(1.0, 0.45, 0.4, 0.9)
const MOVE_FILL := Color(0.10, 0.42, 1.0, 0.26)
const GUARD_FILL := Color(1.0, 0.84, 0.25, 0.30)
const GUARD_BORDER := Color(1.0, 0.9, 0.45, 0.9)

enum Phase { NONE, ENTER, DECLARE, PLAYER, RESOLVE, ENV }

var istate := {}
var node_of := {}
var plan: Array = []
var current_verb := ""
var current_intent := {}
var phase: int = Phase.NONE
var round_num := 0
var active_id := "hero"
var move_left := {}
var acted := {}
var turn_done := {}
var pending_ability := ""
var telegraph_cells: Array = []
var move_cells: Array = []
var cue_plays := 0
var formation_layout: RefCounted = FormationLayoutScript.new()
var selected_formation: StringName = &"square"
## T-096/T-097 seam: Sol's real neutral formation/deployment snapshot.
var deployment_snapshot := {}
var encounter_ui: CanvasLayer
var plan_label: Label
var intent_label: Label
var prompt_label: Label
var hp_labels := {}
var formation_label: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--formation="):
			var requested := StringName(arg.trim_prefix("--formation="))
			if formation_layout.is_valid_formation(requested):
				selected_formation = requested
	floor_low = load(TEX_FLOOR_LOW)
	floor_high = load(TEX_FLOOR_HIGH)
	_build_room()
	_spawn_party()
	_spawn_enemy()
	_spawn_block()
	_add_camera()
	_build_encounter_ui()
	print("INTENT PROTOTYPE: ready (intent rounds, deterministic, in-room)")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _scripted_tour()
		for line in tour_log:
			print(line)
		var failed := tour_log.filter(func(l: String) -> bool: return l.begins_with("FAIL"))
		print("INTENT PROTOTYPE: %s -> %s" % \
				["FAIL" if failed.size() > 0 else "done", out_dir])
		get_tree().quit(1 if failed.size() > 0 else 0)
	else:
		_add_hint()


func _add_hint() -> void:
	var ui := CanvasLayer.new()
	var label := Label.new()
	label.text = "T-097 intent prototype - WASD move; near the slime an encounter cue fires, then intent rounds.\nThe slime telegraphs its NEXT action fully (cells + exact damage) and its coming verbs.\nAll four of you act in any order: step out, body-block, 2 Bash (stun), 3 Shove, 4 Guard the line."
	label.position = Vector2(12, 84)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	ui.add_child(label)
	formation_label = Label.new()
	formation_label.position = Vector2(12, 146)
	formation_label.add_theme_font_size_override("font_size", 15)
	formation_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	formation_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	formation_label.add_theme_constant_override("outline_size", 4)
	ui.add_child(formation_label)
	_update_formation_label()
	add_child(ui)


func _process(_delta: float) -> void:
	if out_dir != "" or busy or leader == null:
		return
	if mode == Mode.EXPLORE:
		if leader.moving:
			return
		for action: String in DIR_ACTIONS:
			if Input.is_action_pressed(action):
				_player_act(DIR_ACTIONS[action])
				break
	elif phase == Phase.PLAYER:
		for action: String in DIR_ACTIONS:
			if Input.is_action_just_pressed(action):
				_encounter_step(active_id, DIR_ACTIONS[action])
				break


func _unhandled_input(event: InputEvent) -> void:
	if out_dir != "" or busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if mode == Mode.EXPLORE:
			match event.keycode:
				KEY_1: _select_formation(&"line")
				KEY_2: _select_formation(&"square")
				KEY_3: _select_formation(&"spaced")
			return
		if mode != Mode.ENCOUNTER or phase != Phase.PLAYER:
			return
		match event.keycode:
			KEY_1:
				_select_ability("strike")
			KEY_2:
				_select_ability("bash")
			KEY_3:
				_select_ability("shove")
			KEY_4:
				_select_ability("guard")
			KEY_E, KEY_ENTER:
				_commit_ability()
			KEY_TAB:
				_switch_unit()
			KEY_Q:
				if pending_ability != "":
					pending_ability = ""
					_update_ui()
				else:
					_end_unit(active_id)


## Exploration is the parent's behavior; once an encounter starts, the
## intent-round coroutine owns `busy` until the player phase opens.
func _player_act(dir: Vector2i) -> void:
	if mode == Mode.ENCOUNTER:
		return
	busy = true
	if _try_leader_step(dir):
		await leader.move_finished
		_check_detection()
	if mode == Mode.ENCOUNTER:
		return
	busy = false


## --- encounter lifecycle ------------------------------------------------------

## T-097/D-036 ENTER phase: gate input immediately (mode + phase + busy, all
## local - never SceneTree.paused), play the cue, reveal the combat UI, THEN
## declare and open the first player phase. The cue runs exactly once per
## encounter because a resolved encounter never restarts (D-028).
func _start_encounter() -> void:
	if mode == Mode.ENCOUNTER:
		return
	mode = Mode.ENCOUNTER
	phase = Phase.ENTER
	busy = true
	for i in followers.size():
		if follower_tweens[i] != null and follower_tweens[i].is_valid():
			follower_tweens[i].kill()
		var f := followers[i] as GridActor
		f.position = room.cell_to_pos(f.cell)
		room.occupy(f, f.cell)
	node_of = {"hero": leader, "friend": followers[0],
			"blocker1": followers[1], "blocker2": followers[2],
			"slime": enemy_actor}
	_build_istate()
	deployment_snapshot = _build_deployment_snapshot()
	_apply_deployment_snapshot()
	plan = IntentLogic.make_plan(istate, "slime")
	print("INTENT PROTOTYPE: encounter started in-room at leader ", leader.cell)
	await _play_encounter_cue()
	for id: String in node_of:
		_attach_intent_hp_label(id)
	encounter_ui.visible = true
	_run_round()


## Short original placeholder sting (generated in code, no assets) plus a
## strong full-screen ENCOUNTER / TURN-BASED beat. Timing is tween-driven
## only, so nothing here can deadlock the round coroutine.
func _play_encounter_cue() -> void:
	cue_plays += 1
	var sting := AudioStreamPlayer.new()
	sting.stream = _make_sting()
	sting.finished.connect(sting.queue_free)
	add_child(sting)
	sting.play()
	var banner := CanvasLayer.new()
	banner.layer = 5
	var strip := ColorRect.new()
	strip.color = Color(0.06, 0.02, 0.10, 0.85)
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 0.36
	strip.anchor_bottom = 0.60
	var label := Label.new()
	label.text = "!  ENCOUNTER  -  TURN-BASED  !"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 8)
	strip.add_child(label)
	banner.add_child(strip)
	add_child(banner)
	strip.modulate.a = 0.0
	var tw_in := create_tween()
	tw_in.tween_property(strip, "modulate:a", 1.0, 0.12)
	await tw_in.finished
	if out_dir != "":
		await _shot("02-encounter-cue")
	else:
		await _frames(32)
	var tw_out := create_tween()
	tw_out.tween_property(strip, "modulate:a", 0.0, 0.18)
	await tw_out.finished
	banner.queue_free()


## A tiny original three-note rising square-wave arpeggio, synthesized here
## so the placeholder sting ships no third-party audio.
func _make_sting() -> AudioStreamWAV:
	var rate := 22050
	var notes: Array = [523.25, 659.25, 783.99]  # C5 E5 G5
	var data := PackedByteArray()
	for n in notes.size():
		var freq: float = notes[n]
		var length := 0.11 if n < notes.size() - 1 else 0.24
		var count := int(rate * length)
		for i in count:
			var t := float(i) / rate
			var envelope := 1.0 - float(i) / count
			var v := (0.22 if fmod(t * freq, 1.0) < 0.5 else -0.22) * envelope
			var s := int(clampf(v, -1.0, 1.0) * 32767.0)
			data.append(s & 0xFF)
			data.append((s >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _build_istate() -> void:
	var blocked: Dictionary = room.blocked.duplicate()
	blocked[block.cell] = true  # the pushable block is terrain to the intent AI
	istate = {"width": room.width, "height": room.height, "blocked": blocked,
			"units": {
				"hero": {"id": "hero", "cell": leader.cell, "hp": 20,
						"max_hp": 20, "atk": 5, "df": 2, "side": "party",
						"statuses": {}},
				"friend": {"id": "friend", "cell": (followers[0] as GridActor).cell,
						"hp": 14, "max_hp": 14, "atk": 4, "df": 1,
						"side": "party", "statuses": {}},
				"blocker1": {"id": "blocker1", "cell": (followers[1] as GridActor).cell,
						"hp": 10, "max_hp": 10, "atk": 2, "df": 1,
						"side": "party", "statuses": {}},
				"blocker2": {"id": "blocker2", "cell": (followers[2] as GridActor).cell,
						"hp": 10, "max_hp": 10, "atk": 2, "df": 1,
						"side": "party", "statuses": {}},
				"slime": {"id": "slime", "cell": enemy_actor.cell, "hp": 12,
						"max_hp": 12, "atk": 3, "df": 1, "side": "enemy",
						"statuses": {}},
			}}


func _select_formation(formation_id: StringName) -> void:
	if not formation_layout.is_valid_formation(formation_id):
		return
	selected_formation = formation_id
	_update_formation_label()


func _update_formation_label() -> void:
	if formation_label != null:
		formation_label.text = "Encounter formation: %s  [1]line [2]square [3]spaced" \
				% String(selected_formation).to_upper()


## Build Sol's neutral snapshot from this room and Fable's current party ids.
## The formation planner owns every offset/fallback choice; this scene only
## supplies live cells, terrain exclusions, elevation, and the authored ramp.
func _build_deployment_snapshot() -> Dictionary:
	var member_cells := {
		&"hero": leader.cell,
		&"friend": (followers[0] as GridActor).cell,
		&"blocker1": (followers[1] as GridActor).cell,
		&"blocker2": (followers[2] as GridActor).cell,
	}
	var walkable_cells: Array[Vector2i] = []
	for y in room.height:
		for x in room.width:
			var cell := Vector2i(x, y)
			if not room.blocked.has(cell) and not room.pits.has(cell):
				walkable_cells.append(cell)
	var prop_cells: Array[Vector2i] = []
	if block != null:
		prop_cells.append(block.cell)
	var facing: Vector2i = leader.facing
	if not FormationLayoutScript.CARDINAL_DIRECTIONS.has(facing):
		facing = Vector2i.UP
	var ramp_edges: Array = [{
		"from": RAMP_CELL,
		"to": Vector2i(RAMP_CELL.x, RAMP_CELL.y - 1),
	}]
	return formation_layout.plan_deployment(
			selected_formation,
			&"hero",
			facing,
			FORMATION_MEMBER_IDS,
			member_cells,
			walkable_cells,
			[],
			[enemy_actor.cell],
			prop_cells,
			room.elevation,
			ramp_edges)


## Reposition party members onto Sol's planner output. Validate the complete
## snapshot first, then vacate all four old cells before occupying any target;
## this allows legal formation swaps when one member's target is another
## member's exploration cell without overwriting the occupancy map.
func _apply_deployment_snapshot() -> void:
	if deployment_snapshot.is_empty():
		return
	var starts: Dictionary = SolSnapshotAdapter.encounter_start_cells(
			deployment_snapshot, PARTY_ORDER)
	if starts.size() != PARTY_ORDER.size():
		deployment_snapshot = {}
		return
	var unique := {}
	for id: String in starts:
		var unit := node_of.get(id) as GridActor
		var c: Vector2i = starts[id]
		if unit == null or unique.has(c) or not _deployment_cell_is_legal(c):
			deployment_snapshot = {}
			return
		unique[c] = true
	for id: String in PARTY_ORDER:
		room.vacate(node_of[id])
	for id: String in PARTY_ORDER:
		var unit := node_of[id] as GridActor
		var c: Vector2i = starts[id]
		room.occupy(unit, c)
		unit.cell = c
		unit.position = room.cell_to_pos(c)
		istate["units"][id]["cell"] = c


func _deployment_cell_is_legal(cell: Vector2i) -> bool:
	if not room.in_bounds(cell) or room.blocked.has(cell) or room.pits.has(cell):
		return false
	var occupant := room.get_occupant(cell)
	return occupant == null or (
			node_of.values().has(occupant) and occupant != enemy_actor)


func _sync_cells() -> void:
	for id: String in node_of:
		var node = node_of[id]
		if node != null and istate["units"].has(id):
			istate["units"][id]["cell"] = node.cell


func _run_round() -> void:
	busy = true
	phase = Phase.DECLARE
	round_num += 1
	pending_ability = ""
	_sync_cells()
	# Invalid plans (dead/changed target, illegal head) rebuild the whole
	# horizon; otherwise the ordinary refill keeps already-shown verbs.
	if IntentLogic.plan_needs_rebuild(istate, "slime", plan):
		plan = IntentLogic.make_plan(istate, "slime")
	else:
		plan = IntentLogic.refill_plan(istate, "slime", plan)
	var intent: Dictionary = IntentLogic.declare(istate, "slime", plan[0]["verb"])
	if intent.get("verb", "") == "stunned":
		current_verb = "stunned"  # the plan is NOT consumed - it resumes
	elif intent.get("invalid", false):
		# A pathological room can make even a rebuilt head impossible; the
		# round then stalls visibly - it never consumes a plan step (T-097).
		plan = IntentLogic.make_plan(istate, "slime")
		intent = IntentLogic.declare(istate, "slime", plan[0]["verb"])
		if intent.get("invalid", false):
			intent = {"owner": "slime", "verb": "stalled", "cells": [],
					"damage": 0, "status": {}, "canceled": true}
			current_verb = "stalled"
		else:
			current_verb = str(plan.pop_front()["verb"])
	else:
		current_verb = str(plan.pop_front()["verb"])
	current_intent = intent
	if current_intent.get("verb", "") == "move":
		await _animate_enemy_path(current_intent.get("path", []))
	_set_telegraph()
	phase = Phase.PLAYER
	for id: String in PARTY_ORDER:
		move_left[id] = MOVE_BUDGET
		acted[id] = false
		turn_done[id] = false
	active_id = PARTY_ORDER[0]
	_refresh_move_cells()
	_update_ui()
	busy = false


func _finish_round() -> void:
	busy = true
	phase = Phase.RESOLVE
	pending_ability = ""
	move_cells = []
	queue_redraw()
	_sync_cells()
	var results: Array = IntentLogic.resolve(istate, current_intent)
	for r: Dictionary in results:
		var victim := node_of[r["id"]] as GridActor
		if r.get("blocked", false):
			_popup(victim, "Blocked!")
			continue
		_popup(victim, "-%d" % int(r["damage"]))
		victim.modulate = Color(1.0, 0.5, 0.5)
	if results.is_empty() and not current_intent.get("canceled", false) \
			and current_intent.get("verb", "") in ["spit", "slam"]:
		intent_label.text = "Dodged - the %s hit nobody!" % current_intent["verb"]
	if results.size() > 0:
		await _frames(16)
		for r: Dictionary in results:
			(node_of[r["id"]] as GridActor).modulate = Color.WHITE
	telegraph_cells = []
	queue_redraw()
	phase = Phase.ENV
	var ticks: Array = IntentLogic.environment_tick(istate)
	for t: Dictionary in ticks:
		_popup(node_of[t["id"]], "-%d burn" % int(t["damage"]))
	if ticks.size() > 0:
		await _frames(16)
	_refresh_all_hp()
	queue_redraw()  # guard overlays may have expired at the tick
	_run_round()


func _end_encounter() -> void:
	print("INTENT PROTOTYPE: enemy resolved; exploration continues in-place")
	var tw := enemy_actor.create_tween()
	tw.tween_property(enemy_actor, "modulate:a", 0.0, 0.25)
	await tw.finished
	room.unregister(enemy_actor)
	enemy_actor.queue_free()
	enemy_actor = null
	for f in followers:
		room.vacate(f)
	trail.clear()
	for f in followers:
		trail.append((f as GridActor).cell)
	for id: String in hp_labels:
		hp_labels[id].queue_free()
	hp_labels.clear()
	telegraph_cells = []
	move_cells = []
	queue_redraw()
	encounter_ui.visible = false
	phase = Phase.NONE
	mode = Mode.EXPLORE


## --- player actions -------------------------------------------------------------

func _encounter_step(id: String, dir: Vector2i) -> void:
	if phase != Phase.PLAYER:
		return
	if turn_done.get(id, true) or int(move_left.get(id, 0)) <= 0:
		return
	var unit := node_of[id] as GridActor
	if unit.moving or not unit.try_step(dir):
		return
	busy = true
	await unit.move_finished
	move_left[id] = int(move_left[id]) - 1
	_sync_cells()
	_refresh_move_cells()
	_update_ui()
	busy = false


func _select_ability(ability_name: String) -> void:
	if acted.get(active_id, true) or turn_done.get(active_id, true):
		return
	var ability: Dictionary = ABILITIES[ability_name]
	if not ability.get("guard", false):
		if enemy_actor == null \
				or not _adjacent((node_of[active_id] as GridActor).cell, enemy_actor.cell):
			prompt_label.text = "%s must stand adjacent to the slime for that." \
					% _display_name(active_id)
			return
	pending_ability = ability_name
	_update_ui()


func _commit_ability() -> void:
	if pending_ability == "" or enemy_actor == null:
		return
	busy = true
	_sync_cells()
	var ability: Dictionary = ABILITIES[pending_ability]
	if ability.get("push", false):
		var actor := node_of[active_id] as GridActor
		var dir: Vector2i = IntentLogic._axis_dir_toward(actor.cell, enemy_actor.cell)
		if IntentLogic.push_unit(istate, "slime", dir, current_intent):
			await _animate_enemy_to(istate["units"]["slime"]["cell"])
			_popup(enemy_actor, "Pushed!")
			_set_telegraph()
		else:
			_popup(enemy_actor, "Won't budge!")
	elif ability.get("guard", false):
		var actor := node_of[active_id] as GridActor
		IntentLogic.apply_guard(istate, active_id, actor.facing,
				int(ability["duration"]))
		_popup(actor, "Guard!")
		queue_redraw()  # the guarded cells render immediately
	else:
		var shown: Dictionary = IntentLogic.player_attack_resolve(
				istate, active_id, "slime", ability)
		_popup(enemy_actor, "-%d" % int(shown["damage"]))
		enemy_actor.modulate = Color(1.0, 0.5, 0.5)
		await _frames(10)
		if enemy_actor != null:
			enemy_actor.modulate = Color.WHITE
		if shown["status"].has("stun"):
			current_intent["canceled"] = true
			_set_telegraph()
			intent_label.text = "Intention canceled - the slime is stunned!"
		_refresh_all_hp()
		if int(istate["units"]["slime"]["hp"]) <= 0:
			await _end_encounter()
			busy = false
			return
	acted[active_id] = true
	pending_ability = ""
	_update_ui()
	busy = false


## Tab: the next roster member whose turn is still open (any order, D-027).
func _switch_unit() -> void:
	var idx := PARTY_ORDER.find(active_id)
	for offset in range(1, PARTY_ORDER.size()):
		var candidate: String = PARTY_ORDER[(idx + offset) % PARTY_ORDER.size()]
		if not turn_done.get(candidate, true):
			active_id = candidate
			pending_ability = ""
			_refresh_move_cells()
			_update_ui()
			return


func _end_unit(id: String) -> void:
	turn_done[id] = true
	pending_ability = ""
	for pid: String in PARTY_ORDER:
		if not turn_done.get(pid, true):
			active_id = pid
			_refresh_move_cells()
			_update_ui()
			return
	_finish_round()


## --- enemy animation --------------------------------------------------------------

func _animate_enemy_path(path: Array) -> void:
	for c: Vector2i in path:
		room.move_occupant(enemy_actor, enemy_actor.cell, c)
		enemy_actor.cell = c
		var tw := enemy_actor.create_tween()
		tw.tween_property(enemy_actor, "position", room.cell_to_pos(c), MOVE_TIME)
		await tw.finished


func _animate_enemy_to(c: Vector2i) -> void:
	room.move_occupant(enemy_actor, enemy_actor.cell, c)
	enemy_actor.cell = c
	var tw := enemy_actor.create_tween()
	tw.tween_property(enemy_actor, "position", room.cell_to_pos(c), MOVE_TIME)
	await tw.finished


## --- presentation ------------------------------------------------------------------

func _draw() -> void:
	super._draw()
	if room == null:
		return
	for c: Vector2i in move_cells:
		var pos := Vector2(c.x * TILE, c.y * TILE - room.lift_px(c))
		draw_rect(Rect2(pos, Vector2(TILE, TILE)), MOVE_FILL)
	for effect: Dictionary in istate.get("effects", []):
		for c: Vector2i in effect.get("cells", []):
			var pos := Vector2(c.x * TILE, c.y * TILE - room.lift_px(c))
			draw_rect(Rect2(pos, Vector2(TILE, TILE)), GUARD_FILL)
			draw_rect(Rect2(pos + Vector2(4, 4), Vector2(TILE - 8, TILE - 8)),
					GUARD_BORDER, false, 2.0)
	for c: Vector2i in telegraph_cells:
		var pos := Vector2(c.x * TILE, c.y * TILE - room.lift_px(c))
		draw_rect(Rect2(pos, Vector2(TILE, TILE)), TELEGRAPH_FILL)
		draw_rect(Rect2(pos + Vector2(2, 2), Vector2(TILE - 4, TILE - 4)),
				TELEGRAPH_BORDER, false, 3.0)


func _set_telegraph() -> void:
	if current_intent.get("canceled", false):
		telegraph_cells = []
	else:
		telegraph_cells = current_intent.get("cells", [])
	queue_redraw()


## Reachable cells for the active unit's remaining moves - the player-side
## "you see exactly where you can move" half of the transparency rule.
func _refresh_move_cells() -> void:
	move_cells = []
	if phase != Phase.PLAYER or turn_done.get(active_id, true):
		queue_redraw()
		return
	var origin := (node_of[active_id] as GridActor).cell
	var limit := int(move_left.get(active_id, 0))
	var dist := {origin: 0}
	var frontier: Array = [origin]
	while frontier.size() > 0:
		var c: Vector2i = frontier.pop_front()
		if int(dist[c]) >= limit:
			continue
		for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + dir
			if not dist.has(n) and room.is_walkable(n):
				dist[n] = int(dist[c]) + 1
				move_cells.append(n)
				frontier.append(n)
	queue_redraw()


func _build_encounter_ui() -> void:
	encounter_ui = CanvasLayer.new()
	plan_label = _make_ui_label(Vector2(12, 8), 18)
	intent_label = _make_ui_label(Vector2(12, 34), 16)
	prompt_label = _make_ui_label(Vector2(12, 668), 16)
	encounter_ui.add_child(plan_label)
	encounter_ui.add_child(intent_label)
	encounter_ui.add_child(prompt_label)
	encounter_ui.visible = false
	add_child(encounter_ui)


func _make_ui_label(pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _update_ui() -> void:
	if mode != Mode.ENCOUNTER:
		return
	# Future steps serialize through future_verbs ONLY - the label never sees
	# targets, destinations, or cells (T-097 acceptance 6).
	plan_label.text = "Round %d | Slime: %s | coming verbs: %s" \
			% [round_num, current_verb.to_upper(),
			", ".join(IntentLogic.future_verbs(plan))]
	match current_intent.get("verb", ""):
		"stunned":
			intent_label.text = "The slime is stunned - it declares nothing this round!"
		"stalled":
			intent_label.text = "The slime cannot act this round."
		"move":
			intent_label.text = "The slime repositioned - no attack declared this round."
		"spit":
			if current_intent.get("canceled", false):
				intent_label.text = "Intention canceled!"
			else:
				intent_label.text = "Spit telegraph: %d dmg + Burn(%d) on the red line - would hit: %s" \
						% [int(current_intent["damage"]),
						int(current_intent["status"].get("burn", 0)),
						_would_hit_text()]
		"slam":
			if current_intent.get("canceled", false):
				intent_label.text = "Intention canceled!"
			else:
				intent_label.text = "Slam telegraph: %d dmg on the red cell - would hit: %s" \
						% [int(current_intent["damage"]), _would_hit_text()]
	if pending_ability != "":
		var ability: Dictionary = ABILITIES[pending_ability]
		if ability.get("push", false):
			prompt_label.text = "%s: Shove - push the slime one cell (cancels its aim) - E confirm, Q cancel" \
					% _display_name(active_id)
		elif ability.get("guard", false):
			prompt_label.text = "%s: Guard - protect the 3 cells ahead for %d round(s); blocks line attacks - E confirm, Q cancel" \
					% [_display_name(active_id), int(ability["duration"])]
		else:
			var shown: Dictionary = IntentLogic.player_attack_preview(
					istate, active_id, "slime", ability)
			prompt_label.text = "%s: %s - exactly %d dmg (Slime %d -> %d)%s - E confirm, Q cancel" \
					% [_display_name(active_id), ability["label"],
					int(shown["damage"]), int(istate["units"]["slime"]["hp"]),
					int(shown["target_hp_after"]),
					" + Stun(1)" if shown["status"].has("stun") else ""]
	else:
		prompt_label.text = "%s - moves left %d%s - [1]Strike [2]Bash [3]Shove [4]Guard [Tab]switch [Q]end turn" \
				% [_display_name(active_id), int(move_left.get(active_id, 0)),
				" (acted)" if acted.get(active_id, false) else ""]


func _would_hit_text() -> String:
	_sync_cells()
	var shown: Array = IntentLogic.preview(istate, current_intent)
	if shown.is_empty():
		return "nobody (dodged)"
	var names: Array = []
	for r: Dictionary in shown:
		if r.get("blocked", false):
			names.append("%s's guard (blocked)" % _display_name(r["id"]))
		else:
			names.append(_display_name(r["id"]))
	return ", ".join(names)


func _display_name(id: String) -> String:
	match id:
		"hero": return "Hero"
		"friend": return "Friend"
		"blocker1": return "Blocker1"
		"blocker2": return "Blocker2"
		"slime": return "Slime"
	return id.capitalize()


func _attach_intent_hp_label(id: String) -> void:
	var unit: Dictionary = istate["units"][id]
	var label := Label.new()
	label.text = "%s %d/%d" % [_display_name(id), int(unit["hp"]), int(unit["max_hp"])]
	label.position = Vector2(-32, -80 if id == "hero" else -62)
	label.size = Vector2(64, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 3
	node_of[id].add_child(label)
	hp_labels[id] = label


func _refresh_all_hp() -> void:
	for id: String in hp_labels:
		var unit: Dictionary = istate["units"][id]
		hp_labels[id].text = "%s %d/%d" % [_display_name(id),
				maxi(0, int(unit["hp"])), int(unit["max_hp"])]


## --- proof tour ---------------------------------------------------------------------

func _until_player_phase(max_frames := 900) -> bool:
	for _i in max_frames:
		if mode == Mode.ENCOUNTER and phase == Phase.PLAYER and not busy:
			return true
		if mode == Mode.EXPLORE and enemy_actor == null:
			return true
		await _frames(1)
	return false


## No target names or cells may ever reach the future-verbs label; "Slime" is
## the acting enemy itself, so it is allowed.
func _future_ui_leaks() -> bool:
	for token: String in ["Hero", "Friend", "Blocker", "(", ")"]:
		if plan_label.text.contains(token):
			return true
	return false


func _scripted_tour() -> void:
	await _frames(6)
	var scene_before := get_tree().current_scene
	var camera_before := get_viewport().get_camera_2d()
	await _shot("01-explore-approach")
	# Approach: up the stairs onto the plateau until detection triggers.
	for dir: Vector2i in [Vector2i.UP, Vector2i.UP, Vector2i.UP, Vector2i.UP,
			Vector2i.LEFT]:
		if mode == Mode.ENCOUNTER:
			break
		await _player_act(dir)
	# 1) ENTER phase: input gates immediately, before the cue completes.
	_assert(mode == Mode.ENCOUNTER and phase == Phase.ENTER,
			"detection opened the ENTER phase")
	var cell_during_cue := leader.cell
	_player_act(Vector2i.LEFT)                       # refused: encounter mode
	await _encounter_step("hero", Vector2i.LEFT)     # refused: not player phase
	_assert(leader.cell == cell_during_cue,
			"exploration and combat input are gated during the entry cue")
	_assert(not encounter_ui.visible,
			"the combat UI is revealed only after the cue")
	_assert(await _until_player_phase(),
			"the entry cue completed and opened the first player phase")
	_assert(cue_plays == 1, "the encounter cue ran exactly once")
	_assert(not deployment_snapshot.is_empty(),
			"Sol's real formation planner supplied the encounter deployment")
	_assert(deployment_snapshot.get("deployment_cells", {}).size() == PARTY_ORDER.size(),
			"the deployment snapshot contains all four party members")
	# 2) Continuity across entry: same scene/camera/room, party where it stood.
	_assert(get_tree().current_scene == scene_before, "no scene change at entry")
	_assert(get_viewport().get_camera_2d() == camera_before,
			"no camera change at entry")
	_assert(leader.cell == Vector2i(7, 2),
			"the leader stands exactly where detection caught it")
	# Round 1: d=2 plan opens with a reposition; future verbs telegraph.
	_assert(current_verb == "move", "round 1 declares the plan's move")
	var shown_r1: Array = IntentLogic.future_verbs(plan)
	_assert(shown_r1 == ["spit", "slam"],
			"two upcoming verbs stay visible after the pop")
	_assert(not _future_ui_leaks(),
			"the future UI shows verbs only - no targets or cells")
	await _shot("03-first-intent")
	# 3) All four members act, in arbitrary (non-roster) order.
	var blocker1_start := (followers[1] as GridActor).cell
	await _encounter_step("blocker1", Vector2i.RIGHT)
	_assert((followers[1] as GridActor).cell == blocker1_start + Vector2i.RIGHT,
			"blocker1 moved first, out of roster order")
	var blocker2_start := (followers[2] as GridActor).cell
	await _encounter_step("blocker2", Vector2i.LEFT)
	await _encounter_step("blocker2", Vector2i.RIGHT)
	_assert((followers[2] as GridActor).cell == blocker2_start,
			"blocker2 moved out and back after blocker1")
	# Player-side preview = result.
	var slime_hp_before := int(istate["units"]["slime"]["hp"])
	var strike_preview: Dictionary = IntentLogic.player_attack_preview(
			istate, "hero", "slime", ABILITIES["strike"])
	_select_ability("strike")
	_update_ui()
	await _shot("04-strike-preview")
	await _commit_ability()
	_assert(int(istate["units"]["slime"]["hp"])
			== slime_hp_before - int(strike_preview["damage"]),
			"player strike landed exactly the previewed damage")
	await _encounter_step("friend", Vector2i.RIGHT)
	_assert((followers[0] as GridActor).cell == Vector2i(9, 2),
			"the friend moved too - all four acted this round")
	await _shot("05-four-units-any-order")
	_end_unit("blocker2")
	_end_unit("hero")
	_end_unit("blocker1")
	_end_unit("friend")
	_assert(await _until_player_phase(), "round 2 reached the player phase")
	# 4) Ordinary refill: the verbs telegraphed in round 1 come true in order.
	_assert(current_verb == shown_r1[0],
			"the first telegraphed verb (spit) is now the current action")
	_assert(IntentLogic.future_verbs(plan)[0] == shown_r1[1],
			"the second telegraphed verb survived the ordinary refill")
	_assert(telegraph_cells.size() == 3, "spit locks a 3-cell line")
	await _shot("06-spit-telegraph")
	# 5) Guard vs the line: square deployment places blocker2 directly behind
	# the leader, so a blocked step faces the incoming line without moving.
	await _encounter_step("blocker2", Vector2i.UP)  # bump on the hero: turn only
	_assert((followers[2] as GridActor).cell == blocker2_start
			and (followers[2] as GridActor).facing == Vector2i.UP,
			"a blocked step turns the guard toward the line without moving")
	_switch_unit()  # hero -> friend
	_switch_unit()  # friend -> blocker1
	_switch_unit()  # blocker1 -> blocker2
	_assert(active_id == "blocker2", "tab cycling reaches every open member")
	_select_ability("guard")
	await _commit_ability()
	var effects: Array = istate.get("effects", [])
	_assert(effects.size() == 1 and effects[0]["cells"]
			== [Vector2i(7, 2), Vector2i(6, 2), Vector2i(8, 2)],
			"the guard covers front, front-left, and front-right")
	# The hero steps out of the line; the friend stays behind the guard wall.
	await _encounter_step("hero", Vector2i.UP)
	await _encounter_step("hero", Vector2i.RIGHT)
	_sync_cells()
	var would: Array = IntentLogic.preview(istate, current_intent)
	_assert(would.size() == 1 and would[0].get("blocked", false)
			and would[0]["id"] == "blocker2",
			"the live preview shows the guard blocking the line")
	var hero_hp := int(istate["units"]["hero"]["hp"])
	var friend_hp := int(istate["units"]["friend"]["hp"])
	_update_ui()
	await _shot("07-guard-vs-line")
	_end_unit("hero")
	_end_unit("friend")
	_end_unit("blocker1")
	_end_unit("blocker2")
	_assert(await _until_player_phase(), "round 3 reached the player phase")
	# 6) Guard preview equaled resolution: nobody was damaged or burned.
	_assert(int(istate["units"]["hero"]["hp"]) == hero_hp
			and int(istate["units"]["friend"]["hp"]) == friend_hp,
			"the blocked spit dealt no damage - preview equals resolution")
	_assert(not istate["units"]["friend"]["statuses"].has("burn")
			and not istate["units"]["hero"]["statuses"].has("burn"),
			"the blocked spit applied no status either")
	_assert(istate.get("effects", []).is_empty(),
			"the guard expired after exactly its 1-round duration")
	# 7) Target invalidation: the guarded formation changed the nearest target,
	# so the old hero plan rebuilds instead of continuing with its stale slam.
	_assert(current_verb == "move",
			"the invalidated plan rebuilt (a stale continuation would slam)")
	_assert(str(plan[0]["target_id"]) != "hero"
			and istate["units"].has(str(plan[0]["target_id"])),
			"the rebuilt plan retargets from current state (private context)")
	_assert(IntentLogic.future_verbs(plan) == ["spit", "slam"],
			"the rebuilt horizon telegraphs deterministically")
	_assert(not _future_ui_leaks(), "the retarget never leaks to the future UI")
	await _shot("08-replan-after-invalidation")
	# 8) Stun still cancels/skips: bash the slime, it skips its next declare.
	await _encounter_step("hero", Vector2i.DOWN)
	_select_ability("bash")
	await _commit_ability()
	_assert(int(istate["units"]["slime"]["statuses"].get("stun", 0)) == 1,
			"stun landed at exactly the stated duration")
	await _shot("09-stun-lands")
	_end_unit("hero")
	_end_unit("friend")
	_end_unit("blocker1")
	_end_unit("blocker2")
	_assert(await _until_player_phase(), "round 4 reached the player phase")
	_assert(current_verb == "stunned", "stunned enemy skips exactly one declare")
	_assert(IntentLogic.future_verbs(plan).size() == 3,
			"a skipped declare consumes no plan step")
	# Finish the fight through the same committed-preview path.
	_select_ability("strike")
	await _commit_ability()
	_end_unit("hero")   # active advances to the friend
	_switch_unit()      # friend -> blocker1: the flank strikes too
	_select_ability("strike")
	await _commit_ability()
	_end_unit("friend")
	_end_unit("blocker1")
	_end_unit("blocker2")
	_assert(await _until_player_phase(), "round 5 reached the player phase")
	_select_ability("strike")
	await _commit_ability()
	_assert(await _until_player_phase(), "victory resolved")
	# 9) Continuity across victory: the same world simply continues.
	_assert(mode == Mode.EXPLORE and enemy_actor == null,
			"encounter resolved in-room (enemy defeated)")
	_assert(get_tree().current_scene == scene_before,
			"no scene change across the whole encounter")
	_assert(get_viewport().get_camera_2d() == camera_before,
			"no camera change across the whole encounter")
	_assert(cue_plays == 1, "the cue never replayed mid-encounter")
	_assert(block.cell == BLOCK_CELL, "untouched puzzle block undisturbed")
	_assert(room.blocked.has(CHEST_CELL), "chest cell still blocked")
	await _player_act(Vector2i.RIGHT)
	await _player_act(Vector2i.RIGHT)
	await _frames(8)
	await _shot("10-victory-continuous")
