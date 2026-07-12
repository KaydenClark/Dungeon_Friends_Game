extends "res://scripts/dev/three_quarter_spike.gd"
## T-090 pivot spike: the unified in-room encounter (D-025's core claim -
## the same room IS the battlefield). Builds directly inside the T-089 room:
## a slime waits on the plateau; walking into its detection range (or bumping
## it) starts an encounter IN PLACE - no scene change, no zoom, no camera
## move. Followers snap onto their current cells and become real blocking
## occupants (D-020 survives in-encounter); the first friend fights alongside
## the hero. After victory the overworld is simply continuous: same room
## instance, resolved enemy gone, pushed puzzle blocks exactly where they
## were pushed.
##
## Turn model here is a deliberately dumb step-tick (hero acts -> friend AI
## acts -> enemy AI acts). It is NOT intent rounds and NOT the v1 initiative
## system - T-092 owns the D-027 turn-structure decision. Damage is already
## deterministic per D-026's first-cut formula: max(1, atk - def).
##
## Interactive: walk into the slime's range; bump it to attack. Proof shots:
##   godot --path game scenes/dev/unified_encounter_spike.tscn \
##       --resolution 1280x720 -- --out=<dir>

const ENEMY_CELL := Vector2i(5, 2)
const BLOCK_CELL := Vector2i(9, 6)
## Manhattan cells at which the slime notices the party ("they entered the
## same zone and spotted you" - detection, not just touch).
const DETECT_RANGE := 2

enum Mode { EXPLORE, ENCOUNTER }

var mode: int = Mode.EXPLORE
var busy := false
var enemy_actor: GridActor
var block: PushableBlock
var stats := {}   # GridActor -> {hp, max_hp, atk, df, label(Label), unit_name}
var tour_log: Array[String] = []


class EncounterLeader extends GridActor:
	var host


	func _on_bump(occ: Node2D) -> void:
		host._leader_bumped(occ)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	floor_low = load(TEX_FLOOR_LOW)
	floor_high = load(TEX_FLOOR_HIGH)
	_build_room()
	_spawn_party()
	_spawn_enemy()
	_spawn_block()
	_add_camera()
	print("UNIFIED ENCOUNTER SPIKE: ready (in-room encounter, no scene change)")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _scripted_tour()
		for line in tour_log:
			print(line)
		var failed := tour_log.filter(func(l: String) -> bool: return l.begins_with("FAIL"))
		print("UNIFIED ENCOUNTER SPIKE: %s -> %s" % \
				["FAIL" if failed.size() > 0 else "done", out_dir])
		get_tree().quit(1 if failed.size() > 0 else 0)
	else:
		_add_hint()


func _process(_delta: float) -> void:
	if out_dir != "" or busy or leader == null or leader.moving:
		return
	for action: String in DIR_ACTIONS:
		if Input.is_action_pressed(action):
			_player_act(DIR_ACTIONS[action])
			break


## --- party/actor construction (T-089 overrides) -----------------------------

## Same party as T-089, but the leader reports bumps back to the spike (block
## pushes + attacks) and followers are GridActors so they can occupy cells
## and step during encounters. They still never enter the occupancy map in
## exploration (D-029 non-blocking).
func _spawn_party() -> void:
	var l := EncounterLeader.new()
	l.host = self
	l.name = "Leader"
	l.move_time = MOVE_TIME
	if not l._make_sprite(load("res://data/sprites/kenney_hero.tres")):
		l._make_body(Color(0.3, 0.8, 1.0))
	leader = l
	_add_foot_shadow(leader)
	room.register(leader, LEADER_START)

	for i in FOLLOWER_STARTS.size():
		var f := GridActor.new()
		f.name = "Follower%d" % (i + 1)
		f.move_time = MOVE_TIME
		_add_foot_shadow(f)
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = load(FOLLOWER_TEXTURES[i])
		sprite.scale = Vector2(4.0, 4.0)
		f.add_child(sprite)
		f.body = sprite
		f.room = room
		f.cell = FOLLOWER_STARTS[i]
		f.position = room.cell_to_pos(FOLLOWER_STARTS[i])
		room.add_child(f)
		followers.append(f)
		follower_tweens.append(null)
		trail.append(FOLLOWER_STARTS[i])


## Track the breadcrumb cell on the follower itself so the encounter snap
## knows exactly which cell each follower claims.
func _glide_follower(i: int, c: Vector2i) -> void:
	followers[i].cell = c
	super._glide_follower(i, c)


func _spawn_enemy() -> void:
	enemy_actor = GridActor.new()
	enemy_actor.name = "Slime"
	enemy_actor.move_time = MOVE_TIME
	if not enemy_actor._make_sprite(load("res://data/sprites/kenney_forest_slime.tres")):
		enemy_actor._make_body(Color(0.9, 0.25, 0.25))
	_add_foot_shadow(enemy_actor)
	room.register(enemy_actor, ENEMY_CELL)
	stats[enemy_actor] = {"hp": 12, "max_hp": 12, "atk": 3, "df": 1,
			"label": null, "unit_name": "Slime"}


