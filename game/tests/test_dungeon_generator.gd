extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const DungeonGeneratorScript = preload("res://scripts/exploration/dungeon_generator.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var generator = DungeonGeneratorScript.new(catalog)

	var floor_state = generator.generate_floor("floor_01", 101, null)
	if floor_state == null or floor_state is Dictionary:
		failures.append("generate_floor should produce a floor state for a valid template")
		return failures

	if not generator.is_boss_path_reachable(floor_state):
		failures.append("generated floor graphs should always contain a reachable boss path")

	var reachable_rooms = generator.list_reachable_rooms(floor_state, "floor_01_start")
	if not reachable_rooms.has("floor_01_boss"):
		failures.append("reachable room listing should include the boss room from the start")

	return failures
