class_name ArenaData
extends Resource
## One editable authored battle arena (T-072, D-018). Topology remains in the
## LDtk level named by ldtk_path + level_id; this record holds the stable,
## non-visual metadata used to select it. Deployment zones intentionally stay
## in LDtk entities so level authors edit their layout in one place.

const TIER_EMPTY := "empty"
const TIER_MID := "mid"
const TIER_HARD := "hard"

@export var id: String = ""
@export var biome: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export_enum("empty", "mid", "hard") var tier: String = TIER_EMPTY
@export_range(1, 100, 1) var weight := 1
@export_file("*.ldtk") var ldtk_path: String = ""
@export var level_id: String = ""
@export var mirror_safe := false


func validation_error() -> String:
	if id.strip_edges().is_empty():
		return "ArenaData requires a stable id"
	if biome.strip_edges().is_empty():
		return "ArenaData '%s' requires a biome" % id
	if not is_valid_tier():
		return "ArenaData '%s' has invalid tier '%s'" % [id, tier]
	if weight < 1:
		return "ArenaData '%s' requires a positive weight" % id
	if ldtk_path.strip_edges().is_empty():
		return "ArenaData '%s' requires an LDtk path" % id
	if level_id.strip_edges().is_empty():
		return "ArenaData '%s' requires an LDtk level id" % id
	return ""


func is_valid_tier() -> bool:
	return tier == TIER_EMPTY or tier == TIER_MID or tier == TIER_HARD


func matches(requested_biome: String, required_tags: PackedStringArray) -> bool:
	if biome != requested_biome:
		return false
	for tag in required_tags:
		if not tags.has(tag):
			return false
	return true
