class_name EnemyStats
extends Resource
## Enemy TEMPLATE (T-052 reshape; see /BLUEPRINT.md -> Data Model): the
## definition of an enemy kind, never a live instance - combat HP lives on
## the combat unit, and per D-009 enemies always respawn, so no defeated
## state is ever saved from here. Combat numbers live in the shared
## CombatStats block so abilities treat both sides identically. All balance
## numbers live in .tres instances under game/data/enemies/, never in scene
## scripts (locked decision).

## Overworld movement profile (kept as our enum rather than the adopted
## spec's ai_profile_id string - it predates T-052 and the AI consumes it).
enum AIBehavior { RANDOM_WALK, BIASED_TRACKING, PATTERN }

@export var id: String = ""
@export var display_name: String = ""

## beast / plant / goblin / undead / slime / ...
@export var family: StringName = &"beast"
## minion / striker / tank / caster / controller / boss.
@export var role: StringName = &"striker"
## minion / standard / elite / boss.
@export var rank: StringName = &"standard"

## The shared combat stat block (same Resource party members use).
@export var stats: CombatStats

## Id references resolved through libraries, like the character template.
@export var ability_ids: Array[StringName] = []
@export var ai_behavior: AIBehavior = AIBehavior.RANDOM_WALK

## {damage_type: multiplier} e.g. {"fire": 1.5, "poison": 0.0}. Types at
## MVP: physical/fire/frost/shock/poison/spirit. Schema-only until Phase 4
## combat consumes it; most enemies should have none.
@export var damage_resistances: Dictionary = {}
@export var status_immunities: Array[StringName] = []

@export_range(0, 9999) var xp_reward: int = 0
## Item ids resolved through ItemLibrary (T-043 deviation from embedded
## ItemData - string ids are what LDtk fields and the reward code speak).
@export var loot_table: PackedStringArray = PackedStringArray()

## Art hook - empty until the art pass (T-043).
@export var battle_sprite: SpriteFrames
