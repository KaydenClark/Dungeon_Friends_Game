extends "res://scripts/dev/intent_prototype_spike.gd"
## T-093B pivot spike: the playable gray-box reaction room (D-031). The same
## T-089/T-090/T-097 room, party, encounter cue, and intent rounds - plus the
## shared material/effect vocabulary living ON the room's cells:
##
##   - Authored materials: a water channel run, a soil patch, a flammable
##     brush chain, and a smoldering smoke pocket, all rendered gray-box.
##   - Six castable verbs in BOTH contexts: 5 grow, 6 fire, 7 water, 8 cold,
##     9 spark, 0 air. Casting opens a WASD-aimed cursor (range 3); the FULL
##     neutral result - affected cells, damage, statuses, hazards, forced
##     movement, environmental changes, and which units would be hit - is
##     shown BEFORE E commits (Q cancels). Preview always equals commit.
##   - One code path: exploration and encounter casts both go through
##     ReactionRoomLogic.cast -> ReactionCore.calculate (Sol's T-093A entry
##     point). Context is metadata only and never branches a rule.
##   - Environmental counterplay: reaction damage maps onto whoever stands in
##     it; a hit on the intention's owner CANCELS its declared intention -
##     generic for any owner, never bespoke pairwise code (D-031).
##
## The T-097 machinery is inherited untouched: encounter entry cue, rolling
## verb forecast, exact current intent, four members acting in any order,
## Strike/Bash/Shove/Guard. Shove additionally previews its exact forced-
## movement destination before commit.
##
## Interactive extras on top of the parent's keys: 5/6/7/8/9/0 start a cast
## in exploration or during your encounter turn; WASD aims, E commits,
## Q cancels. Proof shots:
##   godot --path game scenes/dev/reaction_room_spike.tscn \
##       --resolution 1280x720 -- --out=<dir>

const RoomLogic := preload("res://scripts/dev/reaction_room_logic.gd")

const CAST_RANGE := 3
const VERB_KEYS := {
	KEY_5: "grow", KEY_6: "fire", KEY_7: "water",
	KEY_8: "cold", KEY_9: "spark", KEY_0: "air",
}

## Authored material seeds (all on walkable lower-floor cells).
const CHANNEL_CELLS: Array[Vector2i] = [
	Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5),
]
const SOIL_CELL := Vector2i(10, 5)
const FLAMMABLE_CELLS: Array[Vector2i] = [
	Vector2i(11, 5), Vector2i(12, 5), Vector2i(13, 5),
]
const SMOKE_CELLS: Array[Vector2i] = [
	Vector2i(2, 6), Vector2i(2, 7), Vector2i(3, 7),
]

const MAT_CHANNEL := Color(0.12, 0.18, 0.32, 0.55)
const MAT_SOIL := Color(0.42, 0.28, 0.12, 0.45)
const MAT_FLAMMABLE := Color(0.55, 0.50, 0.18, 0.40)
const MAT_VINE := Color(0.15, 0.65, 0.20, 0.55)
const MAT_WET := Color(0.20, 0.50, 0.95, 0.32)
const MAT_FLOODED := Color(0.10, 0.30, 0.85, 0.30)
const MAT_ICE := Color(0.75, 0.95, 1.00, 0.55)
const MAT_FIRE := Color(1.00, 0.45, 0.10, 0.55)
const MAT_SMOKE := Color(0.55, 0.55, 0.58, 0.60)
const MAT_ELECTRIFIED := Color(1.00, 0.95, 0.20, 0.90)
const CAST_CURSOR_COLOR := Color(1, 1, 1, 0.95)
const CAST_AFFECT_FILL := Color(0.80, 0.30, 1.00, 0.18)
const CAST_AFFECT_BORDER := Color(0.90, 0.40, 1.00, 0.85)

## The room's live reaction world-state ({width, height, cells}) - shared and
## continuous across exploration and encounters (D-025/D-028 spirit).
var rstate := {}
var casting_verb := ""
var cast_cursor := Vector2i.ZERO
var cast_preview := {}
var reaction_ui: CanvasLayer
var preview_panel: ColorRect
var preview_label: Label
var legend_label: Label


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
	_build_reaction_state()
	_build_reaction_ui()
	print("REACTION ROOM: ready (shared vocabulary, one engine, two contexts)")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _scripted_tour()
		for line in tour_log:
			print(line)
		var failed := tour_log.filter(func(l: String) -> bool: return l.begins_with("FAIL"))
		print("REACTION ROOM: %s -> %s" % \
				["FAIL" if failed.size() > 0 else "done", out_dir])
		get_tree().quit(1 if failed.size() > 0 else 0)
	else:
		_add_hint()


