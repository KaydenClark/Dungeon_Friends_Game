class_name SaveManager
extends Object
## Save-file I/O (T-037). Static helpers owned by SceneManager call sites -
## deliberately NOT a new autoload (single-autoload lock, see /BLUEPRINT.md
## -> Architecture). D-006: JSON at user://saves/slot_N.json, 3 slots.
## Writes are atomic (temp file + rename) so a crash mid-write can never
## corrupt an existing save; loads are tolerant (missing/corrupt -> null +
## warning, never a crash). The `dir` parameter exists for tests, which use
## a scratch dir so they can't clobber real saves.

const DEFAULT_DIR := "user://saves"
const SLOT_COUNT := 3


static func path_for(slot: int, dir := DEFAULT_DIR) -> String:
	return "%s/slot_%d.json" % [dir, slot]


## Snapshot the live session into a SaveData (deep copies - the save must not
## keep mutating with the session after capture).
static func capture(state: GameState, current_map: String,
		player_position: Vector2i) -> SaveData:
	var out := SaveData.new()
	out.current_map = current_map
	out.player_position = player_position
	out.party_roster = state.party_roster.duplicate()
	out.party_levels = state.party_levels.duplicate()
	out.party_xp = state.party_xp.duplicate()
	out.party_hp = state.party_hp.duplicate()
	out.party_mp = state.party_mp.duplicate()
	out.inventory = state.inventory.duplicate()
	out.flags = state.flags.duplicate()
	out.arena_selector_state = state.arena_selector_state.duplicate(true)
	out.party_formation = state.party_formation
	return out


## Atomic write: land the JSON in a temp file, then rename over the slot
## file. Rename within one directory is atomic on every platform Godot
## targets, so the slot file is always either the old save or the new one.
static func write(slot: int, data: SaveData, dir := DEFAULT_DIR) -> bool:
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("SaveManager: cannot create %s (%s)" % [dir, error_string(err)])
		return false
	var final_path := path_for(slot, dir)
	var tmp_path := final_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: cannot open %s for writing (%s)"
				% [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data.to_dict(), "  "))
	f.close()
	err = DirAccess.rename_absolute(tmp_path, final_path)
	if err != OK:
		push_warning("SaveManager: rename to %s failed (%s)"
				% [final_path, error_string(err)])
		return false
	return true


## Tolerant load: null (plus a warning for anything but a plain missing file)
## instead of a crash, whatever is on disk.
static func load_slot(slot: int, dir := DEFAULT_DIR) -> SaveData:
	var path := path_for(slot, dir)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SaveManager: cannot open %s (%s)"
				% [path, error_string(FileAccess.get_open_error())])
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	var data := SaveData.from_dict(parsed)
	if data == null:
		push_warning("SaveManager: %s is corrupt or not a save file - ignoring it"
				% path)
	return data


static func slot_exists(slot: int, dir := DEFAULT_DIR) -> bool:
	return FileAccess.file_exists(path_for(slot, dir))


static func any_save_exists(dir := DEFAULT_DIR) -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if slot_exists(slot, dir):
			return true
	return false
