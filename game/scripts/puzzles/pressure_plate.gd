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
var _sprite: Sprite2D


func _ready() -> void:
	z_index = 0
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/art/objects/kenney/pressure_plate.png")
	_sprite.scale = Vector2.ONE * 3.0
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_refresh()


## Wire the plate to its room. Called by the room builder after `room`/`cell`
## are set; the plate then tracks its cell for the room's lifetime.
func watch_room() -> void:
	position = room.cell_to_pos(cell)
	room.cell_occupancy_changed.connect(_on_cell_changed)
	_refresh()


func _on_cell_changed(c: Vector2i) -> void:
	if c == cell:
		# S-012 review C1: combat movement inside an in-room encounter is
		# tactical repositioning, not puzzle input - plates freeze while the
		# encounter runs and re-evaluate when it releases (LdtkRoom calls
		# _refresh via refresh_after_encounter), so puzzle state stays
		# untouched mid-fight (D-025) while the world stays honest after.
		if SceneManager.in_encounter:
			return
		_refresh()


## Re-evaluate after an encounter releases: whoever actually ended the fight
## standing on the plate presses it for real.
func refresh_after_encounter() -> void:
	_refresh()


func _refresh() -> void:
	if room == null:
		return
	var now := room.get_occupant(cell) != null
	if now == pressed:
		return
	pressed = now
	if _sprite:
		_sprite.modulate = Color(0.55, 0.55, 0.55) if pressed else Color.WHITE
		_sprite.position.y = 4.0 if pressed else 0.0
	pressed_changed.emit(pressed)
