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
## S-004/TK-002 (D-044): every adopted NPC, and every vine gate, so the
## material-watcher pass and the route logic can reach them.
var npcs: Array[NPC] = []
var vine_gates: Array[VineGate] = []
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
	_show_onboarding_hint()


## S-014/TK-002: the shortest no-coaching onboarding. Exactly one one-time
## contextual hint per room entry, gated by persistent flags, using the
## existing toast surface - the player is never told to press a dev key, and
## a seen hint never repeats (flags ride the save schema). Encounter-entry
## teaching lives on the encounter surface itself (D-036 banner + the intent
## panel's always-visible controls footer).
func _show_onboarding_hint() -> void:
	if party_followers.size() > 0 \
			and not SceneManager.flags.get("hint_party_controls", false):
		SceneManager.flags["hint_party_controls"] = true
		_show_party_toast("G: CHANGE FORMATION    F: SWITCH LEADER")
		return
	var leader_stats := SceneManager.character_stats_for(party_leader_id)
	if _first_reaction_ability(leader_stats) != null \
			and not SceneManager.flags.get("hint_cast", false):
		SceneManager.flags["hint_cast"] = true
		_show_party_toast("5: CAST %s AT THE FACED TILE"
				% _first_reaction_ability(leader_stats).display_name.to_upper())


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
	_build_material_overlay()
	_adopt_entities(level)
	# S-004/TK-002: gates and watched NPCs answer the RESTORED material
	# truth too, so a persisted vine keeps its gate open across rebuilds.
	_refresh_material_watchers()
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
				# S-004/TK-002 (D-044): a recruited friend's NPC never
				# re-spawns - the roster is the persistent truth.
				if p_npc.recruit_id != "" \
						and SceneManager.state.party_roster.has(p_npc.recruit_id):
					node.free()
					continue
				# Fail-closed: an unknown recruit id is a named authoring
				# error and the NPC downgrades to a plain talker.
				if p_npc.recruit_id != "" \
						and SceneManager.character_stats_for(p_npc.recruit_id) == null:
					var bad := "unknown_recruit_id:%s" % p_npc.recruit_id
					push_error("LdtkRoom authoring (%s): %s" % [level_path, bad])
					authoring_errors.append(bad)
					p_npc.recruit_id = ""
				p_npc.room = self
				p_npc.cell = cell
				register(p_npc, cell)
				npcs.append(p_npc)
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
				# S-003 (D-028, supersedes D-009 routine respawn): a resolved
				# encounter does not respawn on rebuild or load. Its authored
				# identity is kept so snapshots keep reporting it resolved.
				if SceneManager.state.resolved_encounters.get(world_key(),
						{}).get(enemy.world_encounter_id, false):
					authored_encounters[enemy.world_encounter_id] = cell
					node.free()
					continue
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
			"VineGate":
				# S-004/TK-002 (D-044): blocks like a wall while closed; the
				# material-watcher pass opens it when its trellis cell grows
				# a vine. An invalid trellis fails closed: named authoring
				# error, gate simply never opens.
				var gate: VineGate = node
				var gate_error := VineGate.authoring_error(gate.trellis,
						width, height)
				if gate_error != "":
					push_error("LdtkRoom authoring (%s): %s"
							% [level_path, gate_error])
					authoring_errors.append(gate_error)
					gate.trellis = Vector2i(-1, -1)
				gate.room = self
				gate.cell = cell
				set_blocked(cell, true)
				register(gate, cell)
				vine_gates.append(gate)
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
	# Reentrant (S-004/TK-002: a mid-room recruit regrows the party): free
	# the previous follower actors and reseed at the leader's live cell.
	for old in party_followers:
		if old != null and is_instance_valid(old):
			old.queue_free()
	party_followers = []
	party_trail = null
	if roster.size() <= 1:
		return
	var seed_cell := spawn_cell if player == null else player.cell
	var follower_ids := []
	for id in roster:
		if id != party_leader_id:
			follower_ids.append(id)
	party_trail = PartyTrail.new()
	party_trail.setup(follower_ids, seed_cell,
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
	# A bound method with an instance id, not a lambda: a replacement toast
	# inside the 1.4s frees the captured node and a freed lambda capture is
	# an engine ERROR line on the first-session route (S-014/TK-005).
	get_tree().create_timer(1.4).timeout.connect(
			_dismiss_party_toast.bind(_party_toast.get_instance_id()))


func _dismiss_party_toast(toast_id: int) -> void:
	var toast := instance_from_id(toast_id)
	if toast is CanvasLayer:
		(toast as CanvasLayer).queue_free()
	if _party_toast != null and _party_toast.get_instance_id() == toast_id:
		_party_toast = null


## S-014/TK-003: losing window focus must never read as a frozen game -
## surface it through the toast channel (player-facing, never "check logs").
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() \
			and player != null:
		_show_party_toast("WINDOW FOCUS LOST - INPUT PAUSED")


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


## S-003: the room's stable world identity for persistence - authored data,
## never runtime state, so it survives rebuilds and processes.
func world_key() -> String:
	return "%s#%s" % [level_path, level_name]


## S-013/TK-004: the exploration cast control (key 5 / R1). Casts the
## LEADER's first reaction ability at the faced cell through the shared
## seam, spending MP. Fail-closed with named, toasted refusals; the whole
## kit stays data-driven (whoever leads casts their own verb).
func cast_leader_reaction() -> Dictionary:
	if player == null:
		return {"valid": false, "error": "no_leader"}
	var stats := SceneManager.character_stats_for(party_leader_id)
	var ability := _first_reaction_ability(stats)
	if ability == null:
		_show_party_toast("%s HAS NO FIELD VERB" % party_leader_id.to_upper())
		return {"valid": false, "error": "not_a_reaction_ability"}
	var max_mp: int = stats.max_mp if stats != null else 0
	var mp: int = int(SceneManager.state.party_mp.get(party_leader_id, max_mp))
	if mp < ability.mp_cost:
		_show_party_toast("NOT ENOUGH MP")
		return {"valid": false, "error": "not_enough_mp"}
	var target: Vector2i = player.cell + player.facing
	var result := ReactionCaster.cast(self, ability, target, player.facing,
			"exploration")
	if result.get("valid", false):
		SceneManager.state.party_mp[party_leader_id] = mp - ability.mp_cost
		_show_party_toast("%s!" % ability.display_name.to_upper())
	return result


func _first_reaction_ability(stats: CharacterStats) -> AbilityData:
	if stats == null:
		return null
	for ability in stats.starting_abilities:
		if ability != null and ability.reaction_verb != "":
			return ability
	return null


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
		# S-012 review C2: the in-room fight currently fields exactly the
		# touched enemy, so victory pays exactly that enemy's stats. When
		# encounter groups spawn as in-room units, the group pays instead.
		# S-013 (D-028): the payout claims its stable finite source first -
		# a source that somehow resolves twice can never pay twice.
		if SceneManager.claim_reward_source("%s#%s" % [world_key(),
				encounter_id]):
			SceneManager.apply_victory_rewards(_active_encounter_enemy.stats)
		_active_encounter_enemy.defeated()
		# S-003 (D-028): a resolved encounter stays resolved forever - across
		# room rebuilds and save/load - under its stable authored identity.
		var resolved: Dictionary = SceneManager.state.resolved_encounters.get(
				world_key(), {})
		resolved[encounter_id] = true
		SceneManager.state.resolved_encounters[world_key()] = resolved
	if room_encounter != null:
		# S-014/TK-003 (D-043): KO'd allies stand back up at 1 HP when the
		# encounter releases (full wipes skip this - defeat owns recovery).
		room_encounter.revive_downed_members()
		# TK-004: combat damage is real - persist unit HP into the session
		# before the controller goes away (defeat rules own revival).
		room_encounter.write_back_party_hp()
		room_encounter.queue_free()
		room_encounter = null
	_release_party_deployment()
	active_encounter_id = ""
	_active_encounter_enemy = null
	SceneManager.in_encounter = false
	# S-012 review C1: plates froze during the encounter; whoever ended the
	# fight standing on one presses it now.
	for plate in plates:
		plate.refresh_after_encounter()
	_hide_encounter_banner()
	encounter_resolved.emit(encounter_id, victory)
	SceneManager.encounter_finished.emit(victory)
	return ""


## S-014/TK-004: production material readability (closes the matrix GAP -
## the debug-only overlay graduates). Simple colored silhouettes per live
## tag, redrawn on every commit; art polish stays owned by S-004.
const MATERIAL_COLORS := {
	"vine": Color(0.28, 0.62, 0.30, 0.85),
	"flammable": Color(0.75, 0.45, 0.18, 0.85),
	"channel": Color(0.25, 0.47, 0.66, 0.85),
	"smoke": Color(0.45, 0.45, 0.45, 0.8),
	"fire": Color(0.95, 0.45, 0.10, 0.9),
	"wet": Color(0.35, 0.65, 0.95, 0.8),
	"flooded": Color(0.15, 0.35, 0.85, 0.85),
	"ice": Color(0.6, 0.9, 1.0, 0.9),
}
var _material_overlay: Node2D


func _build_material_overlay() -> void:
	_material_overlay = Node2D.new()
	_material_overlay.z_index = 20
	add_child(_material_overlay)
	_material_overlay.draw.connect(_draw_material_overlay)
	_material_overlay.queue_redraw()


func _draw_material_overlay() -> void:
	if not material_state.get("cells") is Dictionary:
		return
	for cell in material_state["cells"]:
		var tags: Array = material_state["cells"][cell]["tags"]
		var offset := 0
		for tag in tags:
			_material_overlay.draw_rect(Rect2(cell_to_pos(cell)
					+ Vector2(-20 + offset * 14, 14), Vector2(12, 12)),
					MATERIAL_COLORS.get(tag, Color(1, 0, 1, 0.8)))
			offset += 1


## Seeds the live reaction state: every in-bounds cell exists (so any target
## is previewable), authored material tags copy in, nothing else is invented.
func _seed_material_state() -> void:
	var cells := {}
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			cells[cell] = {"tags": material_tags(cell), "statuses": {}}
	material_state = {"width": width, "height": height, "cells": cells}
	# S-003: a persisted material snapshot is this room's truth as of its
	# last committed reaction; it replaces the authored seed wholesale.
	# Loading is fail-closed - any malformed entry is ignored entirely and
	# the authored state stands.
	var persisted: Variant = SceneManager.state.world_materials.get(world_key())
	if not persisted is Dictionary:
		return
	var parsed := _parse_persisted_materials(persisted)
	if parsed.is_empty() and not (persisted as Dictionary).is_empty():
		push_warning("LdtkRoom (%s): invalid persisted material state ignored"
				% world_key())
		return
	for cell in material_state["cells"]:
		material_state["cells"][cell] = {"tags": [], "statuses": {}}
	for cell in parsed:
		material_state["cells"][cell] = parsed[cell]


## Fail-closed parse of a persisted material snapshot ({"x,y": {tags,
## statuses}}). Returns {} when ANY entry is malformed or out of bounds.
func _parse_persisted_materials(persisted: Dictionary) -> Dictionary:
	var out := {}
	for key in persisted:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() \
				or not parts[1].is_valid_int():
			return {}
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if not in_bounds(cell):
			return {}
		var entry: Variant = persisted[key]
		if not entry is Dictionary or not entry.get("tags") is Array \
				or not entry.get("statuses") is Dictionary:
			return {}
		var tags: Array = []
		for tag in entry["tags"]:
			if not tag is String:
				return {}
			tags.append(tag)
		out[cell] = {"tags": tags,
				"statuses": (entry["statuses"] as Dictionary).duplicate(true)}
	return out


## S-003: write the room's current material truth into the session (and so
## into saves) as a JSON-safe snapshot keyed by this room's world identity.
func _persist_material_state() -> void:
	var out := {}
	for cell in material_state["cells"]:
		var data: Dictionary = material_state["cells"][cell]
		if data["tags"].is_empty() and data["statuses"].is_empty():
			continue
		out["%d,%d" % [cell.x, cell.y]] = {"tags": data["tags"].duplicate(),
				"statuses": data["statuses"].duplicate(true)}
	SceneManager.state.world_materials[world_key()] = out


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
	_persist_material_state()
	if _material_overlay != null and is_instance_valid(_material_overlay):
		_material_overlay.queue_redraw()
	_refresh_material_watchers()
	return ""


## S-004/TK-002 (D-044): everything that answers the material truth outside
## combat, evaluated after every commit AND once per build (so persisted
## state re-applies). Idempotent: an open gate stays open, resolved lines
## stay resolved.
func _refresh_material_watchers() -> void:
	for gate in vine_gates:
		if gate.open or gate.trellis == Vector2i(-1, -1):
			continue
		if _material_tags_at(gate.trellis).has("vine"):
			gate.set_open(true)
			set_blocked(gate.cell, false)
			unregister(gate)
	for watcher in npcs:
		if watcher.watch_cell == Vector2i(-1, -1) \
				or watcher.resolved_lines.is_empty() \
				or watcher.lines == watcher.resolved_lines:
			continue
		if _material_tags_at(watcher.watch_cell).has("vine"):
			watcher.lines = watcher.resolved_lines
			if watcher.resolved_flag != "":
				SceneManager.flags[watcher.resolved_flag] = true


func _material_tags_at(cell: Vector2i) -> Array:
	var cells: Dictionary = material_state.get("cells", {})
	if not cells.has(cell):
		return []
	return (cells[cell] as Dictionary).get("tags", [])


## S-004/TK-002 (D-044): a recruited friend's NPC leaves the board and the
## party toast announces the join.
func npc_departed(departed: NPC) -> void:
	unregister(departed)
	npcs.erase(departed)
	if npc == departed:
		npc = null
	var stats := SceneManager.character_stats_for(departed.recruit_id)
	if stats != null:
		_show_party_toast("%s JOINED THE EXPEDITION!"
				% stats.display_name.to_upper())
	_spawn_party()
	departed.queue_free()


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
	_play_encounter_sting()


## S-014/TK-004: the minimum coherent D-036 audio cue - a short synthesized
## two-note sting (generated at runtime; no asset, no provenance risk). The
## authored audio pass stays owned by S-004/S-015.
func _play_encounter_sting() -> void:
	var sample_rate := 22050
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	var data := PackedByteArray()
	for note in [[440.0, 0.12], [660.0, 0.18]]:
		var frames := int(sample_rate * note[1])
		for i in frames:
			var t := float(i) / sample_rate
			var envelope := 1.0 - float(i) / frames
			var value := sin(TAU * note[0] * t) * envelope * 0.5
			data.append(int(clampf(value, -1.0, 1.0) * 127.0) + 128)
	stream.data = data
	var player_node := AudioStreamPlayer.new()
	player_node.name = "EncounterSting"
	player_node.stream = stream
	player_node.volume_db = -8.0
	add_child(player_node)
	player_node.play()
	player_node.finished.connect(player_node.queue_free)


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
