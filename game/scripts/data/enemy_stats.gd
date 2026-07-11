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
## Tactical combat reach (T-063 range-field decision, 2026-07-08): cells
## moved per combat turn / basic-attack Manhattan reach. Abilities carry
## their own attack_range on AbilityData.
@export var move_range: int = 3
@export var attack_range: int = 1
@export var abilities: Array[AbilityData] = []
@export var ai_behavior: AIBehavior = AIBehavior.RANDOM_WALK
@export var xp_reward: int = 0
## String item ids resolved through ItemLibrary (T-043 deliberate deviation
## from Array[ItemData] - ids are what LDtk fields and reward code speak).
@export var loot_table: PackedStringArray = PackedStringArray()
## Art-pass slots (T-043): empty until Asset Batch C/E wire real sprites.
@export var portrait: Texture2D
@export var combat_sprite: Texture2D
@export var sprite_frames: SpriteFrames
