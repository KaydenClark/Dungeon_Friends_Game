extends "res://tests/gd_test.gd"
## Unit tests for the D-004/D-008 checkpoint respawn (T-041). The contract:
## defeat inside the dungeon respawns at the hub entrance on a FRESH hub
## (puzzle + enemies reset per T-048) with the suspended forest kept intact
## beneath; defeat outside respawns by the healer in the SAME forest
## instance; inventory is always kept, XP pays the (clamped) penalty, and
## the party comes back at full HP. Save files are never touched - nothing
## here goes near SaveManager. ui_layer stays null so dialogue prints
## instead of awaiting input.

var _world: Node2D
var _combat: Node2D
var _transition: CanvasLayer


func _setup() -> void:
	_world = Node2D.new()
	_combat = Node2D.new()
	_transition = CanvasLayer.new()
	for n in [_world, _combat, _transition]:
		add_child(n)
	SceneManager.register_main(_world, _combat, CanvasLayer.new(), _transition)
	SceneManager.ui_layer.queue_free()
	SceneManager.ui_layer = null   # dialogue must not await input headless
	SceneManager.reset_session_state()


func _teardown() -> void:
	SceneManager.current_room = null
	SceneManager.room_stack.clear()
	SceneManager.reset_session_state()
	for n in [_world, _combat, _transition]:
		n.free()
	SceneManager.world_container = null
	SceneManager.combat_container = null
	SceneManager.transition_layer = null
	SceneManager.fade_rect = null


## Mirror enter_room()'s bookkeeping without its fades: suspend the current
## room onto the stack and make `room` current.
func _push_room(room: Node2D) -> void:
	SceneManager.current_room.visible = false
	SceneManager.room_stack.append(SceneManager.current_room)
	SceneManager.current_room = room
	SceneManager.world_container.add_child(room)


func test_dungeon_defeat_respawns_at_a_fresh_hub_entrance() -> void:
	_setup()
	var forest: LdtkRoom = MapRegistry.build("forest")
	SceneManager.boot_room(forest)
	_push_room(MapRegistry.build("tutorial_hub"))
	var old_hub: Node2D = SceneManager.current_room
	_push_room(MapRegistry.build("tutorial_pit"))
	SceneManager.add_item("shield")
	SceneManager.hero_hp = 1
	SceneManager.respawn_at_dungeon_entrance()
	var hub: Node2D = SceneManager.current_room
	ok(hub is TutorialHubRoom, "defeat in the dungeon lands in the hub")
	ok(hub != old_hub, "the hub is a FRESH rebuild (puzzles + enemies reset)")
	eq(SceneManager.room_stack.size(), 1, "rooms between were freed")
	ok(SceneManager.room_stack[0] == forest,
			"the suspended forest is kept beneath the hub")
	if hub is TutorialHubRoom:
		eq(hub.player.cell, hub.spawn_cell, "player stands at the hub entrance")
		ok(hub.blocks.size() > 0, "the brick wall is back (fresh build)")
	ok(SceneManager.inventory.has("shield"), "inventory kept on defeat (D-008)")
	_teardown()


func test_dungeon_defeat_without_a_forest_below() -> void:
	# Dev-warp path: defeated in a dungeon room with an empty stack.
	_setup()
	SceneManager.boot_room(MapRegistry.build("tutorial_fight"))
	SceneManager.respawn_at_dungeon_entrance()
	ok(SceneManager.current_room is TutorialHubRoom,
			"still lands at the hub entrance")
	eq(SceneManager.room_stack.size(), 0, "no phantom rooms on the stack")
	_teardown()


func test_forest_defeat_respawns_by_the_healer() -> void:
	_setup()
	var forest: LdtkRoom = MapRegistry.build("forest")
	SceneManager.boot_room(forest)
	SceneManager.add_item("forest_key")
	SceneManager.flags["hub_seen"] = true
	SceneManager.respawn_at_healer()
	ok(SceneManager.current_room == forest,
			"outside defeat keeps the same forest instance")
	var dist: int = absi(forest.player.cell.x - forest.healer.cell.x) \
			+ absi(forest.player.cell.y - forest.healer.cell.y)
	eq(dist, 1, "player respawns beside the healer")
	ok(SceneManager.inventory.has("forest_key"), "inventory kept on defeat")
	ok(SceneManager.flags.get("hub_seen", false),
			"flags are NOT wiped (checkpoints, not restart)")
	_teardown()


func test_defeat_penalty_clamps_xp_and_restores_hp() -> void:
	_setup()
	# This suite pins the V1 FALLBACK defeat rules (D-014 25% penalty); the
	# v2 default keeps XP per D-043 and is pinned in test_finite_progression.
	SceneManager.unified_encounters = false
	SceneManager.total_xp = 15          # level 1, floor 0
	SceneManager.state.party_xp["companion_test"] = 7
	SceneManager.hero_hp = 1
	var lost := SceneManager.apply_defeat_xp_penalty()
	# Kayden's 2026-07-10 tuning: 25% of above-floor progress.
	eq(SceneManager.total_xp, 11, "hero keeps 75% of above-floor XP (15 -> 11)")
	eq(SceneManager.state.party_xp.get("companion_test"), 5,
			"companion pays the same 25% (7 -> 5)")
	eq(lost, 6, "penalty reports the total XP lost across the party")
	SceneManager.restore_party_after_defeat()
	eq(SceneManager.hero_hp, 16,
			"party comes back at 80% HP (hero 20 -> 16; Kayden 2026-07-10)")
	eq(SceneManager.state.party_hp.get("companion_test"), 11,
			"companion at 80% too (14 -> 11)")
	eq(SceneManager.state.party_mp.get("hero"),
			SceneManager.hero_stats.max_mp,
			"MP restored in full (flagged interpretation - no MP economy yet)")
	SceneManager.unified_encounters = true   # restore the production default
	_teardown()
