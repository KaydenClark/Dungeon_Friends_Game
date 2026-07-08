class_name ForestRoom
extends LdtkRoom
## The starting forest, authored through the LDtk pipeline (T-011): tiles from
## forest.ldtk's Ground layer, walls from the Wall IntGrid, and every entity
## (NPCs, slimes, boss, locked door, spawn, doorway) placed as an LDtk entity
## instance adopted via the T-031 post-import hook. Replaces the code-built
## ForestSlice layout; the RoomGrid runtime logic is unchanged.
##
## Layout beats: a quest NPC near spawn, a healer mid-map, roaming slimes, a
## leashed Boss Slime guarding the locked east door with the forest key in
## its belly, and the tutorial dungeon (T-027) behind that door.


func _init() -> void:
	level_path = "res://assets/levels/forest.ldtk"


func _on_doorway(fields: Dictionary) -> void:
	if str(fields.get("TargetRoom", "")) == "tutorial_hub":
		SceneManager.flags["entered_dungeon"] = true
		SceneManager.enter_room(TutorialHubRoom.new())


## Called by SceneManager after exit_rooms() restores the forest. Coming out
## of the dungeon the player is restored standing ON the doorway trigger cell
## (they left from it), and the doorway only fires on *arrival* - so walking
## "back in" (north) stepped past the trigger into the decorative cave-mouth
## pocket instead of re-entering (B-08, Kayden's 2026-07-07 round-2 find).
## Step them to the forest side of the door, facing the forest; walking north
## again then arrives at the trigger and re-fires the transition.
func on_room_restored() -> void:
	if player == null or not doorways.has(player.cell):
		return
	teleport(player, player.cell + Vector2i.DOWN)
	player.set_facing(Vector2i.DOWN)
