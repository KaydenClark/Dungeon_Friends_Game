class_name TutorialHubRoom
extends LdtkRoom
## Tutorial dungeon Room 1 - the hub (T-027, see /BLUEPRINT.md -> Phase 2
## Target). The entry door locks behind the player; a 3x3 pushing space with
## the PressurePlate at its center and a PushableBlock in a corner drives the
## east door to the pit room; the locked chest (shield inside) is visible
## from the start; a reset lever is the soft-lock escape valve. Room 3's
## loop-back re-enters through the west door, which only opens from that far
## side. Opening the chest completes the dungeon and unbolts the entry door.
##
## Doorway targets: forest_exit (south, under the entry door), pit_room
## (east, plate-driven door), fight_room_shortcut (west, after the loop).

## Cell just inside the west door, where the Room 3 loop drops the player.
const WEST_ENTRY := Vector2i(1, 6)


func _init() -> void:
	level_path = "res://assets/levels/tutorial_dungeon.ldtk"
	level_name = "HubRoom"


func _room_ready() -> void:
	# Flavor the special doors. hub_entry opens when the dungeon is complete;
	# hub_west only ever opens from the Room 3 side.
	var entry := _door_with_link("hub_entry")
	if entry:
		entry.locked_lines = PackedStringArray([
			"The door slammed shut behind you - it won't budge.",
			"Something in this place must release it...",
		])
	var west := _door_with_link("hub_west")
	if west:
		west.locked_lines = PackedStringArray([
			"It won't budge from this side.",
		])
	player.move_finished.connect(_check_completion)
	if not SceneManager.flags.get("hub_seen", false):
		SceneManager.flags["hub_seen"] = true
		SceneManager.show_dialogue([
			"*THUD* - the door slams shut behind you!",
			"A locked chest sits across the room...",
			"and a strange plate is set into the floor.",
		])


func _on_doorway(fields: Dictionary) -> void:
	match str(fields.get("TargetRoom", "")):
		"forest_exit":
			SceneManager.exit_room()
		"pit_room":
			SceneManager.enter_room(TutorialPitRoom.new())
		"fight_room_shortcut":
			# Back through the shortcut the loop opened: one room deep.
			var fight := TutorialFightRoom.new()
			fight.rooms_below_to_hub = 1
			fight.spawn_override = TutorialFightRoom.WEST_ENTRY
			SceneManager.enter_room(fight)


## Called by SceneManager after exit_rooms() restores this room. The Room 3
## loop-back lands the player at the west door and swings it open for good.
func on_room_restored() -> void:
	if not SceneManager.flags.get("tutorial_loop_return", false):
		return
	SceneManager.flags.erase("tutorial_loop_return")
	teleport(player, WEST_ENTRY)
	var west := _door_with_link("hub_west")
	if west and not west.opened:
		west.open_permanently()
		SceneManager.show_dialogue([
			"The west door swings open from this side!",
			"A shortcut back - now, about that chest...",
		])


## The dungeon's finish line: once the chest has been opened, unbolt the
## entry door so the player can leave with their prize.
func _check_completion() -> void:
	if not SceneManager.flags.get("chest_tutorial_chest_opened", false):
		return
	var entry := _door_with_link("hub_entry")
	if entry and not entry.opened:
		entry.open_permanently()
		SceneManager.show_dialogue([
			"*CLUNK* - somewhere below, a heavy bolt slides open.",
			"The way back to the forest is clear!",
		])


func _door_with_link(id: String) -> LockedDoor:
	for d: LockedDoor in doors:
		if d.link_id == id:
			return d
	return null
