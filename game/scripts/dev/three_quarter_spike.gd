extends Node2D
## T-089 pivot spike: three-quarter perspective on the orthogonal grid.
## One dev room, two integer elevation levels (D-030), one stair ramp, one
## tall vertical wall face, and a four-member visible party - directly
## controlled leader plus three non-blocking breadcrumb followers (D-029).
## Throwaway spike code (TASKBOARD.md -> Pivot Sequence); it proves
## readability only. High-ground bonuses, line-of-sight, and combat are
## explicitly out of scope.
##
## Interactive: run the scene windowed and move with the normal move_* keys.
## Proof shots:
##   godot --path game scenes/dev/three_quarter_spike.tscn \
##       --resolution 1280x720 -- --out=<dir>
## writes four PNGs (needs a display; headless renders black).

const TILE := 64
## One elevation level of visual lift. 48px (3/4 of a tile) is deliberately
## strong so the spike answers "does height read?" unambiguously.
const ELEV_PX := 48.0
const GRID_W := 16
const GRID_H := 9
const PLATEAU_ROWS: Array[int] = [1, 2, 3]
const CLIFF_ROW := 4
const RAMP_CELL := Vector2i(8, 4)
const NORTH_WALL_H := 128.0
const CLIFF_H := TILE + ELEV_PX
const LEADER_START := Vector2i(8, 6)
const FOLLOWER_STARTS: Array[Vector2i] = [
	Vector2i(7, 6), Vector2i(6, 6), Vector2i(5, 6),
]
const CHEST_CELL := Vector2i(12, 2)
const TREE_CELLS: Array[Vector2i] = [Vector2i(3, 6), Vector2i(12, 6)]
const MOVE_TIME := 0.15

const DIR_ACTIONS := {
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
}

const TEX_FLOOR_LOW := "res://assets/art/tilesets/kenney/forest_ground.png"
const TEX_FLOOR_HIGH := "res://assets/art/tilesets/kenney/dungeon_floor.png"
const TEX_WALL := "res://assets/art/tilesets/kenney/dungeon_wall.png"
const TEX_TREE := "res://assets/art/tilesets/kenney/forest_tree.png"
const TEX_CHEST := "res://assets/art/objects/kenney/chest_closed.png"
const FOLLOWER_TEXTURES: Array[String] = [
	"res://assets/art/sprites/runtime/kenney/buddy.png",
	"res://assets/art/sprites/runtime/kenney/healer.png",
	"res://assets/art/sprites/runtime/kenney/quest_npc.png",
]

## Readability shading: vertical surfaces render darker than walkable floors
## (the standard 3/4 depth cue), with a lit lip where a face meets the floor
## above it and a contact shadow where it meets the ground below.
const FACE_TINT := Color(0.62, 0.56, 0.52)
const FLOOR_HIGH_TINT := Color(1.12, 1.1, 1.02)
const FACE_LIP := Color(1.0, 0.97, 0.85, 0.30)
const FACE_FOOT := Color(0.0, 0.0, 0.0, 0.30)


## D-030 on the existing runtime grid model: the logic grid stays orthogonal
## square cells; elevation is a small INTEGER per cell. Rendering and actor
## positions lift by elevation * ELEV_PX. The ramp cell is presentation-only
## half-lift - its logical elevation stays integer 0, it is simply the
## walkable gap in the cliff row that connects the levels.
class SpikeRoom extends RoomGrid:
	var elev_px := 48.0
	var elevation := {}   # Vector2i -> int (0 or 1 in this spike)
	var ramp_cells := {}  # Vector2i -> true

	func lift_px(c: Vector2i) -> float:
		if ramp_cells.has(c):
			return elev_px * 0.5
		return float(elevation.get(c, 0)) * elev_px

	## Every consumer of cell positions (GridActor tweens, register,
	## teleport) picks the lift up for free, so grid-snapped Tween movement
	## rises and falls the ramp with zero changes to GridActor.
	func cell_to_pos(c: Vector2i) -> Vector2:
		return super.cell_to_pos(c) + Vector2(0.0, -lift_px(c))


