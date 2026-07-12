extends Node2D
## T-086 isolated visual spike. It renders a foreshortened orthogonal board
## with prototype-local height metadata; production rooms and pathfinding are
## intentionally not involved.
##
## Interactive:
##   Godot --path . scenes/dev/three_quarter_height_spike.tscn --resolution 1280x720
## Capture:
##   Godot --path . scenes/dev/three_quarter_height_spike.tscn \
##     --resolution 1280x720 -- --out=/tmp/three_quarter_height_spike.png

const HeightLayout = preload("res://scripts/dev/three_quarter_height_layout.gd")

const VIEWPORT_SIZE := Vector2i(1280, 720)
const LOWER_A := Color("29374f")
const LOWER_B := Color("31425d")
const LOWER_GRID := Color("62728c")
const UPPER_A := Color("326a64")
const UPPER_B := Color("39776e")
const UPPER_GRID := Color("82d8bd")
const CLIFF_FACE := Color("244b49")
const CLIFF_SHADOW := Color("173537")
const WALKABLE_MARK := Color(0.54, 0.78, 0.91, 0.34)
const BLOCKED_MARK := Color("e17373")
const WALL_FACE := Color("725660")
const WALL_LIGHT := Color("a77876")
const WALL_DARK := Color("493f50")
const WALL_RISE := 34.0
const STAIR_FACE := Color("b9854e")
const STAIR_LIGHT := Color("f0c978")

var _layout = HeightLayout.new()
var _font: Font = ThemeDB.fallback_font
var _textures: Dictionary = {}
var _out_path := ""


func _ready() -> void:
	for spec in _layout.actor_specs():
		var path := str(spec.get("texture", ""))
		if not path.is_empty() and not _textures.has(path):
			_textures[path] = load(path)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
	queue_redraw()
	print("THREE-QUARTER HEIGHT SPIKE: ready (orthogonal 13x8, elevations [0, 1], actors 4)")
	if not _out_path.is_empty():
		_capture_when_ready.call_deferred()


func _capture_when_ready() -> void:
	# Metal can expose a partially populated viewport if read back immediately
	# after the first CanvasItem redraw. Let the real window settle, then cross
	# two completed render frames before reading pixels.
	for _frame in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_width() != VIEWPORT_SIZE.x or image.get_height() != VIEWPORT_SIZE.y:
		push_error("THREE-QUARTER HEIGHT SPIKE: expected 1280x720, got %dx%d"
				% [image.get_width(), image.get_height()])
		get_tree().quit(1)
		return
	var error := image.save_png(_out_path)
	if error != OK:
		push_error("THREE-QUARTER HEIGHT SPIKE: could not write %s (error %d)"
				% [_out_path, error])
		get_tree().quit(1)
		return
	print("THREE-QUARTER HEIGHT SPIKE: wrote ", _out_path, " (1280x720)")
	get_tree().quit(0)


func _draw() -> void:
	_draw_backdrop()
	_draw_header()
	_draw_board()
	_draw_depth_items()
	_draw_callouts()
	_draw_legend()


func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)), Color("09101f"))
	draw_rect(Rect2(0, 0, 1280, 112), Color("101a2d"))
	for i in range(8):
		var alpha := 0.035 + float(i) * 0.006
		draw_circle(Vector2(1110, 80), 90.0 + i * 34.0, Color(0.23, 0.55, 0.65, alpha))
	# The board shadow establishes a compact diorama without changing its grid.
	draw_rect(Rect2(_layout.BOARD_ORIGIN + Vector2(14, 22),
			Vector2(_layout.GRID_SIZE) * _layout.CELL_SIZE), Color(0, 0, 0, 0.28))


