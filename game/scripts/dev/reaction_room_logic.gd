extends RefCounted
## T-093B caller-side bridge for the gray-box reaction room (D-031).
##
## Sol's T-093A core (reaction_core.gd) owns every reaction rule. This file
## owns ONLY the work the T093_REACTION_CORE_API doc leaves to callers, in one
## pure place so exploration and encounter cannot drift apart:
##
##   - cast(): the single invocation path both contexts use. Their only
##     difference is the context string, exactly as the API contract demands.
##   - units_hit()/apply_hits(): map Sol's cell-shaped damage onto whoever
##     stands there, preview-first (units_hit is the preview, apply_hits
##     commits exactly that preview).
##   - intent_disrupted(): the generic rule letting an environmental reaction
##     cancel a declared enemy intention - a hit on the intention's owner
##     disrupts its aim. No per-character pairwise code (D-031).
##   - push_destination(): the forced-movement preview twin of
##     IntentLogic.push_unit, so shove commits exactly what it showed.
##
## No reaction rules, no scene nodes, no randomness. Spike code - graduating
## it into production architecture is its own explicit decision.

const ReactionCore := preload("res://scripts/world/reaction_core.gd")

const PREVIEW_PANEL_MARGIN := 12.0
const PREVIEW_PANEL_TOP := 68.0
const PREVIEW_PANEL_WIDTH := 500.0
const PREVIEW_PANEL_HEIGHT := 260.0
const COMBAT_LABEL_LEFT := 12.0
const COMBAT_LABEL_GUTTER := 12.0


## Keep the dense neutral consequence preview inside the current viewport.
## The room supports flexible HD/ultrawide windows, so the UI cannot assume
## that the 1280x720 proof size is the only live layout.
static func preview_panel_rect(viewport_size: Vector2) -> Rect2:
	var width := minf(PREVIEW_PANEL_WIDTH,
			maxf(0.0, viewport_size.x - PREVIEW_PANEL_MARGIN * 2.0))
	var available_height := maxf(0.0,
			viewport_size.y - PREVIEW_PANEL_TOP - PREVIEW_PANEL_MARGIN)
	var height := minf(PREVIEW_PANEL_HEIGHT, available_height)
	return Rect2(Vector2(viewport_size.x - width - PREVIEW_PANEL_MARGIN,
			PREVIEW_PANEL_TOP), Vector2(width, height))


## Reserve explicit logical-viewport rectangles for the inherited encounter
## labels. Header labels stop at a gutter left of the consequence panel; the
## command prompt owns a separate bottom band.
static func combat_label_rects(viewport_size: Vector2) -> Dictionary:
	var panel := preview_panel_rect(viewport_size)
	var header_width := maxf(0.0,
			panel.position.x - COMBAT_LABEL_GUTTER - COMBAT_LABEL_LEFT)
	return {
		"plan": Rect2(Vector2(COMBAT_LABEL_LEFT, 8.0),
				Vector2(header_width, 24.0)),
		"intent": Rect2(Vector2(COMBAT_LABEL_LEFT, 34.0),
				Vector2(header_width, 28.0)),
		"prompt": Rect2(Vector2(COMBAT_LABEL_LEFT,
				maxf(0.0, viewport_size.y - 52.0)),
				Vector2(maxf(0.0, viewport_size.x - COMBAT_LABEL_LEFT * 2.0),
						40.0)),
	}


## World-space HP labels can cross into the CanvasLayer preview after camera
## transforms. Return the exact viewport-space translation that keeps the
## label and the panel gutter disjoint; labels already outside keep their
## actor-relative placement.
static func label_shift_left_of_panel(panel_rect: Rect2,
		label_rect: Rect2) -> Vector2:
	if not panel_rect.intersects(label_rect):
		return Vector2.ZERO
	return Vector2(panel_rect.position.x - COMBAT_LABEL_GUTTER
			- label_rect.end.x, 0.0)


## Parse the physical PNG size required by a proof run. Invalid input returns
## ZERO so the caller can fail before accepting mislabeled artifacts.
static func capture_size_from_text(text: String) -> Vector2i:
	var parts := text.split("x", false)
	if parts.size() != 2 or not parts[0].is_valid_int() \
			or not parts[1].is_valid_int():
		return Vector2i.ZERO
	var size := Vector2i(int(parts[0]), int(parts[1]))
	if size.x <= 0 or size.y <= 0:
		return Vector2i.ZERO
	return size


## A complete frame may contain very dark UI, but broad exactly-black samples
## indicate Metal exposed an incompletely populated viewport. Keep this pure so
## the capture guard's threshold is pinned without depending on a renderer.
static func capture_samples_are_complete(luminances: Array,
		max_black_fraction := 0.02) -> bool:
	if luminances.is_empty():
		return false
	var black_samples := 0
	for value: Variant in luminances:
		if float(value) <= 0.01:
			black_samples += 1
	return float(black_samples) / float(luminances.size()) <= max_black_fraction


