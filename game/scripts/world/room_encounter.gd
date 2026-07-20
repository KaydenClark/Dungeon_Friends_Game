class_name RoomEncounter
extends Node
## S-012/TK-002: production intent-round controller for one in-room encounter
## (D-025/D-026/D-027/D-036). Built by LdtkRoom.begin_room_encounter after
## party deployment; owns the promoted IntentLogic state mirrored from the
## live room (party units from roster stats at their deployed cells, the
## touched enemy from its authored EnemyStats, walls/pits/props blocked).
## Each round the enemy plan refills or rebuilds deterministically, the
## current intent declares with EXACT cells/damage/status, and only the verb
## sequence of future steps is ever exposed (D-026/D-027). A minimal intent
## panel and cell highlights reveal after the D-036 ENTER beat; the full
## action loop (party actions, resolution, environment) lands in TK-003/004.

const IntentLogic := preload("res://scripts/world/intent_logic.gd")

## Seconds between the encounter cue and the intent UI reveal (D-036: the
## mode change gets a readable beat before the first declaration shows).
const ENTER_REVEAL_DELAY := 0.6

var room: LdtkRoom
var state := {}
var enemy_id := ""
var plan: Array = []
var current_intent := {}
var round_number := 0
## S-012/TK-003 party turn bookkeeping: id -> {"moves": int, "acted": bool}.
## Every party unit gets its move budget and one action per round, spent in
## any order (D-027); end_party_turn resolves the enemy intent and starts
## the next round.
var active_unit_id := ""
var _turns := {}
## Round-start cells so an un-acted unit's movement can be undone exactly.
var _round_start_cells := {}
var _enemy_node: OverworldEnemy
var _panel: CanvasLayer
var _intent_label: Label
var _highlights: Node2D


## Mirrors the live room into an IntentLogic state and declares round one.
## Returns "" or a named error with nothing half-built (fail closed).
func setup(p_room: LdtkRoom, enemy: OverworldEnemy) -> String:
	if p_room == null or enemy == null or not is_instance_valid(enemy):
		return "invalid_encounter_setup"
	if enemy.stats == null:
		return "enemy_without_stats"
	room = p_room
	_enemy_node = enemy
	enemy_id = enemy.world_encounter_id
	var blocked := {}
	for cell in p_room.blocked:
		blocked[cell] = true
	for cell in p_room.pits:
		blocked[cell] = true
	for cell in p_room.occupants:
		var node: Node2D = p_room.occupants[cell]
		if node is Player or node is PartyFollower or node == enemy:
			continue
		blocked[cell] = true   # doors, blocks, chests, other frozen enemies
	var units := {}
	units[p_room.party_leader_id] = _party_unit(p_room.party_leader_id,
			p_room.player.cell)
	for follower in p_room.party_followers:
		units[follower.member_id] = _party_unit(follower.member_id,
				follower.cell)
	units[enemy_id] = {"id": enemy_id, "cell": enemy.cell,
			"hp": enemy.stats.max_hp, "max_hp": enemy.stats.max_hp,
			"atk": enemy.stats.attack, "df": enemy.stats.defense,
			"side": "enemy", "statuses": {}}
	state = {"width": p_room.width, "height": p_room.height,
			"blocked": blocked, "units": units, "effects": []}
	begin_round()
	return ""


func _party_unit(id: String, cell: Vector2i) -> Dictionary:
	var stats := SceneManager.character_stats_for(id)
	var max_hp: int = stats.max_hp if stats != null else 10
	return {"id": id, "cell": cell,
			"hp": int(SceneManager.state.party_hp.get(id, max_hp)),
			"max_hp": max_hp,
			"atk": stats.attack if stats != null else 1,
			"df": stats.defense if stats != null else 0,
			"move_range": stats.move_range if stats != null else 3,
			"passives": [stats.passive_id] if stats != null \
					and stats.passive_id != "" else [],
			"side": "party", "statuses": {}}


