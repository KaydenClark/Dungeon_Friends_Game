class_name DialogueBox
extends PanelContainer
## Minimal dialogue box shown on the UILayer. Advances one line per
## confirm/interact press; emits `finished` after the last line. Created and
## awaited by SceneManager.show_dialogue().

signal finished

## Minimum time between accepted presses. Stops a couple of quick E taps from
## flushing every line at once (and dumping the player straight back out); each
## line now needs its own deliberate press.
const ADVANCE_COOLDOWN_MS := 220

var lines := PackedStringArray()
var idx := 0
var label: Label
var hint: Label
var _last_input_ms := 0


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
	hint.text = ""
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var prompt_row := HBoxContainer.new()
	prompt_row.alignment = BoxContainer.ALIGNMENT_END
	prompt_row.add_child(InputPrompts.make_glyph("confirm"))
	prompt_row.add_child(hint)
	vbox.add_child(prompt_row)
	var panel_style := StyleBoxTexture.new()
	panel_style.texture = load("res://assets/art/ui/kenney/panel.png")
	panel_style.texture_margin_left = 5.0
	panel_style.texture_margin_top = 5.0
	panel_style.texture_margin_right = 5.0
	panel_style.texture_margin_bottom = 5.0
	panel_style.modulate_color = Color(0.12, 0.16, 0.24, 0.96)
	add_theme_stylebox_override("panel", panel_style)


func open(p_lines: PackedStringArray) -> void:
	lines = p_lines
	idx = 0
	# Seed the cooldown from open time so the keypress that opened the dialogue
	# can't also advance it on the same/next frame.
	_last_input_ms = Time.get_ticks_msec()
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
	if not (event.is_action_pressed("confirm") \
			or event.is_action_pressed("interact") \
			or event.is_action_pressed("cancel")):
		return
	# Always consume the press so it never leaks to the overworld/player, even
	# while the per-line cooldown is swallowing it.
	get_viewport().set_input_as_handled()
	# Per-line cooldown: each advance needs its own deliberate press, so mashing
	# E can't flush multiple lines (or close the box) in one burst.
	if Time.get_ticks_msec() - _last_input_ms < ADVANCE_COOLDOWN_MS:
		return
	_last_input_ms = Time.get_ticks_msec()
	advance()
