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
## S-009/TK-004 (D-025): when true, touching an enemy enters the in-room
## encounter mode seam on the current LdtkRoom instead of the v1 zoom/arena
## CombatScene. Deliberately opt-in and false by default - S-012 flips the
## default once real combat resolution replaces the v1 route with proof.
var unified_encounters := false
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
## Slot backing the current session. Zero means this run started fresh; if a
## file already occupies the target slot, the crystal must ask before the
## first overwrite (B-15).
var loaded_slot := 0


## Snapshot the live session into a save slot (T-039; the SaveCrystal calls
## this). The map id comes from the registry, the position from the live
## player. Refuses (false + warning) rather than writing a save it could
## never load back.
func save_needs_overwrite_confirmation(slot: int = 1) -> bool:
	return loaded_slot != slot and SaveManager.slot_exists(slot, save_dir)


func save_game(slot: int = 1, overwrite_confirmed := false) -> bool:
	if save_needs_overwrite_confirmation(slot) and not overwrite_confirmed:
		push_warning("save_game: slot %d exists and overwrite was not confirmed" % slot)
		return false
	var map_id := MapRegistry.id_for(current_room)
	if map_id == "":
		push_warning("save_game: current room is not a registered map - not saving")
		return false
	var player: Variant = current_room.get("player")
	if not player is Player:
		push_warning("save_game: current room has no player - not saving")
		return false
	var data := SaveManager.capture(state, map_id, player.cell)
	var wrote := SaveManager.write(slot, data, save_dir)
	if wrote:
		loaded_slot = slot
	return wrote


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
	loaded_slot = slot
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
	# B-12: refuse during a room transition - an encounter starting mid-fade
	# would fight enter_room/exit_rooms over the fade rect and world container,
	# and could seed its arena from the wrong room.
	if in_encounter or transitioning:
		return
	# S-009/TK-004: the unified in-room seam takes the encounter when enabled.
	# It needs no world_container (no scene swap ever happens), so it routes
	# before the v1 guard. Any refusal (already active, unknown identity)
	# falls through to nothing rather than the v1 arena, so a half-configured
	# room cannot double-start.
	if unified_encounters and enemy.room is LdtkRoom:
		var seam_error := (enemy.room as LdtkRoom).begin_room_encounter(enemy)
		if seam_error == "deployment_failed":
			# S-010 review C2: a refused deployment must never be silent
			# dead input - tell the player why nothing happened.
			await show_dialogue(["(There's no room for the party to form up here!)"])
		return
	if world_container == null:
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
			_select_authored_arena(enemy), rng, auto_combat,
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


## Public seam for the S-009/TK-004 in-room encounter resolution: identical
## reward rules to the v1 route (group when authored, single stats otherwise).
func apply_enemy_rewards(enemy: OverworldEnemy) -> String:
	return _apply_enemy_rewards(enemy)


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


## D-018: choose a prebuilt LDtk template by encounter context rather than
## copying a brittle patch of overworld geometry. The fallback is deliberately
## loud and open only for corrupted/missing authored content; valid production
## records must pass ArenaValidator before a battle begins.
const ARENA_W := 17
const ARENA_H := 7
func _select_authored_arena(enemy: OverworldEnemy) -> Dictionary:
	var biome := "forest"
	var tags := PackedStringArray()
	var fixed_arena_id := ""
	if enemy.encounter != null:
		biome = enemy.encounter.biome
		tags = enemy.encounter.arena_tags
		fixed_arena_id = enemy.encounter.fixed_arena_id
	var selector := ArenaSelector.from_game_state(state, 20260711)
	var record := selector.select(ArenaLibrary.registry(), biome, tags, fixed_arena_id)
	if record == null:
		push_error("Authored arena selection failed: %s" % selector.last_error)
		return _open_arena_fallback()
	selector.store_in_game_state(state)
	var loaded := AuthoredArenaLoader.load_record(record, _party_on_left(enemy))
	if not bool(loaded.get("ok", false)):
		push_error("Authored arena load failed: %s" % str(loaded.get("error", "unknown error")))
		return _open_arena_fallback()
	var arena: Dictionary = loaded["arena"]
	var validation_errors := ArenaValidator.validate(arena)
	if not validation_errors.is_empty():
		push_error("Authored arena '%s' failed validation: %s"
				% [record.id, "; ".join(validation_errors)])
		var visual := arena.get("visual") as Node2D
		if visual != null:
			visual.queue_free()
		return _open_arena_fallback()
	return arena


func _open_arena_fallback() -> Dictionary:
	return {"w": ARENA_W, "h": ARENA_H, "blocked": []}


## The board is landscape, so north/south contact maps to a deterministic
## horizontal side instead of rotating a 17x7 tactical grid. East/west contact
## still reads naturally; both vertical directions stay stable across reloads.
func _party_on_left(enemy: OverworldEnemy) -> bool:
	var player: Variant = current_room.get("player") if current_room else null
	var resolved_player := player as Player
	if resolved_player == null:
		return true
	var contact: Vector2i = enemy.cell - resolved_player.cell
	if absi(contact.x) >= absi(contact.y):
		return contact.x >= 0
	return contact.y >= 0


## Restore the whole party to full HP/MP. Shared by the healer NPC and the
## post-defeat recovery so both apply the exact same rule.
func heal_hero_to_full() -> void:
	for id in state.party_roster:
		var stats := character_stats_for(id)
		if stats:
			state.party_hp[id] = stats.max_hp
			state.party_mp[id] = stats.max_mp


## The overworld avatar represents the whole traveling party. Environmental
## hazards therefore persist damage for every member, not Hero alone.
func damage_party(amount: int) -> void:
	for id in state.party_roster:
		var stats := character_stats_for(id)
		if stats:
			var hp: int = state.party_hp.get(id, stats.max_hp)
			state.party_hp[id] = maxi(hp - amount, 0)


## Party defeat (T-041, D-004/D-008): checkpoints, not restarts - "not having
## to do things over again is never the punishment". Keep inventory and
## flags; lose 25% of above-floor XP progress (Progression.DEFEAT_XP_LOSS);
## come back at 80% HP (both Kayden's 2026-07-10 tuning, still tunable).
## In a dungeon: respawn at the dungeon entrance on a
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
	restore_party_after_defeat()
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


## Respawn HP after a defeat (Kayden's 2026-07-10 tuning): "set you to 80%
## health when you come back" - a slight lasting hit, like waking with
## Zelda's three hearts but gentler; a meal/heal tops you back up. Tunable.
const RESPAWN_HP_FRACTION := 0.8


## Post-defeat recovery: every roster member comes back at 80% of max HP
## (never below 1) with full MP (agent interpretation - MP has no food/rest
## economy yet; flag if wrong). The healer NPC still heals to genuine full.
func restore_party_after_defeat() -> void:
	for id in state.party_roster:
		var stats := character_stats_for(id)
		if stats:
			state.party_hp[id] = maxi(1, int(round(stats.max_hp * RESPAWN_HP_FRACTION)))
			state.party_mp[id] = stats.max_mp


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
	loaded_slot = 0
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
