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
