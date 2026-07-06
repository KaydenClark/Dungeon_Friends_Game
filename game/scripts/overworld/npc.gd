class_name NPC
extends Node2D
## Static NPC occupant. Blocks the cell it stands on; `interact` (from the
## player facing it) opens its dialogue. Builder must set `room` and `cell`
## before registering.

var room: RoomGrid
var cell := Vector2i.ZERO
var lines := PackedStringArray()
## Placeholder body color until real sprites land (M1.1); the builder can
## override it to tell NPC roles apart (quest giver vs healer).
var color := Color(0.93, 0.78, 0.25)
## When true, interacting fully restores the hero's HP before the dialogue.
var heals := false


func _ready() -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = Vector2(-24, -24)
	rect.size = Vector2(48, 48)
	add_child(rect)
	var eyes := ColorRect.new()
	eyes.color = Color(0, 0, 0, 0.55)
	eyes.position = Vector2(-6, 6)
	eyes.size = Vector2(12, 12)
	add_child(eyes)


func interact() -> void:
	if heals and SceneManager.hero_stats:
		SceneManager.hero_hp = SceneManager.hero_stats.max_hp
	SceneManager.show_dialogue(lines)
