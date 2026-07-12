extends RefCounted
## T-092 pivot spike: deterministic intent-round combat core (D-026/D-027).
## Pure, scene-independent logic so the preview=result contract is directly
## red/green testable (tests/test_intent_logic.gd). Spike code - graduating
## it into production architecture is its own explicit decision.
##
## The model (Kayden, 2026-07-11):
## - The enemy keeps a rolling plan of the next PLAN_LENGTH verbs, replanned
##   from scratch whenever the current verb is impossible; the plan is a pure
##   function of the battle state - no randomness anywhere (D-026).
## - Future plan steps telegraph the VERB ONLY (not where or to whom); the
##   current action declares full detail: target cells, exact damage, exact
##   status. Player-side previews always show full detail.
## - Attacks hit whoever remains in the affected cells at resolve time.
##   Moving out dodges; a body in the line blocks; stunning or pushing the
##   enemy cancels its declared intention.
## - Status durations are exact: burn deals exactly 1 damage for exactly its
##   duration in environment ticks; stun skips exactly its duration.
##
## State shape (plain dicts, no Nodes):
##   state = {width, height, blocked: {Vector2i: true},
##            units: {id: {id, cell, hp, max_hp, atk, df, side, statuses}}}
##   intent = {owner, verb, cells, damage, status, canceled}  (attacks)
##          | {owner, verb: "move", path}                     (executed move)
##          | {owner, verb: "stunned", cells: [], canceled: true}

const PLAN_LENGTH := 3
const SPIT_DAMAGE := 3
const SPIT_RANGE := 3
const SPIT_BURN_ROUNDS := 2
const SLAM_DAMAGE := 4
const MOVE_STEPS := 2
const BURN_TICK_DAMAGE := 1


## --- plan --------------------------------------------------------------------

## Deterministic verb plan from the current state: pure function of the
## distance to the nearest party unit. Same state -> same plan, always.
static func make_plan(state: Dictionary, enemy_id: String) -> Array:
	var enemy: Dictionary = state["units"][enemy_id]
	var target := nearest_party_unit(state, enemy["cell"])
	if target.is_empty():
		return ["move", "move", "move"]
	var d := manhattan(enemy["cell"], target["cell"])
	if d >= 4:
		return ["move", "move", "spit"]
	if d >= 2:
		return ["move", "spit", "slam"]
	return ["slam", "spit", "move"]


## Rolling refill: consume the executed verb and keep PLAN_LENGTH visible by
## appending the head of a fresh plan for the state as it now stands.
static func refill_plan(state: Dictionary, enemy_id: String, plan: Array) -> Array:
	var next := plan.duplicate()
	while next.size() < PLAN_LENGTH:
		next.append(make_plan(state, enemy_id)[next.size() % PLAN_LENGTH])
	return next


## --- declare phase -------------------------------------------------------------

## Turn the plan's current verb into a concrete intention. Moves execute
## immediately ("enemies move or declare their plans"); attacks lock their
## affected cells, exact damage, and exact status for the player to see.
## Returns {"invalid": true} when the verb is impossible right now - the
## caller must replan. A stunned enemy declares nothing this round.
static func declare(state: Dictionary, enemy_id: String, verb: String) -> Dictionary:
	var enemy: Dictionary = state["units"][enemy_id]
	if int(enemy["statuses"].get("stun", 0)) > 0:
		# Stun is consumed here, not at the environment tick: "stun N" skips
		# exactly N declare phases no matter when in a round it was applied.
		enemy["statuses"]["stun"] = int(enemy["statuses"]["stun"]) - 1
		if int(enemy["statuses"]["stun"]) <= 0:
			enemy["statuses"].erase("stun")
		return {"owner": enemy_id, "verb": "stunned", "cells": [], "damage": 0,
				"status": {}, "canceled": true}
	var target := nearest_party_unit(state, enemy["cell"])
	if target.is_empty():
		return {"invalid": true}
	match verb:
		"move":
			var path := _move_path(state, enemy_id, target["cell"])
			if path.size() > 0:
				enemy["cell"] = path[path.size() - 1]
			return {"owner": enemy_id, "verb": "move", "path": path,
					"cells": [], "damage": 0, "status": {}, "canceled": false}
		"spit":
			var dir := _axis_dir_toward(enemy["cell"], target["cell"])
			var cells: Array = []
			for step in range(1, SPIT_RANGE + 1):
				var c: Vector2i = enemy["cell"] + dir * step
				if not _in_bounds(state, c) or state["blocked"].has(c):
					break
				cells.append(c)
			if cells.is_empty():
				return {"invalid": true}
			return {"owner": enemy_id, "verb": "spit", "dir": dir,
					"cells": cells, "damage": SPIT_DAMAGE,
					"status": {"burn": SPIT_BURN_ROUNDS}, "canceled": false}
		"slam":
			if manhattan(enemy["cell"], target["cell"]) != 1:
				return {"invalid": true}
			return {"owner": enemy_id, "verb": "slam",
					"cells": [target["cell"]], "damage": SLAM_DAMAGE,
					"status": {}, "canceled": false}
	return {"invalid": true}


