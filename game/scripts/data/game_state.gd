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

@export var party_roster: Array[String] = ["hero"]
@export var party_levels: Dictionary = {"hero": 1}
@export var party_xp: Dictionary = {"hero": 0}
@export var party_hp: Dictionary = {}
## {item_id: qty} (T-034). Key items and equipment never stack (qty stays 1);
## consumables increment. Write through SceneManager.add_item()/remove_item().
@export var inventory: Dictionary = {}
## Durable world facts: doors opened, chests looted, dialogue beats seen.
@export var flags: Dictionary = {}
