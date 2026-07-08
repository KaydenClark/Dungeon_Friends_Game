extends "res://tests/gd_test.gd"
## Red/green suite for T-034 (M3.1): ItemData records, the ItemLibrary
## id -> ItemData lookup, and the {item_id: qty} inventory. Written
## failing-first per /RUNBOOK.md -> Test Coverage Policy. The contract:
## authored items live in game/data/items/ and resolve through ItemLibrary;
## keys and equipment never stack past qty 1 (the old loot dedup rule);
## consumables stack; removing the last of an item erases its key so
## Dictionary.has() keeps working as the "do I own it" check doors and
## chests rely on.


func test_library_lookup_finds_every_authored_item() -> void:
	for id in ["forest_key", "dungeon_key", "shield", "tonic"]:
		var item: ItemData = ItemLibrary.get_item(id)
		not_null(item, "%s loads from the library" % id)
		if item:
			eq(item.id, id, "%s record carries its own id" % id)
			ne(item.display_name, "", "%s has a display name" % id)
	is_null(ItemLibrary.get_item("no_such_item"), "unknown id -> null")


func test_display_name_reads_the_record_with_capitalize_fallback() -> void:
	eq(ItemLibrary.display_name("forest_key"), "Forest Key",
			"forest key display name comes from the .tres")
	eq(ItemLibrary.display_name("dungeon_key"), "Dungeon Key",
			"dungeon key display name comes from the .tres")
	eq(ItemLibrary.display_name("shield"), "Shield",
			"shield display name comes from the .tres")
	eq(ItemLibrary.display_name("mystery_thing"), "Mystery Thing",
			"unknown ids fall back to id.capitalize() (tests/dev items)")


func test_item_types_match_the_design() -> void:
	eq(ItemLibrary.get_item("forest_key").item_type, ItemData.ItemType.KEY_ITEM,
			"forest key is a key item")
	eq(ItemLibrary.get_item("dungeon_key").item_type, ItemData.ItemType.KEY_ITEM,
			"dungeon key is a key item")
	eq(ItemLibrary.get_item("shield").item_type, ItemData.ItemType.EQUIPMENT,
			"shield is equipment (D-007 gates Defend on it at T-046)")
	eq(ItemLibrary.get_item("tonic").item_type, ItemData.ItemType.CONSUMABLE,
			"tonic is the first consumable record")
	not_ok(ItemLibrary.get_item("shield").is_stackable(),
			"equipment never stacks")
	ok(ItemLibrary.get_item("tonic").is_stackable(), "consumables stack")


func test_inventory_is_id_to_qty() -> void:
	SceneManager.state = GameState.new()
	SceneManager.add_item("dungeon_key")
	eq(SceneManager.inventory.get("dungeon_key", 0), 1,
			"adding an item records qty 1")
	ok(SceneManager.inventory.has("dungeon_key"),
			"doors/chests keep matching on string ids via has()")
	SceneManager.reset_session_state()


func test_keys_and_equipment_never_stack() -> void:
	SceneManager.state = GameState.new()
	SceneManager.add_item("dungeon_key")
	SceneManager.add_item("dungeon_key")
	eq(SceneManager.inventory.get("dungeon_key", 0), 1,
			"a second identical key is a no-op (loot dedup)")
	SceneManager.add_item("shield")
	SceneManager.add_item("shield")
	eq(SceneManager.inventory.get("shield", 0), 1, "equipment stays unique")
	SceneManager.reset_session_state()


func test_consumables_stack_and_remove_decrements() -> void:
	SceneManager.state = GameState.new()
	SceneManager.add_item("tonic")
	SceneManager.add_item("tonic")
	eq(SceneManager.inventory.get("tonic", 0), 2, "consumables stack to qty 2")
	SceneManager.remove_item("tonic")
	eq(SceneManager.inventory.get("tonic", 0), 1, "remove_item decrements")
	SceneManager.remove_item("tonic")
	not_ok(SceneManager.inventory.has("tonic"),
			"removing the last one erases the key (has() stays truthful)")
	SceneManager.remove_item("tonic")
	eq(SceneManager.inventory.size(), 0,
			"removing an absent item is a safe no-op")
	SceneManager.reset_session_state()


func test_victory_banner_uses_display_names() -> void:
	SceneManager.state = GameState.new()
	var boss: EnemyStats = load("res://data/enemies/boss_slime.tres")
	var msg := SceneManager.apply_victory_rewards(boss)
	ok(msg.contains("Forest Key"),
			"the drop clause names the item, not its id")
	not_ok(msg.contains("forest_key"), "raw ids never reach the player")
	SceneManager.reset_session_state()
