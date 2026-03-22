# Phase 03: Core Dice Combat

## Objective

Implement deterministic encounter resolution around the dice model, action assignment, and enemy turns. This phase establishes the central combat loop that later reward, boss, and progression phases will build on.

## Dependencies

- Depends on: Phase 02
- Enables: Phase 04

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scenes/screens/combat_screen.tscn` | Combat scene used after encounter entry |
| `game/scripts/combat/combat_controller.gd` | Owns combat lifecycle and round resolution |
| `game/scripts/combat/combat_state.gd` | Mutable combat state data object |
| `game/scripts/combat/dice_model.gd` | Dice/body/face/rune roll semantics and validation |
| `game/scripts/combat/action_slot.gd` | Represents codex slots and assignment eligibility |
| `game/scripts/combat/roll_result.gd` | Encapsulates deterministic roll output |
| `game/scripts/combat/enemy_encounter_model.gd` | Enemy state, intent, and action definitions |
| `game/content/dice/bodies.json` | Starter body definitions |
| `game/content/dice/faces.json` | Starter face definitions |
| `game/content/dice/runes.json` | Starter rune definitions |
| `game/content/encounters/tutorial_encounters.json` | Initial encounter definitions |
| `game/content/enemies/tutorial_enemies.json` | Initial enemy definitions |
| `game/tests/test_combat_controller.gd` | Combat flow and turn-order tests |
| `game/tests/test_dice_model.gd` | Dice validity and assignment-rule tests |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `game/scripts/app_root.gd` | Route exploration-triggered encounters into combat |
| `game/scripts/core/game_state_coordinator.gd` | Start encounters and apply encounter results into run-state |
| `game/scripts/core/run_session.gd` | Add active dice, player hp, action slots, and combat result fields |
| `game/scripts/content/content_catalog.gd` | Load dice parts, enemies, and encounter definitions |
| `game/scripts/screens/exploration_screen.gd` | Pause exploration and hand control to combat |
| `game/scripts/ui/hud_controller.gd` | Show hp, active dice summary, and action slots |
| `game/tests/test_runner.gd` | Register combat tests |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | No deletions required in this phase |

## Interface & Contract Changes

New interface implemented from `contracts.md`:

```text
interface CombatController
  begin_encounter(run_state: RunState, encounter: EncounterDefinition) -> CombatState
  roll_active_dice(state: CombatState) -> RollResultSet
  assign_die_to_action(state: CombatState, die_id: String, action_slot_id: String) -> CombatState | RuleViolation
  resolve_player_turn(state: CombatState) -> CombatState
  resolve_enemy_turn(state: CombatState) -> CombatState
  finish_encounter(state: CombatState) -> EncounterResolution
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Encounter start transitions exploration state into combat state | Integration | `game/tests/test_exploration_flow.gd` |
| Dice assignment rejects unrolled or invalid dice ids | Unit | `game/tests/test_dice_model.gd` |
| Combat resolution applies player then enemy turn in order | Integration | `game/tests/test_combat_controller.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] Entering an encounter from exploration opens a combat scene with deterministic starter enemy data
- [ ] Active dice can be rolled and assigned to valid action slots
- [ ] Invalid die assignment attempts are rejected without mutating combat state
- [ ] Combat resolves player turn before enemy turn and returns a structured encounter result
- [ ] Encounter completion updates run hp and completion state in `RunSession`
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity check passes: `make verify`

## Implementation Notes

- Keep randomness injectable or seedable from day one; later Daily Void work depends on this.
- Follow the combat order from `game-design.md` exactly; do not fold enemy resolution into player action resolution.
- Do NOT add reward selection or forge mutation logic in this phase beyond returning an encounter result payload.