var room: SpikeRoom
var leader: GridActor
var followers: Array[Node2D] = []
var follower_tweens: Array[Tween] = []
## Leader's most recently vacated cells, newest first; follower i walks
## trail[i]. Followers never enter the occupancy map (D-029: non-blocking
## outside encounters).
var trail: Array[Vector2i] = []
var out_dir := ""
var floor_low: Texture2D
var floor_high: Texture2D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	floor_low = load(TEX_FLOOR_LOW)
	floor_high = load(TEX_FLOOR_HIGH)
	_build_room()
	_spawn_party()
	_add_camera()
	print("THREE-QUARTER SPIKE: ready (2 elevation levels, 1 ramp, party of 4)")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _scripted_tour()
		print("THREE-QUARTER SPIKE: done -> ", out_dir)
		get_tree().quit(0)
	else:
		_add_hint()


func _process(_delta: float) -> void:
	if out_dir != "" or leader == null or leader.moving:
		return
	for action: String in DIR_ACTIONS:
		if Input.is_action_pressed(action):
			_try_leader_step(DIR_ACTIONS[action])
			break


## --- room construction -----------------------------------------------------

func _build_room() -> void:
	room = SpikeRoom.new()
	room.name = "SpikeRoom"
	room.elev_px = ELEV_PX
	room.y_sort_enabled = true
	room.setup_grid(GRID_W, GRID_H)
	add_child(room)

	for row: int in PLATEAU_ROWS:
		for x in range(1, GRID_W - 1):
			room.elevation[Vector2i(x, row)] = 1
	room.ramp_cells[RAMP_CELL] = true

	var wall: Texture2D = load(TEX_WALL)
	var tree: Texture2D = load(TEX_TREE)
	# North wall: the required tall vertical face, two full tiles above the
	# plateau floor.
	for x in GRID_W:
		room.set_blocked(Vector2i(x, 0), true)
		_add_face(wall, Vector2(x * TILE, TILE - ELEV_PX), NORTH_WALL_H)
	# Cliff row: the plateau's south face, one tile plus one elevation level
	# tall, with the stair ramp as the single gap.
	for x in GRID_W:
		var c := Vector2i(x, CLIFF_ROW)
		if c == RAMP_CELL:
			continue
		room.set_blocked(c, true)
		_add_face(wall, Vector2(x * TILE, (CLIFF_ROW + 1) * TILE), CLIFF_H)
	# Plateau side walls (raised one level like the floor they border).
	for row: int in PLATEAU_ROWS:
		for x: int in [0, GRID_W - 1]:
			room.set_blocked(Vector2i(x, row), true)
			_add_face(wall, Vector2(x * TILE, (row + 1) * TILE - ELEV_PX), CLIFF_H)
	# Lower-floor boundary: forest trees (south row + side columns).
	for x in GRID_W:
		_add_tree(tree, Vector2i(x, GRID_H - 1))
	for row in range(CLIFF_ROW + 1, GRID_H - 1):
		for x: int in [0, GRID_W - 1]:
			_add_tree(tree, Vector2i(x, row))
	# Props for the depth read: a chest on the plateau, trees below.
	_add_prop(load(TEX_CHEST), CHEST_CELL)
	for c: Vector2i in TREE_CELLS:
		_add_tree(tree, c)


