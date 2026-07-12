extends "res://scripts/dev/three_quarter_height_spike.gd"
## T-087/T-096 bootable visible-party prototype. The selected leader moves on
## the tested orthogonal layout; three render-only followers replay breadcrumbs
## and recover toward the selected line, square, or spaced formation.
##
## Interactive:
##   Godot --path . scenes/dev/visible_party_exploration_spike.tscn --resolution 1280x720
## Capture (auto-drives the real controller into the choke first):
##   Godot --path . scenes/dev/visible_party_exploration_spike.tscn \
##     --resolution 1280x720 -- --out=/tmp/visible_party_exploration.png

const PartyModel = preload("res://scripts/dev/visible_party_exploration_model.gd")

const MOVE_TIME := 0.14
const LEADER_COLOR := Color("ffd36a")
const ROUTE_COLOR := Color("79c8ef")
const SAFE_COLOR := Color("75e0b5")
const PLATE_TEXTURE := "res://assets/art/objects/kenney/pressure_plate.png"
const BLOCK_TEXTURE := "res://assets/art/objects/kenney/pushable_block.png"
const ROUTE_CELLS := [
	Vector2i(1, 5),
	Vector2i(2, 5),
	Vector2i(3, 5),
	Vector2i(4, 5),
	Vector2i(5, 5),
	Vector2i(6, 5),
	Vector2i(6, 4),
	Vector2i(6, 3),
	Vector2i(7, 3),
	Vector2i(8, 3),
	Vector2i(9, 3),
	Vector2i(10, 3),
]
const MEMBER_VISUALS := {
	&"hero": {
		"name": "Hero",
		"short": "H",
		"texture": "res://assets/art/sprites/runtime/kenney/hero.png",
		"accent": "62d9ff",
	},
	&"buddy": {
		"name": "Buddy",
		"short": "B",
		"texture": "res://assets/art/sprites/runtime/kenney/buddy.png",
		"accent": "c69cff",
	},
	&"friend_c": {
		"name": "Friend C",
		"short": "C",
		"texture": "res://assets/art/sprites/runtime/kenney/quest_npc.png",
		"accent": "ffb85c",
	},
	&"friend_d": {
		"name": "Friend D",
		"short": "D",
		"texture": "res://assets/art/sprites/runtime/kenney/healer.png",
		"accent": "7ef0a4",
	},
}

var _party = PartyModel.new()
var _previous_cells: Dictionary = {}
var _moving := false
var _move_tween: Tween
var _blocked_flash := ""
var _capture_state: StringName = &"recovered"
var _capture_formation: StringName = &"line"
var _move_progress := 1.0:
	set(value):
		_move_progress = value
		queue_redraw()


func _ready() -> void:
	_layout = _party.layout
	_previous_cells = _party.member_cells()
	for member_id in _party.member_ids():
		var visual: Dictionary = MEMBER_VISUALS[member_id]
		_load_texture(str(visual.get("texture", "")))
	for path in [PLATE_TEXTURE, BLOCK_TEXTURE]:
		_load_texture(path)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--formation="):
			_capture_formation = StringName(arg.trim_prefix("--formation="))
		elif arg == "--state=choke":
			_capture_state = &"choke"
		elif arg == "--state=recovered":
			_capture_state = &"recovered"
	if not _party.select_formation(_capture_formation):
		push_error("VISIBLE PARTY PROTOTYPE: invalid formation '%s'" % _capture_formation)
		get_tree().quit(1)
		return
	queue_redraw()
	print("VISIBLE PARTY PROTOTYPE: ready (formation=%s)" % _party.selected_formation())
	print("  move=WASD/arrows/D-pad  formation=1/2/3  switch=F/Y  reset=R/Q")
	if not _out_path.is_empty():
		_auto_capture_state.call_deferred()


