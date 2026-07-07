@tool
## LDtk entity post-import hook (T-031, locked decision D-002: levels are
## authored all-in as LDtk entities). Set as `entities_post_import` in each
## .ldtk file's import options. For every entity instance on an entity layer
## it instantiates the matching game object (by entity identifier), carries
## the LDtk custom fields across, and stamps grid metadata. The runtime side
## (LdtkRoom.adopt_entities) reparents each spawned node into the room's grid
## and wires occupancy/refs - import time knows the *what/where*, the room
## knows the *runtime how*.
##
## Entity-layer conventions (the contract level authors follow):
##   PlayerSpawn                  -> Marker2D (cell only)
##   Npc        {Lines: Array<String>, Heals: Bool, ColorHex: String}
##   Enemy      {StatsId: String, IsBoss: Bool, LeashRadius: Int, UniqueId: String}
##   LockedDoor {KeyId: String, LinkId: String}
##   PushableBlock {LinkId: String}
##   PressurePlate {Id: String, TargetId: String}
##   Chest      {Id: String, KeyId: String, RewardId: String}
##   Lever      (cell only)
##   Doorway    {TargetRoom: String, SpawnX: Int, SpawnY: Int} -> Marker2D
## Unknown identifiers get a warning and a bare Marker2D so nothing vanishes
## silently. All fields are optional; sensible defaults apply.

const NpcScript = preload("res://scripts/overworld/npc.gd")
const EnemyScript = preload("res://scripts/overworld/overworld_enemy.gd")
const DoorScript = preload("res://scripts/overworld/locked_door.gd")
const BlockScript = preload("res://scripts/puzzles/pushable_block.gd")
const PlateScript = preload("res://scripts/puzzles/pressure_plate.gd")
const ChestScript = preload("res://scripts/puzzles/chest.gd")
const LeverScript = preload("res://scripts/puzzles/lever.gd")


func post_import(entity_layer: LDTKEntityLayer) -> LDTKEntityLayer:
	var grid_size: int = int(entity_layer.definition.get("gridSize", 16))
	var counts := {}
	for entity: Dictionary in entity_layer.entities:
		var node := _spawn(entity)
		var cell := Vector2i(entity.position) / grid_size
		node.set_meta("ldtk_identifier", entity.identifier)
		node.set_meta("ldtk_cell", cell)
		node.set_meta("ldtk_fields", entity.fields)
		counts[entity.identifier] = counts.get(entity.identifier, 0) + 1
		node.name = "%s_%d" % [entity.identifier, counts[entity.identifier]]
		node.position = Vector2(entity.position)
		entity_layer.add_child(node)
	return entity_layer


func _spawn(entity: Dictionary) -> Node2D:
	var fields: Dictionary = entity.fields
	match entity.identifier:
		"PlayerSpawn", "Doorway":
			return Marker2D.new()
		"Npc":
			var npc: Node2D = NpcScript.new()
			var lines := PackedStringArray()
			for line in fields.get("Lines", []):
				lines.append(str(line))
			npc.lines = lines
			npc.heals = bool(fields.get("Heals", false))
			var hex := str(fields.get("ColorHex", ""))
			if hex != "":
				npc.color = Color.from_string(hex, npc.color)
			return npc
		"Enemy":
			var enemy: Node2D = EnemyScript.new()
			enemy.stats = load("res://data/enemies/%s.tres" % str(
					fields.get("StatsId", "forest_slime")))
			enemy.is_boss = bool(fields.get("IsBoss", false))
			enemy.leash_radius = int(fields.get("LeashRadius", -1))
			enemy.unique_id = str(fields.get("UniqueId", ""))
			return enemy
		"LockedDoor":
			var door: Node2D = DoorScript.new()
			door.required_key = str(fields.get("KeyId", "forest_key"))
			door.link_id = str(fields.get("LinkId", ""))
			return door
		"PushableBlock":
			var block: Node2D = BlockScript.new()
			block.link_id = str(fields.get("LinkId", ""))
			return block
		"PressurePlate":
			var plate: Node2D = PlateScript.new()
			plate.id = str(fields.get("Id", ""))
			plate.target_id = str(fields.get("TargetId", ""))
			return plate
		"Chest":
			var chest: Node2D = ChestScript.new()
			chest.id = str(fields.get("Id", "chest"))
			chest.required_key = str(fields.get("KeyId", ""))
			chest.reward_item = str(fields.get("RewardId", ""))
			return chest
		"Lever":
			return LeverScript.new()
	push_warning("entities_post_import: unknown entity '%s' - spawning a marker"
			% entity.identifier)
	return Marker2D.new()
