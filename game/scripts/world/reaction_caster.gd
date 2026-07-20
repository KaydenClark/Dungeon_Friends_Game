class_name ReactionCaster
extends Object
## S-011/TK-003: the one production caller for reaction abilities (D-031).
## Any AbilityData carrying a `reaction_verb` routes through the room's
## preview/commit seam - exploration and encounter callers use these exact
## two entry points, so the committed world is always the previewed result.
## Static helpers on purpose: no autoload, no scene state (single-autoload
## lock, see /BLUEPRINT.md -> Architecture).


## Preview-only: never mutates the room. Returns the complete neutral
## ReactionCore result, or {"valid": false, "error": ...} fail-closed.
static func preview(room: LdtkRoom, ability: AbilityData, target: Vector2i,
		direction := Vector2i.RIGHT, context := "exploration") -> Dictionary:
	if room == null or ability == null or ability.reaction_verb == "":
		return {"valid": false, "error": "not_a_reaction_ability"}
	var request := {"verb": ability.reaction_verb, "target": target,
			"context": context}
	if ability.reaction_verb == "air":
		request["direction"] = direction
	return room.preview_reaction(request)


## Preview then commit atomically. On any refusal (non-reaction ability,
## invalid verb/target, commit mismatch) the room is untouched and the
## returned result carries valid=false with a named error.
static func cast(room: LdtkRoom, ability: AbilityData, target: Vector2i,
		direction := Vector2i.RIGHT, context := "exploration") -> Dictionary:
	var result := preview(room, ability, target, direction, context)
	if not result.get("valid", false):
		return result
	var commit_error: String = room.commit_reaction(result)
	if commit_error != "":
		result["valid"] = false
		result["error"] = commit_error
	return result
