extends SceneTree

const TEST_SCRIPT_PATHS := [
	"res://tests/test_clamping.gd",
	"res://tests/test_battle_log.gd",
	"res://tests/test_hook_dispatcher.gd",
	"res://tests/test_status_engine.gd",
	"res://tests/test_dice_resolver.gd",
	"res://tests/test_effect_resolver.gd",
	"res://tests/test_escape_to_main_menu.gd",
	"res://tests/test_enemy_ai.gd",
	"res://tests/test_combat_engine.gd",
	"res://tests/test_combat_engine_behavior.gd",
	"res://tests/test_combat_controller.gd",
	"res://tests/test_combat_dice_reorder.gd",
	"res://tests/test_boss_encounter.gd",
	"res://tests/test_content_catalog.gd",
	"res://tests/test_daily_void_mode.gd",
	"res://tests/test_dice_model.gd",
	"res://tests/test_dungeon_generator.gd",
	"res://tests/test_exploration_flow.gd",
	"res://tests/test_forge_assembly.gd",
	"res://tests/test_meta_progression.gd",
	"res://tests/test_modifier_registry.gd",
	"res://tests/test_persistence_service.gd",
	"res://tests/test_reward_flow.gd",
	"res://tests/test_run_session.gd",
]

const PER_TEST_TIMEOUT_MS := 30000

var _failure_count := 0


func _initialize() -> void:
	print("Running Facetbound headless tests")

	for path in TEST_SCRIPT_PATHS:
		var test_name: String = path.get_file().get_basename()
		var script := load(path) as GDScript
		if script == null:
			_failure_count += 1
			push_error("FAIL %s: failed to load script (parse error or missing file)" % test_name)
			continue
		if not script.can_instantiate():
			_failure_count += 1
			push_error("FAIL %s: script cannot be instantiated (compile error)" % test_name)
			continue

		var test_case = script.new()
		if test_case == null:
			_failure_count += 1
			push_error("FAIL %s: script.new() returned null" % test_name)
			continue
		if not test_case.has_method("run"):
			_failure_count += 1
			push_error("FAIL %s: missing run() method" % test_name)
			continue

		var started_ms: int = Time.get_ticks_msec()
		var failures: Array = test_case.run()
		var elapsed_ms: int = Time.get_ticks_msec() - started_ms

		if elapsed_ms > PER_TEST_TIMEOUT_MS:
			_failure_count += 1
			push_error("FAIL %s: exceeded soft timeout (%d ms > %d ms)" % [test_name, elapsed_ms, PER_TEST_TIMEOUT_MS])
			continue

		if failures.is_empty():
			print("PASS %s (%d ms)" % [test_name, elapsed_ms])
			continue

		for failure in failures:
			_failure_count += 1
			push_error("FAIL %s: %s" % [test_name, failure])

	if _failure_count == 0:
		print("All Facetbound tests passed")
	else:
		push_error("%d Facetbound test assertion(s) failed" % _failure_count)

	quit(_failure_count)
