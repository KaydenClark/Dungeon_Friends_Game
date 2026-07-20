extends "res://tests/gd_test.gd"
## T-093B strict red/green suite for the gray-box reaction room's caller-side
## bridge. The bridge owns exactly the work Sol's T-093A API leaves to callers:
## one shared invocation path into ReactionCore.calculate for BOTH exploration
## and encounter casts, mapping cell-shaped damage onto units, disrupting a
## declared enemy intention, and the forced-movement (shove) preview contract.
## It must never contain reaction rules of its own.

const ReactionRoomLogic := preload("res://scripts/dev/reaction_room_logic.gd")
const IntentLogic := preload("res://scripts/world/intent_logic.gd")


func _cell(tags: Array = [], statuses := {}) -> Dictionary:
	return {"tags": tags.duplicate(), "statuses": statuses.duplicate(true)}


func _wet_chain_state() -> Dictionary:
	return {"width": 10, "height": 8, "cells": {
		Vector2i(2, 2): _cell(["wet"]),
		Vector2i(3, 2): _cell(["wet"]),
		Vector2i(4, 2): _cell(["floor"]),
	}}


func _outcome(result: Dictionary) -> Dictionary:
	var copy := result.duplicate(true)
	copy.erase("metadata")
	return copy


func _unit(id: String, cell: Vector2i, hp: int, side := "enemy") -> Dictionary:
	return {"id": id, "cell": cell, "hp": hp, "max_hp": hp, "atk": 3, "df": 1,
			"side": side, "statuses": {}}


## The consequence panel must stay inside the live viewport at every supported
## review size. This prevents preview copy from spilling over the window edge
## or relying on one hard-coded desktop resolution.
func test_preview_panel_layout_is_viewport_contained() -> void:
	for viewport_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080),
			Vector2(960, 540)]:
		var rect: Rect2 = ReactionRoomLogic.preview_panel_rect(viewport_size)
		ok(rect.position.x >= 0.0 and rect.position.y >= 0.0,
				"panel starts inside %s" % str(viewport_size))
		ok(rect.end.x <= viewport_size.x and rect.end.y <= viewport_size.y,
				"panel ends inside %s" % str(viewport_size))
		eq(rect.end.x, viewport_size.x - 12.0,
				"panel keeps the right safe margin at %s" % str(viewport_size))
		ok(rect.size.x >= 420.0 and rect.size.y >= 240.0,
				"panel remains readable at %s" % str(viewport_size))


## Combat labels get an explicit left/bottom reservation instead of relying on
## whatever minimum size a Label happens to calculate. Every reserved label
## rectangle must stay disjoint from the consequence panel.
func test_preview_panel_never_intersects_reserved_combat_label_rects() -> void:
	for viewport_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080),
			Vector2(960, 540)]:
		var panel := ReactionRoomLogic.preview_panel_rect(viewport_size)
		var labels: Dictionary = ReactionRoomLogic.combat_label_rects(viewport_size)
		for label_name: String in labels:
			var label_rect: Rect2 = labels[label_name]
			not_ok(panel.intersects(label_rect),
					"%s label stays outside the panel at %s"
					% [label_name, str(viewport_size)])
		eq(labels["intent"].end.x, panel.position.x - 12.0,
				"intent reservation ends at the panel gutter")


## Per-unit HP labels live under world actors rather than the encounter
## CanvasLayer. A viewport-space collision must still yield the exact shift
## needed to reserve the panel gutter.
func test_world_hp_label_collision_shifts_left_of_preview_panel() -> void:
	var panel := Rect2(Vector2(768, 68), Vector2(500, 260))
	var blocker_hp := Rect2(Vector2(832, 174), Vector2(104, 18))
	var shift: Vector2 = ReactionRoomLogic.label_shift_left_of_panel(
			panel, blocker_hp)
	eq(shift, Vector2(-180, 0),
			"intersecting HP label shifts to the panel's left gutter")
	not_ok(panel.intersects(Rect2(blocker_hp.position + shift,
			blocker_hp.size)), "shifted HP label is disjoint from the panel")
	eq(ReactionRoomLogic.label_shift_left_of_panel(panel,
			Rect2(Vector2(620, 174), Vector2(104, 18))), Vector2.ZERO,
			"already disjoint HP labels keep their actor-relative placement")


