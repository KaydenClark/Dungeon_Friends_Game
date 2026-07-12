extends Node
## Deterministic rendered proof for T-085/T-087. Captures the exact HUD/menu/
## targeting states that failed Kayden's playthrough plus forest/dungeon biome
## separation. Run windowed; the dummy headless renderer produces black PNGs.

var out_dir := "user://combat_readability_tour"
var combat: CombatScene


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _run()
	print("COMBAT READABILITY TOUR: done -> ", out_dir)
	get_tree().quit(0)


func _run() -> void:
	SceneManager.reset_session_state()
	SceneManager.inventory = {"potion": 2, "shield": 1}
	combat = await _build_combat("forest_crossroads", "res://data/enemies/forest_slime.tres")
	combat.round_label.text = "Round 1"
	combat.log_label.text = "Hero's turn."
	combat.tm.setup(combat.units)
	combat._refresh_hud()
	await _shot("01-turn-start")

	var hero: CombatUnit = combat.units[0]
	combat.menu_options = combat._build_root_options(hero)
	combat.prompt_label.text = "Choose Hero's action"
	combat._render_menu()
	combat._set_menu_visible(true)
	await _shot("02-root-menu")

	combat.menu_options = combat._build_item_options(hero)
	combat.prompt_label.text = "Choose an item for Hero"
	combat._render_menu()
	combat._set_menu_visible(true)
	await _shot("03-item-menu")

	combat._set_menu_visible(false)
	combat.menu_panel.visible = true
	combat.prompt_label.text = "Move Hero  (E confirm, Q stay)"
	combat.prompt_label.visible = true
	var reachable := combat._reachable_cells(hero)
	combat._show_highlights(reachable.keys(), CombatScene.MOVE_HIGHLIGHT_FILL)
	combat._show_attack_fringe(hero, reachable)
	var destination := hero.cell
	for cell: Vector2i in reachable:
		if cell.x > destination.x:
			destination = cell
	combat._move_cursor_to(destination)
	combat.cursor_rect.visible = true
	await _shot("04-move-destination")

	combat._clear_highlights()
	combat.cursor_rect.visible = false
	combat.menu_panel.visible = false
	combat.prompt_label.visible = false
	combat.log_label.text = "Rolled 4 — HIT!  4 damage.  Forest Slime: 2/6 HP."
	combat._show_popup(combat.units[2], "-4", Color(1.0, 0.45, 0.35))
	await _shot("05-attack-result", 2)

	combat.log_label.text = "Forest battle — authored forest terrain"
	await _shot("06-forest-battle")
	combat.queue_free()
	await _frames(3)

	combat = await _build_combat("dungeon_stone_hall", "res://data/enemies/dungeon_slime.tres")
	combat.round_label.text = "Round 1"
	combat.log_label.text = "Dungeon guardian battle — authored stone terrain"
	combat.tm.setup(combat.units)
	combat._refresh_hud()
	await _shot("07-dungeon-battle")
	combat.queue_free()
	await _frames(2)
	SceneManager.reset_session_state()


func _build_combat(arena_id: String, enemy_path: String) -> CombatScene:
	var record := ArenaLibrary.registry().resolve(arena_id)
	var loaded := AuthoredArenaLoader.load_record(record, true)
	if not bool(loaded.get("ok", false)):
		push_error("COMBAT READABILITY TOUR: %s" % str(loaded.get("error", "unknown")))
		get_tree().quit(1)
		return null
	var hero_stats: CharacterStats = load("res://data/characters/hero.tres")
	var buddy_stats: CharacterStats = load("res://data/characters/companion_test.tres")
	var enemy_stats: EnemyStats = load(enemy_path)
	var built := CombatScene.new()
	built.autostart = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260711
	built.setup([
		CombatUnit.from_character("hero", hero_stats, hero_stats.max_hp, hero_stats.max_mp),
		CombatUnit.from_character("companion_test", buddy_stats, buddy_stats.max_hp, buddy_stats.max_mp),
	], [
		CombatUnit.from_enemy(enemy_stats, 0),
		CombatUnit.from_enemy(enemy_stats, 1),
	], loaded["arena"], rng, false, true)
	add_child(built)
	await _frames(4)
	return built


func _shot(name: String, settle_frames := 4) -> void:
	await _frames(settle_frames)
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [out_dir, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("  wrote ", path)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame
