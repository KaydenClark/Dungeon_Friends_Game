class_name KenneyManifest
extends RefCounted
## Validation boundary for the deterministic Kenney promotion manifest.


static func load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func validate_file(path: String) -> Dictionary:
	var data := load_file(path)
	var errors: Array[String] = []
	var names := {}
	if data.get("source_cell", 0) != 16:
		errors.append("source_cell must be 16")
	if data.get("display_scale", 0) != 4:
		errors.append("display_scale must be 4")
	if data.get("filter", "") != "nearest":
		errors.append("filter must be nearest")
	var entries: Array = data.get("entries", [])
	for raw: Variant in entries:
		if not raw is Dictionary:
			errors.append("entry is not an object")
			continue
		var entry: Dictionary = raw
		var name := str(entry.get("runtime_name", ""))
		if name == "":
			errors.append("entry missing runtime_name")
		elif names.has(name):
			errors.append("duplicate runtime_name: %s" % name)
		names[name] = true
		var source := str(entry.get("source", ""))
		var rect: Array = entry.get("rect", [])
		if source == "" or rect.size() != 4:
			errors.append("%s missing source/rect" % name)
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(source))
		if image == null or image.is_empty():
			errors.append("%s source does not load" % name)
			continue
		var region := Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))
		if region.position.x < 0 or region.position.y < 0 \
				or region.end.x > image.get_width() or region.end.y > image.get_height():
			errors.append("%s source region out of bounds" % name)
		if str(entry.get("runtime_path", "")) == "":
			errors.append("%s missing runtime_path" % name)
	return {"errors": errors, "entries": entries.size(), "names": names}
