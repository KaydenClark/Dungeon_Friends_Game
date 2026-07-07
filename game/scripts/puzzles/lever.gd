class_name Lever
extends Node2D
## Wall-mounted reset lever (T-024; the cheap escape valve from the
## block-puzzle soft-lock risk row in /BLUEPRINT.md -> Known Risks): interact
## resets the room's puzzle - every un-sunk PushableBlock returns to its
## starting cell. It occupies (and blocks) its cell like other interactables,
## so it is always operated from an adjacent cell.

var room: RoomGrid
var cell := Vector2i.ZERO


func _ready() -> void:
	# Placeholder art: a bronze base with an upright handle.
	var base := ColorRect.new()
	base.color = Color(0.42, 0.32, 0.2)
	base.position = Vector2(-20, 2)
	base.size = Vector2(40, 22)
	add_child(base)
	var handle := ColorRect.new()
	handle.color = Color(0.75, 0.62, 0.3)
	handle.position = Vector2(-4, -24)
	handle.size = Vector2(8, 28)
	add_child(handle)


func interact() -> void:
	if room:
		room.reset_puzzle()
	SceneManager.show_dialogue([
		"You pull the lever. Gears grind somewhere below...",
		"The room's blocks slide back to where they began.",
	])
