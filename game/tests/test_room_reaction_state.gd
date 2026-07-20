extends "res://tests/gd_test.gd"
## S-011/TK-002 strict red/green suite: live material/effect state on the
## production room. Every LdtkRoom owns one mutable reaction state seeded
## from the validated authored Material layer (S-009/TK-002); previews run
## the promoted ReactionCore against it without mutating anything, commits
## are explicit and fail closed, and the neutral world snapshot reflects the
## LIVE state - preview-equals-result at the production seam (D-031).

const WorldState := preload("res://scripts/world/world_state.gd")
const FIXTURE := "res://assets/levels/entity_test_room.ldtk"


func _make_room(level_path := FIXTURE) -> LdtkRoom:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	var room := LdtkRoom.new()
	room.level_path = level_path
	add_child(room)
	return room


func _teardown(room: LdtkRoom) -> void:
	room.queue_free()
	SceneManager.reset_session_state()
	SceneManager.flags = {}


func test_material_state_seeded_from_authoring() -> void:
	var room := _make_room()
	var state: Dictionary = room.material_state
	eq(int(state.get("width", 0)), 12, "state width matches the room")
	eq(int(state.get("height", 0)), 8, "state height matches the room")
	eq(state["cells"][Vector2i(5, 1)]["tags"], ["vine"],
			"authored vine seeds the live state")
	eq(state["cells"][Vector2i(8, 1)]["tags"], ["smoke"],
			"authored smoke seeds the live state")
	eq(state["cells"][Vector2i(2, 2)]["tags"], [],
			"unauthored cells start clean")
	eq(state["cells"][Vector2i(2, 2)]["statuses"], {},
			"no invented statuses anywhere")
	_teardown(room)


func test_preview_never_mutates_and_commit_applies() -> void:
	var room := _make_room()
	var request := {"verb": "fire", "target": Vector2i(5, 1),
			"context": "exploration"}
	var preview: Dictionary = room.preview_reaction(request)
	eq(preview.get("valid"), true, "preview against the live state is valid")
	eq(room.material_state["cells"][Vector2i(5, 1)]["tags"], ["vine"],
			"preview leaves the live state untouched (preview-first)")
	eq(room.commit_reaction(preview), "", "the previewed result commits")
	ok(room.material_state["cells"][Vector2i(5, 1)]["tags"].has("fire"),
			"committed fire lands in the live state")
	ok(room.material_state["cells"][Vector2i(5, 1)]["tags"].has("smoke"),
			"burning produces smoke in the live state")
	not_ok(room.material_state["cells"][Vector2i(5, 1)]["tags"].has("vine"),
			"the burned vine is gone (preview equals result)")
	eq(room.material_tags(Vector2i(5, 1)), ["vine"],
			"the authored record stays intact for rebuilds")
	_teardown(room)


func test_commit_fails_closed() -> void:
	var room := _make_room()
	var before: Dictionary = room.material_state.duplicate(true)
	eq(room.commit_reaction({}), "invalid_reaction_result",
			"an empty result refuses to commit")
	eq(room.commit_reaction({"valid": false, "state_after": {}}),
			"invalid_reaction_result", "an invalid result refuses to commit")
	var wrong_shape := {"valid": true, "state_after": {"width": 2,
			"height": 2, "cells": {}}}
	eq(room.commit_reaction(wrong_shape), "invalid_reaction_result",
			"a mismatched state shape refuses to commit")
	eq(room.material_state, before, "failed commits leave the state untouched")
	_teardown(room)


func test_snapshot_reflects_live_material_state() -> void:
	var room := _make_room()
	var preview: Dictionary = room.preview_reaction({"verb": "fire",
			"target": Vector2i(5, 1), "context": "exploration"})
	eq(room.commit_reaction(preview), "", "reaction committed")
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "post-commit snapshot has no error")
	if not data.has("error"):
		eq(WorldState.validate(data), "", "post-commit snapshot validates")
		ok(data["cells"][Vector2i(5, 1)]["tags"].has("fire"),
				"the snapshot carries the LIVE burned state, not the authoring")
		eq(data["cells"][Vector2i(6, 1)]["tags"], ["flammable"],
				"untouched authored cells still project")
	_teardown(room)


func test_context_parity_through_the_room_seam() -> void:
	# One engine, one state: the identical request in exploration and
	# encounter context differs only in the copied metadata (D-031).
	var room := _make_room()
	var exploration: Dictionary = room.preview_reaction({"verb": "water",
			"target": Vector2i(7, 1), "context": "exploration"})
	var encounter: Dictionary = room.preview_reaction({"verb": "water",
			"target": Vector2i(7, 1), "context": "encounter"})
	eq(exploration["valid"], true, "exploration preview valid")
	eq(encounter["valid"], true, "encounter preview valid")
	eq(exploration["changed_cells"], encounter["changed_cells"],
			"identical changed cells across contexts")
	eq(exploration["state_after"], encounter["state_after"],
			"identical resulting state across contexts")
	eq(str(exploration["metadata"]["context"]), "exploration",
			"context stays metadata")
	eq(str(encounter["metadata"]["context"]), "encounter",
			"context stays metadata for encounters")
	_teardown(room)


func test_pre_authoring_rooms_seed_clean_state() -> void:
	SceneManager.reset_session_state()
	var room := TutorialFightRoom.new()
	add_child(room)
	var state: Dictionary = room.material_state
	eq(int(state.get("width", 0)), room.width, "state sized to the room")
	var dirty := 0
	for cell in state.get("cells", {}):
		if not state["cells"][cell]["tags"].is_empty() \
				or not state["cells"][cell]["statuses"].is_empty():
			dirty += 1
	eq(dirty, 0, "pre-TK-002 rooms seed a fully clean live state")
	var preview: Dictionary = room.preview_reaction({"verb": "water",
			"target": Vector2i(2, 2), "context": "exploration"})
	eq(preview.get("valid"), true, "reactions are previewable everywhere")
	room.free()
	SceneManager.reset_session_state()
