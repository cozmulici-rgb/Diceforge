# Code Review: `feat/game-development-docs`

**Branch:** feat/game-development-docs
**Base:** main
**Date:** 2026-03-22
**Commits:** 8 | **Files changed:** 122 | **Lines added:** ~8,500

## Overview

This branch implements a Godot-based dice-forge dungeon crawler across 7 development phases: documentation pipeline, gameplay foundation, deterministic combat, rewards/forge system, exploration, meta-progression, and daily void mode.

---

## Critical Issues

### 1. Inverted error detection logic

**Files:** `game/scripts/core/game_state_coordinator.gd:414`, `game/scripts/exploration/dungeon_generator.gd:82-83`

`_is_error_result()` uses `not value.get("ok", true)` — defaulting to `true` means a missing `ok` key is treated as success, silently masking errors. Should default to `false`.

```gdscript
# BUG
func _is_error_result(value) -> bool:
    return value is Dictionary and not value.get("ok", true)

# FIX
func _is_error_result(value) -> bool:
    return value is Dictionary and not value.get("ok", false)
```

### 2. Null crash in save validation

**File:** `game/scripts/persistence/save_schema.gd:36-48`

`validate_run_state()` accepts a nullable `content_catalog` parameter. If null, calling `content_catalog.validate_saved_state()` crashes with a null reference error.

### 3. File write without null check

**File:** `game/scripts/persistence/persistence_service.gd:114-117`

`FileAccess.open()` can return null on failure, but `store_string()` is called without checking the return value first.

### 4. Boss phase controller — empty phases and off-by-one

**File:** `game/scripts/combat/boss_phase_controller.gd`

- **Line 6:** Returns empty dict if phases array is empty; callers don't handle this.
- **Lines 27-31:** Phase transition index check appears inverted, preventing advancement to the next phase.

### 5. Dice model zero side_count

**File:** `game/scripts/combat/dice_model.gd:39-42`

`clampi(1, 1, 0)` returns 0 when `side_count` is 0, producing invalid roll results.

### 6. Test assertion is inverted

**File:** `game/tests/test_forge_assembly.gd:32`

Uses `.get("ok", true)` when testing rejection. The test passes even when the forge incorrectly accepts invalid input.

```gdscript
# BUG: default true means this never catches failures
if invalid_rune.get("ok", true):
    failures.append("...")

# FIX
if invalid_rune.get("ok", false):
    failures.append("...")
```

---

## High Priority

| File | Line(s) | Issue |
|------|---------|-------|
| `game/scripts/core/game_state_coordinator.gd` | 260-268 | Duplicate boss defeat check — floor advancement logic may be skipped |
| `game/scripts/combat/combat_controller.gd` | 283 | `_render()` accesses nested combat_state properties without null safety |
| `game/scripts/combat/action_slot.gd` | 19 | `accepts_family()` returns null instead of false on failure path |
| `game/scripts/exploration/exploration_controller.gd` | 54-65 | `get_room()` can return null but result is dereferenced without check |
| `game/scripts/progression/achievement_tracker.gd` | 13-14 | No null check on `get_progression_definitions()` return — crash risk |
| `game/scripts/progression/unlock_registry.gd` | 13-14 | Same null safety issue as achievement_tracker |
| `game/scripts/modifiers/modifier_registry.gd` | 18-19 | Silently skips malformed modifiers with no logging |

---

## Medium Priority

| File | Line(s) | Issue |
|------|---------|-------|
| `game/scripts/progression/meta_progression_controller.gd` | 35-39 | Inconsistent return types — returns data object OR error Dictionary |
| `game/scripts/exploration/dungeon_generator.gd` | 38-48 | Same inconsistent return type pattern |
| `game/scripts/modes/daily_void_mode_adapter.gd` | 30 | Assigns `meta_state.unlocked_archetype_ids` directly then appends, mutating source |
| `game/scripts/app_root.gd` | 114-117 | Checks for `errors` (plural) key but coordinator returns `error` (singular) — dead code |
| `game/scripts/content/content_validator.gd` | 74-76 | Blessing/curse ID collision silently overwrites without warning |
| `game/scripts/persistence/persistence_service.gd` | 63 | Directory removal doesn't verify success before returning true |
| `game/scripts/persistence/persistence_service.gd` | 92 | Redundant `validate_run_state()` call in list iteration — performance |
| `game/scripts/combat/combat_controller.gd` | 216-241 | `run_auto_round()` chains operations without mid-sequence validation |
| `game/scripts/combat/combat_state.gd` | 26-32 | `.duplicate(true)` on arrays doesn't deep-clone nested RefCounted objects |
| `game/scripts/exploration/room_graph.gd` | 64-75 | `_add_connection()` creates duplicate links if called multiple times with same rooms |
| `game/scripts/rewards/forge_assembly_system.gd` | 30, 51, 92 | Unsafe dictionary/array casting without validation |
| `game/scripts/screens/start_menu_controller.gd` | 19-29 | Initialization order hazard — `_ready()` vs `configure()` race |
| `game/scripts/rewards/reward_controller.gd` | 30, 51-52 | Unsafe `run_session` access without null checks |
| Multiple combat scripts | — | State phases use raw strings (`"player_roll"`, `"enemy_turn"`, `"complete"`) with no enum/constants |

