extends Node
## 1280x720 under-one-minute review artifact for T-080.

const Manifest = preload("res://scripts/assets/kenney_manifest.gd")

var out_path := "user://kenney_contact_sheet.png"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	var data: Dictionary = Manifest.load_file("res://assets/art/kenney_manifest.json")
	var title := Label.new()
	title.text = "KENNEY-FIRST RUNTIME SKELETON  •  16px source / 4x world / nearest"
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)
	for i in data.entries.size():
		var entry: Dictionary = data.entries[i]
		var card := Control.new()
		card.position = Vector2(28 + (i % 9) * 138, 62 + (i / 9) * 154)
		var bg := ColorRect.new()
		bg.color = Color("182133")
		bg.size = Vector2(124, 138)
		card.add_child(bg)
		var sprite := Sprite2D.new()
		sprite.texture = load(entry.runtime_path)
		sprite.position = Vector2(62, 48)
		sprite.scale = Vector2.ONE * (4.0 if entry.scale >= 4 else 2.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		card.add_child(sprite)
		var label := Label.new()
		label.text = entry.runtime_name.replace("_", " ")
		label.position = Vector2(6, 92)
		label.size = Vector2(112, 42)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		card.add_child(label)
		add_child(card)
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_path)
	print("KENNEY CONTACT SHEET: wrote ", out_path)
	get_tree().quit(0)
