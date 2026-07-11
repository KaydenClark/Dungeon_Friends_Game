class_name ArenaSelector
extends RefCounted
## Deterministic weighted shuffle-bag selection for D-018 authored arenas.
## The serializable state stores the PRNG position and unconsumed tickets, so
## a save made before a draw resumes at the same arena rather than rerolling.

const STATE_VERSION := 1
const DEFAULT_SEED := 1
const _MODULUS := 2147483647
const _MULTIPLIER := 48271

var last_error := ""
var last_arena_id := ""
var _seed := DEFAULT_SEED
var _rng_state := DEFAULT_SEED
## {canonical biome/tag key: Array[String] unconsumed weighted ticket ids}
var _bags: Dictionary = {}


func _init(seed := DEFAULT_SEED) -> void:
	_seed = _normalize_seed(seed)
	_rng_state = _seed


## Expands only for inspection/tests. Production draws use the same weights
## through _build_shuffled_bag(), never a separate random path.
static func ticket_count(candidates: Array[ArenaData]) -> int:
	var total := 0
	for arena in candidates:
		if arena != null and arena.weight > 0:
			total += arena.weight
	return total


func select(registry: ArenaRegistry, requested_biome: String,
		required_tags: PackedStringArray = PackedStringArray(),
		fixed_arena_id := "") -> ArenaData:
	last_error = ""
	if registry == null:
		last_error = "ArenaSelector requires a registry"
		return null
	if requested_biome.strip_edges().is_empty():
		last_error = "ArenaSelector requires a biome"
		return null
	if not fixed_arena_id.strip_edges().is_empty():
		return _select_fixed(registry, requested_biome, required_tags, fixed_arena_id)

	var candidates := registry.eligible(requested_biome, required_tags)
	if candidates.is_empty():
		last_error = "No authored arenas match biome '%s' and tags %s" \
				% [requested_biome, str(required_tags)]
		return null
	var key := _context_key(requested_biome, required_tags)
	var bag := _usable_bag(key, candidates, registry)
	if bag.is_empty():
		bag = _build_shuffled_bag(candidates)
	if bag.is_empty():
		last_error = "No positive-weight authored arena tickets are available"
		return null

	# A weighted bag can hold repeat tickets. Before each draw, move an
	# alternate ticket forward. If this bag's remaining tickets are all the
	# prior id, append a deterministic refill instead of permitting a reroll.
	_prepare_next_draw(bag, candidates)
	var selected_id: String = bag.pop_front()
	_bags[key] = bag
	var selected := registry.resolve(selected_id)
	if selected == null:
		# _usable_bag should already discard stale ids. This is defensive only;
		# never silently substitute a different arena when persisted state is bad.
		last_error = "Arena selector state referenced unknown arena '%s'" % selected_id
		return null
	last_arena_id = selected.id
	return selected


func to_state() -> Dictionary:
	var serialized_bags := {}
	for key in _bags:
		var tickets: Array[String] = []
		for arena_id in _bags[key]:
			tickets.append(str(arena_id))
		serialized_bags[str(key)] = tickets
	return {
		"version": STATE_VERSION,
		"seed": _seed,
		"rng_state": _rng_state,
		"bags": serialized_bags,
		"last_arena_id": last_arena_id,
	}


## Tolerant because saves are player-controlled JSON. Invalid state leaves a
## fresh deterministic selector instead of making save loading fail.
func restore_state(raw: Variant) -> bool:
	last_error = ""
	if not raw is Dictionary:
		last_error = "Arena selector state must be a dictionary"
		return false
	var state: Dictionary = raw
	_seed = _normalize_seed(int(state.get("seed", _seed)))
	_rng_state = _normalize_seed(int(state.get("rng_state", _seed)))
	last_arena_id = str(state.get("last_arena_id", ""))
	_bags = {}
	var raw_bags: Variant = state.get("bags", {})
	if raw_bags is Dictionary:
		for raw_key in raw_bags:
			var raw_tickets: Variant = raw_bags[raw_key]
			if not raw_tickets is Array:
				continue
			var tickets: Array[String] = []
			for raw_id in raw_tickets:
				var arena_id := str(raw_id)
				if not arena_id.is_empty():
					tickets.append(arena_id)
			_bags[str(raw_key)] = tickets
	return true


