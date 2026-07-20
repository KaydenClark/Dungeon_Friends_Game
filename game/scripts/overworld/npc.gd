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
## S-004/TK-002 (D-044) recruit-on-dialogue: when set, finishing this NPC's
## dialogue recruits that roster id through the fail-closed finite
## SceneManager.recruit_member and the NPC departs into the party. Adoption
## validates the id and downgrades unknowns to plain talkers.
@export var recruit_id := ""
## S-004/TK-002 (D-044) watched-cell resolution: when the watched cell gains
## the `vine` tag, `lines` swaps to `resolved_lines` and `resolved_flag` is
## recorded - a non-combat problem resolved through the shared vocabulary.
@export var watch_cell := Vector2i(-1, -1)
@export var resolved_lines := PackedStringArray()
@export var resolved_flag := ""


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
	if recruit_id == "":
		SceneManager.show_dialogue(lines)
		return
	# Recruit-on-dialogue (D-044): the join happens when the dialogue ends,
	# through the fail-closed finite recruit. On refusal (unknown id, dup,
	# full party) the NPC simply stays a talker.
	await SceneManager.show_dialogue(lines)
	if not is_inside_tree() or not SceneManager.recruit_member(recruit_id):
		return
	if room is LdtkRoom:
		(room as LdtkRoom).npc_departed(self)
