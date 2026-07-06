class_name NPC
extends Node2D
## Static NPC occupant. Blocks the cell it stands on; `interact` (from the
## player facing it) opens its dialogue. Builder must set `room` and `cell`
## before registering.

var room: RoomGrid
var cell := Vector2i.ZERO
var lines := PackedStringArray()


func _ready() -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.93, 0.78, 0.25)
	rect.position = Vector2(-24, -24)
	rect.size = Vector2(48, 48)
	add_child(rect)
	var eyes := ColorRect.new()
	eyes.color = Color(0, 0, 0, 0.55)
	eyes.position = Vector2(-6, 6)
	eyes.size = Vector2(12, 12)
	add_child(eyes)


func interact() -> void:
	SceneManager.show_dialogue(lines)