func _add_hint() -> void:
	super._add_hint()
	var ui := CanvasLayer.new()
	var label := _make_ui_label(Vector2(12, 190), 15)
	label.text = "T-093B reactions - cast anywhere (exploration AND combat turns):\n[5]Grow [6]Fire [7]Water [8]Cold [9]Spark [0]Air - WASD aims, E commits, Q cancels.\nTry: grow the soil then burn it; flood the channel then freeze it; wet the slime then spark it."
	label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	ui.add_child(label)
	add_child(ui)


## --- reaction world-state ------------------------------------------------------

## Every walkable cell is addressable; walls/pits fail closed inside the core.
func _build_reaction_state() -> void:
	var targetable: Array = []
	for y in GRID_H:
		for x in GRID_W:
			var cell := Vector2i(x, y)
			if not room.blocked.has(cell) and not room.pits.has(cell):
				targetable.append(cell)
	var seeds := {}
	for cell: Vector2i in CHANNEL_CELLS:
		seeds[cell] = ["channel"]
	seeds[SOIL_CELL] = ["soil"]
	for cell: Vector2i in FLAMMABLE_CELLS:
		seeds[cell] = ["flammable"]
	for cell: Vector2i in SMOKE_CELLS:
		seeds[cell] = ["smoke"]
	rstate = RoomLogic.build_state(GRID_W, GRID_H, targetable, seeds)


func _build_reaction_ui() -> void:
	reaction_ui = CanvasLayer.new()
	preview_panel = ColorRect.new()
	preview_panel.color = Color(0.02, 0.03, 0.05, 0.90)
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.visible = false
	reaction_ui.add_child(preview_panel)
	preview_label = _make_ui_label(Vector2(12, 12), 13)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.clip_text = true
	preview_panel.add_child(preview_label)
	legend_label = _make_ui_label(Vector2(700, 8), 13)
	legend_label.text = "Materials: channel=navy  soil=brown  brush=olive  smoke=gray\nvine=green  wet=blue  ice=pale  fire=orange  zap=yellow edge"
	reaction_ui.add_child(legend_label)
	add_child(reaction_ui)
	_layout_preview_panel()
	get_viewport().size_changed.connect(_layout_preview_panel)


func _layout_preview_panel() -> void:
	var rect := RoomLogic.preview_panel_rect(get_viewport_rect().size)
	preview_panel.position = rect.position
	preview_panel.size = rect.size
	preview_label.size = rect.size - Vector2(24, 24)


func _set_preview_visible(value: bool) -> void:
	preview_panel.visible = value
	preview_label.visible = value


## --- casting input ---------------------------------------------------------------

func _process(delta: float) -> void:
	if out_dir == "" and not busy and casting_verb != "":
		for action: String in DIR_ACTIONS:
			if Input.is_action_just_pressed(action):
				_move_cast_cursor(DIR_ACTIONS[action])
				break
		return
	super._process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if out_dir != "" or busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if casting_verb != "":
			match event.keycode:
				KEY_E, KEY_ENTER:
					_commit_cast()
				KEY_Q:
					_cancel_cast()
			return
		if VERB_KEYS.has(event.keycode):
			_start_cast(VERB_KEYS[event.keycode])
			return
	super._unhandled_input(event)


func _caster_actor() -> GridActor:
	if mode == Mode.ENCOUNTER:
		return node_of[active_id] as GridActor
	return leader


func _cast_context() -> String:
	return "encounter" if mode == Mode.ENCOUNTER else "exploration"


## A cast is your unit's action for the round in an encounter; exploration
## casting is always open.
func _can_start_cast() -> bool:
	if mode == Mode.ENCOUNTER:
		return phase == Phase.PLAYER and not acted.get(active_id, true) \
				and not turn_done.get(active_id, true)
	return leader != null


func _targetable(cell: Vector2i) -> bool:
	return rstate.get("cells", {}).has(cell)


func _start_cast(verb: String) -> void:
	if not _can_start_cast():
		return
	casting_verb = verb
	var caster := _caster_actor()
	var start: Vector2i = caster.cell + caster.facing
	if not _targetable(start):
		start = caster.cell
	cast_cursor = start
	_refresh_cast_preview()


func _move_cast_cursor(dir: Vector2i) -> void:
	var candidate := cast_cursor + dir
	if _targetable(candidate) \
			and _manhattan(_caster_actor().cell, candidate) <= CAST_RANGE:
		cast_cursor = candidate
		_refresh_cast_preview()


