class_name Chest
extends Node2D
## Treasure chest interactable (T-026). Placed visibly in the room from the
## start - no reveal triggers ("if you're confused the players will be too",
## locked decision). May be locked behind a matching key item, reusing the
## LockedDoor key-check pattern; opening grants its reward once. Opened state
## persists across room rebuilds via SceneManager.flags (rooms are freed and
## rebuilt on re-entry), keyed by `id`.

var room: RoomGrid
var cell := Vector2i.ZERO
@export var id := "chest"
## Empty string = unlocked chest.
@export var required_key := ""
@export var reward_item := ""
var opened := false
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2.ONE * 4.0
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_refresh_look()


## Restore persisted state. Called by the room builder after `id` is set.
func restore_state() -> void:
	opened = SceneManager.flags.get(_flag_name(), false)
	_refresh_look()


func interact() -> void:
	if opened:
		SceneManager.show_dialogue(["The chest is empty."])
		return
	if required_key != "" and not SceneManager.inventory.has(required_key):
		SceneManager.show_dialogue([
			"The chest is locked - a sturdy little lock.",
			"Its key must be around here somewhere...",
		])
		return
	opened = true
	SceneManager.flags[_flag_name()] = true
	var lines := PackedStringArray()
	if required_key != "":
		lines.append("You unlock the chest with the %s."
				% ItemLibrary.display_name(required_key))
	if reward_item != "" and not SceneManager.inventory.has(reward_item):
		SceneManager.add_item(reward_item)
		lines.append("You got the %s!" % ItemLibrary.display_name(reward_item))
		if reward_item == "shield":
			# D-007: the shield unlocks the Defend command (T-046).
			lines.append("You can now Defend in combat!")
	else:
		lines.append("It's empty...")
	_refresh_look()
	SceneManager.show_dialogue(lines)


func _flag_name() -> String:
	return "chest_%s_opened" % id


func _refresh_look() -> void:
	if _sprite:
		_sprite.texture = load("res://assets/art/objects/kenney/chest_open.png" \
				if opened else "res://assets/art/objects/kenney/chest_closed.png")
