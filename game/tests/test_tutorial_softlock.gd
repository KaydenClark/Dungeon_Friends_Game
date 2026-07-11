extends "res://tests/gd_test.gd"
## Soft-lock proof for the tutorial dungeon's block puzzles (T-024/T-027,
## reworked for the 2026-07-07 layout; see /BLUEPRINT.md -> Known Risks,
## block-puzzle soft-locks: every puzzle room's proof must include a
## can-the-player-wedge-it check, not just a can-it-be-solved check).
##
## These build the REAL shipped rooms (TutorialHubRoom / TutorialPitRoom from
## tutorial_dungeon.ldtk) and run an exhaustive BFS over every reachable
## (movable-block position, player region) state. Fixed bricks (movable=false)
## are static obstacles; manual jumping is deliberately absent (T-078).
##  - Hub: from every reachable state, both far-side exits (east gap, north
##    door approach) are still reachable OR the reset lever is (the designed
##    escape valve for the one movable brick).
##  - Pressure-plate room: one open floor, one block, one momentary plate, one
##    north gate. Every reachable block state can still reach the plate or the
##    reset lever, and the south exit stays available.


## Player-walkable predicate for the solver (static geometry + fixed bricks;
## the one movable block is handled separately by the state).
func _walkable(room: LdtkRoom, c: Vector2i, block: Vector2i) -> bool:
	if c == block or not room.in_bounds(c):
		return false
	if room.blocked.has(c) or room.pits.has(c):
		return false
	var occ: Node2D = room.get_occupant(c)
	# The player and the tracked movable block aren't obstacles to the
	# abstract player; everything else (fixed bricks, chest, lever, closed
	# door, NPC) is.
	if occ != null and occ != room.player \
			and not (occ is PushableBlock and occ.movable):
		return false
	return true


