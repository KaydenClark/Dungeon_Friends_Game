class_name CombatScene
extends Node2D
## Tactical turn-based combat (Phase 4, T-061/T-062/T-063/T-064; BG3
## turn-based mode is the model, Fire Emblem range highlighting the
## presentation - see /BLUEPRINT.md -> Party And Combat Model). Two-layer
## FSM (locked decision): the Battle FSM here (Initialize ->
## CalculateInitiative -> UnitTurn loop -> EncounterEnd) drives a
## TurnManager that interleaves ALL combatants by speed; each unit runs the
## per-entity FSM on CombatUnit (CheckRange -> Moving -> SelectingAction ->
## ExecutingCommand). The arena is seeded from the local overworld terrain
## around the contact point (D-012) and the party comes from the GameState
## roster (D-013's test companion included). Math lives in CombatMath;
## rendering is screen-space (CanvasLayer) placeholder art.

signal finished(victory: bool, result: Dictionary)
signal menu_confirmed(index: int)
signal cursor_confirmed(cell: Vector2i)
signal advanced

enum BattleState { INITIALIZE, CALCULATE_INITIATIVE, UNIT_TURN, ENCOUNTER_END }
enum InputMode { NONE, MENU, CURSOR_MOVE, CURSOR_TARGET, CONTINUE }

const TILE := 64

var arena_w := 17
var arena_h := 7
var arena_blocked: Dictionary = {}   # Vector2i -> true
var arena_origin := Vector2.ZERO

var units: Array[CombatUnit] = []
## Tests flip this off to drive _execute_*/_reachable_cells directly
## without _ready launching a real battle around them.
var autostart := true
var tm := TurnManager.new()
var rng: RandomNumberGenerator
var auto_play := false
var defend_unlocked := false
var battle_state := BattleState.INITIALIZE

var input_mode := InputMode.NONE
var menu_options: Array = []         # [{label, enabled, payload}]
var menu_index := 0
var cursor_cell := Vector2i.ZERO
var cursor_start := Vector2i.ZERO
var cursor_valid: Dictionary = {}    # Vector2i -> true (cells confirm accepts)
var astar := AStarGrid2D.new()

var layer: CanvasLayer
var log_label: Label
var round_label: Label
var turn_order_label: Label
var party_status_label: Label
var menu_panel: ColorRect
var prompt_label: Label
var menu_label: Label
var continue_label: Label
var cursor_rect: ColorRect
var highlight_root: Control


## party/enemies are prebuilt CombatUnits (SceneManager owns the GameState
## snapshot); arena is {"w": int, "h": int, "blocked": Array[Vector2i]}.
func setup(party: Array[CombatUnit], enemies: Array[CombatUnit],
		arena: Dictionary, p_rng: RandomNumberGenerator, p_auto: bool,
		p_defend_unlocked: bool) -> void:
	rng = p_rng
	auto_play = p_auto
	defend_unlocked = p_defend_unlocked
	arena_w = arena.get("w", 17)
	arena_h = arena.get("h", 7)
	for c in arena.get("blocked", []):
		arena_blocked[c] = true
	units.append_array(party)
	units.append_array(enemies)
	_place_units(party, enemies)


## Deterministic formation placement: each side deploys vertically near its
## edge, centered on the board. Allies never consume the cell directly in
## front of Hero, and SceneManager keeps these deployment columns clear.
func _place_units(party: Array[CombatUnit], enemies: Array[CombatUnit]) -> void:
	var taken: Dictionary = {}
	var free_left: Array[Vector2i] = []
	var free_right: Array[Vector2i] = []
	var center_y := arena_h / 2
	for x in [mini(1, arena_w - 1), 0, mini(2, arena_w - 1)]:
		for offset in arena_h:
			var y: int = center_y + (offset + 1) / 2 * (1 if offset % 2 == 1 else -1)
			if y < 0 or y >= arena_h:
				continue
			var c := Vector2i(x, y)
			if not arena_blocked.has(c):
				free_left.append(c)
	for x in [maxi(arena_w - 2, 0), arena_w - 1, maxi(arena_w - 3, 0)]:
		for offset in arena_h:
			var y: int = center_y + (offset + 1) / 2 * (1 if offset % 2 == 1 else -1)
			if y < 0 or y >= arena_h:
				continue
			var c := Vector2i(x, y)
			if not arena_blocked.has(c):
				free_right.append(c)
	var li := 0
	for u in party:
		while li < free_left.size() and taken.has(free_left[li]):
			li += 1
		if li < free_left.size():
			u.cell = free_left[li]
			taken[u.cell] = true
	var ri := 0
	for u in enemies:
		while ri < free_right.size() and taken.has(free_right[ri]):
			ri += 1
		if ri < free_right.size():
			u.cell = free_right[ri]
			taken[u.cell] = true


