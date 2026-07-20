class_name LdtkRoom
extends RoomGrid
## Runtime base for a room authored in LDtk (T-031, locked decision D-002:
## levels are all-in LDtk entities). Instantiates the imported .ldtk world,
## scales the 16px art to the 64px runtime cell (M1.1 grid unit), feeds the
## Wall/Pit IntGrid layers into the RoomGrid model, and adopts every game
## object the entities_post_import hook spawned - reparenting it out of the
## scaled art space into the grid and wiring occupancy, refs, and puzzle
## signals. Room subclasses set `level_path` (and `level_name` for
## multi-level worlds) and override the _room_* hooks.

const ART_SCALE := 4.0
const ART_GRID := 16

## S-009/TK-002 authoring contract for the neutral world-state seam.
## An optional `Elevation` IntGrid layer authors integer cell elevation: its
## values MUST be declared contiguous ascending from 1, so the imported
## atlas.x index maps as elevation = index + 1 (the importer stores only the
## value index - see addons/ldtk-importer/src/layer.gd create_intgrid_layer).
## An optional `Material` IntGrid layer authors initial material tags: its
## values MUST be declared contiguous from 1 with identifiers naming
## MATERIAL_TAGS in order (vine, flammable, channel, smoke - the authorable
## subset of the D-031 ReactionCore vocabulary; transient states like
## wet/fire/ice are never authored).
## Because the import discards the declared values, the declarations are
## re-validated against the source .ldtk at build time (declaration_errors):
## a reordered or gapped declaration fails closed instead of silently
## re-meaning painted cells. Exported builds strip .ldtk sources, so that
## check runs in dev/CI where authoring happens; frozen exports carry
## already-validated data.
## Any declaration violation, unknown value, or duplicate encounter id is
## recorded in `authoring_errors` and the world-state adapter fails closed;
## the v1 room build itself stays green (S-009: v1 remains runnable until
## replacement).
const MATERIAL_TAGS := ["vine", "flammable", "channel", "smoke"]
const MAX_ELEVATION := 8
const ReactionCore := preload("res://scripts/world/reaction_core.gd")

## level_path -> Array of declaration errors, parsed once per source file.
static var _declaration_cache := {}

var level_path := ""
## Which level to use from a multi-level world ("" = the first level).
var level_name := ""

var player: Player
var npc: NPC          # first quest (non-healer) NPC, if any
var healer: NPC       # first healer NPC, if any
var boss: OverworldEnemy
var door: LockedDoor  # first door, if any (forest-slice compatibility ref)
var doors: Array = []
var plates: Array = []
var blocks: Array = []
var chests: Array = []
var levers: Array = []
var crystals: Array = []
## Doorway marker cells -> their LDtk fields ({TargetRoom, SpawnX, SpawnY}).
var doorways := {}
var spawn_cell := Vector2i.ZERO
## Set before enter_room() to spawn the player somewhere other than the
## level's PlayerSpawn (e.g. entering a room through its far door).
var spawn_override := Vector2i(-1, -1)
var puzzle: PuzzleController
## Named authoring failures (unknown material value, invalid elevation value,
## duplicate encounter id). Non-empty means the world-state adapter refuses
## this room; the v1 build continues regardless.
var authoring_errors: Array[String] = []
## Stable encounter id -> the authored (spawn) cell it was declared at.
## Survives defeats: a resolved encounter keeps its authored identity.
var authored_encounters := {}
## S-009/TK-003 visible pass-through party (D-029). The roster leader is the
## Player; every other roster member is a render-only PartyFollower driven by
## the PartyTrail model. Followers never enter the occupancy map.
var party_leader_id := ""
var party_followers: Array = []
var party_trail: PartyTrail
## S-009/TK-004 in-room encounter mode seam (D-025/D-036). Non-empty while an
## encounter is active in THIS room instance; the room, camera, positions,
## and puzzle state never change on entry or resolution. Exploration input is
## gated through SceneManager.in_encounter, and a minimal banner announces
## the mode change (the full D-036 audio/visual sting is S-012 polish).
var active_encounter_id := ""
var _active_encounter_enemy: OverworldEnemy
var _encounter_banner: CanvasLayer
var _party_toast: CanvasLayer
## S-010/TK-004 (D-037): true while followers hold real occupancy on their
## legal deployment cells for the active encounter.
var party_deployed := false
## S-012/TK-002: the production intent-round controller for the active
## in-room encounter; null outside encounters.
var room_encounter: RoomEncounter
## S-011/TK-002 (D-031): the room's LIVE material/effect state - exactly the
## {width, height, cells: {tags, statuses}} shape ReactionCore consumes.
## Seeded once at build from the validated authored Material layer; mutated
## only through commit_reaction(). The authored `materials` store stays
## intact as the rebuild-time record.
var material_state := {}

