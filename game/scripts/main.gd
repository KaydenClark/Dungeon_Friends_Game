extends Node2D
## Root scene script: registers the containers with SceneManager and loads
## the current world into WorldContainer. Today that world is the
## first-playable forest slice (placeholder art); the LDtk pipeline
## (T-004/T-011) will replace how rooms are authored, not this wiring.


var hud: Label


func _ready() -> void:
	SceneManager.register_main(
		$WorldContainer, $CombatContainer, $UILayer, $TransitionLayer)
	# The factory lets a party defeat rebuild the game from the start (T-029);
	# it resolves through the map registry like every other room build (T-038).
	SceneManager.boot_factory = func() -> Node2D: return MapRegistry.build("forest")
	var hint := Label.new()
	hint.text = "WASD / Arrows: move    E: talk & interact"
	hint.position = Vector2(16, 8)
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.75)
	$UILayer.add_child(hint)
	hud = Label.new()
	hud.position = Vector2(16, 30)
	hud.add_theme_font_size_override("font_size", 18)
	hud.modulate = Color(1, 0.95, 0.75)
	$UILayer.add_child(hud)
	# Dev tools (T-030): debug builds only, hidden until F1 - never in a
	# release export.
	if OS.is_debug_build():
		add_child(DebugOverlay.new())
	# Boot flow (T-040, D-011): an existing save gets a minimal Continue/New
	# Game prompt; otherwise (or on New Game / a failed load) start fresh.
	if SaveManager.any_save_exists(SceneManager.save_dir):
		var prompt := BootPrompt.new()
		add_child(prompt)
		var continue_game: bool = await prompt.chosen
		prompt.queue_free()
		if continue_game:
			if SceneManager.load_game(1):
				return
			# B-14: never fall through to a fresh game silently - the player
			# chose Continue and needs to know the load failed (the save file
			# itself is untouched; load_game leaves it on disk).
			SceneManager.boot_room(SceneManager.boot_factory.call())
			await SceneManager.show_dialogue([
				"The saved adventure could not be loaded...",
				"(The save file was left untouched.)",
				"Starting a new adventure for now.",
			])
			return
	SceneManager.boot_room(SceneManager.boot_factory.call())


func _process(_delta: float) -> void:
	# Tiny placeholder HUD (real UI is a later phase): live HP / XP / key
	# status, so playtesters can see combat and loot actually change state.
	# B-16: every roster member gets an HP readout - Buddy's post-fight health
	# was invisible outside combat, so "is my companion down?" was unanswerable.
	if SceneManager.hero_stats == null:
		return
	var rows := PackedStringArray()
	for id in SceneManager.state.party_roster:
		var stats := SceneManager.character_stats_for(id)
		if stats == null:
			continue
		var hp: int = SceneManager.state.party_hp.get(id, stats.max_hp)
		if hp <= 0:
			rows.append("%s DOWN" % stats.display_name)
		else:
			rows.append("%s %d/%d" % [stats.display_name, hp, stats.max_hp])
	hud.text = "%s    XP %d    Items: %s" % [
		" | ".join(rows), SceneManager.total_xp, SceneManager.inventory_summary()]
