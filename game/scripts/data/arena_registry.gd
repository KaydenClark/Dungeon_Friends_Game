class_name ArenaRegistry
extends RefCounted
## Stable id lookup plus biome/tag filtering for authored battle arenas. It is
## intentionally data-only: LDtk loading and combat placement belong to the
## later T-073/T-074 seams, not selector tests.

var last_error := ""
var _records: Array[ArenaData] = []
var _by_id: Dictionary = {}


func register(arena: ArenaData) -> bool:
	last_error = ""
	if arena == null:
		last_error = "ArenaRegistry cannot register a null record"
		return false
	var error := arena.validation_error()
	if not error.is_empty():
		last_error = error
		return false
	if _by_id.has(arena.id):
		last_error = "ArenaRegistry has duplicate id '%s'" % arena.id
		return false
	_records.append(arena)
	_by_id[arena.id] = arena
	return true


func all() -> Array[ArenaData]:
	var copied: Array[ArenaData] = []
	copied.append_array(_records)
	return copied


func eligible(requested_biome: String,
		required_tags: PackedStringArray = PackedStringArray()) -> Array[ArenaData]:
	var matches: Array[ArenaData] = []
	if requested_biome.strip_edges().is_empty():
		return matches
	for arena in _records:
		if arena.matches(requested_biome, required_tags):
			matches.append(arena)
	return matches


func resolve(arena_id: String) -> ArenaData:
	var found: Variant = _by_id.get(arena_id)
	return found if found is ArenaData else null
