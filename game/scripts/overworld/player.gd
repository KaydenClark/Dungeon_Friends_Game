class_name Player
extends GridActor
## Player-controlled grid actor with camera follow. Input comes exclusively
## from the Input Map actions (see /BLUEPRINT.md -> Commands).

var camera: Camera2D


func _ready() -> void:
	_make_body(Color(0.25, 0.5, 0.95))
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func _process(_delta: float) -> void:
	if moving or SceneManager.ui_busy or SceneManager.in_encounter:
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("move_up"):
		dir = Vector2i.UP
	elif Input.is_action_pressed("move_down"):
		dir = Vector2i.DOWN
	elif Input.is_action_pressed("move_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_pressed("move_right"):
		dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		try_step(dir)
	elif Input.is_action_just_pressed("interact"):
		interact()


func interact() -> void:
	if room == null:
		return
	var occ: Node2D = room.get_occupant(cell + facing)
	if occ and occ.has_method("interact"):
		occ.interact()


func _on_bump(occ: Node2D) -> void:
	if occ is OverworldEnemy:
		SceneManager.start_encounter(occ)
