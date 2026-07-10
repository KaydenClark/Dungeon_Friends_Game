class_name ItemData
extends Resource
## Item record (T-034; see /BLUEPRINT.md -> Data Model). All item facts live
## in .tres instances under game/data/items/, never in scene scripts (locked
## decision). Looked up by id through ItemLibrary.

enum ItemType { KEY_ITEM, CONSUMABLE, EQUIPMENT }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.KEY_ITEM
## Stretch fields (S-001 equipment / combat consumables): present so the
## schema doesn't churn later, consumed by nothing at MVP.
@export var stat_modifiers: Dictionary = {}
@export var on_use_ability: String = ""


## Only consumables stack in the {id: qty} inventory; keys and gear are
## unique (a second copy is ignored - the long-standing loot-dedup rule).
func stacks() -> bool:
	return item_type == ItemType.CONSUMABLE
