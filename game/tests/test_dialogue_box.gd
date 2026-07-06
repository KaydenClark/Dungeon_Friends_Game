extends "res://tests/gd_test.gd"
## Unit tests for DialogueBox line advancement. The per-line input cooldown is
## input-driven (real-time, hard to unit test deterministically), so these
## exercise the pure model instead: advance() walks the lines in order and
## emits `finished` exactly once, after the last line. SceneManager and the
## smoke test cover the full keypress-driven flow end to end.

var _finished_count := 0


func _on_finished() -> void:
	_finished_count += 1


func _open_box(lines: PackedStringArray) -> DialogueBox:
	var box := DialogueBox.new()
	add_child(box)
	_finished_count = 0
	box.finished.connect(_on_finished)
	box.open(lines)
	return box


func test_open_shows_first_line() -> void:
	var box := _open_box(PackedStringArray(["one", "two", "three"]))
	eq(box.idx, 0, "starts on the first line")
	eq(box.label.text, "one", "first line shown")
	box.queue_free()


func test_advance_walks_lines_in_order() -> void:
	var box := _open_box(PackedStringArray(["one", "two", "three"]))
	box.advance()
	eq(box.idx, 1, "advanced to line 2")
	eq(box.label.text, "two", "second line shown")
	box.advance()
	eq(box.label.text, "three", "third line shown")
	eq(_finished_count, 0, "not finished before the last line")
	box.queue_free()


func test_finished_emits_once_after_last_line() -> void:
	var box := _open_box(PackedStringArray(["only line"]))
	eq(_finished_count, 0, "not finished on open")
	box.advance()
	eq(_finished_count, 1, "finished fires past the last line")
	box.queue_free()


func test_single_line_box_finishes_on_first_advance() -> void:
	var box := _open_box(PackedStringArray(["solo"]))
	eq(box.label.text, "solo", "single line shown")
	box.advance()
	eq(_finished_count, 1, "one advance closes a one-line box")
	box.queue_free()
