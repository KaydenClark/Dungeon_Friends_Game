class_name CharacterStats
extends Resource
## Party member TEMPLATE (T-052 reshape; see /BLUEPRINT.md -> Data Model):
## the definition of a character, never their live state - current HP/XP/
## level/recruitment live on GameState (and SaveData saves by this id).
## Combat numbers live in the shared CombatStats block so abilities treat
## both sides of a fight identically. All balance numbers live in .tres
## instances under game/data/characters/, never in scene scripts (locked
## decision).

@export var id: String = ""
@export var display_name: String = ""
## balanced / tank / striker / caster / support.
@export var role: StringName = &"balanced"

## The shared combat stat block (same Resource enemies use).
@export var stats: CombatStats

@export_range(1, 99) var starting_level: int = 1

## Id references resolved through libraries (the ItemLibrary pattern), not
## embedded Resources - what save files and LDtk fields speak (T-035 will
## add the AbilityData records these point at).
@export var starting_ability_ids: Array[StringName] = []
@export var starting_equipment_ids: Array[StringName] = []

## Zelda-style utility tags for overworld puzzles, e.g. "cut_vines",
## "push_heavy_blocks", "light_torches". Schema-only until the party system
## (Phase 5) makes the leader's utility matter.
@export var exploration_tags: Array[StringName] = []

@export_multiline var description: String = ""

## Art hooks - empty until the art pass (T-043).
@export var portrait: Texture2D
@export var battle_sprite: SpriteFrames
