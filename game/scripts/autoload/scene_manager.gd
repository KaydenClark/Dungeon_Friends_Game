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
var _combat_camera: Camera2D
var _combat_camera_zoom := Vector2.ONE

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
## Where save files live (T-037/T-039). Tests point this at a scratch dir so
## automated runs can never clobber a real save in user://saves.
var save_dir: String = SaveManager.DEFAULT_DIR


## Snapshot the live session into a save slot (T-039; the SaveCrystal calls
## this). The map id comes from the registry, the position from the live
## player. Refuses (false + warning) rather than writing a save it could
## never load back.
func save_game(slot: int = 1) -> bool:
	var map_id := MapRegistry.id_for(current_room)
	if map_id == "":
		push_warning("save_game: current room is not a registered map - not saving")
		return false
	var player: Variant = current_room.get("player")
	if not player is Player:
		push_warning("save_game: current room has no player - not saving")
		return false
	var data := SaveManager.capture(state, map_id, player.cell)
	return SaveManager.write(slot, data, save_dir)


## Restore a saved session (T-040, D-011): swap in the saved GameState, tear
## down the live room graph, and boot the saved map via the registry with the
## player at the saved cell. Rooms rebuild opened doors/chests from flags in
## _ready(), so no per-object load code exists here by design. A failed load
## (missing/corrupt file, unknown map id) returns false and leaves the live
## session untouched.
func load_game(slot: int = 1) -> bool:
	if world_container == null:
		push_warning("load_game: no world container registered - not loading")
		return false
	var data := SaveManager.load_slot(slot, save_dir)
	if data == null:
		return false
	var room := MapRegistry.build(data.current_map)
	if room == null:
		return false
	state = data.to_game_state()
	for r in room_stack:
		r.queue_free()
	room_stack.clear()
	if current_room:
		current_room.queue_free()
		current_room = null
	if room is LdtkRoom:
		room.spawn_override = data.player_position
	boot_room(room)
	return true


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
	# The player re-entered this room through wherever they now stand (the
	# doorway they left from, or wherever on_room_restored moved them) - that
	# is the new "last entrance" a pit fall walks back to (T-047).
	if current_room is RoomGrid and prev_player is Player:
		current_room.entry_cell = prev_player.cell
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
		var skip_msg := _apply_enemy_rewards(enemy)
		enemy.defeated()
		encounter_finished.emit(true)
		await show_dialogue(["(Dev: combat skipped.)", skip_msg])
		return
	in_encounter = true
	await _zoom_into_encounter()
	await _fade_to(1.0)
	world_container.visible = false
	world_container.process_mode = Node.PROCESS_MODE_DISABLED
	var combat := CombatScene.new()
	combat.setup(_build_party_units(), _build_enemy_units(enemy),
			_arena_from_room(enemy.cell), rng, auto_combat,
			inventory.has("shield"))
	combat_container.add_child(combat)
	await _fade_to(0.0)
	var result: Array = await combat.finished
	var victory: bool = result[0]
	var payload: Dictionary = result[1]
	for id in payload.get("party_hp", {}):
		state.party_hp[id] = payload["party_hp"][id]
	for id in payload.get("party_mp", {}):
		state.party_mp[id] = payload["party_mp"][id]
	await _fade_to(1.0)
	combat.queue_free()
	world_container.visible = true
	world_container.process_mode = Node.PROCESS_MODE_INHERIT
	await _zoom_out_of_encounter()
	await _fade_to(0.0)
	if victory:
		var msg := _apply_enemy_rewards(enemy)
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
	var group: Array[EnemyStats] = [enemy_stats]
	return _apply_rewards(group)


## Reward an authored encounter as one victory. Every enemy in the group
## contributes XP and its string-id loot; add_item() keeps key/gear dedup.
func apply_encounter_rewards(encounter: EncounterData) -> String:
	return _apply_rewards(encounter.enemy_group if encounter != null else [])


func _apply_enemy_rewards(enemy: OverworldEnemy) -> String:
	if enemy.encounter != null and not enemy.encounter.enemy_group.is_empty():
		return apply_encounter_rewards(enemy.encounter)
	return apply_victory_rewards(enemy.stats)


