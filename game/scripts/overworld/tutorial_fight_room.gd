class_name TutorialFightRoom
extends LdtkRoom
## Tutorial dungeon Room 4 - the fight room (T-027). A lone Dungeon Slime
## (unique_id key_guardian) carries the dungeon_key that opens the hub's
## north door to the chest room (Kayden 2026-07-07: door locked, not the
## chest). Beating it opens the loop back: the west door leads straight to
## the hub, popping the suspended rooms between (SceneManager.exit_rooms),
## where the hub repositions the player at its west door and opens it
## permanently.
##
## Doorway targets: pit_room_return (south, back the way you came),
## hub_loop (west, the shortcut home).

## Where the hub's west-door shortcut drops the player when re-entering.
const WEST_ENTRY := Vector2i(1, 4)

## How many rooms sit between this room and the hub on the stack: 2 when
## entered the long way (hub -> pit -> here), 1 via the opened shortcut.
var rooms_below_to_hub := 2


func _init() -> void:
	level_path = "res://assets/levels/tutorial_dungeon.ldtk"
	level_name = "FightRoom"


func _room_ready() -> void:
	# The guardian respawns on every rebuild (D-009/T-048), so there is no
	# "quiet chamber" empty state anymore - the intro line just plays once.
	if not SceneManager.flags.get("fight_room_seen", false):
		SceneManager.flags["fight_room_seen"] = true
		SceneManager.show_dialogue([
			"Something big slithers in the dark...",
			"It's guarding a glint of brass - a key!",
		])


func _on_doorway(fields: Dictionary) -> void:
	match str(fields.get("TargetRoom", "")):
		"pit_room_return":
			SceneManager.exit_room()
		"hub_loop":
			SceneManager.flags["tutorial_loop_return"] = true
			SceneManager.exit_rooms(rooms_below_to_hub)
