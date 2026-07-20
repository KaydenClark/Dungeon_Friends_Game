extends RefCounted
## S-012/TK-001 promoted this pure intent/preview domain unchanged from the
## T-092/T-097 dev spike into the production world namespace; the suite pins
## the full contract at the production path plus zero-RNG structure, and dev
## consumers route through this exact script - no divergent copy.
##
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
## T-097 recut (SOL_FABLE_PIVOT_FIX_HANDOFF.md):
## - Plan entries are {verb, target_id}: the verb is public (the only thing
##   the future UI may serialize - see future_verbs()); target_id is private
##   planning context, never shown.
## - Ordinary refill (refill_plan) preserves already-telegraphed verbs and
##   appends only the newly exposed horizon step. When the plan's internal
##   target dies/changes or the head verb becomes illegal
##   (plan_needs_rebuild), the caller rebuilds the whole horizon.
## - An empty move is invalid and can never silently consume a round.
## - guarded_cells: a generic, data-shaped effect (state["effects"]) - facing
##   defines the front/front-left/front-right protected cells for an exact
##   duration; it intercepts a line-shaped spit before allies behind it, with
##   preview == resolution. Gray-box for T-093 to absorb; not a friend kit.
##
## State shape (plain dicts, no Nodes):
##   state = {width, height, blocked: {Vector2i: true},
##            units: {id: {id, cell, hp, max_hp, atk, df, side, statuses}},
##            effects: [{kind, owner, cells, rounds}]}  (optional)
##   plan entry = {verb: String, target_id: String}     (target_id is private)
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

## Deterministic plan from the current state: a pure function of the distance
## to the nearest party unit. Entries carry the public verb plus the private
## planning context they were built around. Same state -> same plan, always.
static func make_plan(state: Dictionary, enemy_id: String) -> Array:
	var enemy: Dictionary = state["units"][enemy_id]
	var target := nearest_party_unit(state, enemy["cell"])
	var target_id: String = "" if target.is_empty() else str(target["id"])
	var verbs: Array = ["move", "move", "move"]
	if not target.is_empty():
		var d := manhattan(enemy["cell"], target["cell"])
		if d >= 4:
			verbs = ["move", "move", "spit"]
		elif d >= 2:
			verbs = ["move", "spit", "slam"]
		else:
			verbs = ["slam", "spit", "move"]
	var plan: Array = []
	for verb: String in verbs:
		plan.append({"verb": verb, "target_id": target_id})
	return plan


## The ONLY thing the future-intent UI may serialize: the verb sequence.
## Private context (targets, destinations, cells) never leaves the plan.
static func future_verbs(plan: Array) -> Array:
	var verbs: Array = []
	for entry: Dictionary in plan:
		verbs.append(str(entry["verb"]))
	return verbs


## Ordinary rolling refill: already-telegraphed entries stay untouched (they
## remain trustworthy) and only the newly exposed horizon step is appended,
## taken from a fresh plan for the state as it now stands.
static func refill_plan(state: Dictionary, enemy_id: String, plan: Array) -> Array:
	var next := plan.duplicate(true)
	var fresh := make_plan(state, enemy_id)
	while next.size() < PLAN_LENGTH:
		next.append(fresh[next.size()])
	return next


## True when the plan can no longer be trusted and the caller must rebuild the
## whole horizon from current state: its internal target died or is no longer
## the nearest unit, or the current head verb became illegal.
static func plan_needs_rebuild(state: Dictionary, enemy_id: String, plan: Array) -> bool:
	if plan.is_empty():
		return true
	var head: Dictionary = plan[0]
	var target_id := str(head.get("target_id", ""))
	if target_id == "" or not state["units"].has(target_id) \
			or int(state["units"][target_id]["hp"]) <= 0:
		return true
	var enemy: Dictionary = state["units"][enemy_id]
	var nearest := nearest_party_unit(state, enemy["cell"])
	if nearest.is_empty() or str(nearest["id"]) != target_id:
		return true
	return not _verb_legal(state, enemy_id, str(head["verb"]))


