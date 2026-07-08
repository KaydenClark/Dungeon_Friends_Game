extends "res://tests/gd_test.gd"
## Red/green suite for B-08 (Kayden, 2026-07-07 round-2 playtest): exiting
## the tutorial dungeon restored the player standing ON the forest's doorway
## trigger cell, so "walking back in" (north, through the open door) stepped
## PAST the trigger into the decorative cave-mouth dirt pocket - a walkable
## dead end that reads as a broken room. The doorway only fires on *arrival*
## at its cell, so the fix is spatial: when the forest is restored,
## on_room_restored() steps the player off the trigger to the forest side,
## facing the forest - re-entering then naturally re-fires the transition.


func _forest() -> ForestRoom:
	var room := ForestRoom.new()
	add_child(room)   # _ready() builds the LDtk level + entities
	return room


func _dungeon_doorway(room: ForestRoom) -> Vector2i:
	for c: Vector2i in room.doorways:
		if str(room.doorways[c].get("TargetRoom", "")) == "tutorial_hub":
			return c
	return Vector2i(-1, -1)


func test_restore_steps_the_player_off_the_doorway_trigger() -> void:
	var room := _forest()
	var door_cell := _dungeon_doorway(room)
	ne(door_cell, Vector2i(-1, -1), "forest has the dungeon doorway")
	room.teleport(room.player, door_cell)   # how exit_rooms leaves the player
	room.on_room_restored()
	eq(room.player.cell, door_cell + Vector2i.DOWN,
			"restored player stands on the forest side of the door")
	eq(room.player.facing, Vector2i.DOWN, "facing back into the forest")
	room.queue_free()
	SceneManager.reset_session_state()


func test_restore_away_from_the_door_is_untouched() -> void:
	var room := _forest()
	var start := room.player.cell
	ne(start, _dungeon_doorway(room), "spawn is not the doorway")
	room.on_room_restored()
	eq(room.player.cell, start,
			"a restore elsewhere (e.g. post-combat) never teleports the player")
	room.queue_free()
	SceneManager.reset_session_state()
