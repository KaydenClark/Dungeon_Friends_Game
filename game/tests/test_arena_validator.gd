extends "res://tests/gd_test.gd"
## T-075: negative fixtures exercise the same pure arena validator used by the
## gallery, so bad LDtk authoring cannot reach a real encounter unnoticed.


func _valid_arena() -> Dictionary:
	return {
		"id": "fixture",
		"w": 17,
		"h": 7,
		"blocked": [],
		"party_zone": [Vector2i(1, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)],
		"enemy_zone": [Vector2i(15, 1), Vector2i(14, 2), Vector2i(14, 3), Vector2i(14, 4)],
		"biome": "forest",
		"tags": ["forest", "outdoor"],
		"tier": "mid",
		"weight": 2,
	}


func _has(errors: Array[String], phrase: String) -> bool:
	for error in errors:
		if error.contains(phrase):
			return true
	return false


func test_valid_four_by_four_arena_passes() -> void:
	eq(ArenaValidator.validate(_valid_arena()).size(), 0,
			"valid 17x7 forest 4v4 arena passes")


func test_blocked_or_duplicate_deployment_is_rejected() -> void:
	var arena := _valid_arena()
	arena["blocked"] = [Vector2i(1, 1)]
	var errors := ArenaValidator.validate(arena)
	ok(_has(errors, "PartyDeployment cell (1, 1) is blocked"),
			"blocked party deployment reports the precise authoring error")
	arena = _valid_arena()
	arena["enemy_zone"][3] = Vector2i(14, 3)
	errors = ArenaValidator.validate(arena)
	ok(_has(errors, "EnemyDeployment contains a duplicate"),
			"duplicate enemy deployment is rejected")


func test_disconnected_sides_are_rejected() -> void:
	var arena := _valid_arena()
	var wall: Array[Vector2i] = []
	for y in 7:
		wall.append(Vector2i(8, y))
	arena["blocked"] = wall
	var errors := ArenaValidator.validate(arena)
	ok(_has(errors, "EnemyDeployment has a disconnected"),
			"full terrain wall cannot isolate the enemy deployment side")


func test_capacity_hero_exit_and_cover_budget_are_rejected() -> void:
	var arena := _valid_arena()
	arena["party_zone"] = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(2, 3)]
	var errors := ArenaValidator.validate(arena)
	ok(_has(errors, "needs at least 4 legal cells"),
			"party side needs enough cells for 4v4")
	arena = _valid_arena()
	arena["party_zone"] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]
	errors = ArenaValidator.validate(arena)
	ok(_has(errors, "Hero deployment has fewer than two"),
			"ally collision cannot trap Hero before the first turn")
	arena = _valid_arena()
	arena["tier"] = "empty"
	arena["blocked"] = [Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)]
	errors = ArenaValidator.validate(arena)
	ok(_has(errors, "cover budget"), "empty arenas allow at most two obstacles")


func test_invalid_metadata_is_rejected() -> void:
	var arena := _valid_arena()
	arena["id"] = ""
	arena["tier"] = "bossy"
	arena["weight"] = 0
	arena["biome"] = ""
	var errors := ArenaValidator.validate(arena)
	ok(_has(errors, "Arena id is required"), "stable id required")
	ok(_has(errors, "tier must be"), "known tier required")
	ok(_has(errors, "weight must be positive"), "positive weight required")
	ok(_has(errors, "biome is required"), "biome required")
