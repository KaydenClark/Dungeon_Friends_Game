extends "res://tests/gd_test.gd"
## Soft-lock proof for the tutorial dungeon's block puzzles (T-024/T-027;
## see /BLUEPRINT.md -> Known Risks, block-puzzle soft-locks: every puzzle
## room's proof must include a can-the-player-wedge-it check, not just a
## can-it-be-solved check).
##
## These build the REAL shipped rooms (TutorialHubRoom / TutorialPitRoom from
## tutorial_dungeon.ldtk) and run an exhaustive BFS over every reachable
## (block position, player region) state:
##  - Hub: from every reachable state, the plate solution is still reachable
##    OR the reset lever is (the designed escape valve).
##  - Pit room: from every reachable state, the block can still be sunk into
##    the pit OR the south exit doorway is reachable (leave-and-re-enter
##    rebuilds the room - the pit room's escape valve).


## Player-walkable predicate for the solver (static geometry only; the block
## is handled separately by the state).
func _walkable(room: LdtkRoom, c: Vector2i, block: Vector2i) -> bool:
	if c == block or not room.in_bounds(c):
		return false
	if room.blocked.has(c) or room.pits.has(c):
		return false
	var occ: Node2D = room.get_occupant(c)
	# The player and the block themselves aren't obstacles to the abstract
	# player; every other occupant (chest, lever, closed door, NPC) is.
	if occ != null and occ != room.player and not occ is PushableBlock:
		return false
	return true


## Flood-fill the player-reachable set from `from` given the block position.
func _reach(room: LdtkRoom, from: Vector2i, block: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if not seen.has(n) and _walkable(room, n, block):
				seen[n] = true
				queue.append(n)
	return seen


## Whether a block could legally be pushed onto `target` (mirror of
## PushableBlock.try_push, minus the pit case which the explorer handles).
func _push_target_free(room: LdtkRoom, target: Vector2i) -> bool:
	if not room.in_bounds(target) or room.no_block_cells.has(target):
		return false
	if room.blocked.has(target) or room.pits.has(target):
		return false
	var occ: Node2D = room.get_occupant(target)
	if occ != null and occ != room.player and not occ is PushableBlock:
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
## A push into a pit is a terminal "sunk" state (the fill is the solution in
## the pit room and can't occur in the hub, which has no pits).
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


func _adjacent_reachable(reach: Dictionary, target: Vector2i) -> bool:
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if reach.has(target + d):
			return true
	return false


func test_hub_puzzle_solvable_and_never_soft_locked() -> void:
	SceneManager.flags = {}
	var hub := TutorialHubRoom.new()
	add_child(hub)
	eq(hub.blocks.size(), 1, "hub has its one block")
	eq(hub.plates.size(), 1, "hub has its one plate")
	eq(hub.levers.size(), 1, "hub has its reset lever")
	var plate_cell: Vector2i = hub.plates[0].cell
	var lever_cell: Vector2i = hub.levers[0].cell
	var block_start: Vector2i = hub.blocks[0].cell
	eq(plate_cell, Vector2i(5, 5), "plate at the 3x3 center")
	eq(block_start, Vector2i(4, 4), "block starts in a 3x3 corner")
	var graph := _explore(hub, block_start, hub.player.cell)
	var states: Dictionary = graph.states
	var can_solve := _can_reach_set(states, graph.edges,
			func(st: Dictionary) -> bool: return not st.sunk and st.block == plate_cell)
	var start_key := _key(block_start, _reach(hub, hub.player.cell, block_start))
	ok(states.size() > 1, "solver explored %d states" % states.size())
	ok(can_solve.has(start_key), "the plate solution is reachable from the start")
	var stuck: Array[String] = []
	for key: String in states:
		var st: Dictionary = states[key]
		if st.sunk or can_solve.has(key):
			continue
		if not _adjacent_reachable(st.reach, lever_cell):
			stuck.append(key)
	eq(stuck.size(), 0,
			"every wedged state can still reach the reset lever (stuck: %s)" % str(stuck))
	hub.queue_free()
	SceneManager.flags = {}


func test_pit_room_solvable_and_exit_always_reachable() -> void:
	SceneManager.flags = {}
	var pit := TutorialPitRoom.new()
	add_child(pit)
	eq(pit.blocks.size(), 1, "pit room has its one block")
	var exit_cell := Vector2i(5, 12)
	ok(pit.doorways.has(exit_cell), "south exit doorway present")
	ok(pit.no_block_cells.has(exit_cell), "block can never plug the exit")
	# The pit band must be 2 wide across the full interior width.
	for x in range(1, 10):
		ok(pit.is_pit(Vector2i(x, 6)) and pit.is_pit(Vector2i(x, 7)),
				"pit spans column %d, 2 cells wide" % x)
	var graph := _explore(pit, pit.blocks[0].cell, pit.player.cell)
	var states: Dictionary = graph.states
	var can_sink := _can_reach_set(states, graph.edges,
			func(st: Dictionary) -> bool: return st.sunk)
	var start_key := _key(pit.blocks[0].cell,
			_reach(pit, pit.player.cell, pit.blocks[0].cell))
	ok(can_sink.has(start_key), "block-into-pit solution reachable from the start")
	var stuck: Array[String] = []
	for key: String in states:
		var st: Dictionary = states[key]
		if st.sunk or can_sink.has(key):
			continue
		if not st.reach.has(exit_cell):
			stuck.append(key)
	eq(stuck.size(), 0,
			"every state can still sink the block or leave to reset (stuck: %s)" % str(stuck))
	pit.queue_free()
	SceneManager.flags = {}
