# Phase 05: Floor Progression And Bosses

## Objective

Turn the encounter-reward loop into a complete run structure by adding branching floors, boss encounters, and run completion conditions. This phase delivers the first full local roguelike loop from start to death or boss victory.

## Dependencies

- Depends on: Phase 04
- Enables: Phase 06

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scripts/exploration/dungeon_generator.gd` | Generates deterministic floor graphs and boss path connectivity |
| `game/scripts/exploration/floor_state.gd` | Tracks floor index, visited rooms, and boss room status |
| `game/scripts/combat/boss_phase_controller.gd` | Handles boss phase transitions and counters |
| `game/content/floors/floor_01.json` | First full branching floor definition |
| `game/content/floors/floor_02.json` | Second floor definition or deterministic variant |
| `game/content/encounters/boss_encounters.json` | Boss encounter definitions |
| `game/content/enemies/bosses.json` | Boss enemy data and counter rules |
| `game/tests/test_dungeon_generator.gd` | Graph reachability and boss-path tests |
| `game/tests/test_boss_encounter.gd` | Boss phase and run-end tests |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `game/scripts/core/game_state_coordinator.gd` | Advance floors, determine run completion, and route into boss encounters |
| `game/scripts/core/run_session.gd` | Track floor progression, visited rooms, and run completion flags |
| `game/scripts/exploration/exploration_controller.gd` | Work with branching room graphs and boss-room logic |
| `game/scripts/combat/combat_controller.gd` | Support boss-specific turn rules and encounter result flags |
| `game/scripts/rewards/reward_controller.gd` | Differentiate standard, elite, and boss rewards |
| `game/scripts/content/content_catalog.gd` | Load floor and boss content definitions |
| `game/tests/test_runner.gd` | Register dungeon and boss tests |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | No deletions required in this phase |

## Interface & Contract Changes

This phase completes the runtime expectations around:

```text
GameStateCoordinator.enter_room(room_id: String) -> RoomTransitionResult
GameStateCoordinator.apply_encounter_result(result: EncounterResolution) -> RunSession
GameStateCoordinator.finalize_run(result: RunOutcome) -> ProgressionResult
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Dungeon generation creates a reachable boss path | Unit | `game/tests/test_dungeon_generator.gd` |
| Combat resolution applies player then enemy turn in order | Integration | `game/tests/test_combat_controller.gd` |
| Run completion awards Echo Shards and unlocks | Integration | `game/tests/test_boss_encounter.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] A run can progress across multiple rooms and at least one branching floor
- [ ] Generated or loaded floor graphs always contain a reachable boss path
- [ ] Boss encounters can trigger multi-phase combat behavior and return run-complete outcomes
- [ ] Defeating a boss or dying marks the run as complete and routes into the run-end flow
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity check passes: `make verify`

## Implementation Notes

- Keep floor generation deterministic and seed-driven to support later Daily Void reuse.
- Boss design should express counterplay but does not need final polish effects yet.
- If run-end progression data shape is incomplete, return a structured placeholder and finish persistence in Phase 06.