## Proof runs fail closed when the requested physical PNG dimensions are
## absent or malformed; the live tour consumes this exact parser.
func test_capture_size_parser_accepts_only_exact_positive_dimensions() -> void:
	eq(ReactionRoomLogic.capture_size_from_text("1280x720"),
			Vector2i(1280, 720), "1280 proof size parses exactly")
	eq(ReactionRoomLogic.capture_size_from_text("1920x1080"),
			Vector2i(1920, 1080), "1920 proof size parses exactly")
	eq(ReactionRoomLogic.capture_size_from_text("1920X1080"),
			Vector2i.ZERO, "uppercase separator fails closed")
	eq(ReactionRoomLogic.capture_size_from_text("0x720"),
			Vector2i.ZERO, "non-positive dimensions fail closed")
	eq(ReactionRoomLogic.capture_size_from_text("wide"),
			Vector2i.ZERO, "malformed dimensions fail closed")


## Metal may expose a partially populated frame even after frame_post_draw.
## The proof tour must reject broad black holes while accepting the intentionally
## near-black preview panel.
func test_capture_coverage_rejects_partial_metal_frames() -> void:
	var complete := [0.22, 0.31, 0.04, 0.18, 0.27, 0.12, 0.03, 0.45]
	var partial := [0.22, 0.0, 0.0, 0.18, 0.0, 0.0, 0.03, 0.45]
	ok(ReactionRoomLogic.capture_samples_are_complete(complete, 0.02),
			"dark UI remains valid when the frame has real coverage")
	not_ok(ReactionRoomLogic.capture_samples_are_complete(partial, 0.02),
			"broad pure-black holes reject a partial Metal frame")
	not_ok(ReactionRoomLogic.capture_samples_are_complete([], 0.02),
			"missing capture samples fail closed")


## Presentation cues are semantic shape names used by the live draw path.
## Smoke is painted first and fire last so a combined cell keeps both a
## smoke silhouette and an unobscured flame instead of becoming a muddy fill.
func test_fire_and_smoke_keep_distinct_shape_cues_when_combined() -> void:
	eq(ReactionRoomLogic.material_cue_shapes(["fire"]),
			["fire_flame"], "fire owns a flame-shaped board cue")
	eq(ReactionRoomLogic.material_cue_shapes(["smoke"]),
			["smoke_puffs"], "smoke owns a puff-shaped board cue")
	eq(ReactionRoomLogic.material_cue_shapes(["soil", "fire", "smoke"]),
			["smoke_puffs", "fire_flame"],
			"combined smoke renders below a still-visible fire mark")


## The instruction layers are exploration-only. Encounter HUD and unit labels
## must get the viewport without the inherited spike hints covering them.
func test_exploration_hints_hide_during_an_encounter() -> void:
	ok(ReactionRoomLogic.exploration_hints_visible(false),
			"exploration instructions show while exploring")
	not_ok(ReactionRoomLogic.exploration_hints_visible(true),
			"exploration instructions hide for the active encounter")


## Rejected input is not allowed to look like a frozen game. The live scene
## consumes these exact messages for range/wall rejection and lost focus.
func test_blocked_aim_and_window_focus_have_visible_feedback() -> void:
	eq(ReactionRoomLogic.aim_rejection_text(false, 2, 3),
			"Aim blocked by the room edge or wall.",
			"an untargetable aim cell explains the refusal")
	eq(ReactionRoomLogic.aim_rejection_text(true, 4, 3),
			"Aim limit reached (range 3).",
			"an out-of-range aim cell explains the clamp")
	eq(ReactionRoomLogic.aim_rejection_text(true, 2, 3), "",
			"a legal aim direction needs no warning")
	eq(ReactionRoomLogic.focus_prompt_text(false),
			"Click inside the game window to enable controls.",
			"lost focus gives the player a recovery action")
	eq(ReactionRoomLogic.focus_prompt_text(true), "",
			"focused play keeps the prompt out of the way")