## Flood-fill the player-reachable set from `from` given the block position.
## Pit cells are never crossed: the shipped tutorial no longer binds jump.
func _reach(room: LdtkRoom, from: Vector2i, block: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if _walkable(room, n, block):
				if not seen.has(n):
					seen[n] = true
					queue.append(n)
	return seen


## Whether the movable block could legally be pushed onto `target` (mirror of
## PushableBlock.try_push, minus the pit case which the explorer handles).
func _push_target_free(room: LdtkRoom, target: Vector2i) -> bool:
	if not room.in_bounds(target) or room.no_block_cells.has(target):
		return false
	if room.blocked.has(target) or room.pits.has(target):
		return false
	var occ: Node2D = room.get_occupant(target)
	if occ != null and occ != room.player \
			and not (occ is PushableBlock and occ.movable):
		return false
	return true


func _key(block: Vector2i, reach: Dictionary) -> String:
	# Canonical player-region id: the smallest reachable cell.
	var best := Vector2i(1 << 20, 1 << 20)
	for c: Vector2i in reach:
		if c.y < best.y or (c.y == best.y and c.x < best.x):
			best = c
	return "%s|%s" % [str(block), str(best)]


## Exhaustively explore the (block, player-region) push graph. Returns
## {"states": {key: {block, reach, sunk}}, "edges": {key: [next_key, ...]}}.
## A push into a pit is a terminal "sunk" state.
func _explore(room: LdtkRoom, block_start: Vector2i, player_start: Vector2i) -> Dictionary:
	var states := {}
	var edges := {}
	var start_reach := _reach(room, player_start, block_start)
	var start_key := _key(block_start, start_reach)
	states[start_key] = {"block": block_start, "reach": start_reach, "sunk": false}
	var queue := [start_key]
	while not queue.is_empty():
		var key: String = queue.pop_back()
		var st: Dictionary = states[key]
		var b: Vector2i = st.block
		var outgoing: Array[String] = []
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not st.reach.has(b - d):
				continue  # player can't stand behind the block for this push
			var target: Vector2i = b + d
			var next_key: String
			if room.pits.has(target) and not room.no_block_cells.has(target):
				next_key = "sunk@%s" % str(target)
				if not states.has(next_key):
					states[next_key] = {"block": target, "reach": {}, "sunk": true}
			elif _push_target_free(room, target):
				next_key = _key(target, _reach(room, b, target))
				if not states.has(next_key):
					states[next_key] = {"block": target,
							"reach": _reach(room, b, target), "sunk": false}
					queue.append(next_key)
			else:
				continue
			outgoing.append(next_key)
		edges[key] = outgoing
	return {"states": states, "edges": edges}


func _adjacent_reachable(reach: Dictionary, target: Vector2i) -> bool:
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if reach.has(target + d):
			return true
	return false


func _movable_blocks(room: LdtkRoom) -> Array:
	var out := []
	for b: PushableBlock in room.blocks:
		if b.movable:
			out.append(b)
	return out


func test_hub_brick_wall_solvable_and_never_soft_locked() -> void:
	SceneManager.flags = {}
	var hub := TutorialHubRoom.new()
	add_child(hub)
	eq(hub.blocks.size(), 13, "hub wall is 13 bricks")
	var movable := _movable_blocks(hub)
	eq(movable.size(), 1, "exactly one brick budges (the solver assumes one)")
	eq(hub.plates.size(), 0, "no pressure plate in the hub (on hold, 2026-07-07)")
	eq(hub.chests.size(), 0, "no chest in the hub (moved to the chest room)")
	eq(hub.levers.size(), 1, "hub keeps its reset lever")
	var block_start: Vector2i = movable[0].cell
	eq(block_start, Vector2i(6, 8), "the loose brick sits in the wall row")
	var lever_cell: Vector2i = hub.levers[0].cell
	var east_exit := Vector2i(14, 6)
	var north_approach := Vector2i(7, 1)
	var entry_inside := Vector2i(7, 11)
	ok(hub.doorways.has(east_exit), "east gap doorway present")
	var graph := _explore(hub, block_start, hub.player.cell)
	var states: Dictionary = graph.states
	# A "good" state sees both far-side exits AND the entry strip in one
	# region - the full dungeon loop (out east/north, back south to leave)
	# stays open.
	var can_pass := _can_reach_set(states, graph.edges,
			func(st: Dictionary) -> bool:
				return not st.sunk and st.reach.has(east_exit) \
						and st.reach.has(north_approach) \
						and st.reach.has(entry_inside))
	var start_key := _key(block_start, _reach(hub, hub.player.cell, block_start))
	ok(states.size() > 1, "solver explored %d states" % states.size())
	ok(can_pass.has(start_key), "the wall can be passed from the start")
	var stuck: Array[String] = []
	for key: String in states:
		var st: Dictionary = states[key]
		if st.sunk or can_pass.has(key):
			continue
		if not _adjacent_reachable(st.reach, lever_cell):
			stuck.append(key)
	eq(stuck.size(), 0,
			"every wedged state can still reach the reset lever (stuck: %s)" % str(stuck))
	hub.queue_free()
	SceneManager.flags = {}


func test_mechanism_room_solvable_and_exit_always_reachable() -> void:
	SceneManager.flags = {}
	var pit := TutorialPitRoom.new()
	add_child(pit)
	var movable := _movable_blocks(pit)
	eq(pit.blocks.size(), 1, "mechanism room has one teaching block")
	eq(movable.size(), 1, "and it is movable")
	eq(pit.plates.size(), 1, "one momentary pressure plate is shipped")
	eq(pit.levers.size(), 1, "only the recovery/reset lever remains")
	eq(pit.doors.size(), 1, "one plate-driven north gate is present")
	eq(pit.pits.size(), 0, "the teaching room has no pits or ambiguous floor")
	var world: Node = pit.get_child(0)
	var level: LDTKLevel = pit._pick_level(world)
	var ground: TileMapLayer = pit._find_tile_layer(level, "Ground")
	var missing_floor: Array[Vector2i] = []
	for y in range(1, 12):
		for x in range(1, 10):
			var c := Vector2i(x, y)
			if ground == null or ground.get_cell_source_id(c) == -1:
				missing_floor.append(c)
	eq(missing_floor.size(), 0,
			"every interior cell paints the same continuous floor (missing: %s)"
			% str(missing_floor))
	var exit_cell := Vector2i(5, 12)
	ok(pit.doorways.has(exit_cell), "south exit doorway present")
	ok(pit.no_block_cells.has(exit_cell), "block can never plug the exit")
	var block_start: Vector2i = movable[0].cell
	eq(block_start, Vector2i(5, 9), "block starts on the plate's teaching row")
	var plate_cell: Vector2i = pit.plates[0].cell
	eq(plate_cell, Vector2i(2, 9), "plate is visible on the open lower floor")
	var reset: Lever = pit.levers[0]
	eq(reset.target_id, "", "the remaining lever is only the reset escape valve")
	var plate_door: LockedDoor = pit.doors[0]
	eq(plate_door.link_id, "pit_plate", "plate targets the north gate")
	eq(plate_door.cell, Vector2i(5, 1), "gate visibly guards the north exit")
	# Prove the real shipped actors teach the momentary rule: player weight
	# opens the gate, stepping off closes it again.
	pit.teleport(pit.player, Vector2i(2, 10))
	ok(pit.player.try_step(Vector2i.UP), "player can step onto the floor plate")
	ok(pit.plates[0].pressed and plate_door.held_open,
			"standing on the plate opens the north gate")
	pit.player.moving = false
	ok(pit.player.try_step(Vector2i.DOWN), "player can step off the plate")
	not_ok(pit.plates[0].pressed or plate_door.held_open,
			"stepping off releases the plate and closes the gate")
	pit.player.moving = false
	pit.teleport(pit.player, Vector2i(5, 11))
	var graph := _explore(pit, block_start, pit.player.cell)
	var states: Dictionary = graph.states
	var can_plate := _can_reach_set(states, graph.edges,
			func(st: Dictionary) -> bool: return st.block == plate_cell)
	var start_key := _key(block_start, _reach(pit, pit.player.cell, block_start))
	ok(can_plate.has(start_key), "block-to-plate solution reachable from the start")
	var stuck: Array[String] = []
	for key: String in states:
		var st: Dictionary = states[key]
		if can_plate.has(key):
			continue
		if not _adjacent_reachable(st.reach, reset.cell):
			stuck.append(key)
	eq(stuck.size(), 0,
			"every bad block state can reach the reset lever (stuck: %s)" % str(stuck))
	pit.queue_free()
	SceneManager.flags = {}


## The set of state keys from which any goal state is reachable, via reverse
## closure over the push graph.
func _can_reach_set(states: Dictionary, edges: Dictionary, is_goal: Callable) -> Dictionary:
	var incoming := {}
	for key: String in edges:
		for next_key: String in edges[key]:
			if not incoming.has(next_key):
				incoming[next_key] = []
			incoming[next_key].append(key)
	var can := {}
	var queue := []
	for key: String in states:
		if is_goal.call(states[key]):
			can[key] = true
			queue.append(key)
	while not queue.is_empty():
		var key: String = queue.pop_back()
		for prev: String in incoming.get(key, []):
			if not can.has(prev):
				can[prev] = true
				queue.append(prev)
	return can