signal encounter_started(encounter_id: String)
signal encounter_resolved(encounter_id: String, victory: bool)


func _ready() -> void:
	_build()
	_room_ready()


## Post-build hook for room subclasses (welcome dialogue, extra wiring).
func _room_ready() -> void:
	pass


## Player stepped onto a doorway marker cell. Subclasses decide what the
## TargetRoom field means (enter a sub-room, exit, warp).
func _on_doorway(_fields: Dictionary) -> void:
	pass


func _build() -> void:
	var world: Node2D = (load(level_path) as PackedScene).instantiate()
	world.scale = Vector2(ART_SCALE, ART_SCALE)
	add_child(world)
	var level := _pick_level(world)
	if level == null:
		push_error("LdtkRoom: no LDTKLevel found in %s" % level_path)
		return
	# Align the picked level's origin with the room's origin and hide siblings
	# (multi-level worlds place levels at world offsets).
	world.position = -Vector2(level.position) * ART_SCALE
	for other in world.get_children():
		if other is LDTKLevel and other != level:
			other.visible = false
			other.process_mode = Node.PROCESS_MODE_DISABLED
	setup_grid(level.size.x / ART_GRID, level.size.y / ART_GRID)
	for c in _intgrid_cells(level, "Wall-values"):
		set_blocked(c, true)
	for c in _intgrid_cells(level, "Pit-values"):
		set_pit(c, true)
	_apply_authoring_layers(level)
	_seed_material_state()
	_adopt_entities(level)
	_spawn_player()
	puzzle = PuzzleController.new()
	puzzle.plates = plates
	puzzle.doors = doors
	puzzle.levers = levers
	add_child(puzzle)
	puzzle.wire()


func _pick_level(world: Node) -> LDTKLevel:
	var first: LDTKLevel = null
	for child in world.get_children():
		if child is LDTKLevel:
			if first == null:
				first = child
			if level_name == "" or String(child.name) == level_name:
				return child
	return first


func _intgrid_cells(level: Node, layer_name: String) -> Array:
	var layer := _find_tile_layer(level, layer_name)
	return layer.get_used_cells() if layer else []


## IntGrid value *index* per painted cell: the importer stores each cell as
## atlas coords (value_index, 0), so atlas.x recovers the authored value's
## position in the layer's declared value list.
func _intgrid_value_indices(level: Node, layer_name: String) -> Dictionary:
	var layer := _find_tile_layer(level, layer_name)
	if layer == null:
		return {}
	var indices := {}
	for cell in layer.get_used_cells():
		indices[cell] = layer.get_cell_atlas_coords(cell).x
	return indices


## Maps an imported Elevation IntGrid value index to its integer elevation,
## or -1 for an index outside the supported authoring range (fail closed).
static func elevation_for_index(index: int) -> int:
	if index < 0 or index + 1 > MAX_ELEVATION:
		return -1
	return index + 1


## Maps an imported Material IntGrid value index to its D-031 material tag,
## or "" for an unknown index (fail closed).
static func material_for_index(index: int) -> String:
	if index < 0 or index >= MATERIAL_TAGS.size():
		return ""
	return MATERIAL_TAGS[index]


## The stable encounter identity for an authored Enemy: its UniqueId when
## set, else a deterministic id from the authored cell. Both are stable
## across room rebuilds because both come from the authored level data.
static func encounter_id_for(unique_id: String, cell: Vector2i) -> String:
	if unique_id != "":
		return unique_id
	return "enc_%d_%d" % [cell.x, cell.y]


