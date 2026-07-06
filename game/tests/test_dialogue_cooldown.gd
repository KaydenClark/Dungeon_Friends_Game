extends "res://tests/gd_test.gd"
## Tests for DialogueBox's per-line input cooldown (ADVANCE_COOLDOWN_MS).
## test_dialogue_box.gd covers the pure advance() model; these drive the real
## _unhandled_input() handler with synthetic confirm presses so the debounce
## that stops a burst of E taps from flushing every line at once is actually
## verified.
##
## The cooldown compares Time.get_ticks_msec() against the box's `_last_input_ms`
## stamp. Rather than sleep through real ~220ms windows (flaky: headless timers
## can fire a hair early), these control that stamp directly -- pushing it into
## the past is exactly equivalent to "the cooldown has elapsed" and keeps the
## tests deterministic while still running the real handler branch.


func _open(lines: Array) -> DialogueBox:
	var box := DialogueBox.new()
	add_child(box)
	box.open(PackedStringArray(lines))
	return box


func _confirm_event() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "confirm"
	ev.pressed = true
	return ev


func _elapse_cooldown(box: DialogueBox) -> void:
	# Simulate a full second passing since the last accepted press.
	box._last_input_ms -= 1000


func test_press_within_cooldown_is_swallowed() -> void:
	# open() stamps _last_input_ms = now, so an immediate press is inside the
	# window and must not advance (the press that opened the box can't flush it).
	var box := _open(["one", "two", "three"])
	box._unhandled_input(_confirm_event())
	eq(box.idx, 0, "press within the cooldown does not advance")
	box.queue_free()


func test_press_after_cooldown_advances() -> void:
	var box := _open(["one", "two", "three"])
	_elapse_cooldown(box)
	box._unhandled_input(_confirm_event())
	eq(box.idx, 1, "a press past the cooldown advances one line")
	box.queue_free()


func test_burst_presses_advance_only_once() -> void:
	var box := _open(["one", "two", "three"])
	_elapse_cooldown(box)
	box._unhandled_input(_confirm_event())   # accepted -> line 2, re-stamps to now
	box._unhandled_input(_confirm_event())   # same burst -> swallowed
	box._unhandled_input(_confirm_event())   # same burst -> swallowed
	eq(box.idx, 1, "a mashed burst only advances a single line")
	_elapse_cooldown(box)
	box._unhandled_input(_confirm_event())   # deliberate new press -> line 3
	eq(box.idx, 2, "a fresh press after the cooldown advances again")
	box.queue_free()


func test_cancel_action_also_advances() -> void:
	# The handler accepts confirm/interact/cancel alike; verify a non-confirm
	# bound action still drives advancement through the same cooldown gate.
	var box := _open(["one", "two"])
	_elapse_cooldown(box)
	var ev := InputEventAction.new()
	ev.action = "cancel"
	ev.pressed = true
	box._unhandled_input(ev)
	eq(box.idx, 1, "a cancel press advances past the cooldown")
	box.queue_free()
