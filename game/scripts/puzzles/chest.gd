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
var _lid: ColorRect


func _ready() -> void:
	# Placeholder art: a wooden chest with a lid band that pops open.
	var chest_body := ColorRect.new()
	chest_body.color = Color(0.5, 0.33, 0.16)
	chest_body.position = Vector2(-22, -14)
	chest_body.size = Vector2(44, 34)
	add_child(chest_body)
	_lid = ColorRect.new()
	_lid.color = Color(0.62, 0.44, 0.2)
	_lid.position = Vector2(-22, -26)
	_lid.size = Vector2(44, 16)
	add_child(_lid)
	var clasp := ColorRect.new()
	clasp.color = Color(0.9, 0.75, 0.2)
	clasp.position = Vector2(-4, -16)
	clasp.size = Vector2(8, 10)
	add_child(clasp)
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
	else:
		lines.append("It's empty...")
	_refresh_look()
	SceneManager.show_dialogue(lines)


func _flag_name() -> String:
	return "chest_%s_opened" % id


func _refresh_look() -> void:
	if _lid:
		_lid.color = Color(0.3, 0.2, 0.1) if opened else Color(0.62, 0.44, 0.2)
