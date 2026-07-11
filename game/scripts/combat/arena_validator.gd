class_name ArenaValidator
extends RefCounted
## Pure authored-arena safety checks. Both the developer gallery and tests use
## this exact validator so an editor preview cannot silently accept a board
## production combat would reject.

const EXPECTED_W := 17
const EXPECTED_H := 7
const MAX_BLOCKED_BY_TIER := {
	"empty": 2,
	"mid": 18,
	"hard": 28,
}


static func validate(arena: Dictionary, party_size: int = 4,
		enemy_size: int = 4) -> Array[String]:
	var errors: Array[String] = []
	var id := str(arena.get("id", ""))
	if id == "":
		errors.append("Arena id is required.")
	var w := int(arena.get("w", 0))
	var h := int(arena.get("h", 0))
	if w != EXPECTED_W or h != EXPECTED_H:
		errors.append("Arena must be %dx%d, got %dx%d." % [EXPECTED_W, EXPECTED_H, w, h])
	var tier := str(arena.get("tier", ""))
	if not MAX_BLOCKED_BY_TIER.has(tier):
		errors.append("Arena tier must be empty, mid, or hard.")
	var weight := int(arena.get("weight", 0))
	if weight <= 0:
		errors.append("Arena weight must be positive.")
	if str(arena.get("biome", "")) == "":
		errors.append("Arena biome is required.")
	var tags: Variant = arena.get("tags", [])
	if not (tags is Array or tags is PackedStringArray):
		errors.append("Arena tags must be an array.")
	var blocked := _cell_array(arena.get("blocked", []))
	var party_zone := _cell_array(arena.get("party_zone", []))
	var enemy_zone := _cell_array(arena.get("enemy_zone", []))
	var blocked_set := _cell_set(blocked)
	if blocked_set.size() != blocked.size():
		errors.append("Blocked cells contain duplicates.")
	for cell in blocked:
		if not _in_bounds(cell, w, h):
			errors.append("Blocked cell %s is outside the arena." % cell)
	if MAX_BLOCKED_BY_TIER.has(tier) and blocked_set.size() > MAX_BLOCKED_BY_TIER[tier]:
		errors.append("%s arena exceeds its %d-cell cover budget."
				% [tier, MAX_BLOCKED_BY_TIER[tier]])
	_validate_zone("PartyDeployment", party_zone, party_size, w, h, blocked_set, errors)
	_validate_zone("EnemyDeployment", enemy_zone, enemy_size, w, h, blocked_set, errors)
	var party_set := _cell_set(party_zone)
	for cell in enemy_zone:
		if party_set.has(cell):
			errors.append("PartyDeployment and EnemyDeployment overlap at %s." % cell)
	if not errors.is_empty():
		return errors
	var connected := _walkable_component(party_zone[0], w, h, blocked_set)
	for cell in party_zone:
		if not connected.has(cell):
			errors.append("PartyDeployment has a disconnected cell at %s." % cell)
	for cell in enemy_zone:
		if not connected.has(cell):
			errors.append("EnemyDeployment has a disconnected cell at %s." % cell)
	if not errors.is_empty():
		return errors
	var occupied := {}
	for i in range(1, party_size):
		occupied[party_zone[i]] = true
	for i in enemy_size:
		occupied[enemy_zone[i]] = true
	var hero_exits := 0
	for direction: Vector2i in _CARDINALS:
		var neighbor: Vector2i = party_zone[0] + direction
		if _in_bounds(neighbor, w, h) and not blocked_set.has(neighbor) \
				and not occupied.has(neighbor):
			hero_exits += 1
	if hero_exits < 2:
		errors.append("Hero deployment has fewer than two legal first moves with allies blocking.")
	if not _has_attack_approach(connected, enemy_zone, w, h, blocked_set):
		errors.append("No walkable attack approach reaches the enemy deployment side.")
	return errors


const _CARDINALS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


static func _validate_zone(label: String, zone: Array[Vector2i], required: int,
		w: int, h: int, blocked: Dictionary, errors: Array[String]) -> void:
	if zone.size() < required:
		errors.append("%s needs at least %d legal cells for %dv%d."
				% [label, required, required, required])
	var seen := {}
	for cell in zone:
		if not _in_bounds(cell, w, h):
			errors.append("%s cell %s is outside the arena." % [label, cell])
		elif blocked.has(cell):
			errors.append("%s cell %s is blocked." % [label, cell])
		if seen.has(cell):
			errors.append("%s contains a duplicate cell %s." % [label, cell])
		seen[cell] = true


static func _cell_array(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if raw is Array:
		for cell in raw:
			if cell is Vector2i:
				out.append(cell)
	return out


static func _cell_set(cells: Array[Vector2i]) -> Dictionary:
	var out := {}
	for cell in cells:
		out[cell] = true
	return out


static func _in_bounds(cell: Vector2i, w: int, h: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < w and cell.y < h


static func _walkable_component(start: Vector2i, w: int, h: int,
		blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		for direction: Vector2i in _CARDINALS:
			var neighbor: Vector2i = cell + direction
			if _in_bounds(neighbor, w, h) and not blocked.has(neighbor) \
					and not seen.has(neighbor):
				seen[neighbor] = true
				frontier.append(neighbor)
	return seen


static func _has_attack_approach(connected: Dictionary, enemy_zone: Array[Vector2i],
		w: int, h: int, blocked: Dictionary) -> bool:
	for enemy_cell in enemy_zone:
		for direction: Vector2i in _CARDINALS:
			var approach: Vector2i = enemy_cell + direction
			if _in_bounds(approach, w, h) and not blocked.has(approach) \
					and connected.has(approach):
				return true
	return false