func _ready() -> void:
	# B-11: center on the actual viewport, not a hardcoded 1280x720 - with
	# canvas_items/expand stretch (flexible HD/ultrawide decision) the visible
	# canvas is only 1280x720 at exactly 16:9.
	var vs := get_viewport_rect().size
	arena_origin = Vector2((vs.x - arena_w * TILE) / 2.0,
			(vs.y - arena_h * TILE) / 2.0 - 20)
	astar.region = Rect2i(0, 0, arena_w, arena_h)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	_build_view()
	if autostart:
		_run_battle()


# ---------------------------------------------------------------- Battle FSM

func _run_battle() -> void:
	battle_state = BattleState.INITIALIZE
	await _wait(0.3)
	_log("Battle start!")
	await _wait(0.6)
	battle_state = BattleState.CALCULATE_INITIATIVE
	tm.setup(units)
	battle_state = BattleState.UNIT_TURN
	while not tm.battle_over():
		if tm.round_number > 100:
			# Safety valve: a battle that goes 100 rounds is wedged (units
			# that can't reach each other). Should be impossible now that the
			# arena is one connected region - loud, not silent, if it fires.
			push_warning("Combat stalemate guard fired - ending the battle.")
			_log("The fight breaks off...")
			break
		var u := tm.next_unit()
		if u == null:
			break
		round_label.text = "Round %d" % tm.round_number
		_refresh_hud()
		await _take_turn(u)
	battle_state = BattleState.ENCOUNTER_END
	var victory := tm.players_alive()
	_log("Victory!" if victory else "Defeat...")
	await _wait(0.8)
	var party_hp := {}
	var party_mp := {}
	for u in units:
		if u.is_player:
			party_hp[u.unit_id] = u.hp
			party_mp[u.unit_id] = u.mp
	finished.emit(victory, {"party_hp": party_hp, "party_mp": party_mp})


# ------------------------------------------------------------ per-unit turn

func _take_turn(u: CombatUnit) -> void:
	u.defending = false
	_log("%s's turn." % u.display_name)
	await _wait(0.4)
	if u.is_player and not auto_play:
		await _player_turn(u)
	else:
		await _ai_turn(u)
	u.state = CombatUnit.EntityState.AWAITING_TURN


func _player_turn(u: CombatUnit) -> void:
	# CheckRange: light up where this unit can go (FE-style affordance).
	u.state = CombatUnit.EntityState.CHECK_RANGE
	var reachable := _reachable_cells(u)
	_show_highlights(reachable.keys(), Color(0.3, 0.5, 1.0, 0.35))
	_show_attack_fringe(u, reachable)
	# Moving: pick a destination inside the highlight (confirm on own cell or
	# cancel = stay put).
	u.state = CombatUnit.EntityState.MOVING
	var dest := await _pick_cell(u.cell, reachable, "Move %s (E confirm, Q stay)" % u.display_name)
	_clear_highlights()
	if dest != u.cell:
		await _walk(u, dest)
	# SelectingAction: the Attack/Ability/Item/Defend command set (D-007:
	# Defend is absent until the shield is in the inventory).
	u.state = CombatUnit.EntityState.SELECTING_ACTION
	await _action_menu(u)


