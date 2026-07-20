extends "res://tests/gd_test.gd"
## T-093A strict red/green matrix for the shared deterministic material/effect
## core. Tests speak only to the neutral ReactionCore API that both exploration
## and encounter callers will use.

## S-011/TK-001 promoted the core to the production world namespace
## unchanged; this suite now pins the production path and
## test_production_core_parity pins that dev consumers route through the
## same script (no divergent dev copy can reappear).
const ReactionCore := preload("res://scripts/world/reaction_core.gd")
const RETIRED_DEV_PATH := "res://scripts/dev/reaction_core.gd"


func _cell(tags: Array = [], statuses := {}) -> Dictionary:
	return {"tags": tags.duplicate(), "statuses": statuses.duplicate(true)}


func _state(cells: Dictionary, width := 12, height := 8) -> Dictionary:
	return {"width": width, "height": height, "cells": cells.duplicate(true)}


func _request(verb: String, target: Vector2i, context := "exploration",
		direction := Vector2i.RIGHT) -> Dictionary:
	return {"verb": verb, "target": target, "context": context,
			"direction": direction}


func _outcome(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true)
	copy.erase("metadata")
	return copy


func test_grow_creates_strengthens_and_fire_burns_vine() -> void:
	var initial := _state({Vector2i(2, 2): _cell(["soil"])})
	var grown := ReactionCore.calculate(initial, _request("grow", Vector2i(2, 2)))
	ok(grown["valid"], "grow is valid")
	eq(grown["state_after"]["cells"][Vector2i(2, 2)]["tags"],
			["soil", "vine"], "grow creates a vine without losing soil")
	eq(grown["state_after"]["cells"][Vector2i(2, 2)]["statuses"]["vine_strength"],
			1, "new vine starts at strength 1")
	var strengthened := ReactionCore.calculate(grown["state_after"],
			_request("grow", Vector2i(2, 2)))
	eq(strengthened["state_after"]["cells"][Vector2i(2, 2)]["statuses"]["vine_strength"],
			2, "repeat grow strengthens the vine")
	var burned := ReactionCore.calculate(strengthened["state_after"],
			_request("fire", Vector2i(2, 2)))
	eq(burned["state_after"]["cells"][Vector2i(2, 2)]["tags"],
			["soil", "fire", "smoke"], "fire consumes vine and creates fire/smoke")
	not_ok(burned["state_after"]["cells"][Vector2i(2, 2)]["statuses"].has("vine_strength"),
			"burn removes vine strength")
	eq(burned["damage"], [{"cell": Vector2i(2, 2), "amount": 2,
			"kind": "fire"}], "burn reports neutral cell damage")
	eq(burned["hazards"], [{"cell": Vector2i(2, 2), "kind": "fire",
			"damage": 2}], "burn reports the resulting fire hazard")
	eq(burned["canceled_effects"], [{"cell": Vector2i(2, 2),
			"effect": "vine", "reason": "burned"}], "consumed vine is explicit")


func test_water_wets_or_floods_then_cold_freezes() -> void:
	var initial := _state({
		Vector2i(1, 1): _cell(["floor"]),
		Vector2i(2, 1): _cell(["channel"]),
	})
	var wet := ReactionCore.calculate(initial, _request("water", Vector2i(1, 1)))
	eq(wet["state_after"]["cells"][Vector2i(1, 1)]["tags"],
			["floor", "wet"], "water wets an ordinary cell")
	eq(wet["state_after"]["cells"][Vector2i(1, 1)]["statuses"]["wet_rounds"],
			2, "wet duration is explicit")
	var flooded := ReactionCore.calculate(initial, _request("water", Vector2i(2, 1)))
	eq(flooded["state_after"]["cells"][Vector2i(2, 1)]["tags"],
			["channel", "wet", "flooded"], "water floods a channel and marks it wet")
	var frozen := ReactionCore.calculate(flooded["state_after"],
			_request("cold", Vector2i(2, 1)))
	eq(frozen["state_after"]["cells"][Vector2i(2, 1)]["tags"],
			["channel", "ice"], "cold converts flooded/wet water to ice")
	eq(frozen["state_after"]["cells"][Vector2i(2, 1)]["statuses"]["frozen"],
			true, "frozen status is explicit")
	eq(frozen["canceled_effects"], [
		{"cell": Vector2i(2, 1), "effect": "wet", "reason": "frozen"},
		{"cell": Vector2i(2, 1), "effect": "flooded", "reason": "frozen"},
	], "freeze reports each consumed water effect")


