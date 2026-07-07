class_name LockedDoor
extends Node2D
## A door occupying (and blocking) one cell. Two unlock modes:
## - Key door (default): `interact` opens it permanently when `required_key`
##   is in the inventory.
## - Plate-driven door (T-024, momentary semantics - locked decision): a
##   PuzzleController holds it open while its PressurePlate is pressed and
##   re-locks it on release. Keys never open a plate-driven door.
## Builder must set `room` and `cell` before registering, and mark the cell
## blocked for pathfinding.

var room: RoomGrid
var cell := Vector2i.ZERO
## LDtk link id so plates/controllers can target this door.
var link_id := ""
var required_key := "forest_key"
## When true the door belongs to a plate, not a key.
var plate_driven := false
## Permanently opened (key doors only).
var opened := false
## Currently held open by a pressed plate (plate-driven doors only).
var held_open := false
## Set while waiting for something standing in the doorway to move on before
## the released plate can re-lock it (never close a door onto an occupant).
var _relock_pending := false
var panel: ColorRect


var _keyhole: ColorRect


func _ready() -> void:
	panel = ColorRect.new()
	panel.position = Vector2(-28, -28)
	panel.size = Vector2(56, 56)
	add_child(panel)
	_keyhole = ColorRect.new()
	_keyhole.position = Vector2(-5, -8)
	_keyhole.size = Vector2(10, 16)
	add_child(_keyhole)
	refresh_look()


## Plate-driven doors read as steel machinery, key doors as old wood. Called
## again by PuzzleController.wire(), which may flip plate_driven after _ready.
func refresh_look() -> void:
	if panel == null:
		return
	panel.color = Color(0.4, 0.4, 0.48) if plate_driven else Color(0.45, 0.29, 0.13)
	_keyhole.color = Color(0.65, 0.68, 0.75) if plate_driven else Color(0.9, 0.75, 0.2)


func interact() -> void:
	if opened or held_open:
		return
	if plate_driven:
		SceneManager.show_dialogue([
			"It won't budge - some mechanism holds it shut.",
			"There must be a trigger for it nearby...",
		])
		return
	if SceneManager.inventory.has(required_key):
		open_permanently()
		SceneManager.show_dialogue([
			"You use the %s." % required_key.capitalize().replace("_", " "),
			"The old door creaks open!",
		])
	else:
		SceneManager.show_dialogue([
			"It's locked tight.",
			"Something around here must hold the key...",
		])


## Open for good: leave the grid entirely (key doors, and one-way doors
## unlocked from their far side).
func open_permanently() -> void:
	if opened:
		return
	opened = true
	held_open = false
	room.unregister(self)
	room.set_blocked(cell, false)
	visible = false


## Momentary hold from a pressure plate (via PuzzleController). Opening
## clears the cell; releasing re-locks it - unless something is standing in
## the doorway, in which case the re-lock waits for the cell to empty.
func set_held_open(v: bool) -> void:
	if opened or held_open == v:
		return
	held_open = v
	if v:
		_relock_pending = false
		room.vacate(self)
		room.set_blocked(cell, false)
		visible = false
	else:
		_try_relock()


func _try_relock() -> void:
	if held_open or opened:
		return
	if room.get_occupant(cell) != null:
		if not _relock_pending:
			_relock_pending = true
			room.cell_occupancy_changed.connect(_on_doorway_changed)
		return
	if _relock_pending:
		_relock_pending = false
		room.cell_occupancy_changed.disconnect(_on_doorway_changed)
	room.occupy(self, cell)
	room.set_blocked(cell, true)
	visible = true


func _on_doorway_changed(c: Vector2i) -> void:
	if c == cell:
		_try_relock()
