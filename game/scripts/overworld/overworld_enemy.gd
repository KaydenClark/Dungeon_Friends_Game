class_name OverworldEnemy
extends GridActor
## Enemy visible on the map (no random/invisible encounters - locked
## decision). Moves only when the player moves (synchronized turns) and
## triggers combat on contact.

## Manhattan distance (in tiles) at which the enemy notices the player and
## starts closing in. Outside this it just wanders, so it reads as ambient
## until you choose to approach.
const TRACK_RADIUS := 4

var stats: EnemyStats


func _ready() -> void:
	_make_body(Color(0.62, 0.3, 0.72))


func take_overworld_turn(player: Player) -> void:
	if moving or stats == null or SceneManager.in_encounter:
		return
	# MVP overworld AI: wander randomly until the player is within TRACK_RADIUS,
	# then path toward them and bump into combat. Strict per-behavior AI
	# (dedicated BIASED_TRACKING / PATTERN routines) is a Phase 4 concern; for
	# now the one forest slime uses this hybrid regardless of ai_behavior.
	var to_player: Vector2i = player.cell - cell
	var dist: int = absi(to_player.x) + absi(to_player.y)
	if dist <= TRACK_RADIUS:
		_step_toward(player)
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


func _wander() -> void:
	var dirs: Array[Vector2i] = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT
	]
	try_step(dirs[SceneManager.rng.randi_range(0, 3)])


func defeated() -> void:
	if room:
		room.unregister(self)
		room.enemies.erase(self)
	queue_free()
