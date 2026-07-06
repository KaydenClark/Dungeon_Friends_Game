class_name EnemyStats
extends Resource
## Enemy stat block (see /BLUEPRINT.md -> Data Model). All balance numbers
## live in .tres instances under game/data/enemies/, never in scene scripts
## (locked decision).

enum AIBehavior { RANDOM_WALK, BIASED_TRACKING, PATTERN }

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 5
@export var attack: int = 1
@export var defense: int = 0
@export var speed: int = 1
@export var abilities: Array[Resource] = []
@export var ai_behavior: AIBehavior = AIBehavior.RANDOM_WALK
@export var xp_reward: int = 0
@export var loot_table: PackedStringArray = PackedStringArray()