## Validates the source .ldtk's Elevation/Material IntGrid declarations
## against the positional authoring contract above. Returns [] when valid or
## when the source file is unavailable (exported builds; see the header note).
static func declaration_errors(path: String) -> Array:
	if _declaration_cache.has(path):
		return _declaration_cache[path]
	var errors := []
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			errors = _declaration_errors_from(parsed)
		else:
			errors.append("ldtk_source_unreadable:%s" % path)
	_declaration_cache[path] = errors
	return errors


static func _declaration_errors_from(data: Dictionary) -> Array:
	var errors := []
	var defs: Dictionary = data.get("defs", {})
	for layer in defs.get("layers", []):
		var ident := str(layer.get("identifier", ""))
		if ident != "Elevation" and ident != "Material":
			continue
		var values: Array = layer.get("intGridValues", [])
		for i in values.size():
			var value := int(values[i].get("value", -1))
			var name := str(values[i].get("identifier", "")).to_lower()
			if ident == "Elevation":
				if value != i + 1 or value > MAX_ELEVATION:
					errors.append("elevation_declaration_invalid:value_%d" % value)
			else:
				if value != i + 1 or i >= MATERIAL_TAGS.size() \
						or name != MATERIAL_TAGS[i]:
					errors.append("material_declaration_mismatch:value_%d" % value)
	return errors


## Adopts the optional Elevation/Material IntGrid layers into the RoomGrid
## world-state extensions. Fail closed: any invalid authored value voids BOTH
## stores (no partial or guessed adoption) and records a named error; the v1
## room build continues unaffected.
func _apply_authoring_layers(level: Node) -> void:
	var errors: Array[String] = []
	for declaration_error in declaration_errors(level_path):
		errors.append(str(declaration_error))
	var elevation_indices := _intgrid_value_indices(level, "Elevation-values")
	for cell: Vector2i in elevation_indices:
		if not in_bounds(cell):
			errors.append("elevation_out_of_bounds:%s" % cell)
			continue
		var value := elevation_for_index(int(elevation_indices[cell]))
		if value < 0:
			errors.append("invalid_elevation_value:%s" % cell)
			continue
		set_elevation(cell, value)
	var material_indices := _intgrid_value_indices(level, "Material-values")
	for cell: Vector2i in material_indices:
		if not in_bounds(cell):
			errors.append("material_out_of_bounds:%s" % cell)
			continue
		var tag := material_for_index(int(material_indices[cell]))
		if tag == "":
			errors.append("unknown_material_value:%s" % cell)
			continue
		add_material(cell, tag)
	if not errors.is_empty():
		elevation.clear()
		materials.clear()
		for error in errors:
			push_error("LdtkRoom authoring (%s): %s" % [level_path, error])
		authoring_errors.append_array(errors)


func _find_tile_layer(root: Node, name_part: String) -> TileMapLayer:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is TileMapLayer and String(n.name).contains(name_part):
			return n
		for c in n.get_children():
			stack.append(c)
	return null


