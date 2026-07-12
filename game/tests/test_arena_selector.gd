extends "res://tests/gd_test.gd"
## Strict red/green coverage for T-072's pure authored-arena selector. The
## production combat path is deliberately not involved here: these tests pin
## the data/selection/save contract that T-074 will consume.

const SAVE_DIR := "user://arena_selector_save_test"


func _arena(arena_id: String, biome := "forest",
		tags := PackedStringArray(), tier := "empty", weight := 1) -> ArenaData:
	var arena := ArenaData.new()
	arena.id = arena_id
	arena.biome = biome
	arena.tags = tags
	arena.tier = tier
	arena.weight = weight
	arena.ldtk_path = "res://assets/levels/battle_arenas.ldtk"
	arena.level_id = arena_id
	return arena


func _forest_pool() -> Array[ArenaData]:
	return [
		_arena("forest_empty_01", "forest", PackedStringArray(["open"]), "empty", 5),
		_arena("forest_empty_02", "forest", PackedStringArray(["open"]), "empty", 5),
		_arena("forest_mid_01", "forest", PackedStringArray(["cover"]), "mid", 2),
		_arena("forest_mid_02", "forest", PackedStringArray(["cover"]), "mid", 2),
		_arena("forest_mid_03", "forest", PackedStringArray(["cover", "wet"]), "mid", 2),
		_arena("forest_hard_01", "forest", PackedStringArray(["tight"]), "hard", 1),
		_arena("forest_hard_02", "forest", PackedStringArray(["tight", "wet"]), "hard", 1),
	]


func _registry(records: Array[ArenaData]) -> ArenaRegistry:
	var registry := ArenaRegistry.new()
	for arena in records:
		ok(registry.register(arena), "registers %s: %s" % [arena.id, registry.last_error])
	return registry


func _wipe_save_dir() -> void:
	var root := DirAccess.open("user://")
	if root == null or not root.dir_exists("arena_selector_save_test"):
		return
	var inner := DirAccess.open(SAVE_DIR)
	for file in inner.get_files():
		inner.remove(file)
	root.remove("arena_selector_save_test")


func test_seven_forest_records_have_the_locked_weighted_ticket_mix() -> void:
	var registry := _registry(_forest_pool())
	var counts := {"empty": 0, "mid": 0, "hard": 0}
	var tickets := {"empty": 0, "mid": 0, "hard": 0}
	for arena in registry.all():
		counts[arena.tier] += 1
		tickets[arena.tier] += arena.weight
	eq(counts, {"empty": 2, "mid": 3, "hard": 2}, "the forest pool is 2/3/2")
	eq(tickets, {"empty": 10, "mid": 6, "hard": 2}, "the forest pool expands to 5/2/1 tickets")
	eq(ArenaSelector.ticket_count(registry.all()), 18, "all seven records produce 18 tickets")


func test_shipped_forest_records_resolve_as_the_locked_pool() -> void:
	ArenaLibrary.clear_cache()
	var registry := ArenaLibrary.registry()
	var records := registry.eligible("forest", PackedStringArray())
	eq(registry.all().size(), 8, "the shipped library also contains one dungeon arena")
	eq(records.size(), 7, "the shipped library contains seven authored forest arenas")
	eq(ArenaSelector.ticket_count(records), 18, "the shipped pool has 18 weighted tickets")
	var expected_ids := [
		"forest_open_glade", "forest_sunlit_meadow", "forest_split_grove",
		"forest_winding_copse", "forest_crossroads", "forest_thorn_choke",
		"forest_old_growth_maze",
	]
	var ids: Array[String] = []
	for arena in records:
		ids.append(arena.id)
		eq(arena.biome, "forest", "%s stays in the forest pool" % arena.id)
		not_ok(arena.level_id.is_empty(), "%s has a stable LDtk level id" % arena.id)
	eq(ids, expected_ids, "library preserves its stable authored record order")
	var dungeon_records := registry.eligible("dungeon", PackedStringArray(["stone"]))
	eq(dungeon_records.size(), 1, "dungeon context has one isolated authored arena")
	if dungeon_records.size() == 1:
		eq(dungeon_records[0].id, "dungeon_stone_hall", "dungeon selects the stone hall")


func test_biome_and_required_tags_narrow_eligible_records() -> void:
	var records := _forest_pool()
	records.append(_arena("cave_open", "cave", PackedStringArray(["wet"]), "empty", 5))
	var registry := _registry(records)
	var forest_wet := registry.eligible("forest", PackedStringArray(["wet"]))
	eq(forest_wet.size(), 2, "all requested tags must match within the biome")
	eq(forest_wet[0].id, "forest_mid_03", "forest wet record stays eligible")
	eq(forest_wet[1].id, "forest_hard_02", "second forest wet record stays eligible")
	var selector := ArenaSelector.new(11)
	var selected := selector.select(registry, "forest", PackedStringArray(["wet"]))
	not_null(selected, "selector returns a tagged forest arena")
	if selected != null:
		ok(selected.tags.has("wet"), "selected arena carries the requested tag")
		eq(selected.biome, "forest", "selected arena stays in the requested biome")


