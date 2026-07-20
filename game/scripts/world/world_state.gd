extends RefCounted
## S-009/TK-001: the neutral production world-state contract (D-024/D-025).
##
## One typed, serializable snapshot owns everything the v2 systems share:
## orthogonal cells (geometry + integer elevation + material tags/statuses),
## neutral actor occupancy, party identity, stable encounter IDs, and the
## in-room encounter lifecycle. Formations (S-010), reactions (S-011), combat
## (S-012), and persistence (S-003) all graduate onto this seam instead of
## keeping private copies of the prototype state.
##
## Contract rules pinned by tests/test_world_state.gd:
## - validate()/from_dict() fail closed with a named error; nothing is guessed.
## - to_dict() exports a deep, deterministically ordered copy (value object).
## - snapshot_room_grid() carries existing geometry over without inventing
##   material or elevation data (defaults are explicit zeros/empties).
## - reaction_state() projects exactly the {width, height, cells} shape
##   ReactionCore.calculate consumes; commit_reaction() writes material state
##   back without touching geometry.
## - begin/resolve encounter transitions are pure mode/bookkeeping changes:
##   cells, actors, and party identity stay continuous (D-025), and resolved
##   encounters stay resolved (D-028).

const MODES := ["exploration", "encounter"]
const ACTOR_KINDS := ["party", "enemy", "npc", "object"]
const ENCOUNTER_STATUSES := ["unresolved", "active", "resolved"]
const CELL_KEYS := ["blocked", "pit", "elevation", "tags", "statuses"]

var width := 0
var height := 0
var cells := {}        # Vector2i -> {blocked, pit, elevation, tags, statuses}
var actors := {}       # String id -> {kind, cell}
var party := {"leader": "", "members": []}
var encounters := {}   # String id -> {status, cells}
var mode := "exploration"
var active_encounter := ""


## Returns "" for a valid snapshot dictionary, or the first named error.
## Every consumer treats a non-empty return as a hard failure (fail closed).
static func validate(data: Dictionary) -> String:
	if not data.get("width") is int or not data.get("height") is int \
			or int(data["width"]) <= 0 or int(data["height"]) <= 0:
		return "invalid_dimensions"
	if not data.get("cells") is Dictionary:
		return "invalid_cells"
	var w := int(data["width"])
	var h := int(data["height"])
	for key in data["cells"]:
		if not key is Vector2i:
			return "invalid_cell_key"
		if key.x < 0 or key.y < 0 or key.x >= w or key.y >= h:
			return "cell_out_of_bounds"
		if _cell_error(data["cells"][key]) != "":
			return _cell_error(data["cells"][key])
	if not data.get("actors") is Dictionary:
		return "invalid_actors"
	var occupied := {}
	for id in data["actors"]:
		if not id is String or id == "":
			return "invalid_actor_id"
		var actor: Variant = data["actors"][id]
		if not actor is Dictionary or not actor.get("cell") is Vector2i \
				or not ACTOR_KINDS.has(actor.get("kind")):
			return "invalid_actor_data"
		var cell: Vector2i = actor["cell"]
		if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
			return "actor_out_of_bounds"
		if occupied.has(cell):
			return "actor_cell_collision"
		occupied[cell] = true
	var party_error := _party_error(data)
	if party_error != "":
		return party_error
	if not data.get("encounters") is Dictionary:
		return "invalid_encounters"
	for id in data["encounters"]:
		if not id is String or id == "":
			return "invalid_encounter_id"
		var enc: Variant = data["encounters"][id]
		if not enc is Dictionary or not enc.get("cells") is Array:
			return "invalid_encounter_data"
		if not ENCOUNTER_STATUSES.has(enc.get("status")):
			return "invalid_encounter_status"
		for cell in enc["cells"]:
			if not cell is Vector2i or cell.x < 0 or cell.y < 0 \
					or cell.x >= w or cell.y >= h:
				return "invalid_encounter_data"
	if not MODES.has(data.get("mode")):
		return "invalid_mode"
	var active: Variant = data.get("active_encounter")
	if not active is String:
		return "invalid_active_encounter"
	if active != "" and not data["encounters"].has(active):
		return "active_encounter_missing"
	if data["mode"] == "encounter" and active == "":
		return "active_encounter_missing"
	if data["mode"] == "exploration" and active != "":
		return "active_without_encounter_mode"
	return ""


static func _cell_error(cell: Variant) -> String:
	if not cell is Dictionary or cell.size() != CELL_KEYS.size():
		return "invalid_cell_data"
	if not cell.get("blocked") is bool or not cell.get("pit") is bool \
			or not cell.get("elevation") is int \
			or not cell.get("tags") is Array \
			or not cell.get("statuses") is Dictionary:
		return "invalid_cell_data"
	for tag in cell["tags"]:
		if not tag is String:
			return "invalid_cell_data"
	return ""