func _draw_header() -> void:
	_text(Vector2(34, 45), "T-086  /  THREE-QUARTER HEIGHT SPIKE", 26, Color("f2f6ff"))
	_text(Vector2(34, 76),
			"Orthogonal square-grid logic • presentation-only elevation • production rooms untouched",
			15, Color("9dabc2"))
	_badge(Rect2(824, 30, 130, 30), "ORTHOGONAL", Color("3a77a5"))
	_badge(Rect2(966, 30, 120, 30), "2 LEVELS", Color("397d70"))
	_badge(Rect2(1098, 30, 146, 30), "STATIC PARTY ×4", Color("73588f"))


func _draw_board() -> void:
	for cell in _layout.all_cells():
		var level := _layout.elevation_at(cell)
		var pos := _layout.project_cell(cell)
		var rect := Rect2(pos, _layout.CELL_SIZE)
		var checker := (cell.x + cell.y) % 2 == 0
		var fill := (UPPER_A if checker else UPPER_B) if level == 1 \
				else (LOWER_A if checker else LOWER_B)
		var grid := UPPER_GRID if level == 1 else LOWER_GRID
		draw_rect(rect, fill)
		draw_rect(rect, grid, false, 1.0)
		if _layout.is_walkable(cell):
			draw_rect(rect.grow(-5), WALKABLE_MARK, false, 1.0)
		else:
			draw_rect(rect.grow(-6), Color(BLOCKED_MARK, 0.22))
			draw_line(rect.position + Vector2(10, 10), rect.end - Vector2(10, 10),
					BLOCKED_MARK, 2.0)
			draw_line(Vector2(rect.end.x - 10, rect.position.y + 10),
					Vector2(rect.position.x + 10, rect.end.y - 10), BLOCKED_MARK, 2.0)
		if _is_platform_front(cell):
			_draw_cliff_face(rect)
	_draw_stairs()
	_draw_level_tags()


func _is_platform_front(cell: Vector2i) -> bool:
	return (
		cell.y == _layout.PLATFORM_MAX.y
		and cell.x > _layout.STAIR_CELL.x
		and cell.x <= _layout.PLATFORM_MAX.x
	)


func _draw_cliff_face(top_rect: Rect2) -> void:
	var face := Rect2(top_rect.position + Vector2(0, top_rect.size.y),
			Vector2(top_rect.size.x, _layout.ELEVATION_RISE))
	draw_rect(face, CLIFF_FACE)
	draw_rect(Rect2(face.position, Vector2(face.size.x, 8)), Color("3f7670"))
	draw_line(Vector2(face.position.x, face.end.y), face.end, CLIFF_SHADOW, 3.0)
	for y_offset in [17.0, 31.0]:
		draw_line(face.position + Vector2(8, y_offset),
				Vector2(face.end.x - 8, face.position.y + y_offset),
				Color(0.55, 0.77, 0.70, 0.16), 1.0)


func _draw_stairs() -> void:
	var transition := _layout.transition_at(_layout.STAIR_CELL)
	var upper_cell: Vector2i = transition.get("upper_cell", Vector2i(-1, -1))
	var lower_cell: Vector2i = transition.get("lower_cell", Vector2i(-1, -1))
	var from_elevation := int(transition.get("from_elevation", 0))
	var upper_edge := _layout.project_cell(upper_cell) + Vector2(0, _layout.CELL_SIZE.y)
	var lower_edge := _layout.project_cell(lower_cell, from_elevation)
	var points := PackedVector2Array([
		upper_edge,
		upper_edge + Vector2(_layout.CELL_SIZE.x, 0),
		lower_edge + Vector2(_layout.CELL_SIZE.x, 0),
		lower_edge,
	])
	draw_colored_polygon(points, STAIR_FACE)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]),
			STAIR_LIGHT, 2.0)
	for step in range(1, 5):
		var t := float(step) / 5.0
		var y := lerpf(upper_edge.y, lower_edge.y, t)
		draw_line(Vector2(upper_edge.x + 3, y),
				Vector2(upper_edge.x + _layout.CELL_SIZE.x - 3, y),
				Color(STAIR_LIGHT, 0.82), 2.0)
	_text(upper_edge + Vector2(8, 22), "0 → 1", 12, Color("fff0bd"))