func _apply_rewards(enemy_group: Array[EnemyStats]) -> String:
	var xp := 0
	var drops := PackedStringArray()
	for enemy_stats in enemy_group:
		if enemy_stats == null:
			continue
		xp += enemy_stats.xp_reward
		for item in enemy_stats.loot_table:
			drops.append(item)
			add_item(item)
	total_xp += xp
	var msg := "Victory! Gained %d XP." % xp
	if drops.size() > 0:
		var names := PackedStringArray()
		for item in drops:
			names.append(ItemLibrary.display_name(item))
		msg += " The enemies dropped: %s!" % ", ".join(names)
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


## Cached CharacterStats lookup for every roster member (the hero keeps its
## dedicated hero_stats var for legacy call sites; this is the general path).
var _character_stats_cache: Dictionary = {}
func character_stats_for(id: String) -> CharacterStats:
	if not _character_stats_cache.has(id):
		_character_stats_cache[id] = load("res://data/characters/%s.tres" % id)
	return _character_stats_cache[id]


## The player's side of a battle (T-062): one CombatUnit per roster member,
## with current HP/MP carried in (defaults: full).
func _build_party_units() -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for id in state.party_roster:
		var stats := character_stats_for(id)
		if stats == null:
			push_warning("No CharacterStats for roster id %s" % id)
			continue
		var hp: int = state.party_hp.get(id, stats.max_hp)
		var mp: int = state.party_mp.get(id, stats.max_mp)
		out.append(CombatUnit.from_character(id, stats, hp, mp))
	return out


## The enemy side (T-062): the touched enemy's EncounterData party when it
## carries one (T-066 wires the LDtk field), else the single enemy itself.
func _build_enemy_units(enemy: OverworldEnemy) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	if enemy.encounter != null and not enemy.encounter.enemy_group.is_empty():
		for i in enemy.encounter.enemy_group.size():
			out.append(CombatUnit.from_enemy(enemy.encounter.enemy_group[i], i))
	else:
		out.append(CombatUnit.from_enemy(enemy.stats, 0))
	return out