## D-027 round start: refill (preserving telegraphed verbs) or rebuild the
## plan, then declare the current intent with exact outcomes. A declared
## "move" executes in the domain, so the room's enemy node follows it.
## Party budgets and actions reset with every round.
func begin_round() -> Dictionary:
	round_number += 1
	_turns = {}
	_round_start_cells = {}
	for id in party_unit_ids():
		var unit: Dictionary = state["units"][id]
		_turns[id] = {"moves": int(unit.get("move_range", 3)), "acted": false}
		_round_start_cells[id] = unit["cell"]
	if active_unit_id == "" or not _turns.has(active_unit_id):
		active_unit_id = room.party_leader_id
	if plan.is_empty() or IntentLogic.plan_needs_rebuild(state, enemy_id, plan):
		plan = IntentLogic.make_plan(state, enemy_id)
	else:
		plan = IntentLogic.refill_plan(state, enemy_id, plan)
	if plan.is_empty():
		current_intent = {}
		return {}
	current_intent = IntentLogic.declare(state, enemy_id,
			str(plan[0]["verb"]))
	_sync_enemy_node()
	_refresh_panel()
	return current_intent


## --- party turn (TK-003) ----------------------------------------------------

## Living party units, leader first, roster order after.
func party_unit_ids() -> Array:
	var ids: Array = []
	if state["units"].has(room.party_leader_id):
		ids.append(room.party_leader_id)
	for follower in room.party_followers:
		if state["units"].has(follower.member_id):
			ids.append(follower.member_id)
	return ids


func can_act(id: String) -> bool:
	return _turns.has(id) and not _turns[id]["acted"] \
			and state["units"].has(id) and int(state["units"][id]["hp"]) > 0


func moves_left(id: String) -> int:
	return int(_turns.get(id, {}).get("moves", 0))


func set_active_unit(id: String) -> bool:
	if not _turns.has(id) or not state["units"].has(id):
		return false
	active_unit_id = id
	_refresh_panel()
	return true


func cycle_active_unit() -> String:
	var ids := party_unit_ids()
	var index := ids.find(active_unit_id)
	if index >= 0 and ids.size() > 1:
		set_active_unit(ids[(index + 1) % ids.size()])
	return active_unit_id


func unit_at(cell: Vector2i) -> Dictionary:
	for id in state["units"]:
		var unit: Dictionary = state["units"][id]
		if unit["cell"] == cell and int(unit["hp"]) > 0:
			return unit
	return {}


## One legal cardinal step for the active party unit; spends move budget and
## keeps room occupancy/visuals in sync.
func move_active(dir: Vector2i) -> bool:
	if absi(dir.x) + absi(dir.y) != 1 or not _turns.has(active_unit_id):
		return false
	if moves_left(active_unit_id) <= 0:
		return false
	var unit: Dictionary = state["units"][active_unit_id]
	var dest: Vector2i = unit["cell"] + dir
	if dest.x < 0 or dest.y < 0 or dest.x >= int(state["width"]) \
			or dest.y >= int(state["height"]):
		return false
	if state["blocked"].has(dest) or not unit_at(dest).is_empty():
		return false
	unit["cell"] = dest
	_turns[active_unit_id]["moves"] = moves_left(active_unit_id) - 1
	_sync_party_node(active_unit_id)
	_refresh_panel()
	return true


## Exact full-detail attack preview for the active unit (D-026).
func attack_preview(target_id: String) -> Dictionary:
	if not state["units"].has(target_id) \
			or not state["units"].has(active_unit_id):
		return {"valid": false, "error": "unknown_unit"}
	if not _adjacent_units(active_unit_id, target_id):
		return {"valid": false, "error": "out_of_range"}
	var shown := IntentLogic.player_attack_preview(state, active_unit_id,
			target_id, {"power": 0})
	shown["valid"] = true
	return shown


## Basic attack: applies exactly the preview; a kill wins the encounter in
## place through the seam's existing victory path.
func attack(target_id: String) -> Dictionary:
	if not can_act(active_unit_id):
		return {"valid": false, "error": "already_acted"}
	var shown := attack_preview(target_id)
	if not shown.get("valid", false):
		return shown
	var result := IntentLogic.player_attack_resolve(state, active_unit_id,
			target_id, {"power": 0})
	result["valid"] = true
	_turns[active_unit_id]["acted"] = true
	if int(state["units"][target_id]["hp"]) <= 0 and target_id == enemy_id:
		_refresh_panel()
		room.resolve_room_encounter(true)
		return result
	_refresh_panel()
	return result