static func _party_error(data: Dictionary) -> String:
	var p: Variant = data.get("party")
	if not p is Dictionary or not p.get("leader") is String \
			or not p.get("members") is Array:
		return "invalid_party"
	var members: Array = p["members"]
	if members.is_empty():
		return "" if p["leader"] == "" else "leader_not_member"
	var seen := {}
	for member in members:
		if not member is String or seen.has(member):
			return "invalid_party"
		seen[member] = true
		if not data["actors"].has(member):
			return "member_missing_actor"
		if data["actors"][member]["kind"] != "party":
			return "member_not_party"
	if not members.has(p["leader"]):
		return "leader_not_member"
	return ""


## Builds a WorldState from a snapshot dictionary, or returns null when the
## snapshot is invalid. Never partially constructs.
static func from_dict(data: Dictionary) -> RefCounted:
	if validate(data) != "":
		return null
	var state := new()
	state.width = int(data["width"])
	state.height = int(data["height"])
	state.cells = data["cells"].duplicate(true)
	state.actors = data["actors"].duplicate(true)
	state.party = data["party"].duplicate(true)
	state.encounters = data["encounters"].duplicate(true)
	state.mode = str(data["mode"])
	state.active_encounter = str(data["active_encounter"])
	return state


## Deep, deterministically ordered export. Mutating the returned dictionary
## never affects this state.
func to_dict() -> Dictionary:
	var out_cells := {}
	for cell in _sorted_cells(cells.keys()):
		out_cells[cell] = cells[cell].duplicate(true)
	var out_actors := {}
	for id in _sorted_ids(actors.keys()):
		out_actors[id] = actors[id].duplicate(true)
	var out_encounters := {}
	for id in _sorted_ids(encounters.keys()):
		out_encounters[id] = encounters[id].duplicate(true)
	return {
		"width": width,
		"height": height,
		"cells": out_cells,
		"actors": out_actors,
		"party": party.duplicate(true),
		"encounters": out_encounters,
		"mode": mode,
		"active_encounter": active_encounter,
	}


## Neutral default cell: open floor at elevation 0 with no material state.
## These are explicit defaults, not invented data - LDtk authoring (TK-002)
## is the only source of real elevation/material values.
static func default_cell() -> Dictionary:
	return {"blocked": false, "pit": false, "elevation": 0,
			"tags": [], "statuses": {}}


## Snapshot an existing production RoomGrid's geometry and occupancy into the
## neutral contract shape. actor_map optionally names occupant nodes
## ({node: {"id": ..., "kind": ...}}); unmapped occupants get deterministic
## object ids in cell order. No material or elevation data is invented: the
## grid's authored elevation/materials stores (TK-002) are the only source,
## and they stay empty for rooms authored without those layers.
static func snapshot_room_grid(grid: RoomGrid, actor_map := {}) -> Dictionary:
	var out_cells := {}
	for cell in _sorted_cells(grid.blocked.keys()):
		var data := default_cell()
		data["blocked"] = true
		out_cells[cell] = data
	for cell in _sorted_cells(grid.pits.keys()):
		var data: Dictionary = out_cells.get(cell, default_cell())
		data["pit"] = true
		out_cells[cell] = data
	for cell in _sorted_cells(grid.elevation.keys()):
		var data: Dictionary = out_cells.get(cell, default_cell())
		data["elevation"] = int(grid.elevation[cell])
		out_cells[cell] = data
	for cell in _sorted_cells(grid.materials.keys()):
		var data: Dictionary = out_cells.get(cell, default_cell())
		data["tags"] = grid.materials[cell].duplicate()
		out_cells[cell] = data
	var out_actors := {}
	var auto_index := 0
	for cell in _sorted_cells(grid.occupants.keys()):
		var node: Node2D = grid.occupants[cell]
		var mapping: Dictionary = actor_map.get(node, {})
		var id := str(mapping.get("id", ""))
		if id == "":
			id = "object_%d" % auto_index
			auto_index += 1
		out_actors[id] = {"kind": str(mapping.get("kind", "object")),
				"cell": cell}
	return {
		"width": grid.width,
		"height": grid.height,
		"cells": out_cells,
		"actors": out_actors,
		"party": {"leader": "", "members": []},
		"encounters": {},
		"mode": "exploration",
		"active_encounter": "",
	}


