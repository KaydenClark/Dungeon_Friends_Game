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
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/art/objects/kenney/save_crystal.png")
	sprite.scale = Vector2.ONE * 4.0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


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
