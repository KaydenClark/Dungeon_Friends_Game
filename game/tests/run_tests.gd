extends Node
## Headless unit-test runner (see /RUNBOOK.md -> Test Coverage Policy). Loads
## each suite listed below, discovers its `test_*` methods reflectively, runs
## them, and prints a per-suite + overall tally. Exits 0 when every check
## passes, 1 otherwise -- so CI/manual verification can gate on the exit code.
##
## Run: Godot --headless --path . tests/run_tests.tscn
## The scene wrapper (run_tests.tscn) ensures the SceneManager autoload loads,
## matching how the real game and the slice smoke test boot.

const SUITES := [
	"res://tests/test_combat_math.gd",
	"res://tests/test_turn_manager.gd",
	"res://tests/test_combat_scene.gd",
	"res://tests/test_arena_validator.gd",
	"res://tests/test_authored_arena_loader.gd",
	"res://tests/test_room_grid.gd",
	"res://tests/test_grid_actor.gd",
	"res://tests/test_data_resources.gd",
	"res://tests/test_item_data.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_dialogue_box.gd",
	"res://tests/test_overworld_enemy.gd",
	"res://tests/test_scene_manager.gd",
	"res://tests/test_game_state.gd",
	"res://tests/test_save_manager.gd",
	"res://tests/test_arena_selector.gd",
	"res://tests/test_map_registry.gd",
	"res://tests/test_load_flow.gd",
	"res://tests/test_defeat_respawn.gd",
	"res://tests/test_enemy_ai.gd",
	"res://tests/test_dialogue_cooldown.gd",
	"res://tests/test_player_movement.gd",
	"res://tests/test_pushable_block.gd",
	"res://tests/test_pressure_plate.gd",
	"res://tests/test_jump.gd",
	"res://tests/test_pit_fall.gd",
	"res://tests/test_chest.gd",
	"res://tests/test_ldtk_pipeline.gd",
	"res://tests/test_tutorial_softlock.gd",
	"res://tests/test_debug_overlay.gd",
	"res://tests/test_kenney_manifest.gd",
	"res://tests/test_input_prompts.gd",
	"res://tests/test_intent_logic.gd",
]


func _ready() -> void:
	var total_checks := 0
	var total_failures: Array[String] = []
	var suites_run := 0
	var tests_run := 0

	print("UNIT TESTS: begin")
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			# can_instantiate() also catches "loaded but failed to compile" -
			# without it, script.new() returns null and the crash below would
			# abort _ready() before quit(), hanging the process forever.
			total_failures.append("%s: suite failed to load/compile" % path)
			print("  SUITE LOAD FAILED: ", path)
			continue
		var suite: Node = script.new()
		add_child(suite)
		suites_run += 1
		var suite_name: String = path.get_file().get_basename()

		var method_names: Array[String] = []
		for m in suite.get_method_list():
			if m.name.begins_with("test_"):
				method_names.append(m.name)
		method_names.sort()   # stable, alphabetical order

		for m_name in method_names:
			suite.set_context("%s.%s" % [suite_name, m_name])
			# await handles both plain and coroutine test methods (the timing
			# suites await real timers); a synchronous test just returns at once.
			await suite.call(m_name)
			tests_run += 1

		total_checks += suite.checks
		for f in suite.failures:
			total_failures.append(f)
		var status := "ok" if suite.failures.is_empty() else "FAIL"
		print("  [%s] %s (%d checks, %d failed)"
				% [status, suite_name, suite.checks, suite.failures.size()])
		suite.queue_free()

	print("UNIT TESTS: %d suites, %d tests, %d checks, %d failed"
			% [suites_run, tests_run, total_checks, total_failures.size()])
	if total_failures.is_empty():
		print("UNIT TESTS: PASS")
		get_tree().quit(0)
	else:
		print("UNIT TESTS: FAIL")
		for f in total_failures:
			print("  failed: ", f)
		get_tree().quit(1)