## Walk the level's entity layers and move every post-import-spawned game
## object into the runtime grid. Opened doors and opened chests restore
## their persisted state from SceneManager.flags (rooms are freed and
## rebuilt on re-entry); enemies always respawn on a rebuild (D-009/T-048).
func _adopt_entities(level: Node) -> void:
	var adoptable: Array[Node2D] = []
	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node2D and n.has_meta("ldtk_identifier"):
			adoptable.append(n)
			continue
		for c in n.get_children():
			stack.append(c)
	for node in adoptable:
		var ident: String = node.get_meta("ldtk_identifier")
		var cell: Vector2i = node.get_meta("ldtk_cell")
		var fields: Dictionary = node.get_meta("ldtk_fields", {})
		node.get_parent().remove_child(node)
		match ident:
			"PlayerSpawn":
				spawn_cell = cell
				node.free()
			"Doorway":
				doorways[cell] = fields
				# The doorway AND its approach cells are block-free: a block on
				# the gap plugs the exit, and one parked on the only approach
				# cell is just as fatal (found by the soft-lock solver - see
				# tests/test_tutorial_softlock.gd). Blocks stay in their room.
				no_block_cells[cell] = true
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					no_block_cells[cell + d] = true
				node.free()
			"Npc":
				var p_npc: NPC = node
				p_npc.room = self
				p_npc.cell = cell
				register(p_npc, cell)
				if p_npc.heals and healer == null:
					healer = p_npc
				elif not p_npc.heals and npc == null:
					npc = p_npc
			"Enemy":
				# D-009 (T-048): enemies ALWAYS respawn on a freed-and-rebuilt
				# room, uniques and bosses included - the room-reset escape
				# valve applies to fights too. Loot dedup prevents duplicate
				# key drops; suspended rooms keep their in-visit state because
				# they are never rebuilt.
				var enemy: OverworldEnemy = node
				enemy.home_cell = cell
				# S-009/TK-002: stable encounter identity from authored data.
				enemy.world_encounter_id = encounter_id_for(enemy.unique_id, cell)
				if authored_encounters.has(enemy.world_encounter_id):
					var dup := "duplicate_encounter_id:%s" % enemy.world_encounter_id
					push_error("LdtkRoom authoring (%s): %s" % [level_path, dup])
					authoring_errors.append(dup)
				else:
					authored_encounters[enemy.world_encounter_id] = cell
				register(enemy, cell)
				enemies.append(enemy)
				if enemy.is_boss and boss == null:
					boss = enemy
			"LockedDoor":
				var d: LockedDoor = node
				if d.link_id != "" \
						and SceneManager.flags.get("door_%s_opened" % d.link_id, false):
					node.free()
					continue
				d.room = self
				d.cell = cell
				set_blocked(cell, true)
				register(d, cell)
				doors.append(d)
				if door == null:
					door = d
			"PushableBlock":
				register(node, cell)
				blocks.append(node)
			"PressurePlate":
				var plate: PressurePlate = node
				plate.room = self
				plate.cell = cell
				add_child(plate)
				plate.watch_room()
				plates.append(plate)
			"Chest":
				var chest: Chest = node
				chest.room = self
				chest.cell = cell
				register(chest, cell)
				chest.restore_state()
				chests.append(chest)
			"Lever":
				var lever: Lever = node
				lever.room = self
				lever.cell = cell
				register(lever, cell)
				levers.append(lever)
			"SaveCrystal":
				var crystal: SaveCrystal = node
				crystal.room = self
				crystal.cell = cell
				register(crystal, cell)
				crystals.append(crystal)
			_:
				node.free()


func _spawn_player() -> void:
	if spawn_override != Vector2i(-1, -1):
		spawn_cell = spawn_override
	entry_cell = spawn_cell   # where a pit fall walks you back to (T-047)
	player = Player.new()
	register(player, spawn_cell)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = width * TILE
	player.camera.limit_bottom = height * TILE
	player.move_finished.connect(_on_player_moved)
	for e in enemies:
		e.target_player = player
	_spawn_party()


## Spawns the visible pass-through party from the session roster: the leader
## identity stays on the Player; every other member becomes a render-only
## follower seeded beside the spawn cell (D-029).
func _spawn_party() -> void:
	var roster: Array = []
	for id in SceneManager.state.party_roster:
		roster.append(str(id))
	# S-010/TK-003: leader authority and formation identity live in session
	# state, so a switch or selection survives room changes and respawns.
	var session_leader := str(SceneManager.state.party_leader)
	if session_leader != "" and roster.has(session_leader):
		party_leader_id = session_leader
	else:
		party_leader_id = "hero" if roster.is_empty() else roster[0]
	if party_leader_id != "hero" and player != null:
		player.apply_character(SceneManager.character_stats_for(party_leader_id))
	party_followers = []
	party_trail = null
	if roster.size() <= 1:
		return
	var follower_ids := []
	for id in roster:
		if id != party_leader_id:
			follower_ids.append(id)
	party_trail = PartyTrail.new()
	party_trail.setup(follower_ids, spawn_cell,
			func(c: Vector2i) -> bool: return is_walkable(c))
	party_trail.set_formation(StringName(SceneManager.state.party_formation))
	var seeded: Dictionary = party_trail.follower_cells()
	for fid in follower_ids:
		var follower := PartyFollower.new()
		follower.setup(fid, SceneManager.character_stats_for(fid), self,
				seeded[fid])
		add_child(follower)
		party_followers.append(follower)


