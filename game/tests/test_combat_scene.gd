extends "res://tests/gd_test.gd"
## Scripted combat acceptance coverage (T-068 core): drives the real
## CombatScene mechanics - command branches, range refusal, authored D-018
## deployment zones, and one full seeded auto-battle to completion. Every test
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


func test_item_menu_names_consumables_quantity_and_user() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	var c := _scene([hero], [foe])
	SceneManager.inventory = {"potion": 2, "shield": 1}
	var options: Array = c._build_item_options(hero)
	eq(options.size(), 2, "one usable consumable plus Back")
	eq(options[0]["label"], "Potion x2 -> Hero", "choice names item, quantity, and user")
	eq(options[0]["item_id"], "potion", "choice carries the selected item id")
	eq(options[1]["kind"], "back", "cancel path is explicit")
	c.free()
	SceneManager.reset_session_state()


func test_selected_item_only_consumes_its_own_id() -> void:
	var tonic := ItemData.new()
	tonic.id = "test_tonic"
	tonic.display_name = "Small Tonic"
	tonic.item_type = ItemData.ItemType.CONSUMABLE
	tonic.stat_modifiers = {"heal": 2}
	ItemLibrary.register(tonic)
	var hero := CombatUnit.from_character("hero", _character("hero"), 10, 5)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	var c := _scene([hero], [foe])
	add_child(c)
	SceneManager.inventory = {"potion": 2, "test_tonic": 1}
	await c._execute_item(hero, "test_tonic")
	eq(hero.hp, 12, "selected tonic applies its own heal value")
	eq(SceneManager.inventory.get("test_tonic", 0), 0, "selected tonic consumed")
	eq(SceneManager.inventory.get("potion", 0), 2, "unselected potion untouched")
	c.queue_free()
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


func test_authored_deployment_zones_drive_unit_placement() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	var buddy := CombatUnit.from_character("companion_test",
			_character("companion_test"), 14, 6)
	var foe_a := CombatUnit.from_enemy(_slime(), 0)
	var foe_b := CombatUnit.from_enemy(_slime(), 1)
	var arena := {
		"w": 17,
		"h": 7,
		"blocked": [],
		"party_zone": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 3), Vector2i(0, 4)],
		"enemy_zone": [Vector2i(15, 1), Vector2i(15, 2), Vector2i(16, 3), Vector2i(16, 4)],
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var c := CombatScene.new()
	c.setup([hero, buddy], [foe_a, foe_b], arena, rng, true, false)
	eq(hero.cell, Vector2i(1, 1), "Hero uses the first authored party slot")
	eq(buddy.cell, Vector2i(1, 2), "Buddy uses the next authored party slot")
	eq(foe_a.cell, Vector2i(15, 1), "first enemy uses authored enemy slot")
	eq(foe_b.cell, Vector2i(15, 2), "second enemy uses authored enemy slot")
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


func test_authored_arena_never_uses_the_contact_room_topology() -> void:
	var old_state := SceneManager.state
	var old_room := SceneManager.current_room
	SceneManager.state = GameState.new()
	var room := LdtkRoom.new()
	room.player = Player.new()
	room.player.cell = Vector2i(9, 3)
	SceneManager.current_room = room
	var enemy := OverworldEnemy.new()
	enemy.cell = Vector2i(10, 3)
	enemy.encounter = load("res://data/encounters/forest_pair.tres")
	var arena := SceneManager._select_authored_arena(enemy)
	eq(arena.get("w"), 17, "authored boards keep the 17-cell combat width")
	eq(arena.get("h"), 7, "authored boards keep the 7-cell combat height")
	eq(arena.get("biome"), "forest", "forest encounter selects forest arena data")
	not_ok(arena.has("contact_origin"), "no contact-window terrain metadata survives")
	ok(arena.has("party_zone") and arena.has("enemy_zone"),
			"authored deployment zones replace copied contact columns")
	eq(ArenaValidator.validate(arena).size(), 0,
			"selected production arena passes the shared safety validator")
	var visual := arena.get("visual") as Node2D
	if visual != null:
		visual.free()
	SceneManager.current_room = old_room
	SceneManager.state = old_state


func test_encounter_context_filters_pins_and_orients_authored_arenas() -> void:
	var old_state := SceneManager.state
	var old_room := SceneManager.current_room
	SceneManager.state = GameState.new()
	var room := LdtkRoom.new()
	room.player = Player.new()
	room.player.cell = Vector2i(9, 3)
	SceneManager.current_room = room
	var enemy := OverworldEnemy.new()
	enemy.cell = Vector2i(10, 3)
	var encounter := EncounterData.new()
	encounter.id = "arena_test"
	encounter.biome = "forest"
	encounter.arena_tags = PackedStringArray(["glade"])
	enemy.encounter = encounter
	var filtered := SceneManager._select_authored_arena(enemy)
	eq(filtered.get("id"), "forest_open_glade",
			"encounter tags restrict a forest selection to its matching template")
	var filtered_visual := filtered.get("visual") as Node2D
	if filtered_visual != null:
		filtered_visual.free()
	SceneManager.state = GameState.new()
	encounter.arena_tags = PackedStringArray()
	encounter.fixed_arena_id = "forest_old_growth_maze"
	room.player.cell = Vector2i(11, 3)
	var fixed := SceneManager._select_authored_arena(enemy)
	eq(fixed.get("id"), "forest_old_growth_maze",
			"fixed boss-style arena override wins over the weighted bag")
	eq(fixed["party_zone"][0], Vector2i(15, 1),
			"opposite contact side moves the party onto the authored right deployment")
	not_ok(fixed.get("mirrored", true),
			"a non-mirror-safe template keeps its authored topology when sides swap")
	var fixed_visual := fixed.get("visual") as Node2D
	if fixed_visual != null:
		fixed_visual.free()
	SceneManager.current_room = old_room
	SceneManager.state = old_state
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


func test_combat_view_uses_runtime_animated_sprites() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	var buddy := CombatUnit.from_character("companion_test",
			_character("companion_test"), 14, 6)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	var c := _scene([hero, buddy], [foe])
	add_child(c)
	for unit in [hero, buddy, foe]:
		var sprite: Node = unit.node.get_node_or_null("RuntimeSprite")
		ok(sprite is AnimatedSprite2D,
				"%s renders as an AnimatedSprite2D" % unit.display_name)
	c.queue_free()
	await get_tree().process_frame


func test_move_range_uses_a_visible_blue_highlight_panel() -> void:
	var hero := CombatUnit.from_character("hero", _character("hero"), 20, 5)
	var foe := CombatUnit.from_enemy(_slime(), 0)
	var c := _scene([hero], [foe])
	add_child(c)
	c._show_highlights([hero.cell], CombatScene.MOVE_HIGHLIGHT_FILL)
	eq(c.highlight_root.get_child_count(), 1, "one reachable cell gets one range panel")
	var highlight := c.highlight_root.get_child(0) as Panel
	var style := highlight.get_theme_stylebox("panel") as StyleBoxFlat
	ok(style.bg_color.b > style.bg_color.r,
			"move range fill is visibly blue, not a muted texture tint")
	ok(style.border_color.b > style.border_color.r,
			"move range border stays blue against green terrain")
	c.queue_free()
	await get_tree().process_frame


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
