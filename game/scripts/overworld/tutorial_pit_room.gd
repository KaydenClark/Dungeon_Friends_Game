class_name TutorialPitRoom
extends LdtkRoom
## Tutorial dungeon Room 3 - the pressure-plate room (T-078/D-022/D-023).
## One unambiguous open floor teaches one idea, modeled after A Link to the
## Past: player weight opens the north gate only while standing on the plate;
## pushing the heavy block onto it holds the gate open. There are no pits and
## no second mechanism competing with that lesson. A reset lever and the
## south exit keep every bad block position recoverable.
##
## Doorway targets: hub_return (south), fight_room (north, past the chasm).


func _init() -> void:
	level_path = "res://assets/levels/tutorial_dungeon.ldtk"
	level_name = "PitRoom"


func _room_ready() -> void:
	var plate: PressurePlate = plates[0] if not plates.is_empty() else null
	if plate:
		plate.id = "pit_plate"
		plate.target_id = "pit_plate"
		plate.pressed_changed.connect(_on_plate_changed)
	# The first LdtkRoom wiring pass happened before the tutorial plate target
	# was assigned. A second pass connects it to the north gate.
	puzzle.levers = levers
	puzzle.wire()
	if not SceneManager.flags.get("pit_room_seen", false):
		SceneManager.flags["pit_room_seen"] = true
		SceneManager.show_dialogue([
			"The north gate is sealed.",
			"That brass plate is set into the floor like a switch.",
			"(Try stepping on it.)",
		])


func _on_plate_changed(pressed: bool) -> void:
	if not pressed or SceneManager.flags.get("plate_hint_seen", false):
		return
	SceneManager.flags["plate_hint_seen"] = true
	SceneManager.show_dialogue([
		"The plate sinks under your weight - the north gate opens!",
		"Step off and it will close again.",
		"Push the heavy block onto the plate to hold it down.",
	])


func _door_with_link(id: String) -> LockedDoor:
	for door: LockedDoor in doors:
		if door.link_id == id:
			return door
	return null


func _on_doorway(fields: Dictionary) -> void:
	match str(fields.get("TargetRoom", "")):
		"hub_return":
			SceneManager.exit_room()
		"fight_room":
			var fight := TutorialFightRoom.new()
			fight.rooms_below_to_hub = 2
			SceneManager.enter_room(fight)