## The acceptance seam: the exploration caller and the encounter caller invoke
## the SAME cast() path and identical state produces identical reaction data -
## context is presentation metadata only.
func test_exploration_and_encounter_casts_share_one_engine_and_agree() -> void:
	var state := _wet_chain_state()
	var before := state.duplicate(true)
	var caster := Vector2i(2, 4)
	var exploration := ReactionRoomLogic.cast(state, "spark", caster,
			Vector2i(2, 2), "exploration")
	var encounter := ReactionRoomLogic.cast(state, "spark", caster,
			Vector2i(2, 2), "encounter")
	eq(state, before, "cast never mutates the caller's world state")
	ok(exploration["valid"], "the exploration cast is valid")
	eq(_outcome(exploration), _outcome(encounter),
			"identical state through both callers yields identical results")
	eq(exploration["metadata"]["context"], "exploration",
			"exploration context is metadata only")
	eq(encounter["metadata"]["context"], "encounter",
			"encounter context is metadata only")
	eq(exploration["propagation_order"], [Vector2i(2, 2), Vector2i(3, 2)],
			"the shared path is really Sol's engine (wet conduction happened)")


## Air/fire direction is derived from caster -> target, cardinal only,
## deterministically: larger axis wins, ties prefer horizontal.
func test_cast_direction_is_deterministic_cardinal() -> void:
	eq(ReactionRoomLogic.cast_direction(Vector2i(2, 2), Vector2i(5, 3)),
			Vector2i.RIGHT, "larger x delta wins")
	eq(ReactionRoomLogic.cast_direction(Vector2i(2, 2), Vector2i(2, 5)),
			Vector2i.DOWN, "pure y delta goes vertical")
	eq(ReactionRoomLogic.cast_direction(Vector2i(5, 2), Vector2i(2, 2)),
			Vector2i.LEFT, "negative x delta goes left")
	eq(ReactionRoomLogic.cast_direction(Vector2i(2, 5), Vector2i(2, 2)),
			Vector2i.UP, "negative y delta goes up")
	eq(ReactionRoomLogic.cast_direction(Vector2i(2, 2), Vector2i(4, 4)),
			Vector2i.RIGHT, "diagonal ties prefer horizontal")
	eq(ReactionRoomLogic.cast_direction(Vector2i(2, 2), Vector2i(2, 2)),
			Vector2i.RIGHT, "self-target falls back to a legal cardinal")


func test_cast_feeds_air_the_caster_relative_direction() -> void:
	var state := {"width": 10, "height": 8, "cells": {
		Vector2i(3, 3): _cell(["fire", "smoke"]),
		Vector2i(2, 3): _cell(["vine"], {"vine_strength": 1}),
		Vector2i(1, 3): _cell(["flammable"]),
	}}
	var result := ReactionRoomLogic.cast(state, "air", Vector2i(5, 3),
			Vector2i(3, 3), "exploration")
	ok(result["valid"], "air cast is valid")
	eq(result["propagation_order"],
			[Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 3)],
			"air fed the flame away from the caster, through the chain")


## Cell-shaped reaction damage maps onto whoever stands there NOW; dead units
## and unhit bystanders are excluded. This mapping is the "caller work" Sol's
## API doc names, in one pure place shared by preview and commit.
func test_units_hit_maps_cell_damage_to_living_units_only() -> void:
	var units := {
		"slime": _unit("slime", Vector2i(2, 2), 5),
		"husk": _unit("husk", Vector2i(3, 2), 0),
		"hero": _unit("hero", Vector2i(6, 6), 20, "party"),
	}
	var state := _wet_chain_state()
	var result := ReactionRoomLogic.cast(state, "spark", Vector2i(2, 4),
			Vector2i(2, 2), "encounter")
	var hits: Array = ReactionRoomLogic.units_hit(units, result)
	eq(hits, [{"id": "slime", "cell": Vector2i(2, 2), "amount": 2,
			"kind": "spark"}],
			"the living unit on a damaged cell is hit; the dead one is not")


func test_units_hit_is_empty_when_no_unit_stands_in_the_damage() -> void:
	var units := {"hero": _unit("hero", Vector2i(6, 6), 20, "party")}
	var state := _wet_chain_state()
	var result := ReactionRoomLogic.cast(state, "spark", Vector2i(2, 4),
			Vector2i(2, 2), "encounter")
	eq(ReactionRoomLogic.units_hit(units, result), [],
			"reaction damage on empty cells hits nobody")


