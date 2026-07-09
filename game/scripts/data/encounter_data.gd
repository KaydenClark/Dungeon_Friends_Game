class_name EncounterData
extends Resource
## Encounter record (T-044, D-010: built now as a stub, wired at Phase 4's
## T-066). An overworld enemy that carries one of these represents a *party*
## of enemies; touching it builds the combat enemy side from enemy_group.
## No random rolls anywhere - encounters are always authored (locked
## decision: no random encounters).

@export var id: String = ""
@export var enemy_group: Array[EnemyStats] = []
## Post-MVP: picks the combat backdrop once arenas have art.
@export var background_id: String = ""
