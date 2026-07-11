extends "res://tests/gd_test.gd"
## Scripted combat acceptance coverage (T-068 core): drives the real
## CombatScene mechanics - command branches, range refusal, the D-012
## arena seed, and one full seeded auto-battle to completion. Every test
## resets shared SceneManager state it touches.


func _character(id: String) -> CharacterStats:
	return load("res://data/characters/%s.tres" % id)


func _slime() -> EnemyStats:
	return load("res://data/enemies/forest_slime.tres")


## A minimal battle scene added to the tree (awaitable timers need it) with
## an open arena; auto=false so nothing runs until we drive it.
func _scene(party: Array[CombatUnit], foes: Array[CombatUnit],
		defend_unlocked := false) -> CombatScene:
	var c := CombatScene.new()
	# Block _ready's _run_battle from racing the test: we drive manually.
	c.autostart = false
	c.rng = RandomNumberGenerator.new()
	c.rng.seed = 1234
	c.auto_play = true
	c.defend_unlocked = defend_unlocked
	c.arena_w = 9
	c.arena_h = 5
	c.units.append_array(party)
	c.units.append_array(foes)
	return c


func test_defend_is_gated_on_the_shield() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	SceneManager.inventory = {}
	var without := _scene([hero], [foe], false)
	var kinds_without: Array = without._build_root_options(hero) \
			.map(func(o: Dictionary) -> String: return o["kind"])
	not_ok(kinds_without.has("defend"), "no shield -> Defend absent (D-007)")
	ok(kinds_without.has("attack") and kinds_without.has("ability")
			and kinds_without.has("item"), "Attack/Ability/Item always listed")
	var with_shield := _scene([hero], [foe], true)
	var kinds_with: Array = with_shield._build_root_options(hero) \
			.map(func(o: Dictionary) -> String: return o["kind"])
	ok(kinds_with.has("defend"), "shield -> Defend present")
	without.free()
	with_shield.free()
	SceneManager.reset_session_state()


func test_item_option_tracks_potion_stock() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	var c := _scene([hero], [foe])
	SceneManager.inventory = {}
	var no_potion: Dictionary = c._build_root_options(hero)[2]
	not_ok(no_potion["enabled"], "Item greyed out with no potions")
	SceneManager.add_item("potion")
	var with_potion: Dictionary = c._build_root_options(hero)[2]
	ok(with_potion["enabled"], "Item enabled once a potion is held")
	c.free()
	SceneManager.reset_session_state()


func test_reachable_cells_respect_move_range_and_solids() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	hero.cell = Vector2i(4, 2)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	foe.cell = Vector2i(5, 2)  # standing right of the hero: a living wall
	var c := _scene([hero], [foe])
	var reach := c._reachable_cells(hero)
	ok(reach.has(Vector2i(4, 2)), "own cell always reachable")
	ok(reach.has(Vector2i(1, 2)), "move_range 3 reaches 3 cells left")
	not_ok(reach.has(Vector2i(0, 2)), "4 cells away is out of range")
	not_ok(reach.has(Vector2i(5, 2)), "a living unit's cell is solid")
	# Walking around the foe costs steps: (6,2) is 2 away straight through
	# the foe, but 4 around it - beyond move_range via any legal path.
	not_ok(reach.has(Vector2i(6, 2)), "blocked straight line forces the long way around")
	c.free()


func test_ability_targets_and_mp_gate() -> void:
	var buddy := CombatUnit.from_character("companion_test",
			_character("companion_test"), 14, 6)
	buddy.cell = Vector2i(2, 2)
	var hero := CombatUnit.from_character("hero", _character("hero"), 10, 5)
	hero.cell = Vector2i(3, 2)  # adjacent ally, wounded (10/20)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	foe.cell = Vector2i(8, 4)  # far away - strike has no target
	var c := _scene([buddy, hero], [foe])
	var usable := c._usable_abilities(buddy)
	var ids: Array = usable.map(func(a: AbilityData) -> String: return a.id)
	ok(ids.has("mend"), "mend usable: wounded ally in range")
	not_ok(ids.has("strike"), "strike unusable: no foe within its range")
	buddy.mp = 0
	eq(c._usable_abilities(buddy).size(), 0, "no MP -> no abilities")
	c.free()


func test_mend_heals_without_a_roll_and_spends_mp() -> void:
	var buddy := CombatUnit.from_character("companion_test",
			_character("companion_test"), 14, 6)
	var hero := CombatUnit.from_character("hero", _character("hero"), 10, 5)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	var c := _scene([buddy, hero], [foe])
	add_child(c)  # _execute_* awaits scene-tree timers
	var mend: AbilityData = load("res://data/abilities/mend.tres")
	await c._execute_ability(buddy, hero, mend)
	eq(hero.hp, 14, "mend healed its power (10 + 4)")
	eq(buddy.mp, 4, "mend spent 2 MP")
	c.queue_free()