func _cancel_cast() -> void:
	casting_verb = ""
	cast_preview = {}
	_set_preview_visible(false)
	queue_redraw()


## THE shared invocation: both contexts preview through this single call into
## Sol's entry point; only the context string differs.
func _refresh_cast_preview() -> void:
	cast_preview = RoomLogic.cast(rstate, casting_verb, _caster_actor().cell,
			cast_cursor, _cast_context())
	_update_preview_label()
	queue_redraw()


## Units this cast would hit right now - preview and commit share this exact
## computation, so what the panel says is what apply does.
func _previewed_hits() -> Array:
	if mode != Mode.ENCOUNTER or cast_preview.is_empty():
		return []
	return RoomLogic.units_hit(istate["units"], cast_preview)


func _commit_cast() -> void:
	if casting_verb == "" or not cast_preview.get("valid", false):
		return
	busy = true
	var result: Dictionary = cast_preview
	rstate = result["state_after"]
	if mode == Mode.ENCOUNTER:
		_sync_cells()
		var hits: Array = RoomLogic.units_hit(istate["units"], result)
		var disrupted: bool = RoomLogic.intent_disrupted(current_intent, hits)
		RoomLogic.apply_hits(istate["units"], hits)
		for hit: Dictionary in hits:
			var victim := node_of[hit["id"]] as GridActor
			_popup(victim, "-%d %s" % [int(hit["amount"]), str(hit["kind"])])
			victim.modulate = Color(1.0, 0.5, 0.5)
		if disrupted:
			current_intent["canceled"] = true
			_set_telegraph()
			intent_label.text = "Intention canceled - the %s disrupted the slime!" \
					% casting_verb
		_refresh_all_hp()
		acted[active_id] = true
		casting_verb = ""
		cast_preview = {}
		_set_preview_visible(false)
		queue_redraw()
		if hits.size() > 0:
			await _frames(12)
			for hit: Dictionary in hits:
				var victim := node_of.get(hit["id"]) as GridActor
				if victim != null:
					victim.modulate = Color.WHITE
		if int(istate["units"]["slime"]["hp"]) <= 0:
			await _end_encounter()
			busy = false
			return
		_update_ui()
	else:
		casting_verb = ""
		cast_preview = {}
		_set_preview_visible(false)
		queue_redraw()
	busy = false


## --- the full pre-commit preview panel -------------------------------------------

func _update_preview_label() -> void:
	if casting_verb == "":
		_set_preview_visible(false)
		return
	_set_preview_visible(true)
	var lines: Array[String] = []
	lines.append("CAST %s at %s (%s) - WASD aim, E commit, Q cancel"
			% [casting_verb.to_upper(), str(cast_cursor), _cast_context()])
	if not cast_preview.get("valid", false):
		lines.append("Invalid target: %s" % str(cast_preview.get("error", "?")))
		preview_label.text = "\n".join(lines)
		return
	var order: Array = cast_preview["propagation_order"]
	lines.append("Affected cells (%d, in order): %s"
			% [order.size(), _cells_text(order)])
	lines.append("Damage: %s" % _damage_text(cast_preview["damage"]))
	lines.append("Hazards: %s" % _hazards_text(cast_preview["hazards"]))
	lines.append("Cell changes: %s"
			% _changes_text(cast_preview["resulting_cells"]))
	lines.append("Consumed/canceled: %s"
			% _canceled_text(cast_preview["canceled_effects"]))
	lines.append("Forced movement: none (reactions never push)")
	if cast_preview.get("cascade_limited", false):
		lines.append("CASCADE LIMIT reached - the reaction truncates here")
	if mode == Mode.ENCOUNTER:
		var hits := _previewed_hits()
		if hits.is_empty():
			lines.append("Would hit: no combatants")
		else:
			var parts: Array[String] = []
			for hit: Dictionary in hits:
				parts.append("%s -%d (%s)" % [_display_name(hit["id"]),
						int(hit["amount"]), str(hit["kind"])])
			lines.append("Would hit: %s" % ", ".join(parts))
			if RoomLogic.intent_disrupted(current_intent, hits):
				lines.append("WOULD CANCEL the slime's declared intention!")
	else:
		lines.append("Would hit: environment only (damage maps to units in encounters)")
	preview_label.text = "\n".join(lines)


func _cells_text(cells: Array) -> String:
	if cells.is_empty():
		return "none"
	var parts: Array[String] = []
	for i in mini(cells.size(), 6):
		parts.append(str(cells[i]))
	if cells.size() > 6:
		parts.append("+%d more" % (cells.size() - 6))
	return " > ".join(parts)


