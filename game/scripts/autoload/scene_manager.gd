extends Node
## The project's one and only autoload (locked architecture decision, see
## /BLUEPRINT.md -> Architecture). Owns transient session state (containers,
## hero state, inventory, flags) and orchestrates the overworld <-> combat
## transition with SceneManager context passing: the overworld is paused and
## hidden (never freed), so the player returns to the exact pre-combat
## position. The fade transition is a placeholder for the eventual
## camera-zoom-into-the-encounter treatment (see BLUEPRINT.md Design
## Decisions) - same context-passing pattern, different animation.
##
## Session state lives on a single GameState Resource (T-036); the
## hero_hp/total_xp/inventory/flags properties below forward to it so call
## sites read naturally while `state` stays the one serializable truth
## (T-037's SaveData wraps it).

signal encounter_finished(victory: bool)

var world_container: Node2D
var combat_container: Node2D
var ui_layer: CanvasLayer
var transition_layer: CanvasLayer
var fade_rect: ColorRect

var rng := RandomNumberGenerator.new()
## When true (used by the headless smoke test), combat auto-plays with tiny
## waits and menu selection is skipped.
var auto_combat := false
## Dev-tools hook (T-030): when true, touching an enemy skips the battle
## entirely and resolves as an instant victory. Never on in a real build -
## only the debug overlay flips it.
var skip_combat := false

var hero_stats: CharacterStats
## The one mutable-session Resource (T-036). Swapped wholesale on reset/load.
var state := GameState.new()

var hero_hp: int:
	get: return state.party_hp.get("hero", 0)
	set(v): state.party_hp["hero"] = v
var total_xp: int:
	get: return state.party_xp.get("hero", 0)
	set(v): state.party_xp["hero"] = v
## {item_id: qty} (T-034). Write through add_item()/remove_item(), never
## directly - they own the stack-vs-dedup rules. Reads (.has(), .size(),
## iteration over ids) are safe.
var inventory: Dictionary:
	get: return state.inventory
	set(v): state.inventory = v
var flags: Dictionary:
	get: return state.flags
	set(v): state.flags = v

var ui_busy := false
## Set when a dialogue closes. The player polls interact each frame, so without
## this the same keypress that closes a box re-opens it on the next frame.
var last_ui_close_ms := 0
var in_encounter := false
var current_dialogue: DialogueBox

## Room transitions (T-022). The active room plus a stack of suspended ones:
## entering a sub-room (the dungeon behind the boss door) hides and disables
## the current room rather than freeing it - the same context-preservation
## pattern combat uses - so exiting restores it exactly (defeated enemies,
## opened doors, player position all intact).
var current_room: Node2D
var room_stack: Array[Node2D] = []
var transitioning := false
## How the booting scene rebuilds the game's starting room - set by main.gd,
## used by restart_game() (T-029: party defeat restarts from the beginning).
var boot_factory := Callable()


func _ready() -> void:
	rng.randomize()
	hero_stats = load("res://data/characters/hero.tres")
	if hero_stats:
		hero_hp = hero_stats.max_hp
	print("SceneManager ready.")


## Called by main.gd so this autoload can reach the containers regardless of
## which scene is the root (main game, dev spikes, smoke test).
func register_main(world: Node2D, combat: Node2D, ui: CanvasLayer,
		transition: CanvasLayer) -> void:
	world_container = world
	combat_container = combat
	ui_layer = ui
	transition_layer = transition
	transition_layer.layer = 100
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_layer.add_child(fade_rect)


## Place the game's starting room. Called by the booting scene (main.gd or a
## test) after register_main, so room transitions know what "current" is.
func boot_room(room: Node2D) -> void:
	current_room = room
	world_container.add_child(room)


## Suspend the current room and enter a new one (e.g. forest -> dungeon).
func enter_room(new_room: Node2D) -> void:
	if transitioning or in_encounter or world_container == null:
		new_room.free()
		return
	transitioning = true
	await _fade_to(1.0)
	if current_room:
		current_room.visible = false
		current_room.process_mode = Node.PROCESS_MODE_DISABLED
		room_stack.append(current_room)
	current_room = new_room
	world_container.add_child(new_room)
	await _fade_to(0.0)
	transitioning = false


## Leave the current room and restore the one beneath it on the stack. The
## restored room's player resumes at the exact cell they left from.
func exit_room() -> void:
	await exit_rooms(1)


## Pop `count` rooms in one transition (the tutorial dungeon's Room 3 -> hub
## loop skips back past Room 2). Freed rooms rebuild fresh on re-entry - that
## re-entry reset is the puzzle escape valve. The restored room gets an
## on_room_restored() callback to reposition the player / react to flags.
func exit_rooms(count: int) -> void:
	if transitioning or in_encounter or room_stack.is_empty():
		return
	transitioning = true
	await _fade_to(1.0)
	for i in count:
		if room_stack.is_empty():
			break
		if current_room:
			current_room.queue_free()
		current_room = room_stack.pop_back()
	current_room.visible = true
	current_room.process_mode = Node.PROCESS_MODE_INHERIT
	var prev_player: Variant = current_room.get("player")
	if prev_player is Player and prev_player.camera:
		prev_player.camera.make_current()
	if current_room.has_method("on_room_restored"):
		current_room.on_room_restored()
	await _fade_to(0.0)
	transitioning = false


