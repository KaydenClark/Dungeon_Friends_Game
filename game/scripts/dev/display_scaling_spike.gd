extends Node2D
## Display-scaling spike (TASKBOARD.md T-007, upgraded for T-020/M1.4). Not
## shipped gameplay - a throwaway diagnostic scene proving the flexible
## HD/ultrawide stretch settings (canvas_items + expand, see BLUEPRINT.md ->
## Architecture) render a consistent, undistorted pixel-sprite tile grid at
## 1280x720, 1920x1080, and 3440x1440.
##
## T-020 upgrade (2026-07-06): the grid now draws the REAL M1.1 test tiles
## (16x16 art at 4x = 64px cells, nearest-filtered) instead of ColorRects, plus
## the hero sprite - so the M1.4 windowed check judges actual pixel art. Falls
## back to ColorRects if the textures are missing.
##
## Run with `--resolution WxH` to check a specific target size, e.g.:
##   Godot --path . scenes/dev/display_scaling_spike.tscn --resolution 1920x1080
## (headless runs ignore --resolution - the windowed check is the real M1.4
## gate; see RUNBOOK.md -> Test And Build.)

const TILE_SIZE := 64
const ART_TILE := 16
const COLOR_A := Color(0.16, 0.55, 0.32, 1)
const COLOR_B := Color(0.10, 0.35, 0.20, 1)

var tiles_tex: Texture2D = load("res://assets/art/tilesets/test_tiles.png")
var hero_tex: Texture2D = load("res://assets/art/sprites/test_hero.png")


func _ready() -> void:
	_build_grid()
	_build_label()


func _build_grid() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var cols: int = int(ceil(vp_size.x / TILE_SIZE)) + 1
	var rows: int = int(ceil(vp_size.y / TILE_SIZE)) + 1
	for y in range(rows):
		for x in range(cols):
			if tiles_tex:
				# Real art: grass field, tree border, a path row and a cave-wall
				# row so every M1.1 tile is on screen for the readability check.
				var t := 0
				if y == 0 or x == 0:
					t = 1   # tree
				elif y == rows / 2:
					t = 2   # path
				elif y == rows - 2:
					t = 4   # cave wall
				elif y == rows - 3:
					t = 3   # cave floor
				_add_tile_sprite(Vector2(x, y) * TILE_SIZE, t)
			else:
				var tile := ColorRect.new()
				tile.size = Vector2(TILE_SIZE, TILE_SIZE)
				tile.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				tile.color = COLOR_A if (x + y) % 2 == 0 else COLOR_B
				add_child(tile)
	if hero_tex:
		var hero := Sprite2D.new()
		hero.texture = hero_tex
		hero.centered = false
		hero.scale = Vector2(4, 4)
		hero.position = Vector2(5, 3) * TILE_SIZE
		add_child(hero)
	# Printed so headless runs (no visible window) still produce verifiable
	# proof that the grid sized itself to the actual viewport/resolution.
	print("DisplayScalingSpike: viewport=%s tiles=%dx%d (tile_size=%dpx, real_art=%s)"
			% [vp_size, cols, rows, TILE_SIZE, tiles_tex != null])


func _add_tile_sprite(pos: Vector2, t: int) -> void:
	var s := Sprite2D.new()
	s.texture = tiles_tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(t * ART_TILE, 0, ART_TILE, ART_TILE)
	s.scale = Vector2(4, 4)
	s.position = pos
	add_child(s)


func _build_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = "res: %s | tile: 16px art @4x = %dpx | stretch: canvas_items/expand" % [
		get_viewport_rect().size, TILE_SIZE]
	layer.add_child(label)
