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
@export var sprite_frames: SpriteFrames
@export var starting_abilities: Array[Resource] = []