## Shove: push the adjacent target one cell straight away; pushing the
## intent's owner cancels its declared intention (D-026 counterplay).
func shove(target_id: String) -> bool:
	if not can_act(active_unit_id) or not state["units"].has(target_id):
		return false
	if not _adjacent_units(active_unit_id, target_id):
		return false
	var dir: Vector2i = state["units"][target_id]["cell"] \
			- state["units"][active_unit_id]["cell"]
	if not IntentLogic.push_unit(state, target_id, dir, current_intent):
		return false
	_turns[active_unit_id]["acted"] = true
	if target_id == enemy_id:
		_sync_enemy_node()
	else:
		_sync_party_node(target_id)
	_refresh_panel()
	return true


## Bash: stun the adjacent enemy for one round, canceling its intention.
func bash(target_id: String) -> bool:
	if not can_act(active_unit_id) or target_id != enemy_id:
		return false
	if not _adjacent_units(active_unit_id, target_id):
		return false
	IntentLogic.stun_enemy(state, current_intent)
	_turns[active_unit_id]["acted"] = true
	_refresh_panel()
	return true


## Guard: raise the front/front-left/front-right protected cells for exactly
## one round (D-037 body-blocking as deliberate counterplay).
func guard(facing: Vector2i) -> bool:
	if not can_act(active_unit_id) \
			or absi(facing.x) + absi(facing.y) != 1:
		return false
	IntentLogic.apply_guard(state, active_unit_id, facing, 1)
	_turns[active_unit_id]["acted"] = true
	_refresh_panel()
	return true


## TK-004: undo an un-acted unit's movement back to its round-start cell,
## refunding the budget. Acting locks the position (D-026: commitments are
## exact; free repositioning ends at the action).
func undo_move(id := active_unit_id) -> bool:
	if not _turns.has(id) or _turns[id]["acted"]:
		return false
	var unit: Dictionary = state["units"][id]
	var start: Vector2i = _round_start_cells.get(id, unit["cell"])
	if start == unit["cell"]:
		return false
	if state["blocked"].has(start) or not unit_at(start).is_empty():
		return false
	unit["cell"] = start
	_turns[id]["moves"] = int(unit.get("move_range", 3))
	_sync_party_node(id)
	_refresh_panel()
	return true


## S-014/TK-003 (D-043 rule 2): a KO'd ally self-revives at exactly 1 HP
## when the encounter ends EITHER way - unless the whole party is down, in
## which case the defeat rules own recovery. Never an unrecoverable state.
func revive_downed_members() -> void:
	var anyone_alive := false
	for id in party_unit_ids():
		if int(state["units"][id]["hp"]) > 0:
			anyone_alive = true
	if not anyone_alive:
		return
	for id in party_unit_ids():
		if int(state["units"][id]["hp"]) <= 0:
			state["units"][id]["hp"] = 1


## TK-004: persist combat HP into the session so damage taken in an
## encounter is real afterwards (clamped at zero; defeat rules own revival).
func write_back_party_hp() -> void:
	for id in party_unit_ids():
		SceneManager.state.party_hp[id] = maxi(0,
				int(state["units"][id]["hp"]))


## S-013/TK-004: cast the active unit's first reaction ability at the cell
## toward the enemy through the same seam exploration uses (D-031 context
## parity). Consumes the unit's action and MP; fail-closed refusals.
func cast_reaction() -> Dictionary:
	if not can_act(active_unit_id):
		return {"valid": false, "error": "already_acted"}
	var stats := SceneManager.character_stats_for(active_unit_id)
	var ability: AbilityData = null
	if stats != null:
		for candidate in stats.starting_abilities:
			if candidate != null and candidate.reaction_verb != "":
				ability = candidate
				break
	if ability == null:
		return {"valid": false, "error": "not_a_reaction_ability"}
	var max_mp: int = stats.max_mp
	var mp: int = int(SceneManager.state.party_mp.get(active_unit_id, max_mp))
	if mp < ability.mp_cost:
		return {"valid": false, "error": "not_enough_mp"}
	var facing := _facing_toward_enemy()
	var target: Vector2i = state["units"][active_unit_id]["cell"] + facing
	var result := ReactionCaster.cast(room, ability, target, facing,
			"encounter")
	if result.get("valid", false):
		SceneManager.state.party_mp[active_unit_id] = mp - ability.mp_cost
		_turns[active_unit_id]["acted"] = true
		_refresh_panel()
	return result


