extends "res://scripts/dev/unified_encounter_spike.gd"
## T-092 pivot spike: the deterministic intent-round prototype (D-026/D-027).
## Same room and party as T-089/T-090; the combat is replaced by intent
## rounds driven by the pure, unit-tested core in intent_logic.gd:
##
##   1. The enemy moves or declares its plan (rolling 3-verb queue - future
##      steps telegraph the VERB ONLY; the current action shows full detail:
##      target cells, exact damage, exact status).
##   2. The player sees every target and effect, live-updated as units move.
##   3. Party members act in any order (Tab switches; move + one ability).
##   4. Enemy actions resolve - hitting whoever REMAINS in the locked cells.
##   5. Environmental reactions resolve (burn ticks, exact durations).
##
## Counterplay on show: move out (dodge), body-block the line, Bash (stun
## cancels the intention), Shove (pushing the enemy cancels its aim).
## Player-side previews always show exact damage before committing (D-026).
##
## Interactive keys in an encounter: WASD/arrows step the active unit,
## 1 Strike / 2 Bash / 3 Shove (E confirms, Q cancels), Tab switch, Q end
## turn. Proof shots:
##   godot --path game scenes/dev/intent_prototype_spike.tscn \
##       --resolution 1280x720 -- --out=<dir>

const IntentLogic := preload("res://scripts/dev/intent_logic.gd")
const MOVE_BUDGET := 3
const ABILITIES := {
	"strike": {"key": "1", "label": "Strike", "power": 0, "status": {}},
	"bash": {"key": "2", "label": "Bash", "power": -2, "status": {"stun": 1}},
	"shove": {"key": "3", "label": "Shove", "push": true},
}
const TELEGRAPH_FILL := Color(0.96, 0.16, 0.16, 0.34)
const TELEGRAPH_BORDER := Color(1.0, 0.45, 0.4, 0.9)
const MOVE_FILL := Color(0.10, 0.42, 1.0, 0.26)

enum Phase { NONE, DECLARE, PLAYER, RESOLVE, ENV }

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
var encounter_ui: CanvasLayer
var plan_label: Label
var intent_label: Label
var prompt_label: Label
var hp_labels := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
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
	label.text = "T-092 intent prototype - WASD move; near the slime an intent round starts.\nIt telegraphs its NEXT action fully (cells + exact damage) and its coming verbs.\nCounter it: step out, body-block the line, 2 Bash (stun) or 3 Shove (push)."
	label.position = Vector2(12, 84)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	ui.add_child(label)
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
	if out_dir != "" or busy or mode != Mode.ENCOUNTER or phase != Phase.PLAYER:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_select_ability("strike")
			KEY_2:
				_select_ability("bash")
			KEY_3:
				_select_ability("shove")
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

func _start_encounter() -> void:
	mode = Mode.ENCOUNTER
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
	plan = IntentLogic.make_plan(istate, "slime")
	for id: String in node_of:
		_attach_intent_hp_label(id)
	encounter_ui.visible = true
	print("INTENT PROTOTYPE: encounter started in-room at leader ", leader.cell)
	_run_round()


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
	if plan.is_empty():
		plan = IntentLogic.make_plan(istate, "slime")
	var intent: Dictionary = IntentLogic.declare(istate, "slime", plan[0])
	if intent.get("verb", "") == "stunned":
		current_verb = "stunned"  # the plan is NOT consumed - it resumes
	elif intent.get("invalid", false):
		plan = IntentLogic.make_plan(istate, "slime")
		intent = IntentLogic.declare(istate, "slime", plan[0])
		current_verb = str(plan.pop_front())
	else:
		current_verb = str(plan.pop_front())
	current_intent = intent
	if current_intent.get("verb", "") == "move":
		await _animate_enemy_path(current_intent.get("path", []))
	_set_telegraph()
	phase = Phase.PLAYER
	for id: String in ["hero", "friend"]:
		move_left[id] = MOVE_BUDGET
		acted[id] = false
		turn_done[id] = false
	active_id = "hero"
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
		var victim: GridActor = node_of[r["id"]]
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
	_sync_cells()
	plan = IntentLogic.refill_plan(istate, "slime", plan)
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


func _switch_unit() -> void:
	var other := "friend" if active_id == "hero" else "hero"
	if not turn_done.get(other, true):
		active_id = other
		pending_ability = ""
		_refresh_move_cells()
		_update_ui()


func _end_unit(id: String) -> void:
	turn_done[id] = true
	pending_ability = ""
	if turn_done.get("hero", false) and turn_done.get("friend", false):
		_finish_round()
		return
	active_id = "friend" if id == "hero" else "hero"
	_refresh_move_cells()
	_update_ui()


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
	var upcoming: Array = []
	for verb in plan:
		upcoming.append(str(verb))  # future steps: verb only, never targets
	plan_label.text = "Round %d - Slime acts: %s   |   then (verbs only): %s" \
			% [round_num, current_verb.to_upper(), ", ".join(upcoming)]
	match current_intent.get("verb", ""):
		"stunned":
			intent_label.text = "The slime is stunned - it declares nothing this round!"
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
		else:
			var shown: Dictionary = IntentLogic.player_attack_preview(
					istate, active_id, "slime", ability)
			prompt_label.text = "%s: %s - exactly %d dmg (Slime %d -> %d)%s - E confirm, Q cancel" \
					% [_display_name(active_id), ability["label"],
					int(shown["damage"]), int(istate["units"]["slime"]["hp"]),
					int(shown["target_hp_after"]),
					" + Stun(1)" if shown["status"].has("stun") else ""]
	else:
		prompt_label.text = "%s - moves left %d%s - [1]Strike [2]Bash [3]Shove [Tab]switch [Q]end turn" \
				% [_display_name(active_id), int(move_left.get(active_id, 0)),
				" (acted)" if acted.get(active_id, false) else ""]


