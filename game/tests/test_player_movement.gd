extends "res://tests/gd_test.gd"
## Unit tests for the T-021 movement-feel state machine
## (Player._movement_intent) and the last-pressed-wins direction read
## (Player._read_dir). The intent function is a pure function of
## (direction, delta) plus actor state - no Input, no tweens - so these run
## the real shipped path deterministically with hand-fed deltas.
##
## The player is instantiated bare (never added to the tree), so _ready()
## never runs: no camera, no body - just the movement logic under test.

const FRAME := 1.0 / 60.0


func _bare_player() -> Player:
	var p: Player = Player.new()
	# Never added to the tree: _process/_ready stay quiet; facing defaults DOWN.
	return p


## Feed the intent function a held direction for `seconds`, returning how many
## step requests it produced. Simulates the tween by holding `moving` true for
## `move_time` after each granted step, maturing the hold through it exactly
## like _process does in real frames.
func _run_hold(p: Player, dir: Vector2i, seconds: float) -> int:
	var steps := 0
	var t := 0.0
	var move_left := 0.0
	while t < seconds:
		p.moving = move_left > 0.0
		if p._movement_intent(dir, FRAME):
			steps += 1
			move_left = p.move_time
		elif move_left > 0.0:
			move_left -= FRAME
		t += FRAME
	p.moving = false
	return steps


func test_tap_in_faced_direction_steps_immediately() -> void:
	var p := _bare_player()
	ok(p._movement_intent(Vector2i.DOWN, FRAME), "tap toward facing steps on the first frame")
	p.free()


func test_tap_in_new_direction_only_turns() -> void:
	var p := _bare_player()
	not_ok(p._movement_intent(Vector2i.LEFT, FRAME), "tap toward a new direction does not step")
	eq(p.facing, Vector2i.LEFT, "but it does turn the player to face it")
	p._movement_intent(Vector2i.ZERO, FRAME)   # release before TURN_DELAY
	not_ok(p._movement_intent(Vector2i.ZERO, FRAME), "nothing steps after the release")
	eq(p.facing, Vector2i.LEFT, "facing sticks after a turn-only tap")
	p.free()


func test_held_new_direction_steps_after_turn_delay() -> void:
	var p := _bare_player()
	var stepped := false
	var t := 0.0
	while t < p.TURN_DELAY + 3 * FRAME:
		if p._movement_intent(Vector2i.LEFT, FRAME):
			stepped = true
			break
		t += FRAME
	ok(stepped, "holding a new direction steps once TURN_DELAY elapses")
	ok(t >= p.TURN_DELAY - 2 * FRAME, "but not before the turn pause matures")
	p.free()


func test_tap_is_exactly_one_step() -> void:
	var p := _bare_player()
	# Tap = press for less than MOVE_REPEAT_DELAY, in the faced direction.
	var steps := _run_hold(p, Vector2i.DOWN, p.MOVE_REPEAT_DELAY - 2 * FRAME)
	p._movement_intent(Vector2i.ZERO, FRAME)   # release
	eq(steps, 1, "a tap produces exactly one step (B-04 contract)")
	p.free()


func test_hold_in_faced_direction_walks_continuously() -> void:
	var p := _bare_player()
	# 1 second of holding: first step at t=0, repeat engages at 0.2s, then one
	# step per move_time (0.15 default here since _ready never ran).
	var steps := _run_hold(p, Vector2i.DOWN, 1.0)
	ok(steps >= 5, "a 1s hold walks continuously (got %d steps)" % steps)
	ok(p._repeating, "auto-walk state is engaged")
	p.free()


func test_no_stationary_gap_between_repeat_steps() -> void:
	var p := _bare_player()
	_run_hold(p, Vector2i.DOWN, 0.5)   # get into repeat mode
	ok(p._repeating, "precondition: repeating")
	# The frame a move ends, the very next intent call must step again.
	p.moving = false
	ok(p._movement_intent(Vector2i.DOWN, FRAME), "next step fires immediately after a move ends")
	p.free()


func test_turn_then_walk_has_no_second_pause() -> void:
	var p := _bare_player()
	# Hold LEFT through the turn pause and first step; by the time that first
	# step's tween has run, the hold (turn + tween time) exceeds
	# MOVE_REPEAT_DELAY, so the walk chains with no extra stationary beat.
	var t := 0.0
	while not p._movement_intent(Vector2i.LEFT, FRAME):
		t += FRAME
	# Simulate the first step's tween maturing the hold.
	p.moving = true
	var tween := 0.0
	while tween < 0.12:
		p._movement_intent(Vector2i.LEFT, FRAME)
		tween += FRAME
	p.moving = false
	ok(p._movement_intent(Vector2i.LEFT, FRAME), "step chains immediately after a turn-then-walk")
	p.free()


func test_direction_change_while_walking_is_seamless() -> void:
	var p := _bare_player()
	_run_hold(p, Vector2i.DOWN, 0.5)   # walking down
	ok(p._repeating, "precondition: repeating")
	p.moving = false
	ok(p._movement_intent(Vector2i.RIGHT, FRAME), "direction change mid-walk steps with no turn pause")
	ok(p._repeating, "auto-walk survives the direction change")
	p.free()


func test_fresh_press_during_move_is_buffered() -> void:
	var p := _bare_player()
	p.set_facing(Vector2i.DOWN)
	p.moving = true   # a step is in flight
	not_ok(p._movement_intent(Vector2i.DOWN, FRAME), "no step while the tween runs")
	ok(p._buffered_step, "the faced-direction press is buffered")
	p.moving = false
	ok(p._movement_intent(Vector2i.DOWN, FRAME), "buffered step lands the frame the move ends")
	p.free()


func test_release_resets_all_hold_state() -> void:
	var p := _bare_player()
	_run_hold(p, Vector2i.DOWN, 0.5)
	p._movement_intent(Vector2i.ZERO, FRAME)
	not_ok(p._repeating, "release disengages auto-walk")
	eq(p._hold_dir, Vector2i.ZERO, "hold direction cleared")
	eq(p._hold_time, 0.0, "hold timer cleared")
	p.free()


func test_read_dir_last_pressed_wins_with_rollover() -> void:
	var p := _bare_player()
	Input.action_release("move_up")
	Input.action_release("move_right")
	eq(p._read_dir(), Vector2i.ZERO, "no input reads ZERO")
	Input.action_press("move_right")
	eq(p._read_dir(), Vector2i.RIGHT, "single press reads that direction")
	Input.action_press("move_up")
	eq(p._read_dir(), Vector2i.UP, "newer press wins over a still-held one")
	Input.action_release("move_up")
	eq(p._read_dir(), Vector2i.RIGHT, "releasing the newer key falls back to the held one")
	Input.action_release("move_right")
	eq(p._read_dir(), Vector2i.ZERO, "all released reads ZERO")
	p.free()
