class_name Player
extends GridActor
## Player-controlled grid actor with camera follow. Input comes exclusively
## from the Input Map actions (see /BLUEPRINT.md -> Commands).
##
## Feel model (T-021, 2026-07-06 - see /BLUEPRINT.md -> Core Logic, feel bar):
## grid-locked but never *feels* locked, the Zelda/Pokemon standard.
## - Tap toward a new direction: turn in place (face it, no step).
## - Hold past TURN_DELAY: take the first step, then walk continuously.
## - Tap in the faced direction: exactly one step (B-04 stays fixed).
## - Hold in the faced direction: one step, a short beat, then continuous.
## - While walking, direction changes are seamless (no turn pause, no gap).
## - Last-pressed direction wins (pressing right while holding up goes right),
##   and releasing it falls back to whatever is still held.
## The step decision lives in _movement_intent(), a pure function of
## (direction, delta) plus actor state, so the unit suite drives the real path.

## Visible time for one grid step. Long enough to read as motion instead of a
## cell pop, short enough that the grid still feels crisp.
const WALK_MOVE_TIME := 0.16
## Total hold time (from press, *including* the move tween) before auto-walk
## engages. Anything shorter reads as a tap = exactly one step. This sits just
## above WALK_MOVE_TIME, so held walking chains after about one frame instead
## of the old ~0.08s beat.
const MOVE_REPEAT_DELAY := 0.17
## Facing a new direction pauses this long before the first step (turn-in-
## place). Consumed concurrently with the hold, so a turn that becomes a walk
## has no extra stationary beat after its first step.
const TURN_DELAY := 0.1
## Airtime for a real jump across a gap, and for the refused in-place hop.
const JUMP_TIME := 0.22
const HOP_TIME := 0.14
## Pit falls (T-047, D-008 part 4): walking into a pit drops the player,
## costs fall_damage(), and respawns them at the room's entry_cell.
## Kayden's windowed-playtest correction: 10% was too soft and made repeated
## mistakes feel consequence-free. A fall now costs a flat 10 HP party-wide.
const FALL_DAMAGE := 10
const FALL_TIME := 0.3


func fall_damage() -> int:
	return FALL_DAMAGE

## B-08 (2026-07-11, Kayden): overworld actors temporarily use the colored
## placeholder bodies again. The runtime idle sprites have no directional
## frames and no facing marker, which made interact/push targeting guesswork.
## The square + face marker restores readable facing until the Mac Mini asset
## merge supplies directional-capable art; combat keeps its sprites (no facing
## there). Flip to true once directional sprites land.
const USE_SPRITE_BODY := false

const DIR_ACTIONS := {
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
}

var camera: Camera2D
var _hold_dir := Vector2i.ZERO
var _hold_time := 0.0
var _repeating := false
var _turn_pause := 0.0
var _buffered_step := false
## Held directions in press order; the most recent press is authoritative.
var _pressed_stack: Array[Vector2i] = []


func _ready() -> void:
	var hero: CharacterStats = load("res://data/characters/hero.tres")
	if not USE_SPRITE_BODY or not _make_sprite(hero.sprite_frames, 0.5):
		_make_body(Color(0.25, 0.5, 0.95))
	# Snappier per-step tween than the default so grid movement reads as crisp
	# steps rather than a laggy glide (playtest feedback 2026-07-05).
	move_time = WALK_MOVE_TIME
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	# Tighter follow (was 8.0) so the camera doesn't visibly trail the player.
	camera.position_smoothing_speed = 12.0
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	if SceneManager.ui_busy or SceneManager.in_encounter or SceneManager.transitioning:
		_reset_hold()
		return
	# Jump is a deliberate button press (D-003: Space primary, C fallback), never
	# automatic - it beats movement this frame so a hop is never eaten by a step.
	if not moving and Input.is_action_just_pressed("jump"):
		try_jump()
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
	if _movement_intent(dir, delta):
		try_step(dir)


## The whole tap/turn/hold/walk state machine, kept free of Input and tween
## calls so tests can drive it deterministically. Returns true when a step
## should be attempted this frame; mutates hold state (and facing, for
## turn-in-place) as a side effect.
func _movement_intent(dir: Vector2i, delta: float) -> bool:
	if dir == Vector2i.ZERO:
		_reset_hold()
		return false
	if dir != _hold_dir:
		# Fresh press or direction change.
		_hold_dir = dir
		_hold_time = 0.0
		_buffered_step = false
		if _repeating:
			# Already auto-walking: change direction seamlessly - no turn
			# pause, no repeat re-arm, next step fires as soon as we can move.
			_hold_time = MOVE_REPEAT_DELAY
			_turn_pause = 0.0
			return not moving
		if dir != facing:
			# Turn in place: face the new direction now; the first step only
			# happens if the press outlives TURN_DELAY.
			set_facing(dir)
			_turn_pause = TURN_DELAY
			return false
		_turn_pause = 0.0
		if moving:
			# Fresh press in the faced direction while a step is finishing:
			# buffer it so the step lands the moment the tween ends.
			_buffered_step = true
			return false
		return true
	# Direction unchanged: the hold matures even while the move tween runs, so
	# hold-to-walk has no stationary re-arm gap between steps.
	_hold_time += delta
	if moving:
		return false
	if _turn_pause > 0.0:
		_turn_pause -= delta
		if _turn_pause > 0.0:
			return false
		return true
	if _buffered_step:
		_buffered_step = false
		return true
	if _repeating:
		return true
	if _hold_time >= MOVE_REPEAT_DELAY:
		_repeating = true
		return true
	return false


