class_name NPC
extends Node2D
## Static NPC occupant. Blocks the cell it stands on; `interact` (from the
## player facing it) opens its dialogue. Builder must set `room` and `cell`
## before registering.

var room: RoomGrid
var cell := Vector2i.ZERO
@export var lines := PackedStringArray()
## Placeholder body color until real sprites land (M1.1); the builder can
## override it to tell NPC roles apart (quest giver vs healer).
@export var color := Color(0.93, 0.78, 0.25)
## When true, interacting fully restores the hero's HP before the dialogue.
@export var heals := false


func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "RuntimeSprite"
	sprite.texture = load("res://assets/art/sprites/runtime/kenney/healer.png" \
			if heals else "res://assets/art/sprites/runtime/kenney/quest_npc.png")
	sprite.scale = Vector2.ONE * 4.0
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func interact() -> void:
	if heals:
		SceneManager.heal_hero_to_full()
	SceneManager.show_dialogue(lines)
