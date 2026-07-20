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
	SceneManager.unified_encounters = false
	SceneManager.in_encounter = false
	SceneManager.reset_session_state()
	SceneManager.flags = {}


func _enemy_at(room: LdtkRoom, cell: Vector2i) -> OverworldEnemy:
	for enemy in room.enemies:
		if enemy.cell == cell:
			return enemy
	return null


func test_v1_route_stays_default() -> void:
	not_ok(SceneManager.unified_encounters,
			"unified encounters are opt-in until S-012 accepts replacement")


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
