extends RefCounted
## T-093A shared deterministic material/effect reaction core (D-031).
##
## Both exploration and encounter callers use calculate(). It is deliberately
## preview-first: caller state is never mutated, and state_after is the complete
## candidate a caller may commit after presenting the neutral result data.
## Context is copied into metadata only and never branches reaction rules.
##
## State:
##   {width: int, height: int,
##    cells: {Vector2i: {tags: Array[String], statuses: Dictionary}}}
## Request:
##   {verb: String, target: Vector2i, context: String,
##    direction: Vector2i} # direction is used only by air spreading fire
##
## Propagation is cardinal breadth-first with neighbor priority up, right,
## down, left. Directional air/fire follows the supplied cardinal direction.
## Every cascade stops at MAX_CASCADE_STEPS and reports the first canceled
## continuation; visited sets plus this boundary make loops impossible.

const MAX_CASCADE_STEPS := 32
const MAX_VINE_STRENGTH := 3
const WET_ROUNDS := 2
const FIRE_DAMAGE := 2
const SPARK_DAMAGE := 2
const CARDINALS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const VERBS := ["grow", "fire", "water", "cold", "spark", "air"]


## The single public reaction entry point. This calculates the entire reaction
## without mutating state; committing state_after is intentionally the caller's
## separate responsibility.
static func calculate(state: Dictionary, request: Dictionary) -> Dictionary:
	var result := _empty_result(state, request)
	var error := _validation_error(state, request)
	if error != "":
		result["error"] = error
		return result

	var verb := str(request["verb"])
	if not VERBS.has(verb):
		result["error"] = "invalid_verb"
		return result

	var target: Vector2i = request["target"]
	var state_after: Dictionary = result["state_after"]
	_ensure_cell(state_after, target)
	result["valid"] = true
	result["error"] = ""

	match verb:
		"grow":
			_direct_grow(state_after, target, result)
		"fire":
			_direct_fire(state_after, target, result, "fire")
		"water":
			_direct_water(state_after, target, result)
		"cold":
			_direct_cold(state_after, target, result)
		"spark":
			_conduct_spark(state_after, target, result)
		"air":
			_apply_air(state_after, target, request.get("direction", Vector2i.RIGHT),
					result)

	_finalize_changes(state, result)
	return result


static func _empty_result(state: Dictionary, request: Dictionary) -> Dictionary:
	return {
		"valid": false,
		"error": "invalid_request",
		"metadata": {"context": str(request.get("context", "exploration"))},
		"changed_cells": [],
		"resulting_cells": [],
		"damage": [],
		"hazards": [],
		"propagation_order": [],
		"canceled_effects": [],
		"cascade_steps": 0,
		"cascade_limited": false,
		"state_after": state.duplicate(true),
	}


static func _validation_error(state: Dictionary, request: Dictionary) -> String:
	if not state.has("width") or not state.has("height") or not state.has("cells"):
		return "invalid_state"
	if int(state["width"]) <= 0 or int(state["height"]) <= 0 \
			or not state["cells"] is Dictionary:
		return "invalid_state"
	if not request.has("verb") or not request.has("target") \
			or not request["target"] is Vector2i:
		return "invalid_request"
	if not _in_bounds(state, request["target"]):
		return "target_out_of_bounds"
	if not state["cells"].has(request["target"]):
		return "target_cell_missing"
	if str(request["verb"]) == "air":
		var direction: Variant = request.get("direction", Vector2i.RIGHT)
		if not direction is Vector2i or not CARDINALS.has(direction):
			return "invalid_direction"
	return ""


static func _direct_grow(state: Dictionary, cell: Vector2i,
		result: Dictionary) -> void:
	_visit(result, cell)
	var data: Dictionary = state["cells"][cell]
	_add_tag(data, "vine")
	data["statuses"]["vine_strength"] = mini(MAX_VINE_STRENGTH,
			int(data["statuses"].get("vine_strength", 0)) + 1)


static func _direct_fire(state: Dictionary, cell: Vector2i,
		result: Dictionary, source: String) -> void:
	_visit(result, cell)
	var data: Dictionary = state["cells"][cell]
	var burned := false
	if _remove_tag(data, "vine"):
		data["statuses"].erase("vine_strength")
		result["canceled_effects"].append({"cell": cell, "effect": "vine",
				"reason": "burned"})
		burned = true
	if _remove_tag(data, "flammable"):
		result["canceled_effects"].append({"cell": cell, "effect": "flammable",
				"reason": "burned"})
		burned = true
	if burned or data["tags"].has("fire"):
		_add_tag(data, "fire")
		_add_tag(data, "smoke")
		result["damage"].append({"cell": cell, "amount": FIRE_DAMAGE,
				"kind": source})
		result["hazards"].append({"cell": cell, "kind": "fire",
				"damage": FIRE_DAMAGE})


static func _direct_water(state: Dictionary, cell: Vector2i,
		result: Dictionary) -> void:
	_visit(result, cell)
	var data: Dictionary = state["cells"][cell]
	_add_tag(data, "wet")
	data["statuses"]["wet_rounds"] = WET_ROUNDS
	if data["tags"].has("channel"):
		_add_tag(data, "flooded")


static func _direct_cold(state: Dictionary, cell: Vector2i,
		result: Dictionary) -> void:
	_visit(result, cell)
	var data: Dictionary = state["cells"][cell]
	var froze := false
	if _remove_tag(data, "wet"):
		data["statuses"].erase("wet_rounds")
		result["canceled_effects"].append({"cell": cell, "effect": "wet",
				"reason": "frozen"})
		froze = true
	if _remove_tag(data, "flooded"):
		result["canceled_effects"].append({"cell": cell, "effect": "flooded",
				"reason": "frozen"})
		froze = true
	if froze:
		_add_tag(data, "ice")
		data["statuses"]["frozen"] = true