func _sync_party(instant := false) -> void:
	if party_trail == null:
		return
	party_trail.leader_moved(player.cell)
	var cells: Dictionary = party_trail.follower_cells()
	for follower in party_followers:
		follower.glide_to(cells[follower.member_id], instant)


## Teleports (room restore, pit-fall respawn, dev warps) reseed the party
## beside the leader instead of leaving followers stranded across the room.
func teleport(node: Node2D, to: Vector2i) -> void:
	super.teleport(node, to)
	# During an encounter the followers hold DEPLOYED combat cells; the
	# exploration trail must not fight the combat controller over them.
	if node == player and active_encounter_id == "":
		_sync_party(true)


## S-010/TK-002: the room's selected formation (line/square/spaced).
func party_formation() -> StringName:
	if party_trail == null:
		return &"line"
	return party_trail.selected_formation()


func set_party_formation(formation_id: StringName) -> bool:
	if party_trail == null:
		return false
	if not party_trail.set_formation(formation_id):
		return false
	SceneManager.state.party_formation = String(formation_id)
	var cells: Dictionary = party_trail.follower_cells()
	for follower in party_followers:
		follower.glide_to(cells[follower.member_id])
	return true


## The smallest production selector (TK-003): one action cycles the accepted
## formations in planner order and announces the result.
func cycle_party_formation() -> StringName:
	if party_trail == null:
		return party_formation()
	var order: Array = PartyFormationLayout.new().formation_ids()
	var index := order.find(party_formation())
	var next: StringName = order[(index + 1) % order.size()] if index >= 0 \
			else order[0]
	if set_party_formation(next):
		_show_party_toast("FORMATION: %s" % String(next).to_upper())
	return party_formation()


## S-010/TK-002 leader switching (D-029): control and camera move to the next
## roster member's cell; the demoted leader becomes a follower at the old
## control cell. Nobody else moves and no occupancy is invented - the switch
## is refused if the promoted member's render cell is occupied. Returns the
## new leader id, or "" when refused.
func switch_party_leader() -> String:
	if player == null or party_trail == null or party_followers.is_empty():
		return ""
	if active_encounter_id != "" or SceneManager.in_encounter \
			or SceneManager.transitioning:
		return ""
	var order: Array = []
	for id in SceneManager.state.party_roster:
		order.append(str(id))
	var index := order.find(party_leader_id)
	if index < 0 or order.size() < 2:
		return ""
	var next_leader: String = order[(index + 1) % order.size()]
	var promoted: PartyFollower = null
	for follower in party_followers:
		if follower.member_id == next_leader:
			promoted = follower
	if promoted == null:
		return ""
	var control_from := player.cell
	var control_to := promoted.cell
	if occupants.has(control_to):
		return ""   # a real occupant holds that cell; switching would stomp it
	var old_leader := party_leader_id
	party_leader_id = next_leader
	promoted.member_id = old_leader
	promoted.apply_character(SceneManager.character_stats_for(old_leader))
	player.apply_character(SceneManager.character_stats_for(next_leader))
	super.teleport(player, control_to)
	promoted.glide_to(control_from, true)
	var follower_order: Array = []
	var follower_cells := {}
	for id in order:
		if id == party_leader_id:
			continue
		follower_order.append(id)
	for follower in party_followers:
		follower_cells[follower.member_id] = follower.cell
	party_trail.assume(control_to, follower_cells, follower_order)
	SceneManager.state.party_leader = next_leader
	var stats := SceneManager.character_stats_for(next_leader)
	_show_party_toast("LEADER: %s" % (stats.display_name.to_upper()
			if stats != null else next_leader.to_upper()))
	return next_leader


