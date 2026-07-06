extends Node2D
## Root scene script: registers the containers with SceneManager and loads
## the current world into WorldContainer. Today that world is the
## first-playable forest slice (placeholder art); the LDtk pipeline
## (T-004/T-011) will replace how rooms are authored, not this wiring.


func _ready() -> void:
	SceneManager.register_main(
		$WorldContainer, $CombatContainer, $UILayer, $TransitionLayer)
	var room := ForestSlice.new()
	$WorldContainer.add_child(room)
	var hint := Label.new()
	hint.text = "WASD / Arrows: move    E or Space: talk & interact"
	hint.position = Vector2(16, 8)
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(1, 1, 1, 0.75)
	$UILayer.add_child(hint)
