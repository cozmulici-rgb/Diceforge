extends SceneTree

const TEST_SCRIPTS := [
	preload("res://tests/test_content_catalog.gd"),
	preload("res://tests/test_exploration_flow.gd"),
	preload("res://tests/test_run_session.gd"),
]

var _failure_count := 0


func _initialize() -> void:
	print("Running Facetbound headless tests")

	for script in TEST_SCRIPTS:
		var test_case = script.new()
		var test_name = script.resource_path.get_file().get_basename()
		var failures: Array = test_case.run()

		if failures.is_empty():
			print("PASS %s" % test_name)
			continue

		for failure in failures:
			_failure_count += 1
			push_error("FAIL %s: %s" % [test_name, failure])

	if _failure_count == 0:
		print("All Facetbound tests passed")
	else:
		push_error("%d Facetbound test assertion(s) failed" % _failure_count)

	quit(_failure_count)
