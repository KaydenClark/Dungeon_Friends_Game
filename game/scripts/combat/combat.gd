class_name CombatScene
extends Node2D
## Minimal grid-based turn-based combat MVP (walking-skeleton version of the
## Phase 4 combat system - see /BLUEPRINT.md -> Core Logic And Invariants):
## - all combatants sorted by speed each round, strict per-unit initiative
##   (TurnManager behavior; never a whole-team phase);
## - units occupy arena cells, move via AStarGrid2D (no diagonals) up to
##   MOVE_RANGE, melee = adjacent tile;
## - d10 percentage resolution: roll 1-10, hit on a HIGH roll at/above a
##   stat-derived target (roll-high-good; see _attack).
## The threshold/damage formula below is a PLACEHOLDER pending the Phase 3/4
## red/green combat-math implementation; the full two-layer FSM and
## Attack/Ability/Item/Defend menu land in Phase 4. Rendering is screen-space
## (CanvasLayer) so the overworld camera doesn't affect it.

signal finished(victory: bool, hero_hp: int)
signal choice_made(action: String)

const TILE := 64
const ARENA_W := 9
const ARENA_H := 5
const MOVE_RANGE := 3
const ARENA_ORIGIN := Vector2(352, 184)

# Pokemon-style two-tier command menu. Root asks the verb; picking Fight opens
# the move list. (One move for this demo; Ability/Item slots arrive in Phase 4.)
const ROOT_OPTIONS := ["Fight", "Defend"]
const MOVE_OPTIONS := ["Swing Sword", "Back"]


## Pure d10 combat math (Phase 3/4 red-green target - see RUNBOOK -> Test
## Coverage Policy). Extracted as static functions so the hit/damage rules can
## be unit tested without standing up the whole combat scene. _attack() below
## is the only caller; keep the two in sync.

## Percent-to-hit tier (also the tens digit shown to the player): 5 + attack
## - defense, minus 2 when the defender is bracing, clamped to a 10%..90% band
## so nothing is ever a guaranteed hit or a certain miss.
static func hit_threshold(attack: int, defense: int, defending: bool) -> int:
	return clampi(5 + attack - defense - (2 if defending else 0), 1, 9)


## The d10 value the attacker must meet or beat (roll-high-good): a 70% tier
## (threshold 7) means "roll a 4 or higher".
static func needed_roll(threshold: int) -> int:
	return 11 - threshold


## Damage on a hit: attack minus half the defender's defense (min 1), then
## halved again (min 1) when the defender is bracing.
static func attack_damage(attack: int, defense: int, defending: bool) -> int:
	var dmg := maxi(1, attack - int(defense / 2.0))
	if defending:
		dmg = maxi(1, int(dmg / 2.0))
	return dmg


class CombatUnit:
	var display_name := ""
	var attack := 0
	var defense := 0
	var speed := 0
	var max_hp := 0
	var hp := 0
	var cell := Vector2i.ZERO
	var is_player := false
	var is_boss := false
	var defending := false
	var node: Node2D
	var info: Label


var units: Array[CombatUnit] = []
var rng: RandomNumberGenerator
var auto_play := false
var battle_over := false
var awaiting_choice := false
var awaiting_continue := false
var menu_level := 0    # 0 = root (Fight/Defend), 1 = move list
var menu_index := 0
var _active_hero: CombatUnit
var astar := AStarGrid2D.new()
var layer: CanvasLayer
var log_label: Label
var menu_panel: ColorRect
var prompt_label: Label
var menu_label: Label
var continue_label: Label


func setup(hero: CharacterStats, hero_hp: int, enemy: EnemyStats,
		p_rng: RandomNumberGenerator, p_auto: bool) -> void:
	rng = p_rng
	auto_play = p_auto
	var h := CombatUnit.new()
	h.display_name = hero.display_name
	h.attack = hero.attack
	h.defense = hero.defense
	h.speed = hero.speed
	h.max_hp = hero.max_hp
	h.hp = hero_hp
	h.cell = Vector2i(2, 2)
	h.is_player = true
	units.append(h)
	var e := CombatUnit.new()
	e.display_name = enemy.display_name
	e.attack = enemy.attack
	e.defense = enemy.defense
	e.speed = enemy.speed
	e.max_hp = enemy.max_hp
	e.hp = enemy.max_hp
	e.cell = Vector2i(6, 2)
	e.is_boss = enemy.id == "boss_slime"
	units.append(e)