## The root command set for a unit's turn (extracted for unit tests): the
## locked Attack/Ability/Item/Defend, with Defend absent until the shield is
## in the inventory (D-007/T-046) and Wait as the always-available turn-end.
func _build_root_options(u: CombatUnit) -> Array:
	var opts: Array = []
	var foes := _targets_in_range(u, u.attack_range, false)
	opts.append({"label": "Attack", "enabled": not foes.is_empty(), "kind": "attack"})
	var usable := _usable_abilities(u)
	opts.append({"label": "Ability", "enabled": not usable.is_empty(), "kind": "ability"})
	var usable_items := _usable_item_ids()
	opts.append({"label": "Item" if not usable_items.is_empty() else "Item (none)",
			"enabled": not usable_items.is_empty(), "kind": "item"})
	if defend_unlocked:
		opts.append({"label": "Defend", "enabled": true, "kind": "defend"})
	opts.append({"label": "Wait", "enabled": true, "kind": "wait"})
	return opts


## One menu pass; recursion-free loop so Back always lands here again.
func _action_menu(u: CombatUnit) -> void:
	while true:
		var opts := _build_root_options(u)
		var foes := _targets_in_range(u, u.attack_range, false)
		var usable := _usable_abilities(u)
		var pick: Dictionary = await _menu(u, "What will %s do?" % u.display_name, opts)
		match pick.get("kind", "wait"):
			"attack":
				var t: CombatUnit = await _pick_target(u, foes)
				if t == null:
					continue
				await _execute_attack(u, t, null)
				return
			"ability":
				var ab_opts: Array = []
				for ab in usable:
					ab_opts.append({"label": "%s (MP %d)" % [ab.display_name, ab.mp_cost],
							"enabled": true, "kind": "cast", "ability": ab})
				ab_opts.append({"label": "Back", "enabled": true, "kind": "back"})
				var ab_pick: Dictionary = await _menu(u, "Which ability?", ab_opts)
				if ab_pick.get("kind") != "cast":
					continue
				var ability: AbilityData = ab_pick["ability"]
				var pool := _ability_targets(u, ability)
				var target: CombatUnit = await _pick_target(u, pool)
				if target == null:
					continue
				await _execute_ability(u, target, ability)
				return
			"item":
				var item_pick: Dictionary = await _menu(u,
						"Use which item on %s?" % u.display_name,
						_build_item_options(u))
				if item_pick.get("kind") != "item_choice":
					continue
				await _execute_item(u, item_pick["item_id"])
				return
			"defend":
				u.defending = true
				_log("%s braces behind the shield." % u.display_name)
				await _wait(0.5)
				return
			_:
				_log("%s holds position." % u.display_name)
				await _wait(0.4)
				return


func _ai_turn(u: CombatUnit) -> void:
	# MVP AI (enemies, and party units under auto_play): close on the nearest
	# living foe, basic-attack when in range. Nothing smarter until Stretch.
	u.state = CombatUnit.EntityState.CHECK_RANGE
	var target := _nearest_foe(u)
	if target == null:
		return
	u.state = CombatUnit.EntityState.MOVING
	if _range_between(u.cell, target.cell) > u.attack_range:
		var dest := _ai_step_toward(u, target)
		if dest != u.cell:
			await _walk(u, dest)
	u.state = CombatUnit.EntityState.EXECUTING_COMMAND
	if _range_between(u.cell, target.cell) <= u.attack_range:
		await _execute_attack(u, target, null)
	else:
		_log("%s moves closer." % u.display_name)
		await _wait(0.3)


# ------------------------------------------------------------------ actions

