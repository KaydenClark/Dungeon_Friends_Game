class_name OverworldEnemy
extends GridActor
## Enemy visible on the map (no random/invisible encounters - locked
## decision). Moves only when the player moves (synchronized turns) and
## triggers combat on contact.

var stats: EnemyStats


func _ready() -> void:
	_make_body(Color(0.62, 0.3, 0.72))


func take_overworld_turn(player: Player) -> void:
	if moving or stats == null or SceneManager.in_encounter:
		return
	match stats.ai_behavior:
		EnemyStats.AIBehavior.RANDOM_WALK:
			var dirs: Array[Vector2i] = [
				Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT
			]
			var dir: Vector2i = dirs[SceneManager.rng.randi_range(0, 3)]
			if cell + dir == player.cell:
				SceneManager.start_encounter(self)
			else:
				try_step(dir)
		_:
			pass  # BIASED_TRACKING / PATTERN are Phase 4+ behaviors.


func defeated() -> void:
	if room:
		room.unregister(self)
		room.enemies.erase(self)
	queue_free()