func _draw_level_tags() -> void:
	var lower := _layout.project_cell(Vector2i(0, 7), 0) + Vector2(6, 32)
	_tag(lower, "LOWER  •  0", Color("37506e"), Color("b8d8f0"))
	var upper := _layout.project_cell(Vector2i(10, 0), 1) + Vector2(4, 28)
	_tag(upper, "UPPER  •  1", Color("28665d"), Color("c3ffe7"))


func _draw_depth_items() -> void:
	var items: Array[Dictionary] = []
	for spec in _layout.actor_specs():
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
	items.sort_custom(_sort_depth)
	for item in items:
		if item.get("kind", "") == "wall":
			_draw_tall_wall()
		else:
			_draw_actor(item.get("spec", {}))


func _sort_depth(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("depth", 0)) < int(b.get("depth", 0))


func _draw_actor(spec: Dictionary) -> void:
	var cell: Vector2i = spec.get("cell", Vector2i.ZERO)
	var tile := Rect2(_layout.project_cell(cell), _layout.CELL_SIZE)
	var foot := Vector2(tile.get_center().x, tile.end.y - 7)
	var accent: Color = spec.get("accent", Color.WHITE)
	# A soft cell marker keeps the exact occupied square readable beneath art.
	draw_circle(foot + Vector2(0, 3), 20.0, Color(0, 0, 0, 0.38))
	draw_arc(foot + Vector2(0, 2), 20.0, 0, TAU, 32, accent, 3.0, true)
	var texture: Texture2D = _textures.get(str(spec.get("texture", "")))
	if texture != null:
		draw_texture_rect(texture, Rect2(foot - Vector2(32, 60), Vector2(64, 64)), false)
	else:
		draw_circle(foot - Vector2(0, 28), 18.0, accent)
	var label_pos := foot - Vector2(30, 66)
	if spec.get("role", "") == "behind wall":
		# Leave the visible head/shoulders unobstructed so the wall demonstrates
		# partial occlusion rather than making the rear actor disappear.
		label_pos = foot - Vector2(30, 94)
	_tag(label_pos, str(spec.get("name", "Friend")), Color(accent, 0.88), Color("08101c"))


func _draw_tall_wall() -> void:
	for cell in _layout.wall_cells():
		var footprint := Rect2(_layout.project_cell(cell, 0), _layout.CELL_SIZE)
		var face := Rect2(footprint.position + Vector2(3, -WALL_RISE),
				Vector2(footprint.size.x - 6, footprint.size.y + WALL_RISE))
		var cap := PackedVector2Array([
			face.position,
			face.position + Vector2(8, -10),
			Vector2(face.end.x + 8, face.position.y - 10),
			Vector2(face.end.x, face.position.y),
		])
		draw_rect(face, WALL_FACE)
		draw_colored_polygon(cap, WALL_LIGHT)
		draw_line(Vector2(face.position.x, face.end.y), face.end, WALL_DARK, 4.0)
		for y_offset in [16.0, 37.0, 58.0]:
			if face.position.y + y_offset < face.end.y - 3:
				draw_line(face.position + Vector2(5, y_offset),
						Vector2(face.end.x - 5, face.position.y + y_offset),
						Color(WALL_LIGHT, 0.35), 1.0)
		draw_line(face.position + Vector2(face.size.x * 0.5, 2),
				Vector2(face.position.x + face.size.x * 0.5, face.end.y - 3),
				Color(WALL_DARK, 0.34), 1.0)
	# A single silhouette reads as one authored obstacle, not three crates.
	var first := Rect2(_layout.project_cell(_layout.wall_cells()[0], 0), _layout.CELL_SIZE)
	var last := Rect2(_layout.project_cell(_layout.wall_cells()[-1], 0), _layout.CELL_SIZE)
	draw_line(first.position + Vector2(3, -WALL_RISE),
			Vector2(last.end.x - 3, last.position.y - WALL_RISE), Color("f3a985"), 3.0)