## A vertical wall face whose wrapper origin sits at its footprint base so
## room-level Y-sort occludes correctly: full 64px segments stacked upward,
## topped with a cropped remainder slice (kept crisp via AtlasTexture).
func _add_face(tex: Texture2D, base_pos: Vector2, height_px: float) -> void:
	var face := Node2D.new()
	face.position = base_pos
	var remaining := height_px
	var y := 0.0
	while remaining >= TILE:
		var seg := Sprite2D.new()
		seg.texture = tex
		seg.centered = false
		seg.scale = Vector2(4.0, 4.0)
		seg.position = Vector2(0.0, y - TILE)
		face.add_child(seg)
		y -= TILE
		remaining -= TILE
	if remaining > 0.0:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(0.0, 0.0, 16.0, remaining / 4.0)
		var cap := Sprite2D.new()
		cap.texture = atlas
		cap.centered = false
		cap.scale = Vector2(4.0, 4.0)
		cap.position = Vector2(0.0, y - remaining)
		face.add_child(cap)
	for seg: Node in face.get_children():
		seg.modulate = FACE_TINT
	var lip := ColorRect.new()
	lip.color = FACE_LIP
	lip.position = Vector2(0.0, -height_px)
	lip.size = Vector2(TILE, 5.0)
	face.add_child(lip)
	var foot := ColorRect.new()
	foot.color = FACE_FOOT
	foot.position = Vector2(0.0, -7.0)
	foot.size = Vector2(TILE, 7.0)
	face.add_child(foot)
	room.add_child(face)


func _add_tree(tex: Texture2D, c: Vector2i) -> void:
	room.set_blocked(c, true)
	_add_base_sprite(tex, c)


func _add_prop(tex: Texture2D, c: Vector2i) -> void:
	room.set_blocked(c, true)
	_add_base_sprite(tex, c)


func _add_base_sprite(tex: Texture2D, c: Vector2i) -> void:
	var wrapper := Node2D.new()
	wrapper.position = Vector2(c.x * TILE, (c.y + 1) * TILE - room.lift_px(c))
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.scale = Vector2(4.0, 4.0)
	sprite.position = Vector2(0.0, -TILE)
	wrapper.add_child(sprite)
	room.add_child(wrapper)


## Floors, stair bands, and faint grid lines draw under the Y-sorted room
## children (parent draws before children).
func _draw() -> void:
	if room == null or floor_low == null or floor_high == null:
		return
	# Plateau floor renders brighter than the vertical faces around it - the
	# lit horizontal / shaded vertical split is what makes height read.
	for row: int in PLATEAU_ROWS:
		for x in range(1, GRID_W - 1):
			var pos := Vector2(x * TILE, row * TILE - ELEV_PX)
			draw_texture_rect(floor_high, Rect2(pos, Vector2(TILE, TILE)), false,
					FLOOR_HIGH_TINT)
			draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color(0, 0, 0, 0.10), false, 1.0)
	for row in range(CLIFF_ROW + 1, GRID_H - 1):
		for x in range(1, GRID_W - 1):
			var pos := Vector2(x * TILE, row * TILE)
			draw_texture_rect(floor_low, Rect2(pos, Vector2(TILE, TILE)), false)
			draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color(0, 0, 0, 0.10), false, 1.0)
	# Cliff contact shadow cast onto the lower floor.
	draw_rect(Rect2(TILE, (CLIFF_ROW + 1) * TILE, (GRID_W - 2) * TILE, 10.0),
			Color(0, 0, 0, 0.22))
	# Stair ramp: four treads stepping down from plateau level to floor
	# level, strongly darkening toward the bottom, with dark cut-in side
	# rails so the stairwell reads as a channel through the cliff.
	var band_h := CLIFF_H / 4.0
	var top := (CLIFF_ROW + 1) * TILE - CLIFF_H
	var ramp_x := RAMP_CELL.x * TILE
	for j in 4:
		var rect := Rect2(ramp_x, top + j * band_h, TILE, band_h)
		var shade := 1.14 - 0.16 * j
		draw_texture_rect(floor_high, rect, false, Color(shade, shade, shade * 0.94))
		draw_line(rect.position + Vector2(0.0, band_h),
				rect.position + Vector2(TILE, band_h), Color(0, 0, 0, 0.45), 3.0)
	draw_rect(Rect2(ramp_x, top, 5.0, CLIFF_H), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(ramp_x + TILE - 5.0, top, 5.0, CLIFF_H), Color(0, 0, 0, 0.45))


