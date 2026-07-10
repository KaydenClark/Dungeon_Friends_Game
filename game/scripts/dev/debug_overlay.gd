class_name DebugOverlay
extends CanvasLayer
## Dev-tools overlay (T-030; Kayden: "build out some dev tools ... as soon as
## we can"). Debug builds only - main.gd instantiates it behind
## OS.is_debug_build(), so it never ships in an exported release build - and
## hidden until toggled, so a debug session stays clean by default.
##
## F1 toggles the panel. While it is open:
##   1-5  warp: a fresh copy of any registered map (T-049: the list IS the
##        MapRegistry - "go to anywhere we have built"; a new room registered
##        there gets its warp entry automatically, up to MAX_WARPS)
##   R    reset the current room's puzzle (blocks back to start)
##   6-8  grant forest_key / dungeon_key / shield
##   9    heal to full
##   0    toggle skip-combat (touch an enemy = instant victory)
##   P    grant 3 potions (T-064 flagged consumables having no natural
##        source yet; the in-world source is a T-069/Phase 5 design call)
##
## Warps tear down the current room graph and boot the target directly, so a
## warped-to dungeon room has no forest beneath it - its exit doorways just
## no-op on the empty room stack. Fine for iteration, not a player path.

var panel: ColorRect
var text: Label
var open := false

## Number keys reserved for warps before the grant keys start at 6. If the
## registry ever outgrows this, the overlay needs a paging rework - warn
## loudly instead of silently dropping rooms.
const MAX_WARPS := 5
const WARP_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]


## The warp list is the registry, in registry order (T-049).
func warp_ids() -> Array[String]:
	var ids := MapRegistry.ids()
	if ids.size() > MAX_WARPS:
		push_warning("DebugOverlay: %d registered maps but only %d warp keys"
				% [ids.size(), MAX_WARPS])
	return ids


func _ready() -> void:
	layer = 90   # above gameplay, below the fade layer (100)
	panel = ColorRect.new()
	panel.color = Color(0.02, 0.05, 0.1, 0.88)
	panel.position = Vector2(880, 40)
	panel.size = Vector2(380, 384)
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
	var warp_slot: int = WARP_KEYS.find(key)
	if warp_slot >= 0 and warp_slot < warp_ids().size():
		_warp(warp_ids()[warp_slot])
		get_viewport().set_input_as_handled()
		_refresh()
		return
	match key:
		KEY_R: reset_puzzle()
		KEY_6: grant_item("forest_key")
		KEY_7: grant_item("dungeon_key")
		KEY_8: grant_item("shield")
		KEY_9: SceneManager.heal_hero_to_full()
		KEY_0: SceneManager.skip_combat = not SceneManager.skip_combat
		KEY_P: grant_item("potion", 3)
		_:
			return
	get_viewport().set_input_as_handled()
	_refresh()


func _warp(map_id: String) -> void:
	var room := MapRegistry.build(map_id)
	if room == null:
		return
	for r in SceneManager.room_stack:
		r.queue_free()
	SceneManager.room_stack.clear()
	if SceneManager.current_room:
		SceneManager.current_room.queue_free()
		SceneManager.current_room = null
	SceneManager.boot_room(room)


func reset_puzzle() -> void:
	var current: Node2D = SceneManager.current_room
	if current is RoomGrid:
		current.reset_puzzle()


func grant_item(item: String, qty: int = 1) -> void:
	SceneManager.add_item(item, qty)  # dedup/stack lives in the one write path (T-036)


func _refresh() -> void:
	var warps := ""
	var ids := warp_ids()
	for i in mini(ids.size(), MAX_WARPS):
		warps += "%d  Warp: %s (fresh)\n" % [i + 1, MapRegistry.label(ids[i])]
	text.text = """DEV TOOLS (F1 to close)

%sR  Reset room puzzle
6  Grant forest_key
7  Grant dungeon_key
8  Grant shield
9  Heal to full
0  Skip combat: %s
P  Grant 3 potions

Items: %s""" % [
		warps,
		"ON" if SceneManager.skip_combat else "off",
		SceneManager.inventory_summary(),
	]
