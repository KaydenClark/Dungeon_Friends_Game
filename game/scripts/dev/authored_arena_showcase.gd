extends Node
## One-command visual proof that CombatScene renders a selected imported LDtk
## arena, its authored deployment slots, and the real party/enemy sprites.

var out_path := "user://authored_arena_combat.png"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	var record := ArenaLibrary.registry().resolve("forest_crossroads")
	var loaded := AuthoredArenaLoader.load_record(record, true)
	if not bool(loaded.get("ok", false)):
		push_error("AUTHORED ARENA SHOWCASE: %s" % str(loaded.get("error", "unknown")))
		get_tree().quit(1)
		return
	var arena: Dictionary = loaded["arena"]
	var hero_stats: CharacterStats = load("res://data/characters/hero.tres")
	var buddy_stats: CharacterStats = load("res://data/characters/companion_test.tres")
	var slime_stats: EnemyStats = load("res://data/enemies/forest_slime.tres")
	var combat := CombatScene.new()
	combat.autostart = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260711
	combat.setup([
		CombatUnit.from_character("hero", hero_stats, hero_stats.max_hp, hero_stats.max_mp),
		CombatUnit.from_character("companion_test", buddy_stats, buddy_stats.max_hp, buddy_stats.max_mp),
	], [
		CombatUnit.from_enemy(slime_stats, 0),
		CombatUnit.from_enemy(slime_stats, 1),
	], arena, rng, false, false)
	add_child(combat)
	for _frame in 4:
		await get_tree().process_frame
	var hero := combat.units[0]
	var reachable := combat._reachable_cells(hero)
	combat._show_highlights(reachable.keys(), CombatScene.MOVE_HIGHLIGHT_FILL)
	combat._show_attack_fringe(hero, reachable)
	combat.menu_panel.visible = true
	combat.prompt_label.text = "Move Hero  (E confirm, Q stay)"
	combat.prompt_label.visible = true
	for _frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("AUTHORED ARENA COMBAT SHOWCASE: wrote ", out_path)
	get_tree().quit(0)
