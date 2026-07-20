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
	match str(fields.get("TargetRoom", "")):
		"tutorial_hub":
			SceneManager.flags["entered_dungeon"] = true
			SceneManager.enter_room(TutorialHubRoom.new())
		"withered_grove":
			# S-004/TK-002 (D-044): the thesis route's grove, south edge.
			SceneManager.enter_room(GroveRoom.new())