func test_spark_conducts_only_through_connected_wet_cells() -> void:
	var initial := _state({
		Vector2i(2, 2): _cell(["wet"]),
		Vector2i(2, 1): _cell(["wet"]),
		Vector2i(3, 2): _cell(["wet"]),
		Vector2i(4, 2): _cell(["floor"]),
		Vector2i(5, 2): _cell(["wet"]),
	})
	var result := ReactionCore.calculate(initial, _request("spark", Vector2i(2, 2)))
	eq(result["propagation_order"],
			[Vector2i(2, 2), Vector2i(2, 1), Vector2i(3, 2)],
			"spark uses BFS with up/right/down/left neighbor priority")
	eq(result["damage"], [
		{"cell": Vector2i(2, 2), "amount": 2, "kind": "spark"},
		{"cell": Vector2i(2, 1), "amount": 2, "kind": "spark"},
		{"cell": Vector2i(3, 2), "amount": 2, "kind": "spark"},
	], "every connected wet cell receives ordered spark damage")
	not_ok(result["state_after"]["cells"][Vector2i(5, 2)]["statuses"].has("electrified"),
			"dry gap stops conduction")


func test_air_spreads_fire_in_direction_through_flammable_chain() -> void:
	var initial := _state({
		Vector2i(1, 3): _cell(["fire", "smoke"]),
		Vector2i(2, 3): _cell(["vine"], {"vine_strength": 2}),
		Vector2i(3, 3): _cell(["flammable"]),
		Vector2i(4, 3): _cell(["stone"]),
		Vector2i(5, 3): _cell(["vine"], {"vine_strength": 1}),
	})
	var result := ReactionCore.calculate(initial,
			_request("air", Vector2i(1, 3), "exploration", Vector2i.RIGHT))
	eq(result["propagation_order"],
			[Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)],
			"air spreads from the source in one explicit direction")
	ok(result["state_after"]["cells"][Vector2i(2, 3)]["tags"].has("fire"),
			"adjacent vine ignites")
	not_ok(result["state_after"]["cells"][Vector2i(2, 3)]["tags"].has("vine"),
			"spread fire burns the vine")
	ok(result["state_after"]["cells"][Vector2i(3, 3)]["tags"].has("fire"),
			"flammable chain continues")
	not_ok(result["state_after"]["cells"][Vector2i(5, 3)]["tags"].has("fire"),
			"nonflammable stone stops the directional spread")


func test_air_clears_connected_smoke_when_target_is_not_fire() -> void:
	var initial := _state({
		Vector2i(3, 3): _cell(["smoke"]),
		Vector2i(3, 2): _cell(["smoke"]),
		Vector2i(4, 3): _cell(["smoke"]),
		Vector2i(5, 3): _cell(["floor"]),
		Vector2i(6, 3): _cell(["smoke"]),
	})
	var result := ReactionCore.calculate(initial, _request("air", Vector2i(3, 3)))
	eq(result["propagation_order"],
			[Vector2i(3, 3), Vector2i(3, 2), Vector2i(4, 3)],
			"smoke clearing uses the same deterministic BFS order")
	for cell: Vector2i in result["propagation_order"]:
		not_ok(result["state_after"]["cells"][cell]["tags"].has("smoke"),
				"visited smoke is cleared")
	ok(result["state_after"]["cells"][Vector2i(6, 3)]["tags"].has("smoke"),
			"disconnected smoke remains")
	eq(result["canceled_effects"].size(), 3,
			"every cleared smoke effect is reported")


func test_context_changes_metadata_only() -> void:
	var initial := _state({Vector2i(2, 2): _cell(["soil"])})
	var exploration := ReactionCore.calculate(initial,
			_request("grow", Vector2i(2, 2), "exploration"))
	var encounter := ReactionCore.calculate(initial,
			_request("grow", Vector2i(2, 2), "encounter"))
	eq(_outcome(exploration), _outcome(encounter),
			"identical state + verb has identical reaction data in both contexts")
	eq(exploration["metadata"]["context"], "exploration",
			"exploration context is presentation metadata")
	eq(encounter["metadata"]["context"], "encounter",
			"encounter context is presentation metadata")


func test_calculate_is_preview_only_and_returns_complete_commit_candidate() -> void:
	var initial := _state({Vector2i(2, 2): _cell(["soil"])})
	var before := initial.duplicate(true)
	var result := ReactionCore.calculate(initial, _request("grow", Vector2i(2, 2)))
	eq(initial, before, "calculate never mutates caller state")
	ne(result["state_after"], initial, "result carries the complete changed state")
	eq(result["changed_cells"].size(), 1, "preview names every changed cell")
	eq(result["resulting_cells"], [{
		"cell": Vector2i(2, 2),
		"tags": ["soil", "vine"],
		"statuses": {"vine_strength": 1},
	}], "preview exposes neutral resulting tags and statuses")


