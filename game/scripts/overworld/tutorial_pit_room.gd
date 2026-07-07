class_name TutorialPitRoom
extends LdtkRoom
## Tutorial dungeon Room 2 - the pit room (T-027). A 2-cell-wide pit spans
## the full room width - deliberately beyond the 1-cell jump limit, so the
## jump alone can't cross it. The intended solution: push the room's block
## into the pit (fills one cell), then jump the remaining 1-cell gap from the
## filled cell - teaching block-fills-pit, the jump, and the jump's limit in
## one move. Leaving south resets the room (freed + rebuilt), the pit-room
## escape valve if the block gets wedged.
##
## Doorway targets: hub_return (south), fight_room (north, past the pit).


func _init() -> void:
	level_path = "res://assets/levels/tutorial_dungeon.ldtk"
	level_name = "PitRoom"


func _room_ready() -> void:
	if not SceneManager.flags.get("pit_room_seen", false):
		SceneManager.flags["pit_room_seen"] = true
		SceneManager.show_dialogue([
			"A wide chasm splits the room - too wide to jump.",
			"That block looks heavy enough to fall...",
			"(Walk into the block to push it. Alt or C jumps.)",
		])


func _on_doorway(fields: Dictionary) -> void:
	match str(fields.get("TargetRoom", "")):
		"hub_return":
			SceneManager.exit_room()
		"fight_room":
			var fight := TutorialFightRoom.new()
			fight.rooms_below_to_hub = 2
			SceneManager.enter_room(fight)
