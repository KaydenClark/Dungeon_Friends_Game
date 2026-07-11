class_name BootPrompt
extends CanvasLayer
## Minimal Continue/New Game prompt (T-040, D-011: when a save exists, ask;
## no title screen until Phase 6). Same actions as dialogue:
## confirm/interact continues, cancel starts fresh. main.gd awaits `chosen`
## before booting a room, so nothing else is running underneath it.

signal chosen(continue_game: bool)


func _ready() -> void:
	layer = 95   # above gameplay UI, below the fade layer (100)
	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.05, 0.1, 0.92)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var text := Label.new()
	text.text = "A saved adventure awaits.\n\nContinue                  New Game"
	text.add_theme_font_size_override("font_size", 30)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_child(text)
	var confirm_glyph := InputPrompts.make_glyph("confirm")
	confirm_glyph.position = Vector2(505, 420)
	confirm_glyph.size = Vector2(40, 40)
	panel.add_child(confirm_glyph)
	var cancel_glyph := InputPrompts.make_glyph("cancel")
	cancel_glyph.position = Vector2(755, 420)
	cancel_glyph.size = Vector2(40, 40)
	panel.add_child(cancel_glyph)
	var frame := TextureRect.new()
	frame.texture = load("res://assets/art/ui/kenney/panel.png")
	frame.position = Vector2(390, 235)
	frame.size = Vector2(500, 260)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_TILE
	frame.modulate = Color(0.2, 0.32, 0.5, 0.4)
	panel.add_child(frame)
	panel.move_child(frame, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		chosen.emit(true)
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		chosen.emit(false)
