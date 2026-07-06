class_name Player
extends GridActor
## Player-controlled grid actor with camera follow. Input comes exclusively
## from the Input Map actions (see /BLUEPRINT.md -> Commands).

## Delayed-auto-shift: after the first step, a held direction must be held this
## much longer (on top of the move tween) before it starts repeating. Keeps a
## tap to exactly one cell while still allowing hold-to-walk.
const MOVE_REPEAT_DELAY := 0.2

var camera: Camera2D
var _hold_dir := Vector2i.ZERO
var _hold_time := 0.0
var _repeating := false


func _ready() -> void:
	_make_body(Color(0.25, 0.5, 0.95))
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	if SceneManager.ui_busy or SceneManager.in_encounter:
		_reset_hold()
		return
	var dir := _read_dir()
	if dir == Vector2i.ZERO:
		_reset_hold()
		# Ignore the interact press for a moment after a dialogue closes, so the
		# same keypress that dismissed a box can't immediately re-open it.
		if not moving and Input.is_action_just_pressed("interact") \
				and Time.get_ticks_msec() - SceneManager.last_ui_close_ms >= 250:
			interact()
		return
	if moving:
		return
	if dir != _hold_dir:
		# Fresh press (or a direction change): always exactly one step.
		_hold_dir = dir
		_hold_time = 0.0
		_repeating = false
		try_step(dir)
	elif _repeating:
		# Auto-repeat engaged: step at the move-tween cadence.
		try_step(dir)
	else:
		# Same direction still held but not yet repeating: wait out the delay.
		_hold_time += delta
		if _hold_time >= MOVE_REPEAT_DELAY:
			_repeating = true
			try_step(dir)


func _read_dir() -> Vector2i:
	if Input.is_action_pressed("move_up"):
		return Vector2i.UP
	if Input.is_action_pressed("move_down"):
		return Vector2i.DOWN
	if Input.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if Input.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _reset_hold() -> void:
	_hold_dir = Vector2i.ZERO
	_hold_time = 0.0
	_repeating = false


func interact() -> void:
	if room == null:
		return
	var occ: Node2D = room.get_occupant(cell + facing)
	if occ and occ.has_method("interact"):
		occ.interact()


func _on_bump(occ: Node2D) -> void:
	if occ is OverworldEnemy:
		SceneManager.start_encounter(occ)
