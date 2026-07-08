extends "res://tests/gd_test.gd"
## Unit tests for the data model: the shared CombatStats block (T-052,
## Kayden's 2026-07-07 direction - one stat system for both sides of a
## fight), the CharacterStats/EnemyStats template wrappers around it, and
## the shipped .tres instances the game actually loads at runtime. These
## guard the invariants gameplay leans on - e.g. only the boss carries the
## forest key, and the key it drops is the one the locked door demands.
## Templates are definitions: nothing runtime (current HP, position, status)
## belongs on them.


func test_combat_stats_defaults() -> void:
	var s := CombatStats.new()
	eq(s.max_hp, 10, "default max_hp")
	eq(s.might, 1, "default might")
	eq(s.guard, 0, "default guard")
	eq(s.skill, 1, "default skill")
	eq(s.speed, 1, "default speed")
	eq(s.focus, 0, "default focus")
	eq(s.move_range, 3, "default move_range")


func test_character_template_defaults() -> void:
	var s := CharacterStats.new()
	eq(s.role, &"balanced", "default role")
	eq(s.starting_level, 1, "characters start at level 1")
	eq(s.starting_ability_ids.size(), 0, "no abilities by default")
	eq(s.exploration_tags.size(), 0, "no exploration tags by default")


func test_enemy_template_defaults() -> void:
	var s := EnemyStats.new()
	eq(s.ai_behavior, EnemyStats.AIBehavior.RANDOM_WALK, "default AI is random walk")
	eq(s.rank, &"standard", "default rank")
	eq(s.xp_reward, 0, "default xp reward")
	eq(s.loot_table.size(), 0, "default loot table empty")
	eq(s.damage_resistances.size(), 0, "no resistances by default (schema-only until Phase 4)")


func test_hero_resource_loads_with_expected_stats() -> void:
	var hero: CharacterStats = load("res://data/characters/hero.tres")
	not_null(hero, "hero.tres loads")
	eq(hero.id, "hero", "hero id")
	eq(hero.display_name, "Hero", "hero display name")
	not_null(hero.stats, "hero carries a shared CombatStats block")
	eq(hero.stats.max_hp, 20, "hero max_hp")
	eq(hero.stats.might, 4, "hero might")
	eq(hero.stats.guard, 4, "hero guard")
	eq(hero.stats.skill, 4, "hero skill")
	eq(hero.stats.speed, 4, "hero speed")
	eq(hero.stats.focus, 3, "hero focus")
	eq(hero.stats.move_range, 4, "hero move range")
	eq(hero.role, &"balanced", "hero role")


func test_forest_slime_resource() -> void:
	var slime: EnemyStats = load("res://data/enemies/forest_slime.tres")
	not_null(slime, "forest_slime.tres loads")
	eq(slime.id, "forest_slime", "slime id")
	not_null(slime.stats, "slime carries a shared CombatStats block")
	eq(slime.stats.max_hp, 8, "slime max_hp (tutorial minion scale)")
	eq(slime.stats.might, 2, "slime might")
	eq(slime.rank, &"minion", "slime rank")
	eq(slime.xp_reward, 5, "slime xp reward")
	not_ok(slime.loot_table.has("forest_key"), "regular slime carries no key")


func test_boss_slime_resource() -> void:
	var boss: EnemyStats = load("res://data/enemies/boss_slime.tres")
	not_null(boss, "boss_slime.tres loads")
	eq(boss.id, "boss_slime", "boss id")
	eq(boss.stats.max_hp, 16, "boss max_hp")
	eq(boss.rank, &"boss", "boss rank")
	eq(boss.xp_reward, 25, "boss xp reward")
	ok(boss.loot_table.has("forest_key"), "boss carries the forest key")


func test_dungeon_slime_resource() -> void:
	var guardian: EnemyStats = load("res://data/enemies/dungeon_slime.tres")
	not_null(guardian, "dungeon_slime.tres loads")
	eq(guardian.stats.max_hp, 10, "guardian max_hp")
	eq(guardian.rank, &"elite", "guardian rank")
	ok(guardian.loot_table.has("dungeon_key"), "guardian carries the dungeon key")


func test_hero_outclasses_slime() -> void:
	# Sanity on the balance curve: the starting hero should out-stat the basic
	# forest slime on the axes that decide a fight.
	var hero: CharacterStats = load("res://data/characters/hero.tres")
	var slime: EnemyStats = load("res://data/enemies/forest_slime.tres")
	ok(hero.stats.max_hp > slime.stats.max_hp, "hero tankier than a slime")
	ok(hero.stats.speed > slime.stats.speed, "hero acts before a slime")
	ok(hero.stats.might > slime.stats.guard, "hero punches through slime guard")


func test_boss_key_matches_locked_door() -> void:
	# Cross-system invariant: the key the boss drops must be the exact key the
	# forest door asks for, or the reward loop dead-ends. required_key became a
	# per-door variable in T-024; the forest door uses the default.
	var boss: EnemyStats = load("res://data/enemies/boss_slime.tres")
	var door := LockedDoor.new()
	ok(boss.loot_table.has(door.required_key),
			"boss drop matches the default door key (%s)" % door.required_key)
	door.free()
