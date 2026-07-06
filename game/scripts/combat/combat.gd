class_name CombatScene
extends Node2D
## Minimal grid-based turn-based combat MVP (walking-skeleton version of the
## Phase 4 combat system - see /BLUEPRINT.md -> Core Logic And Invariants):
## - all combatants sorted by speed each round, strict per-unit initiative
##   (TurnManager behavior; never a whole-team phase);
## - units occupy arena cells, move via AStarGrid2D (no diagonals) up to
##   MOVE_RANGE, melee = adjacent tile;
## - d10 percentage resolution: roll 1-10 vs a stat-derived threshold.
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


class CombatUnit:
	var display_name := ""
	var attack := 0
	var defense := 0
	var speed := 0
	var max_hp := 0
	var hp := 0
	var cell := Vector2i.ZERO
	var is_player := false
	var defending := false
	var node: Node2D
	var info: Label


var units: Array[CombatUnit] = []
var rng: RandomNumberGenerator
var auto_play := false
var battle_over := false
var awaiting_choice := false
var menu_index := 0
var astar := AStarGrid2D.new()
var layer: CanvasLayer
var log_label: Label
var menu_label: Label


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
		var rect := ColorRect.new()
		rect.color = Color(0.25, 0.5, 0.95) if u.is_player else Color(0.62, 0.3, 0.72)
		rect.position = Vector2(-24, -24)
		rect.size = Vector2(48, 48)
		u.node.add_child(rect)
		u.info = Label.new()
		u.info.position = Vector2(-40, -56)
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
	menu_label = Label.new()
	menu_label.position = Vector2(80, 560)
	menu_label.add_theme_font_size_override("font_size", 26)
	menu_label.visible = false
	layer.add_child(menu_label)


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
		action = await _player_choose()
	if action == "defend":
		u.defending = true
		_log("%s braces for impact." % u.display_name)
		await _wait(0.5)
		return
	var target := _foe_of(u)
	await _approach(u, target)
	if _adjacent(u.cell, target.cell):
		await _attack(u, target)
	else:
		_log("%s moves closer." % u.display_name)
		await _wait(0.4)


func _player_choose() -> String:
	awaiting_choice = true
	menu_index = 0
	_update_menu()
	menu_label.visible = true
	var action: String = await choice_made
	menu_label.visible = false
	awaiting_choice = false
	return action


func _unhandled_input(event: InputEvent) -> void:
	if not awaiting_choice:
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		menu_index = 1 - menu_index
		_update_menu()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		choice_made.emit("attack" if menu_index == 0 else "defend")


func _update_menu() -> void:
	menu_label.text = "▶ Attack\n   Defend" if menu_index == 0 else "   Attack\n▶ Defend"


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


func _attack(atk: CombatUnit, def: CombatUnit) -> void:
	# PLACEHOLDER d10 formula (Phase 3/4 decides the real one, red/green):
	# threshold = 5 + attack - defense (-2 if defending), clamped 1..9;
	# a threshold of 7 reads as a 70% chance to hit.
	var threshold := clampi(5 + atk.attack - def.defense - (2 if def.defending else 0), 1, 9)
	var roll := rng.randi_range(1, 10)
	_log("%s attacks %s (%d0%% to hit)... rolled %d." % [
		atk.display_name, def.display_name, threshold, roll])
	await _wait(0.7)
	if roll <= threshold:
		var dmg := maxi(1, atk.attack - int(def.defense / 2.0))
		if def.defending:
			dmg = maxi(1, int(dmg / 2.0))
		def.hp = maxi(0, def.hp - dmg)
		_update_info(def)
		_log("Hit! %d damage. %s: %d/%d HP." % [dmg, def.display_name, def.hp, def.max_hp])
		if def.hp <= 0:
			def.node.visible = false
			battle_over = true
	else:
		_log("Miss!")
	await _wait(0.7)


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
