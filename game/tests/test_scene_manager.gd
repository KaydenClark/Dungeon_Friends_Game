extends "res://tests/gd_test.gd"
## Unit tests for the SceneManager reward/heal rules that decide loot, XP, and
## recovery after a fight. These call the exact methods start_encounter (on
## victory) and the healer NPC (on interact) use, so the loot dedup and the
## restore-to-full rules are pinned without running a whole battle. The full
## fade/combat/return loop stays covered by the slice smoke test.
##
## SceneManager is an autoload singleton, so these tests mutate and then reset
## its shared session state (total_xp, inventory, hero_hp) around each check to
## stay independent of run order.

func _reset() -> void:
	SceneManager.total_xp = 0
	SceneManager.inventory = {}


func test_victory_grants_xp() -> void:
	_reset()
	var slime: EnemyStats = load("res://data/enemies/forest_slime.tres")
	SceneManager.apply_victory_rewards(slime)
	eq(SceneManager.total_xp, 5, "slime grants 5 XP")
	SceneManager.apply_victory_rewards(slime)
	eq(SceneManager.total_xp, 10, "XP accumulates across fights")
	_reset()


func test_victory_adds_loot() -> void:
	_reset()
	var boss: EnemyStats = load("res://data/enemies/boss_slime.tres")
	SceneManager.apply_victory_rewards(boss)
	ok(SceneManager.inventory.has("forest_key"), "boss loot lands in inventory")
	_reset()


func test_loot_is_deduplicated() -> void:
	# Beating a second key-carrier (or re-applying) must not stack a duplicate.
	_reset()
	var boss: EnemyStats = load("res://data/enemies/boss_slime.tres")
	SceneManager.apply_victory_rewards(boss)
	SceneManager.apply_victory_rewards(boss)
	var keys := 0
	for item in SceneManager.inventory:
		if item == "forest_key":
			keys += 1
	eq(keys, 1, "forest_key appears exactly once after two wins")
	_reset()


func test_no_loot_from_lootless_enemy() -> void:
	_reset()
	var slime: EnemyStats = load("res://data/enemies/forest_slime.tres")
	SceneManager.apply_victory_rewards(slime)
	eq(SceneManager.inventory.size(), 0, "a lootless slime drops nothing")
	_reset()


func test_victory_banner_text() -> void:
	_reset()
	var slime: EnemyStats = load("res://data/enemies/forest_slime.tres")
	var no_loot := SceneManager.apply_victory_rewards(slime)
	eq(no_loot, "Victory! Gained 5 XP.", "lootless banner omits the drop clause")
	_reset()
	var boss: EnemyStats = load("res://data/enemies/boss_slime.tres")
	var with_loot := SceneManager.apply_victory_rewards(boss)
	ok(with_loot.contains("dropped: Forest Key"),
			"loot banner uses the ItemData display name (T-034)")
	ok(with_loot.contains("25 XP"), "loot banner shows boss XP")
	_reset()


func test_heal_restores_to_full() -> void:
	var saved := SceneManager.hero_hp
	SceneManager.hero_hp = 1
	SceneManager.heal_hero_to_full()
	eq(SceneManager.hero_hp, SceneManager.hero_stats.max_hp, "heal tops HP to max")
	SceneManager.hero_hp = saved


func test_defeat_reset_wipes_session_state() -> void:
	# T-029 (D-004): party defeat restarts from the beginning of the game.
	# This pins the state-wipe half; the room reboot is covered end-to-end by
	# the slice smoke test's forced-defeat pass.
	var saved_hp := SceneManager.hero_hp
	SceneManager.total_xp = 120
	SceneManager.inventory = {"forest_key": 1, "shield": 1}
	SceneManager.flags = {"entered_dungeon": true, "chest_hub_opened": true}
	SceneManager.hero_hp = 3
	SceneManager.reset_session_state()
	eq(SceneManager.total_xp, 0, "XP resets to zero")
	eq(SceneManager.inventory.size(), 0, "inventory wiped")
	eq(SceneManager.flags.size(), 0, "flags wiped")
	eq(SceneManager.hero_hp, SceneManager.hero_stats.max_hp,
			"hero restored to full for the fresh start")
	SceneManager.hero_hp = saved_hp


func test_skip_combat_flag_defaults_off() -> void:
	# The T-030 dev hook must never leak into a real session by default.
	not_ok(SceneManager.skip_combat, "skip_combat is off unless dev tools enable it")
