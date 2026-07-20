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
			"side": "party", "statuses": {}}


## D-027 round start: refill (preserving telegraphed verbs) or rebuild the
## plan, then declare the current intent with exact outcomes. A declared
## "move" executes in the domain, so the room's enemy node follows it.
func begin_round() -> Dictionary:
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


func _exit_tree() -> void:
	if _highlights != null and is_instance_valid(_highlights):
		_highlights.queue_free()