## --- party ------------------------------------------------------------------

func _spawn_party() -> void:
	leader = GridActor.new()
	leader.name = "Leader"
	leader.move_time = MOVE_TIME
	if not leader._make_sprite(load("res://data/sprites/kenney_hero.tres")):
		leader._make_body(Color(0.3, 0.8, 1.0))
	_add_foot_shadow(leader)
	room.register(leader, LEADER_START)

	for i in FOLLOWER_STARTS.size():
		var f := Node2D.new()
		f.name = "Follower%d" % (i + 1)
		_add_foot_shadow(f)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = load(FOLLOWER_TEXTURES[i])
		sprite.scale = Vector2(4.0, 4.0)
		f.add_child(sprite)
		f.position = room.cell_to_pos(FOLLOWER_STARTS[i])
		room.add_child(f)
		followers.append(f)
		follower_tweens.append(null)
		trail.append(FOLLOWER_STARTS[i])


## Elliptical contact shadow under each party member - grounds the sprite on
## its cell so the eye keeps track of which level everyone stands on.
func _add_foot_shadow(actor: Node2D) -> void:
	var shadow := Polygon2D.new()
	shadow.name = "FootShadow"
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	var points := PackedVector2Array()
	for k in 16:
		var angle := TAU * k / 16.0
		points.append(Vector2(cos(angle) * 26.0, sin(angle) * 9.0))
	shadow.polygon = points
	shadow.position = Vector2(0.0, 28.0)
	shadow.z_index = 1
	actor.add_child(shadow)


func _try_leader_step(dir: Vector2i) -> bool:
	var vacated := leader.cell
	if not leader.try_step(dir):
		return false
	trail.push_front(vacated)
	while trail.size() > followers.size():
		trail.pop_back()
	for i in followers.size():
		_glide_follower(i, trail[i])
	return true


func _glide_follower(i: int, c: Vector2i) -> void:
	var f := followers[i]
	var target := room.cell_to_pos(c)
	var sprite: Sprite2D = f.get_node("Sprite")
	if absf(target.x - f.position.x) > 1.0:
		sprite.flip_h = target.x < f.position.x
	if follower_tweens[i] != null and follower_tweens[i].is_valid():
		follower_tweens[i].kill()
	var tw := f.create_tween()
	tw.tween_property(f, "position", target, MOVE_TIME)
	follower_tweens[i] = tw


## --- presentation helpers ---------------------------------------------------

func _add_camera() -> void:
	var cam := Camera2D.new()
	cam.position = Vector2(GRID_W * TILE / 2.0, 224.0)
	add_child(cam)
	cam.make_current()


func _add_hint() -> void:
	var ui := CanvasLayer.new()
	var label := Label.new()
	label.text = "T-089 three-quarter spike - move with WASD/arrows.\nLeader + 3 breadcrumb followers; stairs connect the two levels."
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	ui.add_child(label)
	add_child(ui)


## --- proof tour --------------------------------------------------------------

func _scripted_tour() -> void:
	await _frames(6)
	await _shot("01-lower-floor")
	await _walk([Vector2i.UP, Vector2i.UP])
	await _shot("02-ascending-ramp")
	await _walk([Vector2i.UP, Vector2i.UP])
	await _shot("03-spanning-elevations")
	await _walk([Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT])
	await _shot("04-plateau-at-chest")


func _walk(dirs: Array) -> void:
	for dir: Vector2i in dirs:
		if _try_leader_step(dir):
			await leader.move_finished
	await _frames(4)


func _shot(shot_name: String, settle_frames := 4) -> void:
	await _frames(settle_frames)
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	print("  wrote ", path)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
