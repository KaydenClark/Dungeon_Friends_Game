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
## Optional since T-072. SCHEMA_VERSION stays at 1 because version-1 saves
## simply omit this field and resume with a fresh deterministic selector.
var arena_selector_state: Dictionary = {}
## Optional since S-010/TK-003; older saves omit it and default to "line".
var party_formation := "line"
## Optional since S-003; older saves omit both and default to empty (no
## resolved encounters, authored material state everywhere).
var resolved_encounters: Dictionary = {}
var world_materials: Dictionary = {}
var reward_ledger: Dictionary = {}


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
		"arena_selector_state": arena_selector_state.duplicate(true),
		"party_formation": party_formation,
		"resolved_encounters": resolved_encounters.duplicate(true),
		"world_materials": world_materials.duplicate(true),
		"reward_ledger": reward_ledger.duplicate(true),
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
	# Read the default-guarded value, not d["flags"]: a payload missing the
	# key entirely used to crash here (found by the S-010/TK-003 legacy-save
	# test), violating the tolerant-load rule.
	var raw_flags: Variant = d.get("flags", {})
	if raw_flags is Dictionary:
		out.flags = raw_flags
	var raw_selector_state: Variant = d.get("arena_selector_state", {})
	if raw_selector_state is Dictionary:
		var selector_state: Dictionary = raw_selector_state
		out.arena_selector_state = selector_state.duplicate(true)
	out.party_formation = str(d.get("party_formation", "line"))
	var raw_resolved: Variant = d.get("resolved_encounters", {})
	if raw_resolved is Dictionary:
		out.resolved_encounters = (raw_resolved as Dictionary).duplicate(true)
	var raw_materials: Variant = d.get("world_materials", {})
	if raw_materials is Dictionary:
		out.world_materials = (raw_materials as Dictionary).duplicate(true)
	var raw_ledger: Variant = d.get("reward_ledger", {})
	if raw_ledger is Dictionary:
		out.reward_ledger = (raw_ledger as Dictionary).duplicate(true)
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
	s.arena_selector_state = arena_selector_state.duplicate(true)
	s.party_formation = party_formation
	s.resolved_encounters = resolved_encounters.duplicate(true)
	s.world_materials = world_materials.duplicate(true)
	s.reward_ledger = reward_ledger.duplicate(true)
	return s


static func _int_values(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			var v: Variant = raw[k]
			out[k] = int(v) if v is float else v
	return out
