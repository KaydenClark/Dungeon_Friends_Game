extends "res://tests/gd_test.gd"
## Unit tests for SaveData + SaveManager (T-037, red/green). The contract:
## capture() snapshots the whole session (GameState payload + map id + player
## cell), write() lands it as JSON in a slot file atomically (temp + rename),
## and load_slot() round-trips it exactly - or returns null with a warning on
## a missing/corrupt file, never a crash. Slots are isolated from each other.
##
## Tests write to a dedicated user://saves_test dir (wiped per test) so they
## can never clobber a real player save in user://saves.

const TEST_DIR := "user://saves_test"


func _wipe_test_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir == null or not dir.dir_exists("saves_test"):
		return
	var inner := DirAccess.open(TEST_DIR)
	for f in inner.get_files():
		inner.remove(f)
	dir.remove("saves_test")


## A recognizably non-default session to round-trip.
func _sample_state() -> GameState:
	var s := GameState.new()
	s.party_levels = {"hero": 3, "companion_test": 2}
	s.party_xp = {"hero": 120, "companion_test": 45}
	s.party_hp = {"hero": 7, "companion_test": 12}
	s.party_mp = {"hero": 2, "companion_test": 5}
	s.inventory = {"forest_key": 1, "potion": 3}
	s.flags = {"door_boss_door_opened": true, "hub_seen": true}
	return s


func test_capture_snapshots_the_session() -> void:
	var data := SaveManager.capture(_sample_state(), "tutorial_hub", Vector2i(4, 9))
	eq(data.current_map, "tutorial_hub", "capture keeps the map id")
	eq(data.player_position, Vector2i(4, 9), "capture keeps the player cell")
	eq(data.party_xp.get("hero"), 120, "capture keeps party XP")
	eq(data.inventory.get("potion"), 3, "capture keeps stacked items")
	ok(data.flags.get("hub_seen", false), "capture keeps flags")
	eq(data.schema_version, SaveData.SCHEMA_VERSION, "capture stamps the schema version")


func test_round_trip_preserves_everything() -> void:
	_wipe_test_dir()
	var data := SaveManager.capture(_sample_state(), "forest", Vector2i(14, 4))
	ok(SaveManager.write(1, data, TEST_DIR), "write reports success")
	var loaded := SaveManager.load_slot(1, TEST_DIR)
	not_null(loaded, "the written slot loads")
	if loaded == null:
		return
	eq(loaded.current_map, "forest", "map id survives")
	eq(loaded.player_position, Vector2i(14, 4), "player cell survives as Vector2i")
	eq(loaded.party_roster, ["hero", "companion_test"], "roster survives")
	eq(loaded.party_levels, {"hero": 3, "companion_test": 2}, "levels survive")
	eq(loaded.party_xp, {"hero": 120, "companion_test": 45}, "xp survives")
	eq(loaded.party_hp, {"hero": 7, "companion_test": 12}, "hp survives")
	eq(loaded.party_mp, {"hero": 2, "companion_test": 5}, "mp survives")
	eq(loaded.inventory, {"forest_key": 1, "potion": 3}, "inventory survives")
	eq(loaded.flags, {"door_boss_door_opened": true, "hub_seen": true},
			"flags survive")
	# JSON parses every number as float; the loader must hand back ints or
	# typed comparisons and Dictionary equality break all over the game.
	ok(loaded.party_xp["hero"] is int, "loaded xp values are ints, not floats")
	ok(loaded.inventory["potion"] is int, "loaded item quantities are ints")
	_wipe_test_dir()


func test_to_game_state_rebuilds_the_session() -> void:
	var data := SaveManager.capture(_sample_state(), "forest", Vector2i(1, 1))
	var rebuilt := data.to_game_state()
	eq(rebuilt.party_xp.get("hero"), 120, "rebuilt state carries XP")
	eq(rebuilt.inventory.get("potion"), 3, "rebuilt state carries inventory")
	ok(rebuilt.flags.get("hub_seen", false), "rebuilt state carries flags")


func test_capture_copies_do_not_alias_the_live_state() -> void:
	var state := _sample_state()
	var data := SaveManager.capture(state, "forest", Vector2i.ZERO)
	state.inventory["potion"] = 99
	state.flags["late_flag"] = true
	eq(data.inventory.get("potion"), 3, "captured inventory is a copy")
	not_ok(data.flags.has("late_flag"), "captured flags are a copy")


func test_missing_file_loads_as_null() -> void:
	_wipe_test_dir()
	is_null(SaveManager.load_slot(2, TEST_DIR), "missing slot -> null, no crash")


func test_corrupt_file_loads_as_null() -> void:
	_wipe_test_dir()
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var f := FileAccess.open(TEST_DIR + "/slot_3.json", FileAccess.WRITE)
	f.store_string("{this is not json")
	f.close()
	is_null(SaveManager.load_slot(3, TEST_DIR), "corrupt JSON -> null, no crash")
	var g := FileAccess.open(TEST_DIR + "/slot_3.json", FileAccess.WRITE)
	g.store_string("[1, 2, 3]")   # valid JSON, wrong shape
	g.close()
	is_null(SaveManager.load_slot(3, TEST_DIR), "non-dict JSON -> null, no crash")
	_wipe_test_dir()


func test_slots_are_isolated() -> void:
	_wipe_test_dir()
	var a := SaveManager.capture(_sample_state(), "forest", Vector2i(1, 1))
	var b_state := GameState.new()
	b_state.party_xp = {"hero": 999, "companion_test": 0}
	var b := SaveManager.capture(b_state, "tutorial_hub", Vector2i(2, 2))
	SaveManager.write(1, a, TEST_DIR)
	SaveManager.write(2, b, TEST_DIR)
	var la := SaveManager.load_slot(1, TEST_DIR)
	var lb := SaveManager.load_slot(2, TEST_DIR)
	eq(la.current_map, "forest", "slot 1 keeps its own data")
	eq(lb.current_map, "tutorial_hub", "slot 2 keeps its own data")
	eq(lb.party_xp.get("hero"), 999, "slot 2 payload is slot 2's")
	_wipe_test_dir()


func test_write_leaves_no_temp_file() -> void:
	_wipe_test_dir()
	var data := SaveManager.capture(_sample_state(), "forest", Vector2i.ZERO)
	SaveManager.write(1, data, TEST_DIR)
	var files := DirAccess.open(TEST_DIR).get_files()
	eq(files.size(), 1, "atomic write leaves exactly the slot file behind")
	eq(files[0], "slot_1.json", "the one file is the slot file")
	_wipe_test_dir()


func test_slot_exists_and_any_save() -> void:
	_wipe_test_dir()
	not_ok(SaveManager.slot_exists(1, TEST_DIR), "no file -> slot_exists false")
	not_ok(SaveManager.any_save_exists(TEST_DIR), "no files -> any_save false")
	var data := SaveManager.capture(GameState.new(), "forest", Vector2i.ZERO)
	SaveManager.write(2, data, TEST_DIR)
	not_ok(SaveManager.slot_exists(1, TEST_DIR), "slot 1 still empty")
	ok(SaveManager.slot_exists(2, TEST_DIR), "slot 2 exists after write")
	ok(SaveManager.any_save_exists(TEST_DIR), "any_save sees slot 2")
	_wipe_test_dir()
