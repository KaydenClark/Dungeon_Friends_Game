extends "res://tests/gd_test.gd"
## T-096 contract tests for pure selectable layouts and encounter deployment.

const LAYOUT_PATH := "res://scripts/dev/party_formation_layout.gd"
const SNAPSHOT_ADAPTER_PATH := "res://scripts/dev/sol_snapshot_adapter.gd"
const MEMBER_IDS := [&"hero", &"buddy", &"friend_c", &"friend_d"]
const MEMBER_CELLS := {
	&"hero": Vector2i.ZERO,
	&"buddy": Vector2i(-1, 0),
	&"friend_c": Vector2i(-2, 0),
	&"friend_d": Vector2i(-3, 0),
}


func _layout() -> Variant:
	if not ResourceLoader.exists(LAYOUT_PATH):
		return null
	var script: GDScript = load(LAYOUT_PATH)
	if script == null or not script.can_instantiate():
		return null
	return script.new()


func _open_cells(radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			cells.append(Vector2i(x, y))
	return cells


func _flat_elevations(cells: Array[Vector2i]) -> Dictionary:
	var elevations := {}
	for cell in cells:
		elevations[cell] = 0
	return elevations


func test_exactly_three_formations_and_four_facing_rotations() -> void:
	var layout: Variant = _layout()
	not_null(layout, "party formation layout exists")
	if layout == null:
		return
	var formations: Array = layout.formation_ids()
	eq(formations, [&"line", &"square", &"spaced"],
			"prototype exposes exactly line, square, and spaced")
	var facings := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for formation_id in formations:
		var right_offsets: Array = layout.preferred_offsets(formation_id, Vector2i.RIGHT)
		eq(right_offsets.size(), 3, "%s has three follower offsets" % formation_id)
		for facing in facings:
			var offsets: Array = layout.preferred_offsets(formation_id, facing)
			eq(offsets.size(), 3, "%s supports facing %s" % [formation_id, facing])
			var occupied := {Vector2i.ZERO: true}
			for offset in offsets:
				ne(offset, Vector2i.ZERO, "%s never overlaps the leader" % formation_id)
				not_ok(occupied.has(offset), "%s offsets stay distinct" % formation_id)
				occupied[offset] = true
		eq(layout.preferred_offsets(formation_id, Vector2i.DOWN),
			layout.rotate_offsets(right_offsets, Vector2i.DOWN),
			"%s rotates clockwise for down" % formation_id)
		eq(layout.preferred_offsets(formation_id, Vector2i.LEFT),
			layout.rotate_offsets(right_offsets, Vector2i.LEFT),
			"%s rotates twice for left" % formation_id)
		eq(layout.preferred_offsets(formation_id, Vector2i.UP),
			layout.rotate_offsets(right_offsets, Vector2i.UP),
			"%s rotates counter-clockwise for up" % formation_id)
	eq(layout.preferred_offsets(&"unknown", Vector2i.RIGHT), [],
			"invalid formation has no offsets")
	eq(layout.preferred_offsets(&"line", Vector2i(1, 1)), [],
			"invalid facing has no offsets")


func test_open_deployment_is_pure_deterministic_and_differs_by_formation() -> void:
	var layout: Variant = _layout()
	not_null(layout, "party formation layout exists")
	if layout == null:
		return
	var walkable := _open_cells(5)
	var elevations := _flat_elevations(walkable)
	var original_cells: Dictionary = MEMBER_CELLS.duplicate(true)
	var snapshots := {}
	for formation_id in layout.formation_ids():
		var first: Dictionary = layout.plan_deployment(
				formation_id, &"hero", Vector2i.RIGHT, MEMBER_IDS, MEMBER_CELLS,
				walkable, [], [], [], elevations)
		var second: Dictionary = layout.plan_deployment(
				formation_id, &"hero", Vector2i.RIGHT, MEMBER_IDS, MEMBER_CELLS,
				walkable, [], [], [], elevations)
		eq(first, second, "%s deployment is deterministic" % formation_id)
		eq(first.get("formation_id"), formation_id, "snapshot names its formation")
		eq(first.get("leader_id"), &"hero", "snapshot names its leader")
		eq(first.get("facing"), Vector2i.RIGHT, "snapshot preserves facing")
		eq(first.get("member_cells"), MEMBER_CELLS, "snapshot preserves exploration cells")
		var deployed: Dictionary = first.get("deployment_cells", {})
		eq(deployed.size(), 4, "%s returns all four deployment cells" % formation_id)
		eq(deployed.get(&"hero"), Vector2i.ZERO, "leader stays anchored")
		var unique := {}
		for member_id in MEMBER_IDS:
			var cell: Vector2i = deployed.get(member_id, Vector2i(999, 999))
			ok(walkable.has(cell), "%s deploys %s on walkable terrain" % [formation_id, member_id])
			not_ok(unique.has(cell), "%s deployment cells are distinct" % formation_id)
			unique[cell] = true
		snapshots[formation_id] = deployed
	eq(MEMBER_CELLS, original_cells, "deployment never mutates caller member cells")
	ne(snapshots[&"line"], snapshots[&"square"], "line and square differ in open space")
	ne(snapshots[&"square"], snapshots[&"spaced"], "square and spaced differ in open space")
	ne(snapshots[&"line"], snapshots[&"spaced"], "line and spaced differ in open space")


func test_fable_adapter_consumes_the_real_sol_snapshot() -> void:
	var layout: Variant = _layout()
	var adapter: GDScript = load(SNAPSHOT_ADAPTER_PATH)
	not_null(layout, "party formation layout exists")
	not_null(adapter, "Fable snapshot adapter exists")
	if layout == null or adapter == null:
		return
	var walkable := _open_cells(5)
	var snapshot: Dictionary = layout.plan_deployment(
			&"square", &"hero", Vector2i.RIGHT, MEMBER_IDS, MEMBER_CELLS,
			walkable, [], [], [], _flat_elevations(walkable))
	var fable_ids := ["hero", "buddy", "friend_c", "friend_d"]
	var starts: Dictionary = adapter.encounter_start_cells(snapshot, fable_ids)
	eq(starts.size(), 4, "adapter returns every Sol-planned party cell")
	for id: String in fable_ids:
		eq(starts.get(id), snapshot["deployment_cells"].get(StringName(id)),
				"adapter preserves Sol's deployment for %s" % id)


func test_dense_fallback_stays_reachable_and_excludes_obstacles_and_height_jumps() -> void:
	var layout: Variant = _layout()
	not_null(layout, "party formation layout exists")
	if layout == null:
		return
	var walkable: Array[Vector2i] = []
	for y in range(-3, 4):
		for x in range(-3, 4):
			walkable.append(Vector2i(x, y))
	var blocked: Array[Vector2i] = []
	for y in range(-3, 4):
		blocked.append(Vector2i(-1, y))
	blocked.append(Vector2i(0, -1))
	var enemies := [Vector2i(1, 0)]
	var props := [Vector2i(0, -2)]
	var elevations := _flat_elevations(walkable)
	elevations[Vector2i(0, 2)] = 3
	var snapshot: Dictionary = layout.plan_deployment(
			&"spaced", &"hero", Vector2i.RIGHT, MEMBER_IDS, MEMBER_CELLS,
			walkable, blocked, enemies, props, elevations)
	var deployed: Dictionary = snapshot.get("deployment_cells", {})
	eq(deployed.size(), 4, "dense fallback still finds four legal cells")
	var forbidden := blocked + enemies + props + [Vector2i(0, 2)]
	var unique := {}
	for member_id in MEMBER_IDS:
		var cell: Vector2i = deployed.get(member_id, Vector2i(999, 999))
		not_ok(forbidden.has(cell), "%s avoids walls, enemies, props, and high jumps" % member_id)
		ok(cell.x >= 0, "%s stays in the leader's reachable component" % member_id)
		not_ok(unique.has(cell), "%s receives a distinct fallback cell" % member_id)
		unique[cell] = true
	eq(deployed.get(&"hero"), Vector2i.ZERO, "fallback never moves the leader")


func test_invalid_or_insufficient_deployment_fails_closed() -> void:
	var layout: Variant = _layout()
	not_null(layout, "party formation layout exists")
	if layout == null:
		return
	var tiny: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]
	var elevations := _flat_elevations(tiny)
	eq(layout.plan_deployment(&"unknown", &"hero", Vector2i.RIGHT, MEMBER_IDS,
			MEMBER_CELLS, tiny, [], [], [], elevations), {},
			"invalid formation fails closed")
	eq(layout.plan_deployment(&"line", &"hero", Vector2i.RIGHT, MEMBER_IDS,
			MEMBER_CELLS, tiny, [], [], [], elevations), {},
			"fewer than four legal reachable cells fails closed")


func test_elevation_changes_require_an_explicit_transition_edge() -> void:
	var layout: Variant = _layout()
	not_null(layout, "party formation layout exists")
	if layout == null:
		return
	var walkable: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	]
	var elevations := {
		Vector2i(0, 0): 0,
		Vector2i(1, 0): 1,
		Vector2i(2, 0): 1,
		Vector2i(3, 0): 1,
	}
	eq(layout.plan_deployment(&"line", &"hero", Vector2i.LEFT, MEMBER_IDS,
			MEMBER_CELLS, walkable, [], [], [], elevations, []), {},
			"an adjacent one-level cliff is not reachable without a transition")
	var stair_edges := [{"from": Vector2i(0, 0), "to": Vector2i(1, 0)}]
	var snapshot: Dictionary = layout.plan_deployment(&"line", &"hero", Vector2i.LEFT,
			MEMBER_IDS, MEMBER_CELLS, walkable, [], [], [], elevations, stair_edges)
	eq(snapshot.get("deployment_cells", {}).size(), 4,
			"an authored one-level stair edge connects the deployment component")
