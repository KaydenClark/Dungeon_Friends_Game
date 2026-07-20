extends "res://tests/gd_test.gd"
## S-009/TK-004 strict red/green suite: the production in-room encounter mode
## seam (D-025/D-036). Encounter entry flips mode inside the SAME room
## instance - no scene change, no zoom, no arena - gating exploration input
## via SceneManager.in_encounter; victory resolves in place, grants the v1
## reward path, and returns to exploration with room, player position,
## camera, and puzzle state untouched. The v1 CombatScene route stays the
## default: the seam only takes over when SceneManager.unified_encounters is
## explicitly enabled (S-012 owns flipping the default with real combat).

const WorldState := preload("res://scripts/world/world_state.gd")
const FIXTURE := "res://assets/levels/entity_test_room.ldtk"


func _make_room() -> LdtkRoom:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	return room


func _teardown(room: LdtkRoom) -> void:
	room.queue_free()
	SceneManager.unified_encounters = true
	SceneManager.in_encounter = false
	SceneManager.reset_session_state()
	SceneManager.flags = {}


func _enemy_at(room: LdtkRoom, cell: Vector2i) -> OverworldEnemy:
	for enemy in room.enemies:
		if enemy.cell == cell:
			return enemy
	return null


func test_unified_route_is_the_default() -> void:
	# S-012/TK-004 (D-042): in-room intent combat is the production route;
	# the v1 arena path stays reachable by flipping the flag false (the
	# slice smoke test pins it so) until the S-004 owner replay accepts.
	ok(SceneManager.unified_encounters,
			"unified in-room encounters are the production default")


func test_entry_gates_input_in_the_same_room() -> void:
	var room := _make_room()
	SceneManager.unified_encounters = true
	var enemy := _enemy_at(room, Vector2i(9, 5))
	var player_cell := room.player.cell
	var camera := room.player.camera
	eq(room.begin_room_encounter(enemy), "", "known live encounter begins")
	eq(room.active_encounter_id, "enc_9_5", "active encounter recorded")
	ok(SceneManager.in_encounter, "exploration input gated (D-036)")
	eq(room.player.cell, player_cell, "player never moves on entry (D-025)")
	eq(room.player.camera, camera, "same camera node - no zoom, no swap")
	ok(is_instance_valid(enemy) and enemy.is_inside_tree(),
			"the enemy stays in the room")
	eq(room.begin_room_encounter(enemy), "already_in_encounter",
			"re-entry fails closed")
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "encounter-mode snapshot has no error")
	if not data.has("error"):
		eq(WorldState.validate(data), "", "encounter-mode snapshot validates")
		eq(data["mode"], "encounter", "snapshot mode is encounter")
		eq(data["active_encounter"], "enc_9_5", "snapshot active id carried")
		eq(data["encounters"]["enc_9_5"]["status"], "active",
				"active encounter status projected")
	_teardown(room)


func test_victory_resolves_in_place_and_preserves_state() -> void:
	var room := _make_room()
	SceneManager.unified_encounters = true
	# Change puzzle state first: push the block left onto the plate.
	var block: PushableBlock = room.blocks[0]
	block.try_push(Vector2i.LEFT)
	eq(block.cell, Vector2i(2, 5), "block pushed onto the plate pre-battle")
	ok(room.door.held_open, "plate-held door open pre-battle")
	var enemy := _enemy_at(room, Vector2i(9, 5))
	var xp_before: int = SceneManager.total_xp
	eq(room.begin_room_encounter(enemy), "", "encounter begins")
	eq(room.resolve_room_encounter(true), "", "victory resolves")
	eq(room.active_encounter_id, "", "no active encounter after victory")
	not_ok(SceneManager.in_encounter, "input gate released")
	ok(SceneManager.total_xp > xp_before, "v1 reward path granted XP")
	ok(_enemy_at(room, Vector2i(9, 5)) == null, "defeated enemy left the room")
	eq(block.cell, Vector2i(2, 5), "pushed block survives the encounter")
	ok(room.door.held_open, "held door survives the encounter")
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "post-victory snapshot has no error")
	if not data.has("error"):
		eq(data["mode"], "exploration", "mode returns to exploration")
		eq(data["encounters"]["enc_9_5"],
				{"status": "resolved", "cells": [Vector2i(9, 5)]},
				"victory resolves the encounter under its stable id (D-028)")
		eq(data["encounters"]["fixture_guardian"]["status"], "unresolved",
				"other encounters untouched")
	_teardown(room)


func test_seam_fails_closed() -> void:
	var room := _make_room()
	SceneManager.unified_encounters = true
	eq(room.resolve_room_encounter(true), "no_active_encounter",
			"resolving outside an encounter fails closed")
	eq(room.begin_room_encounter(null), "unknown_encounter",
			"null enemy fails closed")
	var stray := OverworldEnemy.new()
	eq(room.begin_room_encounter(stray), "unknown_encounter",
			"an enemy without authored identity fails closed")
	stray.free()
	not_ok(SceneManager.in_encounter, "failed entries never gate input")
	_teardown(room)


func test_retreat_resolves_without_rewards_or_defeat() -> void:
	var room := _make_room()
	SceneManager.unified_encounters = true
	var enemy := _enemy_at(room, Vector2i(9, 5))
	var xp_before: int = SceneManager.total_xp
	eq(room.begin_room_encounter(enemy), "", "encounter begins")
	eq(room.resolve_room_encounter(false), "", "non-victory resolution")
	not_ok(SceneManager.in_encounter, "input gate released")
	eq(SceneManager.total_xp, xp_before, "no rewards without victory")
	ok(is_instance_valid(enemy) and enemy.is_inside_tree(),
			"the enemy survives a non-victory resolution")
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	if not data.has("error"):
		eq(data["encounters"]["enc_9_5"]["status"], "unresolved",
				"a non-victory leaves the encounter unresolved")
	_teardown(room)