## An environmental hit on the intention's owner disrupts (cancels) it; hits
## on anyone else never do, and an already-canceled intention stays canceled
## rather than double-reporting.
func test_intent_disrupted_only_by_hits_on_the_owner() -> void:
	var intent := {"owner": "slime", "verb": "spit", "canceled": false}
	var slime_hit := [{"id": "slime", "cell": Vector2i(2, 2), "amount": 2,
			"kind": "spark"}]
	var hero_hit := [{"id": "hero", "cell": Vector2i(5, 5), "amount": 2,
			"kind": "fire"}]
	ok(ReactionRoomLogic.intent_disrupted(intent, slime_hit),
			"a hit on the owner disrupts its declared intention")
	not_ok(ReactionRoomLogic.intent_disrupted(intent, hero_hit),
			"a hit on someone else never disrupts it")
	not_ok(ReactionRoomLogic.intent_disrupted(intent, []),
			"no hits, no disruption")
	var canceled := {"owner": "slime", "verb": "spit", "canceled": true}
	not_ok(ReactionRoomLogic.intent_disrupted(canceled, slime_hit),
			"an already-canceled intention is not re-disrupted")


## Preview = result for the unit mapping: applying the hits changes each hp by
## exactly the previewed amount and nothing else.
func test_apply_hits_commits_exactly_the_previewed_amounts() -> void:
	var units := {
		"slime": _unit("slime", Vector2i(2, 2), 5),
		"hero": _unit("hero", Vector2i(3, 2), 20, "party"),
	}
	var state := _wet_chain_state()
	var result := ReactionRoomLogic.cast(state, "spark", Vector2i(2, 4),
			Vector2i(2, 2), "encounter")
	var hits: Array = ReactionRoomLogic.units_hit(units, result)
	eq(hits.size(), 2, "both units in the conduction are previewed")
	ReactionRoomLogic.apply_hits(units, hits)
	eq(int(units["slime"]["hp"]), 3, "the slime lost exactly the previewed 2")
	eq(int(units["hero"]["hp"]), 18, "the hero lost exactly the previewed 2")


## Forced-movement preview contract: push_destination must predict exactly
## what IntentLogic.push_unit will do, without mutating anything.
func test_push_destination_predicts_push_unit_exactly() -> void:
	var state := {"width": 8, "height": 6, "blocked": {Vector2i(4, 1): true},
			"units": {
				"slime": _unit("slime", Vector2i(4, 2), 5),
				"hero": _unit("hero", Vector2i(4, 3), 20, "party"),
			}}
	for dir: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN,
			Vector2i.LEFT]:
		var shown: Dictionary = ReactionRoomLogic.push_destination(
				state, "slime", dir)
		var live := state.duplicate(true)
		var intent := {"owner": "slime", "canceled": false}
		var pushed: bool = IntentLogic.push_unit(live, "slime", dir, intent)
		eq(shown["legal"], pushed,
				"push preview legality matches push_unit for %s" % str(dir))
		if pushed:
			eq(shown["dest"], live["units"]["slime"]["cell"],
					"push preview destination matches push_unit for %s" % str(dir))
	not_ok(ReactionRoomLogic.push_destination(state, "slime", Vector2i.UP)["legal"],
			"pushing into blocked terrain previews as illegal")
	not_ok(ReactionRoomLogic.push_destination(state, "slime", Vector2i.DOWN)["legal"],
			"pushing into an occupied cell previews as illegal")


## build_state exposes exactly the targetable cells; anything else fails
## closed inside Sol's engine instead of silently springing into existence.
func test_build_state_covers_exactly_the_targetable_cells() -> void:
	var seeds := {Vector2i(1, 1): ["channel"], Vector2i(2, 1): ["smoke"]}
	var state: Dictionary = ReactionRoomLogic.build_state(6, 4,
			[Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], seeds)
	eq(state["width"], 6, "width carried")
	eq(state["height"], 4, "height carried")
	eq(state["cells"].size(), 3, "exactly the targetable cells exist")
	eq(state["cells"][Vector2i(1, 1)]["tags"], ["channel"], "seed tags applied")
	eq(state["cells"][Vector2i(3, 1)]["tags"], [], "unseeded cells start bare")
	var offgrid := ReactionRoomLogic.cast(state, "grow", Vector2i(1, 2),
			Vector2i(4, 1), "exploration")
	not_ok(offgrid["valid"], "a wall/untargetable cell fails closed")
	eq(offgrid["error"], "target_cell_missing", "with Sol's explicit error")
