class_name ItemData
extends Resource
## One authored item record (T-034, M3.1; Gameplan §6). Everything the game
## knows about an item lives here - code matches on `id` strings (what LDtk
## entity fields and loot tables speak), the UI reads `display_name`, and
## `item_type` decides stacking: keys and equipment are unique (qty 1),
## consumables stack. Records live as .tres under game/data/items/ and
## resolve through ItemLibrary.

enum ItemType { KEY_ITEM, CONSUMABLE, EQUIPMENT }

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var item_type: ItemType = ItemType.KEY_ITEM
## Stretch fields (M3.1 schema, consumed by nothing yet): stat_modifiers is
## the Phase 5 equipment hook ({stat: delta}), on_use_ability the Phase 4
## consumable hook (an AbilityData id).
@export var stat_modifiers: Dictionary = {}
@export var on_use_ability := ""


func is_stackable() -> bool:
	return item_type == ItemType.CONSUMABLE
