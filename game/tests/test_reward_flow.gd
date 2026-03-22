extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const GameStateCoordinatorScript = preload("res://scripts/core/game_state_coordinator.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var coordinator = GameStateCoordinatorScript.new(catalog)

	var run_session = coordinator.create_run_session("starter_facetwalker")
	if run_session == null or run_session is Dictionary:
		failures.append("reward flow requires a valid run session")
		return failures

	coordinator.enter_room("floor_01_fight")
	coordinator.begin_encounter("tutorial_slime")
	var updated_session = coordinator.apply_encounter_result({
		"outcome": "victory",
		"player_hp_after": 28,
		"encounter_id": "tutorial_slime",
		"room_id": "floor_01_fight",
		"reward_source": {"reward_type": "encounter", "reward_source_id": "tutorial_slime_rewards"},
	})
	if updated_session == null or updated_session is Dictionary:
		failures.append("apply_encounter_result should keep the run session alive on victory")
		return failures

	var reward_flow = coordinator.open_reward_flow({"reward_type": "encounter", "reward_source_id": "tutorial_slime_rewards"})
	if not reward_flow.get("ok", false):
		failures.append("open_reward_flow should resolve a deterministic encounter reward table")
		return failures

	var options: Array = reward_flow.get("available_options", [])
	if options.size() != 3:
		failures.append("tutorial reward flow should expose the seeded reward options")

	var select_result = coordinator.apply_reward_selection(options[0])
	if not select_result.get("ok", false):
		failures.append("apply_reward_selection should add the claimed reward into inventory")
		return failures

	if not (coordinator.current_session.inventory.get("faces", []) as Array).has("heavy_strike"):
		failures.append("claiming the heavy strike reward should add the face into run inventory")

	if not coordinator.can_enter_forge():
		failures.append("the tutorial encounter reward flow should enable forge entry after claiming a spare part")

	var event_flow = coordinator.open_reward_flow({"reward_type": "event", "reward_source_id": "tutorial_shrine"})
	if not event_flow.get("ok", false):
		failures.append("event definitions should resolve through the reward controller path")

	var shop_flow = coordinator.open_reward_flow({"reward_type": "shop", "reward_source_id": "tutorial_vendor"})
	if not shop_flow.get("ok", false):
		failures.append("shop definitions should resolve through the reward controller path")

	return failures
