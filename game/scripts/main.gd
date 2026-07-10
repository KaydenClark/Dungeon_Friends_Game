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
	hint.text = "WASD / Arrows: move    E or Space: talk & interact"
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
		if continue_game and SceneManager.load_game(1):
			return
	SceneManager.boot_room(SceneManager.boot_factory.call())


func _process(_delta: float) -> void:
	# Tiny placeholder HUD (real UI is a later phase): live HP / XP / key
	# status, so playtesters can see combat and loot actually change state.
	if SceneManager.hero_stats == null:
		return
	hud.text = "HP %d/%d    XP %d    Items: %s" % [
		SceneManager.hero_hp, SceneManager.hero_stats.max_hp,
		SceneManager.total_xp, SceneManager.inventory_summary()]
