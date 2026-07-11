class_name PuzzleController
extends Node
## Per-room puzzle wiring (T-024; MVP choice per /BLUEPRINT.md - explicit
## signal wiring at _ready() is simpler to debug than fully-automatic
## discovery). The room builder hands it the room's plates and doors; it
## connects each plate's pressed_changed to the door whose link_id matches
## the plate's target_id, enforcing the momentary open-while-pressed /
## re-lock-on-release semantics.

var plates: Array = []
var doors: Array = []
var levers: Array = []


func wire() -> void:
	for plate: PressurePlate in plates:
		if plate.target_id == "":
			continue
		var door := _door_with_link(plate.target_id)
		if door == null:
			# A door opened permanently in a previous visit isn't rebuilt -
			# the plate legitimately has nothing left to drive. Anything else
			# is a level-authoring mistake worth flagging.
			if not SceneManager.flags.get("door_%s_opened" % plate.target_id, false):
				push_warning("PuzzleController: plate '%s' targets unknown door '%s'"
						% [plate.id, plate.target_id])
			continue
		door.plate_driven = true
		door.refresh_look()
		plate.pressed_changed.connect(door.set_held_open)
		# Adopt the plate's current state (a block may already sit on it).
		if plate.pressed:
			door.set_held_open(true)
	for lever: Lever in levers:
		if lever.target_id == "":
			continue
		var door := _door_with_link(lever.target_id)
		if door == null:
			push_warning("PuzzleController: lever targets unknown door '%s'"
					% lever.target_id)
			continue
		door.plate_driven = true
		door.refresh_look()
		lever.target_door = door


func _door_with_link(id: String) -> LockedDoor:
	for door: LockedDoor in doors:
		if door.link_id == id:
			return door
	return null