func _damage_text(damage: Array) -> String:
	if damage.is_empty():
		return "none"
	var parts: Array[String] = []
	for i in mini(damage.size(), 5):
		var d: Dictionary = damage[i]
		parts.append("%d %s at %s" % [int(d["amount"]), str(d["kind"]),
				str(d["cell"])])
	if damage.size() > 5:
		parts.append("+%d more" % (damage.size() - 5))
	return "; ".join(parts)


func _hazards_text(hazards: Array) -> String:
	if hazards.is_empty():
		return "none"
	var counts := {}
	for h: Dictionary in hazards:
		var kind := str(h["kind"])
		counts[kind] = int(counts.get(kind, 0)) + 1
	var parts: Array[String] = []
	for kind: String in counts:
		parts.append("%s x%d" % [kind, int(counts[kind])])
	return ", ".join(parts)


func _changes_text(resulting: Array) -> String:
	if resulting.is_empty():
		return "none"
	var parts: Array[String] = []
	for i in mini(resulting.size(), 4):
		var r: Dictionary = resulting[i]
		parts.append("%s -> [%s]" % [str(r["cell"]),
				", ".join(r["tags"])])
	if resulting.size() > 4:
		parts.append("+%d more" % (resulting.size() - 4))
	return "  ".join(parts)


func _canceled_text(canceled: Array) -> String:
	if canceled.is_empty():
		return "none"
	var parts: Array[String] = []
	for i in mini(canceled.size(), 4):
		var c: Dictionary = canceled[i]
		parts.append("%s %s at %s" % [str(c["effect"]), str(c["reason"]),
				str(c["cell"])])
	if canceled.size() > 4:
		parts.append("+%d more" % (canceled.size() - 4))
	return "; ".join(parts)


## Shove gains its forced-movement preview: the exact destination (or the
## refusal) is visible before E commits - same contract as everything else.
func _update_ui() -> void:
	super._update_ui()
	if mode == Mode.ENCOUNTER and pending_ability == "shove" \
			and enemy_actor != null:
		var actor := node_of[active_id] as GridActor
		var dir: Vector2i = IntentLogic._axis_dir_toward(actor.cell,
				enemy_actor.cell)
		var shown: Dictionary = RoomLogic.push_destination(istate, "slime", dir)
		if shown["legal"]:
			prompt_label.text += "  -> would push Slime to %s" % str(shown["dest"])
		else:
			prompt_label.text += "  -> Slime won't budge (%s is blocked)" \
					% str(shown["dest"])


## --- gray-box material presentation ----------------------------------------------

func _draw() -> void:
	super._draw()
	if room == null or rstate.is_empty():
		return
	for cell: Vector2i in rstate["cells"]:
		_draw_cell_materials(cell, rstate["cells"][cell])
	if casting_verb != "":
		for c: Vector2i in cast_preview.get("propagation_order", []):
			var rect := _cell_rect(c)
			draw_rect(rect, CAST_AFFECT_FILL)
			draw_rect(Rect2(rect.position + Vector2(6, 6),
					rect.size - Vector2(12, 12)), CAST_AFFECT_BORDER, false, 2.0)
		var cursor_rect := _cell_rect(cast_cursor)
		draw_rect(Rect2(cursor_rect.position + Vector2(2, 2),
				cursor_rect.size - Vector2(4, 4)), CAST_CURSOR_COLOR, false, 3.0)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell.x * TILE, cell.y * TILE - room.lift_px(cell)),
			Vector2(TILE, TILE))


