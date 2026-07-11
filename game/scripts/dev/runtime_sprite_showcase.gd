extends Node
## One-command visual proof for the first runtime sprite pass.
##
## Run windowed:
## Godot --path . scenes/dev/runtime_sprite_showcase.tscn \
##   -- --out=/tmp/dungeon-runtime-sprites.png

var out_path := "user://runtime_sprite_showcase.png"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	var hero_stats: CharacterStats = load("res://data/characters/hero.tres")
	var buddy_stats: CharacterStats = load("res://data/characters/companion_test.tres")
	var slime_stats: EnemyStats = load("res://data/enemies/forest_slime.tres")
	var boss_stats: EnemyStats = load("res://data/enemies/boss_slime.tres")
	var hero := CombatUnit.from_character("hero", hero_stats, hero_stats.max_hp, hero_stats.max_mp)
	var buddy := CombatUnit.from_character(
			"companion_test", buddy_stats, buddy_stats.max_hp, buddy_stats.max_mp)
	var slime := CombatUnit.from_enemy(slime_stats, 0)
	var boss := CombatUnit.from_enemy(boss_stats, 0)
	var combat := CombatScene.new()
	combat.autostart = false
	combat.setup([hero, buddy], [slime, boss],
			{"w": 17, "h": 7, "blocked": []}, RandomNumberGenerator.new(), false, true)
	add_child(combat)
	for _frame in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_path)
	print("RUNTIME SPRITE SHOWCASE: wrote ", out_path)
	get_tree().quit(0)
