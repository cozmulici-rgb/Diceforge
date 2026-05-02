extends RefCounted

const AppRootScript = preload("res://scripts/app_root.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var app_root = AppRootScript.new()

	var cases := {
		"start_menu": "show_quit_confirm",
		"exploration": "show_return_confirm",
		"combat": "show_return_confirm",
		"reward": "show_return_confirm",
		"forge": "show_return_confirm",
		"progression": "return_to_menu",
		"": "noop",
		"unknown_screen": "noop",
	}

	for kind in cases.keys():
		var expected: String = cases[kind]
		var actual: String = app_root._dispatch_escape_for_screen(kind)
		if actual != expected:
			failures.append(
				"_dispatch_escape_for_screen(\"%s\") expected \"%s\" but got \"%s\""
					% [kind, expected, actual]
			)

	app_root.free()
	return failures
