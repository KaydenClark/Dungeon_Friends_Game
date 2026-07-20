extends "res://tests/gd_test.gd"
## S-009/TK-002 strict red/green suite: LDtk/RoomGrid authoring for the
## neutral world-state seam. Pins the authoring contract end to end:
## - `Elevation`/`Material` IntGrid layers feed per-cell integer elevation and
##   initial material tags through the imported `<Name>-values` TileMapLayers
##   (atlas.x is the IntGrid value index - see addons/ldtk-importer layer.gd).
## - Every overworld Enemy gets a stable encounter id: its authored UniqueId,
##   else a deterministic id from its authored cell.
## - WorldState.snapshot_ldtk_room() is the fail-closed adapter: it returns a
##   valid neutral snapshot or a named error, never a half-guessed state.
## - Rooms authored before TK-002 (no Elevation/Material layers) snapshot with
##   zero elevation and no tags - no invented data (S-009 acceptance).

const WorldState := preload("res://scripts/world/world_state.gd")
const FIXTURE := "res://assets/levels/entity_test_room.ldtk"
const BAD_FIXTURE := "res://assets/levels/entity_bad_authoring_room.ldtk"
const BAD_DECLARATION_FIXTURE := "res://assets/levels/entity_bad_declaration_room.ldtk"


func _make_room(level_path := FIXTURE) -> LdtkRoom:
	SceneManager.flags = {}
	var room := LdtkRoom.new()
	room.level_path = level_path
	add_child(room)   # _ready builds the grid and adopts entities
	return room


func _find_enemy_at(room: LdtkRoom, cell: Vector2i) -> OverworldEnemy:
	for enemy in room.enemies:
		if enemy.cell == cell:
			return enemy
	return null


func test_index_conversions_fail_closed() -> void:
	eq(LdtkRoom.elevation_for_index(0), 1, "first IntGrid value is elevation 1")
	eq(LdtkRoom.elevation_for_index(7), 8, "highest supported index maps")
	eq(LdtkRoom.elevation_for_index(8), -1, "elevation beyond the cap refused")
	eq(LdtkRoom.elevation_for_index(-1), -1, "negative elevation index refused")
	eq(LdtkRoom.material_for_index(0), "vine", "material index 0 is vine")
	eq(LdtkRoom.material_for_index(1), "flammable", "material index 1 is flammable")
	eq(LdtkRoom.material_for_index(2), "channel", "material index 2 is channel")
	eq(LdtkRoom.material_for_index(3), "smoke", "material index 3 is smoke")
	eq(LdtkRoom.material_for_index(4), "", "unknown material index refused")
	eq(LdtkRoom.material_for_index(-1), "", "negative material index refused")
	eq(LdtkRoom.encounter_id_for("fixture_guardian", Vector2i(5, 6)),
			"fixture_guardian", "authored UniqueId wins as the encounter id")
	eq(LdtkRoom.encounter_id_for("", Vector2i(9, 5)), "enc_9_5",
			"missing UniqueId falls back to the authored cell id")


func test_fixture_authoring_layers_adopted() -> void:
	var room := _make_room()
	eq(room.authoring_errors, [], "fixture authors cleanly")
	eq(room.elevation_at(Vector2i(3, 1)), 1, "Elevation value 1 adopted")
	eq(room.elevation_at(Vector2i(4, 1)), 2, "Elevation value 2 adopted")
	eq(room.elevation_at(Vector2i(2, 2)), 0, "unpainted cell stays at ground")
	eq(room.material_tags(Vector2i(5, 1)), ["vine"], "vine material adopted")
	eq(room.material_tags(Vector2i(6, 1)), ["flammable"],
			"flammable material adopted")
	eq(room.material_tags(Vector2i(7, 1)), ["channel"], "channel adopted")
	eq(room.material_tags(Vector2i(8, 1)), ["smoke"], "smoke adopted")
	eq(room.material_tags(Vector2i(2, 2)), [], "unpainted cell has no tags")
	# Elevation/materials never leak into the v1 walkability model.
	ok(room.is_walkable(Vector2i(4, 1)), "elevated cell still walkable in v1")
	ok(room.is_walkable(Vector2i(5, 1)), "material cell still walkable in v1")
	room.queue_free()
	SceneManager.flags = {}