func test_player_bump_routes_through_the_seam_when_enabled() -> void:
	var room := _make_room()
	SceneManager.unified_encounters = true
	# Teleport the leader beside the enemy and bump it: the seam must start
	# in-room instead of the v1 zoom/arena path.
	room.teleport(room.player, Vector2i(8, 5))
	room.player.try_step(Vector2i.RIGHT)
	eq(room.active_encounter_id, "enc_9_5",
			"bumping an enemy starts the in-room encounter")
	ok(SceneManager.in_encounter, "bump entry gates input")
	eq(room.player.cell, Vector2i(8, 5), "bump never moves the leader")
	eq(room.resolve_room_encounter(true), "", "seam-started encounter resolves")
	_teardown(room)


func test_freed_room_releases_the_input_gate() -> void:
	# TK-004 review F1: load_game frees rooms without an in_encounter guard;
	# a freed room must never strand the global gate.
	var room := _make_room()
	SceneManager.unified_encounters = true
	var enemy := _enemy_at(room, Vector2i(9, 5))
	eq(room.begin_room_encounter(enemy), "", "encounter begins")
	ok(SceneManager.in_encounter, "gate held during the encounter")
	remove_child(room)
	room.free()
	not_ok(SceneManager.in_encounter,
			"freeing a room mid-encounter releases the gate")
	SceneManager.unified_encounters = true
	SceneManager.reset_session_state()
	SceneManager.flags = {}


func test_stale_active_id_fails_closed_in_snapshot() -> void:
	# TK-004 review F2: an active id pointing at a resolved encounter is a
	# seam bug and must refuse the snapshot, not validate.
	var room := _make_room()
	SceneManager.unified_encounters = true
	var enemy := _enemy_at(room, Vector2i(9, 5))
	eq(room.begin_room_encounter(enemy), "", "encounter begins")
	eq(room.resolve_room_encounter(true), "", "victory resolves")
	room.active_encounter_id = "enc_9_5"   # simulate the stale-id bug
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	ok(data.has("error"), "stale active id refuses the snapshot")
	if data.has("error"):
		eq(str(data["error"]), "active_encounter_not_active",
				"the invariant names the seam bug")
	room.active_encounter_id = ""
	_teardown(room)


func test_encounter_deploys_followers_as_occupants() -> void:
	# S-010/TK-004 (D-037): followers snap to legal deployment cells and
	# become real occupying tactical units for the encounter, then return to
	# pass-through on resolution.
	var room := _make_room()
	SceneManager.unified_encounters = true
	var enemy := _enemy_at(room, Vector2i(9, 5))
	eq(room.begin_room_encounter(enemy), "", "encounter begins")
	ok(room.party_deployed, "party deployment applied on entry")
	var follower: PartyFollower = room.party_followers[0]
	eq(room.get_occupant(follower.cell), follower,
			"deployed follower occupies its cell")
	not_ok(room.is_walkable(follower.cell),
			"a deployed follower body-blocks (D-020/D-037)")
	ne(follower.cell, room.player.cell, "deployment cell distinct from leader")
	ne(follower.cell, enemy.cell, "deployment avoids enemy cells")
	var data: Dictionary = WorldState.snapshot_ldtk_room(room)
	not_ok(data.has("error"), "deployed snapshot has no error")
	if not data.has("error"):
		eq(data["actors"]["companion_test"]["cell"], follower.cell,
				"deployed follower actor at its occupied cell")
		eq(data["mode"], "encounter", "snapshot still in encounter mode")
	eq(room.resolve_room_encounter(true), "", "victory resolves")
	not_ok(room.party_deployed, "deployment released on resolution")
	is_null(room.get_occupant(follower.cell),
			"the follower left the occupancy map")
	ok(room.is_walkable(follower.cell), "follower is pass-through again")
	_teardown(room)


func test_solo_roster_needs_no_deployment() -> void:
	SceneManager.reset_session_state()
	SceneManager.flags = {}
	SceneManager.state.party_roster = ["hero"] as Array[String]
	var room := LdtkRoom.new()
	room.level_path = FIXTURE
	add_child(room)
	SceneManager.unified_encounters = true
	eq(room.party_followers.size(), 0, "solo roster spawns no followers")
	var enemy := _enemy_at(room, Vector2i(9, 5))
	eq(room.begin_room_encounter(enemy), "",
			"a solo leader still enters encounters")
	not_ok(room.party_deployed, "nothing to deploy for a solo roster")
	eq(room.resolve_room_encounter(true), "", "solo encounter resolves")
	_teardown(room)


func test_deployment_never_presses_plates() -> void:
	# S-010 review C1: cramped deployment beside the plate corridor must not
	# park a follower on a plate cell - "followers never hold plates" (D-029)
	# survives into encounters.
	# Leader beside the plate with the preferred offset in a wall and the
	# plate as the nearest fallback cell: without the exclusion the planner
	# would deploy the follower onto the plate and press it.
	var room := _make_room()
	SceneManager.unified_encounters = true
	var guardian := _enemy_at(room, Vector2i(5, 6))
	room.teleport(guardian, Vector2i(2, 3))
	room.teleport(room.player, Vector2i(2, 4))
	var plate: PressurePlate = room.plates[0]
	eq(room.begin_room_encounter(guardian), "", "plate-side encounter begins")
	ok(room.party_deployed, "party deployed beside the plate")
	for follower in room.party_followers:
		ne(follower.cell, plate.cell,
				"no follower deploys onto the plate cell")
	not_ok(plate.pressed, "deployment never presses the plate")
	eq(room.resolve_room_encounter(false), "", "encounter releases")
	_teardown(room)
