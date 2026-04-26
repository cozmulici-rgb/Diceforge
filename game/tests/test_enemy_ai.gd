extends RefCounted

const EnemyAIScript = preload("res://scripts/combat/enemy_ai.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var ai = EnemyAIScript.new()

	var action := ai.select_action({"ai_pattern": [{"action": "attack", "damage": 5, "label": "Strike"}]}, 1)
	if str(action.get("action", "")) != "attack" or int(action.get("damage", -1)) != 5:
		failures.append("single-action pattern should select attack")

	var cycled := {"ai_pattern": [
		{"action": "attack", "damage": 3, "label": "Gel Strike"},
		{"action": "debuff", "status": "poison", "stacks": 2, "duration": 2, "label": "Venom Splash"},
	]}
	if str(ai.select_action(cycled, 2).get("action", "")) != "debuff":
		failures.append("turn 2 should select second pattern entry")
	if str(ai.select_action(cycled, 3).get("action", "")) != "attack":
		failures.append("pattern should wrap by turn index")

	var player_after := ai.resolve_action({"action": "attack", "damage": 7, "label": "Strike"}, {"hp": 20, "max_hp": 20, "block": 3}, {})
	if int(player_after.get("hp", -1)) != 16 or int(player_after.get("block", -1)) != 0:
		failures.append("attack should drain block then hp")

	var poisoned := ai.resolve_action({"action": "debuff", "status": "poison", "stacks": 2, "duration": 3, "label": "Venom"}, {"hp": 20, "max_hp": 20, "block": 0, "statuses": []}, {})
	if (poisoned.get("statuses", []) as Array).size() != 1:
		failures.append("debuff should add one player status")

	return failures