## --- preview / resolve: the tested contract -----------------------------------

## What the player is shown for a declared enemy intent, given the CURRENT
## positions: exactly which units would be hit and for how much. resolve()
## against the same state must produce exactly this.
static func preview(state: Dictionary, intent: Dictionary) -> Array:
	if intent.get("canceled", false):
		return []
	var results: Array = []
	match intent.get("verb", ""):
		"spit":
			# The line stops at the first body: nearer cells shield farther ones.
			for c: Vector2i in intent["cells"]:
				var hit := _unit_at(state, c, intent["owner"])
				if not hit.is_empty():
					results.append({"id": hit["id"], "damage": intent["damage"],
							"status": intent["status"].duplicate()})
					break
		"slam":
			for c: Vector2i in intent["cells"]:
				var hit := _unit_at(state, c, intent["owner"])
				if not hit.is_empty():
					results.append({"id": hit["id"], "damage": intent["damage"],
							"status": intent["status"].duplicate()})
	return results


## Commit the declared intent against wherever units NOW stand ("attacks hit
## if their target remains in the affected cells"). Returns the same shape
## preview() returned for this state, and applies it.
static func resolve(state: Dictionary, intent: Dictionary) -> Array:
	var results := preview(state, intent)
	for r: Dictionary in results:
		var unit: Dictionary = state["units"][r["id"]]
		unit["hp"] = int(unit["hp"]) - int(r["damage"])
		for status_name: String in r["status"]:
			unit["statuses"][status_name] = maxi(
					int(unit["statuses"].get(status_name, 0)),
					int(r["status"][status_name]))
	return results


## --- counterplay ----------------------------------------------------------------

## Stunning the enemy cancels its declared intention and costs it exactly
## `rounds` declare phases.
static func stun_enemy(state: Dictionary, intent: Dictionary, rounds := 1) -> void:
	var enemy: Dictionary = state["units"][intent["owner"]]
	enemy["statuses"]["stun"] = rounds
	intent["canceled"] = true


## Push a unit one cell. If the pushed unit owns the given intent, the
## intention is canceled - its locked cells were aimed from a cell it no
## longer occupies. Returns false (and cancels nothing) when the destination
## is not free.
static func push_unit(state: Dictionary, target_id: String, dir: Vector2i,
		intent: Dictionary) -> bool:
	var unit: Dictionary = state["units"][target_id]
	var dest: Vector2i = unit["cell"] + dir
	if not _in_bounds(state, dest) or state["blocked"].has(dest) \
			or not _unit_at(state, dest, target_id).is_empty():
		return false
	unit["cell"] = dest
	if intent.get("owner", "") == target_id:
		intent["canceled"] = true
	return true


## --- player side ------------------------------------------------------------------

## Full-detail player preview: exact damage and the defender's HP after.
## D-026 first-cut formula: max(1, power + atk - def).
static func player_attack_preview(state: Dictionary, attacker_id: String,
		target_id: String, ability: Dictionary) -> Dictionary:
	var attacker: Dictionary = state["units"][attacker_id]
	var target: Dictionary = state["units"][target_id]
	var dmg: int = maxi(1, int(ability.get("power", 0)) + int(attacker["atk"])
			- int(target["df"]))
	return {"damage": dmg, "target_hp_after": int(target["hp"]) - dmg,
			"status": ability.get("status", {}).duplicate()}