## Ends the party phase (D-027 steps 4-5): the declared enemy intention
## resolves against whoever remains in its cells (canceled intentions
## resolve to nothing), the environment ticks exact statuses and effect
## durations, and either the fight ends (environmental kill, party wipe) or
## the consumed plan step pops and the next round declares.
func end_party_turn() -> Dictionary:
	var events: Array = []
	if not current_intent.is_empty() \
			and not current_intent.get("canceled", false):
		events = IntentLogic.resolve(state, current_intent)
	var party_damage := 0
	for event: Dictionary in events:
		if not event.get("blocked", false):
			party_damage += int(event.get("damage", 0))
	var env_events: Array = IntentLogic.environment_tick(state)
	var summary := {"party_damage": party_damage, "events": events,
			"environment": env_events, "round": round_number}
	if state["units"].has(enemy_id) \
			and int(state["units"][enemy_id]["hp"]) <= 0:
		summary["victory"] = true
		room.resolve_room_encounter(true)
		return summary
	var party_alive := false
	for id in party_unit_ids():
		if int(state["units"][id]["hp"]) > 0:
			party_alive = true
	if not party_alive:
		# Party wipe: the encounter releases and the v1 checkpoint-defeat
		# rules take over (respawn, XP penalty - D-014/D-015 via T-041).
		summary["defeat"] = true
		write_back_party_hp()
		room.resolve_room_encounter(false)
		if SceneManager.current_room != null:
			SceneManager.handle_defeat()
		return summary
	if not plan.is_empty():
		plan.pop_front()
	begin_round()
	summary["round"] = round_number
	return summary


func _adjacent_units(a_id: String, b_id: String) -> bool:
	return IntentLogic.manhattan(state["units"][a_id]["cell"],
			state["units"][b_id]["cell"]) == 1


func _sync_party_node(id: String) -> void:
	if room == null:
		return
	var cell: Vector2i = state["units"][id]["cell"]
	if id == room.party_leader_id:
		if room.player != null and room.player.cell != cell:
			room.teleport(room.player, cell)
		return
	for follower in room.party_followers:
		if follower.member_id == id and follower.cell != cell:
			room.teleport(follower, cell)


## The ONLY future information the UI may show: the verb sequence (D-026).
func forecast() -> Array:
	return IntentLogic.future_verbs(plan)


## The exact preview of the declared current intent (cells, damage, status).
func intent_preview() -> Array:
	if current_intent.is_empty():
		return []
	return IntentLogic.preview(state, current_intent)


func _sync_enemy_node() -> void:
	if room == null or _enemy_node == null or not is_instance_valid(_enemy_node):
		return
	var unit: Dictionary = state["units"].get(enemy_id, {})
	if unit.is_empty():
		return
	if _enemy_node.cell != unit["cell"]:
		room.teleport(_enemy_node, unit["cell"])


func _ready() -> void:
	_build_panel()
	_refresh_panel()   # setup() declared round one before we entered the tree
	var timer := get_tree().create_timer(ENTER_REVEAL_DELAY)
	timer.timeout.connect(func():
		if _panel != null and is_instance_valid(_panel):
			_panel.visible = true
		_refresh_panel())


func _build_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.layer = 45
	_panel.visible = false   # revealed after the ENTER beat (D-036)
	_intent_label = Label.new()
	_intent_label.add_theme_font_size_override("font_size", 18)
	_intent_label.add_theme_color_override("font_color", Color(1, 0.85, 0.75))
	_intent_label.add_theme_color_override("font_outline_color",
			Color(0, 0, 0, 0.9))
	_intent_label.add_theme_constant_override("outline_size", 6)
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_intent_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_intent_label.offset_left = -520
	_intent_label.offset_top = 96
	_intent_label.offset_right = -16
	_panel.add_child(_intent_label)
	add_child(_panel)
	_highlights = Node2D.new()
	_highlights.z_index = 25
	room.add_child(_highlights)
	_highlights.draw.connect(_draw_highlights)


