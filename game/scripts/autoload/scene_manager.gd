extends Node
## The project's one and only autoload (locked architecture decision, see
## /BLUEPRINT.md -> Architecture). Owns transient session state (containers,
## hero state, inventory, flags) and orchestrates the overworld <-> combat
## transition with SceneManager context passing: the overworld is paused and
## hidden (never freed), so the player returns to the exact pre-combat
## position. The fade transition is a placeholder for the eventual
## camera-zoom-into-the-encounter treatment (see BLUEPRINT.md Design
## Decisions) - same context-passing pattern, different animation.
##
## Full GameState/SaveData Resources arrive in Phase 3; until then the small
## amount of session state below lives directly on this node.

signal encounter_finished(victory: bool)

var world_container: Node2D
var combat_container: Node2D
var ui_layer: CanvasLayer
var transition_layer: CanvasLayer
var fade_rect: ColorRect

var rng := RandomNumberGenerator.new()
## When true (used by the headless smoke test), combat auto-plays with tiny
## waits and menu selection is skipped.
var auto_combat := false

var hero_stats: CharacterStats
var hero_hp := 0
var inventory := PackedStringArray()
var total_xp := 0
var flags := {}

var ui_busy := false
## Set when a dialogue closes. The player polls interact each frame, so without
## this the same keypress that closes a box re-opens it on the next frame.
var last_ui_close_ms := 0
var in_encounter := false
var current_dialogue: DialogueBox


func _ready() -> void:
	rng.randomize()
	hero_stats = load("res://data/characters/hero.tres")
	if hero_stats:
		hero_hp = hero_stats.max_hp
	print("SceneManager ready.")


## Called by main.gd so this autoload can reach the containers regardless of
## which scene is the root (main game, dev spikes, smoke test).
func register_main(world: Node2D, combat: Node2D, ui: CanvasLayer,
		transition: CanvasLayer) -> void:
	world_container = world
	combat_container = combat
	ui_layer = ui
	transition_layer = transition
	transition_layer.layer = 100
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_layer.add_child(fade_rect)


func show_dialogue(lines: PackedStringArray) -> void:
	if ui_layer == null:
		for l in lines:
			print("[dialogue] ", l)
		return
	while ui_busy:
		await get_tree().process_frame
	ui_busy = true
	var box := DialogueBox.new()
	current_dialogue = box
	ui_layer.add_child(box)
	box.open(lines)
	await box.finished
	current_dialogue = null
	box.queue_free()
	ui_busy = false
	last_ui_close_ms = Time.get_ticks_msec()


func start_encounter(enemy: OverworldEnemy) -> void:
	if in_encounter or world_container == null:
		return
	in_encounter = true
	await _fade_to(1.0)
	world_container.visible = false
	world_container.process_mode = Node.PROCESS_MODE_DISABLED
	var combat := CombatScene.new()
	combat.setup(hero_stats, hero_hp, enemy.stats, rng, auto_combat)
	combat_container.add_child(combat)
	await _fade_to(0.0)
	var result: Array = await combat.finished
	var victory: bool = result[0]
	hero_hp = result[1]
	await _fade_to(1.0)
	combat.queue_free()
	world_container.visible = true
	world_container.process_mode = Node.PROCESS_MODE_INHERIT
	await _fade_to(0.0)
	if victory:
		var msg := apply_victory_rewards(enemy.stats)
		enemy.defeated()
		in_encounter = false
		encounter_finished.emit(true)
		await show_dialogue([msg])
	else:
		heal_hero_to_full()
		in_encounter = false
		encounter_finished.emit(false)
		await show_dialogue([
			"You were defeated...",
			"You wake up back in the forest, restored.",
		])


## Grant XP and loot for a defeated enemy and return the victory banner text.
## Loot is de-duplicated (you never pick up a second identical key). Extracted
## from start_encounter so the reward rules can be unit tested without running
## a whole battle (see /RUNBOOK.md -> Unit tests).
func apply_victory_rewards(enemy_stats: EnemyStats) -> String:
	total_xp += enemy_stats.xp_reward
	var drops: PackedStringArray = enemy_stats.loot_table
	for item in drops:
		if not inventory.has(item):
			inventory.append(item)
	var msg := "Victory! Gained %d XP." % enemy_stats.xp_reward
	if drops.size() > 0:
		msg += " The %s dropped: %s!" % [enemy_stats.display_name, ", ".join(drops)]
	return msg


## Restore the hero to full HP. Shared by the healer NPC and the post-defeat
## recovery so both apply the exact same rule.
func heal_hero_to_full() -> void:
	if hero_stats:
		hero_hp = hero_stats.max_hp


func _fade_to(alpha: float) -> void:
	if fade_rect == null:
		return
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", alpha, 0.02 if auto_combat else 0.3)
	await tw.finished
