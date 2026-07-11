extends SceneTree
## Deterministic preparation step. Crops only selected transparent atlas
## regions into stable runtime paths and assembles the five-slot LDtk strip.

const MANIFEST := "res://assets/art/kenney_manifest.json"
const Manifest = preload("res://scripts/assets/kenney_manifest.gd")
const WORLD_ORDER := [
	"forest_tree", "forest_ground", "forest_path", "dungeon_wall", "dungeon_floor"
]


func _init() -> void:
	var data: Dictionary = Manifest.load_file(MANIFEST)
	var by_name := {}
	for entry: Dictionary in data.get("entries", []):
		var source := Image.load_from_file(ProjectSettings.globalize_path(entry.source))
		var rect_data: Array = entry.rect
		var rect := Rect2i(rect_data[0], rect_data[1], rect_data[2], rect_data[3])
		var cropped := source.get_region(rect)
		var out_path := ProjectSettings.globalize_path(entry.runtime_path)
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var err := cropped.save_png(out_path)
		if err != OK:
			push_error("Kenney promotion failed for %s" % entry.runtime_name)
		by_name[entry.runtime_name] = cropped
	var strip := Image.create(80, 16, false, Image.FORMAT_RGBA8)
	strip.fill(Color.TRANSPARENT)
	for i in WORLD_ORDER.size():
		strip.blit_rect(by_name[WORLD_ORDER[i]], Rect2i(0, 0, 16, 16), Vector2i(i * 16, 0))
	var strip_path := ProjectSettings.globalize_path(
			"res://assets/art/tilesets/kenney/world_tiles.png")
	strip.save_png(strip_path)
	print("KENNEY PREP: promoted %d assets + world strip" % by_name.size())
	quit()