## Transient control feedback (TK-003): a short centered toast, no persistent
## HUD chrome. Replaces any previous toast immediately.
func _show_party_toast(text: String) -> void:
	if _party_toast != null and is_instance_valid(_party_toast):
		_party_toast.queue_free()
	_party_toast = CanvasLayer.new()
	_party_toast.layer = 40
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 96
	label.offset_bottom = 130
	_party_toast.add_child(label)
	add_child(_party_toast)
	var toast := _party_toast
	get_tree().create_timer(1.4).timeout.connect(func():
		if is_instance_valid(toast):
			toast.queue_free()
		if _party_toast == toast:
			_party_toast = null)


## TK-004 review F1: a room freed or removed while owning the active
## encounter must never strand the global input gate (load_game frees rooms
## without an in_encounter guard).
func _exit_tree() -> void:
	if active_encounter_id != "":
		room_encounter = null   # freed with the room's children
		_release_party_deployment()
		active_encounter_id = ""
		_active_encounter_enemy = null
		SceneManager.in_encounter = false


## Enters encounter mode for a live, authored enemy in THIS room instance.
## Pure mode/bookkeeping change (D-025): nothing moves, nothing is rebuilt.
## Returns "" on success or a named refusal (fail closed, no side effects).
func begin_room_encounter(enemy: OverworldEnemy) -> String:
	if active_encounter_id != "":
		return "already_in_encounter"
	if SceneManager.transitioning:
		return "encounter_blocked"
	if enemy == null or not is_instance_valid(enemy) \
			or not is_instance_valid(self) or enemy.room != self:
		return "unknown_encounter"
	if enemy.world_encounter_id == "" \
			or not authored_encounters.has(enemy.world_encounter_id):
		return "unknown_encounter"
	# S-010/TK-004: deploy the party BEFORE committing any encounter state -
	# a failed deployment refuses entry with no side effects (fail closed).
	var deployment_error := _deploy_party_for_encounter()
	if deployment_error != "":
		return deployment_error
	# S-012/TK-002: the intent-round controller mirrors the room into the
	# promoted domain and declares round one. A failed setup undoes the
	# deployment and refuses entry (fail closed, no side effects).
	var controller := RoomEncounter.new()
	var setup_error := controller.setup(self, enemy)
	if setup_error != "":
		controller.free()
		_release_party_deployment()
		return setup_error
	room_encounter = controller
	add_child(controller)
	active_encounter_id = enemy.world_encounter_id
	_active_encounter_enemy = enemy
	SceneManager.in_encounter = true
	_show_encounter_banner()
	encounter_started.emit(active_encounter_id)
	return ""


## Snap followers onto the promoted planner's legal deployment cells and make
## them real occupants (D-037: body-blocking tactical units). Returns "" or
## "deployment_failed" with nothing applied.
func _deploy_party_for_encounter() -> String:
	if party_trail == null or party_followers.is_empty() or player == null:
		return ""   # solo leader: nothing to deploy
	# The planner speaks StringName member ids (T-096 contract).
	var member_ids: Array = [StringName(party_leader_id)]
	var member_cells := {StringName(party_leader_id): player.cell}
	for follower in party_followers:
		member_ids.append(StringName(follower.member_id))
		member_cells[StringName(follower.member_id)] = follower.cell
	var walkable_cells: Array[Vector2i] = []
	var enemy_cells: Array[Vector2i] = []
	var prop_cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if not blocked.has(cell) and not pits.has(cell):
				walkable_cells.append(cell)
	for cell in occupants:
		var node: Node2D = occupants[cell]
		if node is OverworldEnemy:
			enemy_cells.append(cell)
		elif node != player:
			prop_cells.append(cell)
	# S-010 review C1: plates are not occupants, but a follower deployed onto
	# one WOULD press it via occupy(). "Followers never hold plates" (D-029)
	# survives into encounters: plate cells are excluded like props.
	for plate in plates:
		prop_cells.append(plate.cell)
	var elevations := {}
	for cell in walkable_cells:
		elevations[cell] = elevation_at(cell)
	var plan: Dictionary = PartyFormationLayout.new().plan_deployment(
			party_formation(), StringName(party_leader_id),
			party_trail.facing(), member_ids, member_cells, walkable_cells,
			[], enemy_cells, prop_cells, elevations, [])
	var deployed: Dictionary = plan.get("deployment_cells", {})
	if deployed.size() != member_ids.size():
		return "deployment_failed"
	for follower in party_followers:
		var cell: Vector2i = deployed[StringName(follower.member_id)]
		follower.glide_to(cell)
		occupy(follower, cell)
	party_deployed = true
	return ""


