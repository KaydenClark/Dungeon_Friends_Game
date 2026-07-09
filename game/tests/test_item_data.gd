extends "res://tests/gd_test.gd"
## Unit tests for ItemData + ItemLibrary + the {id: qty} inventory (T-034).
## The contract: game/data/items/*.tres are the item records, ItemLibrary is
## the id -> ItemData lookup, GameState.inventory is a {id: qty} Dictionary,
## SceneManager.add_item()/remove_item() are the only write paths - key
## items and equipment never stack, consumables do. Every test ends on
## reset_session_state() so later suites see a clean session.


func test_library_loads_the_shipped_items() -> void:
	var key: ItemData = ItemLibrary.get_item("forest_key")
	ok(key != null, "forest_key.tres loads through the library")
	eq(key.display_name, "Forest Key", "forest_key carries its display name")
	eq(key.item_type, ItemData.ItemType.KEY_ITEM, "forest_key is a key item")
	var dkey: ItemData = ItemLibrary.get_item("dungeon_key")
	ok(dkey != null and dkey.item_type == ItemData.ItemType.KEY_ITEM,
			"dungeon_key loads as a key item")
	var shield: ItemData = ItemLibrary.get_item("shield")
	ok(shield != null, "shield.tres loads through the library")
	eq(shield.item_type, ItemData.ItemType.EQUIPMENT, "shield is equipment")


func test_display_name_falls_back_for_unknown_ids() -> void:
	eq(ItemLibrary.display_name("shield"), "Shield",
			"known ids use the ItemData display name")
	eq(ItemLibrary.display_name("mystery_orb"), "Mystery Orb",
			"unknown ids fall back to id.capitalize()")


func test_key_items_never_stack() -> void:
	SceneManager.state = GameState.new()
	SceneManager.add_item("dungeon_key")
	SceneManager.add_item("dungeon_key")
	eq(SceneManager.inventory.get("dungeon_key"), 1,
			"a second identical key is ignored (qty stays 1)")
	eq(SceneManager.inventory.size(), 1, "no duplicate entry appears")
	SceneManager.reset_session_state()


func test_consumables_stack() -> void:
	var tonic := ItemData.new()
	tonic.id = "test_tonic"
	tonic.display_name = "Test Tonic"
	tonic.item_type = ItemData.ItemType.CONSUMABLE
	ItemLibrary.register(tonic)
	SceneManager.state = GameState.new()
	SceneManager.add_item("test_tonic")
	SceneManager.add_item("test_tonic", 2)
	eq(SceneManager.inventory.get("test_tonic"), 3, "consumables stack by qty")
	SceneManager.reset_session_state()


func test_remove_item_decrements_and_erases() -> void:
	var tonic := ItemData.new()
	tonic.id = "test_tonic"
	tonic.item_type = ItemData.ItemType.CONSUMABLE
	ItemLibrary.register(tonic)
	SceneManager.state = GameState.new()
	SceneManager.add_item("test_tonic", 2)
	ok(SceneManager.remove_item("test_tonic"), "removing 1 of 2 succeeds")
	eq(SceneManager.inventory.get("test_tonic"), 1, "qty decremented to 1")
	not_ok(SceneManager.remove_item("test_tonic", 5),
			"removing more than held is refused")
	eq(SceneManager.inventory.get("test_tonic"), 1, "refused remove changes nothing")
	ok(SceneManager.remove_item("test_tonic"), "removing the last one succeeds")
	not_ok(SceneManager.inventory.has("test_tonic"),
			"the entry is erased at zero, not left as qty 0")
	SceneManager.reset_session_state()


func test_inventory_summary_reads_display_names() -> void:
	SceneManager.state = GameState.new()
	eq(SceneManager.inventory_summary(), "-", "empty inventory reads as '-'")
	SceneManager.add_item("forest_key")
	eq(SceneManager.inventory_summary(), "Forest Key",
			"single key item shows its display name, no qty suffix")
	var tonic := ItemData.new()
	tonic.id = "test_tonic"
	tonic.display_name = "Test Tonic"
	tonic.item_type = ItemData.ItemType.CONSUMABLE
	ItemLibrary.register(tonic)
	SceneManager.add_item("test_tonic", 3)
	eq(SceneManager.inventory_summary(), "Forest Key, Test Tonic x3",
			"stacked consumables show a qty suffix")
	SceneManager.reset_session_state()