---

## Low Priority

| File | Line(s) | Issue |
|------|---------|-------|
| `game/scripts/core/run_session.gd` | 37-52 | Unnecessary `.duplicate()` on primitives (strings, ints, bools) |
| `game/scripts/content/content_catalog.gd` | 97-108 | Repetitive load pattern — could use a generic helper |
| `game/scripts/combat/combat_controller.gd` | 298-300 | `JSON.stringify()` called on potentially large arrays every frame |
| `game/scripts/exploration/exploration_controller.gd` | 83-92 | Room button list rebuilt from scratch every transition — no caching |
| `game/scripts/combat/dice_model.gd` | 52 | Face family fallback to `"utility"` may cause unexpected behavior |
| `game/scripts/rewards/forge_assembly_system.gd` | 37-38, 50 | Redundant type casting and duplication pattern |

---

## JSON Content Data

22 content files reviewed. All valid JSON with correct cross-references.

| File | Severity | Issue |
|------|----------|-------|
| `game/content/floors/tutorial_floor.json` | Medium | Missing `boss_encounter_id` and `seed` fields present in floor_01 and floor_02. Has redundant empty `rooms: []` array. |
| `game/content/archetypes/starter_archetypes.json` | Low | Missing `name` field, unlike every other content type. |

Cross-reference validations passed:
- All encounter, enemy, dice face, body, rune, modifier, archetype, room, reward, and unlock IDs resolve correctly.
- Enum values (`family`, `modifier_type`, `reward_type`, `room_type`, etc.) are consistent.
- Enemy difficulty curve and reward distribution are well-balanced.

---

## Test Coverage

### Gaps identified

- **No negative testing** — no malformed input, boundary conditions, or failure scenarios
- **Missing direct tests** for: `ModifierEffect`, `AchievementTracker`, `UnlockRegistry`
- **`test_combat_controller.gd`** — only tests enemy defeat, not player defeat or timeout
- **`test_exploration_flow.gd`** — no room state persistence or recovery scenarios
- **`test_daily_void_mode.gd`** — no timezone/DST edge case tests
- **`test_persistence_service.gd`** — no failure/recovery scenarios (disk full, corrupted saves)

### Test quality concern

The test runner uses a simple `Array[String]` failure collection pattern. Assertions are string-based with no structured error codes, making automated analysis difficult.

---

## Positives

- Clean separation of concerns: content loading, game logic, persistence, and UI are well-isolated
- Content-driven architecture with JSON definitions is extensible and designer-friendly
- Deterministic combat flow with proper state snapshots
- Good use of `.duplicate(true)` for state immutability (though inconsistently applied)
- Solid documentation pipeline with design docs, ADRs, and phased implementation plans
- Content validator provides good structural validation at load time
- Well-structured dungeon generation with graph-based room connectivity

---

## Recommended Fix Priority

1. **Fix `_is_error_result()` default** — affects error propagation across the entire codebase
2. **Fix `test_forge_assembly.gd:32` assertion** — test is not validating what it claims
3. **Add null guards** in `persistence_service.gd` file operations and `save_schema.gd` catalog parameter
4. **Fix `boss_phase_controller.gd`** phase transition logic and empty phases handling
5. **Standardize return types** — always return Dictionary with `ok` key, not mixed types
6. **Add `boss_encounter_id` and `seed`** to `tutorial_floor.json`
7. **Define constants/enums** for combat state phases
8. **Expand test coverage** with negative tests and edge cases
