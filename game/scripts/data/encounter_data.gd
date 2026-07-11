class_name EncounterData
extends Resource
## Encounter record (T-044, D-010: built now as a stub, wired at Phase 4's
## T-066). An overworld enemy that carries one of these represents a *party*
## of enemies; touching it builds the combat enemy side from enemy_group.
## No random rolls anywhere - encounters are always authored (locked
## decision: no random encounters).

@export var id: String = ""
@export var enemy_group: Array[EnemyStats] = []
## D-018 authored battle context. Biome/tags restrict the editable arena pool;
## a boss may set fixed_arena_id to pin one deliberate board. Enemy group
## strength remains independent of the selected terrain tier.
@export var biome := "forest"
@export var arena_tags := PackedStringArray()
@export var fixed_arena_id := ""
## Retained for future broad backdrop treatment; live terrain is now supplied
## by the selected authored LDtk arena rather than a copied contact patch.
@export var background_id: String = ""
