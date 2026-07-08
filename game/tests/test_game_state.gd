extends "res://tests/gd_test.gd"
## Unit tests for the GameState Resource + SceneManager's forwarding
## properties (T-036). The contract: `SceneManager.state` is the single
## source of truth; the hero_hp/total_xp/inventory/flags properties and
## add_item() all read/write through to it, and reset swaps the whole
## Resource for a fresh one. Every test ends on reset_session_state() so
## later suites see a clean session.


func test_fresh_state_defaults_are_party_shaped() -> void:
	var s := GameState.new()
	eq(s.party_roster, ["hero"], "roster starts as the lone hero")
	eq(s.party_levels.get("hero"), 1, "hero starts at level 1")
	eq(s.party_xp.get("hero"), 0, "hero starts with 0 XP")
	eq(s.inventory.size(), 0, "inventory starts empty")
	eq(s.flags.size(), 0, "flags start empty")


func test_two_states_never_share_containers() -> void:
	# Regression guard: GDScript evaluates Dictionary/Array defaults per
	# instance - if that ever regresses, every save slot would alias.
	var a := GameState.new()
	var b := GameState.new()
	a.party_xp["hero"] = 99
	a.flags["door_x_opened"] = true
	a.inventory["shield"] = 1
	eq(b.party_xp.get("hero"), 0, "xp dictionaries are per-instance")
	not_ok(b.flags.has("door_x_opened"), "flags dictionaries are per-instance")
	eq(b.inventory.size(), 0, "inventories are per-instance")


func test_properties_forward_to_state() -> void:
	SceneManager.state = GameState.new()
	SceneManager.hero_hp = 7
	SceneManager.total_xp = 42
	SceneManager.flags["seen_thing"] = true
	eq(SceneManager.state.party_hp.get("hero"), 7, "hero_hp writes land on state")
	eq(SceneManager.state.party_xp.get("hero"), 42, "total_xp writes land on state")
	ok(SceneManager.state.flags.get("seen_thing", false),
			"in-place flag writes land on state (Dictionary is by reference)")
	SceneManager.state.party_hp["hero"] = 3
	eq(SceneManager.hero_hp, 3, "hero_hp reads come from state")
	SceneManager.reset_session_state()


func test_add_item_is_the_deduped_write_path() -> void:
	SceneManager.state = GameState.new()
	SceneManager.add_item("dungeon_key")
	SceneManager.add_item("dungeon_key")
	eq(SceneManager.state.inventory.get("dungeon_key", 0), 1,
			"add_item de-duplicates (qty stays 1)")
	ok(SceneManager.inventory.has("dungeon_key"),
			"the inventory property sees the item")
	SceneManager.reset_session_state()


func test_reset_swaps_in_a_fresh_state() -> void:
	SceneManager.state = GameState.new()
	var old: GameState = SceneManager.state
	SceneManager.add_item("shield")
	SceneManager.total_xp = 50
	SceneManager.reset_session_state()
	ok(SceneManager.state != old, "reset replaces the GameState instance")
	eq(SceneManager.total_xp, 0, "XP back to zero")
	eq(SceneManager.inventory.size(), 0, "inventory back to empty")
	eq(SceneManager.hero_hp, SceneManager.hero_stats.stats.max_hp,
			"hero healed to full on reset")
