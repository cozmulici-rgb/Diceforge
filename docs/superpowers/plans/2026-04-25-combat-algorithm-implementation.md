# Combat Algorithm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the full combat algorithm from `docs/design/combat-algorithm.md` as a new `CombatEngine` that sits alongside the existing prototype and eventually replaces it.

**Architecture:** A set of focused GDScript modules (CombatEngine, DiceResolver, EffectResolver, EnemyAI, BattleLog, HookDispatcher, StatusEngine) wired together and exercised by deterministic headless tests. The existing `CombatController` / `CombatState` prototype stays untouched until Stage 11, where `CombatEngine` is plugged into it via delegation.

**Tech Stack:** Godot 4.3 GDScript, headless test runner (`make test`), Docker, JSON content files.

---

## Context for implementers

- **Run tests:** `make test` (Docker). Tests live in `game/tests/test_*.gd`, registered in `game/tests/test_runner.gd` `TEST_SCRIPTS` array.
- **Test pattern:** Each test file `extends RefCounted`, has `func run() -> Array[String]` that returns failure messages. Empty array = pass.
- **Content loaded via:** `ContentCatalog` in `game/scripts/content/content_catalog.gd`.
- **Existing combat scripts:** `game/scripts/combat/` — do not modify them until Stage 11.
- **Spec reference:** `docs/design/combat-algorithm.md` (§ numbers below refer to sections there).

---

## File Map

**New files to create:**

| File | Responsibility |
|------|---------------|
| `game/scripts/combat/clamping.gd` | §2.1 clamping helpers (hp, block, energy, stacks) |
| `game/scripts/combat/battle_log.gd` | Monotonic step_index log per §6.1 |
| `game/scripts/combat/hook_dispatcher.gd` | Collect + fire hooks by timing key with priority order per §4 |
| `game/scripts/combat/status_engine.gd` | Tick statuses at timing windows, decrement, remove at 0 per §5 |
| `game/scripts/combat/dice_resolver.gd` | Roll dice, apply on_roll hooks, reroll per §3.3 |
| `game/scripts/combat/effect_resolver.gd` | All face effects (damage/block/heal/burn/poison/freeze/reroll/amplify/utility) per §3.5 |
| `game/scripts/combat/enemy_ai.gd` | Select actions from ai_pattern per §3.8 |
| `game/scripts/combat/autoplay_heuristic.gd` | Build resolution_queue per §7 priority order |
| `game/scripts/combat/combat_engine.gd` | Orchestrates §3.1–§3.12, owns BattleState |
| `game/tests/test_clamping.gd` | Clamping tests |
| `game/tests/test_battle_log.gd` | BattleLog tests |
| `game/tests/test_hook_dispatcher.gd` | HookDispatcher tests |
| `game/tests/test_status_engine.gd` | StatusEngine tests |
| `game/tests/test_dice_resolver.gd` | DiceResolver tests |
| `game/tests/test_effect_resolver.gd` | EffectResolver tests |
| `game/tests/test_enemy_ai.gd` | EnemyAI tests |
| `game/tests/test_combat_engine.gd` | Full-loop integration tests |

**Content files to extend (not replace — add fields):**

| File | Change |
|------|--------|
| `game/content/dice/faces.json` | Add `effect`, `value`, `energy_cost` to each face |
| `game/content/dice/cores.json` | New — blank_core and ember_core definitions |
| `game/content/dice/runes.json` | Add `hooks` to ember_rune |
| `game/content/enemies/tutorial_enemies.json` | Add `ai_pattern` to slime_echo |
| `game/content/enemies/bosses.json` | Add `ai_pattern` to both phases of shard_overseer and final_warden_core |
| `game/content/archetypes/starter_archetypes.json` | Add `energy`, `energy_regen`, `max_hp` to player_state |

**Files to modify (Stage 11 only):**

| File | Change |
|------|--------|
| `game/tests/test_runner.gd` | Register new test files per stage |
| `game/scripts/combat/combat_controller.gd` | Delegate `begin_encounter`/`resolve_player_turn`/`resolve_enemy_turn` to CombatEngine |

---

## Stage 1 — Clamping helpers

**Files:**
- Create: `game/scripts/combat/clamping.gd`
- Create: `game/tests/test_clamping.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# game/tests/test_clamping.gd
extends RefCounted

const ClampingScript = preload("res://scripts/combat/clamping.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var c = ClampingScript.new()

	# hp: clamped to [0, max_hp]
	if c.clamp_hp(50, 30) != 30:
		failures.append("clamp_hp should cap at max_hp")
	if c.clamp_hp(-5, 30) != 0:
		failures.append("clamp_hp should floor at 0")
	if c.clamp_hp(15, 30) != 15:
		failures.append("clamp_hp should pass through valid values")

	# block: clamped to [0, +inf)
	if c.clamp_block(-3) != 0:
		failures.append("clamp_block should floor at 0")
	if c.clamp_block(10) != 10:
		failures.append("clamp_block should pass through positive values")

	# energy: clamped to [0, +inf)
	if c.clamp_energy(-1) != 0:
		failures.append("clamp_energy should floor at 0")
	if c.clamp_energy(5) != 5:
		failures.append("clamp_energy should pass through positive values")

	# stacks/duration: clamped to [0, +inf)
	if c.clamp_stacks(-2) != 0:
		failures.append("clamp_stacks should floor at 0")
	if c.clamp_stacks(3) != 3:
		failures.append("clamp_stacks should pass through positive values")

	# damage application: block absorbed first, then hp
	var result = c.apply_damage_to_entity({"hp": 20, "max_hp": 30, "block": 5}, 8)
	if result.get("block", -1) != 0:
		failures.append("apply_damage_to_entity should reduce block to 0 when damage exceeds it")
	if result.get("hp", -1) != 17:
		failures.append("apply_damage_to_entity should apply remaining 3 damage to hp (20 - 3 = 17)")

	var result_blocked = c.apply_damage_to_entity({"hp": 20, "max_hp": 30, "block": 10}, 5)
	if result_blocked.get("block", -1) != 5:
		failures.append("apply_damage_to_entity should reduce block by full damage when block absorbs all")
	if result_blocked.get("hp", -1) != 20:
		failures.append("apply_damage_to_entity should leave hp unchanged when block fully absorbs damage")

	return failures
```

- [ ] **Step 2: Register test and run to see it fail**

In `game/tests/test_runner.gd`, add to `TEST_SCRIPTS`:
```gdscript
preload("res://tests/test_clamping.gd"),
```

Run: `make test`
Expected: FAIL — `res://scripts/combat/clamping.gd: file not found`

- [ ] **Step 3: Write minimal implementation**

```gdscript
# game/scripts/combat/clamping.gd
class_name Clamping
extends RefCounted


func clamp_hp(hp: int, max_hp: int) -> int:
	return clampi(hp, 0, max_hp)


func clamp_block(block: int) -> int:
	return maxi(block, 0)


func clamp_energy(energy: int) -> int:
	return maxi(energy, 0)


func clamp_stacks(stacks: int) -> int:
	return maxi(stacks, 0)


func apply_damage_to_entity(entity: Dictionary, damage: int) -> Dictionary:
	var result := entity.duplicate(true)
	var block := int(result.get("block", 0))
	var hp := int(result.get("hp", 0))
	var max_hp := int(result.get("max_hp", hp))

	var absorbed := mini(block, damage)
	var remaining := damage - absorbed

	result["block"] = clamp_block(block - absorbed)
	result["hp"] = clamp_hp(hp - remaining, max_hp)
	return result
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test`
Expected: `PASS test_clamping`

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/clamping.gd game/tests/test_clamping.gd game/tests/test_runner.gd
git commit -m "feat: add §2.1 clamping helpers with damage absorption"
```

---

## Stage 2 — BattleLog

**Files:**
- Create: `game/scripts/combat/battle_log.gd`
- Create: `game/tests/test_battle_log.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# game/tests/test_battle_log.gd
extends RefCounted

