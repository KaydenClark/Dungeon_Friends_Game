class_name InputPrompts
extends RefCounted
## One active input vocabulary at a time (T-079/T-083). Gameplay bindings
## remain in InputMap; this class only chooses the matching Kenney glyph.

enum Mode { KEYBOARD, CONTROLLER }

static var mode := Mode.KEYBOARD

const BASENAMES := {
	"confirm": "confirm",
	"interact": "confirm",
	"jump": "jump",
	"cancel": "cancel",
	"character_menu": "character",
	"menu": "menu",
}


static func reset() -> void:
	mode = Mode.KEYBOARD


static func observe(event: InputEvent) -> bool:
	var next := mode
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next = Mode.CONTROLLER
	elif event is InputEventKey or event is InputEventMouseButton:
		next = Mode.KEYBOARD
	if next == mode:
		return false
	mode = next
	return true


static func texture_path(action: String, for_mode := mode) -> String:
	var base: String = BASENAMES.get(action, "confirm")
	var device := "controller" if for_mode == Mode.CONTROLLER else "keyboard"
	return "res://assets/art/ui/prompts/kenney/%s_%s.png" % [device, base]


static func make_glyph(action: String) -> TextureRect:
	var glyph := TextureRect.new()
	glyph.name = "InputGlyph_%s" % action
	glyph.set_meta("prompt_action", action)
	glyph.add_to_group("input_prompt_glyphs")
	glyph.custom_minimum_size = Vector2(32, 32)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	refresh_glyph(glyph)
	return glyph


static func refresh_glyph(glyph: TextureRect) -> void:
	glyph.texture = load(texture_path(str(glyph.get_meta("prompt_action", "confirm"))))
