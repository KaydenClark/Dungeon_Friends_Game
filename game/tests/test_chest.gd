extends "res://tests/gd_test.gd"
## Unit tests for the Chest interactable + chest-key flow (T-026): a locked
## chest refuses to open without its matching key, opens with it, grants its
## reward exactly once, and persists its opened state through room rebuilds
## via SceneManager.flags.
##
## SceneManager is an autoload, so shared state (inventory, flags) is reset
## around each test.


func _reset() -> void:
	SceneManager.inventory = PackedStringArray()
	SceneManager.flags = {}


func _chest(locked := true) -> Chest:
	var c := Chest.new()
	c.id = "test_chest"
	c.required_key = "chest_key" if locked else ""
	c.reward_item = "shield"
	add_child(c)
	return c


func test_locked_chest_refuses_without_key() -> void:
	_reset()
	var c := _chest()
	c.interact()
	not_ok(c.opened, "locked chest stays shut without the key")
	not_ok(SceneManager.inventory.has("shield"), "no reward without the key")
	c.queue_free()
	_reset()


func test_locked_chest_opens_with_key() -> void:
	_reset()
	SceneManager.inventory.append("chest_key")
	var c := _chest()
	c.interact()
	ok(c.opened, "chest opens once the key is held")
	ok(SceneManager.inventory.has("shield"), "shield granted (plain item, D-001)")
	ok(SceneManager.flags.get("chest_test_chest_opened", false),
			"opened state recorded in session flags")
	c.queue_free()
	_reset()


func test_reward_granted_only_once() -> void:
	_reset()
	SceneManager.inventory.append("chest_key")
	var c := _chest()
	c.interact()
	c.interact()   # already opened: "the chest is empty"
	var shields := 0
	for item in SceneManager.inventory:
		if item == "shield":
			shields += 1
	eq(shields, 1, "shield appears exactly once after repeat interactions")
	c.queue_free()
	_reset()


func test_unlocked_chest_opens_freely() -> void:
	_reset()
	var c := _chest(false)
	c.interact()
	ok(c.opened, "a keyless chest opens on interact")
	ok(SceneManager.inventory.has("shield"), "reward granted")
	c.queue_free()
	_reset()


func test_opened_state_persists_across_rebuild() -> void:
	_reset()
	SceneManager.inventory.append("chest_key")
	var first := _chest()
	first.interact()
	first.queue_free()
	# A rebuilt room re-creates the chest and restores from flags (rooms are
	# freed and rebuilt on re-entry, so this is the persistence path).
	var rebuilt := _chest()
	rebuilt.restore_state()
	ok(rebuilt.opened, "rebuilt chest remembers it was opened")
	rebuilt.interact()
	var shields := 0
	for item in SceneManager.inventory:
		if item == "shield":
			shields += 1
	eq(shields, 1, "no second reward from the rebuilt chest")
	rebuilt.queue_free()
	_reset()
