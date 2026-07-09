class_name CharacterStats
extends Resource
## Party member stat block (see /BLUEPRINT.md -> Data Model). All balance
## numbers live in .tres instances under game/data/characters/, never in
## scene scripts (locked decision).

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 10
@export var max_mp: int = 0
@export var attack: int = 1
@export var defense: int = 0
@export var speed: int = 1
## Tactical combat reach (T-063 range-field decision, 2026-07-08): cells
## moved per combat turn / basic-attack Manhattan reach. Abilities carry
## their own attack_range on AbilityData.
@export var move_range: int = 3
@export var attack_range: int = 1
@export var sprite_frames: SpriteFrames
@export var starting_abilities: Array[AbilityData] = []
## Art-pass slots (T-043): empty until Asset Batch C/F wire real art.
@export var portrait: Texture2D
@export var combat_sprite: Texture2D
