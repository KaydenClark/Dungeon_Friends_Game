class_name AuthoredArenaLoader
extends RefCounted
## Turns one editable LDtk arena level into the small dictionary the existing
## CombatScene already consumes. The imported level itself is retained as a
## visual node so authored terrain, not a copied overworld patch or duplicate
## hand-maintained cell list, is the source of both topology and appearance.

const TILE := 64


## `record` is deliberately duck-typed: ArenaData is an authored
## Resource, but this loader stays usable by the gallery's validation fixtures.
## Returns `{ok, arena}` on success and `{ok=false, error}` for a recoverable
## authoring/import failure.
static func load_record(record: Resource, party_on_left: bool = true) -> Dictionary:
	if record == null:
		return {"ok": false, "error": "No battle arena record supplied."}
	var level_path := str(record.get("ldtk_path"))
	var level_id := str(record.get("level_id"))
	if level_path == "" or level_id == "":
		return {"ok": false, "error": "Arena record is missing LDtk path or level id."}
	var packed := load(level_path) as PackedScene
	if packed == null:
		return {"ok": false, "error": "Could not load arena LDtk scene: %s" % level_path}
	var world := packed.instantiate() as Node2D
	if world == null:
		return {"ok": false, "error": "Arena LDtk scene has no Node2D world root: %s" % level_path}
	var level := _pick_level(world, level_id)
	if level == null:
		world.queue_free()
		return {"ok": false, "error": "Arena level '%s' was not imported from %s." % [level_id, level_path]}
	for child in world.get_children():
		if child is LDTKLevel and child != level:
			child.visible = false
			child.process_mode = Node.PROCESS_MODE_DISABLED
	var wall_layer := _find_tile_layer(level, "Wall-values")
	if wall_layer == null:
		world.queue_free()
		return {"ok": false, "error": "Arena '%s' has no Wall IntGrid layer." % level_id}
	var w := int(level.size.x / 16)
	var h := int(level.size.y / 16)
	if w <= 0 or h <= 0:
		world.queue_free()
		return {"ok": false, "error": "Arena '%s' has an invalid imported size." % level_id}
	var blocked: Array[Vector2i] = []
	for cell in wall_layer.get_used_cells():
		blocked.append(cell)
	var party_zone := _deployment_cells(level, "PartyDeployment")
	var enemy_zone := _deployment_cells(level, "EnemyDeployment")
	if party_zone.is_empty() or enemy_zone.is_empty():
		world.queue_free()
		return {"ok": false, "error": "Arena '%s' is missing PartyDeployment or EnemyDeployment markers." % level_id}
	var mirrored := not party_on_left and bool(record.get("mirror_safe"))
	if mirrored:
		blocked = _mirror_cells(blocked, w)
		party_zone = _mirror_cells(party_zone, w)
		enemy_zone = _mirror_cells(enemy_zone, w)
	# Mirroring moves the authored PartyDeployment zone to the requested side;
	# a non-mirror-safe template keeps its topology and simply swaps who owns
	# the two authored deployment zones.
	if not party_on_left and not mirrored:
		var swap := party_zone
		party_zone = enemy_zone
		enemy_zone = swap
	var visual := Node2D.new()
	visual.name = "AuthoredArenaVisual"
	visual.set_meta("arena_source", level_path)
	visual.set_meta("arena_level", level_id)
	visual.set_meta("mirrored", mirrored)
	world.position = Vector2(-level.position.x * 4.0, -level.position.y * 4.0)
	world.scale = Vector2(4.0, 4.0)
	if mirrored:
		# Flip around the combat board's left edge, then translate the full
		# 17-cell source width back into view.
		world.position.x = float(w * TILE) + level.position.x * 4.0
		world.scale.x = -4.0
	visual.add_child(world)
	return {
		"ok": true,
		"arena": {
			"id": str(record.get("id")),
			"w": w,
			"h": h,
			"blocked": blocked,
			"party_zone": party_zone,
			"enemy_zone": enemy_zone,
			"biome": str(record.get("biome")),
			"tags": record.get("tags"),
			"tier": str(record.get("tier")),
			"weight": int(record.get("weight")),
			"mirrored": mirrored,
			"visual": visual,
		}
	}


static func _pick_level(world: Node, level_id: String) -> LDTKLevel:
	for child in world.get_children():
		if child is LDTKLevel and String(child.name) == level_id:
			return child
	return null


static func _find_tile_layer(root: Node, name_part: String) -> TileMapLayer:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is TileMapLayer and String(node.name).contains(name_part):
			return node
		for child in node.get_children():
			stack.append(child)
	return null


static func _deployment_cells(root: Node, identifier: String) -> Array[Vector2i]:
	var entries: Array[Dictionary] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		# Battle templates deliberately keep their marker entities as LDtk data;
		# the production importer need not instantiate gameplay objects for a
		# combat-only authoring level. Read that canonical entity data directly.
		if node is LDTKEntityLayer:
			for entity in node.entities:
				if str(entity.identifier) == identifier:
					var entity_fields: Dictionary = entity.fields
					entries.append({
						"cell": Vector2i(entity.position) / 16,
						"slot": int(entity_fields.get("Slot", 9999)),
					})
		if node.get_meta("ldtk_identifier", "") == identifier:
			var fields: Dictionary = node.get_meta("ldtk_fields", {})
			# A project can opt into the shared post-import hook. Do not double
			# count its marker children when the source LDTKEntityLayer above
			# already supplied the authoritative entities.
			if entries.is_empty():
				entries.append({
					"cell": node.get_meta("ldtk_cell", Vector2i.ZERO),
					"slot": int(fields.get("Slot", 9999)),
				})
		for child in node.get_children():
			stack.append(child)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["slot"]) < int(b["slot"])
	)
	var out: Array[Vector2i] = []
	for entry in entries:
		out.append(entry["cell"])
	return out


static func _mirror_cells(cells: Array[Vector2i], width: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in cells:
		out.append(Vector2i(width - 1 - cell.x, cell.y))
	return out