func test_known_seed_has_a_stable_draw_order() -> void:
	var registry := _registry([
		_arena("a"), _arena("b"), _arena("c"), _arena("d"), _arena("e"),
	])
	var selector := ArenaSelector.new(7)
	var actual: Array[String] = []
	for _unused in range(5):
		var selected := selector.select(registry, "forest")
		not_null(selected, "known-seed draw succeeds")
		if selected != null:
			actual.append(selected.id)
	eq(actual, ["a", "b", "d", "e", "c"], "seed 7 has the pinned shuffle order")


func test_no_immediate_repeat_survives_a_bag_refill() -> void:
	var registry := _registry([_arena("a"), _arena("b")])
	var selector := ArenaSelector.new(23)
	var previous := ""
	for _unused in range(8):
		var selected := selector.select(registry, "forest")
		not_null(selected, "two-record bag yields an arena")
		if selected == null:
			continue
		if previous != "":
			ne(selected.id, previous, "no immediate repeat, including after refill")
		previous = selected.id


func test_refills_are_deterministic_for_the_same_seed_and_context() -> void:
	var registry := _registry(_forest_pool())
	var first := ArenaSelector.new(29)
	var second := ArenaSelector.new(29)
	var first_draws: Array[String] = []
	var second_draws: Array[String] = []
	for _unused in range(36):
		var first_selected := first.select(registry, "forest")
		var second_selected := second.select(registry, "forest")
		first_draws.append(first_selected.id)
		second_draws.append(second_selected.id)
		if first_draws.size() > 1:
			ne(first_draws[-1], first_draws[-2],
					"the weighted forest pool never repeats immediately across refills")
	eq(first_draws, second_draws, "same seed repeats every draw and refill exactly")


func test_invalid_records_and_empty_eligibility_fail_explicitly() -> void:
	var registry := ArenaRegistry.new()
	var invalid := _arena("")
	not_ok(registry.register(invalid), "records without stable ids are rejected")
	not_ok(registry.last_error.is_empty(), "invalid record reports a useful error")
	ok(registry.register(_arena("forest_only")), "valid record can still register")
	var selector := ArenaSelector.new(3)
	is_null(selector.select(registry, "desert"), "empty eligibility has no silent fallback")
	not_ok(selector.last_error.is_empty(), "empty eligibility reports an explicit error")


func test_fixed_override_must_exist_and_match_the_encounter_context() -> void:
	var boss := _arena("forest_boss", "forest", PackedStringArray(["boss"]), "hard", 1)
	var registry := _registry([_arena("forest_open"), boss, _arena("cave_boss", "cave", PackedStringArray(["boss"]))])
	var selector := ArenaSelector.new(5)
	var selected := selector.select(registry, "forest", PackedStringArray(["boss"]), "forest_boss")
	not_null(selected, "valid fixed arena resolves")
	if selected != null:
		eq(selected.id, "forest_boss", "fixed override wins over the bag")
	is_null(selector.select(registry, "forest", PackedStringArray(["boss"]), "missing"),
			"unknown fixed arena is rejected")
	not_ok(selector.last_error.is_empty(), "unknown fixed arena explains the failure")
	is_null(selector.select(registry, "forest", PackedStringArray(["boss"]), "cave_boss"),
			"cross-biome fixed arena is rejected")


func test_save_load_continues_with_the_same_next_draw() -> void:
	_wipe_save_dir()
	var registry := _registry(_forest_pool())
	var uninterrupted := ArenaSelector.new(41)
	for _unused in range(4):
		uninterrupted.select(registry, "forest")
	var state := GameState.new()
	uninterrupted.store_in_game_state(state)
	var save := SaveManager.capture(state, "forest", Vector2i(3, 4))
	ok(SaveManager.write(1, save, SAVE_DIR), "selector state writes through SaveManager")
	var loaded := SaveManager.load_slot(1, SAVE_DIR)
	not_null(loaded, "saved selector state reloads")
	if loaded != null:
		var resumed := ArenaSelector.from_game_state(loaded.to_game_state())
		for _unused in range(8):
			var expected := uninterrupted.select(registry, "forest")
			var actual := resumed.select(registry, "forest")
			not_null(actual, "restored selector produces a draw")
			if actual != null:
				eq(actual.id, expected.id, "save/load cannot reroll the next arena")
	_wipe_save_dir()
