class_name VineGate
extends Node2D
## S-004/TK-002 (D-044): a lattice of dead vines barring a passage. Blocks
## like a wall while closed; the room opens it when its authored trellis
## cell gains the `vine` tag through the shared reaction seam (and, because
## material state persists per room, an opened gate stays open on rebuild).
## Fail-closed: an invalid authored trellis records a named authoring error
## and the gate simply never opens.

const CELL := 64.0

var room: RoomGrid
var cell := Vector2i.ZERO
## Exported: the post-import hook sets it at import time, so it must
## serialize into the packed level scene.
@export var trellis := Vector2i(-1, -1)
var open := false


## Named authoring validation (D-039 style): "" means valid.
static func authoring_error(trellis_cell: Vector2i, width: int,
		height: int) -> String:
	if trellis_cell.x < 0 or trellis_cell.y < 0 \
			or trellis_cell.x >= width or trellis_cell.y >= height:
		return "vine_gate_trellis_out_of_bounds"
	return ""


func set_open(value: bool) -> void:
	open = value
	queue_redraw()


## Facing the closed lattice and interacting reads the answer without
## coaching (S-014): something must grow.
func interact() -> void:
	if open:
		return
	SceneManager.show_dialogue(PackedStringArray([
		"A lattice of dead vines is woven shut across the gap.",
		"The dry tendrils twitch toward your hands... they want to live.",
	]))


func _draw() -> void:
	var half := CELL / 2.0
	if open:
		# An opened frame: two side stubs of living green.
		draw_rect(Rect2(-half, -half, 8, CELL), Color(0.30, 0.62, 0.32), true)
		draw_rect(Rect2(half - 8, -half, 8, CELL), Color(0.30, 0.62, 0.32), true)
		return
	draw_rect(Rect2(-half, -half, CELL, CELL), Color(0.24, 0.20, 0.14), true)
	var lattice := Color(0.45, 0.40, 0.24)
	for i in range(1, 4):
		var offset := -half + i * CELL / 4.0
		draw_line(Vector2(offset, -half), Vector2(offset, half), lattice, 4.0)
		draw_line(Vector2(-half, offset), Vector2(half, offset), lattice, 4.0)
