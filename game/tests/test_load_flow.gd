extends "res://tests/gd_test.gd"
## Unit tests for the load flow (T-040). The contract: save_game() then
## load_game() rebuilds the saved map through the registry, places the player
## at the saved cell, and restores the GameState payload wholesale - and a
## door opened before the save stays open after the load, because rooms
## rebuild door/chest state from flags on _ready() (verified here, not
## assumed). Runs against scratch containers + a scratch save dir, and puts
## the autoload back the way it found it.

const TEST_DIR := "user://saves_test_load"

var _world: Node2D
var _combat: Node2D
var _ui: CanvasLayer
var _transition: CanvasLayer


func _setup_containers() -> void:
	_world = Node2D.new()
	_combat = Node2D.new()
	_ui = CanvasLayer.new()
	_transition = CanvasLayer.new()
	for n in [_world, _combat, _ui, _transition]:
		add_child(n)
	SceneManager.register_main(_world, _combat, _ui, _transition)
	SceneManager.save_dir = TEST_DIR
	SceneManager.reset_session_state()
	SceneManager.current_room = null
	SceneManager.room_stack.clear()


func _teardown() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("saves_test_load"):
		for f in DirAccess.open(TEST_DIR).get_files():
			DirAccess.open(TEST_DIR).remove(f)
		dir.remove("saves_test_load")
	SceneManager.save_dir = SaveManager.DEFAULT_DIR
	SceneManager.current_room = null
	SceneManager.room_stack.clear()
	SceneManager.reset_session_state()
	for n in [_world, _combat, _ui, _transition]:
		n.free()
	SceneManager.world_container = null
	SceneManager.combat_container = null
	SceneManager.ui_layer = null
	SceneManager.transition_layer = null
	SceneManager.fade_rect = null


func test_save_then_load_restores_the_session() -> void:
	_setup_containers()
	# Play state: forest booted, the boss door already opened, loot + XP held.
	SceneManager.flags["door_forest_door_opened"] = true
	SceneManager.add_item("forest_key")
	SceneManager.add_item("potion", 2)
	SceneManager.total_xp = 77
	var room: LdtkRoom = MapRegistry.build("forest")
	SceneManager.boot_room(room)
	var there := Vector2i(10, 10)
	room.teleport(room.player, there)
	ok(SceneManager.save_game(1), "save_game writes slot 1")

	# Wreck the session, then load.
	SceneManager.reset_session_state()
	eq(SceneManager.total_xp, 0, "session really was wiped before the load")
	ok(SceneManager.load_game(1), "load_game reads slot 1 back")
	var loaded: Node2D = SceneManager.current_room
	ok(loaded is ForestRoom, "load rebuilt the saved map via the registry")
	ok(loaded != room, "load built a fresh room instance")
	if loaded is ForestRoom:
		eq(loaded.player.cell, there, "player restored to the saved cell")
		# The forest boss door was open at save time; the rebuilt room must
		# honor the flag (doors restore from flags on _ready - verified).
		var still_locked := false
		for d in loaded.doors:
			if d.link_id == "forest_door":
				still_locked = true
		not_ok(still_locked, "door opened before the save stays open after load")
	eq(SceneManager.total_xp, 77, "XP survived the save/load cycle")
	eq(SceneManager.inventory.get("potion"), 2, "stacked items survived")
	ok(SceneManager.inventory.has("forest_key"), "key items survived")
	ok(SceneManager.flags.get("door_forest_door_opened", false),
			"door flag survived")
	_teardown()


func test_load_from_an_empty_slot_fails_softly() -> void:
	_setup_containers()
	not_ok(SceneManager.load_game(3), "empty slot -> false, session untouched")
	is_null(SceneManager.current_room, "no room was booted on a failed load")
	_teardown()


func test_load_with_an_unknown_map_fails_softly() -> void:
	_setup_containers()
	var data := SaveManager.capture(GameState.new(), "no_such_map", Vector2i.ZERO)
	SaveManager.write(2, data, TEST_DIR)
	SceneManager.total_xp = 5
	not_ok(SceneManager.load_game(2), "unregistered map id -> false")
	eq(SceneManager.total_xp, 5, "failed load leaves the live session alone")
	_teardown()
