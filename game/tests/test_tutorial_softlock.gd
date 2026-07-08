extends "res://tests/gd_test.gd"
## Soft-lock proof for the tutorial dungeon's block puzzles (T-024/T-027,
## reworked for the 2026-07-07 layout; see /BLUEPRINT.md -> Known Risks,
## block-puzzle soft-locks: every puzzle room's proof must include a
## can-the-player-wedge-it check, not just a can-it-be-solved check).
##
## These build the REAL shipped rooms (TutorialHubRoom / TutorialPitRoom from
## tutorial_dungeon.ldtk) and run an exhaustive BFS over every reachable
## (movable-block position, player region) state. Fixed bricks (movable=false)
## are static obstacles; the player's 1-cell jump over a single pit cell is
## part of reachability (T-025).
##  - Hub: from every reachable state, both far-side exits (east gap, north
##    door approach) are still reachable OR the reset lever is (the designed
##    escape valve for the one movable brick).
##  - Pit room: every reachable sink lands in the 2-wide chasm (there IS no
##    wrong pit to feed - the ledges can't be reached by a push), and from
##    every un-sunk state the south exit stays reachable (leave-and-re-enter
##    rebuilds the room - the belt-and-braces escape valve).


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
## Includes the 1-cell jump: a single pit cell with walkable ground beyond it
## can be crossed (T-025 - the pit room's ledges are part of reachability).
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
			elif room.pits.has(n) and n != block:
				var land: Vector2i = c + d * 2
				if _walkable(room, land, block) and not seen.has(land):
					seen[land] = true
					queue.append(land)
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


func test_pit_room_solvable_and_exit_always_reachable() -> void:
	SceneManager.flags = {}
	var pit := TutorialPitRoom.new()
	add_child(pit)
	var movable := _movable_blocks(pit)
	eq(pit.blocks.size(), 1, "pit room has its one block")
	eq(movable.size(), 1, "and it is movable")
	var exit_cell := Vector2i(5, 12)
	ok(pit.doorways.has(exit_cell), "south exit doorway present")
	ok(pit.no_block_cells.has(exit_cell), "block can never plug the exit")
	# Geometry contract: two 1-wide jumpable ledges, then the 2-wide chasm.
	for x in range(1, 10):
		ok(pit.is_pit(Vector2i(x, 9)) and not pit.is_pit(Vector2i(x, 8)),
				"first ledge is exactly 1 wide at column %d" % x)
		ok(pit.is_pit(Vector2i(x, 7)) and not pit.is_pit(Vector2i(x, 6)),
				"second ledge is exactly 1 wide at column %d" % x)
		ok(pit.is_pit(Vector2i(x, 3)) and pit.is_pit(Vector2i(x, 4)),
				"chasm spans column %d, 2 cells wide" % x)
	var block_start: Vector2i = movable[0].cell
	eq(block_start, Vector2i(3, 5), "block starts on the chasm's near bank")
	var graph := _explore(pit, block_start, pit.player.cell)
	var states: Dictionary = graph.states
	var can_sink := _can_reach_set(states, graph.edges,
			func(st: Dictionary) -> bool: return st.sunk)
	var start_key := _key(block_start, _reach(pit, pit.player.cell, block_start))
	ok(can_sink.has(start_key), "block-into-chasm solution reachable from the start")
	var bad_sinks: Array[String] = []
	var stuck: Array[String] = []
	for key: String in states:
		var st: Dictionary = states[key]
		if st.sunk:
			# Every reachable sink must land in the chasm band - the ledges
			# are unreachable to a push, so there is no wrong pit to feed.
			if st.block.y > 4:
				bad_sinks.append(key)
			continue
		if not can_sink.has(key):
			stuck.append(key)
			continue
		if not st.reach.has(exit_cell):
			stuck.append(key)
	eq(bad_sinks.size(), 0,
			"no push can sink the block into a ledge (bad: %s)" % str(bad_sinks))
	eq(stuck.size(), 0,
			"every state can still sink the block AND leave to reset (stuck: %s)" % str(stuck))
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