## Semantic shape cues consumed by the live gray-box draw path. Smoke is
## deliberately listed first so the flame remains the topmost mark when both
## states occupy one cell.
static func material_cue_shapes(tags: Array) -> Array[String]:
	var cues: Array[String] = []
	if tags.has("smoke"):
		cues.append("smoke_puffs")
	if tags.has("fire"):
		cues.append("fire_flame")
	return cues


## Exploration instruction layers must leave the viewport when the encounter
## HUD becomes authoritative.
static func exploration_hints_visible(in_encounter: bool) -> bool:
	return not in_encounter


## Rejected aim input needs a reason at the point of refusal. The range message
## wins when a candidate is both outside the room and beyond the cast radius.
static func aim_rejection_text(is_targetable: bool, distance: int,
		cast_range: int) -> String:
	if distance > cast_range:
		return "Aim limit reached (range %d)." % cast_range
	if not is_targetable:
		return "Aim blocked by the room edge or wall."
	return ""


## Lost window focus is recoverable player state, not a silent input failure.
static func focus_prompt_text(window_focused: bool) -> String:
	if window_focused:
		return ""
	return "Click inside the game window to enable controls."


## Build the room's reaction world-state: exactly the targetable cells exist,
## seeded with their authored material tags. Anything not listed here fails
## closed inside the core with target_cell_missing.
static func build_state(width: int, height: int, targetable_cells: Array,
		seeds: Dictionary) -> Dictionary:
	var cells := {}
	for cell: Vector2i in targetable_cells:
		var tags: Array = seeds.get(cell, [])
		cells[cell] = {"tags": tags.duplicate(), "statuses": {}}
	return {"width": width, "height": height, "cells": cells}


## Cardinal direction from caster toward target: larger axis wins, diagonal
## ties prefer horizontal, self-target falls back to RIGHT. Deterministic -
## the same rule intent_logic uses for its axis aiming.
static func cast_direction(caster: Vector2i, target: Vector2i) -> Vector2i:
	var delta := target - caster
	if absi(delta.x) >= absi(delta.y) and delta.x != 0:
		return Vector2i(signi(delta.x), 0)
	if delta.y != 0:
		return Vector2i(0, signi(delta.y))
	return Vector2i.RIGHT


## THE shared reaction entry: both the exploration caller and the encounter
## caller invoke this exact function, which invokes Sol's exact entry point.
## Context is passed through as metadata only; it never branches anything.
static func cast(state: Dictionary, verb: String, caster_cell: Vector2i,
		target: Vector2i, context: String) -> Dictionary:
	return ReactionCore.calculate(state, {
		"verb": verb,
		"target": target,
		"context": context,
		"direction": cast_direction(caster_cell, target),
	})


## Preview which units a committed reaction would hit: every living unit
## standing on a damaged cell, in propagation (damage-list) order. This is the
## "mapping them to units is caller work" seam from Sol's API doc.
static func units_hit(units: Dictionary, result: Dictionary) -> Array:
	var hits: Array = []
	for entry: Dictionary in result.get("damage", []):
		var cell: Vector2i = entry["cell"]
		var ids: Array = units.keys()
		ids.sort()
		for id: String in ids:
			var unit: Dictionary = units[id]
			if int(unit["hp"]) > 0 and unit["cell"] == cell:
				hits.append({"id": id, "cell": cell,
						"amount": int(entry["amount"]),
						"kind": str(entry["kind"])})
	return hits


## True when these hits would disrupt (cancel) the declared intention: the
## intention is live and its owner is among the units hit. Generic for any
## intention owner - no bespoke character pairs (D-031).
static func intent_disrupted(intent: Dictionary, hits: Array) -> bool:
	if intent.is_empty() or intent.get("canceled", false):
		return false
	var owner := str(intent.get("owner", ""))
	if owner == "":
		return false
	for hit: Dictionary in hits:
		if str(hit["id"]) == owner:
			return true
	return false


## Commit exactly what units_hit previewed - nothing more, nothing less.
static func apply_hits(units: Dictionary, hits: Array) -> void:
	for hit: Dictionary in hits:
		var unit: Dictionary = units[hit["id"]]
		unit["hp"] = int(unit["hp"]) - int(hit["amount"])


## Forced-movement preview: predict IntentLogic.push_unit without mutating.
## Legal exactly when the destination is in bounds, unblocked, and free of
## living units - the same checks push_unit applies.
static func push_destination(state: Dictionary, target_id: String,
		dir: Vector2i) -> Dictionary:
	var unit: Dictionary = state["units"][target_id]
	var dest: Vector2i = unit["cell"] + dir
	var legal: bool = dest.x >= 0 and dest.y >= 0 \
			and dest.x < int(state["width"]) and dest.y < int(state["height"]) \
			and not state["blocked"].has(dest)
	if legal:
		var ids: Array = state["units"].keys()
		ids.sort()
		for id: String in ids:
			if id == target_id:
				continue
			var other: Dictionary = state["units"][id]
			if int(other["hp"]) > 0 and other["cell"] == dest:
				legal = false
				break
	return {"legal": legal, "dest": dest}
