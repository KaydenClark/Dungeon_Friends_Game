class_name GameState
extends Resource
## The whole mutable session in one serializable Resource (T-036, Phase 3;
## BLUEPRINT Architecture: GameState is a Resource held by SceneManager, "which makes
## save/load trivial"). Party-shaped from day one - dictionaries keyed by
## character id - so the Phase 5 party system lands without a save-schema
## bump; today the roster is just the hero.
##
## SceneManager exposes hero_hp/total_xp/inventory/flags as forwarding
## properties, so call sites read naturally while this Resource stays the
## single source of truth (and the thing T-037's SaveData serializes).

## "companion_test" is the D-013 placeholder party member (2026-07-08,
## Kayden: "give me a test companion for now") - it exists so Phase 4's
## multi-unit combat is real before Phase 5 recruitment replaces it.
@export var party_roster: Array[String] = ["hero", "companion_test"]
@export var party_levels: Dictionary = {"hero": 1, "companion_test": 1}
@export var party_xp: Dictionary = {"hero": 0, "companion_test": 0}
@export var party_hp: Dictionary = {}
## {character_id: current MP} - lazily seeded to max at combat start.
@export var party_mp: Dictionary = {}
## {item_id: qty} (T-034). Key items and equipment never stack (qty stays 1);
## consumables increment. Write through SceneManager.add_item()/remove_item().
@export var inventory: Dictionary = {}
## Durable world facts: doors opened, chests looted, dialogue beats seen.
@export var flags: Dictionary = {}
## T-072's compact deterministic authored-arena selector payload. It remains
## empty until the first encounter draw, keeping version-1 saves compatible.
@export var arena_selector_state: Dictionary = {}
## S-010/TK-003 (D-029/D-037): the selected exploration formation identity.
## Serialized with saves; pre-TK-003 saves omit it and default to "line".
@export var party_formation: String = "line"
## S-003 (D-028): {world_key: {encounter_id: true}}. A resolved encounter
## never respawns on room rebuild or load; world_key is the room's stable
## level_path#level_name identity.
@export var resolved_encounters: Dictionary = {}
## S-003 (D-031): {world_key: {"x,y": {"tags": [...], "statuses": {...}}}}.
## The room's material truth as of its last committed reaction, serialized
## JSON-safe. Loading is fail-closed: an invalid entry is ignored wholesale
## and the room keeps its authored state.
@export var world_materials: Dictionary = {}
## S-013 (D-028/D-043): one-shot finite reward accounting. {source_id: true}
## - a claimed source (encounter victory, quest, discovery) can never pay
## again, in this session or any save.
@export var reward_ledger: Dictionary = {}
## The currently controlled roster member ("" = the roster's first member).
## Session-only authority: rooms read it so a leader switch survives room
## changes and defeat respawns; it deliberately stays out of the save schema
## (loading resumes control with the roster leader).
@export var party_leader: String = ""