func _draw_cell_materials(cell: Vector2i, data: Dictionary) -> void:
	var tags: Array = data["tags"]
	var statuses: Dictionary = data["statuses"]
	if tags.is_empty() and statuses.is_empty():
		return
	var rect := _cell_rect(cell)
	# Authored terrain marks (inset so the floor still reads).
	if tags.has("channel"):
		draw_rect(Rect2(rect.position + Vector2(10, 22),
				Vector2(TILE - 20, TILE - 44)), MAT_CHANNEL)
	if tags.has("soil"):
		draw_rect(Rect2(rect.position + Vector2(14, 14),
				Vector2(TILE - 28, TILE - 28)), MAT_SOIL)
	if tags.has("flammable"):
		draw_rect(Rect2(rect.position + Vector2(8, 34),
				Vector2(TILE - 16, 14)), MAT_FLAMMABLE)
		draw_rect(Rect2(rect.position + Vector2(20, 20),
				Vector2(TILE - 40, 12)), MAT_FLAMMABLE)
	# Dynamic materials layer over them.
	if tags.has("wet"):
		draw_rect(rect, MAT_WET)
	if tags.has("flooded"):
		draw_rect(rect, MAT_FLOODED)
	if tags.has("ice"):
		draw_rect(rect, MAT_ICE)
		draw_rect(Rect2(rect.position + Vector2(4, 4),
				rect.size - Vector2(8, 8)), Color(1, 1, 1, 0.8), false, 2.0)
	if tags.has("fire"):
		draw_rect(Rect2(rect.position + Vector2(6, 6),
				rect.size - Vector2(12, 12)), MAT_FIRE)
	if tags.has("smoke"):
		draw_rect(rect, MAT_SMOKE)
	if tags.has("vine"):
		draw_rect(Rect2(rect.position + Vector2(12, 12),
				rect.size - Vector2(24, 24)), MAT_VINE)
		var strength := int(statuses.get("vine_strength", 0))
		for i in strength:
			draw_rect(Rect2(rect.position + Vector2(14 + i * 12, TILE - 14),
					Vector2(8, 8)), Color(0.1, 0.9, 0.25, 0.95))
	if statuses.get("electrified", false):
		draw_rect(Rect2(rect.position + Vector2(3, 3),
				rect.size - Vector2(6, 6)), MAT_ELECTRIFIED, false, 3.0)


## The parent's cue capture is hardcoded as 02-encounter-cue; remap it into
## this tour's chronological numbering. Unlike the original spike capture,
## validate broad frame coverage: Metal can expose a half-populated viewport
## after frame_post_draw, which is not valid demo evidence.
func _shot(shot_name: String, settle_frames := 4) -> void:
	if shot_name == "02-encounter-cue":
		shot_name = "08-encounter-cue"
	var image: Image
	for attempt in 6:
		queue_redraw()
		await _frames(settle_frames if attempt == 0 else 45)
		RenderingServer.force_draw()
		RenderingServer.force_sync()
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		RenderingServer.force_draw()
		RenderingServer.force_sync()
		await RenderingServer.frame_post_draw
		image = get_viewport().get_texture().get_image()
		if _capture_image_is_complete(image):
			break
		print("REACTION ROOM: incomplete frame; redraw retry ", attempt + 1)
		# Dirty every inherited CanvasItem, not only this script's custom draw.
		# Metal's stale readback can otherwise preserve the same missing tiles
		# across retries even though the live window is complete.
		modulate = Color(1.0, 1.0, 1.0, 0.999)
		await get_tree().process_frame
		modulate = Color.WHITE
		visible = false
		await _frames(2)
		visible = true
		queue_redraw()
		if casting_verb != "":
			var verb := casting_verb
			casting_verb = ""
			cast_preview = {}
			_set_preview_visible(false)
			queue_redraw()
			await _frames(2)
			casting_verb = verb
			_refresh_cast_preview()
	if not _capture_image_is_complete(image):
		_assert(false, "capture %s populated the complete viewport" % shot_name)
		return
	var path := "%s/%s.png" % [out_dir, shot_name]
	var error := image.save_png(path)
	if error != OK:
		_assert(false, "capture %s wrote successfully" % shot_name)
		return
	print("  wrote ", path)