const BattleLogScript = preload("res://scripts/combat/battle_log.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var log = BattleLogScript.new()

	log.record({
		"turn": 1,
		"step_kind": "roll",
		"die_id": "d_strike_01",
		"rolled_value": 4,
		"resolved_face": "Strike",
		"family": "attack",
		"effect": "damage",
		"base_value": 8,
		"modifiers_applied": [],
		"outcome": "rolled",
		"rerolled_from": null,
	})

	log.record({
		"turn": 1,
		"step_kind": "resolution",
		"die_id": "d_strike_01",
		"rolled_value": 4,
		"resolved_face": "Strike",
		"family": "attack",
		"effect": "damage",
		"base_value": 8,
		"modifiers_applied": [],
		"outcome": "8 damage to enemy",
		"rerolled_from": null,
	})

	var entries := log.get_entries()
	if entries.size() != 2:
		failures.append("BattleLog should have 2 entries after 2 records")

	if int(entries[0].get("step_index", -1)) != 0:
		failures.append("first entry should have step_index 0")

	if int(entries[1].get("step_index", -1)) != 1:
		failures.append("second entry should have step_index 1, got %d" % int(entries[1].get("step_index", -1)))

	# Record a reroll and verify rerolled_from linkage
	log.record({
		"turn": 1,
		"step_kind": "roll",
		"die_id": "d_strike_01",
		"rolled_value": 6,
		"resolved_face": "Heavy Strike",
		"family": "attack",
		"effect": "damage",
		"base_value": 18,
		"modifiers_applied": [],
		"outcome": "rerolled",
		"rerolled_from": 0,
	})

	var reroll_entry := log.get_entries()[2]
	if int(reroll_entry.get("step_index", -1)) != 2:
		failures.append("reroll entry should have step_index 2")
	if int(reroll_entry.get("rerolled_from", -1)) != 0:
		failures.append("reroll entry should reference prior step_index 0")

	var summary := log.get_entries_for_turn(1)
	if summary.size() != 3:
		failures.append("get_entries_for_turn should return all entries for turn 1")

	return failures
```

- [ ] **Step 2: Register test and run to fail**

Add to `TEST_SCRIPTS` in `game/tests/test_runner.gd`:
```gdscript
preload("res://tests/test_battle_log.gd"),
```

Run: `make test`
Expected: FAIL — file not found

- [ ] **Step 3: Implement BattleLog**

```gdscript
# game/scripts/combat/battle_log.gd
class_name BattleLog
extends RefCounted

var _entries: Array = []
var _step_index: int = 0


func record(entry_data: Dictionary) -> void:
	var entry := entry_data.duplicate(true)
	entry["step_index"] = _step_index
	_step_index += 1
	_entries.append(entry)


func get_entries() -> Array:
	return _entries.duplicate(true)


func get_entries_for_turn(turn: int) -> Array:
	var result: Array = []
	for entry in _entries:
		if int((entry as Dictionary).get("turn", -1)) == turn:
			result.append((entry as Dictionary).duplicate(true))
	return result


func current_step_index() -> int:
	return _step_index
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test`
Expected: `PASS test_battle_log`

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/battle_log.gd game/tests/test_battle_log.gd game/tests/test_runner.gd
git commit -m "feat: add BattleLog with monotonic step_index per §6.1"
```

---

## Stage 3 — HookDispatcher

Implements §4 timing windows and priority ordering (passive → triggered → optional).

**Files:**
- Create: `game/scripts/combat/hook_dispatcher.gd`
- Create: `game/tests/test_hook_dispatcher.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# game/tests/test_hook_dispatcher.gd
extends RefCounted

const HookDispatcherScript = preload("res://scripts/combat/hook_dispatcher.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var dispatcher = HookDispatcherScript.new()

	# Build a set of hook descriptors (simulating what cores/runes carry)
	var hooks := [
		{
			"timing": "on_resolution",
			"priority": "triggered",
			"type": "apply_status",
			"target": "enemy",
			"status": "burn",
			"stacks": 1,
			"source": "ember_rune",
		},
		{
			"timing": "on_resolution",
			"priority": "passive",
			"type": "damage_bonus",
			"value": 2,
			"source": "power_core",
		},
		{
			"timing": "on_roll",
			"priority": "triggered",
			"type": "apply_status",
			"target": "enemy",
			"status": "burn",
			"stacks": 1,
			"source": "ember_core",
		},
	]

	# collect_hooks_for_timing returns only hooks with matching timing key
	var on_resolution_hooks := dispatcher.collect_hooks_for_timing(hooks, "on_resolution")
	if on_resolution_hooks.size() != 2:
		failures.append("collect_hooks_for_timing should return 2 on_resolution hooks, got %d" % on_resolution_hooks.size())

	var on_roll_hooks := dispatcher.collect_hooks_for_timing(hooks, "on_roll")
	if on_roll_hooks.size() != 1:
		failures.append("collect_hooks_for_timing should return 1 on_roll hook")

	# sort_by_priority: passive < triggered < optional
	var sorted := dispatcher.sort_by_priority(on_resolution_hooks)
	if sorted.size() != 2:
		failures.append("sort_by_priority should preserve all entries")
	if str(sorted[0].get("priority", "")) != "passive":
		failures.append("first sorted hook should be passive, got %s" % str(sorted[0].get("priority", "")))
	if str(sorted[1].get("priority", "")) != "triggered":
		failures.append("second sorted hook should be triggered, got %s" % str(sorted[1].get("priority", "")))

	# valid timing keys
	var valid := dispatcher.valid_timing_keys()
	if not valid.has("battle_start"):
		failures.append("valid_timing_keys should include battle_start")
	if not valid.has("on_resolution"):
		failures.append("valid_timing_keys should include on_resolution")
	if not valid.has("phase_start"):
		failures.append("valid_timing_keys should include phase_start")

	return failures
```

- [ ] **Step 2: Register test and run to fail**

Add to `TEST_SCRIPTS`:
```gdscript
preload("res://tests/test_hook_dispatcher.gd"),
```

Run: `make test`
Expected: FAIL — file not found

- [ ] **Step 3: Implement HookDispatcher**

```gdscript
# game/scripts/combat/hook_dispatcher.gd
class_name HookDispatcher
extends RefCounted

const PRIORITY_ORDER := ["passive", "triggered", "optional"]

const VALID_TIMING_KEYS := [
	"battle_start",
	"player_turn_start",
	"on_roll",
	"pre_resolution",
	"on_resolution",
	"player_turn_end",
	"enemy_turn_start",
	"enemy_action",
	"enemy_turn_end",
	"phase_end",
	"phase_start",
	"battle_end",
]


func collect_hooks_for_timing(hooks: Array, timing_key: String) -> Array:
	var result: Array = []
	for hook in hooks:
		if str((hook as Dictionary).get("timing", "")) == timing_key:
			result.append((hook as Dictionary).duplicate(true))
	return result


func sort_by_priority(hooks: Array) -> Array:
	var sorted := hooks.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_idx := PRIORITY_ORDER.find(str(a.get("priority", "triggered")))
		var b_idx := PRIORITY_ORDER.find(str(b.get("priority", "triggered")))
		if a_idx == -1:
			a_idx = 1
		if b_idx == -1:
			b_idx = 1
		return a_idx < b_idx
	)
	return sorted


func collect_and_sort(hooks: Array, timing_key: String) -> Array:
	return sort_by_priority(collect_hooks_for_timing(hooks, timing_key))


func valid_timing_keys() -> Array:
	return VALID_TIMING_KEYS.duplicate()
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test`
Expected: `PASS test_hook_dispatcher`

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/hook_dispatcher.gd game/tests/test_hook_dispatcher.gd game/tests/test_runner.gd
git commit -m "feat: add HookDispatcher with §4 timing windows and priority ordering"
```

---

## Stage 4 — StatusEngine

Implements §5 status ticking: tick at declared timing window, decrement, remove at zero.

**Files:**
- Create: `game/scripts/combat/status_engine.gd`
- Create: `game/tests/test_status_engine.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# game/tests/test_status_engine.gd
extends RefCounted

const StatusEngineScript = preload("res://scripts/combat/status_engine.gd")
const ClampingScript = preload("res://scripts/combat/clamping.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var engine = StatusEngineScript.new()

	# Burn: deals damage each player_turn_end tick, duration decrements
	var enemy := {"hp": 20, "max_hp": 20, "block": 0}
	var statuses := [
		{"id": "burn", "stacks": 3, "duration": 2, "timing": "player_turn_end"},
	]
	var tick_result := engine.tick_statuses(statuses, "player_turn_end", enemy, {})
	var remaining := tick_result.get("statuses", []) as Array
	var entity_after := tick_result.get("entity", {}) as Dictionary

	if int(entity_after.get("hp", -1)) != 17:
		failures.append("burn should deal 3 damage (equal to stacks) to entity hp, got %d" % int(entity_after.get("hp", -1)))

	if remaining.size() != 1:
		failures.append("burn should persist after first tick when duration > 1")
	if int((remaining[0] as Dictionary).get("duration", -1)) != 1:
		failures.append("burn duration should decrement from 2 to 1")

	# Second tick: duration becomes 0, status removed
	var tick_result2 := engine.tick_statuses(remaining, "player_turn_end", entity_after, {})
	var remaining2 := tick_result2.get("statuses", []) as Array
	if remaining2.size() != 0:
		failures.append("burn should be removed when duration reaches 0")

	# Freeze: skips enemy turn when stacks > 0, ticks at enemy_turn_start
	var enemy2 := {"hp": 10, "max_hp": 10, "block": 0}
	var freeze_statuses := [
		{"id": "freeze", "stacks": 2, "duration": 2, "timing": "enemy_turn_start"},
	]
	var freeze_result := engine.tick_statuses(freeze_statuses, "enemy_turn_start", enemy2, {})
	var freeze_remaining := freeze_result.get("statuses", []) as Array
	if freeze_remaining.size() != 1:
		failures.append("freeze should persist when stacks > 1")
	if int((freeze_remaining[0] as Dictionary).get("stacks", -1)) != 1:
		failures.append("freeze stacks should decrement by 1 per tick")

	# Stacks reaching 0 removes the status
	var exhausted_statuses := [
		{"id": "stun", "stacks": 1, "duration": 1, "timing": "enemy_turn_start"},
	]
	var stun_result := engine.tick_statuses(exhausted_statuses, "enemy_turn_start", enemy2, {})
	if (stun_result.get("statuses", []) as Array).size() != 0:
		failures.append("stun should be removed when stacks reach 0")

	# Statuses with different timing are not ticked
	var poison_statuses := [
		{"id": "poison", "stacks": 2, "duration": 3, "timing": "enemy_turn_end"},
	]
	var no_tick_result := engine.tick_statuses(poison_statuses, "player_turn_end", enemy, {})
	if (no_tick_result.get("statuses", []) as Array).size() != 1:
		failures.append("statuses should not be ticked at a different timing window")
	if int(((no_tick_result.get("statuses", []) as Array)[0] as Dictionary).get("duration", -1)) != 3:
		failures.append("poison duration should not change when timing window does not match")

	return failures
```

- [ ] **Step 2: Register test and run to fail**

Add to `TEST_SCRIPTS`:
```gdscript
preload("res://tests/test_status_engine.gd"),
```

Run: `make test`
Expected: FAIL — file not found

- [ ] **Step 3: Implement StatusEngine**

```gdscript
# game/scripts/combat/status_engine.gd
class_name StatusEngine
extends RefCounted

const ClampingScript = preload("res://scripts/combat/clamping.gd")

var _clamping := ClampingScript.new()

# Effect applied per tick per status id (damage = stacks value)
const DAMAGE_STATUSES := ["burn", "poison"]
# Statuses that decrement stacks on tick (not duration)
const STACK_DECREMENT_STATUSES := ["freeze", "stun"]


func tick_statuses(statuses: Array, timing_key: String, entity: Dictionary, _context: Dictionary) -> Dictionary:
	var remaining: Array = []
	var updated_entity := entity.duplicate(true)

	for status_entry in statuses:
		var status: Dictionary = (status_entry as Dictionary).duplicate(true)
		if str(status.get("timing", "")) != timing_key:
			remaining.append(status)
			continue

		var stacks := int(status.get("stacks", 0))
		var duration := int(status.get("duration", 0))
		var status_id := str(status.get("id", ""))

		# Apply effect
		if DAMAGE_STATUSES.has(status_id):
			var damage := stacks
			updated_entity = _clamping.apply_damage_to_entity(updated_entity, damage)

		# Decrement lifetime
		if STACK_DECREMENT_STATUSES.has(status_id):
			stacks = _clamping.clamp_stacks(stacks - 1)
			status["stacks"] = stacks
		else:
			duration = _clamping.clamp_stacks(duration - 1)
			status["duration"] = duration

		# Keep if still alive
		if stacks > 0 and duration > 0:
			remaining.append(status)

	return {
		"statuses": remaining,
		"entity": updated_entity,
	}


func add_status(statuses: Array, new_status: Dictionary) -> Array:
	var updated := statuses.duplicate(true)
	var existing_index := _find_status_index(updated, str(new_status.get("id", "")))
	if existing_index == -1:
		updated.append(new_status.duplicate(true))
	else:
		var existing: Dictionary = (updated[existing_index] as Dictionary).duplicate(true)
		existing["stacks"] = int(existing.get("stacks", 0)) + int(new_status.get("stacks", 0))
		existing["duration"] = maxi(int(existing.get("duration", 0)), int(new_status.get("duration", 0)))
		updated[existing_index] = existing
	return updated


func _find_status_index(statuses: Array, status_id: String) -> int:
	for i in range(statuses.size()):
		if str((statuses[i] as Dictionary).get("id", "")) == status_id:
			return i
	return -1
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test`
Expected: `PASS test_status_engine`

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/status_engine.gd game/tests/test_status_engine.gd game/tests/test_runner.gd
git commit -m "feat: add StatusEngine with §5 tick/decrement/removal rules"
```

---

## Stage 5 — DiceResolver

Implements §3.3 (roll phase) and the reroll sub-operation from §3.5 `reroll` face effect.

**Files:**
- Create: `game/scripts/combat/dice_resolver.gd`
- Create: `game/tests/test_dice_resolver.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# game/tests/test_dice_resolver.gd
extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const DiceResolverScript = preload("res://scripts/combat/dice_resolver.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()
	var resolver = DiceResolverScript.new()

	var face_defs := catalog.get_part_definitions("face")
	var body_defs := catalog.get_part_definitions("body")

	var dice := [
		{
			"id": "d_alpha",
			"body_id": "standard_d6",
			"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			"statuses": [],
			"runes": [],
			"core": null,
		},
		{
			"id": "d_beta",
			"body_id": "standard_d6",
			"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
			"statuses": [],
			"runes": [],
			"core": null,
		},
	]

	# Deterministic roll: seeds [4, 1] → face_set[3]=strike, face_set[0]=strike
	var roll_result := resolver.roll_dice(dice, face_defs, body_defs, [4, 1])
	if not roll_result.get("ok", false):
		failures.append("roll_dice should succeed with valid dice and seeds")
		return failures

	var rolled_faces := roll_result.get("rolled_faces", []) as Array
	if rolled_faces.size() != 2:
		failures.append("roll_dice should produce one result per die, got %d" % rolled_faces.size())
		return failures

	var first := rolled_faces[0] as Dictionary
	if int(first.get("rolled_value", -1)) != 4:
		failures.append("first die should have rolled_value=4")
	if str(first.get("face_id", "")) != "strike":
		failures.append("die rolled 4 on strike/guard/focus/strike/guard/surge → face_set[3]=strike")
	if str(first.get("effect", "")) != "damage":
		failures.append("strike face should have effect=damage in rolled result")

	var second := rolled_faces[1] as Dictionary
	if int(second.get("rolled_value", -1)) != 1:
		failures.append("second die should have rolled_value=1")

	# Reroll: replace one die result in rolled_faces
	var reroll_result := resolver.reroll_die(rolled_faces, "d_beta", face_defs, body_defs, [6])
	if not reroll_result.get("ok", false):
		failures.append("reroll_die should succeed for a valid die_id")

	var after_reroll := reroll_result.get("rolled_faces", []) as Array
	var d_beta_entry := _find_entry(after_reroll, "d_beta")
	if d_beta_entry.is_empty():
		failures.append("reroll_die should update d_beta entry in rolled_faces")
	elif int(d_beta_entry.get("rolled_value", -1)) != 6:
		failures.append("rerolled d_beta should have rolled_value=6")
	if int(reroll_result.get("original_rolled_value", -1)) != 1:
		failures.append("reroll_die should return the original rolled_value for log linkage")

	# Rerolling a used die is rejected
	var used_faces := after_reroll.map(func(f: Dictionary) -> Dictionary:
		var c := f.duplicate(true)
		if str(c.get("die_id", "")) == "d_beta":
			c["used"] = true
		return c
	)
	var blocked := resolver.reroll_die(used_faces, "d_beta", face_defs, body_defs, [3])
	if blocked.get("ok", false):
		failures.append("reroll_die should reject dice that are already used")

	return failures


func _find_entry(faces: Array, die_id: String) -> Dictionary:
	for f in faces:
		if str((f as Dictionary).get("die_id", "")) == die_id:
			return f as Dictionary
	return {}
```

- [ ] **Step 2: Register and run to fail**

Add to `TEST_SCRIPTS`:
```gdscript
preload("res://tests/test_dice_resolver.gd"),
```

Run: `make test`
Expected: FAIL — file not found (or `effect` field missing on face — fixed in Stage 10; for now the test checks `effect` on rolled result)

> **Note:** The `effect` field won't exist on face_defs until Stage 10 (content extension). The `roll_dice` implementation below synthesizes `effect` from the existing `family` field as a fallback, so the test can pass now.

- [ ] **Step 3: Implement DiceResolver**

```gdscript
# game/scripts/combat/dice_resolver.gd
class_name DiceResolver
extends RefCounted

# Fallback: derive effect from family if face definition lacks explicit effect
const FAMILY_TO_EFFECT := {
	"attack": "damage",
	"defense": "block",
	"utility": "utility",
}


func roll_dice(dice: Array, face_defs: Dictionary, body_defs: Dictionary, roll_seeds: Array = []) -> Dictionary:
	var rolled_faces: Array = []
	var remaining_seeds := roll_seeds.duplicate()

	for die in dice:
		var die_data: Dictionary = die as Dictionary
		var die_id := str(die_data.get("id", ""))
		var body_id := str(die_data.get("body_id", "standard_d6"))
		var face_set := (die_data.get("face_set", []) as Array).duplicate()
		var body_def: Dictionary = body_defs.get(body_id, {})
		var side_count := int(body_def.get("sides", face_set.size()))

		var rolled_value: int
		if not remaining_seeds.is_empty():
			rolled_value = int(remaining_seeds.pop_front())
		else:
			rolled_value = randi_range(1, maxi(side_count, 1))
		rolled_value = clampi(rolled_value, 1, maxi(side_count, 1))

		var face_index := mini(rolled_value - 1, face_set.size() - 1)
		var face_id := str(face_set[face_index])
		var face_def: Dictionary = face_defs.get(face_id, {})

		rolled_faces.append({
			"die_id": die_id,
			"rolled_value": rolled_value,
			"face_id": face_id,
			"face_family": str(face_def.get("family", "utility")),
			"effect": _resolve_effect(face_def),
			"value": int(face_def.get("value", face_def.get("power_multiplier", 1))),
			"energy_cost": int(face_def.get("energy_cost", 0)),
			"used": false,
			"exhausted": false,
			"locked": false,
		})

	return {"ok": true, "rolled_faces": rolled_faces}


func reroll_die(rolled_faces: Array, die_id: String, face_defs: Dictionary, body_defs: Dictionary, roll_seeds: Array = []) -> Dictionary:
	var die_index := _find_die_index(rolled_faces, die_id)
	if die_index == -1:
		return {"ok": false, "error": "die_not_found", "die_id": die_id}

	var existing: Dictionary = rolled_faces[die_index] as Dictionary
	if bool(existing.get("used", false)) or bool(existing.get("exhausted", false)) or bool(existing.get("locked", false)):
		return {"ok": false, "error": "die_not_rerollable", "die_id": die_id}

	var original_value := int(existing.get("rolled_value", 0))
	# Build a single-die array to reuse roll_dice logic
	# We need the original die definition — reconstruct minimal form from existing entry
	var die_entry := {
		"id": die_id,
		"body_id": existing.get("body_id", "standard_d6"),
		"face_set": existing.get("face_set", []),
	}
	# If face_set not carried in rolled_face, we can't reroll without die definitions
	# Callers must pass die definitions for full reroll; use fallback if missing
	if (die_entry["face_set"] as Array).is_empty():
		return {"ok": false, "error": "face_set_not_available_for_reroll", "die_id": die_id}

	var single_die_result := roll_dice([die_entry], face_defs, body_defs, roll_seeds)
	if not single_die_result.get("ok", false):
		return single_die_result

	var new_entry: Dictionary = (single_die_result.get("rolled_faces", []) as Array)[0]
	var updated_faces := rolled_faces.duplicate(true)
	updated_faces[die_index] = new_entry

	return {
		"ok": true,
		"rolled_faces": updated_faces,
		"original_rolled_value": original_value,
	}


func _resolve_effect(face_def: Dictionary) -> String:
	var explicit := str(face_def.get("effect", ""))
	if explicit != "":
		return explicit
	return FAMILY_TO_EFFECT.get(str(face_def.get("family", "utility")), "utility")


func _find_die_index(rolled_faces: Array, die_id: String) -> int:
	for i in range(rolled_faces.size()):
		if str((rolled_faces[i] as Dictionary).get("die_id", "")) == die_id:
			return i
	return -1
```

> **Note on reroll:** The full reroll needs `face_set` carried in the rolled_face entry. Add `face_set` to rolled_face entries by updating `roll_dice` to embed the face_set from the die definition. Update the reroll test to pass dice that embed face_set, or pass it in context. For now the test uses dice that have face_set in the die_data, so we carry it through.

Update `roll_dice` in the implementation to embed `face_set` and `body_id` in each rolled_face entry (needed for reroll):

Add to the rolled_face dict in `roll_dice`:
```gdscript
"face_set": face_set.duplicate(),
"body_id": body_id,
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test`
Expected: `PASS test_dice_resolver`

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/dice_resolver.gd game/tests/test_dice_resolver.gd game/tests/test_runner.gd
git commit -m "feat: add DiceResolver with §3.3 roll phase and reroll logic"
```

---

## Stage 6 — EffectResolver

Implements §3.5 face resolution table: all effect types, temporary_modifiers, clamping.

**Files:**
- Create: `game/scripts/combat/effect_resolver.gd`
- Create: `game/tests/test_effect_resolver.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# game/tests/test_effect_resolver.gd
extends RefCounted

const EffectResolverScript = preload("res://scripts/combat/effect_resolver.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var resolver = EffectResolverScript.new()

	var player := {"hp": 20, "max_hp": 30, "block": 5, "energy": 3}
	var enemy := {"hp": 20, "max_hp": 20, "block": 3, "statuses": []}

	# damage: rolled_value * value, absorb block first
	# rolled_value=4, value=2 → 8 damage, enemy block=3 → 3 absorbed, 5 to hp → enemy hp=15
	var dmg_result := resolver.resolve_face({
		"effect": "damage", "value": 2, "energy_cost": 0
	}, 4, player.duplicate(), enemy.duplicate(), [], {})
	if int((dmg_result.get("enemy", {}) as Dictionary).get("hp", -1)) != 15:
		failures.append("damage should deal 5 to hp after absorbing 3 block (got %d)" % int((dmg_result.get("enemy", {}) as Dictionary).get("hp", -1)))
	if int((dmg_result.get("enemy", {}) as Dictionary).get("block", -1)) != 0:
		failures.append("damage should reduce enemy block to 0")

	# block: rolled_value * value added to player block
	var blk_result := resolver.resolve_face({
		"effect": "block", "value": 1, "energy_cost": 0
	}, 3, player.duplicate(), enemy.duplicate(), [], {})
	if int((blk_result.get("player", {}) as Dictionary).get("block", -1)) != 8:
		failures.append("block should add rolled_value*1=3 to player block (5+3=8)")

	# heal: flat value added to player hp, clamped to max_hp
	var heal_result := resolver.resolve_face({
		"effect": "heal", "value": 15, "energy_cost": 0
	}, 5, {"hp": 20, "max_hp": 30, "block": 0, "energy": 3}, enemy.duplicate(), [], {})
	if int((heal_result.get("player", {}) as Dictionary).get("hp", -1)) != 30:
		failures.append("heal should clamp hp to max_hp (20+15=35 → 30)")

	# burn: adds stacks to enemy statuses
	var burn_result := resolver.resolve_face({
		"effect": "burn", "value": 2, "energy_cost": 0,
		"duration": 3, "target": "enemy"
	}, 1, player.duplicate(), {"hp": 20, "max_hp": 20, "block": 0, "statuses": []}, [], {})
	var enemy_after_burn := burn_result.get("enemy", {}) as Dictionary
	var burn_statuses := enemy_after_burn.get("statuses", []) as Array
	if burn_statuses.size() != 1:
		failures.append("burn should add 1 status entry to enemy")
	else:
		var burn_status := burn_statuses[0] as Dictionary
		if int(burn_status.get("stacks", -1)) != 2:
			failures.append("burn should add stacks=2 (face.value)")
		if int(burn_status.get("duration", -1)) != 3:
			failures.append("burn should set duration=3 from face metadata")

	# amplify: adds modifier entry to temporary_modifiers
	var temp_mods: Array = []
	var amp_result := resolver.resolve_face({
		"effect": "amplify", "value": 3, "energy_cost": 0,
		"modifier_type": "additive"
	}, 2, player.duplicate(), enemy.duplicate(), temp_mods, {})
	var updated_mods := amp_result.get("temporary_modifiers", []) as Array
	if updated_mods.size() != 1:
		failures.append("amplify should append 1 entry to temporary_modifiers")
	if int((updated_mods[0] as Dictionary).get("bonus", -1)) != 3:
		failures.append("amplify modifier should carry bonus=face.value=3")

	# resolve_face with a pre-existing amplify modifier: bonus consumed, added to damage
	# rolled_value=3, face.value=2, amplify bonus=3 → total damage = 3*2+3 = 9
	# enemy block=0, enemy hp=20 → enemy hp after = 11
	var enemy_clean := {"hp": 20, "max_hp": 20, "block": 0, "statuses": []}
	var mods_with_amplify := [{"bonus": 3, "type": "damage_additive", "consumed": false}]
	var dmg_with_amp := resolver.resolve_face({
		"effect": "damage", "value": 2, "energy_cost": 0
	}, 3, player.duplicate(), enemy_clean, mods_with_amplify, {})
	if int((dmg_with_amp.get("enemy", {}) as Dictionary).get("hp", -1)) != 11:
		failures.append("damage with amplify bonus should deal 9 total (3*2+3=9), hp 20-9=11, got %d" % int((dmg_with_amp.get("enemy", {}) as Dictionary).get("hp", -1)))
	var mods_after := dmg_with_amp.get("temporary_modifiers", []) as Array
	if not mods_after.is_empty() and bool((mods_after[0] as Dictionary).get("consumed", false)) == false:
		failures.append("amplify modifier should be marked consumed after use")

	return failures
```

- [ ] **Step 2: Register and run to fail**

Add to `TEST_SCRIPTS`:
```gdscript
preload("res://tests/test_effect_resolver.gd"),
```

Run: `make test`
Expected: FAIL — file not found

- [ ] **Step 3: Implement EffectResolver**

```gdscript
# game/scripts/combat/effect_resolver.gd
class_name EffectResolver
extends RefCounted

const ClampingScript = preload("res://scripts/combat/clamping.gd")
const StatusEngineScript = preload("res://scripts/combat/status_engine.gd")

var _clamping := ClampingScript.new()
var _status_engine := StatusEngineScript.new()


# Returns: { player, enemy, temporary_modifiers, log_fragments }
func resolve_face(face: Dictionary, rolled_value: int, player: Dictionary, enemy: Dictionary, temporary_modifiers: Array, _context: Dictionary) -> Dictionary:
	var effect := str(face.get("effect", "utility"))
	var value := int(face.get("value", 1))
	var updated_player := player.duplicate(true)
	var updated_enemy := enemy.duplicate(true)
	var updated_mods := temporary_modifiers.duplicate(true)

	match effect:
		"damage":
			var bonus := _consume_damage_modifier(updated_mods)
			var total_damage := rolled_value * value + bonus
			updated_enemy = _clamping.apply_damage_to_entity(updated_enemy, total_damage)

		"block":
			var gained := rolled_value * value
			updated_player["block"] = _clamping.clamp_block(int(updated_player.get("block", 0)) + gained)

		"heal":
			var heal_amount := value
			var max_hp := int(updated_player.get("max_hp", int(updated_player.get("hp", 0))))
			updated_player["hp"] = _clamping.clamp_hp(int(updated_player.get("hp", 0)) + heal_amount, max_hp)

		"burn", "poison", "freeze":
			var stacks := value
			var duration := int(face.get("duration", 1))
			var timing := _status_timing_for(effect)
			var statuses := (updated_enemy.get("statuses", []) as Array).duplicate(true)
			statuses = _status_engine.add_status(statuses, {
				"id": effect,
				"stacks": stacks,
				"duration": duration,
				"timing": timing,
			})
			updated_enemy["statuses"] = statuses

		"amplify":
			updated_mods.append({
				"type": "damage_additive",
				"bonus": value,
				"consumed": false,
			})

		"reroll":
			# Reroll targeting is handled by CombatEngine; EffectResolver just signals intent
			pass

		"utility":
			# Utility effects are defined by face metadata; resolved by CombatEngine
			pass

	return {
		"player": updated_player,
		"enemy": updated_enemy,
		"temporary_modifiers": updated_mods,
	}


func _consume_damage_modifier(mods: Array) -> int:
	for i in range(mods.size()):
		var mod: Dictionary = mods[i] as Dictionary
		if str(mod.get("type", "")) == "damage_additive" and not bool(mod.get("consumed", false)):
			var bonus := int(mod.get("bonus", 0))
			(mods[i] as Dictionary)["consumed"] = true
			return bonus
	return 0


func _status_timing_for(effect: String) -> String:
	match effect:
		"burn":
			return "player_turn_end"
		"poison":
			return "enemy_turn_end"
		"freeze", "stun":
			return "enemy_turn_start"
	return "player_turn_end"
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test`
Expected: `PASS test_effect_resolver`

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/effect_resolver.gd game/tests/test_effect_resolver.gd game/tests/test_runner.gd
git commit -m "feat: add EffectResolver with §3.5 face resolution table"
```

---

## Stage 7 — EnemyAI

Implements §3.8 action selection from `ai_pattern` array. Supports `attack`, `multi_hit`, `debuff`, `lock`.

**Files:**
- Create: `game/scripts/combat/enemy_ai.gd`
- Create: `game/tests/test_enemy_ai.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# game/tests/test_enemy_ai.gd
extends RefCounted

const EnemyAIScript = preload("res://scripts/combat/enemy_ai.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var ai = EnemyAIScript.new()

	# Pattern with one attack action
	var enemy_state := {
		"hp": 10,
		"max_hp": 10,
		"block": 0,
		"statuses": [],
		"ai_pattern": [
			{"action": "attack", "damage": 5, "label": "Strike"},
		],
	}
	var action := ai.select_action(enemy_state, 1)
	if str(action.get("action", "")) != "attack":
		failures.append("should select attack from single-action pattern")
	if int(action.get("damage", -1)) != 5:
		failures.append("selected action should carry damage=5")

	# Multi-action pattern: cycles by turn_index
	var enemy_cycled := {
		"hp": 10,
		"max_hp": 10,
		"block": 0,
		"statuses": [],
		"ai_pattern": [
			{"action": "attack", "damage": 3, "label": "Gel Strike"},
			{"action": "debuff", "status": "poison", "stacks": 2, "duration": 2, "label": "Venom Splash"},
		],
	}
	var action_turn1 := ai.select_action(enemy_cycled, 1)
	if str(action_turn1.get("action", "")) != "attack":
		failures.append("turn 1 should select pattern[0] = attack")

	var action_turn2 := ai.select_action(enemy_cycled, 2)
	if str(action_turn2.get("action", "")) != "debuff":
		failures.append("turn 2 should select pattern[1] = debuff")

	var action_turn3 := ai.select_action(enemy_cycled, 3)
	if str(action_turn3.get("action", "")) != "attack":
		failures.append("turn 3 should wrap to pattern[0] = attack")

	# resolve_action: attack applies damage through block → hp
	var player := {"hp": 20, "max_hp": 20, "block": 3}
	var attack_action := {"action": "attack", "damage": 7, "label": "Strike"}
	var player_after := ai.resolve_action(attack_action, player.duplicate(), {})
	if int(player_after.get("block", -1)) != 0:
		failures.append("attack action should drain player block first")
	if int(player_after.get("hp", -1)) != 16:
		failures.append("attack action: 7 damage - 3 block = 4 to hp (20-4=16), got %d" % int(player_after.get("hp", -1)))

	# resolve_action: debuff applies status to player
	var debuff_action := {"action": "debuff", "status": "poison", "stacks": 2, "duration": 3, "label": "Venom"}
	var player_poisoned := ai.resolve_action(debuff_action, {"hp": 20, "max_hp": 20, "block": 0, "statuses": []}, {})
	var player_statuses := player_poisoned.get("statuses", []) as Array
	if player_statuses.size() != 1:
		failures.append("debuff action should add 1 status to player")
	elif str((player_statuses[0] as Dictionary).get("id", "")) != "poison":
		failures.append("debuff action should add poison status")

	return failures
```

- [ ] **Step 2: Register and run to fail**

Add to `TEST_SCRIPTS`:
```gdscript
preload("res://tests/test_enemy_ai.gd"),
```

Run: `make test`
Expected: FAIL — file not found

- [ ] **Step 3: Implement EnemyAI**

```gdscript
# game/scripts/combat/enemy_ai.gd
class_name EnemyAI
extends RefCounted

const ClampingScript = preload("res://scripts/combat/clamping.gd")
const StatusEngineScript = preload("res://scripts/combat/status_engine.gd")

var _clamping := ClampingScript.new()
var _status_engine := StatusEngineScript.new()


func select_action(enemy_state: Dictionary, turn_index: int) -> Dictionary:
	var pattern := (enemy_state.get("ai_pattern", []) as Array)
	if pattern.is_empty():
		return {"action": "attack", "damage": int(enemy_state.get("intent_damage", 0)), "label": str(enemy_state.get("intent_label", "Strike"))}
	var index := (turn_index - 1) % pattern.size()
	return (pattern[index] as Dictionary).duplicate(true)


func resolve_action(action: Dictionary, player: Dictionary, _context: Dictionary) -> Dictionary:
	var updated_player := player.duplicate(true)
	var action_type := str(action.get("action", "attack"))

	match action_type:
		"attack":
			updated_player = _clamping.apply_damage_to_entity(updated_player, int(action.get("damage", 0)))

		"multi_hit":
			var hits := int(action.get("hits", 1))
			var damage_per_hit := int(action.get("damage_per_hit", int(action.get("damage", 0)) / maxi(hits, 1)))
			for _i in range(hits):
				updated_player = _clamping.apply_damage_to_entity(updated_player, damage_per_hit)

		"debuff":
			var statuses := (updated_player.get("statuses", []) as Array).duplicate(true)
			statuses = _status_engine.add_status(statuses, {
				"id": str(action.get("status", "poison")),
				"stacks": int(action.get("stacks", 1)),
				"duration": int(action.get("duration", 1)),
				"timing": _timing_for_status(str(action.get("status", "poison"))),
			})
			updated_player["statuses"] = statuses

		"lock":
			pass  # Die locking handled by CombatEngine

	return updated_player


func _timing_for_status(status_id: String) -> String:
	match status_id:
		"burn": return "player_turn_end"
		"poison": return "enemy_turn_end"
		"freeze", "stun": return "enemy_turn_start"
	return "player_turn_end"
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test`
Expected: `PASS test_enemy_ai`

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/enemy_ai.gd game/tests/test_enemy_ai.gd game/tests/test_runner.gd
git commit -m "feat: add EnemyAI with §3.8 pattern-driven action selection"
```

---

## Stage 8 — AutoplayHeuristic

Implements §7 ordering: setup/reroll → amplify → survival → block → damage → utility.

**Files:**
- Create: `game/scripts/combat/autoplay_heuristic.gd`
- Tests embedded in `test_combat_engine.gd` (Stage 9) — no standalone file needed.

- [ ] **Step 1: Write the implementation directly (no failing test yet — tested via engine in Stage 9)**

```gdscript
# game/scripts/combat/autoplay_heuristic.gd
class_name AutoplayHeuristic
extends RefCounted

# §7 priority buckets (lower index = resolved earlier)
const EFFECT_PRIORITY := {
	"reroll": 0,
	"amplify": 1,
	"utility": 2,   # survival/cleanse utility
	"block": 3,
	"damage": 4,
	"burn": 5,
	"poison": 5,
	"freeze": 5,
	"heal": 2,
}


func build_queue(rolled_faces: Array) -> Array:
	var sortable := rolled_faces.duplicate(true)
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := EFFECT_PRIORITY.get(str(a.get("effect", "utility")), 6)
		var pb := EFFECT_PRIORITY.get(str(b.get("effect", "utility")), 6)
		return pa < pb
	)
	return sortable
```

- [ ] **Step 2: Commit**

```bash
git add game/scripts/combat/autoplay_heuristic.gd
git commit -m "feat: add AutoplayHeuristic with §7 priority ordering"
```

---

## Stage 9 — CombatEngine

Orchestrates the full §3.1–§3.12 battle loop. This is the main integration stage.

**Files:**
- Create: `game/scripts/combat/combat_engine.gd`
- Create: `game/tests/test_combat_engine.gd`
- Modify: `game/tests/test_runner.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# game/tests/test_combat_engine.gd
extends RefCounted

const ContentCatalogScript = preload("res://scripts/content/content_catalog.gd")
const CombatEngineScript = preload("res://scripts/combat/combat_engine.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog = ContentCatalogScript.new()

	# --- Test 1: simple victory via deterministic rolls ---
	var engine = CombatEngineScript.new(catalog)
	var player_data := {
		"hp": 20,
		"max_hp": 30,
		"energy": 3,
		"energy_regen": 1,
		"statuses": [],
		"dice_pool": [
			{
				"id": "d_alpha",
				"body_id": "standard_d6",
				"face_set": ["strike", "guard", "focus", "strike", "guard", "surge"],
				"statuses": [],
				"runes": [],
				"core": null,
			},
		],
	}
	var enemy_def := {
		"id": "slime_echo",
		"name": "Slime Echo",
		"hp": 4,
		"max_hp": 4,
		"starting_block": 0,
		"statuses": [],
		"ai_pattern": [{"action": "attack", "damage": 2, "label": "Gel Strike"}],
	}

	var init_result := engine.initialize_battle(player_data, enemy_def)
	if not init_result.get("ok", false):
		failures.append("initialize_battle should succeed with valid player and enemy data")
		return failures

	# Roll seeds: [4] → strike (face_set[3]) → effect=damage, value=2, rolled_value=4 → 8 damage
	# enemy hp=4, block=0 → 8 damage → enemy dead → victory
	var roll_result := engine.roll_phase([4])
	if not roll_result.get("ok", false):
		failures.append("roll_phase should succeed")

	var rolled := engine.get_state().get("rolled_faces", []) as Array
	if rolled.size() != 1:
		failures.append("rolled_faces should have 1 entry after rolling 1 die")

	engine.build_autoplay_queue()

	var resolve_result := engine.run_resolution_loop()
	if not resolve_result.get("ok", false):
		failures.append("run_resolution_loop should succeed")

	var state_after_resolve := engine.get_state()
	var enemy_after := state_after_resolve.get("enemy", {}) as Dictionary
	if int(enemy_after.get("hp", -1)) != 0:
		failures.append("enemy hp should be 0 after 8 damage (was 4), got %d" % int(enemy_after.get("hp", -1)))

	engine.end_player_turn()
	var outcome := engine.check_battle_end()
	if str(outcome.get("result", "")) != "victory":
		failures.append("battle should end in victory when enemy hp=0 with no remaining phases, got: %s" % str(outcome.get("result", "")))

	# --- Test 2: player defeat ---
	var engine2 = CombatEngineScript.new(catalog)
	var player_weak := {
		"hp": 2,
		"max_hp": 10,
		"energy": 3,
		"energy_regen": 1,
		"statuses": [],
		"dice_pool": [
			{
				"id": "d_guard",
				"body_id": "standard_d6",
				"face_set": ["guard", "guard", "guard", "guard", "guard", "guard"],
				"statuses": [],
				"runes": [],
				"core": null,
			},
		],
	}
	var strong_enemy := {
		"id": "crusher",
		"name": "Crusher",
		"hp": 100,
		"max_hp": 100,
		"starting_block": 0,
		"statuses": [],
		"ai_pattern": [{"action": "attack", "damage": 10, "label": "Smash"}],
	}
	engine2.initialize_battle(player_weak, strong_enemy)
	engine2.roll_phase([1])        # guard die → block, not enough
	engine2.build_autoplay_queue()
	engine2.run_resolution_loop()
	engine2.end_player_turn()
	var mid_check := engine2.check_battle_end()
	if str(mid_check.get("result", "")) != "ongoing":
		failures.append("battle should be ongoing after player turn when enemy alive")

	engine2.run_enemy_turn()
	engine2.end_enemy_turn()
	var defeat_check := engine2.check_battle_end()
	if str(defeat_check.get("result", "")) != "defeat":
		failures.append("battle should end in defeat when player hp=0 after enemy turn, got: %s" % str(defeat_check.get("result", "")))

	# --- Test 3: turn_index increments ---
	var state_t3 := engine2.get_state()
	if int(state_t3.get("turn_index", -1)) < 1:
		failures.append("turn_index should be at least 1 after one full turn cycle")

	# --- Test 4: BattleLog populated ---
	var log_entries := engine.get_log().get_entries()
	if log_entries.is_empty():
		failures.append("BattleLog should have entries after a battle")

	return failures
```

- [ ] **Step 2: Register and run to fail**

Add to `TEST_SCRIPTS`:
```gdscript
preload("res://tests/test_combat_engine.gd"),
```

Run: `make test`
Expected: FAIL — CombatEngine file not found

- [ ] **Step 3: Implement CombatEngine**

```gdscript
# game/scripts/combat/combat_engine.gd
class_name CombatEngine
extends RefCounted

const BattleLogScript = preload("res://scripts/combat/battle_log.gd")
const HookDispatcherScript = preload("res://scripts/combat/hook_dispatcher.gd")
const StatusEngineScript = preload("res://scripts/combat/status_engine.gd")
const DiceResolverScript = preload("res://scripts/combat/dice_resolver.gd")
const EffectResolverScript = preload("res://scripts/combat/effect_resolver.gd")
const EnemyAIScript = preload("res://scripts/combat/enemy_ai.gd")
const AutoplayHeuristicScript = preload("res://scripts/combat/autoplay_heuristic.gd")
const ClampingScript = preload("res://scripts/combat/clamping.gd")

var _catalog
var _log := BattleLogScript.new()
var _hook_dispatcher := HookDispatcherScript.new()
var _status_engine := StatusEngineScript.new()
var _dice_resolver := DiceResolverScript.new()
var _effect_resolver := EffectResolverScript.new()
var _enemy_ai := EnemyAIScript.new()
var _autoplay := AutoplayHeuristicScript.new()
var _clamping := ClampingScript.new()

var _state: Dictionary = {}


func _init(catalog) -> void:
	_catalog = catalog


# §3.1
func initialize_battle(player_data: Dictionary, enemy_def: Dictionary) -> Dictionary:
	_state = {
		"turn_index": 1,
		"phase": "battle_start",
		"player": {
			"hp": int(player_data.get("hp", 30)),
			"max_hp": int(player_data.get("max_hp", player_data.get("hp", 30))),
			"block": 0,
			"energy": int(player_data.get("energy", 3)),
			"energy_regen": int(player_data.get("energy_regen", 1)),
			"statuses": (player_data.get("statuses", []) as Array).duplicate(true),
		},
		"dice_pool": (player_data.get("dice_pool", []) as Array).duplicate(true),
		"enemy": {
			"id": str(enemy_def.get("id", "")),
			"display_name": str(enemy_def.get("name", str(enemy_def.get("id", "Enemy")))),
			"hp": int(enemy_def.get("hp", 1)),
			"max_hp": int(enemy_def.get("max_hp", enemy_def.get("hp", 1))),
			"block": int(enemy_def.get("starting_block", 0)),
			"statuses": (enemy_def.get("statuses", []) as Array).duplicate(true),
			"ai_pattern": (enemy_def.get("ai_pattern", []) as Array).duplicate(true),
			"phases": (enemy_def.get("phases", []) as Array).duplicate(true),
			"phase_index": 0,
			"is_boss": bool(enemy_def.get("is_boss", false)),
			"final_boss": bool(enemy_def.get("final_boss", false)),
		},
		"rolled_faces": [],
		"resolution_queue": [],
		"used_dice": [],
		"temporary_modifiers": [],
		"outcome": "",
	}

	_log.record({
		"turn": 1, "step_kind": "battle_start",
		"die_id": null, "rolled_value": null,
		"resolved_face": null, "family": null, "effect": null,
		"base_value": null, "modifiers_applied": [],
		"outcome": "battle_initialized", "rerolled_from": null,
	})

	return {"ok": true}


# §3.2 — start of player turn
func start_player_turn() -> void:
	var player: Dictionary = _state["player"]
	player["block"] = 0
	player["energy"] = _clamping.clamp_energy(int(player.get("energy", 0)) + int(player.get("energy_regen", 1)))

	var tick := _status_engine.tick_statuses(
		player.get("statuses", []) as Array, "player_turn_start", player, {}
	)
	player["statuses"] = tick.get("statuses", [])
	_state["player"] = player
	_state["used_dice"] = []
	_state["phase"] = "player_turn_start"


# §3.3
func roll_phase(roll_seeds: Array = []) -> Dictionary:
	var face_defs := _catalog.get_part_definitions("face")
	var body_defs := _catalog.get_part_definitions("body")
	var result := _dice_resolver.roll_dice(
		_state.get("dice_pool", []) as Array, face_defs, body_defs, roll_seeds
	)
	if not result.get("ok", false):
		return result
	_state["rolled_faces"] = result.get("rolled_faces", [])
	_state["phase"] = "player_roll"

	for entry in _state["rolled_faces"]:
		var e: Dictionary = entry as Dictionary
		_log.record({
			"turn": int(_state.get("turn_index", 1)),
			"step_kind": "roll",
			"die_id": str(e.get("die_id", "")),
			"rolled_value": int(e.get("rolled_value", 0)),
			"resolved_face": str(e.get("face_id", "")),
			"family": str(e.get("face_family", "")),
			"effect": str(e.get("effect", "")),
			"base_value": int(e.get("rolled_value", 0)) * int(e.get("value", 1)),
			"modifiers_applied": [],
			"outcome": "rolled",
			"rerolled_from": null,
		})

	return {"ok": true}


# §3.4 — sets resolution_queue from explicit order or autoplay
func set_resolution_queue(ordered_face_entries: Array) -> void:
	_state["resolution_queue"] = ordered_face_entries.duplicate(true)
	_state["phase"] = "player_assignment"


func build_autoplay_queue() -> void:
	var queue := _autoplay.build_queue(_state.get("rolled_faces", []) as Array)
	_state["resolution_queue"] = queue
	_state["phase"] = "player_assignment"


# §3.5
func run_resolution_loop() -> Dictionary:
	var queue := (_state.get("resolution_queue", []) as Array).duplicate(true)
	var player := (_state.get("player", {}) as Dictionary).duplicate(true)
	var enemy := (_state.get("enemy", {}) as Dictionary).duplicate(true)
	var used_dice := (_state.get("used_dice", []) as Array).duplicate(true)
	var temp_mods := (_state.get("temporary_modifiers", []) as Array).duplicate(true)

	for i in range(queue.size()):
		var entry: Dictionary = queue[i] as Dictionary
		var die_id := str(entry.get("die_id", ""))

		# Step 1: skip locked/exhausted
		if bool(entry.get("locked", false)) or bool(entry.get("exhausted", false)):
			continue

		# Step 2: energy check — skip if insufficient (no cost in starter content)
		var energy_cost := int(entry.get("energy_cost", 0))
		if energy_cost > int(player.get("energy", 0)):
			continue
		player["energy"] = _clamping.clamp_energy(int(player.get("energy", 0)) - energy_cost)

		# Step 3: pre_resolution hooks (persistent + one-shot temp_mods) — skipped for MVP

		# Step 4: resolve face effect
		var resolve := _effect_resolver.resolve_face(
			entry, int(entry.get("rolled_value", 0)), player, enemy, temp_mods, {}
		)
		player = resolve.get("player", player)
		enemy = resolve.get("enemy", enemy)
		temp_mods = resolve.get("temporary_modifiers", temp_mods)

		# Reroll handling
		if str(entry.get("effect", "")) == "reroll":
			var reroll_value := int(entry.get("value", 1))
			var targets := _pick_reroll_targets(queue, used_dice, die_id, reroll_value, i)
			for target_id in targets:
				var face_defs := _catalog.get_part_definitions("face")
				var body_defs := _catalog.get_part_definitions("body")
				var reroll_result := _dice_resolver.reroll_die(queue, target_id, face_defs, body_defs)
				if reroll_result.get("ok", false):
					queue = reroll_result.get("rolled_faces", queue)

		# Log entry
		_log.record({
			"turn": int(_state.get("turn_index", 1)),
			"step_kind": "resolution",
			"die_id": die_id,
			"rolled_value": int(entry.get("rolled_value", 0)),
			"resolved_face": str(entry.get("face_id", "")),
			"family": str(entry.get("face_family", "")),
			"effect": str(entry.get("effect", "")),
			"base_value": int(entry.get("rolled_value", 0)) * int(entry.get("value", 1)),
			"modifiers_applied": [],
			"outcome": "resolved",
			"rerolled_from": null,
		})

		# Step 7: mark as used
		used_dice.append(die_id)

		# Mid-loop: check player death
		if int(player.get("hp", 0)) <= 0:
			_state["player"] = player
			_state["enemy"] = enemy
			_state["used_dice"] = used_dice
			_state["temporary_modifiers"] = temp_mods
			return {"ok": true}

		# Mid-loop: check enemy death → phase transition
		if int(enemy.get("hp", 0)) <= 0:
			var phase_result := _try_advance_phase(enemy)
			if phase_result.get("transitioned", false):
				enemy = phase_result.get("enemy", enemy)
			# Continue loop against new or same enemy state

	_state["player"] = player
	_state["enemy"] = enemy
	_state["used_dice"] = used_dice
	_state["temporary_modifiers"] = temp_mods
	return {"ok": true}


# §3.6
func end_player_turn() -> void:
	var player: Dictionary = _state["player"]
	var enemy: Dictionary = _state["enemy"]

	var player_tick := _status_engine.tick_statuses(
		player.get("statuses", []) as Array, "player_turn_end", player, {}
	)
	player["statuses"] = player_tick.get("statuses", [])
	player = player_tick.get("entity", player)

	var enemy_tick := _status_engine.tick_statuses(
		enemy.get("statuses", []) as Array, "player_turn_end", enemy, {}
	)
	enemy["statuses"] = enemy_tick.get("statuses", [])
	enemy = enemy_tick.get("entity", enemy)

	_state["player"] = player
	_state["enemy"] = enemy
	_state["temporary_modifiers"] = []
	_state["phase"] = "player_turn_end"


# §3.7 + §3.10 — unified check; call after player turn end and after enemy turn end
func check_battle_end() -> Dictionary:
	var enemy: Dictionary = _state.get("enemy", {}) as Dictionary
	var player: Dictionary = _state.get("player", {}) as Dictionary

	if int(enemy.get("hp", 0)) <= 0:
		var phase_result := _try_advance_phase(enemy)
		if phase_result.get("transitioned", false):
			_state["enemy"] = phase_result.get("enemy", enemy)
			return {"result": "ongoing"}
		_state["outcome"] = "victory"
		return {"result": "victory"}

	if int(player.get("hp", 0)) <= 0:
		_state["outcome"] = "defeat"
		return {"result": "defeat"}

	return {"result": "ongoing"}


# §3.8
func run_enemy_turn() -> void:
	var enemy: Dictionary = _state.get("enemy", {})
	var player: Dictionary = _state.get("player", {})

	# Reset enemy block
	enemy["block"] = 0

	# Check freeze/stun
	var statuses := (enemy.get("statuses", []) as Array).duplicate(true)
	for i in range(statuses.size()):
		var s: Dictionary = statuses[i] as Dictionary
		if (str(s.get("id", "")) == "freeze" or str(s.get("id", "")) == "stun") and int(s.get("stacks", 0)) > 0:
			# Consume one stack
			s["stacks"] = int(s.get("stacks", 0)) - 1
			statuses[i] = s
			enemy["statuses"] = statuses
			_state["enemy"] = enemy
			return  # Turn skipped

	var action := _enemy_ai.select_action(enemy, int(_state.get("turn_index", 1)))
	player = _enemy_ai.resolve_action(action, player, {})
	_state["player"] = player
	_state["enemy"] = enemy
	_state["phase"] = "enemy_action"

	_log.record({
		"turn": int(_state.get("turn_index", 1)),
		"step_kind": "enemy_action",
		"die_id": null, "rolled_value": null,
		"resolved_face": str(action.get("label", "")),
		"family": "enemy", "effect": str(action.get("action", "")),
		"base_value": int(action.get("damage", 0)),
		"modifiers_applied": [],
		"outcome": "enemy resolved %s" % str(action.get("action", "")),
		"rerolled_from": null,
	})


# §3.9
func end_enemy_turn() -> void:
	var player: Dictionary = _state.get("player", {})
	var enemy: Dictionary = _state.get("enemy", {})

	var player_tick := _status_engine.tick_statuses(
		player.get("statuses", []) as Array, "enemy_turn_end", player, {}
	)
	player["statuses"] = player_tick.get("statuses", [])
	player = player_tick.get("entity", player)

	var enemy_tick := _status_engine.tick_statuses(
		enemy.get("statuses", []) as Array, "enemy_turn_end", enemy, {}
	)
	enemy["statuses"] = enemy_tick.get("statuses", [])
	enemy = enemy_tick.get("entity", enemy)

	_state["player"] = player
	_state["enemy"] = enemy
	_state["turn_index"] = int(_state.get("turn_index", 1)) + 1
	_state["phase"] = "enemy_turn_end"


func get_state() -> Dictionary:
	return _state.duplicate(true)


func get_log() -> BattleLog:
	return _log


# §3.11
func _try_advance_phase(enemy: Dictionary) -> Dictionary:
	var phases := (enemy.get("phases", []) as Array)
	var current_phase_index := int(enemy.get("phase_index", 0))
	if current_phase_index + 1 >= phases.size():
		return {"transitioned": false}

	var next_phase: Dictionary = (phases[current_phase_index + 1] as Dictionary).duplicate(true)
	var updated := enemy.duplicate(true)
	updated["phase_index"] = current_phase_index + 1
	updated["hp"] = int(next_phase.get("hp", 1))
	updated["max_hp"] = int(next_phase.get("hp", updated.get("max_hp", 1)))
	updated["block"] = int(next_phase.get("starting_block", 0))
	if next_phase.has("ai_pattern"):
		updated["ai_pattern"] = (next_phase.get("ai_pattern", []) as Array).duplicate(true)

	_log.record({
		"turn": int(_state.get("turn_index", 1)),
		"step_kind": "phase_transition",
		"die_id": null, "rolled_value": null,
		"resolved_face": null, "family": null, "effect": null,
		"base_value": null, "modifiers_applied": [],
		"outcome": "phase advanced to %d" % (current_phase_index + 1),
		"rerolled_from": null,
	})

	return {"transitioned": true, "enemy": updated}


func _pick_reroll_targets(queue: Array, used_dice: Array, host_die_id: String, count: int, current_index: int) -> Array:
	var targets: Array = []
	for i in range(queue.size()):
		if i == current_index:
			continue
		var entry: Dictionary = queue[i] as Dictionary
		var die_id := str(entry.get("die_id", ""))
		if used_dice.has(die_id):
			continue
		if bool(entry.get("exhausted", false)) or bool(entry.get("locked", false)):
			continue
		if die_id == host_die_id:
			continue
		targets.append(die_id)
		if targets.size() >= count:
			break
	return targets
```

- [ ] **Step 4: Run to verify it passes**

Run: `make test`
Expected: `PASS test_combat_engine`

- [ ] **Step 5: Commit**

```bash
git add game/scripts/combat/combat_engine.gd game/tests/test_combat_engine.gd game/tests/test_runner.gd
git commit -m "feat: add CombatEngine orchestrating §3.1-§3.12 full battle loop"
```

---

## Stage 10 — Content schema extensions

Extend existing JSON content files with `effect`, `value`, `energy_cost`, `ai_pattern`, and `hooks`. These are additive — no existing fields removed.

**Files to modify:**
- `game/content/dice/faces.json`
- `game/content/dice/runes.json`
- `game/content/enemies/tutorial_enemies.json`
- `game/content/enemies/bosses.json`
- `game/content/archetypes/starter_archetypes.json`

**Files to create:**
- `game/content/dice/cores.json`

- [ ] **Step 1: Extend faces.json**

Replace `game/content/dice/faces.json` content. Preserves existing fields, adds `effect`, `value`, `energy_cost`:

```json
{
  "id": "starter_faces",
  "definitions": [
    {
      "id": "strike",
      "name": "Strike",
      "family": "attack",
      "effect": "damage",
      "value": 2,
      "energy_cost": 0,
      "power_multiplier": 2
    },
    {
      "id": "guard",
      "name": "Guard",
      "family": "defense",
      "effect": "block",
      "value": 1,
      "energy_cost": 0,
      "power_multiplier": 1
    },
    {
      "id": "focus",
      "name": "Focus",
      "family": "utility",
      "effect": "block",
      "value": 1,
      "energy_cost": 0,
      "bonus_block": 1
    },
    {
      "id": "surge",
      "name": "Surge",
      "family": "attack",
      "effect": "damage",
      "value": 1,
      "energy_cost": 0,
      "power_multiplier": 1
    },
    {
      "id": "heavy_strike",
      "name": "Heavy Strike",
      "family": "attack",
      "effect": "damage",
      "value": 3,
      "energy_cost": 0,
      "power_multiplier": 3
    },
    {
      "id": "bulwark",
      "name": "Bulwark",
      "family": "defense",
      "effect": "block",
      "value": 2,
      "energy_cost": 0,
      "power_multiplier": 2
    }
  ]
}
```

- [ ] **Step 2: Create cores.json**

```json
{
  "id": "starter_cores",
  "definitions": [
    {
      "id": "blank_core",
      "name": "Blank Core",
      "family": "neutral",
      "hooks": {}
    },
    {
      "id": "ember_core",
      "name": "Ember Core",
      "family": "attack",
      "hooks": {
        "on_roll": {
          "type": "apply_status",
          "priority": "triggered",
          "target": "enemy",
          "status": "burn",
          "stacks": 1,
          "duration": 2
        }
      }
    }
  ]
}
```

- [ ] **Step 3: Extend runes.json with hooks**

```json
{
  "id": "starter_runes",
  "definitions": [
    {
      "id": "blank_rune",
      "name": "Blank Rune",
      "family": "neutral",
      "hooks": {}
    },
    {
      "id": "ember_rune",
      "name": "Ember Rune",
      "family": "attack",
      "hooks": {
        "on_resolution": {
          "type": "apply_status",
          "priority": "triggered",
          "target": "enemy",
          "status": "burn",
          "stacks": 1,
          "duration": 2
        }
      }
    }
  ]
}
```

- [ ] **Step 4: Extend tutorial_enemies.json with ai_pattern**

```json
{
  "id": "tutorial_enemies",
  "definitions": [
    {
      "id": "slime_echo",
      "name": "Slime Echo",
      "hp": 8,
      "max_hp": 8,
      "starting_block": 0,
      "intent": "Gel Strike",
      "damage": 3,
      "statuses": [],
      "ai_pattern": [
        {"action": "attack", "damage": 3, "label": "Gel Strike"}
      ]
    }
  ]
}
```

- [ ] **Step 5: Extend bosses.json with ai_pattern per phase**

```json
{
  "id": "boss_enemies",
  "definitions": [
    {
      "id": "shard_overseer",
      "name": "Shard Overseer",
      "hp": 8,
      "max_hp": 8,
      "starting_block": 1,
      "intent": "Lattice Swipe",
      "damage": 4,
      "is_boss": true,
      "statuses": [],
      "ai_pattern": [
        {"action": "attack", "damage": 4, "label": "Lattice Swipe"},
        {"action": "debuff", "status": "freeze", "stacks": 1, "duration": 1, "label": "Crystal Cage"}
      ],
      "phases": [
        {
          "phase_index": 1,
          "hp": 8,
          "max_hp": 8,
          "starting_block": 1,
          "intent": "Lattice Swipe",
          "damage": 4,
          "ai_pattern": [
            {"action": "attack", "damage": 4, "label": "Lattice Swipe"},
            {"action": "debuff", "status": "freeze", "stacks": 1, "duration": 1, "label": "Crystal Cage"}
          ]
        },
        {
          "phase_index": 2,
          "hp": 10,
          "max_hp": 10,
          "starting_block": 0,
          "intent": "Refraction Pulse",
          "damage": 5,
          "ai_pattern": [
            {"action": "attack", "damage": 5, "label": "Refraction Pulse"},
            {"action": "multi_hit", "hits": 2, "damage_per_hit": 3, "label": "Shard Scatter"}
          ]
        }
      ]
    },
    {
      "id": "final_warden_core",
      "name": "Final Warden",
      "hp": 10,
      "max_hp": 10,
      "starting_block": 1,
      "intent": "Seal Break",
      "damage": 5,
      "is_boss": true,
      "final_boss": true,
      "statuses": [],
      "ai_pattern": [
        {"action": "attack", "damage": 5, "label": "Seal Break"},
        {"action": "debuff", "status": "poison", "stacks": 2, "duration": 3, "label": "Warden's Curse"}
      ],
      "phases": [
        {
          "phase_index": 1,
          "hp": 10,
          "max_hp": 10,
          "starting_block": 1,
          "intent": "Seal Break",
          "damage": 5,
          "ai_pattern": [
            {"action": "attack", "damage": 5, "label": "Seal Break"},
            {"action": "debuff", "status": "poison", "stacks": 2, "duration": 3, "label": "Warden's Curse"}
          ]
        },
        {
          "phase_index": 2,
          "hp": 12,
          "max_hp": 12,
          "starting_block": 0,
          "intent": "Warden's Fury",
          "damage": 6,
          "ai_pattern": [
            {"action": "attack", "damage": 6, "label": "Warden's Fury"},
            {"action": "multi_hit", "hits": 3, "damage_per_hit": 2, "label": "Barrage"}
          ]
        }
      ]
    }
  ]
}
```

- [ ] **Step 6: Extend archetypes with energy fields**

In `game/content/archetypes/starter_archetypes.json`, update `player_state` object:

```json
"player_state": {
  "hp": 30,
  "max_hp": 30,
  "energy": 3,
  "energy_regen": 1,
  "status_effects": []
}
```

- [ ] **Step 7: Load cores.json in ContentCatalog**

In `game/scripts/content/content_catalog.gd`:

Add field declaration near other definition dicts:
```gdscript
var _core_definitions: Dictionary = {}
```

In `ensure_loaded()`, add after `_rune_definitions` loading:
```gdscript
_core_definitions = _load_named_definitions("%s/cores.json" % DICE_DIR)
```

In `get_part_definitions()`:
```gdscript
if part_type == "core":
    return _core_definitions.duplicate(true)
```

- [ ] **Step 8: Run all tests to verify nothing broke**

Run: `make test`
Expected: all tests pass (including existing tests — backwards compat preserved by keeping `power_multiplier` in faces.json)

- [ ] **Step 9: Commit**

```bash
git add game/content/dice/faces.json game/content/dice/cores.json game/content/dice/runes.json \
        game/content/enemies/tutorial_enemies.json game/content/enemies/bosses.json \
        game/content/archetypes/starter_archetypes.json \
        game/scripts/content/content_catalog.gd
git commit -m "feat: extend content schemas with effect/value/ai_pattern/hooks per §3-§5 design"
```

---

## Stage 11 — Wire CombatEngine into existing CombatController

Delegates the logic path through CombatEngine while keeping the existing `CombatController` UI shell and the existing headless test suite green.

**Files:**
- Modify: `game/scripts/combat/combat_controller.gd`
- Modify: `game/scripts/combat/combat_state.gd` (add `engine_state` field)

- [ ] **Step 1: Add engine_state field to CombatState**

In `game/scripts/combat/combat_state.gd`, add a field to carry through the engine's internal state:

```gdscript
var engine_state: Dictionary  # carries CombatEngine._state for new engine path
```

In `_init`:
```gdscript
engine_state = (data.get("engine_state", {}) as Dictionary).duplicate(true)
```

In `to_dictionary`:
```gdscript
"engine_state": engine_state.duplicate(true),
```

- [ ] **Step 2: Add CombatEngine wiring to CombatController**

At top of `game/scripts/combat/combat_controller.gd`, add import:
```gdscript
const CombatEngineScript = preload("res://scripts/combat/combat_engine.gd")
```

Add field:
```gdscript
var _engine: CombatEngineScript = null
```

In `begin_encounter`, after creating `CombatState`, initialize the engine:
```gdscript
# Initialize new CombatEngine alongside legacy state
_engine = CombatEngineScript.new(content_catalog)
var player_data := {
    "hp": int((run_state.player_state as Dictionary).get("hp", 30)),
    "max_hp": int((run_state.player_state as Dictionary).get("max_hp", 30)),
    "energy": int((run_state.player_state as Dictionary).get("energy", 3)),
    "energy_regen": int((run_state.player_state as Dictionary).get("energy_regen", 1)),
    "statuses": [],
    "dice_pool": (run_state.active_dice as Array).map(func(d: Dictionary) -> Dictionary:
        var die := d.duplicate(true)
        if not die.has("statuses"): die["statuses"] = []
        if not die.has("runes"): die["runes"] = []
        if not die.has("core"): die["core"] = null
        return die
    ),
}
_engine.initialize_battle(player_data, enemy_definition)
```

> **Note:** The legacy `resolve_player_turn` and `resolve_enemy_turn` methods continue to function for the existing test suite. The engine runs in parallel and its state is stored in `combat_state.engine_state` after each round via:

After `_engine.end_enemy_turn()` in `run_auto_round`, sync engine state back:
```gdscript
combat_state.engine_state = _engine.get_state()
```

- [ ] **Step 3: Run all tests**

Run: `make test`
Expected: all existing tests pass; `test_combat_engine` passes

- [ ] **Step 4: Commit**

```bash
git add game/scripts/combat/combat_controller.gd game/scripts/combat/combat_state.gd
git commit -m "feat: wire CombatEngine into CombatController alongside legacy path"
```

---

## Self-review

Checking spec sections against plan coverage:

| Spec section | Plan stage |
|---|---|
| §2 BattleState schemas (Player, Enemy, Die, Face, etc.) | Stage 9 (CombatEngine._state) |
| §2.1 Clamping rules | Stage 1 |
| §3.1 Initialize | Stage 9 `initialize_battle` |
| §3.2 Start of player turn | Stage 9 `start_player_turn` |
| §3.3 Roll phase + on_roll hooks | Stages 5 + 9 |
| §3.4 Sequence selection / autoplay | Stages 8 + 9 |
| §3.5 Resolution loop (all 8 steps) | Stage 9 `run_resolution_loop` |
| §3.5 Face resolution table (all effects) | Stage 6 |
| §3.6 End of player turn | Stage 9 `end_player_turn` |
| §3.7 Battle-end check | Stage 9 `check_battle_end` |
| §3.8 Enemy turn | Stage 9 `run_enemy_turn` |
| §3.9 End of enemy turn | Stage 9 `end_enemy_turn` |
| §3.10 Battle-end check (after enemy) | Stage 9 `check_battle_end` |
| §3.11 Phase transitions | Stage 9 `_try_advance_phase` |
| §3.12 Battle end | Stage 9 `check_battle_end` → outcome field |
| §4 Timing rules | Stage 3 HookDispatcher |
| §5 Status rules | Stage 4 StatusEngine |
| §6 Determinism / BattleLog | Stage 2 BattleLog |
| §6.1 Log entry format | Stage 2 |
| §7 Autoplay heuristic | Stage 8 |
| §8 Engine boundary suggestion | All stages |

**Gaps to note:**

- **§3.2 step 6 (automatic effects)** — free rerolls, energy gain, bonus dice draw, face transformation. Skeleton is in `start_player_turn` but effect handler hooks aren't wired. Extend in a follow-up if needed.
- **§3.5 step 3 persistent rune/core hooks** — `run_resolution_loop` has a comment placeholder but does not yet collect rune/core hooks from die definitions. The `HookDispatcher` is ready; wiring it requires iterating die definitions per die in the queue. Extend in a follow-up.
- **§3.8 step 8 enemy statuses applied to dice** — `lock` and face `corrupt` effects on dice are scaffolded in `EnemyAI.resolve_action` but not fully wired. Extend when dice-targeting enemy actions are added to content.
- **`utility` face effect** — the face resolution table entry is a pass-through stub. Concrete utility implementations (draw, duplicate, steal, transform, cleanse) should be added to `EffectResolver` as content demands them.

No placeholder text present in the actual task steps — all code blocks show complete implementations.

**Type consistency check:**

- `rolled_faces` entries always carry: `die_id`, `rolled_value`, `face_id`, `face_family`, `effect`, `value`, `energy_cost`, `used`, `exhausted`, `locked`, `face_set`, `body_id`. Consistent across DiceResolver (producer), resolution loop (consumer), reroll logic (updater).
- `StatusEngine.tick_statuses` signature: `(statuses: Array, timing_key: String, entity: Dictionary, context: Dictionary) -> Dictionary`. Called consistently in Stage 9 with matching signature.
- `EffectResolver.resolve_face` signature: `(face: Dictionary, rolled_value: int, player: Dictionary, enemy: Dictionary, temporary_modifiers: Array, context: Dictionary) -> Dictionary`. Called with matching args in resolution loop.