static func _conduct_spark(state: Dictionary, target: Vector2i,
		result: Dictionary) -> void:
	if not state["cells"][target]["tags"].has("wet"):
		return
	var queue: Array = [target]
	var queued := {target: true}
	while not queue.is_empty() and result["propagation_order"].size() < MAX_CASCADE_STEPS:
		var cell: Vector2i = queue.pop_front()
		_visit(result, cell)
		var data: Dictionary = state["cells"][cell]
		data["statuses"]["electrified"] = true
		result["damage"].append({"cell": cell, "amount": SPARK_DAMAGE,
				"kind": "spark"})
		result["hazards"].append({"cell": cell, "kind": "electrified_water",
				"damage": SPARK_DAMAGE})
		_enqueue_tagged_neighbors(state, cell, "wet", queue, queued)
	_limit_if_needed(result, queue, "spark")


static func _apply_air(state: Dictionary, target: Vector2i, direction: Vector2i,
		result: Dictionary) -> void:
	var target_data: Dictionary = state["cells"][target]
	# Fire takes precedence when a cell also contains its smoke: air feeds the
	# flame in the supplied cardinal direction. A non-burning smoke target uses
	# the connected-smoke clearing rule instead.
	if target_data["tags"].has("fire"):
		_visit(result, target)
		var next := target + direction
		while result["propagation_order"].size() < MAX_CASCADE_STEPS \
				and _in_bounds(state, next) and state["cells"].has(next):
			var data: Dictionary = state["cells"][next]
			if not data["tags"].has("vine") and not data["tags"].has("flammable"):
				break
			_direct_fire(state, next, result, "air_spread_fire")
			next += direction
		if result["propagation_order"].size() >= MAX_CASCADE_STEPS \
				and _in_bounds(state, next) and state["cells"].has(next):
			var pending: Dictionary = state["cells"][next]
			if pending["tags"].has("vine") or pending["tags"].has("flammable"):
				_mark_limit(result, next, "air_spread_fire")
		return

	if not target_data["tags"].has("smoke"):
		return
	var queue: Array = [target]
	var queued := {target: true}
	while not queue.is_empty() and result["propagation_order"].size() < MAX_CASCADE_STEPS:
		var cell: Vector2i = queue.pop_front()
		_visit(result, cell)
		var data: Dictionary = state["cells"][cell]
		_remove_tag(data, "smoke")
		result["canceled_effects"].append({"cell": cell, "effect": "smoke",
				"reason": "cleared_by_air"})
		_enqueue_tagged_neighbors(state, cell, "smoke", queue, queued)
	_limit_if_needed(result, queue, "air_clear_smoke")


static func _enqueue_tagged_neighbors(state: Dictionary, cell: Vector2i,
		tag: String, queue: Array, queued: Dictionary) -> void:
	for direction: Vector2i in CARDINALS:
		var next := cell + direction
		if queued.has(next) or not _in_bounds(state, next) \
				or not state["cells"].has(next):
			continue
		if state["cells"][next]["tags"].has(tag):
			queued[next] = true
			queue.append(next)


static func _limit_if_needed(result: Dictionary, queue: Array,
		effect: String) -> void:
	if not queue.is_empty():
		_mark_limit(result, queue[0], effect)


static func _mark_limit(result: Dictionary, cell: Vector2i,
		effect: String) -> void:
	result["cascade_limited"] = true
	result["canceled_effects"].append({"cell": cell, "effect": effect,
			"reason": "cascade_limit"})


static func _visit(result: Dictionary, cell: Vector2i) -> void:
	if not result["propagation_order"].has(cell):
		result["propagation_order"].append(cell)
		result["cascade_steps"] = result["propagation_order"].size()


static func _finalize_changes(state_before: Dictionary, result: Dictionary) -> void:
	var state_after: Dictionary = result["state_after"]
	for cell: Vector2i in result["propagation_order"]:
		var before: Dictionary = state_before["cells"].get(cell,
				{"tags": [], "statuses": {}})
		var after: Dictionary = state_after["cells"].get(cell,
				{"tags": [], "statuses": {}})
		if before == after:
			continue
		result["changed_cells"].append({"cell": cell,
				"before": before.duplicate(true), "after": after.duplicate(true)})
		result["resulting_cells"].append({"cell": cell,
				"tags": after["tags"].duplicate(),
				"statuses": after["statuses"].duplicate(true)})


static func _ensure_cell(state: Dictionary, cell: Vector2i) -> void:
	if not state["cells"].has(cell):
		state["cells"][cell] = {"tags": [], "statuses": {}}
	else:
		var data: Dictionary = state["cells"][cell]
		if not data.has("tags") or not data["tags"] is Array:
			data["tags"] = []
		if not data.has("statuses") or not data["statuses"] is Dictionary:
			data["statuses"] = {}


static func _add_tag(data: Dictionary, tag: String) -> void:
	if not data["tags"].has(tag):
		data["tags"].append(tag)


static func _remove_tag(data: Dictionary, tag: String) -> bool:
	var index: int = data["tags"].find(tag)
	if index < 0:
		return false
	data["tags"].remove_at(index)
	return true


static func _in_bounds(state: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 \
			and cell.x < int(state["width"]) and cell.y < int(state["height"])