func _refresh_panel() -> void:
	if _intent_label == null or not is_instance_valid(_intent_label):
		return
	var enemy_label := enemy_id
	if _enemy_node != null and is_instance_valid(_enemy_node) \
			and _enemy_node.stats != null:
		enemy_label = _enemy_node.stats.display_name
	var lines: Array[String] = []
	if not current_intent.is_empty():
		var verb := str(current_intent.get("verb", "?")).to_upper()
		var line := "%s INTENT: %s" % [enemy_label.to_upper(), verb]
		if current_intent.has("damage"):
			line += "  %d dmg" % int(current_intent["damage"])
		if current_intent.get("status", {}) is Dictionary \
				and not current_intent.get("status", {}).is_empty():
			line += "  +%s" % str(current_intent["status"].keys()[0])
		lines.append(line)
	var verbs := forecast()
	if not verbs.is_empty():
		lines.append("NEXT: %s" % ", ".join(PackedStringArray(verbs)))
	for id in party_unit_ids():
		var unit: Dictionary = state["units"][id]
		var marker := ">" if id == active_unit_id else " "
		lines.append("%s %s %d/%d  mv %d%s" % [marker, str(id).to_upper(),
				int(unit["hp"]), int(unit["max_hp"]), moves_left(id),
				"  (acted)" if not can_act(id) else ""])
	lines.append("WASD move - 1 atk 2 bash 3 shove 4 guard 5 cast - Z undo - TAB unit - Q end")
	_intent_label.text = "\n".join(lines)
	if _highlights != null and is_instance_valid(_highlights):
		_highlights.queue_redraw()


func _draw_highlights() -> void:
	if _panel == null or not _panel.visible or current_intent.is_empty() \
			or room == null:
		return
	for cell in current_intent.get("cells", []):
		var pos: Vector2 = room.cell_to_pos(cell)
		_highlights.draw_rect(Rect2(pos - Vector2(28, 28), Vector2(56, 56)),
				Color(1.0, 0.35, 0.2, 0.28))
		_highlights.draw_rect(Rect2(pos - Vector2(28, 28), Vector2(56, 56)),
				Color(1.0, 0.5, 0.2, 0.9), false, 3.0)


## Encounter-mode controls (D-019 anchors reused): movement actions step the
## active unit, 1-4 are the counterplay verbs aimed at the enemy, Tab cycles
## the acting unit, cancel (Q) ends the party phase.
func _unhandled_input(event: InputEvent) -> void:
	if room == null or room.room_encounter != self \
			or not SceneManager.in_encounter:
		return
	if event.is_action_pressed("move_up"):
		move_active(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		move_active(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		move_active(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		move_active(Vector2i.RIGHT)
	elif event.is_action_pressed("cancel"):
		end_party_turn()
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_1:
				attack(enemy_id)
			KEY_2:
				bash(enemy_id)
			KEY_3:
				shove(enemy_id)
			KEY_4:
				guard(_facing_toward_enemy())
			KEY_5:
				cast_reaction()
			KEY_TAB:
				cycle_active_unit()
			KEY_Z:
				undo_move()
			_:
				return
	else:
		return
	get_viewport().set_input_as_handled()


func _facing_toward_enemy() -> Vector2i:
	if not state["units"].has(enemy_id) \
			or not state["units"].has(active_unit_id):
		return Vector2i.RIGHT
	var delta: Vector2i = state["units"][enemy_id]["cell"] \
			- state["units"][active_unit_id]["cell"]
	if absi(delta.x) >= absi(delta.y):
		return Vector2i(signi(delta.x) if delta.x != 0 else 1, 0)
	return Vector2i(0, signi(delta.y))


func _exit_tree() -> void:
	if _highlights != null and is_instance_valid(_highlights):
		_highlights.queue_free()