func _spawn_block() -> void:
	block = PushableBlock.new()
	block.name = "SpikeBlock"
	block.move_time = MOVE_TIME
	room.register(block, BLOCK_CELL)


func _add_hint() -> void:
	var ui := CanvasLayer.new()
	var label := Label.new()
	label.text = "T-090 unified encounter spike - WASD/arrows move, bump to push or attack.\nWalk near the slime on the plateau: the encounter starts in this room, no scene change."
	label.position = Vector2(12, 8)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	ui.add_child(label)
	add_child(ui)


## --- exploration / encounter switching --------------------------------------

## One player input = one action. In exploration that is a plain leader step
## (followers breadcrumb behind); in an encounter every hero step or bump-
## attack advances one tick: friend AI acts, then the enemy acts.
func _player_act(dir: Vector2i) -> void:
	busy = true
	var acted := false
	if mode == Mode.EXPLORE:
		acted = _try_leader_step(dir)
		if acted:
			await leader.move_finished
			_check_detection()
	else:
		acted = leader.try_step(dir)
		if acted:
			await leader.move_finished
		elif _adjacent(leader.cell, enemy_actor.cell) \
				and leader.cell + dir == enemy_actor.cell:
			await _attack(leader, enemy_actor)
			acted = true
		if acted and mode == Mode.ENCOUNTER:
			await _ally_tick()
			await _enemy_tick()
	busy = false


func _leader_bumped(occ: Node2D) -> void:
	if occ is PushableBlock and mode == Mode.EXPLORE:
		occ.try_push(leader.facing)
	# Direct contact with the enemy starts the fight even before detection.
	elif occ == enemy_actor and mode == Mode.EXPLORE:
		_start_encounter()


func _check_detection() -> void:
	if mode == Mode.EXPLORE and enemy_actor != null \
			and _manhattan(leader.cell, enemy_actor.cell) <= DETECT_RANGE:
		_start_encounter()


func _start_encounter() -> void:
	mode = Mode.ENCOUNTER
	# Followers snap onto their current breadcrumb cells and become real
	# blocking occupants - D-020's ally collision survives in-encounter.
	for i in followers.size():
		if follower_tweens[i] != null and follower_tweens[i].is_valid():
			follower_tweens[i].kill()
		var f := followers[i] as GridActor
		f.position = room.cell_to_pos(f.cell)
		room.occupy(f, f.cell)
	stats[leader] = {"hp": 20, "max_hp": 20, "atk": 5, "df": 2,
			"label": null, "unit_name": "Hero"}
	stats[followers[0]] = {"hp": 14, "max_hp": 14, "atk": 4, "df": 1,
			"label": null, "unit_name": "Friend"}
	for unit: GridActor in stats:
		_attach_hp_label(unit)
	print("UNIFIED ENCOUNTER SPIKE: encounter started in-room at leader ",
			leader.cell)


## The fighting friend (follower 1). Followers 2/3 stand as blockers only.
func _ally_tick() -> void:
	if mode != Mode.ENCOUNTER:
		return
	var friend := followers[0] as GridActor
	if _adjacent(friend.cell, enemy_actor.cell):
		await _attack(friend, enemy_actor)
		return
	var path := room.find_path(friend.cell, enemy_actor.cell, true)
	if path.size() > 2:
		if friend.try_step(path[1] - friend.cell):
			await friend.move_finished


func _enemy_tick() -> void:
	if mode != Mode.ENCOUNTER:
		return
	for _step in 2:
		var target := _nearest_player_unit()
		if _adjacent(enemy_actor.cell, target.cell):
			await _attack(enemy_actor, target)
			return
		var path := room.find_path(enemy_actor.cell, target.cell, true)
		if path.size() > 2:
			if enemy_actor.try_step(path[1] - enemy_actor.cell):
				await enemy_actor.move_finished
		else:
			return


func _nearest_player_unit() -> GridActor:
	var friend := followers[0] as GridActor
	if _manhattan(enemy_actor.cell, friend.cell) \
			< _manhattan(enemy_actor.cell, leader.cell):
		return friend
	return leader


## D-026's first-cut deterministic damage: max(1, atk - def). No rolls.
func _attack(attacker: GridActor, defender: GridActor) -> void:
	var dmg: int = maxi(1, int(stats[attacker]["atk"]) - int(stats[defender]["df"]))
	stats[defender]["hp"] = int(stats[defender]["hp"]) - dmg
	_popup(defender, "-%d" % dmg)
	_refresh_hp_label(defender)
	defender.modulate = Color(1.0, 0.5, 0.5)
	await _frames(8)
	defender.modulate = Color.WHITE
	if int(stats[defender]["hp"]) <= 0:
		if defender == enemy_actor:
			await _resolve_victory()
		else:
			print("UNIFIED ENCOUNTER SPIKE: party defeated (unexpected in spike)")


