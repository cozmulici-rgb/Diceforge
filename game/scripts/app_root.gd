extends Node

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")
const StartMenuScene = preload("res://scenes/screens/start_menu.tscn")
const ExplorationScene = preload("res://scenes/screens/exploration_screen.tscn")

@onready var hud = $HUD
@onready var screen_host = $ScreenHost

var content_catalog
var game_state_coordinator


func _ready() -> void:
	content_catalog = ContentCatalogScript.new()
	game_state_coordinator = GameStateCoordinatorScript.new(content_catalog)
	hud.show_error("Select an archetype to begin.")
	_show_start_menu()


func _show_start_menu() -> void:
	_clear_screen_host()

	var start_menu = StartMenuScene.instantiate()
	screen_host.add_child(start_menu)

	var archetypes: Array = content_catalog.list_archetypes()
	start_menu.configure(archetypes)
	start_menu.run_requested.connect(_on_run_requested)


func _show_exploration(run_session) -> void:
	_clear_screen_host()

	var exploration_screen = ExplorationScene.instantiate()
	screen_host.add_child(exploration_screen)
	exploration_screen.setup(game_state_coordinator, content_catalog, run_session)
	exploration_screen.session_updated.connect(_on_session_updated)
	hud.show_status(run_session)
	print("Facetbound app root initialized with session %s" % run_session.session_id)


func _clear_screen_host() -> void:
	for child in screen_host.get_children():
		child.queue_free()


func _on_run_requested(archetype_id: String) -> void:
	var run_result = game_state_coordinator.create_run_session(archetype_id)
	if run_result != null and run_result.has_method("to_dictionary"):
		_show_exploration(run_result)
		return

	var message := "unknown error"
	if run_result is Dictionary:
		if run_result.has("errors"):
			message = ", ".join(run_result.get("errors", []))
		elif run_result.has("error"):
			message = str(run_result["error"])

	hud.show_error(message)
	push_error("App root failed to create run: %s" % message)


func _on_session_updated(run_session) -> void:
	hud.show_status(run_session)
