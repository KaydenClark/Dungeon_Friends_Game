class_name DebugOverlay
extends CanvasLayer
## Dev-tools overlay (T-030; Kayden: "build out some dev tools ... as soon as
## we can"). Debug builds only - main.gd instantiates it behind
## OS.is_debug_build(), so it never ships in an exported release build - and
## hidden until toggled, so a debug session stays clean by default.
##
## F1 toggles the panel. While it is open:
##   1-4  warp: fresh Forest / Tutorial Hub / Pit Room / Fight Room
##   5    reset the current room's puzzle (blocks back to start)
##   6-8  grant forest_key / dungeon_key / shield
##   9    heal to full
##   0    toggle skip-combat (touch an enemy = instant victory)
##
## Warps tear down the current room graph and boot the target directly, so a
## warped-to dungeon room has no forest beneath it - its exit doorways just
## no-op on the empty room stack. Fine for iteration, not a player path.

var panel: ColorRect
var text: Label
var open := false


func _ready() -> void:
	layer = 90   # above gameplay, below the fade layer (100)
	panel = ColorRect.new()
	panel.color = Color(0.02, 0.05, 0.1, 0.88)
	panel.position = Vector2(880, 40)
	panel.size = Vector2(380, 330)
	panel.visible = false
	add_child(panel)
	text = Label.new()
	text.position = Vector2(14, 10)
	text.add_theme_font_size_override("font_size", 17)
	panel.add_child(text)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_F1:
		open = not open
		panel.visible = open
		get_viewport().set_input_as_handled()
		_refresh()
		return
	if not open:
		return
	if SceneManager.in_encounter or SceneManager.transitioning:
		return
	match key:
		KEY_1: _warp(func() -> Node2D: return ForestRoom.new())
		KEY_2: _warp(func() -> Node2D: return TutorialHubRoom.new())
		KEY_3: _warp(func() -> Node2D: return TutorialPitRoom.new())
		KEY_4: _warp(func() -> Node2D: return TutorialFightRoom.new())
		KEY_5: reset_puzzle()
		KEY_6: grant_item("forest_key")
		KEY_7: grant_item("dungeon_key")
		KEY_8: grant_item("shield")
		KEY_9: SceneManager.heal_hero_to_full()
		KEY_0: SceneManager.skip_combat = not SceneManager.skip_combat
		_:
			return
	get_viewport().set_input_as_handled()
	_refresh()


func _warp(factory: Callable) -> void:
	for r in SceneManager.room_stack:
		r.queue_free()
	SceneManager.room_stack.clear()
	if SceneManager.current_room:
		SceneManager.current_room.queue_free()
		SceneManager.current_room = null
	SceneManager.boot_room(factory.call())


func reset_puzzle() -> void:
	var current: Node2D = SceneManager.current_room
	if current is RoomGrid:
		current.reset_puzzle()


func grant_item(item: String) -> void:
	SceneManager.add_item(item)  # dedup lives in the one write path (T-036)


func _refresh() -> void:
	text.text = """DEV TOOLS (F1 to close)

1  Warp: Forest (fresh)
2  Warp: Tutorial Hub
3  Warp: Pit Room
4  Warp: Fight Room
5  Reset room puzzle
6  Grant forest_key
7  Grant dungeon_key
8  Grant shield
9  Heal to full
0  Skip combat: %s

Items: %s""" % [
		"ON" if SceneManager.skip_combat else "off",
		", ".join(SceneManager.inventory) if SceneManager.inventory.size() > 0 else "-",
	]
