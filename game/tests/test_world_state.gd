extends "res://tests/gd_test.gd"
## S-009/TK-001 strict red/green contract suite for the neutral production
## world-state snapshot (WorldState). This is the one seam formations (S-010),
## reactions (S-011), combat (S-012), and persistence (S-003) graduate onto,
## so the contract itself is what gets pinned here: fail-closed validation,
## deterministic round-trip, RoomGrid parity without invented data, exact
## ReactionCore projection parity, and pure in-room encounter lifecycle.

const WorldState := preload("res://scripts/world/world_state.gd")
const ReactionCore := preload("res://scripts/dev/reaction_core.gd")


func _cell(overrides := {}) -> Dictionary:
	var cell := {
		"blocked": false,
		"pit": false,
		"elevation": 0,
		"tags": [],
		"statuses": {},
	}
	for key in overrides:
		cell[key] = overrides[key]
	return cell


func _valid_fixture() -> Dictionary:
	return {
		"width": 6,
		"height": 4,
		"cells": {
			Vector2i(1, 1): _cell({"blocked": true}),
			Vector2i(2, 1): _cell({"pit": true}),
			Vector2i(3, 1): _cell({"elevation": 2}),
			Vector2i(4, 1): _cell({"tags": ["vine"],
					"statuses": {"vine_strength": 1}}),
		},
		"actors": {
			"hero": {"kind": "party", "cell": Vector2i(0, 0)},
			"buddy": {"kind": "party", "cell": Vector2i(0, 1)},
			"slime_a": {"kind": "enemy", "cell": Vector2i(5, 3)},
		},
		"party": {"leader": "hero", "members": ["hero", "buddy"]},
		"encounters": {
			"forest_pair": {"status": "unresolved",
					"cells": [Vector2i(5, 3)]},
		},
		"mode": "exploration",
		"active_encounter": "",
	}


func _expect_invalid(mutate: Callable, expected_error: String) -> void:
	var data := _valid_fixture()
	mutate.call(data)
	eq(WorldState.validate(data), expected_error,
			"validate flags " + expected_error)
	is_null(WorldState.from_dict(data),
			"from_dict fails closed on " + expected_error)


func test_valid_fixture_accepted() -> void:
	eq(WorldState.validate(_valid_fixture()), "", "valid fixture has no error")
	not_null(WorldState.from_dict(_valid_fixture()),
			"from_dict builds from a valid fixture")


func test_validation_fails_closed() -> void:
	_expect_invalid(func(d): d["width"] = 0, "invalid_dimensions")
	_expect_invalid(func(d): d.erase("cells"), "invalid_cells")
	_expect_invalid(func(d): d["cells"]["oops"] = _cell(),
			"invalid_cell_key")
	_expect_invalid(func(d): d["cells"][Vector2i(9, 9)] = _cell(),
			"cell_out_of_bounds")
	_expect_invalid(func(d): d["cells"][Vector2i(1, 1)] = {"blocked": true},
			"invalid_cell_data")
	_expect_invalid(
			func(d): d["cells"][Vector2i(1, 1)] = _cell({"elevation": 1.5}),
			"invalid_cell_data")
	_expect_invalid(
			func(d): d["actors"]["ghost"] = {"kind": "enemy",
					"cell": Vector2i(9, 9)},
			"actor_out_of_bounds")
	_expect_invalid(
			func(d): d["actors"]["ghost"] = {"kind": "enemy",
					"cell": Vector2i(0, 0)},
			"actor_cell_collision")
	_expect_invalid(func(d): d["party"]["leader"] = "nobody",
			"leader_not_member")
	_expect_invalid(func(d): d["party"]["members"].append("nobody"),
			"member_missing_actor")
	_expect_invalid(
			func(d): d["encounters"]["forest_pair"]["status"] = "maybe",
			"invalid_encounter_status")
	_expect_invalid(func(d): d["mode"] = "cutscene", "invalid_mode")
	_expect_invalid(func(d): d["active_encounter"] = "missing_id",
			"active_encounter_missing")
	# mode/encounter coherence: encounter mode requires an active encounter.
	_expect_invalid(func(d): d["mode"] = "encounter",
			"active_encounter_missing")
	# ...and that encounter must actually be active (TK-004 review F2).
	_expect_invalid(func(d):
		d["mode"] = "encounter"
		d["active_encounter"] = "forest_pair",
		"active_encounter_not_active")


func test_round_trip_is_deterministic() -> void:
	var state = WorldState.from_dict(_valid_fixture())
	not_null(state, "fixture builds")
	if state == null:
		return
	var first: Dictionary = state.to_dict()
	var rebuilt = WorldState.from_dict(first)
	not_null(rebuilt, "serialized snapshot rebuilds")
	if rebuilt == null:
		return
	eq(rebuilt.to_dict(), first, "round-trip is lossless and deterministic")
	# Snapshots are value objects: mutating the export must not touch the state.
	first["cells"][Vector2i(1, 1)]["blocked"] = false
	eq(state.to_dict()["cells"][Vector2i(1, 1)]["blocked"], true,
			"to_dict returns a deep copy, not shared references")