func _execute_attack(atk: CombatUnit, def: CombatUnit, ability: AbilityData) -> void:
	atk.state = CombatUnit.EntityState.EXECUTING_COMMAND
	var power := ability.power if ability != null else 0
	var verb := ability.display_name if ability != null else "attacks"
	if ability != null:
		atk.mp -= ability.mp_cost
		_update_info(atk)
	var threshold := CombatMath.hit_threshold(atk.attack, def.defense, def.defending)
	var needed := CombatMath.needed_roll(threshold)
	var roll := rng.randi_range(1, 10)
	var hit := roll >= needed
	var intro := "%s %s %s!\n%d0%% to hit — roll %d+ on a d10" % [
		atk.display_name,
		("uses %s on" % verb) if ability != null else "attacks",
		def.display_name, threshold, needed]
	_log(intro)
	await _wait(0.6)
	var result := ""
	if hit:
		def.state = CombatUnit.EntityState.TAKING_DAMAGE
		var dmg := CombatMath.attack_damage(atk.attack, def.defense, def.defending, power)
		def.hp = maxi(0, def.hp - dmg)
		_update_info(def)
		_show_popup(def, "-%d" % dmg, Color(1.0, 0.45, 0.35))
		_refresh_hud()
		result = "Rolled %d — HIT!  %d damage.  %s: %d/%d HP." % [
			roll, dmg, def.display_name, def.hp, def.max_hp]
		if def.hp <= 0:
			def.state = CombatUnit.EntityState.DEAD
			def.node.visible = false
			result += "  %s is down!" % def.display_name
	else:
		result = "Rolled %d — MISS!  (needed %d+)" % [roll, needed]
		_show_popup(def, "MISS", Color(0.8, 0.8, 0.9))
	if log_label:
		log_label.text = intro + "\n" + result
	print("[combat] ", result)
	await _wait_for_continue()


func _execute_ability(u: CombatUnit, target: CombatUnit, ability: AbilityData) -> void:
	if ability.target_type == AbilityData.TargetType.ENEMY:
		await _execute_attack(u, target, ability)
		return
	# Support abilities land automatically - no roll on a helping hand.
	u.state = CombatUnit.EntityState.EXECUTING_COMMAND
	u.mp -= ability.mp_cost
	var amount := CombatMath.heal_amount(ability.power)
	target.hp = mini(target.max_hp, target.hp + amount)
	_update_info(u)
	_update_info(target)
	_show_popup(target, "+%d" % amount, Color(0.45, 1.0, 0.6))
	_refresh_hud()
	_log("%s casts %s — %s recovers %d HP (%d/%d)." % [
		u.display_name, ability.display_name, target.display_name,
		amount, target.hp, target.max_hp])
	print("[combat] %s healed %s for %d" % [u.display_name, target.display_name, amount])
	await _wait_for_continue()


## Combat-only item list. The full inventory belongs to Phase 5; this surface
## deliberately includes only consumables with an implemented combat effect.
func _usable_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in SceneManager.inventory:
		var item_id := str(raw_id)
		if int(SceneManager.inventory.get(item_id, 0)) <= 0:
			continue
		var item := ItemLibrary.get_item(item_id)
		if item == null or item.item_type != ItemData.ItemType.CONSUMABLE:
			continue
		if int(item.stat_modifiers.get("heal", 0)) <= 0:
			continue
		ids.append(item_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return ItemLibrary.display_name(a) < ItemLibrary.display_name(b))
	return ids


func _build_item_options(u: CombatUnit) -> Array:
	var opts: Array = []
	for item_id in _usable_item_ids():
		var qty := int(SceneManager.inventory.get(item_id, 0))
		opts.append({
			"label": "%s x%d -> %s" % [ItemLibrary.display_name(item_id), qty,
					u.display_name],
			"enabled": true,
			"kind": "item_choice",
			"item_id": item_id,
		})
	opts.append({"label": "Back", "enabled": true, "kind": "back"})
	return opts


func _execute_item(u: CombatUnit, item_id := "potion") -> void:
	u.state = CombatUnit.EntityState.EXECUTING_COMMAND
	var item := ItemLibrary.get_item(item_id)
	if item == null or item.item_type != ItemData.ItemType.CONSUMABLE \
			or int(item.stat_modifiers.get("heal", 0)) <= 0 \
			or not SceneManager.remove_item(item_id):
		_log("That item cannot be used right now.")
		await _wait(0.4)
		return
	var amount := CombatMath.heal_amount(int(item.stat_modifiers["heal"]))
	u.hp = mini(u.max_hp, u.hp + amount)
	_update_info(u)
	_show_popup(u, "+%d" % amount, Color(0.45, 1.0, 0.6))
	_refresh_hud()
	_log("%s uses %s — recovers %d HP (%d/%d)." % [
		u.display_name, item.display_name, amount, u.hp, u.max_hp])
	print("[combat] %s used %s for %d" % [u.display_name, item_id, amount])
	await _wait_for_continue()


# ----------------------------------------------------------- range and grid