func test_stable_encounter_ids_stamped() -> void:
	var room := _make_room()
	eq(room.enemies.size(), 2, "both fixture enemies adopted")
	var pair := _find_enemy_at(room, Vector2i(9, 5))
	not_null(pair, "cell-id enemy adopted at its authored cell")
	if pair != null:
		eq(pair.world_encounter_id, "enc_9_5",
				"enemy without UniqueId gets the deterministic cell id")
	var guardian := _find_enemy_at(room, Vector2i(5, 6))
	not_null(guardian, "guardian enemy adopted at its authored cell")
	if guardian != null:
		eq(guardian.world_encounter_id, "fixture_guardian",
				"authored UniqueId becomes the stable encounter id")
	eq(room.authored_encounters.get("enc_9_5"), Vector2i(9, 5),
			"authored encounter cell recorded for the cell id")
	eq(room.authored_encounters.get("fixture_guardian"), Vector2i(5, 6),
			"authored encounter cell recorded for the unique id")
	room.queue_free()
	SceneManager.flags = {}


func test_world_snapshot_valid_and_complete() -> void:
	var room := _make_room()
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "snapshot adapter succeeds on the fixture")
	if data.has("error"):
		room.queue_free()
		return
	eq(WorldState.validate(data), "", "snapshot validates against the contract")
	eq(int(data["width"]), 12, "width carried")
	eq(int(data["height"]), 8, "height carried")
	eq(data["cells"][Vector2i(0, 0)]["blocked"], true, "walls carried")
	eq(data["cells"][Vector2i(8, 3)]["pit"], true, "pits carried")
	eq(data["cells"][Vector2i(4, 1)]["elevation"], 2,
			"authored elevation lands in the snapshot")
	eq(data["cells"][Vector2i(5, 1)]["tags"], ["vine"],
			"authored material tags land in the snapshot")
	eq(data["actors"]["hero"]["kind"], "party",
			"the Player is the roster leader's party actor")
	eq(data["party"]["leader"], "hero", "leader keyed by roster id")
	eq(data["party"]["members"], ["hero", "companion_test"],
			"party membership is the full roster (TK-003)")
	eq(data["actors"]["enc_9_5"]["kind"], "enemy",
			"enemy actor keyed by its stable encounter id")
	eq(data["actors"]["fixture_guardian"]["cell"], Vector2i(5, 6),
			"guardian actor at its live cell")
	eq(data["encounters"]["enc_9_5"],
			{"status": "unresolved", "cells": [Vector2i(9, 5)]},
			"live encounter is unresolved at the enemy's cell")
	eq(data["encounters"]["fixture_guardian"]["status"], "unresolved",
			"guardian encounter starts unresolved")
	# No invented data: every snapshot cell is a wall, pit, authored elevation,
	# or authored material cell - nothing else materializes.
	for cell in data["cells"]:
		var entry: Dictionary = data["cells"][cell]
		ok(entry["blocked"] or entry["pit"] or entry["elevation"] > 0 \
				or not entry["tags"].is_empty(),
				"cell %s exists for an authored reason" % cell)
		eq(entry["statuses"], {}, "no invented statuses at %s" % cell)
	room.queue_free()
	SceneManager.flags = {}


func test_defeated_encounter_resolves_in_snapshot() -> void:
	var room := _make_room()
	var pair := _find_enemy_at(room, Vector2i(9, 5))
	not_null(pair, "cell-id enemy present before defeat")
	if pair == null:
		room.queue_free()
		return
	pair.defeated()
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "snapshot still succeeds after a defeat")
	if not data.has("error"):
		eq(data["encounters"]["enc_9_5"],
				{"status": "resolved", "cells": [Vector2i(9, 5)]},
				"defeated encounter is resolved at its authored cell")
		eq(data["encounters"]["fixture_guardian"]["status"], "unresolved",
				"other encounters stay unresolved")
		not_ok(data["actors"].has("enc_9_5"),
				"defeated enemy is no longer an actor")
	room.queue_free()
	SceneManager.flags = {}


