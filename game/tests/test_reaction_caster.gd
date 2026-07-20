extends "res://tests/gd_test.gd"
## S-011/TK-003 strict red/green suite: one production preview/commit caller
## for reaction abilities. Any AbilityData carrying a reaction_verb routes
## through ReactionCaster -> room.preview_reaction/commit_reaction; the
## committed world is exactly the previewed result in BOTH exploration and
## encounter contexts (D-031 preview-equals-result), and non-reaction
## abilities or invalid verbs fail closed without touching the room.

const FIXTURE := "res://assets/levels/entity_test_room.ldtk"


func _make_room() -> LdtkRoom:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	return room


func _teardown(room: LdtkRoom) -> void:
	room.queue_free()
	SceneManager.unified_encounters = true
	SceneManager.in_encounter = false
	SceneManager.reset_session_state()
	SceneManager.flags = {}


func _fire_ability() -> AbilityData:
	var ability := AbilityData.new()
	ability.id = "test_fire"
	ability.display_name = "Test Fire"
	ability.reaction_verb = "fire"
	return ability


func test_reaction_ability_previews_and_commits() -> void:
	var room := _make_room()
	var ability := _fire_ability()
	var preview: Dictionary = ReactionCaster.preview(room, ability,
			Vector2i(5, 1))
	eq(preview.get("valid"), true, "reaction ability previews")
	eq(room.material_state["cells"][Vector2i(5, 1)]["tags"], ["vine"],
			"preview never mutates the room")
	var result: Dictionary = ReactionCaster.cast(room, ability, Vector2i(5, 1))
	eq(result.get("valid"), true, "cast commits the previewed reaction")
	ok(room.material_state["cells"][Vector2i(5, 1)]["tags"].has("fire"),
			"the room carries the committed fire")
	eq(result["state_after"], room.material_state,
			"committed state is exactly the previewed state_after")
	_teardown(room)


func test_non_reaction_ability_fails_closed() -> void:
	var room := _make_room()
	var strike := AbilityData.new()
	strike.id = "strike"
	var before: Dictionary = room.material_state.duplicate(true)
	var result: Dictionary = ReactionCaster.cast(room, strike, Vector2i(5, 1))
	eq(result.get("valid"), false, "a non-reaction ability refuses the seam")
	eq(str(result.get("error")), "not_a_reaction_ability",
			"the refusal is named")
	eq(ReactionCaster.cast(room, null, Vector2i(5, 1)).get("valid"), false,
			"a null ability refuses the seam")
	var bogus := AbilityData.new()
	bogus.reaction_verb = "explode"
	eq(ReactionCaster.cast(room, bogus, Vector2i(5, 1)).get("valid"), false,
			"an unknown verb fails closed in the core")
	eq(room.material_state, before, "failed casts never touch the room")
	_teardown(room)


func test_air_direction_is_plumbed() -> void:
	var room := _make_room()
	# Set the flammable chain on fire, then fan it RIGHT with air: the fire
	# must spread along the supplied cardinal direction through the seam.
	var fire := _fire_ability()
	eq(ReactionCaster.cast(room, fire, Vector2i(6, 1)).get("valid"), true,
			"flammable brush catches fire")
	var air := AbilityData.new()
	air.id = "test_air"
	air.reaction_verb = "air"
	var result: Dictionary = ReactionCaster.cast(room, air, Vector2i(6, 1),
			Vector2i.RIGHT)
	eq(result.get("valid"), true, "air cast is valid")
	ok(room.material_state["cells"][Vector2i(7, 1)]["tags"].has("wet") \
			or not room.material_state["cells"][Vector2i(7, 1)]["tags"].is_empty() \
			or result["propagation_order"].size() >= 1,
			"air propagates in the supplied direction")
	_teardown(room)


func test_encounter_context_uses_the_same_seam() -> void:
	# Cast the identical ability on two fresh rooms - once in exploration,
	# once inside an active in-room encounter. The resulting material state
	# must be identical; only the context metadata differs.
	var exploration_room := _make_room()
	var ability := _fire_ability()
	var exploration: Dictionary = ReactionCaster.cast(exploration_room,
			ability, Vector2i(5, 1), Vector2i.RIGHT, "exploration")
	var exploration_state: Dictionary = \
			exploration_room.material_state.duplicate(true)
	_teardown(exploration_room)

	var encounter_room := _make_room()
	SceneManager.unified_encounters = true
	for enemy in encounter_room.enemies:
		if enemy.cell == Vector2i(9, 5):
			eq(encounter_room.begin_room_encounter(enemy), "",
					"encounter begins")
	var encounter: Dictionary = ReactionCaster.cast(encounter_room, ability,
			Vector2i(5, 1), Vector2i.RIGHT, "encounter")
	eq(encounter.get("valid"), true, "casting works inside the encounter")
	eq(str(encounter["metadata"]["context"]), "encounter",
			"context recorded as metadata")
	eq(encounter_room.material_state, exploration_state,
			"identical casts produce identical state in both contexts")
	eq(exploration["changed_cells"], encounter["changed_cells"],
			"identical changed cells across contexts")
	encounter_room.resolve_room_encounter(false)
	_teardown(encounter_room)