## Commit the player attack: applies exactly what the preview said.
static func player_attack_resolve(state: Dictionary, attacker_id: String,
		target_id: String, ability: Dictionary) -> Dictionary:
	var shown := player_attack_preview(state, attacker_id, target_id, ability)
	var target: Dictionary = state["units"][target_id]
	target["hp"] = shown["target_hp_after"]
	for status_name: String in shown["status"]:
		target["statuses"][status_name] = maxi(
				int(target["statuses"].get(status_name, 0)),
				int(shown["status"][status_name]))
	return shown


## --- environment phase ---------------------------------------------------------

## Round-end environmental/status resolution. Burn deals exactly
## BURN_TICK_DAMAGE per tick for exactly its remaining duration. Stun is
## NOT ticked here - declare() consumes it, so "stun N" always skips
## exactly N declare phases. Deterministic order: unit ids sorted.
static func environment_tick(state: Dictionary) -> Array:
	var results: Array = []
	var ids: Array = state["units"].keys()
	ids.sort()
	for id: String in ids:
		var unit: Dictionary = state["units"][id]
		if int(unit["statuses"].get("burn", 0)) > 0:
			unit["hp"] = int(unit["hp"]) - BURN_TICK_DAMAGE
			unit["statuses"]["burn"] = int(unit["statuses"]["burn"]) - 1
			results.append({"id": id, "damage": BURN_TICK_DAMAGE,
					"source": "burn"})
			if int(unit["statuses"]["burn"]) <= 0:
				unit["statuses"].erase("burn")
	return results


## --- helpers -----------------------------------------------------------------

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Nearest living party unit; ties break by cell (y then x) then id so the
## choice is a pure function of state.
static func nearest_party_unit(state: Dictionary, from: Vector2i) -> Dictionary:
	var best := {}
	var ids: Array = state["units"].keys()
	ids.sort()
	for id: String in ids:
		var unit: Dictionary = state["units"][id]
		if unit["side"] != "party" or int(unit["hp"]) <= 0:
			continue
		if best.is_empty():
			best = unit
			continue
		var d := manhattan(from, unit["cell"])
		var bd: int = manhattan(from, best["cell"])
		if d < bd or (d == bd and (unit["cell"].y < best["cell"].y
				or (unit["cell"].y == best["cell"].y
				and unit["cell"].x < best["cell"].x))):
			best = unit
	return best


static func _unit_at(state: Dictionary, c: Vector2i, ignore_id := "") -> Dictionary:
	var ids: Array = state["units"].keys()
	ids.sort()
	for id: String in ids:
		if id == ignore_id:
			continue
		var unit: Dictionary = state["units"][id]
		if int(unit["hp"]) > 0 and unit["cell"] == c:
			return unit
	return {}


static func _in_bounds(state: Dictionary, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 \
			and c.x < int(state["width"]) and c.y < int(state["height"])


## Axis direction toward the target: the larger delta axis wins, ties prefer
## horizontal - deterministic.
static func _axis_dir_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta := to - from
	if absi(delta.x) >= absi(delta.y) and delta.x != 0:
		return Vector2i(signi(delta.x), 0)
	if delta.y != 0:
		return Vector2i(0, signi(delta.y))
	return Vector2i.RIGHT


## Up to MOVE_STEPS greedy steps toward the target without entering blocked
## or occupied cells and never stepping onto the target itself. Primary axis
## first, secondary as fallback - deterministic.
static func _move_path(state: Dictionary, mover_id: String,
		target_cell: Vector2i) -> Array:
	var mover: Dictionary = state["units"][mover_id]
	var at: Vector2i = mover["cell"]
	var path: Array = []
	for _step in MOVE_STEPS:
		if manhattan(at, target_cell) <= 1:
			break
		var stepped := false
		var primary := _axis_dir_toward(at, target_cell)
		var secondary := Vector2i(0, signi(target_cell.y - at.y)) \
				if primary.x != 0 else Vector2i(signi(target_cell.x - at.x), 0)
		for dir: Vector2i in [primary, secondary]:
			if dir == Vector2i.ZERO:
				continue
			var dest := at + dir
			if dest == target_cell:
				continue
			if _in_bounds(state, dest) and not state["blocked"].has(dest) \
					and _unit_at(state, dest, mover_id).is_empty():
				at = dest
				path.append(dest)
				stepped = true
				break
		if not stepped:
			break
	return path