func _load_texture(path: String) -> void:
	if not path.is_empty() and not _textures.has(path):
		_textures[path] = load(path)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or (event is InputEventKey and event.echo):
		return
	var direction := Vector2i.ZERO
	if event.is_action_pressed("move_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("move_down"):
		direction = Vector2i.DOWN
	elif event.is_action_pressed("move_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("move_right"):
		direction = Vector2i.RIGHT
	if direction != Vector2i.ZERO:
		_attempt_step(direction)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("character_menu"):
		_cycle_leader()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		match event.physical_keycode:
			KEY_1:
				_select_formation(&"line")
				get_viewport().set_input_as_handled()
				return
			KEY_2:
				_select_formation(&"square")
				get_viewport().set_input_as_handled()
				return
			KEY_3:
				_select_formation(&"spaced")
				get_viewport().set_input_as_handled()
				return
	var is_reset_key: bool = event is InputEventKey and event.physical_keycode == KEY_R
	if is_reset_key or event.is_action_pressed("cancel"):
		_reset_party()
		get_viewport().set_input_as_handled()


func _attempt_step(direction: Vector2i) -> bool:
	if _moving:
		return false
	var before := _party.member_cells()
	if not _party.try_step_leader(direction):
		_blocked_flash = "BLOCKED — use the door and gold stairs"
		queue_redraw()
		return false
	_blocked_flash = ""
	_previous_cells = before
	_moving = true
	_move_progress = 0.0
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "_move_progress", 1.0, MOVE_TIME)
	_move_tween.finished.connect(_finish_move)
	return true


func _finish_move() -> void:
	_moving = false
	_move_tween = null
	_previous_cells = _party.member_cells()
	_move_progress = 1.0
	if _party.formation_state() == &"recovered":
		print("VISIBLE PARTY PROTOTYPE: RECOVERED (4/4 upstairs)")
	queue_redraw()


func _cycle_leader() -> void:
	if _moving:
		return
	_previous_cells = _party.member_cells()
	var selected := _party.cycle_leader()
	_move_progress = 1.0
	print("VISIBLE PARTY PROTOTYPE: leader -> ", selected)
	queue_redraw()


func _select_formation(formation_id: StringName) -> void:
	if _moving:
		return
	_previous_cells = _party.member_cells()
	if not _party.select_formation(formation_id):
		return
	_move_progress = 1.0
	print("VISIBLE PARTY PROTOTYPE: formation -> ", formation_id)
	queue_redraw()


func _reset_party() -> void:
	if _move_tween != null:
		_move_tween.kill()
		_move_tween = null
	_moving = false
	_party.reset()
	_previous_cells = _party.member_cells()
	_move_progress = 1.0
	_blocked_flash = ""
	print("VISIBLE PARTY PROTOTYPE: reset")
	queue_redraw()


func _auto_capture_state() -> void:
	for _frame in 8:
		await get_tree().process_frame
	var route := [
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.UP,
	]
	for direction in route:
		if not _attempt_step(direction):
			push_error("VISIBLE PARTY PROTOTYPE: auto-route blocked at %s" % direction)
			get_tree().quit(1)
			return
		while _moving:
			await get_tree().process_frame
	if _party.cell_for(_party.leader_id()) != Vector2i(6, 3):
		push_error("VISIBLE PARTY PROTOTYPE: auto-route missed the upper landing")
		get_tree().quit(1)
		return
	if _capture_state == &"recovered":
		for _step in range(4):
			if not _attempt_step(Vector2i.RIGHT):
				push_error("VISIBLE PARTY PROTOTYPE: recovered route blocked")
				get_tree().quit(1)
				return
			while _moving:
				await get_tree().process_frame
		if _party.formation_state() != &"recovered":
			push_error("VISIBLE PARTY PROTOTYPE: party did not reform at the goal")
			get_tree().quit(1)
			return
		print("VISIBLE PARTY PROTOTYPE: capture state = RECOVERED %s formation"
				% _party.selected_formation())
	else:
		print("VISIBLE PARTY PROTOTYPE: capture state = SINGLE FILE (%s selected)"
				% _party.selected_formation())
	await _capture_when_ready()


func _draw() -> void:
	_draw_backdrop()
	_draw_header()
	_draw_board()
	_draw_depth_items()
	_draw_callouts()
	_draw_legend()


func _draw_header() -> void:
	_text(Vector2(34, 45), "T-096  /  SELECTABLE PARTY FORMATIONS", 26, Color("f2f6ff"))
	_text(Vector2(34, 76),
			"Choose line, square, or spaced; chokes compress temporarily, then restore the choice",
			15, Color("9dabc2"))
	_badge(Rect2(802, 30, 136, 30), str(_party.selected_formation()).to_upper(), Color("397d70"))
	_badge(Rect2(950, 30, 142, 30), "1-CELL CHOKE", Color("3a77a5"))
	_badge(Rect2(1098, 30, 146, 30), "FOLLOWER EFFECTS 0", Color("73588f"))


func _cell_is_walkable(cell: Vector2i) -> bool:
	return _party.is_walkable(cell)


func _draw_board() -> void:
	super._draw_board()
	for cell in ROUTE_CELLS:
		var route_rect := Rect2(_layout.project_cell(cell), _layout.CELL_SIZE).grow(-8)
		draw_rect(route_rect, Color(ROUTE_COLOR, 0.44), false, 2.0)
	_draw_pressure_plate()
	_draw_goal_pad()
	for cell in _party.CORRIDOR_WALL_CELLS:
		_draw_low_corridor_wall(cell)
	_draw_side_block()


func _draw_level_tags() -> void:
	var lower: Vector2 = _layout.project_cell(Vector2i(10, 7), 0) + Vector2(3, 31)
	_tag(lower, "LOWER  •  0", Color("37506e"), Color("b8d8f0"))
	var upper: Vector2 = _layout.project_cell(Vector2i(10, 0), 1) + Vector2(4, 28)
	_tag(upper, "UPPER  •  1", Color("28665d"), Color("c3ffe7"))


func _draw_pressure_plate() -> void:
	var rect := Rect2(_layout.project_cell(_party.PLATE_CELL), _layout.CELL_SIZE)
	var active := _party.plate_active()
	var plate_color := Color("f5c95f") if active else Color("7b8798")
	draw_rect(rect.grow(-12), Color(plate_color, 0.38))
	draw_rect(rect.grow(-12), plate_color, false, 2.0)
	var texture: Texture2D = _textures.get(PLATE_TEXTURE)
	if texture != null:
		draw_texture_rect(texture, Rect2(rect.get_center() - Vector2(16, 16), Vector2(32, 32)), false)


func _draw_goal_pad() -> void:
	var rect := Rect2(_layout.project_cell(_party.GOAL_CELL), _layout.CELL_SIZE).grow(-7)
	draw_rect(rect, Color(SAFE_COLOR, 0.18))
	draw_rect(rect, SAFE_COLOR, false, 3.0)
	_text(rect.position + Vector2(8, 18), "REFORM", 11, Color("d6ffef"))


func _draw_low_corridor_wall(cell: Vector2i) -> void:
	var footprint := Rect2(_layout.project_cell(cell, 0), _layout.CELL_SIZE)
	var face := Rect2(footprint.position + Vector2(4, -22),
			Vector2(footprint.size.x - 8, footprint.size.y + 22))
	draw_rect(face, Color("495267"))
	draw_rect(Rect2(face.position, Vector2(face.size.x, 9)), Color("758299"))
	draw_line(Vector2(face.position.x, face.end.y), face.end, Color("283244"), 3.0)
	draw_line(face.position + Vector2(6, 25), Vector2(face.end.x - 6, face.position.y + 25),
			Color(0.75, 0.81, 0.91, 0.22), 1.0)


func _draw_side_block() -> void:
	var tile := Rect2(_layout.project_cell(_party.BLOCK_CELL), _layout.CELL_SIZE)
	var texture: Texture2D = _textures.get(BLOCK_TEXTURE)
	if texture != null:
		draw_texture_rect(texture, Rect2(tile.get_center() - Vector2(28, 42), Vector2(56, 56)), false)
	else:
		draw_rect(tile.grow(-10), Color("a27a55"))
	_text(tile.position + Vector2(5, 16), "BLOCK", 10, Color("ffe0b0"))


func _dynamic_actor_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for member_id in _party.member_ids():
		var current := _party.cell_for(member_id)
		var previous: Vector2i = _previous_cells.get(member_id, current)
		var from_pos: Vector2 = _layout.project_cell(previous)
		var to_pos: Vector2 = _layout.project_cell(current)
		var visual: Dictionary = MEMBER_VISUALS[member_id]
		specs.append({
			"id": member_id,
			"name": visual.get("name", str(member_id)),
			"short": visual.get("short", "?"),
			"texture": visual.get("texture", ""),
			"accent": Color(str(visual.get("accent", "ffffff"))),
			"cell": current,
			"screen_position": from_pos.lerp(to_pos, _move_progress),
			"is_leader": member_id == _party.leader_id(),
		})
	return specs


func _draw_depth_items() -> void:
	var items: Array[Dictionary] = []
	for spec in _dynamic_actor_specs():
		var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
		items.append({
			"depth": _layout.depth_key(cell, _layout.DEPTH_ACTOR),
			"kind": "actor",
			"spec": spec,
		})
	items.append({
		"depth": _layout.depth_key(_layout.OCCLUSION_WALL_CELL, _layout.DEPTH_WALL),
		"kind": "wall",
	})
	items.append({
		"depth": _layout.depth_key(_party.DOOR_CELL, _layout.DEPTH_WALL),
		"kind": "door",
	})
	items.sort_custom(_sort_depth)
	for item in items:
		match item.get("kind", ""):
			"wall":
				_draw_tall_wall()
			"door":
				_draw_open_door()
			_:
				_draw_party_actor(item.get("spec", {}))
	# Identity badges remain on top of the door/wall occluders so all four
	# visible party members stay readable even while their bodies overlap.
	for spec in _dynamic_actor_specs():
		_draw_party_actor_tag(spec)


func _draw_open_door() -> void:
	var tile := Rect2(_layout.project_cell(_party.DOOR_CELL), _layout.CELL_SIZE)
	var left_post := Rect2(tile.position + Vector2(1, -24), Vector2(8, tile.size.y + 24))
	var right_post := Rect2(Vector2(tile.end.x - 9, tile.position.y - 24), Vector2(8, tile.size.y + 24))
	draw_rect(left_post, Color("9a795f"))
	draw_rect(right_post, Color("9a795f"))
	draw_line(left_post.position, Vector2(right_post.end.x, right_post.position.y), Color("dfbd85"), 5.0)
	draw_line(tile.get_center() + Vector2(0, 18), tile.get_center() + Vector2(0, -8),
			Color(ROUTE_COLOR, 0.82), 3.0)
	var door_label := Vector2(tile.end.x + 8, tile.position.y + 18)
	draw_line(Vector2(right_post.end.x, tile.position.y + 6), door_label - Vector2(4, 4),
			Color("dfbd85"), 1.5)
	_text(door_label, "OPEN DOOR", 11, Color("ffe0a8"))


func _draw_party_actor(spec: Dictionary) -> void:
	var top_left: Vector2 = spec.get("screen_position", Vector2.ZERO)
	var tile := Rect2(top_left, _layout.CELL_SIZE)
	var foot := Vector2(tile.get_center().x, tile.end.y - 7)
	var accent: Color = spec.get("accent", Color.WHITE)
	var is_leader := bool(spec.get("is_leader", false))
	draw_circle(foot + Vector2(0, 3), 20.0, Color(0, 0, 0, 0.4))
	draw_arc(foot + Vector2(0, 2), 21.0, 0, TAU, 32,
			LEADER_COLOR if is_leader else accent, 4.0 if is_leader else 2.5, true)
	var texture: Texture2D = _textures.get(str(spec.get("texture", "")))
	if texture != null:
		draw_texture_rect(texture, Rect2(foot - Vector2(32, 60), Vector2(64, 64)), false)
	else:
		draw_circle(foot - Vector2(0, 28), 18.0, accent)


func _draw_party_actor_tag(spec: Dictionary) -> void:
	var top_left: Vector2 = spec.get("screen_position", Vector2.ZERO)
	var tile := Rect2(top_left, _layout.CELL_SIZE)
	var foot := Vector2(tile.get_center().x, tile.end.y - 7)
	var accent: Color = spec.get("accent", Color.WHITE)
	var is_leader := bool(spec.get("is_leader", false))
	_small_actor_tag(foot - Vector2(13, 76), str(spec.get("short", "?")),
			LEADER_COLOR if is_leader else accent, is_leader)


func _small_actor_tag(pos: Vector2, label: String, color: Color, is_leader: bool) -> void:
	var rect := Rect2(pos, Vector2(26, 22))
	draw_rect(rect, Color(color, 0.94))
	draw_rect(rect, Color.WHITE if is_leader else color.lightened(0.25), false, 1.0)
	_text(pos + Vector2(8, 16), label, 12, Color("08101c"))


func _draw_callouts() -> void:
	_callout(Rect2(24, 180, 176, 122), "TEST ROUTE",
			"RIGHT ×5\nUP ×2 through door\nRIGHT ×4 to reform", ROUTE_COLOR)
	var door_target: Vector2 = _layout.project_cell(_party.DOOR_CELL) + Vector2(5, -12)
	draw_line(Vector2(200, 245), door_target, ROUTE_COLOR, 2.0)
	draw_circle(door_target, 4.0, ROUTE_COLOR)

	var selected := str(_party.selected_formation()).to_upper()
	var movement_state := str(_party.formation_state()).to_upper().replace("_", " ")
	_callout(Rect2(1076, 166, 178, 112), "SELECTED / STATE",
			"%s\n%s" % [selected, movement_state], SAFE_COLOR)
	var plate_state := "ON — LEADER" if _party.plate_active() else "OFF"
	if _party.follower_on_plate() and not _party.plate_active():
		plate_state = "OFF — FOLLOWER INERT"
	_callout(Rect2(1076, 326, 178, 112), "PLATE PROOF",
			"%s\nFollower holds: 0" % plate_state, Color("efc46e"))


func _draw_legend() -> void:
	var selected_visual: Dictionary = MEMBER_VISUALS[_party.leader_id()]
	var selected_name := str(selected_visual.get("name", _party.leader_id()))
	_info_card(Rect2(34, 574, 376, 112), "CONTROLS",
			"WASD / arrows move  •  1 line / 2 square / 3 spaced\nF / pad Y: switch  •  R or Q / pad X: reset", ROUTE_COLOR)
	_info_card(Rect2(452, 574, 376, 112), "LIVE PARTY",
			"Leader: %s  •  selected: %s\nTransient state: %s  •  H / B / C / D = identity" % [
				selected_name, str(_party.selected_formation()),
				str(_party.formation_state()).replace("_", " ")], SAFE_COLOR)
	_info_card(Rect2(870, 574, 376, 112), "FOLLOWER SAFETY",
			"Render-only: no pushing or puzzle occupancy\nLeader-only interaction  •  followers never block", Color("d79bd9"))
	if not _blocked_flash.is_empty():
		_text(Vector2(452, 554), _blocked_flash, 14, Color("ff9f8c"))


func _info_card(rect: Rect2, title: String, body: String, color: Color) -> void:
	draw_rect(rect, Color("111b2d"))
	draw_rect(rect, Color(color, 0.72), false, 2.0)
	draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), color)
	_text(rect.position + Vector2(18, 31), title, 15, color)
	var lines := body.split("\n")
	for index in range(lines.size()):
		_text(rect.position + Vector2(18, 59 + index * 21), lines[index], 13, Color("c3ccda"))
