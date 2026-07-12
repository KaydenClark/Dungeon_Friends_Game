class_name SaveCrystal
extends Node2D
## Save point (T-039). A physical object in the world - saves happen here,
## not from a menu (BLUEPRINT save rule, from the retired Gameplan §12).
## Interacting writes slot 1 and confirms through dialogue. If this fresh
## session would replace an existing slot, a confirm/cancel prompt protects
## it first (B-15). Multi-slot UI is deliberately not MVP - the slots exist
## only in the file format (D-006).
## MVP: crystals exist only in the forest, so there is never a mid-puzzle
## save to reason about. Blocks its cell like an NPC; builder sets room/cell.

var room: RoomGrid
var cell := Vector2i.ZERO
var busy := false


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/art/objects/kenney/save_crystal.png")
	sprite.scale = Vector2.ONE * 4.0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func interact() -> void:
	if busy:
		return
	busy = true
	var overwrite_confirmed := false
	if SceneManager.save_needs_overwrite_confirmation(1):
		var prompt := BootPrompt.new()
		prompt.message = "Slot 1 already holds another adventure.\nOverwrite it?"
		prompt.confirm_text = "Overwrite"
		prompt.cancel_text = "Keep Save"
		add_child(prompt)
		overwrite_confirmed = await prompt.chosen
		prompt.queue_free()
		if not overwrite_confirmed:
			await SceneManager.show_dialogue([
				"The crystal's light settles.",
				"(The existing adventure was kept.)",
			])
			busy = false
			return
	if SceneManager.save_game(1, overwrite_confirmed):
		await SceneManager.show_dialogue([
			"The crystal flares with a soft, steady light.",
			"(Adventure saved.)",
		])
	else:
		# B-18: player-facing copy - "check the log" means nothing to a player;
		# the diagnostic detail already lands in push_warning from save_game().
		await SceneManager.show_dialogue([
			"The crystal flickers... and dims.",
			"(Something is wrong - the adventure was not saved.)",
		])
	busy = false
