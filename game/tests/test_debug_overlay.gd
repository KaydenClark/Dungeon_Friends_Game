extends "res://tests/gd_test.gd"
## Unit tests for the T-030 dev-tools overlay hooks: hidden by default, grant
## is deduplicated, heal and puzzle-reset delegate to the real SceneManager /
## RoomGrid rules. The windowed F1/keys interaction is Kayden's manual check.


func _overlay() -> DebugOverlay:
	var o := DebugOverlay.new()
	add_child(o)
	return o


func test_panel_hidden_by_default() -> void:
	var o := _overlay()
	not_ok(o.open, "overlay starts closed")
	not_ok(o.panel.visible, "panel not visible until toggled")
	o.queue_free()


func test_grant_item_deduplicates() -> void:
	var saved := SceneManager.inventory
	SceneManager.inventory = PackedStringArray()
	var o := _overlay()
	o.grant_item("chest_key")
	o.grant_item("chest_key")
	var count := 0
	for item in SceneManager.inventory:
		if item == "chest_key":
			count += 1
	eq(count, 1, "granting twice keeps a single copy")
	SceneManager.inventory = saved
	o.queue_free()


func test_heal_hook_uses_real_rule() -> void:
	var saved := SceneManager.hero_hp
	SceneManager.hero_hp = 2
	SceneManager.heal_hero_to_full()
	eq(SceneManager.hero_hp, SceneManager.hero_stats.max_hp,
			"dev heal is the same heal_hero_to_full the healer uses")
	SceneManager.hero_hp = saved


func test_reset_puzzle_delegates_to_room() -> void:
	var o := _overlay()
	var g := RoomGrid.new()
	add_child(g)
	g.setup_grid(6, 6)
	var b := PushableBlock.new()
	g.register(b, Vector2i(2, 2))
	b.try_push(Vector2i.RIGHT)
	b.moving = false
	var prev_room: Node2D = SceneManager.current_room
	SceneManager.current_room = g
	o.reset_puzzle()
	SceneManager.current_room = prev_room
	eq(b.cell, Vector2i(2, 2), "dev reset sends the block back to start")
	g.queue_free()
	o.queue_free()
