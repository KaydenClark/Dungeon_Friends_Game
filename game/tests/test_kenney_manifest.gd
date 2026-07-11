extends "res://tests/gd_test.gd"

const MANIFEST_PATH := "res://assets/art/kenney_manifest.json"
const Manifest = preload("res://scripts/assets/kenney_manifest.gd")


func test_manifest_contract_and_coverage() -> void:
	var result: Dictionary = Manifest.validate_file(MANIFEST_PATH)
	ok(result.errors.is_empty(), "manifest contract validates: %s" % [result.errors])
	eq(result.entries, 36, "all selected runtime roles are recorded")
	for role in ["forest_ground", "dungeon_floor", "hero", "buddy",
			"healer", "quest_npc", "forest_slime", "dungeon_slime",
			"boss_slime", "door_closed", "chest_closed", "save_crystal",
			"ui_panel", "prompt_keyboard_confirm", "prompt_controller_confirm"]:
		ok(result.names.has(role), "manifest covers %s" % role)


func test_promoted_files_exist() -> void:
	var data: Dictionary = Manifest.load_file(MANIFEST_PATH)
	for entry: Dictionary in data.get("entries", []):
		var runtime_path := str(entry.get("runtime_path", ""))
		ok(ResourceLoader.exists(runtime_path), "promoted file exists: %s" % runtime_path)
