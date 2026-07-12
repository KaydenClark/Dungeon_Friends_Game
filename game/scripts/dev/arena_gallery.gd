extends Node
## T-075's under-one-minute authoring artifact. It renders the same imported
## LDtk levels, loader, and validator production combat uses, with deployment
## zones overlaid so an author can inspect every shipped board at once.
##
## Run: Godot --path . scenes/dev/arena_gallery.tscn -- --out=/tmp/arenas.png

const CELL := 24.0  # 16px LDtk source cells at a readable 1.5x gallery scale.
const COLUMNS := 3
const CARD_W := 410.0
const CARD_H := 210.0

var out_path := "user://arena_gallery.png"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	var background := ColorRect.new()
	background.color = Color("101827")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title := Label.new()
	title.text = "AUTHORED BATTLE ARENAS  •  forest + dungeon  •  green=party / red=enemy"
	title.position = Vector2(18, 18)
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(0.9, 0.96, 0.82)
	add_child(title)
	var registry := ArenaLibrary.registry()
	for i in registry.all().size():
		var record: ArenaData = registry.all()[i]
		_add_card(record, i)
	for _frame in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_path)
	print("AUTHORED ARENA GALLERY: wrote ", out_path)
	get_tree().quit(0)


func _add_card(record: ArenaData, index: int) -> void:
	var card := Node2D.new()
	card.position = Vector2(18 + (index % COLUMNS) * (CARD_W + 5),
						68 + (index / COLUMNS) * (CARD_H + 4))
	add_child(card)
	var frame := ColorRect.new()
	frame.color = Color("1d2940")
	frame.position = Vector2(-2, -2)
	frame.size = Vector2(CARD_W, CARD_H)
	card.add_child(frame)
	var loaded := AuthoredArenaLoader.load_record(record, true)
	var status := "LOAD ERROR: %s" % str(loaded.get("error", "unknown"))
	if bool(loaded.get("ok", false)):
		var arena: Dictionary = loaded["arena"]
		var visual := arena.get("visual") as Node2D
		if visual != null:
			visual.scale = Vector2.ONE * 0.375  # imported 4x visual -> 1.5x source art
			card.add_child(visual)
		_draw_zone(card, arena.get("party_zone", []), Color(0.25, 0.9, 0.45, 0.38))
		_draw_zone(card, arena.get("enemy_zone", []), Color(0.95, 0.28, 0.3, 0.38))
		var errors := ArenaValidator.validate(arena)
		status = "VALID ✓" if errors.is_empty() else "INVALID: " + "; ".join(errors)
	var info := Label.new()
	info.position = Vector2(4, 171)
	info.size = Vector2(CARD_W - 8, 36)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 12)
	info.text = "%s  •  %s / weight %d\n%s  •  %s" % [
		record.id, record.tier, record.weight, ", ".join(record.tags), status]
	info.modulate = Color(0.83, 0.9, 0.96) if status.begins_with("VALID") else Color(1.0, 0.55, 0.5)
	card.add_child(info)


func _draw_zone(card: Node2D, cells: Variant, color: Color) -> void:
	if not cells is Array:
		return
	for cell in cells:
		if not cell is Vector2i:
			continue
		var overlay := ColorRect.new()
		overlay.color = color
		overlay.position = Vector2(cell) * CELL + Vector2(2, 2)
		overlay.size = Vector2(CELL - 4, CELL - 4)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(overlay)