func _ready() -> void:
	astar.region = Rect2i(0, 0, ARENA_W, ARENA_H)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	_build_view()
	_run_battle()


func _build_view() -> void:
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	for y in ARENA_H:
		for x in ARENA_W:
			var t := ColorRect.new()
			t.color = Color(0.18, 0.24, 0.18) if (x + y) % 2 == 0 else Color(0.16, 0.21, 0.16)
			t.position = ARENA_ORIGIN + Vector2(x, y) * TILE + Vector2(1, 1)
			t.size = Vector2(TILE - 2, TILE - 2)
			layer.add_child(t)
	for u in units:
		u.node = Node2D.new()
		u.node.position = _cell_pos(u.cell)
		if u.is_player:
			var rect := ColorRect.new()
			rect.color = Color(0.25, 0.5, 0.95)
			rect.position = Vector2(-24, -24)
			rect.size = Vector2(48, 48)
			u.node.add_child(rect)
		else:
			# Same placeholder language as the overworld: enemies are red
			# triangles (the boss bigger and darker), so combat matches the map.
			var tri := Polygon2D.new()
			var s := 30.0 if u.is_boss else 24.0
			tri.polygon = PackedVector2Array([
				Vector2(0, -s), Vector2(s, s), Vector2(-s, s)])
			tri.color = Color(0.55, 0.08, 0.12) if u.is_boss else Color(0.85, 0.18, 0.18)
			u.node.add_child(tri)
		u.info = Label.new()
		# Stagger the hero's readout higher than the enemy's so the two labels
		# never collide when the units stand on adjacent cells.
		u.info.position = Vector2(-40, -74 if u.is_player else -50)
		u.info.add_theme_font_size_override("font_size", 15)
		u.node.add_child(u.info)
		_update_info(u)
		layer.add_child(u.node)
	log_label = Label.new()
	log_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	log_label.offset_top = 40.0
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(log_label)
	# Command menu (bottom-left), hidden until it's the hero's turn.
	menu_panel = ColorRect.new()
	menu_panel.color = Color(0.05, 0.04, 0.09, 0.82)
	menu_panel.position = Vector2(56, 516)
	menu_panel.size = Vector2(372, 168)
	menu_panel.visible = false
	layer.add_child(menu_panel)
	prompt_label = Label.new()
	prompt_label.position = Vector2(76, 528)
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.modulate = Color(1, 0.95, 0.7)
	prompt_label.visible = false
	layer.add_child(prompt_label)
	menu_label = Label.new()
	menu_label.position = Vector2(92, 574)
	menu_label.add_theme_font_size_override("font_size", 26)
	menu_label.visible = false
	layer.add_child(menu_label)
	# Shown after each attack resolves; play pauses here so the roll and damage
	# stay on screen until the player presses confirm/interact.
	continue_label = Label.new()
	continue_label.position = Vector2(432, 466)
	continue_label.add_theme_font_size_override("font_size", 22)
	continue_label.modulate = Color(0.75, 1.0, 0.75)
	continue_label.text = "▶  Press E to continue"
	continue_label.visible = false
	layer.add_child(continue_label)


func _run_battle() -> void:
	await _wait(0.3)
	_log("Battle start!")
	await _wait(0.6)
	# CalculateInitiative: every combatant sorted together by speed - strict
	# per-unit order, never a whole-team phase (locked decision).
	var order := units.duplicate()
	order.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool: return a.speed > b.speed)
	while not battle_over:
		for u in order:
			if battle_over:
				break
			if u.hp <= 0:
				continue
			u.defending = false
			await _take_turn(u)
	var hero := _hero_unit()
	var victory := hero.hp > 0
	_log("Victory!" if victory else "Defeat...")
	await _wait(0.8)
	finished.emit(victory, hero.hp)


