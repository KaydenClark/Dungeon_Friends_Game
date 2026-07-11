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
@export var id := ""
## link id of the LockedDoor this plate drives (wired by PuzzleController).
@export var target_id := ""
var pressed := false
var _face: ColorRect
var _center: ColorRect


func _ready() -> void:
	# Placeholder art: a flush brass floor switch, inspired by the readable
	# round pressure buttons in A Link to the Past. It stays under actors.
	# The imported floor TileMap is drawn first. Keep the switch above that
	# floor; actors/blocks use a higher z-index and still cover it naturally.
	z_index = 0
	var rim := ColorRect.new()
	rim.color = Color(0.28, 0.18, 0.08)
	rim.position = Vector2(-24, -24)
	rim.size = Vector2(48, 48)
	add_child(rim)
	_face = ColorRect.new()
	_face.color = Color(0.86, 0.58, 0.16)
	_face.position = Vector2(-19, -19)
	_face.size = Vector2(38, 38)
	add_child(_face)
	_center = ColorRect.new()
	_center.color = Color(1.0, 0.82, 0.32)
	_center.position = Vector2(-9, -9)
	_center.size = Vector2(18, 18)
	add_child(_center)
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
		_face.color = Color(0.48, 0.30, 0.08) if pressed else Color(0.86, 0.58, 0.16)
	if _center:
		_center.color = Color(0.62, 0.40, 0.10) if pressed else Color(1.0, 0.82, 0.32)
	pressed_changed.emit(pressed)
