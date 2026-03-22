extends Node

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")
const StartMenuScene = preload("res://scenes/screens/start_menu.tscn")
const ExplorationScene = preload("res://scenes/screens/exploration_screen.tscn")
const CombatScene = preload("res://scenes/screens/combat_screen.tscn")
const RewardScene = preload("res://scenes/screens/reward_screen.tscn")
const ForgeScene = preload("res://scenes/screens/forge_screen.tscn")
const ProgressionScene = preload("res://scenes/screens/progression_screen.tscn")

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

	var archetypes: Array = _available_archetypes()
	start_menu.configure(
		archetypes,
		game_state_coordinator.get_continue_run_summary(),
		game_state_coordinator.last_recovery_message
	)
	start_menu.run_requested.connect(_on_run_requested)
	start_menu.continue_requested.connect(_on_continue_requested)


func _show_exploration(run_session) -> void:
	_clear_screen_host()

	var exploration_screen = ExplorationScene.instantiate()
	screen_host.add_child(exploration_screen)
	exploration_screen.setup(game_state_coordinator, content_catalog, run_session)
	exploration_screen.session_updated.connect(_on_session_updated)
	exploration_screen.encounter_started.connect(_on_encounter_started)
	hud.show_status(run_session)
	print("Facetbound app root initialized with session %s" % run_session.session_id)


func _show_combat(combat_state) -> void:
	_clear_screen_host()

	var combat_screen = CombatScene.instantiate()
	screen_host.add_child(combat_screen)
	combat_screen.setup(content_catalog, combat_state)
	combat_screen.combat_state_updated.connect(_on_combat_state_updated)
	combat_screen.combat_finished.connect(_on_combat_finished)


func _show_reward_flow(reward_flow_state: Dictionary) -> void:
	_clear_screen_host()

	var reward_screen = RewardScene.instantiate()
	screen_host.add_child(reward_screen)
	reward_screen.setup(reward_flow_state)
	reward_screen.reward_selected.connect(_on_reward_selected)
	hud.show_status(game_state_coordinator.current_session)


func _show_forge_flow() -> void:
	var forge_state = game_state_coordinator.open_forge_flow()
	if not forge_state.get("ok", false):
		var resumed_session = game_state_coordinator.complete_reward_flow()
		if resumed_session != null and resumed_session.has_method("to_dictionary"):
			_show_exploration(resumed_session)
		return

	_clear_screen_host()
	var forge_screen = ForgeScene.instantiate()
	screen_host.add_child(forge_screen)
	forge_screen.setup(game_state_coordinator, forge_state)
	forge_screen.forge_complete.connect(_on_forge_complete)
	hud.show_status(game_state_coordinator.current_session)


func _show_run_complete(run_session) -> void:
	_clear_screen_host()
	var progression_screen = ProgressionScene.instantiate()
	screen_host.add_child(progression_screen)
	progression_screen.configure(run_session.progression_result)
	progression_screen.return_to_menu_requested.connect(_on_return_to_menu_requested)
	hud.show_status(run_session)


func _clear_screen_host() -> void:
	for child in screen_host.get_children():
		child.queue_free()


func _on_run_requested(archetype_id: String) -> void:
	var run_result = game_state_coordinator.create_run_session(archetype_id)
	if run_result != null and not (run_result is Dictionary):
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


func _on_continue_requested(slot_id: String) -> void:
	var load_result = game_state_coordinator.load_run_session(slot_id)
	if not load_result.get("ok", false):
		hud.show_error("Continue failed. Safe defaults restored.")
		_show_start_menu()
		return
	_show_exploration(load_result.get("run_session"))


func _on_session_updated(run_session) -> void:
	hud.show_status(run_session)


func _on_encounter_started(combat_state) -> void:
	_show_combat(combat_state)


func _on_combat_state_updated(_combat_state) -> void:
	hud.show_status(game_state_coordinator.current_session)


func _on_combat_finished(encounter_result: Dictionary) -> void:
	var updated_session = game_state_coordinator.apply_encounter_result(encounter_result)
	if updated_session != null and updated_session.has_method("to_dictionary"):
		if str(encounter_result.get("outcome", "")) == "victory":
			var reward_flow = game_state_coordinator.open_reward_flow(encounter_result.get("reward_source", {}))
			if reward_flow.get("ok", false):
				hud.show_status(updated_session)
				_show_reward_flow(reward_flow)
				return
		if bool(updated_session.run_complete):
			_show_run_complete(updated_session)
			return
		hud.show_status(updated_session)
		_show_exploration(updated_session)
		return

	hud.show_error("Encounter application failed.")


func _on_reward_selected(option_data: Dictionary) -> void:
	var reward_result = game_state_coordinator.apply_reward_selection(option_data)
	if not reward_result.get("ok", false):
		hud.show_error("Reward selection failed.")
		return

	hud.show_status(game_state_coordinator.current_session)
	if game_state_coordinator.can_enter_forge():
		_show_forge_flow()
		return

	var resumed_session = game_state_coordinator.complete_reward_flow()
	if resumed_session != null and resumed_session.has_method("to_dictionary"):
		if bool(resumed_session.run_complete):
			_show_run_complete(resumed_session)
			return
		_show_exploration(resumed_session)


func _on_forge_complete() -> void:
	var resumed_session = game_state_coordinator.complete_reward_flow()
	if resumed_session != null and resumed_session.has_method("to_dictionary"):
		if bool(resumed_session.run_complete):
			hud.show_status(resumed_session)
			_show_run_complete(resumed_session)
			return
		hud.show_status(resumed_session)
		_show_exploration(resumed_session)


func _on_return_to_menu_requested() -> void:
	_show_start_menu()


func _available_archetypes() -> Array:
	var archetypes: Array = []
	for archetype in content_catalog.list_archetypes():
		var archetype_definition: Dictionary = archetype
		if (game_state_coordinator.meta_state.unlocked_archetype_ids as Array).has(str(archetype_definition.get("id", ""))):
			archetypes.append(archetype_definition.duplicate(true))
	return archetypes