func _take_turn(u: CombatUnit) -> void:
	_log("%s's turn." % u.display_name)
	await _wait(0.4)
	var action := "attack"
	if u.is_player and not auto_play:
		action = await _player_choose(u)
	if action == "defend":
		u.defending = true
		_log("%s braces for impact." % u.display_name)
		await _wait(0.5)
		return
	# Step in, swing, step back to their own side, so each turn reads as a
	# discrete attack rather than units drifting together into a clump.
	var home := u.cell
	var target := _foe_of(u)
	await _approach(u, target)
	if _adjacent(u.cell, target.cell):
		await _attack(u, target)
	else:
		_log("%s moves closer." % u.display_name)
		await _wait(0.4)
	if not battle_over and u.hp > 0:
		await _return_to(u, home)


func _player_choose(u: CombatUnit) -> String:
	awaiting_choice = true
	_active_hero = u
	menu_level = 0
	menu_index = 0
	_update_menu()
	_set_menu_visible(true)
	# Returns "attack" (Swing Sword) or "defend"; navigation between the two
	# tiers is handled entirely in _unhandled_input.
	var action: String = await choice_made
	_set_menu_visible(false)
	awaiting_choice = false
	return action


func _unhandled_input(event: InputEvent) -> void:
	if awaiting_continue:
		if event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			awaiting_continue = false
		return
	if not awaiting_choice:
		return
	var opts: Array = ROOT_OPTIONS if menu_level == 0 else MOVE_OPTIONS
	if event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		menu_index = (menu_index - 1 + opts.size()) % opts.size()
		_update_menu()
	elif event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		menu_index = (menu_index + 1) % opts.size()
		_update_menu()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_confirm_menu()
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		if menu_level == 1:  # back out of the move list to the root
			menu_level = 0
			menu_index = 0
			_update_menu()


func _confirm_menu() -> void:
	if menu_level == 0:
		if menu_index == 0:  # Fight -> open the move list
			menu_level = 1
			menu_index = 0
			_update_menu()
		else:  # Defend
			choice_made.emit("defend")
	else:
		if menu_index == 0:  # Swing Sword
			choice_made.emit("attack")
		else:  # Back -> return to the root menu
			menu_level = 0
			menu_index = 0
			_update_menu()


func _set_menu_visible(v: bool) -> void:
	menu_panel.visible = v
	prompt_label.visible = v
	menu_label.visible = v


func _update_menu() -> void:
	var opts: Array = ROOT_OPTIONS if menu_level == 0 else MOVE_OPTIONS
	var hero_name := _active_hero.display_name if _active_hero else "Hero"
	prompt_label.text = "What will %s do?" % hero_name if menu_level == 0 \
			else "%s — choose a move:" % hero_name
	var text := ""
	for i in opts.size():
		text += ("▶ " if i == menu_index else "    ") + str(opts[i]) + "\n"
	menu_label.text = text


func _approach(u: CombatUnit, target: CombatUnit) -> void:
	if _adjacent(u.cell, target.cell):
		return
	# Other living units are solid; path to the best free cell adjacent to
	# the target, then advance up to MOVE_RANGE cells.
	astar.fill_solid_region(astar.region, false)
	for other in units:
		if other != u and other.hp > 0:
			astar.set_point_solid(other.cell, true)
	var best: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var c: Vector2i = target.cell + d
		if not astar.region.has_point(c) or astar.is_point_solid(c):
			continue
		var path := astar.get_id_path(u.cell, c)
		if path.size() > 0 and (best.is_empty() or path.size() < best.size()):
			best = path
	if best.size() < 2:
		return
	var steps: int = mini(MOVE_RANGE, best.size() - 1)
	for i in range(1, steps + 1):
		u.cell = best[i]
		var tw := create_tween()
		tw.tween_property(u.node, "position", _cell_pos(u.cell), 0.02 if auto_play else 0.12)
		await tw.finished


