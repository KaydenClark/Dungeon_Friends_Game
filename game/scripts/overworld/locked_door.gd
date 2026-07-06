class_name LockedDoor
extends Node2D
## A locked door occupying (and blocking) one cell. Opens via `interact` when
## the required key is in the inventory. Builder must set `room` and `cell`
## before registering, and mark the cell blocked for pathfinding.

const REQUIRED_KEY := "forest_key"

var room: RoomGrid
var cell := Vector2i.ZERO
var opened := false
var panel: ColorRect


func _ready() -> void:
	panel = ColorRect.new()
	panel.color = Color(0.45, 0.29, 0.13)
	panel.position = Vector2(-28, -28)
	panel.size = Vector2(56, 56)
	add_child(panel)
	var keyhole := ColorRect.new()
	keyhole.color = Color(0.9, 0.75, 0.2)
	keyhole.position = Vector2(-5, -8)
	keyhole.size = Vector2(10, 16)
	add_child(keyhole)


func interact() -> void:
	if opened:
		return
	if SceneManager.inventory.has(REQUIRED_KEY):
		opened = true
		room.unregister(self)
		room.set_blocked(cell, false)
		visible = false
		SceneManager.show_dialogue([
			"You use the Forest Key.",
			"The old door creaks open!",
		])
	else:
		SceneManager.show_dialogue([
			"It's locked tight.",
			"Something in this forest must hold the key...",
		])
