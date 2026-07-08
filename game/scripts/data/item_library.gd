class_name ItemLibrary
## Static id -> ItemData lookup over the authored records in
## game/data/items/ (T-034). One place knows where item .tres files live;
## everyone else asks by id string. New items: add the .tres, list its path
## here. Unknown ids resolve to null (get_item) or an id.capitalize()
## fallback (display_name) so test-only/dev ids never crash a dialogue.

const _ITEM_PATHS := [
	"res://data/items/forest_key.tres",
	"res://data/items/dungeon_key.tres",
	"res://data/items/shield.tres",
	"res://data/items/tonic.tres",
]

static var _index: Dictionary = {}


static func get_item(id: String) -> ItemData:
	if _index.is_empty():
		for path in _ITEM_PATHS:
			var item: ItemData = load(path)
			if item:
				_index[item.id] = item
	return _index.get(id)


static func display_name(id: String) -> String:
	var item := get_item(id)
	return item.display_name if item else id.capitalize()