## Legality of a verb in the current state without mutating anything - the
## pure check behind plan_needs_rebuild (declare() is the mutating twin).
static func _verb_legal(state: Dictionary, enemy_id: String, verb: String) -> bool:
	var enemy: Dictionary = state["units"][enemy_id]
	var target := nearest_party_unit(state, enemy["cell"])
	if target.is_empty():
		return false
	match verb:
		"move":
			return _move_path(state, enemy_id, target["cell"]).size() > 0
		"spit":
			return _line_cells(state, enemy["cell"], target["cell"]).size() > 0
		"slam":
			return manhattan(enemy["cell"], target["cell"]) == 1
	return false


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
			if path.is_empty():
				# T-097: an empty move is invalid - it can never silently
				# consume a round. The caller replans instead.
				return {"invalid": true}
			enemy["cell"] = path[path.size() - 1]
			return {"owner": enemy_id, "verb": "move", "path": path,
					"cells": [], "damage": 0, "status": {}, "canceled": false}
		"spit":
			var cells := _line_cells(state, enemy["cell"], target["cell"])
			if cells.is_empty():
				return {"invalid": true}
			return {"owner": enemy_id, "verb": "spit",
					"dir": _axis_dir_toward(enemy["cell"], target["cell"]),
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
			# The line stops at the first guarded cell or the first body:
			# nearer cells shield farther ones, and a guarded cell intercepts
			# even the unit standing on it.
			for c: Vector2i in intent["cells"]:
				var guard := _guard_covering(state, c)
				if not guard.is_empty():
					results.append({"id": guard["owner"], "blocked": true,
							"damage": 0, "status": {}})
					break
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
		if r.get("blocked", false):
			continue  # a guard's block reports, but nothing is applied
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


## --- guarded_cells (T-097 gray-box - generic and data-shaped so the T-093
## --- material/effect vocabulary can absorb it; not a dragon or friend kit) ---

## Facing defines the protected cells: front, front-left, front-right.
static func guard_cells(cell: Vector2i, facing: Vector2i) -> Array:
	var front := cell + facing
	var left := Vector2i(facing.y, -facing.x)
	return [front, front + left, front - left]


## Raise a guard for exactly `rounds` environment ticks. Effects live as
## plain data on the state so preview/resolve/tick all read the same source.
static func apply_guard(state: Dictionary, owner_id: String, facing: Vector2i,
		rounds: int) -> Dictionary:
	var owner: Dictionary = state["units"][owner_id]
	var effect := {"kind": "guarded_cells", "owner": owner_id,
			"cells": guard_cells(owner["cell"], facing), "rounds": rounds}
	if not state.has("effects"):
		state["effects"] = []
	state["effects"].append(effect)
	return effect


## First active guard effect covering the cell (deterministic: application
## order). Empty when the cell is unguarded.
static func _guard_covering(state: Dictionary, c: Vector2i) -> Dictionary:
	for effect: Dictionary in state.get("effects", []):
		if effect.get("kind", "") == "guarded_cells" \
				and int(effect.get("rounds", 0)) > 0 \
				and (effect.get("cells", []) as Array).has(c):
			return effect
	return {}


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
		# S-013 (D-033): deterministic friend passives ride the same exact
		# tick as every other duration - no randomness, no hidden timing.
		if (unit.get("passives", []) as Array).has("verdant_mender") \
				and int(unit["hp"]) > 0 and int(unit["hp"]) < int(unit["max_hp"]):
			unit["hp"] = int(unit["hp"]) + 1
			results.append({"id": id, "heal": 1, "source": "verdant_mender"})
		if int(unit["statuses"].get("burn", 0)) > 0:
			unit["hp"] = int(unit["hp"]) - BURN_TICK_DAMAGE
			unit["statuses"]["burn"] = int(unit["statuses"]["burn"]) - 1
			results.append({"id": id, "damage": BURN_TICK_DAMAGE,
					"source": "burn"})
			if int(unit["statuses"]["burn"]) <= 0:
				unit["statuses"].erase("burn")
	# Data-shaped effects (guarded_cells) expire on exact durations too.
	if state.has("effects"):
		var kept: Array = []
		for effect: Dictionary in state["effects"]:
			effect["rounds"] = int(effect.get("rounds", 0)) - 1
			if int(effect["rounds"]) > 0:
				kept.append(effect)
		state["effects"] = kept
	return results


## --- helpers -----------------------------------------------------------------

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Living party-side unit ids, sorted - the round loop iterates these instead
## of any hard-coded roster (T-097: all visible members act, in any order).
static func party_ids(state: Dictionary) -> Array:
	var ids: Array = []
	var all: Array = state["units"].keys()
	all.sort()
	for id: String in all:
		var unit: Dictionary = state["units"][id]
		if unit["side"] == "party" and int(unit["hp"]) > 0:
			ids.append(id)
	return ids


## The spit's affected line: cells outward from `from` toward `toward` until
## bounds/terrain stop it. Shared by declare() and _verb_legal().
static func _line_cells(state: Dictionary, from: Vector2i, toward: Vector2i) -> Array:
	var dir := _axis_dir_toward(from, toward)
	var cells: Array = []
	for step in range(1, SPIT_RANGE + 1):
		var c: Vector2i = from + dir * step
		if not _in_bounds(state, c) or state["blocked"].has(c):
			break
		cells.append(c)
	return cells


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