func test_existing_room_without_layers_has_no_invented_data() -> void:
	SceneManager.reset_session_state()
	var room := TutorialFightRoom.new()
	add_child(room)
	eq(room.authoring_errors, [], "pre-TK-002 room has no authoring errors")
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "pre-TK-002 room snapshots cleanly")
	if not data.has("error"):
		eq(WorldState.validate(data), "", "pre-TK-002 snapshot validates")
		for cell in data["cells"]:
			eq(data["cells"][cell]["elevation"], 0,
					"no invented elevation at %s" % cell)
			eq(data["cells"][cell]["tags"], [], "no invented tags at %s" % cell)
		for id in data["encounters"]:
			eq(data["encounters"][id]["status"], "unresolved",
					"fresh room encounters start unresolved")
	room.free()
	SceneManager.reset_session_state()


func test_bad_declaration_fails_closed() -> void:
	# Legal LDtk edits - reordering Material values or leaving a gap in the
	# Elevation values - shift the imported atlas indices. The positional
	# mapping would silently lie, so the declarations themselves are validated
	# against the authoring contract and the room fails closed instead.
	var room := _make_room(BAD_DECLARATION_FIXTURE)
	not_ok(room.authoring_errors.is_empty(), "bad declarations are detected")
	var has_material := false
	var has_elevation := false
	for error in room.authoring_errors:
		if error.begins_with("material_declaration_mismatch"):
			has_material = true
		if error.begins_with("elevation_declaration_invalid"):
			has_elevation = true
	ok(has_material, "reordered Material declaration named")
	ok(has_elevation, "non-contiguous Elevation declaration named")
	eq(room.elevation, {}, "fail closed: no elevation adopted")
	eq(room.materials, {}, "fail closed: no materials adopted")
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	ok(data.has("error"), "snapshot adapter refuses bad declarations")
	room.queue_free()
	SceneManager.flags = {}


func test_actor_id_collision_fails_closed() -> void:
	# Defense in depth for the adapter: an authored UniqueId that collides
	# with a reserved actor id ("player", an NPC id, an object id) must never
	# silently overwrite another actor in the snapshot.
	var room := _make_room()
	var pair := _find_enemy_at(room, Vector2i(9, 5))
	not_null(pair, "fixture enemy present")
	if pair != null:
		room.authored_encounters.erase(pair.world_encounter_id)
		pair.world_encounter_id = "hero"   # collides with the roster leader
		room.authored_encounters["hero"] = Vector2i(9, 5)
		var data: Dictionary = WorldState.snapshot_ldtk_room(room)
		ok(data.has("error"), "leader-id collision refuses the snapshot")
		if data.has("error"):
			ok(str(data["error"]).begins_with("actor_id_collision"),
					"collision error is named")
		room.authored_encounters.erase("hero")
		pair.world_encounter_id = "companion_test"   # collides with a follower
		room.authored_encounters["companion_test"] = Vector2i(9, 5)
		var follower_case: Dictionary = WorldState.snapshot_ldtk_room(room)
		ok(follower_case.has("error"),
				"follower-id collision refuses the snapshot")
		if follower_case.has("error"):
			ok(str(follower_case["error"]).begins_with("actor_id_collision"),
					"follower collision error is named")
	room.queue_free()
	SceneManager.flags = {}


func test_bad_authoring_fails_closed() -> void:
	var room := _make_room(BAD_FIXTURE)
	# The bad fixture authors an unknown fifth material value AND two enemies
	# sharing one UniqueId. Both must be caught, nothing may be half-applied,
	# and the v1 route must keep working.
	not_ok(room.authoring_errors.is_empty(), "bad authoring is detected")
	var has_material_error := false
	var has_duplicate_error := false
	for error in room.authoring_errors:
		if error.begins_with("unknown_material_value"):
			has_material_error = true
		if error.begins_with("duplicate_encounter_id"):
			has_duplicate_error = true
	ok(has_material_error, "unknown material value named")
	ok(has_duplicate_error, "duplicate encounter id named")
	eq(room.elevation, {}, "fail closed: no partial elevation adopted")
	eq(room.materials, {}, "fail closed: no partial materials adopted")
	eq(room.enemies.size(), 2, "v1 room build still adopts the enemies")
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	ok(data.has("error"), "snapshot adapter refuses a bad-authored room")
	if data.has("error"):
		ok(str(data["error"]).begins_with("unknown_material_value") \
				or str(data["error"]).begins_with("duplicate_encounter_id") \
				or str(data["error"]).begins_with("material_declaration_mismatch"),
				"snapshot error names the authoring problem")
	room.queue_free()
	SceneManager.flags = {}
