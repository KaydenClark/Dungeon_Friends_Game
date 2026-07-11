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
var _handle: ColorRect


func _ready() -> void:
	# Placeholder art: a bronze base with an upright handle.
	var base := ColorRect.new()
	base.color = Color(0.42, 0.32, 0.2)
	base.position = Vector2(-20, 2)
	base.size = Vector2(40, 22)
	add_child(base)
	_handle = ColorRect.new()
	_handle.color = Color(0.75, 0.62, 0.3)
	_handle.position = Vector2(-4, -24)
	_handle.size = Vector2(8, 28)
	add_child(_handle)
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
	if _handle == null:
		return
	_handle.position = Vector2(8, -18) if latched else Vector2(-4, -24)
	_handle.color = Color(0.45, 0.95, 0.55) if latched else Color(0.75, 0.62, 0.3)