## Last-pressed-wins direction read. Newly held actions append to the stack;
## released ones drop out, so rolling from one key to another (or releasing
## back to an earlier held key) always moves the way the hands expect.
func _read_dir() -> Vector2i:
	for action: String in DIR_ACTIONS:
		var dir: Vector2i = DIR_ACTIONS[action]
		if Input.is_action_pressed(action):
			if not _pressed_stack.has(dir):
				_pressed_stack.append(dir)
		else:
			_pressed_stack.erase(dir)
	if _pressed_stack.is_empty():
		return Vector2i.ZERO
	return _pressed_stack.back()


func _reset_hold() -> void:
	_hold_dir = Vector2i.ZERO
	_hold_time = 0.0
	_repeating = false
	_turn_pause = 0.0
	_buffered_step = false


## Jump exactly one cell over a jumpable gap in the facing direction (T-025,
## locked rule: max jump distance is exactly 1 cell - a 1-cell pit is the
## definitional jumpable gap; 2+ cells is never jumpable). A jump into a wall,
## an occupant, or across a too-wide pit plays a small in-place hop instead.
## Tween arc, never physics. Returns true when the jump actually crossed.
func try_jump() -> bool:
	if moving or room == null:
		return false
	var gap := cell + facing
	var land := cell + facing * 2
	if room.is_pit(gap) and room.is_walkable(land):
		_start_jump(land)
		return true
	_hop_in_place()
	return false


## Arc to the landing cell: occupancy and cell update at takeoff (same
## reservation rule as _start_move), the body bobs up and back down while the
## root tweens across, so the hop reads as an arc without any physics.
func _start_jump(land: Vector2i) -> void:
	moving = true
	room.move_occupant(self, cell, land)
	cell = land
	var tw := create_tween()
	tw.tween_property(self, "position", room.cell_to_pos(land), JUMP_TIME)
	_bob_body(JUMP_TIME)
	await tw.finished
	moving = false
	move_finished.emit()


## Refused jump: a quick vertical bob in place, so the button always answers.
func _hop_in_place() -> void:
	if moving:
		return
	moving = true
	_bob_body(HOP_TIME)
	await get_tree().create_timer(HOP_TIME).timeout
	moving = false
	move_finished.emit()


func _bob_body(duration: float) -> void:
	if body == null:
		return
	var rest: Vector2 = body.position
	var tw := create_tween()
	tw.tween_property(body, "position:y", rest.y - 20.0, duration * 0.5)
	tw.tween_property(body, "position:y", rest.y, duration * 0.5)


## Walking into a pit is a fall, not a refusal (T-047 supersedes "pits are
## impassable" - for the player only; enemies and pathing still treat pits
## as solid). Jumping goes through try_jump and never lands here.
func try_step(dir: Vector2i) -> bool:
	if not moving and room != null:
		var target := cell + dir
		if room.is_pit(target) and room.get_occupant(target) == null:
			set_facing(dir)
			_fall_into_pit(target)
			return true
	return super.try_step(dir)


## Zelda-style fall: slide over the pit while shrinking away, take the
## damage, then either walk back in at the room's entry cell or - at 0 HP -
## hand over to the T-041 defeat flow. Occupancy never claims the pit cell;
## the respawn teleport does all the bookkeeping.
func _fall_into_pit(pit: Vector2i) -> void:
	moving = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", room.cell_to_pos(pit), FALL_TIME * 0.5)
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), FALL_TIME) \
			.set_delay(FALL_TIME * 0.25)
	await tw.finished
	SceneManager.damage_party(fall_damage())
	var fatal: bool = SceneManager.hero_hp <= 0
	if not fatal:
		room.teleport(self, room.entry_cell)
	else:
		position = room.cell_to_pos(cell)   # settle back on the takeoff cell
	scale = Vector2.ONE
	moving = false
	move_finished.emit()
	if fatal:
		SceneManager.handle_defeat()


func interact() -> void:
	if room == null:
		return
	var occ: Node2D = room.get_occupant(cell + facing)
	if occ and occ.has_method("interact"):
		occ.interact()


func _on_bump(occ: Node2D) -> void:
	if occ is OverworldEnemy:
		SceneManager.start_encounter(occ)
	elif occ is PushableBlock:
		# Walking into the block while pressing toward it pushes it one cell
		# (T-023). The player stays put; walking follows on the next step.
		occ.try_push(occ.cell - cell)
