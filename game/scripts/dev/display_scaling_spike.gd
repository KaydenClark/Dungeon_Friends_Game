extends Node2D
## Display-scaling spike (TASKBOARD.md T-007). Not shipped gameplay - a
## throwaway diagnostic scene proving the flexible HD/ultrawide stretch
## settings (canvas_items + expand, see BLUEPRINT.md -> Architecture) render a
## consistent, undistorted pixel-sprite tile grid at 1280x720, 1920x1080, and
## 3440x1440. Uses placeholder ColorRect "tiles" since no real sprite art has
## been authored yet (Milestone M1.1 is still pending) - swap in real tile art
## without changing the scaling logic once it exists.
##
## Run with `--resolution WxH` to check a specific target size, e.g.:
##   Godot --headless --path . scenes/dev/display_scaling_spike.tscn --resolution 1920x1080 --quit-after 1
## See RUNBOOK.md -> Test And Build for the full command set.

const TILE_SIZE := 64
const COLOR_A := Color(0.16, 0.55, 0.32, 1)
const COLOR_B := Color(0.10, 0.35, 0.20, 1)

func _ready() -> void:
	_build_grid()
	_build_label()

func _build_grid() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var cols: int = int(ceil(vp_size.x / TILE_SIZE)) + 1
	var rows: int = int(ceil(vp_size.y / TILE_SIZE)) + 1
	for y in range(rows):
		for x in range(cols):
			var tile := ColorRect.new()
			tile.size = Vector2(TILE_SIZE, TILE_SIZE)
			tile.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			tile.color = COLOR_A if (x + y) % 2 == 0 else COLOR_B
			add_child(tile)
	# Printed so headless runs (no visible window) still produce verifiable
	# proof that the grid sized itself to the actual viewport/resolution.
	print("DisplayScalingSpike: viewport=%s tiles=%dx%d (tile_size=%dpx)" % [vp_size, cols, rows, TILE_SIZE])

func _build_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = "res: %s | tile: %dpx | stretch: canvas_items/expand" % [get_viewport_rect().size, TILE_SIZE]
	layer.add_child(label)