## S-009/TK-002 fail-closed production adapter: one LDtk-authored room in,
## either a fully valid neutral snapshot or {"error": <named_error>} out -
## never a half-guessed state. Actors are keyed deterministically (the player
## as the single-member production party until TK-003 graduates followers,
## NPCs by cell, enemies by their stable encounter id, everything else by
## snapshot_room_grid's object ids). Encounter records come from the authored
## identities: a live enemy's encounter is unresolved at its current cell; a
## defeated one is resolved at its authored cell (D-028 groundwork).
static func snapshot_ldtk_room(room: LdtkRoom) -> Dictionary:
	if not room.authoring_errors.is_empty():
		return {"error": str(room.authoring_errors[0])}
	var actor_map := {}
	var live_enemies := {}
	for cell in _sorted_cells(room.occupants.keys()):
		var node: Node2D = room.occupants[cell]
		if node is Player:
			actor_map[node] = {"id": "player", "kind": "party"}
		elif node is OverworldEnemy:
			if node.world_encounter_id == "":
				return {"error": "enemy_without_encounter_id:%s" % cell}
			actor_map[node] = {"id": node.world_encounter_id, "kind": "enemy"}
			live_enemies[node.world_encounter_id] = cell
		elif node is NPC:
			actor_map[node] = {"id": "npc_%d_%d" % [cell.x, cell.y],
					"kind": "npc"}
	var data := snapshot_room_grid(room, actor_map)
	# Defense in depth: every occupant must survive as exactly one actor. A
	# reserved-id collision (e.g. an authored UniqueId of "player" or an NPC
	# cell id) would silently overwrite an actor in the keyed dictionary.
	if data["actors"].size() != room.occupants.size():
		return {"error": "actor_id_collision"}
	if actor_map.values().any(func(m): return m["id"] == "player"):
		data["party"] = {"leader": "player", "members": ["player"]}
	var out_encounters := {}
	for id in _sorted_ids(room.authored_encounters.keys()):
		if live_enemies.has(id):
			out_encounters[id] = {"status": "unresolved",
					"cells": [live_enemies[id]]}
		else:
			out_encounters[id] = {"status": "resolved",
					"cells": [room.authored_encounters[id]]}
	data["encounters"] = out_encounters
	var error := validate(data)
	if error != "":
		return {"error": error}
	return data


## Projects exactly the state shape ReactionCore.calculate consumes. The
## projection is a deep copy: previewing a reaction never mutates this state.
func reaction_state() -> Dictionary:
	var out_cells := {}
	for cell in _sorted_cells(cells.keys()):
		out_cells[cell] = {"tags": cells[cell]["tags"].duplicate(),
				"statuses": cells[cell]["statuses"].duplicate(true)}
	return {"width": width, "height": height, "cells": out_cells}


## Commits a calculated ReactionCore result's material changes back into the
## snapshot. Only tags/statuses change; geometry, elevation, actors, party,
## and encounter bookkeeping are untouched. Fails closed on invalid results.
func commit_reaction(result: Dictionary) -> String:
	if not result.get("valid", false) \
			or not result.get("resulting_cells") is Array:
		return "invalid_reaction_result"
	for entry in result["resulting_cells"]:
		if not entry is Dictionary or not entry.get("cell") is Vector2i:
			return "invalid_reaction_result"
		var cell: Vector2i = entry["cell"]
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			return "invalid_reaction_result"
		var data: Dictionary = cells.get(cell, default_cell())
		data["tags"] = entry.get("tags", []).duplicate()
		data["statuses"] = entry.get("statuses", {}).duplicate(true)
		cells[cell] = data
	return ""


## Enters encounter mode for a known, unresolved encounter. Pure bookkeeping:
## the room, cells, actors, and party stay exactly as they are (D-025).
func begin_encounter(encounter_id: String) -> String:
	if mode != "exploration":
		return "already_in_encounter"
	if not encounters.has(encounter_id):
		return "unknown_encounter"
	if encounters[encounter_id]["status"] == "resolved":
		return "encounter_already_resolved"
	encounters[encounter_id]["status"] = "active"
	mode = "encounter"
	active_encounter = encounter_id
	return ""


## Resolves the active encounter and returns to exploration. Resolved
## encounters stay resolved (D-028) - begin_encounter refuses them forever.
func resolve_active_encounter() -> String:
	if mode != "encounter" or active_encounter == "":
		return "no_active_encounter"
	encounters[active_encounter]["status"] = "resolved"
	active_encounter = ""
	mode = "exploration"
	return ""


static func _sorted_cells(keys: Array) -> Array:
	var sorted := keys.duplicate()
	sorted.sort_custom(func(a, b):
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return sorted


static func _sorted_ids(keys: Array) -> Array:
	var sorted := keys.duplicate()
	sorted.sort()
	return sorted