func test_hard_cascade_boundary_reports_truncation() -> void:
	var cells := {}
	for x in range(ReactionCore.MAX_CASCADE_STEPS + 3):
		cells[Vector2i(x, 0)] = _cell(["wet"])
	var initial := _state(cells, ReactionCore.MAX_CASCADE_STEPS + 3, 1)
	var result := ReactionCore.calculate(initial, _request("spark", Vector2i.ZERO))
	eq(result["cascade_steps"], ReactionCore.MAX_CASCADE_STEPS,
			"cascade stops at the hard boundary")
	eq(result["propagation_order"].size(), ReactionCore.MAX_CASCADE_STEPS,
			"no more cells are visited than the boundary")
	ok(result["cascade_limited"], "truncation is explicit")
	eq(result["canceled_effects"][-1], {
		"cell": Vector2i(ReactionCore.MAX_CASCADE_STEPS, 0),
		"effect": "spark", "reason": "cascade_limit",
	}, "the first unprocessed effect is reported")


func test_invalid_verb_is_neutral_and_non_mutating() -> void:
	var initial := _state({Vector2i(2, 2): _cell(["soil"])})
	var result := ReactionCore.calculate(initial, _request("teleport", Vector2i(2, 2)))
	not_ok(result["valid"], "unknown verb is rejected")
	eq(result["error"], "invalid_verb", "error is data-shaped")
	eq(result["changed_cells"], [], "invalid verb changes no cells")
	eq(result["propagation_order"], [], "invalid verb propagates nowhere")
	eq(result["state_after"], initial, "invalid verb returns an unchanged candidate")


func test_invalid_target_and_air_direction_fail_closed() -> void:
	var initial := _state({Vector2i(2, 2): _cell(["smoke"])})
	var missing := ReactionCore.calculate(initial, _request("grow", Vector2i(3, 3)))
	not_ok(missing["valid"], "a missing target cell is rejected")
	eq(missing["error"], "target_cell_missing", "missing target error is explicit")
	eq(missing["state_after"], initial, "missing target cannot create hidden state")
	var diagonal := ReactionCore.calculate(initial,
			_request("air", Vector2i(2, 2), "exploration", Vector2i(1, 1)))
	not_ok(diagonal["valid"], "diagonal air direction is rejected")
	eq(diagonal["error"], "invalid_direction", "air requires one cardinal direction")


func test_repeat_application_is_bounded_and_deterministic() -> void:
	var initial := _state({Vector2i(2, 2): _cell(["soil"])})
	var state := initial
	for expected_strength in [1, 2, 3, 3]:
		var result := ReactionCore.calculate(state, _request("grow", Vector2i(2, 2)))
		eq(result["state_after"]["cells"][Vector2i(2, 2)]["statuses"]["vine_strength"],
				expected_strength, "grow strength caps deterministically at 3")
		state = result["state_after"]
	var water_once := ReactionCore.calculate(state, _request("water", Vector2i(2, 2)))
	var water_twice := ReactionCore.calculate(water_once["state_after"],
			_request("water", Vector2i(2, 2)))
	eq(water_twice["state_after"], water_once["state_after"],
			"repeat water refreshes to the same exact state rather than stacking")


func test_production_core_parity() -> void:
	# S-011/TK-001: one engine, one script. The gray-box room logic (the
	# S-002 accepted consumer) must load the exact production core, the
	# retired dev path must stay gone, and a golden fire-on-vine reaction
	# must produce the exact accepted result shape through the promoted path.
	not_ok(ResourceLoader.exists(RETIRED_DEV_PATH),
			"the retired dev copy is gone")
	var room_logic: GDScript = load("res://scripts/dev/reaction_room_logic.gd")
	not_null(room_logic, "gray-box room logic still loads")
	if room_logic != null:
		eq(room_logic.get_script_constant_map().get("ReactionCore"),
				ReactionCore,
				"the gray-box consumer routes through the production core")
	var state := {"width": 3, "height": 1, "cells": {
		Vector2i(0, 0): {"tags": [], "statuses": {}},
		Vector2i(1, 0): {"tags": ["vine"], "statuses": {"vine_strength": 1}},
		Vector2i(2, 0): {"tags": [], "statuses": {}},
	}}
	var result: Dictionary = ReactionCore.calculate(state,
			{"verb": "fire", "target": Vector2i(1, 0),
			"context": "exploration"})
	eq(result["valid"], true, "golden request valid through the promoted core")
	ok(result["state_after"]["cells"][Vector2i(1, 0)]["tags"].has("fire"),
			"burned vine catches fire (golden parity)")
	ok(result["state_after"]["cells"][Vector2i(1, 0)]["tags"].has("smoke"),
			"burned vine smokes (golden parity)")
	eq(result["damage"], [{"cell": Vector2i(1, 0), "amount": 2,
			"kind": "fire"}], "exact fire damage unchanged")
	eq(state["cells"][Vector2i(1, 0)]["tags"], ["vine"],
			"preview never mutates caller state")
