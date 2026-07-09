class_name ItemLibrary
extends Object
## id -> ItemData lookup over game/data/items/ (T-034). Loads every .tres in
## ITEM_DIR once on first use; register() lets tests (and future dynamic
## content) add records without touching disk.

const ITEM_DIR := "res://data/items"

static var _cache: Dictionary = {}
static var _loaded := false


static func get_item(item_id: String) -> ItemData:
	if not _loaded:
		_load_all()
	return _cache.get(item_id)


## Display name for HUD/dialogue text. Unknown ids (nothing shipped should
## hit this, but dev grants might) fall back to the old id.capitalize() look.
static func display_name(item_id: String) -> String:
	var item := get_item(item_id)
	return item.display_name if item != null and item.display_name != "" \
			else item_id.capitalize()


static func register(item: ItemData) -> void:
	if not _loaded:
		_load_all()
	_cache[item.id] = item


static func _load_all() -> void:
	_loaded = true
	for file in DirAccess.get_files_at(ITEM_DIR):
		# Export builds list .tres files as .tres.remap; load the real path.
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := load("%s/%s" % [ITEM_DIR, name])
		if res is ItemData and res.id != "":
			_cache[res.id] = res
		else:
			push_warning("ItemLibrary: %s is not a valid ItemData" % name)