func show_dialogue(lines: PackedStringArray) -> void:
	if ui_layer == null:
		for l in lines:
			print("[dialogue] ", l)
		return
	while ui_busy:
		await get_tree().process_frame
	ui_busy = true
	var box := DialogueBox.new()
	current_dialogue = box
	ui_layer.add_child(box)
	box.open(lines)
	await box.finished
	current_dialogue = null
	box.queue_free()
	ui_busy = false
	last_ui_close_ms = Time.get_ticks_msec()


func start_encounter(enemy: OverworldEnemy) -> void:
	if in_encounter or world_container == null:
		return
	if skip_combat:
		# Dev-tools shortcut (T-030): instant victory, no combat scene.
		var skip_msg := apply_victory_rewards(enemy.stats)
		enemy.defeated()
		encounter_finished.emit(true)
		await show_dialogue(["(Dev: combat skipped.)", skip_msg])
		return
	in_encounter = true
	await _fade_to(1.0)
	world_container.visible = false
	world_container.process_mode = Node.PROCESS_MODE_DISABLED
	var combat := CombatScene.new()
	combat.setup(hero_stats, hero_hp, enemy.stats, rng, auto_combat)
	combat_container.add_child(combat)
	await _fade_to(0.0)
	var result: Array = await combat.finished
	var victory: bool = result[0]
	hero_hp = result[1]
	await _fade_to(1.0)
	combat.queue_free()
	world_container.visible = true
	world_container.process_mode = Node.PROCESS_MODE_INHERIT
	await _fade_to(0.0)
	if victory:
		var msg := apply_victory_rewards(enemy.stats)
		enemy.defeated()
		in_encounter = false
		encounter_finished.emit(true)
		await show_dialogue([msg])
	else:
		in_encounter = false
		encounter_finished.emit(false)
		await handle_defeat()


## Grant XP and loot for a defeated enemy and return the victory banner text.
## Loot is de-duplicated (you never pick up a second identical key). Extracted
## from start_encounter so the reward rules can be unit tested without running
## a whole battle (see /RUNBOOK.md -> Unit tests).
func apply_victory_rewards(enemy_stats: EnemyStats) -> String:
	total_xp += enemy_stats.xp_reward
	var drops: PackedStringArray = enemy_stats.loot_table
	for item in drops:
		add_item(item)
	var msg := "Victory! Gained %d XP." % enemy_stats.xp_reward
	if drops.size() > 0:
		var names := PackedStringArray()
		for item in drops:
			names.append(ItemLibrary.display_name(item))
		msg += " The %s dropped: %s!" % [enemy_stats.display_name, ", ".join(names)]
	return msg


## Add an item to the {id: qty} inventory (T-034). Key items and equipment
## never stack - a second copy is ignored (the loot-dedup rule); consumables
## increment by qty. The single write path for inventory from outside this
## autoload.
func add_item(item: String, qty: int = 1) -> void:
	var data := ItemLibrary.get_item(item)
	if data != null and data.stacks():
		state.inventory[item] = int(state.inventory.get(item, 0)) + qty
	elif not state.inventory.has(item):
		state.inventory[item] = 1


## Remove qty of an item (consumable use, T-064). Refuses - and changes
## nothing - if fewer than qty are held; erases the entry at zero so
## has()/size() keep their old meanings.
func remove_item(item: String, qty: int = 1) -> bool:
	var have := int(state.inventory.get(item, 0))
	if have < qty:
		return false
	if have == qty:
		state.inventory.erase(item)
	else:
		state.inventory[item] = have - qty
	return true


## One-line inventory readout for the HUD and dev overlay: display names
## from ItemData, "x qty" suffix only when stacked, "-" when empty.
func inventory_summary() -> String:
	if state.inventory.is_empty():
		return "-"
	var parts := PackedStringArray()
	for item in state.inventory:
		var qty := int(state.inventory[item])
		var display := ItemLibrary.display_name(item)
		parts.append(display if qty <= 1 else "%s x%d" % [display, qty])
	return ", ".join(parts)


## Restore the hero to full HP. Shared by the healer NPC and the post-defeat
## recovery so both apply the exact same rule.
func heal_hero_to_full() -> void:
	if hero_stats:
		hero_hp = hero_stats.max_hp


## Party defeat (T-029, locked decision D-004): restart from the beginning of
## the game - the simplest possible rule, no state snapshotting. The richer
## respawn (healer NPC outside, dungeon room 1 with puzzle reset inside) is
## deferred to Phase 3, where it rides on save/load serialization.
func handle_defeat() -> void:
	await show_dialogue([
		"You were defeated...",
		"Everything fades to black.",
		"...and the adventure begins anew.",
	])
	restart_game()


## Wipe the session and boot a fresh starting room via boot_factory.
func restart_game() -> void:
	reset_session_state()
	for r in room_stack:
		r.queue_free()
	room_stack.clear()
	if current_room:
		current_room.queue_free()
		current_room = null
	if boot_factory.is_valid() and world_container:
		boot_room(boot_factory.call())


## The pure state-reset half of a restart (unit-tested on its own): swap in
## a fresh GameState, then restore HP - XP, inventory, flags, and HP all
## return to a fresh game's values in one move.
func reset_session_state() -> void:
	state = GameState.new()
	heal_hero_to_full()


func _fade_to(alpha: float) -> void:
	if fade_rect == null:
		return
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", alpha, 0.02 if auto_combat else 0.3)
	await tw.finished
