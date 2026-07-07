class_name PressurePlate
extends Node2D
## Momentary pressure plate (T-024; locked semantics, see /BLUEPRINT.md ->
## Core Logic puzzle primitives): pressed while ANY grid occupant (player or
## block) stands on its cell, released the instant the cell is vacated. It is
## not an occupant itself - things stand ON it - so it lives outside the
## occupancy map and listens to RoomGrid.cell_occupancy_changed.
##
## A block pushed onto the plate is the persistent solution; the player
## standing on it is the temporary demonstration.

signal pressed_changed(pressed: bool)

var room: RoomGrid
var cell := Vector2i.ZERO
var id := ""
## link id of the LockedDoor this plate drives (wired by PuzzleController).
var target_id := ""
var pressed := false
var _face: ColorRect


func _ready() -> void:
	# Placeholder art: a recessed steel plate, darker while pressed.
	z_index = -1  # under whatever stands on it
	var rim := ColorRect.new()
	rim.color = Color(0.3, 0.3, 0.34)
	rim.position = Vector2(-24, -24)
	rim.size = Vector2(48, 48)
	add_child(rim)
	_face = ColorRect.new()
	_face.color = Color(0.55, 0.57, 0.62)
	_face.position = Vector2(-19, -19)
	_face.size = Vector2(38, 38)
	add_child(_face)
	_refresh()


## Wire the plate to its room. Called by the room builder after `room`/`cell`
## are set; the plate then tracks its cell for the room's lifetime.
func watch_room() -> void:
	position = room.cell_to_pos(cell)
	room.cell_occupancy_changed.connect(_on_cell_changed)
	_refresh()


func _on_cell_changed(c: Vector2i) -> void:
	if c == cell:
		_refresh()


func _refresh() -> void:
	if room == null:
		return
	var now := room.get_occupant(cell) != null
	if now == pressed:
		return
	pressed = now
	if _face:
		_face.color = Color(0.38, 0.42, 0.4) if pressed else Color(0.55, 0.57, 0.62)
	pressed_changed.emit(pressed)
