class_name Lever
extends Node2D
## Wall-mounted reset lever (T-024; the cheap escape valve from the
## block-puzzle soft-lock risk row in /BLUEPRINT.md -> Known Risks): interact
## resets the room's puzzle - every un-sunk PushableBlock returns to its
## starting cell. It occupies (and blocks) its cell like other interactables,
## so it is always operated from an adjacent cell.

var room: RoomGrid
var cell := Vector2i.ZERO
## Optional link to a mechanism door. Empty keeps the original puzzle-reset
## behavior; a linked lever latches its door open/closed on each interaction.
@export var target_id := ""
var target_door: LockedDoor
var latched := false
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/art/objects/kenney/reset_lever.png")
	_sprite.scale = Vector2.ONE * 4.0
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_refresh_look()


func interact() -> void:
	if target_door != null:
		latched = not latched
		target_door.set_held_open(latched)
		_refresh_look()
		SceneManager.show_dialogue([
			"You pull the lever %s." % ("ON" if latched else "OFF"),
			"The linked gate %s." % ("slides open" if latched else "slides shut"),
		])
		return
	if room:
		room.reset_puzzle()
	SceneManager.show_dialogue([
		"Reset lever - use only if a block gets stuck.",
		"You pull it. Every movable block returns to where it began.",
	])


func _refresh_look() -> void:
	if _sprite == null:
		return
	_sprite.flip_h = latched
	_sprite.modulate = Color(0.62, 1.0, 0.68) if latched else Color.WHITE
