class_name GroveRoom
extends LdtkRoom
## S-004/TK-002 (D-044): the Withered Grove - the thesis route's authored
## room off the forest's south edge (contract:
## docs/planning/S004_THESIS_ROUTE.md). Wren recruits on dialogue by the
## entrance, Moss's herb bed resolves without combat, the vine gate answers
## a grown trellis, and beating the grove guardian regrows the grove heart
## permanently (S-003 persistence carries all of it).

## The withered heart cells that regrow on the guardian's defeat. Kept as an
## explicit authored constant so the regrowth is deterministic and testable.
const HEART_CELLS: Array[Vector2i] = [Vector2i(14, 4), Vector2i(15, 4),
		Vector2i(15, 5), Vector2i(14, 6)]

## Where a FRESH forest drops the player when the grove has no suspended
## room beneath it (a save loaded straight into the grove): one cell north
## of the forest's south doorway.
const FOREST_RETURN := Vector2i(10, 17)


func _init() -> void:
	level_path = "res://assets/levels/grove.ldtk"


func _room_ready() -> void:
	encounter_resolved.connect(_on_grove_encounter_resolved)


func _on_grove_encounter_resolved(encounter_id: String,
		victory: bool) -> void:
	if encounter_id != "grove_guardian" or not victory:
		return
	if SceneManager.flags.get("grove_restored", false):
		return
	# The regrowth rides the same preview/commit vocabulary seam as every
	# other world change - no side-channel mutation (D-031).
	for cell in HEART_CELLS:
		var result := preview_reaction({"verb": "grow", "target": cell,
				"context": "exploration"})
		if result.get("valid", false):
			commit_reaction(result)
	SceneManager.flags["grove_restored"] = true
	_show_party_toast("THE GROVE HEART REGROWS!")


func _on_doorway(fields: Dictionary) -> void:
	if str(fields.get("TargetRoom", "")) != "forest":
		return
	# The forest normally waits suspended beneath this room: resume it (the
	# grove frees, so the next entry rebuilds fresh from persisted truth).
	# Only a save loaded straight into the grove has no room beneath.
	if SceneManager.room_stack.is_empty():
		var forest := ForestRoom.new()
		forest.spawn_override = FOREST_RETURN
		SceneManager.enter_room(forest)
	else:
		SceneManager.exit_room()
