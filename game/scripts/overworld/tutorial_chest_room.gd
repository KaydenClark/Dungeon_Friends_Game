class_name TutorialChestRoom
extends LdtkRoom
## Tutorial dungeon Room 2 - the chest room (Kayden 2026-07-07: "the chest
## goes into a second room off to the side... I like having the door locked
## instead"). A small side chamber behind the hub's north key door
## (dungeon_key, dropped by Room 4's guardian). The chest itself is unlocked
## and holds the shield (D-001); opening it completes the dungeon - the hub
## notices the chest flag and unbolts the entry door.
##
## Doorway targets: hub_return (south, back to the hub).


func _init() -> void:
	level_path = "res://assets/levels/tutorial_dungeon.ldtk"
	level_name = "ChestRoom"


func _room_ready() -> void:
	if not SceneManager.flags.get("chest_room_seen", false):
		SceneManager.flags["chest_room_seen"] = true
		SceneManager.show_dialogue([
			"A small, quiet vault. No tricks, no traps -",
			"just a sturdy old chest, waiting.",
		])


func _on_doorway(fields: Dictionary) -> void:
	if str(fields.get("TargetRoom", "")) == "hub_return":
		SceneManager.exit_room()