func _draw_callouts() -> void:
	_callout(Rect2(24, 206, 176, 102), "TALL WALL",
			"Friend C reads behind.\nHero reads in front.", Color("df907c"))
	var wall_target := _layout.project_cell(_layout.OCCLUSION_WALL_CELL, 0) + Vector2(4, -16)
	draw_line(Vector2(200, 258), wall_target, Color("df907c"), 2.0)
	draw_circle(wall_target, 4.0, Color("df907c"))

	_callout(Rect2(1076, 174, 178, 102), "UPPER LEVEL",
			"Elevation +1 lifts the\nsame square-grid cells.", Color("77dec0"))
	var upper_target := _layout.project_cell(Vector2i(10, 1)) + Vector2(62, 12)
	draw_line(Vector2(1076, 225), upper_target, Color("77dec0"), 2.0)
	draw_circle(upper_target, 4.0, Color("77dec0"))

	_callout(Rect2(1076, 330, 178, 102), "AUTHORED STAIRS",
			"One clear 0 → 1\ntransition; no skew.", Color("efc46e"))
	var stair_target := _layout.project_cell(_layout.STAIR_CELL, 0) + Vector2(60, 34)
	draw_line(Vector2(1076, 382), stair_target, Color("efc46e"), 2.0)
	draw_circle(stair_target, 4.0, Color("efc46e"))


func _draw_legend() -> void:
	var cards := [
		{
			"rect": Rect2(34, 574, 376, 112),
			"title": "WALKABLE CELLS",
			"body": "Inset blue outlines mark floor cells.\nRed crossed footprints are occupied by the wall.",
			"color": Color("7eb9dc"),
		},
		{
			"rect": Rect2(452, 574, 376, 112),
			"title": "LIMITED INTEGER HEIGHT",
			"body": "Only 0 and 1 exist. Upper cells shift up 38 px;\nlogical east/west and north/south stay orthogonal.",
			"color": Color("78d4b8"),
		},
		{
			"rect": Rect2(870, 574, 376, 112),
			"title": "FOREGROUND / BACKGROUND",
			"body": "Friend C is partially occluded behind the wall.\nHero and Buddy render cleanly in front of it.",
			"color": Color("d79bd9"),
		},
	]
	for card in cards:
		var rect: Rect2 = card["rect"]
		draw_rect(rect, Color("111b2d"))
		draw_rect(rect, Color(card["color"], 0.72), false, 2.0)
		draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), card["color"])
		_text(rect.position + Vector2(18, 31), card["title"], 15, card["color"])
		_text(rect.position + Vector2(18, 59), card["body"].split("\n")[0], 13, Color("c3ccda"))
		_text(rect.position + Vector2(18, 80), card["body"].split("\n")[1], 13, Color("c3ccda"))


func _callout(rect: Rect2, title: String, body: String, color: Color) -> void:
	draw_rect(rect, Color("111b2d"))
	draw_rect(rect, Color(color, 0.72), false, 2.0)
	_text(rect.position + Vector2(14, 28), title, 15, color)
	var lines := body.split("\n")
	for i in range(lines.size()):
		_text(rect.position + Vector2(14, 56 + i * 19), lines[i], 13, Color("c3ccda"))


func _badge(rect: Rect2, label: String, color: Color) -> void:
	draw_rect(rect, Color(color, 0.24))
	draw_rect(rect, Color(color, 0.9), false, 1.0)
	_text(rect.position + Vector2(12, 21), label, 12, Color("eaf4ff"))


func _tag(pos: Vector2, label: String, fill: Color, text_color: Color) -> void:
	var width := maxf(62.0, _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0)
	var rect := Rect2(pos, Vector2(width, 22))
	draw_rect(rect, fill)
	draw_rect(rect, Color(fill.lightened(0.28), 0.9), false, 1.0)
	_text(pos + Vector2(7, 16), label, 12, text_color)


func _text(pos: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
