class_name DialogueBox
extends PanelContainer
## Minimal dialogue box shown on the UILayer. Advances one line per
## confirm/interact press; emits `finished` after the last line. Created and
## awaited by SceneManager.show_dialogue().

signal finished

var lines := PackedStringArray()
var idx := 0
var label: Label
var hint: Label
var _opened_ms := 0


func _init() -> void:
	anchor_left = 0.08
	anchor_right = 0.92
	anchor_top = 0.74
	anchor_bottom = 0.94
	var vbox := VBoxContainer.new()
	add_child(vbox)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 26)
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(label)
	hint = Label.new()
	hint.text = "E / Space / Enter ▸"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(hint)


func open(p_lines: PackedStringArray) -> void:
	lines = p_lines
	idx = 0
	_opened_ms = Time.get_ticks_msec()
	_show_line()


func advance() -> void:
	idx += 1
	if idx >= lines.size():
		finished.emit()
	else:
		_show_line()


func _show_line() -> void:
	if idx < lines.size():
		label.text = lines[idx]


func _unhandled_input(event: InputEvent) -> void:
	# Small cooldown so the keypress that opened the dialogue can't also
	# advance it on the same frame.
	if Time.get_ticks_msec() - _opened_ms < 200:
		return
	if event.is_action_pressed("confirm") \
			or event.is_action_pressed("interact") \
			or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		advance()
