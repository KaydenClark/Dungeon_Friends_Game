extends "res://tests/gd_test.gd"
## T-087 contract tests for the pure visible-party breadcrumb model.

const MODEL_PATH := "res://scripts/dev/visible_party_exploration_model.gd"


func _model() -> Variant:
	if not ResourceLoader.exists(MODEL_PATH):
		return null
	var script: GDScript = load(MODEL_PATH)
	if script == null or not script.can_instantiate():
		return null
	return script.new()


func _step(model: Variant, direction: Vector2i, label: String) -> void:
	ok(model.try_step_leader(direction), label)


func _all_cells(model: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for member_id in model.member_ids():
		cells.append(model.cell_for(member_id))
	return cells


func _step_with_legal_member_transitions(
		model: Variant, direction: Vector2i, label: String) -> void:
	var before: Dictionary = model.member_cells()
	ok(model.try_step_leader(direction), "%s succeeds" % label)
	var claimed := {}
	for member_id in model.member_ids():
		var from_cell: Vector2i = before[member_id]
		var to_cell: Vector2i = model.cell_for(member_id)
		ok(from_cell == to_cell or model.can_step(from_cell, to_cell),
				"%s keeps %s on a cardinal walkable transition" % [label, member_id])
		not_ok(claimed.has(to_cell), "%s keeps %s on a distinct cell" % [label, member_id])
		claimed[to_cell] = true


func test_reset_has_four_distinct_visible_members_and_one_occupant() -> void:
	var model: Variant = _model()
	not_null(model, "visible-party model exists")
	if model == null:
		return
	var ids: Array = model.member_ids()
	eq(ids.size(), 4, "prototype has one leader plus three followers")
	eq(model.follower_ids().size(), 3, "exactly three members follow")
	var occupied := {}
	for member_id in ids:
		var cell: Vector2i = model.cell_for(member_id)
		ok(model.is_walkable(cell), "%s starts on a walkable cell" % member_id)
		not_ok(occupied.has(cell), "%s starts on a distinct visible cell" % member_id)
		occupied[cell] = true
	eq(model.gameplay_occupant_at(model.cell_for(model.leader_id())), model.leader_id(),
			"only the selected leader owns gameplay occupancy")


func test_party_threads_the_door_and_stairs_then_recovers_upstairs() -> void:
	var model: Variant = _model()
	not_null(model, "visible-party model exists")
	if model == null:
		return
	for step in range(5):
		_step(model, Vector2i.RIGHT, "lower route step %d succeeds" % (step + 1))
	_step(model, Vector2i.UP, "leader enters the stair cell")
	_step(model, Vector2i.UP, "leader reaches the upper landing")
	eq(model.cell_for(model.leader_id()), Vector2i(6, 3), "leader is above the choke")
	eq(model.follower_cells(), [Vector2i(6, 4), Vector2i(6, 5), Vector2i(5, 5)],
			"followers occupy the exact stair/door/corridor breadcrumb chain")
	eq(model.formation_state(), &"single_file", "choke traversal reads as single file")
	for step in range(4):
		_step(model, Vector2i.RIGHT, "upper route step %d succeeds" % (step + 1))
	eq(model.cell_for(model.leader_id()), model.GOAL_CELL, "leader reaches the upper goal")
	eq(model.formation_state(), &"recovered", "party reforms after clearing the choke")
	eq(model.follower_cells(), [Vector2i(8, 2), Vector2i(7, 2), Vector2i(6, 2)],
			"recovered followers fan into a readable cardinal row")
	var final_cells := _all_cells(model)
	var unique := {}
	for cell in final_cells:
		eq(model.layout.elevation_at(cell), 1, "recovered member stands on elevation 1")
		not_ok(unique.has(cell), "recovered formation keeps cells distinct")
		unique[cell] = true


func test_every_route_and_reformation_transition_is_grid_legal() -> void:
	var model: Variant = _model()
	not_null(model, "visible-party model exists")
	if model == null:
		return
	var route := [
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
	]
	for index in range(route.size()):
		_step_with_legal_member_transitions(
				model, route[index], "route step %d" % (index + 1))
	eq(model.formation_state(), &"recovered",
			"legal final transitions still produce the recovered formation")


func test_leader_switch_preserves_formation_and_transition_legality() -> void:
	var model: Variant = _model()
	not_null(model, "visible-party model exists")
	if model == null:
		return
	model.cycle_leader()
	model.cycle_leader()
	_step_with_legal_member_transitions(
			model, Vector2i.UP, "spawn switch to Friend C")

	model.reset()
	for _step_index in range(5):
		ok(model.try_step_leader(Vector2i.RIGHT), "lower route reaches the door")
	ok(model.try_step_leader(Vector2i.UP), "leader enters the stair cell")
	ok(model.try_step_leader(Vector2i.UP), "leader reaches the upper landing")
	eq(model.formation_state(), &"single_file", "party starts single-file in the choke")
	model.cycle_leader()
	eq(model.formation_state(), &"single_file",
			"switching authority does not relabel unchanged choke positions")
	_step_with_legal_member_transitions(
			model, Vector2i.DOWN, "choke switch to Buddy")

	model.reset()
	var full_route := [
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
	]
	for direction in full_route:
		ok(model.try_step_leader(direction), "party reaches recovered state")
	eq(model.formation_state(), &"recovered", "party is recovered before switching")
	model.cycle_leader()
	eq(model.formation_state(), &"recovered",
			"switching authority preserves the unchanged recovered-state label")


func test_follower_on_plate_never_holds_or_occupies_it() -> void:
	var model: Variant = _model()
	not_null(model, "visible-party model exists")
	if model == null:
		return
	_step(model, Vector2i.RIGHT, "leader steps onto the plate")
	ok(model.plate_active(), "leader weight activates the plate")
	_step(model, Vector2i.RIGHT, "leader steps off while a follower trails onto it")
	ok(model.follower_on_plate(), "a visible follower is now standing on the plate")
	not_ok(model.plate_active(), "follower presence does not hold the plate")
	eq(model.gameplay_occupant_at(model.PLATE_CELL), StringName(),
			"follower contributes no gameplay occupancy at the plate")
	eq(model.follower_plate_holds(), 0, "follower plate-side-effect counter stays zero")


func test_leader_can_backtrack_through_a_follower_visual_cell() -> void:
	var model: Variant = _model()
	not_null(model, "visible-party model exists")
	if model == null:
		return
	var start: Vector2i = model.cell_for(model.leader_id())
	_step(model, Vector2i.RIGHT, "leader moves ahead of the formation")
	ok(model.follower_cells().has(start), "a follower visually trails on the old leader cell")
	_step(model, Vector2i.LEFT, "leader can step back through that follower cell")
	eq(model.cell_for(model.leader_id()), start, "leader returns without being trapped")


func test_only_leader_interacts_and_cycling_transfers_authority() -> void:
	var model: Variant = _model()
	not_null(model, "visible-party model exists")
	if model == null:
		return
	var old_leader: StringName = model.leader_id()
	ok(model.can_interact(old_leader), "selected leader may interact")
	for follower_id in model.follower_ids():
		not_ok(model.can_interact(follower_id), "%s cannot push or interact" % follower_id)
	var new_leader: StringName = model.cycle_leader()
	ne(new_leader, old_leader, "leader cycle selects a different visible member")
	ok(model.can_interact(new_leader), "new leader receives interaction authority")
	not_ok(model.can_interact(old_leader), "old leader becomes puzzle-inert follower")
	eq(model.gameplay_occupant_at(model.cell_for(new_leader)), new_leader,
			"gameplay occupancy transfers to the new leader cell")
	eq(model.member_ids().size(), 4, "leader switching never drops a visible member")
	eq(model.follower_block_pushes(), 0, "follower block-push counter stays zero")


func test_invalid_moves_fail_closed_without_mutating_party_state() -> void:
	var model: Variant = _model()
	not_null(model, "visible-party model exists")
	if model == null:
		return
	var before_cells: Dictionary = model.member_cells()
	var before_state: StringName = model.formation_state()
	not_ok(model.try_step_leader(Vector2i(2, 0)), "multi-cell direction is refused")
	not_ok(model.try_step_leader(Vector2i.UP), "existing tall wall refuses the leader")
	eq(model.member_cells(), before_cells, "refused moves leave every member cell unchanged")
	eq(model.formation_state(), before_state, "refused moves leave formation state unchanged")