func _return_to(u: CombatUnit, home: Vector2i) -> void:
	if u.cell == home:
		return
	# Path back over the now-current occupancy (the foe may have moved).
	astar.fill_solid_region(astar.region, false)
	for other in units:
		if other != u and other.hp > 0:
			astar.set_point_solid(other.cell, true)
	var path := astar.get_id_path(u.cell, home)
	if path.size() < 2:
		u.cell = home  # boxed out of a clean path - snap home so state stays sane
		var snap := create_tween()
		snap.tween_property(u.node, "position", _cell_pos(home), 0.02 if auto_play else 0.12)
		await snap.finished
		return
	for i in range(1, path.size()):
		u.cell = path[i]
		var tw := create_tween()
		tw.tween_property(u.node, "position", _cell_pos(u.cell), 0.02 if auto_play else 0.10)
		await tw.finished


func _attack(atk: CombatUnit, def: CombatUnit) -> void:
	# PLACEHOLDER d10 formula (Phase 3/4 decides the real one, red/green):
	# threshold = 5 + attack - defense (-2 if defending), clamped 1..9; it is
	# the percent chance to hit (7 -> 70%). You roll a d10 and HIT ON A HIGH
	# ROLL - you need to roll `needed` (= 11 - threshold) or higher. So a 70%
	# chance means "roll a 4 or higher". (Revised 2026-07-05: this used to be a
	# roll-UNDER check, which read as backwards - low rolls hitting - during
	# playtest; flipped to roll-high-good, same odds.)
	var threshold := hit_threshold(atk.attack, def.defense, def.defending)
	var needed := needed_roll(threshold)
	var roll := rng.randi_range(1, 10)
	var hit := roll >= needed
	# Two-beat reveal, but keep the attack line + odds on screen so that at the
	# continue prompt the whole exchange is visible together (who attacked, the
	# odds, the roll, hit/miss, damage) - nothing flashes away before you read it.
	var intro := "%s attacks %s!\n%d0%% to hit — roll %d+ on a d10" % [
		atk.display_name, def.display_name, threshold, needed]
	_log(intro)
	await _wait(0.6)
	var result := ""
	if hit:
		var dmg := attack_damage(atk.attack, def.defense, def.defending)
		def.hp = maxi(0, def.hp - dmg)
		_update_info(def)
		result = "Rolled %d — HIT!  %d damage.  %s: %d/%d HP." % [
			roll, dmg, def.display_name, def.hp, def.max_hp]
		if def.hp <= 0:
			def.node.visible = false
			battle_over = true
	else:
		result = "Rolled %d — MISS!  (needed %d+)" % [roll, needed]
	# Append the result under the intro (don't replace it) and hold for continue.
	if log_label:
		log_label.text = intro + "\n" + result
	print("[combat] ", result)
	await _wait_for_continue()


func _foe_of(u: CombatUnit) -> CombatUnit:
	for other in units:
		if other.is_player != u.is_player and other.hp > 0:
			return other
	return null


func _hero_unit() -> CombatUnit:
	for u in units:
		if u.is_player:
			return u
	return null


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _cell_pos(c: Vector2i) -> Vector2:
	return ARENA_ORIGIN + Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5


func _update_info(u: CombatUnit) -> void:
	u.info.text = "%s %d/%d" % [u.display_name, u.hp, u.max_hp]


func _log(msg: String) -> void:
	if log_label:
		log_label.text = msg
	print("[combat] ", msg)


func _wait(t: float) -> void:
	await get_tree().create_timer(0.02 if auto_play else t).timeout


## Pause until the player acknowledges the attack result (so they can read the
## roll and damage). Skipped during auto_play (headless smoke test).
func _wait_for_continue() -> void:
	if auto_play:
		await _wait(0.2)
		return
	continue_label.visible = true
	awaiting_continue = true
	while awaiting_continue:
		await get_tree().process_frame
	continue_label.visible = false
