extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()

	var validation = catalog.validate_all_content()
	if not validation.get("ok", false):
		failures.append("catalog validation should pass for seeded content")

	var archetype = catalog.load_archetype("starter_facetwalker")
	if not (archetype is Dictionary) or archetype.get("id", "") != "starter_facetwalker":
		failures.append("starter archetype should load successfully")

	var missing_archetype = catalog.load_archetype("missing_archetype")
	if not (missing_archetype is Dictionary) or missing_archetype.get("error", "") != "missing_content":
		failures.append("missing archetype should return deterministic missing_content error")

	var floor = catalog.load_floor_template("tutorial_floor")
	if not (floor is Dictionary) or floor.get("starting_room_id", "") != "tutorial_entry":
		failures.append("tutorial floor should load with expected starting room")

	var room_graph = catalog.load_room_graph("tutorial_rooms")
	if not (room_graph is Dictionary) or (room_graph.get("rooms", []) as Array).size() != 2:
		failures.append("tutorial room graph should load with the seeded rooms")

	var encounter = catalog.load_encounter("tutorial_slime")
	if not (encounter is Dictionary) or encounter.get("enemy_id", "") != "slime_echo":
		failures.append("tutorial encounter should load with its seeded enemy")

	var face_definition = catalog.load_part_definition("strike")
	if not (face_definition is Dictionary) or face_definition.get("family", "") != "attack":
		failures.append("starter face definitions should load through load_part_definition")

	var all_content = catalog.get_all_content()
	if not all_content.has("archetypes") or not all_content.has("floors") or not all_content.has("room_graphs"):
		failures.append("catalog should expose loaded archetypes, floors, and room graphs")

	return failures
