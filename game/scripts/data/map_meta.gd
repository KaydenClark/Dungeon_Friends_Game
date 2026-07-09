class_name MapMeta
extends Resource
## Per-level metadata companion (T-044, D-010 stub; see /BLUEPRINT.md ->
## Data Model). LDtk stays the source of truth for layout - this carries the
## non-visual facts. music_track wires up post-MVP (M6.5 audio pass);
## encounter_table wires at Phase 4+ when regions need authored pools.

@export var ldtk_level_id: String = ""
@export var display_name: String = ""
@export var music_track: String = ""
@export var encounter_table: Array[EncounterData] = []
