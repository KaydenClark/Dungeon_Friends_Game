class_name OverworldEnemy
extends GridActor
## Enemy visible on the map (no random/invisible encounters). Moves on its own
## clock (not tied to the player's steps - revised 2026-07-05, supersedes the
## old synchronized-turn model): it wanders on a timer until the player comes
## within TRACK_RADIUS, then paths toward them and triggers combat on contact.
##
## Placeholder art (until M1.1): a red triangle - deliberately not a square,
## so enemies read as hostile at a glance next to the square player/NPCs.
## The boss is a bigger, darker triangle with a gold key glint.

## Manhattan distance (in tiles) at which the enemy notices the player and
## starts closing in. Outside this it just wanders, so it reads as ambient
## until it spots you.
const TRACK_RADIUS := 4
## Seconds between steps (the tween itself takes `move_time` on top of this).
const STEP_INTERVAL := 0.35

var stats: EnemyStats
var target_player: Player
var is_boss := false
## Spawn cell; with a leash set, the enemy drifts back here when it strays.
var home_cell := Vector2i.ZERO
## Max Manhattan distance from home_cell while wandering (< 0 = roam freely).
## Chasing the player may exceed the leash; the enemy walks home afterwards.
var leash_radius := -1
var _step_accum := 0.0


func _ready() -> void:
	var tri := Polygon2D.new()
	var s := 30.0 if is_boss else 24.0
	tri.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s, s), Vector2(-s, s)])
	tri.color = Color(0.55, 0.08, 0.12) if is_boss else Color(0.85, 0.18, 0.18)
	add_child(tri)
	if is_boss:
		# The swallowed key, peeking through: a small gold glint on the belly.
		var glint := ColorRect.new()
		glint.color = Color(0.95, 0.8, 0.25)
		glint.position = Vector2(-5, 4)
		glint.size = Vector2(10, 14)
		add_child(glint)


func _process(delta: float) -> void:
	# Autonomous stepping: accumulate real time and take a grid step whenever the
	# interval elapses, independent of the player. Frozen during combat, dialogue,
	# or while a previous tween is still running.
	if target_player == null or moving or stats == null \
			or SceneManager.in_encounter or SceneManager.ui_busy:
		return
	_step_accum += delta
	if _step_accum < STEP_INTERVAL:
		return
	_step_accum = 0.0
	_act()


func _act() -> void:
	# MVP overworld AI: wander (within the leash, if any) until the player is
	# within TRACK_RADIUS, then path toward them and bump into combat. Strict
	# per-behavior AI (dedicated BIASED_TRACKING / PATTERN routines) is a
	# Phase 4 concern; for now every enemy uses this hybrid regardless of
	# ai_behavior.
	var to_player: Vector2i = target_player.cell - cell
	var dist: int = absi(to_player.x) + absi(to_player.y)
	if dist <= TRACK_RADIUS:
		_step_toward(target_player)
	elif leash_radius >= 0 and _manhattan(cell, home_cell) > leash_radius:
		_step_home()
	else:
		_wander()


func _step_toward(player: Player) -> void:
	# Path around walls; the path's final cell is the player's own, so stepping
	# onto it means contact -> encounter.
	var path := room.find_path(cell, player.cell, true)
	if path.size() < 2:
		_wander()  # boxed in - shuffle instead of freezing
		return
	var dir: Vector2i = path[1] - cell
	if cell + dir == player.cell:
		SceneManager.start_encounter(self)
	else:
		try_step(dir)


func _step_home() -> void:
	var path := room.find_path(cell, home_cell, true)
	if path.size() >= 2:
		try_step(path[1] - cell)


func _wander() -> void:
	var dirs: Array[Vector2i] = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT
	]
	var dir: Vector2i = dirs[SceneManager.rng.randi_range(0, 3)]
	if leash_radius >= 0 and _manhattan(cell + dir, home_cell) > leash_radius:
		return  # would stray past the leash - just idle this beat
	try_step(dir)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func defeated() -> void:
	if room:
		room.unregister(self)
		room.enemies.erase(self)
	queue_free()