func test_potion_heals_and_consumes_stock() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 10, 5)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	var c := _scene([hero], [foe])
	add_child(c)
	SceneManager.inventory = {"potion": 2}
	await c._execute_item(hero)
	eq(hero.hp, 15, "potion healed 5 (10 -> 15)")
	eq(SceneManager.inventory.get("potion"), 1, "one potion consumed")
	c.queue_free()
	SceneManager.reset_session_state()


func test_arena_seed_keeps_only_the_contact_connected_region() -> void:
	# A 12x7 room with a full-height wall at x=8, pocket beyond it. Contact
	# at (4,3): the pocket columns must come back blocked, the main region open.
	var room := RoomGrid.new()
	room.setup_grid(12, 7)
	for y in 7:
		room.set_blocked(Vector2i(8, y), true)
	var saved_room: Node2D = SceneManager.current_room
	SceneManager.current_room = room
	var arena: Dictionary = SceneManager._arena_from_room(Vector2i(4, 3))
	SceneManager.current_room = saved_room
	eq(arena["w"], 12, "small rooms use their full width inside the 17-cell arena cap")
	var blocked: Array = arena["blocked"]
	ok(blocked.size() > 0, "the wall and pocket read as obstacles")
	# The wall column sits at local x = 8 - origin.x; contact side stays open.
	var origin_x: int = 0
	ok(blocked.has(Vector2i(8 - origin_x, 3)), "wall cell blocked in arena coords")
	not_ok(blocked.has(Vector2i(4 - origin_x, 3)), "contact cell open")
	room.free()


func test_party_deploys_vertically_with_forward_space() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	var buddy := CombatUnit.from_character("companion_test",
			_character("companion_test"), 14, 6)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	var c := _scene([hero, buddy], [foe])
	c.arena_w = 17
	c.arena_h = 7
	c._place_units([hero, buddy], [foe])
	eq(hero.cell.x, buddy.cell.x, "Buddy deploys beside Hero, never in front of Hero")
	not_ok(c.arena_blocked.has(hero.cell + Vector2i.RIGHT),
			"Hero always has an open forward deployment cell")
	not_ok(buddy.cell == hero.cell + Vector2i.RIGHT,
			"Buddy cannot consume Hero's first forward move")
	c.free()


func test_full_auto_battle_runs_to_victory_with_payload() -> void:
	# Seeded 2v2: hero + companion vs two slimes on an open field. Auto-play
	# drives both sides; the battle must terminate and report party HP/MP.
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	var buddy := CombatUnit.from_character("companion_test",
			_character("companion_test"), 14, 6)
	var s1 := CombatUnit.from_enemy(_slime(), 0)
	var s2 := CombatUnit.from_enemy(_slime(), 1)
	var c := CombatScene.new()
	c.rng = RandomNumberGenerator.new()
	c.rng.seed = 42
	c.auto_play = true
	c.setup([hero, buddy], [s1, s2],
			{"w": 9, "h": 5, "blocked": []}, c.rng, true, false)
	add_child(c)  # _ready kicks off _run_battle
	var result: Array = await c.finished
	ok(result[0], "seeded 2v2 ends in victory")
	var payload: Dictionary = result[1]
	ok(payload["party_hp"].has("hero") and payload["party_hp"].has("companion_test"),
			"payload carries both party members' HP")
	ok(payload["party_hp"]["hero"] > 0 or payload["party_hp"]["companion_test"] > 0,
			"at least one survivor on a victory")
	ok(payload["party_mp"].has("hero"), "payload carries MP too")
	eq(s1.hp, 0, "first slime down")
	eq(s2.hp, 0, "second slime down")
	c.queue_free()


func test_turn_order_hud_uses_live_turn_manager_order() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	var buddy := CombatUnit.from_character("companion_test",
			_character("companion_test"), 14, 6)
	var slime := CombatUnit.from_enemy(_slime(), 0)
	var c := _scene([hero, buddy], [slime])
	c.tm.setup(c.units)
	eq(c._turn_order_text(), "Turn order: Hero -> Buddy (Test) -> Forest Slime",
			"HUD follows TurnManager speed order")
	slime.hp = 0
	eq(c._turn_order_text(), "Turn order: Hero -> Buddy (Test)",
			"HUD drops defeated units from the live order")
	c.free()