func store_in_game_state(state: GameState) -> void:
	if state != null:
		state.arena_selector_state = to_state()


static func from_game_state(state: GameState,
		fallback_seed := DEFAULT_SEED) -> ArenaSelector:
	var selector := ArenaSelector.new(fallback_seed)
	if state != null and not state.arena_selector_state.is_empty():
		selector.restore_state(state.arena_selector_state)
	return selector


func _select_fixed(registry: ArenaRegistry, requested_biome: String,
		required_tags: PackedStringArray, fixed_arena_id: String) -> ArenaData:
	var fixed := registry.resolve(fixed_arena_id)
	if fixed == null:
		last_error = "Fixed arena '%s' is not registered" % fixed_arena_id
		return null
	if not fixed.matches(requested_biome, required_tags):
		last_error = "Fixed arena '%s' does not match biome/tags" % fixed_arena_id
		return null
	# Fixed encounters do not consume an ordinary encounter ticket, but they do
	# become the previous result so the next normal draw can avoid a repeat.
	last_arena_id = fixed.id
	return fixed


func _usable_bag(key: String, candidates: Array[ArenaData],
		registry: ArenaRegistry) -> Array[String]:
	var stored: Variant = _bags.get(key, [])
	var usable: Array[String] = []
	if not stored is Array:
		return usable
	for raw_id in stored:
		var arena := registry.resolve(str(raw_id))
		if arena != null and candidates.has(arena):
			usable.append(arena.id)
	return usable


func _build_shuffled_bag(candidates: Array[ArenaData]) -> Array[String]:
	var tickets: Array[String] = []
	for arena in candidates:
		for _ticket in range(arena.weight):
			tickets.append(arena.id)
	_shuffle(tickets)
	return tickets


func _prepare_next_draw(bag: Array[String], candidates: Array[ArenaData]) -> void:
	if bag.is_empty() or last_arena_id.is_empty() or bag[0] != last_arena_id:
		return
	if _move_nonrepeat_ticket_forward(bag):
		return
	# A one-record context necessarily repeats. With two or more records, keep
	# the remaining tickets and append a deterministic refill to preserve both
	# the no-repeat rule and every weighted ticket.
	if _distinct_candidate_count(candidates) < 2:
		return
	bag.append_array(_build_shuffled_bag(candidates))
	_move_nonrepeat_ticket_forward(bag)


func _move_nonrepeat_ticket_forward(bag: Array[String]) -> bool:
	for index in range(1, bag.size()):
		if bag[index] != last_arena_id:
			var replacement := bag[index]
			bag[index] = bag[0]
			bag[0] = replacement
			return true
	return false


func _distinct_candidate_count(candidates: Array[ArenaData]) -> int:
	var ids := {}
	for arena in candidates:
		ids[arena.id] = true
	return ids.size()


func _shuffle(values: Array[String]) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _next_random() % (index + 1)
		var previous := values[index]
		values[index] = values[swap_index]
		values[swap_index] = previous


func _next_random() -> int:
	_rng_state = int((_rng_state * _MULTIPLIER) % _MODULUS)
	if _rng_state <= 0:
		_rng_state = DEFAULT_SEED
	return _rng_state


static func _normalize_seed(raw_seed: int) -> int:
	var normalized := raw_seed % (_MODULUS - 1)
	if normalized <= 0:
		normalized += _MODULUS - 1
	return normalized


static func _context_key(requested_biome: String,
		required_tags: PackedStringArray) -> String:
	var normalized_tags: Array[String] = []
	for tag in required_tags:
		if not tag.is_empty() and not normalized_tags.has(tag):
			normalized_tags.append(tag)
	normalized_tags.sort()
	return "%s|%s" % [requested_biome, ",".join(normalized_tags)]
