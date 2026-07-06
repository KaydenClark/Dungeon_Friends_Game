class_name GridActor
extends Node2D
## Base class for anything that moves on the grid. Movement is Tween-based
## grid snapping only - never velocity-based free movement (locked decision,
## see /BLUEPRINT.md -> Core Logic And Invariants). Entities always rest
## exactly on a cell; occupancy is reserved at step start so two actors can
## never claim the same cell.

signal move_finished

@export var move_time := 0.15

var room: RoomGrid
var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var moving := false
var body: ColorRect
var face_marker: ColorRect


func attach(p_room: RoomGrid, p_cell: Vector2i) -> void:
	room = p_room
	cell = p_cell
	position = room.cell_to_pos(cell)


## Synchronous part returns immediately (true = step started); the tween part
## runs as a fire-and-forget coroutine guarded by `moving`.
func try_step(dir: Vector2i) -> bool:
	if moving or room == null:
		return false
	set_facing(dir)
	var target := cell + dir
	var occ: Node2D = room.get_occupant(target)
	if occ != null:
		_on_bump(occ)
		return false
	if not room.is_walkable(target):
		return false
	_start_move(target)
	return true


func _start_move(target: Vector2i) -> void:
	moving = true
	room.move_occupant(self, cell, target)
	cell = target
	var tw := create_tween()
	tw.tween_property(self, "position", room.cell_to_pos(target), move_time)
	await tw.finished
	moving = false
	move_finished.emit()


func set_facing(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	facing = dir
	if face_marker:
		face_marker.position = Vector2(-6, -6) + Vector2(dir) * 18.0


## Called when a step is blocked by another occupant. Subclasses override
## (e.g. the player starts an encounter when bumping an enemy).
func _on_bump(_occ: Node2D) -> void:
	pass


## Placeholder visual until real sprites land (M1.1): a colored square with a
## small dark marker showing facing.
func _make_body(color: Color, side: int = 48) -> void:
	body = ColorRect.new()
	body.color = color
	body.position = Vector2(-side / 2.0, -side / 2.0)
	body.size = Vector2(side, side)
	add_child(body)
	face_marker = ColorRect.new()
	face_marker.color = Color(0, 0, 0, 0.55)
	face_marker.size = Vector2(12, 12)
	add_child(face_marker)
	set_facing(facing)