func test_room_grid_parity_without_invented_data() -> void:
	var grid := RoomGrid.new()
	add_child(grid)
	grid.setup_grid(5, 4)
	grid.set_blocked(Vector2i(1, 1), true)
	grid.set_pit(Vector2i(2, 2), true)
	var npc := Node2D.new()
	grid.register(npc, Vector2i(3, 3))

	var data: Dictionary = WorldState.snapshot_room_grid(grid,
			{npc: {"id": "healer", "kind": "npc"}})
	eq(WorldState.validate(data), "", "RoomGrid snapshot validates")
	eq(int(data["width"]), 5, "width carried over")
	eq(int(data["height"]), 4, "height carried over")
	eq(data["cells"][Vector2i(1, 1)]["blocked"], true, "wall carried over")
	eq(data["cells"][Vector2i(2, 2)]["pit"], true, "pit carried over")
	eq(data["actors"]["healer"]["cell"], Vector2i(3, 3),
			"occupant mapped to its neutral actor id")
	# "Existing rooms load without invented material/elevation data": every
	# snapshot cell stays at elevation 0 with no tags/statuses until LDtk
	# authoring (TK-002) supplies real values.
	for cell in data["cells"]:
		eq(data["cells"][cell]["elevation"], 0,
				"no invented elevation at %s" % cell)
		eq(data["cells"][cell]["tags"], [], "no invented tags at %s" % cell)
		eq(data["cells"][cell]["statuses"], {},
				"no invented statuses at %s" % cell)
	grid.queue_free()


func test_reaction_projection_parity() -> void:
	# The same request against a hand-authored dev state and against the
	# WorldState projection must produce identical ReactionCore results -
	# this is the "one engine, one state" promise of D-031 at the seam.
	var fixture := _valid_fixture()
	var state = WorldState.from_dict(fixture)
	not_null(state, "fixture builds")
	if state == null:
		return
	var dev_state := {"width": 6, "height": 4, "cells": {
		Vector2i(1, 1): {"tags": [], "statuses": {}},
		Vector2i(2, 1): {"tags": [], "statuses": {}},
		Vector2i(3, 1): {"tags": [], "statuses": {}},
		Vector2i(4, 1): {"tags": ["vine"],
				"statuses": {"vine_strength": 1}},
	}}
	var request := {"verb": "fire", "target": Vector2i(4, 1),
			"context": "exploration"}
	var dev_result: Dictionary = ReactionCore.calculate(dev_state, request)
	var projected: Dictionary = state.reaction_state()
	var seam_result: Dictionary = ReactionCore.calculate(projected, request)
	eq(seam_result["valid"], true, "projected reaction request is valid")
	eq(seam_result["changed_cells"], dev_result["changed_cells"],
			"changed cells identical through the seam")
	eq(seam_result["damage"], dev_result["damage"],
			"damage identical through the seam")
	eq(seam_result["propagation_order"], dev_result["propagation_order"],
			"propagation identical through the seam")
	# Committing the reaction back is explicit and updates only material state.
	state.commit_reaction(seam_result)
	var after: Dictionary = state.to_dict()
	ok(after["cells"][Vector2i(4, 1)]["tags"].has("fire"),
			"committed reaction lands in the snapshot")
	eq(after["cells"][Vector2i(1, 1)]["blocked"], true,
			"geometry untouched by a material commit")


func test_encounter_lifecycle_is_pure_and_fail_closed() -> void:
	var state = WorldState.from_dict(_valid_fixture())
	not_null(state, "fixture builds")
	if state == null:
		return
	var before: Dictionary = state.to_dict()

	eq(state.begin_encounter("missing_id"), "unknown_encounter",
			"beginning an unknown encounter fails closed")
	eq(state.to_dict(), before, "failed begin leaves state untouched")

	eq(state.begin_encounter("forest_pair"), "", "known encounter begins")
	eq(state.to_dict()["mode"], "encounter", "mode flips to encounter")
	eq(state.to_dict()["active_encounter"], "forest_pair",
			"active encounter recorded")
	eq(state.begin_encounter("forest_pair"), "already_in_encounter",
			"re-entry fails closed")

	eq(state.resolve_active_encounter(), "", "active encounter resolves")
	eq(state.to_dict()["encounters"]["forest_pair"]["status"], "resolved",
			"resolution is recorded")
	eq(state.to_dict()["mode"], "exploration", "mode returns to exploration")
	eq(state.to_dict()["active_encounter"], "", "active encounter cleared")
	eq(state.resolve_active_encounter(), "no_active_encounter",
			"resolving outside an encounter fails closed")
	eq(state.begin_encounter("forest_pair"), "encounter_already_resolved",
			"resolved encounters stay resolved (D-028)")

	# Same-room continuity: the lifecycle never touches cells, actors, or
	# party identity - only mode/encounter bookkeeping (D-025).
	var after: Dictionary = state.to_dict()
	eq(after["cells"], before["cells"], "cells continuous through lifecycle")
	eq(after["actors"], before["actors"],
			"actors continuous through lifecycle")
	eq(after["party"], before["party"], "party continuous through lifecycle")