func _resolve_victory() -> void:
	print("UNIFIED ENCOUNTER SPIKE: enemy resolved; overworld continues in-place")
	var tw := enemy_actor.create_tween()
	tw.tween_property(enemy_actor, "modulate:a", 0.0, 0.25)
	await tw.finished
	room.unregister(enemy_actor)
	enemy_actor.queue_free()
	enemy_actor = null
	# Back to exploration: followers leave the occupancy map (non-blocking
	# again) from exactly where they fought - the world simply continues.
	for f in followers:
		room.vacate(f)
	trail.clear()
	for f in followers:
		trail.append((f as GridActor).cell)
	for unit in stats:
		var label: Label = stats[unit]["label"]
		if label != null:
			label.queue_free()
	stats.clear()
	mode = Mode.EXPLORE


## --- tiny combat presentation ------------------------------------------------

func _attach_hp_label(unit: GridActor) -> void:
	var label := Label.new()
	label.text = "%s %d/%d" % [stats[unit]["unit_name"], stats[unit]["hp"],
			stats[unit]["max_hp"]]
	# The hero's label sits one step higher so adjacent allies' labels
	# never overlap.
	label.position = Vector2(-32, -80 if unit == leader else -62)
	label.size = Vector2(64, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 3
	unit.add_child(label)
	stats[unit]["label"] = label


func _refresh_hp_label(unit: GridActor) -> void:
	var label: Label = stats[unit]["label"]
	if label != null:
		label.text = "%s %d/%d" % [stats[unit]["unit_name"],
				maxi(0, int(stats[unit]["hp"])), stats[unit]["max_hp"]]


func _popup(unit: GridActor, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 4
	label.position = unit.position + Vector2(-14, -70)
	room.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 26.0, 0.5)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tw.chain().tween_callback(label.queue_free)


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return _manhattan(a, b) == 1


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## --- proof tour ---------------------------------------------------------------

func _assert(ok: bool, what: String) -> void:
	tour_log.append(("PASS: " if ok else "FAIL: ") + what)


func _scripted_tour() -> void:
	await _frames(6)
	var scene_before := get_tree().current_scene
	# 1) Alter puzzle state before the fight: push the block one cell east.
	await _player_act(Vector2i.RIGHT)   # bump-push (9,6) -> (10,6)
	await _frames(6)
	_assert(block.cell == BLOCK_CELL + Vector2i.RIGHT,
			"block pushed to %s before the encounter" % str(block.cell))
	await _shot("01-block-pushed")
	var block_cell_before := block.cell
	# 2) Climb to the plateau and approach until detection triggers.
	for dir: Vector2i in [Vector2i.UP, Vector2i.UP, Vector2i.UP, Vector2i.UP,
			Vector2i.LEFT]:
		if mode == Mode.ENCOUNTER:
			break
		await _player_act(dir)
	_assert(mode == Mode.ENCOUNTER, "detection started the encounter in-room")
	_assert(room.get_occupant((followers[0] as GridActor).cell) == followers[0],
			"followers snapped into the occupancy map (D-020 blocking)")
	await _shot("02-encounter-start")
	# 3) Fight to resolution through the normal player-action path.
	var first_blood_shot := false
	for _turn in 20:
		if mode != Mode.ENCOUNTER:
			break
		var dir := _dir_toward(leader.cell, enemy_actor.cell)
		await _player_act(dir)
		if not first_blood_shot and enemy_actor != null \
				and int(stats.get(enemy_actor, {}).get("hp", 12)) < 12:
			await _shot("03-attack-exchange")
			first_blood_shot = true
	_assert(mode == Mode.EXPLORE and enemy_actor == null,
			"encounter resolved in-room (enemy defeated)")
	# 4) Continuity: same scene, puzzle state kept, followers non-blocking.
	_assert(get_tree().current_scene == scene_before,
			"no scene change across the whole encounter")
	_assert(block.cell == block_cell_before,
			"pushed block still at %s after victory" % str(block.cell))
	_assert(room.blocked.has(CHEST_CELL), "chest cell still blocked after victory")
	_assert(room.get_occupant((followers[0] as GridActor).cell) == null,
			"followers left the occupancy map after victory (D-029)")
	await _player_act(Vector2i.RIGHT)
	await _player_act(Vector2i.RIGHT)
	await _frames(8)
	await _shot("04-victory-world-continuous")


## Step axis-priority toward the target: x first, then y (attacks resolve
## via the bump when adjacent).
func _dir_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	if from.x != to.x:
		return Vector2i(signi(to.x - from.x), 0)
	return Vector2i(0, signi(to.y - from.y))
