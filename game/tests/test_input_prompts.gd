extends "res://tests/gd_test.gd"


func test_active_input_mode_switches_without_mixing_labels() -> void:
	InputPrompts.reset()
	eq(InputPrompts.mode, InputPrompts.Mode.KEYBOARD, "keyboard fallback")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	ok(InputPrompts.observe(joy), "joypad event changes mode")
	eq(InputPrompts.mode, InputPrompts.Mode.CONTROLLER, "controller mode active")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	ok(InputPrompts.observe(key), "keyboard event changes mode")
	eq(InputPrompts.mode, InputPrompts.Mode.KEYBOARD, "keyboard mode restored")


func test_all_locked_pairs_have_runtime_glyphs() -> void:
	for action in ["confirm", "jump", "cancel", "character_menu", "menu"]:
		var keyboard := InputPrompts.texture_path(action, InputPrompts.Mode.KEYBOARD)
		var controller := InputPrompts.texture_path(action, InputPrompts.Mode.CONTROLLER)
		ne(keyboard, controller, "%s modes use distinct assets" % action)
		ok(ResourceLoader.exists(keyboard), "%s keyboard glyph exists" % action)
		ok(ResourceLoader.exists(controller), "%s controller glyph exists" % action)
