class_name SaveData
extends RefCounted
## One save file's worth of session (T-037, D-006: saves are JSON under
## user://, so this is deliberately NOT a Resource - .tres stays the format
## for authored data under res://, and JSON loaded from the writable user dir
## can never smuggle in embedded scripts). Wraps the GameState payload plus
## where the player is (map id + cell); the map id resolves back to a room
## through the T-038 registry. No defeated_enemy_ids - D-009 says enemies
## always respawn.

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var current_map := ""
var player_position := Vector2i.ZERO
var party_roster: Array[String] = []
var party_levels: Dictionary = {}
var party_xp: Dictionary = {}
var party_hp: Dictionary = {}
var party_mp: Dictionary = {}
var inventory: Dictionary = {}
var flags: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"current_map": current_map,
		"player_position": {"x": player_position.x, "y": player_position.y},
		"party_roster": party_roster,
		"party_levels": party_levels,
		"party_xp": party_xp,
		"party_hp": party_hp,
		"party_mp": party_mp,
		"inventory": inventory,
		"flags": flags,
	}


## Rebuild from parsed JSON. Returns null when the shape is wrong (the
## tolerant-load rule: a bad file is a warning and a null, never a crash).
## JSON numbers all parse as float, so every numeric payload is re-inted here.
static func from_dict(raw: Variant) -> SaveData:
	if not raw is Dictionary:
		return null
	var d: Dictionary = raw
	if not d.has("schema_version") or not d.has("current_map"):
		return null
	var out := SaveData.new()
	out.schema_version = int(d["schema_version"])
	out.current_map = str(d["current_map"])
	var pos: Variant = d.get("player_position", {})
	if pos is Dictionary:
		out.player_position = Vector2i(int(pos.get("x", 0)), int(pos.get("y", 0)))
	for id in d.get("party_roster", []):
		out.party_roster.append(str(id))
	out.party_levels = _int_values(d.get("party_levels", {}))
	out.party_xp = _int_values(d.get("party_xp", {}))
	out.party_hp = _int_values(d.get("party_hp", {}))
	out.party_mp = _int_values(d.get("party_mp", {}))
	out.inventory = _int_values(d.get("inventory", {}))
	if d.get("flags", {}) is Dictionary:
		out.flags = d["flags"]
	return out


## A fresh GameState carrying this save's payload (the load flow swaps it in
## wholesale, same move as reset_session_state).
func to_game_state() -> GameState:
	var s := GameState.new()
	s.party_roster = party_roster.duplicate()
	s.party_levels = party_levels.duplicate()
	s.party_xp = party_xp.duplicate()
	s.party_hp = party_hp.duplicate()
	s.party_mp = party_mp.duplicate()
	s.inventory = inventory.duplicate()
	s.flags = flags.duplicate()
	return s


static func _int_values(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			var v: Variant = raw[k]
			out[k] = int(v) if v is float else v
	return out