## BFS flood fill: every cell this unit can end its move on (own cell
## included). Blocked terrain and living units are solid.
func _reachable_cells(u: CombatUnit) -> Dictionary:
	var solid := _solid_cells(u)
	var frontier: Array[Vector2i] = [u.cell]
	var cost := {u.cell: 0}
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_front()
		if cost[c] >= u.move_range:
			continue
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= arena_w or n.y >= arena_h:
				continue
			if solid.has(n) or cost.has(n):
				continue
			cost[n] = cost[c] + 1
			frontier.append(n)
	return cost


func _solid_cells(mover: CombatUnit) -> Dictionary:
	var solid := arena_blocked.duplicate()
	for other in units:
		if other != mover and other.alive():
			solid[other.cell] = true
	return solid


func _range_between(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _targets_in_range(u: CombatUnit, reach: int, allies: bool) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for other in units:
		if not other.alive():
			continue
		if allies != (other.is_player == u.is_player):
			continue
		if _range_between(u.cell, other.cell) <= reach:
			out.append(other)
	return out


func _usable_abilities(u: CombatUnit) -> Array[AbilityData]:
	var out: Array[AbilityData] = []
	for ab in u.abilities:
		if u.mp < ab.mp_cost:
			continue
		if _ability_targets(u, ab).is_empty():
			continue
		out.append(ab)
	return out


func _ability_targets(u: CombatUnit, ab: AbilityData) -> Array[CombatUnit]:
	match ab.target_type:
		AbilityData.TargetType.SELF:
			var self_only: Array[CombatUnit] = [u]
			return self_only
		AbilityData.TargetType.ALLY:
			return _targets_in_range(u, ab.attack_range, true)
		_:
			return _targets_in_range(u, ab.attack_range, false)


func _nearest_foe(u: CombatUnit) -> CombatUnit:
	var best: CombatUnit = null
	var best_d := 1 << 30
	for other in units:
		if other.is_player == u.is_player or not other.alive():
			continue
		var d := _range_between(u.cell, other.cell)
		if d < best_d:
			best_d = d
			best = other
	return best


## Best reachable cell that closes distance toward `target` (ideally into
## attack range), via A* truncated to move_range.
func _ai_step_toward(u: CombatUnit, target: CombatUnit) -> Vector2i:
	var solid := _solid_cells(u)
	astar.fill_solid_region(astar.region, false)
	for c in solid:
		astar.set_point_solid(c, true)
	var best_path: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var c: Vector2i = target.cell + d
		if c.x < 0 or c.y < 0 or c.x >= arena_w or c.y >= arena_h or solid.has(c):
			continue
		var path := astar.get_id_path(u.cell, c)
		if path.size() > 1 and (best_path.is_empty() or path.size() < best_path.size()):
			best_path = path
	if best_path.is_empty():
		return u.cell
	return best_path[mini(u.move_range, best_path.size() - 1)]


func _walk(u: CombatUnit, dest: Vector2i) -> void:
	var solid := _solid_cells(u)
	astar.fill_solid_region(astar.region, false)
	for c in solid:
		astar.set_point_solid(c, true)
	var path := astar.get_id_path(u.cell, dest)
	if path.size() < 2:
		u.cell = dest
		u.node.position = _cell_pos(dest)
		return
	for i in range(1, path.size()):
		u.cell = path[i]
		var tw := create_tween()
		tw.tween_property(u.node, "position", _cell_pos(u.cell), 0.02 if auto_play else 0.1)
		await tw.finished


# -------------------------------------------------------------- input flows

func _menu(_u: CombatUnit, prompt: String, opts: Array) -> Dictionary:
	menu_options = opts
	menu_index = 0
	while menu_index < opts.size() - 1 and not opts[menu_index].get("enabled", true):
		menu_index += 1
	prompt_label.text = prompt
	_render_menu()
	_set_menu_visible(true)
	input_mode = InputMode.MENU
	var idx: int = await menu_confirmed
	input_mode = InputMode.NONE
	_set_menu_visible(false)
	return menu_options[idx]


func _pick_cell(start: Vector2i, valid: Dictionary, prompt: String) -> Vector2i:
	cursor_cell = start
	cursor_start = start
	cursor_valid = valid
	prompt_label.text = prompt
	prompt_label.visible = true
	cursor_rect.visible = true
	_move_cursor_to(start)
	input_mode = InputMode.CURSOR_MOVE
	var picked: Vector2i = await cursor_confirmed
	input_mode = InputMode.NONE
	prompt_label.visible = false
	cursor_rect.visible = false
	return picked


## Cycle through eligible targets (up/down), confirm with E, back out with X.
func _pick_target(u: CombatUnit, pool: Array[CombatUnit]) -> CombatUnit:
	if pool.is_empty():
		return null
	var opts: Array = []
	for t in pool:
		opts.append({"label": "%s  (%d/%d HP)" % [t.display_name, t.hp, t.max_hp],
				"enabled": true, "kind": "target", "unit": t})
	opts.append({"label": "Back", "enabled": true, "kind": "back"})
	var pick: Dictionary = await _menu(u, "Choose a target:", opts)
	if pick.get("kind") != "target":
		return null
	return pick["unit"]


func _unhandled_input(event: InputEvent) -> void:
	match input_mode:
		InputMode.CONTINUE:
			if event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				input_mode = InputMode.NONE
				advanced.emit()
		InputMode.MENU:
			_menu_input(event)
		InputMode.CURSOR_MOVE:
			_cursor_input(event)
		_:
			pass


func _menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		menu_index = _next_enabled(menu_index, -1)
		_render_menu()
	elif event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		menu_index = _next_enabled(menu_index, 1)
		_render_menu()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if menu_options[menu_index].get("enabled", true):
			menu_confirmed.emit(menu_index)
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		# B-13: Q backs out only when the menu actually has a Back entry
		# (target/ability/item submenus). On the root command menu the last
		# entry is Wait, and a reflexive Q was silently ending the whole turn -
		# there cancel is now a no-op; ending the turn takes a deliberate
		# confirm on Wait.
		if menu_options[menu_options.size() - 1].get("kind", "") == "back":
			menu_confirmed.emit(menu_options.size() - 1)


func _cursor_input(event: InputEvent) -> void:
	var dir := Vector2i.ZERO
	if event.is_action_pressed("move_up"):
		dir = Vector2i.UP
	elif event.is_action_pressed("move_down"):
		dir = Vector2i.DOWN
	elif event.is_action_pressed("move_left"):
		dir = Vector2i.LEFT
	elif event.is_action_pressed("move_right"):
		dir = Vector2i.RIGHT
	elif event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		cursor_confirmed.emit(cursor_cell)
		return
	elif event.is_action_pressed("cancel"):
		# Q = stay put: back out of the move without spending it.
		get_viewport().set_input_as_handled()
		cursor_confirmed.emit(cursor_start)
		return
	if dir == Vector2i.ZERO:
		return
	get_viewport().set_input_as_handled()
	# Slide within the valid set: try the direct neighbor, else scan onward in
	# that direction so gaps in the highlight don't strand the cursor.
	var probe := cursor_cell + dir
	while probe.x >= 0 and probe.y >= 0 and probe.x < arena_w and probe.y < arena_h:
		if cursor_valid.has(probe):
			_move_cursor_to(probe)
			return
		probe += dir


func _next_enabled(from: int, step: int) -> int:
	var i := from
	for _n in menu_options.size():
		i = (i + step + menu_options.size()) % menu_options.size()
		if menu_options[i].get("enabled", true):
			return i
	return from


# -------------------------------------------------------------------- view

func _build_view() -> void:
	# B-11: panel/label positions derive from the live viewport size (offsets
	# preserve the original 1280x720 layout exactly at 16:9).
	var vs := get_viewport_rect().size
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	for y in arena_h:
		for x in arena_w:
			var c := Vector2i(x, y)
			var t := ColorRect.new()
			if arena_blocked.has(c):
				# Terrain carried in from the overworld (D-012): read as an
				# obstacle, same palette family as the forest walls.
				t.color = Color(0.10, 0.16, 0.10)
			else:
				t.color = Color(0.18, 0.24, 0.18) if (x + y) % 2 == 0 else Color(0.16, 0.21, 0.16)
			t.position = arena_origin + Vector2(c) * TILE + Vector2(1, 1)
			t.size = Vector2(TILE - 2, TILE - 2)
			layer.add_child(t)
	highlight_root = Control.new()
	layer.add_child(highlight_root)
	for u in units:
		u.node = Node2D.new()
		u.node.position = _cell_pos(u.cell)
		if u.sprite_frames != null:
			var sprite := AnimatedSprite2D.new()
			sprite.name = "RuntimeSprite"
			sprite.sprite_frames = u.sprite_frames
			sprite.animation = &"idle"
			sprite.scale = Vector2.ONE * (0.58 if u.is_player else (0.68 if u.is_boss else 0.56))
			sprite.z_index = 2
			u.node.add_child(sprite)
			sprite.play()
		elif u.is_player:
			var rect := ColorRect.new()
			# Hero blue; companions teal so the party reads as two people.
			rect.color = Color(0.25, 0.5, 0.95) if u.unit_id == "hero" \
					else Color(0.2, 0.8, 0.75)
			rect.position = Vector2(-24, -24)
			rect.size = Vector2(48, 48)
			u.node.add_child(rect)
		else:
			var tri := Polygon2D.new()
			var s := 30.0 if u.is_boss else 24.0
			tri.polygon = PackedVector2Array([
				Vector2(0, -s), Vector2(s, s), Vector2(-s, s)])
			tri.color = Color(0.55, 0.08, 0.12) if u.is_boss else Color(0.85, 0.18, 0.18)
			u.node.add_child(tri)
		u.info = Label.new()
		if u.sprite_frames != null:
			u.info.position = Vector2(38, -30) if u.is_player else Vector2(-145, -30)
		else:
			u.info.position = Vector2(-40, -74 if u.is_player else -50)
		u.info.add_theme_font_size_override("font_size", 15)
		u.node.add_child(u.info)
		_update_info(u)
		# B-10: a unit that enters the battle already at 0 HP (a companion who
		# fell last fight) must not stand on the field looking alive.
		if not u.alive():
			u.state = CombatUnit.EntityState.DEAD
			u.node.visible = false
		layer.add_child(u.node)
	cursor_rect = ColorRect.new()
	cursor_rect.color = Color(1, 1, 0.6, 0.35)
	cursor_rect.size = Vector2(TILE - 6, TILE - 6)
	cursor_rect.visible = false
	layer.add_child(cursor_rect)
	log_label = Label.new()
	log_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	log_label.offset_top = 40.0
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(log_label)
	round_label = Label.new()
	round_label.position = Vector2(40, 40)
	round_label.add_theme_font_size_override("font_size", 20)
	round_label.modulate = Color(0.8, 0.8, 0.9)
	layer.add_child(round_label)
	turn_order_label = Label.new()
	turn_order_label.position = Vector2(40, 68)
	turn_order_label.add_theme_font_size_override("font_size", 17)
	turn_order_label.modulate = Color(0.95, 0.9, 0.7)
	layer.add_child(turn_order_label)
	party_status_label = Label.new()
	party_status_label.position = Vector2(vs.x - 480, 38)
	party_status_label.add_theme_font_size_override("font_size", 17)
	party_status_label.modulate = Color(0.78, 0.9, 1.0)
	layer.add_child(party_status_label)
	menu_panel = ColorRect.new()
	menu_panel.color = Color(0.05, 0.04, 0.09, 0.82)
	menu_panel.position = Vector2(56, vs.y - 240)
	menu_panel.size = Vector2(420, 210)
	menu_panel.visible = false
	layer.add_child(menu_panel)
	prompt_label = Label.new()
	prompt_label.position = Vector2(76, vs.y - 228)
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.modulate = Color(1, 0.95, 0.7)
	prompt_label.visible = false
	layer.add_child(prompt_label)
	menu_label = Label.new()
	menu_label.position = Vector2(92, vs.y - 186)
	menu_label.add_theme_font_size_override("font_size", 24)
	menu_label.visible = false
	layer.add_child(menu_label)
	continue_label = Label.new()
	continue_label.position = Vector2(432, vs.y - 254)
	continue_label.add_theme_font_size_override("font_size", 22)
	continue_label.modulate = Color(0.75, 1.0, 0.75)
	# B-09: E only - Space is the benched traversal action (D-022) and was
	# never accepted by the CONTINUE handler; prompts are keyboard-only (D-019).
	continue_label.text = "▶  Press E to continue"
	continue_label.visible = false
	layer.add_child(continue_label)
	_refresh_hud()


func _show_highlights(cells: Array, color: Color) -> void:
	for c in cells:
		var r := ColorRect.new()
		r.color = color
		r.position = arena_origin + Vector2(c) * TILE + Vector2(3, 3)
		r.size = Vector2(TILE - 6, TILE - 6)
		highlight_root.add_child(r)


## Red fringe: foes this unit could reach with its basic attack from at
## least one highlighted cell - the FE "threat" read at a glance.
func _show_attack_fringe(u: CombatUnit, reachable: Dictionary) -> void:
	for other in units:
		if other.is_player == u.is_player or not other.alive():
			continue
		for c in reachable:
			if _range_between(c, other.cell) <= u.attack_range:
				_show_highlights([other.cell], Color(1.0, 0.25, 0.2, 0.4))
				break


func _clear_highlights() -> void:
	for child in highlight_root.get_children():
		child.queue_free()


func _move_cursor_to(c: Vector2i) -> void:
	cursor_cell = c
	cursor_rect.position = arena_origin + Vector2(c) * TILE + Vector2(3, 3)


func _set_menu_visible(v: bool) -> void:
	menu_panel.visible = v
	prompt_label.visible = v
	menu_label.visible = v


func _render_menu() -> void:
	var text := ""
	for i in menu_options.size():
		var o: Dictionary = menu_options[i]
		var line: String = o.get("label", "?")
		if not o.get("enabled", true):
			line += "  (—)"
		text += ("▶ " if i == menu_index else "    ") + line + "\n"
	menu_label.text = text


func _cell_pos(c: Vector2i) -> Vector2:
	return arena_origin + Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5


func _update_info(u: CombatUnit) -> void:
	if u.info == null:
		return
	var line := "%s %d/%d" % [u.display_name, u.hp, u.max_hp]
	if u.is_player and u.max_mp > 0:
		line += "  MP %d/%d" % [u.mp, u.max_mp]
	u.info.text = line


func _turn_order_text() -> String:
	var names := PackedStringArray()
	for u in tm.build_order():
		names.append(u.display_name)
	return "Turn order: " + " -> ".join(names)


func _refresh_hud() -> void:
	if turn_order_label:
		turn_order_label.text = _turn_order_text()
	if party_status_label:
		var rows := PackedStringArray()
		for u in units:
			if u.is_player:
				# B-10: a downed party member reads as DOWN, not as a live row.
				if u.hp <= 0:
					rows.append("%s  DOWN" % u.display_name)
				else:
					rows.append("%s  HP %d/%d  MP %d/%d" % [
						u.display_name, u.hp, u.max_hp, u.mp, u.max_mp])
		party_status_label.text = "\n".join(rows)


func _show_popup(u: CombatUnit, text: String, color: Color) -> void:
	if layer == null or u.node == null:
		return
	var popup := Label.new()
	popup.text = text
	popup.position = u.node.position + Vector2(-18, -100)
	popup.add_theme_font_size_override("font_size", 22)
	popup.modulate = color
	layer.add_child(popup)
	var tw := create_tween()
	tw.tween_property(popup, "position:y", popup.position.y - 28.0,
				0.04 if auto_play else 0.45)
	tw.parallel().tween_property(popup, "modulate:a", 0.0,
				0.04 if auto_play else 0.45)
	tw.tween_callback(popup.queue_free)


func _log(msg: String) -> void:
	if log_label:
		log_label.text = msg
	print("[combat] ", msg)


func _wait(t: float) -> void:
	await get_tree().create_timer(0.02 if auto_play else t).timeout


## Pause until the player acknowledges the result (so rolls stay readable).
## Skipped during auto_play (headless smoke test).
func _wait_for_continue() -> void:
	if auto_play:
		await _wait(0.2)
		return
	continue_label.visible = true
	input_mode = InputMode.CONTINUE
	await advanced
	continue_label.visible = false
