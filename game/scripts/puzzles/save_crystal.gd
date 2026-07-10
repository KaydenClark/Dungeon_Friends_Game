class_name SaveCrystal
extends Node2D
## Save point (T-039). A physical object in the world - saves happen here,
## not from a menu (BLUEPRINT save rule, from the retired Gameplan §12).
## Interacting writes slot 1 and confirms through dialogue (multi-slot UI is
## deliberately not MVP - the slots exist only in the file format, D-006).
## MVP: crystals exist only in the forest, so there is never a mid-puzzle
## save to reason about. Blocks its cell like an NPC; builder sets room/cell.

var room: RoomGrid
var cell := Vector2i.ZERO


func _ready() -> void:
	# Placeholder art: a cyan diamond with a bright core, until Asset Batch D
	# supplies the real crystal sprite.
	var gem := ColorRect.new()
	gem.color = Color(0.35, 0.9, 0.95)
	gem.position = Vector2(-17, -17)
	gem.size = Vector2(34, 34)
	gem.rotation_degrees = 45.0
	gem.pivot_offset = gem.size * 0.5
	add_child(gem)
	var core := ColorRect.new()
	core.color = Color(0.9, 1.0, 1.0)
	core.position = Vector2(-7, -7)
	core.size = Vector2(14, 14)
	core.rotation_degrees = 45.0
	core.pivot_offset = core.size * 0.5
	add_child(core)


func interact() -> void:
	if SceneManager.save_game(1):
		SceneManager.show_dialogue([
			"The crystal flares with a soft, steady light.",
			"(Adventure saved.)",
		])
	else:
		SceneManager.show_dialogue([
			"The crystal flickers... and dims.",
			"(Saving failed - check the log.)",
		])
