# T-093A Shared Reaction Core API

T-093A provides the pure reaction seam that Fable's exploration and encounter
prototypes should consume. It does not own a room, rendering, input, ability
definitions, persistence, or commit timing.

## One Entry Point

```gdscript
const ReactionCore := preload("res://scripts/dev/reaction_core.gd")

var result: Dictionary = ReactionCore.calculate(state, {
	"verb": "spark",
	"target": Vector2i(4, 3),
	"context": "encounter", # or "exploration"; metadata only
	"direction": Vector2i.RIGHT, # cardinal; used only by air + fire
})
```

`calculate()` never mutates `state`. It computes the full result first. A
caller previews the neutral arrays, then commits only by adopting
`result.state_after` after confirmation:

```gdscript
var preview := ReactionCore.calculate(world_state, request)
show_reaction_preview(preview)
if preview.valid and player_confirmed:
	world_state = preview.state_after
```

Exploration and encounter callers must not wrap this in separate rule
functions. Their only allowed difference is `context`, which is returned as
`result.metadata.context`; it does not affect any reaction field.

## Input State

```gdscript
{
	"width": 8,
	"height": 6,
	"cells": {
		Vector2i(4, 3): {
			"tags": ["channel", "wet"],
			"statuses": {"wet_rounds": 2},
		},
	},
}
```

- Every addressable target must already exist in `cells`.
- Tags are ordered string arrays; statuses are neutral key/value data.
- This prototype uses `Vector2i` keys in memory. Save serialization belongs to
  T-091, not this API.

## Result Shape

Every call returns all keys below, including invalid/no-op calls:

```gdscript
{
	"valid": true,
	"error": "",
	"metadata": {"context": "encounter"},
	"changed_cells": [{"cell": Vector2i(...), "before": {}, "after": {}}],
	"resulting_cells": [{"cell": Vector2i(...), "tags": [], "statuses": {}}],
	"damage": [{"cell": Vector2i(...), "amount": 2, "kind": "spark"}],
	"hazards": [{"cell": Vector2i(...), "kind": "electrified_water", "damage": 2}],
	"propagation_order": [Vector2i(...)],
	"canceled_effects": [{"cell": Vector2i(...), "effect": "wet", "reason": "frozen"}],
	"cascade_steps": 1,
	"cascade_limited": false,
	"state_after": {},
}
```

- `changed_cells` carries before/after snapshots for commit diffing.
- `resulting_cells` is the presentation-friendly final tags/statuses view.
- `damage` and `hazards` are cell-shaped; mapping them to units is caller work.
- `propagation_order` is the exact animation/resolution order.
- `canceled_effects` makes consumed materials, cleared smoke, and truncated
  cascades explicit.

Invalid inputs return `valid = false`, an `error` such as `invalid_verb`,
`target_cell_missing`, or `invalid_direction`, empty result arrays, and an
unchanged `state_after`.

## Deterministic Rules

- `grow`: add `vine`; set/increment `vine_strength`, capped at 3.
- `fire`: consume `vine`/`flammable`; add `fire` + `smoke`; report 2 fire
  damage and a 2-damage fire hazard.
- `water`: add `wet` + `wet_rounds = 2`; a `channel` also gains `flooded`.
  Reapplication refreshes the same state instead of stacking.
- `cold`: consume `wet`/`flooded`; add `ice` + `frozen = true`.
- `spark`: starting on `wet`, conduct through cardinally connected wet cells;
  mark `electrified = true`, report 2 damage and an `electrified_water` hazard
  per visited cell. Wet remains, so a later spark can damage again.
- `air`: if the target has `fire`, fire wins precedence and spreads only in
  `direction` through a contiguous `vine`/`flammable` chain, stopping before
  the first nonflammable/missing cell. Otherwise, a `smoke` target clears its
  cardinally connected smoke component.

Connected propagation is breadth-first. Neighbor priority is **up, right,
down, left**. Directional air/fire follows the supplied cardinal vector. A
single call visits at most `ReactionCore.MAX_CASCADE_STEPS` (32) cells. A
visited set prevents cycles; when work remains at the boundary, the result sets
`cascade_limited = true` and appends the first unprocessed effect with
`reason = "cascade_limit"`.

## Fable Examples

Grow then burn:

```gdscript
var grow := ReactionCore.calculate(state, {
	"verb": "grow", "target": Vector2i(2, 2), "context": context,
})
var burn := ReactionCore.calculate(grow.state_after, {
	"verb": "fire", "target": Vector2i(2, 2), "context": context,
})
```

Flood then freeze:

```gdscript
var flood := ReactionCore.calculate(state, {
	"verb": "water", "target": Vector2i(5, 3), "context": context,
})
var freeze := ReactionCore.calculate(flood.state_after, {
	"verb": "cold", "target": Vector2i(5, 3), "context": context,
})
```

The caller should render `propagation_order`, `resulting_cells`, `damage`,
`hazards`, and `canceled_effects` directly. It should not recalculate any
reaction or apply a second scene-local rules table.