func _would_hit_text() -> String:
	_sync_cells()
	var shown: Array = IntentLogic.preview(istate, current_intent)
	if shown.is_empty():
		return "nobody (dodged)"
	var names: Array = []
	for r: Dictionary in shown:
		names.append(_display_name(r["id"]))
	return ", ".join(names)


func _display_name(id: String) -> String:
	match id:
		"hero": return "Hero"
		"friend": return "Friend"
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


func _scripted_tour() -> void:
	await _frames(6)
	var scene_before := get_tree().current_scene
	# Approach: up the stairs onto the plateau until detection triggers.
	for dir: Vector2i in [Vector2i.UP, Vector2i.UP, Vector2i.UP, Vector2i.UP,
			Vector2i.LEFT]:
		if mode == Mode.ENCOUNTER:
			break
		await _player_act(dir)
	_assert(await _until_player_phase(), "round loop reached the player phase")
	# Round 1: d=2 plan opens with a reposition; future verbs telegraph.
	_assert(current_verb == "move", "round 1 declares the plan's move")
	_assert(plan.size() == 2, "two upcoming verbs stay visible after the pop")
	await _shot("01-plan-bar")
	# Player-side preview = result.
	var slime_hp_before := int(istate["units"]["slime"]["hp"])
	var strike_preview: Dictionary = IntentLogic.player_attack_preview(
			istate, "hero", "slime", ABILITIES["strike"])
	_select_ability("strike")
	_update_ui()
	await _shot("02-strike-preview")
	await _commit_ability()
	_assert(int(istate["units"]["slime"]["hp"])
			== slime_hp_before - int(strike_preview["damage"]),
			"player strike landed exactly the previewed damage")
	await _encounter_step("friend", Vector2i.UP)
	await _encounter_step("friend", Vector2i.LEFT)
	_end_unit("hero")
	_end_unit("friend")
	_assert(await _until_player_phase(), "round 2 reached the player phase")
	# Round 2: the spit telegraph - full detail on the current action.
	_assert(current_verb == "spit", "round 2 declares the spit")
	_assert(telegraph_cells.size() == 3, "spit locks a 3-cell line")
	await _shot("03-spit-telegraph")
	# Hero steps out of the line; the friend steps INTO it as a body-block.
	await _encounter_step("hero", Vector2i.DOWN)
	_switch_unit()
	await _encounter_step("friend", Vector2i.DOWN)
	_sync_cells()
	var would: Array = IntentLogic.preview(istate, current_intent)
	_assert(would.size() == 1 and would[0]["id"] == "friend",
			"live preview re-targets the blocker after the swap")
	var telegraphed_damage := int(would[0]["damage"])
	_update_ui()
	await _shot("04-friend-blocks")
	var friend_hp_before := int(istate["units"]["friend"]["hp"])
	var hero_hp_before := int(istate["units"]["hero"]["hp"])
	_end_unit("hero")
	_end_unit("friend")
	_assert(await _until_player_phase(), "round 3 reached the player phase")
	_assert(int(istate["units"]["hero"]["hp"]) == hero_hp_before,
			"the hero who moved out took nothing (dodge works)")
	_assert(int(istate["units"]["friend"]["hp"])
			== friend_hp_before - telegraphed_damage - 1,
			"blocker took exactly the telegraphed spit damage plus one burn tick")
	_assert(int(istate["units"]["friend"]["statuses"].get("burn", 0)) == 1,
			"burn has exactly one round left")
	# Round 3: bash cancels the declared intention.
	await _encounter_step("hero", Vector2i.LEFT)
	_select_ability("bash")
	await _commit_ability()
	_assert(current_intent.get("canceled", false),
			"bash's stun canceled the declared intention")
	_assert(int(istate["units"]["slime"]["statuses"].get("stun", 0)) == 1,
			"stun landed at exactly the stated duration")
	await _shot("05-stun-cancels")
	_end_unit("hero")
	_select_ability("strike")
	await _commit_ability()
	_end_unit("friend")
	_assert(await _until_player_phase(), "round 4 reached the player phase")
	# Round 4: the stunned enemy skips its declare; burn has expired.
	_assert(current_verb == "stunned", "stunned enemy skips exactly one declare")
	_assert(not istate["units"]["friend"]["statuses"].has("burn"),
			"burn expired after exactly two ticks")
	_assert(int(istate["units"]["friend"]["hp"]) == friend_hp_before
			- telegraphed_damage - 2,
			"burn dealt exactly two total ticks of damage")
	# Finish the fight through the same committed-preview path.
	_select_ability("strike")
	await _commit_ability()
	_assert(await _until_player_phase(), "victory resolved")
	_assert(mode == Mode.EXPLORE and enemy_actor == null,
			"encounter resolved in-room (enemy defeated)")
	_assert(get_tree().current_scene == scene_before,
			"no scene change across the whole encounter")
	_assert(block.cell == BLOCK_CELL, "untouched puzzle block undisturbed")
	_assert(room.blocked.has(CHEST_CELL), "chest cell still blocked")
	await _player_act(Vector2i.RIGHT)
	await _player_act(Vector2i.RIGHT)
	await _frames(8)
	await _shot("06-victory-continuous")
