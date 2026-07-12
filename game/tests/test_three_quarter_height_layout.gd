extends "res://tests/gd_test.gd"
## T-086 prototype contract: limited integer elevation remains metadata on an
## orthogonal square grid. The isolated showcase consumes this exact layout.

const LAYOUT_PATH := "res://scripts/dev/three_quarter_height_layout.gd"


func _layout() -> Variant:
	if not ResourceLoader.exists(LAYOUT_PATH):
		return null
	var script: GDScript = load(LAYOUT_PATH)
	if script == null or not script.can_instantiate():
		return null
	return script.new()


func test_spike_uses_exactly_two_integer_elevations() -> void:
	var layout: Variant = _layout()
	not_null(layout, "prototype layout exists")
	if layout == null:
		return
	eq(layout.elevation_levels(), [0, 1], "layout exposes only lower and upper levels")
	eq(layout.elevation_at(Vector2i(2, 6)), 0, "foreground sample is on lower ground")
	eq(layout.elevation_at(Vector2i(9, 2)), 1, "plateau sample is one level high")


func test_stair_metadata_connects_lower_to_upper() -> void:
	var layout: Variant = _layout()
	not_null(layout, "prototype layout exists")
	if layout == null:
		return
	var transition: Dictionary = layout.transition_at(layout.STAIR_CELL)
	var lower_cell: Vector2i = transition.get("lower_cell", Vector2i(-1, -1))
	var upper_cell: Vector2i = transition.get("upper_cell", Vector2i(-1, -1))
	eq(transition.get("kind", ""), "stairs", "transition is authored as stairs")
	eq(transition.get("from_elevation", -1), 0, "stairs start on lower ground")
	eq(transition.get("to_elevation", -1), 1, "stairs reach the upper platform")
	ok(layout.is_in_bounds(lower_cell), "authored lower stair endpoint is in bounds")
	ok(layout.is_in_bounds(upper_cell), "authored upper stair endpoint is in bounds")
	eq(layout.elevation_at(lower_cell), 0, "authored lower stair endpoint is on elevation 0")
	eq(layout.elevation_at(upper_cell), 1, "authored upper stair endpoint is on elevation 1")
	ok(layout.is_walkable(lower_cell), "authored lower stair endpoint is walkable")
	ok(layout.is_walkable(upper_cell), "authored upper stair endpoint is walkable")
	ok(layout.is_walkable(layout.STAIR_CELL), "stairs remain an explicitly walkable cell")


func test_projection_stays_orthogonal_and_offsets_height_only_on_y() -> void:
	var layout: Variant = _layout()
	not_null(layout, "prototype layout exists")
	if layout == null:
		return
	var origin: Vector2 = layout.project_cell(Vector2i(2, 2), 0)
	var east: Vector2 = layout.project_cell(Vector2i(3, 2), 0)
	var south: Vector2 = layout.project_cell(Vector2i(2, 3), 0)
	var raised: Vector2 = layout.project_cell(Vector2i(2, 2), 1)
	var authored_upper: Vector2 = layout.project_cell(Vector2i(9, 2))
	var authored_upper_at_zero: Vector2 = layout.project_cell(Vector2i(9, 2), 0)
	eq(east - origin, Vector2(layout.CELL_SIZE.x, 0), "east changes screen x only")
	eq(south - origin, Vector2(0, layout.CELL_SIZE.y), "south changes screen y only")
	eq(raised - origin, Vector2(0, -layout.ELEVATION_RISE),
			"elevation lifts the same orthogonal cell without skewing x")
	eq(authored_upper - authored_upper_at_zero, Vector2(0, -layout.ELEVATION_RISE),
			"default scene projection consumes the upper-cell elevation metadata")


func test_depth_contract_places_wall_between_background_and_foreground() -> void:
	var layout: Variant = _layout()
	not_null(layout, "prototype layout exists")
	if layout == null:
		return
	var behind: int = layout.depth_key(layout.BACKGROUND_ACTOR_CELL, layout.DEPTH_ACTOR)
	var wall: int = layout.depth_key(layout.OCCLUSION_WALL_CELL, layout.DEPTH_WALL)
	var in_front: int = layout.depth_key(layout.FOREGROUND_ACTOR_CELL, layout.DEPTH_ACTOR)
	ok(behind < wall, "background actor draws before the tall wall")
	ok(wall < in_front, "foreground actor draws after the tall wall")


func test_actor_and_bounds_metadata_fail_closed() -> void:
	var layout: Variant = _layout()
	not_null(layout, "prototype layout exists")
	if layout == null:
		return
	var actors: Array = layout.actor_specs()
	eq(actors.size(), 4, "spike exposes exactly four placeholder party actors")
	var occupied := {}
	for actor in actors:
		var cell: Vector2i = actor.get("cell", Vector2i(-1, -1))
		ok(layout.is_in_bounds(cell), "%s has an in-bounds cell" % actor.get("name", "actor"))
		ok(layout.is_walkable(cell), "%s stands on a walkable cell" % actor.get("name", "actor"))
		not_ok(occupied.has(cell), "%s does not overlap another actor" % actor.get("name", "actor"))
		occupied[cell] = true
	eq(layout.elevation_at(Vector2i(-1, 0)), layout.INVALID_ELEVATION,
			"out-of-bounds elevation query fails closed")
	not_ok(layout.is_walkable(Vector2i(layout.GRID_SIZE.x, 0)),
			"out-of-bounds walkability query fails closed")