func _capture_image_is_complete(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	if image.get_width() < 640 or image.get_height() < 360:
		return false
	var samples: Array = []
	var logical_size := get_viewport_rect().size
	var image_scale := Vector2(float(image.get_width()) / logical_size.x,
			float(image.get_height()) / logical_size.y)
	var panel_rect := Rect2(preview_panel.position * image_scale,
			preview_panel.size * image_scale)
	for y in range(27):
		for x in range(48):
			var point := Vector2i(
					int((float(x) + 0.5) * image.get_width() / 48.0),
					int((float(y) + 0.5) * image.get_height() / 27.0))
			if preview_panel.visible and panel_rect.has_point(point):
				continue
			samples.append(image.get_pixelv(point).get_luminance())
	return RoomLogic.capture_samples_are_complete(samples, 0.02)


## --- proof tour ---------------------------------------------------------------------

func _strip_meta(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true)
	copy.erase("metadata")
	return copy


func _tags_at(cell: Vector2i) -> Array:
	return rstate["cells"][cell]["tags"]


## Drive one cast through the real interactive path (start -> aim -> commit)
## and return the previewed result for assertions.
func _tour_cast(verb: String, target: Vector2i) -> Dictionary:
	_assert(_manhattan(_caster_actor().cell, target) <= CAST_RANGE,
			"%s target %s is inside cast range" % [verb, str(target)])
	_start_cast(verb)
	_assert(casting_verb == verb, "cast mode opened for %s" % verb)
	cast_cursor = target
	_refresh_cast_preview()
	var preview := cast_preview
	await _commit_cast()
	return preview


func _activate(id: String) -> void:
	for _i in PARTY_ORDER.size():
		if active_id == id:
			return
		_switch_unit()
	_assert(active_id == id, "tab cycling reached %s" % id)


## Step a unit toward `target` through the real per-cell move path until it
## is within `reach`, or its budget/paths run out.
func _step_toward(id: String, target: Vector2i, reach: int) -> void:
	var unit := node_of[id] as GridActor
	for _i in 8:
		if _manhattan(unit.cell, target) <= reach \
				or int(move_left.get(id, 0)) <= 0:
			return
		var primary: Vector2i = RoomLogic.cast_direction(unit.cell, target)
		var secondary := Vector2i(0, signi(target.y - unit.cell.y)) \
				if primary.x != 0 else Vector2i(signi(target.x - unit.cell.x), 0)
		var before := unit.cell
		for dir: Vector2i in [primary, secondary]:
			if dir == Vector2i.ZERO:
				continue
			await _encounter_step(id, dir)
			if unit.cell != before:
				break
		if unit.cell == before:
			return


func _scripted_tour() -> void:
	await _frames(6)
	var scene_before := get_tree().current_scene
	var camera_before := get_viewport().get_camera_2d()
	await _shot("01-explore-materials")

	# --- exploration: grow a vine, then burn it -------------------------------
	_start_cast("grow")
	cast_cursor = SOIL_CELL
	_refresh_cast_preview()
	var grow_prev: Dictionary = cast_preview
	_assert(grow_prev.get("valid", false), "grow preview on the soil is valid")
	_assert(grow_prev["metadata"]["context"] == "exploration",
			"exploration casts carry the exploration context")
	_assert(preview_label.visible and preview_label.text.contains("Forced movement"),
			"the pre-commit panel names every consequence class")
	_assert(preview_panel.visible and preview_panel.color.a >= 0.85,
			"the consequence panel has a readable dark backing")
	_assert(get_viewport_rect().has_point(preview_panel.position)
			and get_viewport_rect().has_point(preview_panel.position
					+ preview_panel.size - Vector2.ONE),
			"the consequence panel stays inside the live viewport")
	await _shot("02-grow-preview")
	await _commit_cast()
	_assert(_tags_at(SOIL_CELL).has("vine"), "grow created a vine on the soil")
	await _tour_cast("grow", SOIL_CELL)
	_assert(int(rstate["cells"][SOIL_CELL]["statuses"]["vine_strength"]) == 2,
			"repeat grow strengthened the vine to exactly 2")

	var burn_prev: Dictionary = await _tour_cast("fire", SOIL_CELL)
	_assert(burn_prev["damage"] == [{"cell": SOIL_CELL, "amount": 2,
			"kind": "fire"}], "burn previewed exactly 2 fire damage")
	_assert(not _tags_at(SOIL_CELL).has("vine")
			and _tags_at(SOIL_CELL).has("fire") and _tags_at(SOIL_CELL).has("smoke"),
			"the vine burned into fire + smoke")
	await _shot("03-vine-burned")

	# --- exploration: air feeds the fire down the flammable brush chain -------
	var spread_prev: Dictionary = await _tour_cast("air", SOIL_CELL)
	_assert(spread_prev["propagation_order"] == [SOIL_CELL, FLAMMABLE_CELLS[0],
			FLAMMABLE_CELLS[1], FLAMMABLE_CELLS[2]],
			"air spread the fire rightward through the whole brush chain")
	for cell: Vector2i in FLAMMABLE_CELLS:
		_assert(_tags_at(cell).has("fire") and not _tags_at(cell).has("flammable"),
				"brush at %s ignited and was consumed" % str(cell))
	await _shot("04-air-fire-spread")

	# --- exploration: flood the channel, then freeze part of it ---------------
	await _walk([Vector2i.LEFT, Vector2i.LEFT, Vector2i.LEFT])   # toward the channel
	for cell: Vector2i in CHANNEL_CELLS:
		var wet_prev: Dictionary = await _tour_cast("water", cell)
		_assert(wet_prev.get("valid", false), "water on %s is valid" % str(cell))
		_assert(_tags_at(cell).has("wet") and _tags_at(cell).has("flooded"),
				"the channel cell %s is wet and flooded" % str(cell))
	var freeze_prev: Dictionary = await _tour_cast("cold", CHANNEL_CELLS[0])
	_assert(_tags_at(CHANNEL_CELLS[0]).has("ice")
			and not _tags_at(CHANNEL_CELLS[0]).has("wet"),
			"cold froze the flooded cell into ice")
	_assert(freeze_prev["canceled_effects"].size() == 2,
			"the freeze reported both consumed water effects")
	await _shot("05-flood-freeze")

	# --- exploration: spark conducts through the remaining connected wet run --
	# Context parity at the acceptance seam: the identical state through both
	# callers yields identical reaction data, and the committed exploration
	# result IS that shared-engine result.
	var caster_cell := _caster_actor().cell
	var snap: Dictionary = rstate.duplicate(true)
	var parity_expl: Dictionary = RoomLogic.cast(snap, "spark", caster_cell,
			CHANNEL_CELLS[1], "exploration")
	var parity_enc: Dictionary = RoomLogic.cast(snap, "spark", caster_cell,
			CHANNEL_CELLS[1], "encounter")
	_assert(_strip_meta(parity_expl) == _strip_meta(parity_enc),
			"identical state -> identical results from both contexts")
	_start_cast("spark")
	cast_cursor = CHANNEL_CELLS[1]
	_refresh_cast_preview()
	var spark_prev := cast_preview
	_assert(_strip_meta(spark_prev) == _strip_meta(parity_expl),
			"the live exploration cast is the exact shared-engine result")
	_assert(spark_prev["propagation_order"] == [CHANNEL_CELLS[1], CHANNEL_CELLS[2]],
			"spark conducts through connected wet cells and stops at the ice")
	await _shot("06-spark-conduction-preview")
	await _commit_cast()
	_assert(rstate["cells"][CHANNEL_CELLS[2]]["statuses"].get("electrified", false),
			"conducted cells are electrified after commit")

	# --- exploration: air clears the smoke pocket ------------------------------
	await _walk([Vector2i.LEFT])
	var clear_prev: Dictionary = await _tour_cast("air", SMOKE_CELLS[1])
	_assert(clear_prev["canceled_effects"].size() == SMOKE_CELLS.size(),
			"air cleared every connected smoke cell")
	for cell: Vector2i in SMOKE_CELLS:
		_assert(not _tags_at(cell).has("smoke"), "smoke gone at %s" % str(cell))
	await _shot("07-smoke-cleared")

	# --- encounter: same room, same cue, same intent rounds --------------------
	var steps: Array = [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT,
			Vector2i.RIGHT, Vector2i.UP, Vector2i.UP, Vector2i.UP, Vector2i.UP,
			Vector2i.LEFT]
	for dir: Vector2i in steps:
		if mode == Mode.ENCOUNTER:
			break
		await _player_act(dir)
	_assert(mode == Mode.ENCOUNTER, "detection started the in-room encounter")
	_assert(await _until_player_phase(),
			"the entry cue completed and opened the first player phase")
	_assert(cue_plays == 1, "the encounter cue ran exactly once")
	_assert(get_tree().current_scene == scene_before, "no scene change at entry")
	_assert(get_viewport().get_camera_2d() == camera_before,
			"no camera change at entry")
	_assert(not deployment_snapshot.is_empty()
			and deployment_snapshot.get("deployment_cells", {}).size()
			== PARTY_ORDER.size(),
			"Sol's formation planner deployed all four members")
	_assert(current_verb == "move", "round 1 declares the plan's move")
	var shown_r1: Array = IntentLogic.future_verbs(plan)
	_assert(shown_r1 == ["spit", "slam"],
			"the rolling verb forecast telegraphs spit then slam")
	_assert(not _future_ui_leaks(),
			"the future UI still shows verbs only - no targets or cells")

	# Round 1: all four act in arbitrary order - blockers step, hero and friend
	# CAST (water) through the same engine used in exploration.
	var slime_cell: Vector2i = istate["units"]["slime"]["cell"]
	var adj := slime_cell + Vector2i.DOWN
	if not _targetable(adj):
		adj = slime_cell + Vector2i.RIGHT
	var b1_start := (node_of["blocker1"] as GridActor).cell
	await _step_toward("blocker1", Vector2i(11, 3), 0)
	_assert((node_of["blocker1"] as GridActor).cell != b1_start
			and acted.get("hero", true) == false,
			"blocker1 moved before the hero acted (arbitrary order)")
	_activate("hero")
	await _step_toward("hero", slime_cell, CAST_RANGE)
	var wet_slime: Dictionary = await _tour_cast("water", slime_cell)
	_assert(wet_slime["metadata"]["context"] == "encounter",
			"encounter casts carry the encounter context")
	_assert(rstate["cells"][slime_cell]["tags"].has("wet"),
			"the slime's cell is wet")
	_activate("friend")
	await _step_toward("friend", adj, CAST_RANGE)
	await _tour_cast("water", adj)
	_assert(rstate["cells"][adj]["tags"].has("wet"),
			"the adjacent conduction cell is wet")
	_assert(acted.get("hero", false) and acted.get("friend", false),
			"hero and friend both spent their round-1 action on casts")
	for id: String in PARTY_ORDER:
		_end_unit(id)
	_assert(await _until_player_phase(), "round 2 reached the player phase")

	# Round 2: the telegraphed spit is now the exact current intent; a spark
	# through the wet cells cancels the slime's declared intention.
	_assert(current_verb == shown_r1[0],
			"the first telegraphed verb (spit) is now the current action")
	_assert(telegraph_cells.size() > 0, "the spit locks exact telegraph cells")
	slime_cell = istate["units"]["slime"]["cell"]
	var party_hp := {}
	for id: String in PARTY_ORDER:
		party_hp[id] = int(istate["units"][id]["hp"])
	var slime_hp := int(istate["units"]["slime"]["hp"])
	_activate("hero")
	await _step_toward("hero", adj, CAST_RANGE)
	_start_cast("spark")
	cast_cursor = adj
	_refresh_cast_preview()
	var zap_prev := cast_preview
	var zap_hits := _previewed_hits()
	_assert(zap_prev["propagation_order"].has(slime_cell),
			"the spark conducts from the aimed cell into the slime's wet cell")
	_assert(zap_hits == [{"id": "slime", "cell": slime_cell, "amount": 2,
			"kind": "spark"}],
			"the pre-commit preview names the slime as the exact unit hit")
	_assert(RoomLogic.intent_disrupted(current_intent, zap_hits),
			"the pre-commit preview promises the intention cancel")
	_assert(preview_label.text.contains("WOULD CANCEL"),
			"the cancel promise is visible in the panel before E is pressed")
	await _shot("09-spark-cancel-preview")
	await _commit_cast()
	_assert(int(istate["units"]["slime"]["hp"]) == slime_hp - 2,
			"the spark dealt exactly the previewed 2 damage")
	_assert(current_intent.get("canceled", false),
			"the environmental reaction CANCELED the declared intention")
	_assert(telegraph_cells.is_empty(), "the canceled telegraph disappeared")
	_assert(IntentLogic.preview(istate, current_intent) == [],
			"the canceled spit can no longer hit anyone")
	await _shot("10-intent-canceled")
	for id: String in PARTY_ORDER:
		_end_unit(id)
	_assert(await _until_player_phase(), "round 3 reached the player phase")
	for id: String in PARTY_ORDER:
		_assert(int(istate["units"][id]["hp"]) == int(party_hp[id]),
				"%s took no damage from the canceled spit" % id)
		_assert(not istate["units"][id]["statuses"].has("burn"),
				"%s was not burned by the canceled spit" % id)

	# Finish through the parent's committed-preview ability path.
	for _round in 8:
		if mode != Mode.ENCOUNTER:
			break
		for id: String in ["hero", "friend"]:
			if mode != Mode.ENCOUNTER:
				break
			_activate(id)
			if acted.get(id, true) or enemy_actor == null:
				continue
			await _step_toward(id, istate["units"]["slime"]["cell"], 1)
			if _adjacent((node_of[id] as GridActor).cell,
					istate["units"]["slime"]["cell"]):
				_select_ability("strike")
				await _commit_ability()
		if mode != Mode.ENCOUNTER:
			break
		for id: String in PARTY_ORDER:
			_end_unit(id)
		await _until_player_phase()
	_assert(mode == Mode.EXPLORE and enemy_actor == null,
			"encounter resolved in-room (enemy defeated)")
	_assert(get_tree().current_scene == scene_before,
			"no scene change across the whole encounter")
	_assert(get_viewport().get_camera_2d() == camera_before,
			"no camera change across the whole encounter")
	_assert(cue_plays == 1, "the cue never replayed mid-encounter")

	# The environment the verbs built persists across the resolved encounter.
	_assert(_tags_at(CHANNEL_CELLS[0]).has("ice"),
			"the frozen channel survived the encounter")
	_assert(_tags_at(FLAMMABLE_CELLS[2]).has("fire"),
			"the spread fire survived the encounter")
	_assert(rstate["cells"][slime_cell]["tags"].has("wet"),
			"the encounter's own casts persist into exploration")
	await _player_act(Vector2i.DOWN)
	await _frames(8)
	await _shot("11-victory-materials-persist")
