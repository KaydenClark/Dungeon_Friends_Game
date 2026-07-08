class_name GameState
extends Resource
## The whole mutable session in one serializable Resource (T-036, Phase 3;
## Gameplan §3.1: GameState is a Resource held by SceneManager, "which makes
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
## {item_id: qty} (T-034). Ids resolve to ItemData through ItemLibrary; keys
## and equipment stay unique at qty 1, consumables stack - enforced by
## SceneManager.add_item, the one write path.
@export var inventory: Dictionary = {}
## Durable world facts: doors opened, chests looted, dialogue beats seen.
@export var flags: Dictionary = {}
