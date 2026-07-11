extends "res://tests/gd_test.gd"
## Unit tests for the data model: the CharacterStats/EnemyStats Resource classes
## and the shipped .tres balance instances the game actually loads at runtime
## (SceneManager loads hero.tres; ForestSlice loads the slime .tres files).
## These guard the invariants gameplay leans on -- e.g. only the boss carries
## the forest key, and the key it drops is the one the locked door demands.


func test_character_stats_defaults() -> void:
	var s := CharacterStats.new()
	eq(s.max_hp, 10, "default max_hp")
	eq(s.attack, 1, "default attack")
	eq(s.defense, 0, "default defense")
	eq(s.speed, 1, "default speed")


func test_enemy_stats_defaults() -> void:
	var s := EnemyStats.new()
	eq(s.max_hp, 5, "default max_hp")
	eq(s.ai_behavior, EnemyStats.AIBehavior.RANDOM_WALK, "default AI is random walk")
	eq(s.xp_reward, 0, "default xp reward")
	eq(s.loot_table.size(), 0, "default loot table empty")


func test_hero_resource_loads_with_expected_stats() -> void:
	var hero: CharacterStats = load("res://data/characters/hero.tres")
	not_null(hero, "hero.tres loads")
	eq(hero.id, "hero", "hero id")
	eq(hero.display_name, "Hero", "hero display name")
	eq(hero.max_hp, 20, "hero max_hp")
	eq(hero.attack, 4, "hero attack")
	eq(hero.defense, 2, "hero defense")
	eq(hero.speed, 5, "hero speed")
	not_null(hero.sprite_frames, "hero carries runtime animation frames")
	eq(hero.sprite_frames.get_frame_count(&"idle"), 4,
			"hero idle animation has four normalized frames")


func test_forest_slime_resource() -> void:
	var slime: EnemyStats = load("res://data/enemies/forest_slime.tres")
	not_null(slime, "forest_slime.tres loads")
	eq(slime.id, "forest_slime", "slime id")
	eq(slime.max_hp, 6, "slime max_hp")
	eq(slime.xp_reward, 5, "slime xp reward")
	not_ok(slime.loot_table.has("forest_key"), "regular slime carries no key")
	not_null(slime.sprite_frames, "slime carries runtime animation frames")
	eq(slime.sprite_frames.get_frame_count(&"idle"), 4,
			"slime idle animation has four normalized frames")


func test_combat_units_keep_resource_animation_frames() -> void:
	var hero_stats: CharacterStats = load("res://data/characters/hero.tres")
	var slime_stats: EnemyStats = load("res://data/enemies/forest_slime.tres")
	var hero := CombatUnit.from_character("hero", hero_stats, 20, 5)
	var slime := CombatUnit.from_enemy(slime_stats, 0)
	eq(hero.sprite_frames, hero_stats.sprite_frames,
			"party CombatUnit keeps its CharacterStats animation")
	eq(slime.sprite_frames, slime_stats.sprite_frames,
			"enemy CombatUnit keeps its EnemyStats animation")


func test_boss_slime_resource() -> void:
	var boss: EnemyStats = load("res://data/enemies/boss_slime.tres")
	not_null(boss, "boss_slime.tres loads")
	eq(boss.id, "boss_slime", "boss id")
	eq(boss.max_hp, 16, "boss max_hp")
	eq(boss.xp_reward, 25, "boss xp reward")
	ok(boss.loot_table.has("forest_key"), "boss carries the forest key")


func test_hero_outclasses_slime() -> void:
	# Sanity on the balance curve: the starting hero should out-stat the basic
	# forest slime on the axes that decide a fight.
	var hero: CharacterStats = load("res://data/characters/hero.tres")
	var slime: EnemyStats = load("res://data/enemies/forest_slime.tres")
	ok(hero.max_hp > slime.max_hp, "hero tankier than a slime")
	ok(hero.speed > slime.speed, "hero acts before a slime")


func test_boss_key_matches_locked_door() -> void:
	# Cross-system invariant: the key the boss drops must be the exact key the
	# forest door asks for, or the reward loop dead-ends. required_key became a
	# per-door variable in T-024; the forest door uses the default.
	var boss: EnemyStats = load("res://data/enemies/boss_slime.tres")
	var door := LockedDoor.new()
	ok(boss.loot_table.has(door.required_key),
			"boss drop matches the default door key (%s)" % door.required_key)
	door.free()