## Followers return to render-only pass-through after the encounter; the
## trail resumes from wherever the fight left everyone.
func _release_party_deployment() -> void:
	if not party_deployed:
		return
	party_deployed = false
	var follower_order: Array = []
	var follower_cells := {}
	for follower in party_followers:
		if not is_instance_valid(follower):
			continue
		vacate(follower)
		follower_order.append(follower.member_id)
		follower_cells[follower.member_id] = follower.cell
	if party_trail != null and player != null:
		party_trail.assume(player.cell, follower_cells, follower_order)


## Resolves the active encounter in place. Victory runs the same reward and
## defeat bookkeeping as the v1 route; a non-victory (retreat/interrupt)
## simply releases the mode with the encounter still unresolved. Room,
## camera, positions, and puzzle state are untouched either way.
func resolve_room_encounter(victory: bool) -> String:
	if active_encounter_id == "":
		return "no_active_encounter"
	var encounter_id := active_encounter_id
	if victory and _active_encounter_enemy != null \
			and is_instance_valid(_active_encounter_enemy):
		SceneManager.apply_enemy_rewards(_active_encounter_enemy)
		_active_encounter_enemy.defeated()
	if room_encounter != null:
		room_encounter.queue_free()
		room_encounter = null
	_release_party_deployment()
	active_encounter_id = ""
	_active_encounter_enemy = null
	SceneManager.in_encounter = false
	_hide_encounter_banner()
	encounter_resolved.emit(encounter_id, victory)
	SceneManager.encounter_finished.emit(victory)
	return ""


## Seeds the live reaction state: every in-bounds cell exists (so any target
## is previewable), authored material tags copy in, nothing else is invented.
func _seed_material_state() -> void:
	var cells := {}
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			cells[cell] = {"tags": material_tags(cell), "statuses": {}}
	material_state = {"width": width, "height": height, "cells": cells}


## S-011 preview seam: runs the promoted ReactionCore against the live state
## without mutating it. Exploration and encounter callers share this exact
## entry point; request.context stays metadata (D-031).
func preview_reaction(request: Dictionary) -> Dictionary:
	return ReactionCore.calculate(material_state, request)


## S-011 commit seam: applies a previewed result's state_after wholesale so
## the committed world is EXACTLY what the preview showed. Fails closed with
## a named error on anything else; a failed commit changes nothing.
func commit_reaction(result: Dictionary) -> String:
	if not result.get("valid", false):
		return "invalid_reaction_result"
	var after: Variant = result.get("state_after")
	if not after is Dictionary or not after.get("cells") is Dictionary \
			or int(after.get("width", -1)) != width \
			or int(after.get("height", -1)) != height:
		return "invalid_reaction_result"
	material_state = (after as Dictionary).duplicate(true)
	return ""


## Minimal D-036 mode cue: a readable banner, no scene or camera change.
func _show_encounter_banner() -> void:
	if _encounter_banner != null:
		return
	_encounter_banner = CanvasLayer.new()
	_encounter_banner.layer = 50
	var label := Label.new()
	label.text = "ENCOUNTER - TURN-BASED MODE"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 40
	label.offset_bottom = 90
	_encounter_banner.add_child(label)
	add_child(_encounter_banner)


func _hide_encounter_banner() -> void:
	if _encounter_banner == null:
		return
	_encounter_banner.queue_free()
	_encounter_banner = null


func _on_player_moved() -> void:
	if SceneManager.transitioning:
		return
	_sync_party()
	if doorways.has(player.cell):
		_on_doorway(doorways[player.cell])
	player_moved.emit()