## D-012 (Kayden: "use the local terrain where you were touched"): seed the
## combat grid from the current room's cells in a window around the contact
## point. Blocked terrain and pits both read as obstacles. Falls back to an
## open field when the local area can't fit both parties.
const ARENA_W := 9
const ARENA_H := 5
func _arena_from_room(contact: Vector2i) -> Dictionary:
	var open_field := {"w": ARENA_W, "h": ARENA_H, "blocked": []}
	var room := current_room as RoomGrid
	if room == null or room.width <= 0:
		return open_field
	var w: int = mini(ARENA_W, room.width)
	var h: int = mini(ARENA_H, room.height)
	var origin := contact - Vector2i(w / 2, h / 2)
	origin.x = clampi(origin.x, 0, room.width - w)
	origin.y = clampi(origin.y, 0, room.height - h)
	var walkable: Dictionary = {}
	for y in h:
		for x in w:
			var world_cell := origin + Vector2i(x, y)
			if not (room.blocked.has(world_cell) or room.pits.has(world_cell)):
				walkable[Vector2i(x, y)] = true
	# Keep only the connected region around the contact point, so the two
	# parties can always reach each other (a wall pocket would otherwise
	# stalemate the battle). Everything else reads as an obstacle.
	var start := contact - origin
	if not walkable.has(start):
		return open_field
	var component: Dictionary = {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_front()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if walkable.has(n) and not component.has(n):
				component[n] = true
				frontier.append(n)
	# Both parties (up to 4 + 4) plus room to maneuver, or fight in a field.
	if component.size() < 12:
		return open_field
	var blocked: Array[Vector2i] = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not component.has(c):
				blocked.append(c)
	return {"w": w, "h": h, "blocked": blocked}


## Restore the whole party to full HP/MP. Shared by the healer NPC and the
## post-defeat recovery so both apply the exact same rule.
func heal_hero_to_full() -> void:
	for id in state.party_roster:
		var stats := character_stats_for(id)
		if stats:
			state.party_hp[id] = stats.max_hp
			state.party_mp[id] = stats.max_mp


## Party defeat (T-041, D-004/D-008): checkpoints, not restarts - "not having
## to do things over again is never the punishment". Keep inventory and
## flags; lose XP down to the current level's floor (Progression tunable);
## come back at full HP (agent interpretation - defeat already costs XP;
## flagged for T-069). In a dungeon: respawn at the dungeon entrance on a
## fresh hub (T-048 rebuild = puzzle + enemy reset), the suspended forest
## kept beneath. Outside: respawn by the healer's campfire in the same
## room. Defeat NEVER touches save files. Unregistered rooms (dev spikes)
## keep the old restart-from-scratch flow; restart_game() itself stays for
## the dev overlay.
func handle_defeat() -> void:
	var map_id := MapRegistry.id_for(current_room)
	if map_id == "":
		await show_dialogue([
			"You were defeated...",
			"Everything fades to black.",
			"...and the adventure begins anew.",
		])
		restart_game()
		return
	var lost := apply_defeat_xp_penalty()
	heal_hero_to_full()
	var lines := PackedStringArray(["You were defeated..."])
	if lost > 0:
		lines.append("(%d XP slips away...)" % lost)
	if map_id == "forest":
		lines.append("You come to by the healer's campfire.")
	else:
		lines.append("You come to at the dungeon's entrance.")
	await show_dialogue(lines)
	if map_id == "forest":
		respawn_at_healer()
	else:
		respawn_at_dungeon_entrance()


## Apply the D-008 XP penalty to every roster member; returns the total lost.
func apply_defeat_xp_penalty() -> int:
	var lost := 0
	for id in state.party_roster:
		var level: int = state.party_levels.get(id, 1)
		var current: int = state.party_xp.get(id, 0)
		var after := Progression.xp_after_defeat(current, level)
		state.party_xp[id] = after
		lost += maxi(current - after, 0)
	return lost


## In-dungeon respawn (T-041): free the current room and every suspended room
## above the forest, then boot a FRESH hub - the T-048 rebuild rule resets
## its puzzle and enemies for free. The suspended forest (when the player
## came in the normal way) stays intact beneath; a dev-warped dungeon with an
## empty stack just gets the fresh hub.
func respawn_at_dungeon_entrance() -> void:
	var keep: Node2D = null
	if not room_stack.is_empty() and MapRegistry.id_for(room_stack[0]) == "forest":
		keep = room_stack[0]
	for r in room_stack:
		if r != keep:
			r.queue_free()
	room_stack.clear()
	if keep != null:
		room_stack.append(keep)
	if current_room:
		current_room.queue_free()
		current_room = null
	boot_room(MapRegistry.build("tutorial_hub"))


## Outside respawn (T-041): same room instance, player moved to a walkable
## cell beside the healer (falling back to the room spawn if the campfire is
## somehow crowded, and to a full restart if the room has no player at all).
func respawn_at_healer() -> void:
	var room := current_room as LdtkRoom
	if room == null or room.player == null:
		restart_game()
		return
	var anchor: Vector2i = room.healer.cell if room.healer != null else room.spawn_cell
	var target := room.spawn_cell
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]:
		if room.is_walkable(anchor + d):
			target = anchor + d
			break
	room.teleport(room.player, target)


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


## Phase 4 framing (T-065): push through the overworld contact before the
## short hand-off fade, then restore the exact same player camera afterwards.
## The room and player remain suspended, so position is never reconstructed.
func _zoom_into_encounter() -> void:
	var player: Variant = current_room.get("player") if current_room else null
	if not player is Player or player.camera == null:
		return
	_combat_camera = player.camera
	_combat_camera_zoom = _combat_camera.zoom
	var tw := create_tween()
	tw.tween_property(_combat_camera, "zoom", _combat_camera_zoom * 2.2,
				0.04 if auto_combat else 0.28)
	await tw.finished


func _zoom_out_of_encounter() -> void:
	if _combat_camera == null or not is_instance_valid(_combat_camera):
		return
	var tw := create_tween()
	tw.tween_property(_combat_camera, "zoom", _combat_camera_zoom,
				0.04 if auto_combat else 0.24)
	await tw.finished
	_combat_camera = null
