# Phase 05: Floor Progression And Bosses

## Objective

Turn the encounter-reward loop into a complete run structure by adding branching floors, boss encounters, and run completion conditions. This phase delivers the first full local roguelike loop from start room to death or final boss victory.

## Dependencies

- Depends on: Phase 04
- Enables: Phase 06

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scripts/exploration/dungeon_generator.gd` | Generates deterministic floor graphs and boss path connectivity |
| `game/scripts/exploration/floor_state.gd` | Tracks floor index, visited rooms, and boss room status |
| `game/scripts/exploration/room_transition_result.gd` | Structured room-entry result for exploration and coordinator flow |
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
| `game/scripts/app_root.gd` | Route floor transitions, boss entry, and run-complete outcomes into the next screen state |
| `game/scripts/core/game_state_coordinator.gd` | Advance floors, determine run completion, and route into boss encounters |
| `game/scripts/core/run_session.gd` | Track floor progression, visited rooms, room graph state, and run completion flags |
| `game/scripts/exploration/exploration_controller.gd` | Work with branching room graphs and boss-room logic |
| `game/scripts/combat/combat_controller.gd` | Support boss-specific turn rules and encounter result flags |
| `game/scripts/rewards/reward_controller.gd` | Differentiate standard, elite, floor-complete, and boss rewards |
| `game/scripts/content/content_catalog.gd` | Load floor, boss, and room graph content definitions |
| `game/scripts/ui/hud_controller.gd` | Show floor index, branching map state, and boss-room status |
| `game/tests/test_runner.gd` | Register dungeon and boss tests |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | No deletions required in this phase |

## Interface & Contract Changes

This phase completes the runtime expectations around:

```text
interface GameStateCoordinator
  enter_room(room_id: String) -> RoomTransitionResult
  apply_encounter_result(result: EncounterResolution) -> RunSession
  finalize_run(result: RunOutcome) -> ProgressionResult
```

This phase also needs a deterministic floor-generation boundary so exploration and tests can share the same graph contract:

```text
interface DungeonGenerator
  generate_floor(template_id: String, seed: int, run_state: RunSession) -> FloorState
  list_reachable_rooms(floor_state: FloorState, from_room_id: String) -> Array[String]
  is_boss_path_reachable(floor_state: FloorState) -> bool
```

Supporting runtime payloads introduced or expanded in this phase:

```text
RoomTransitionResult
  room_id: String
  room_type: start | encounter | event | shop | forge | boss
  encounter_id: String
  reward_source_id: String
  floor_complete: bool
  run_complete: bool
```

```text
FloorState
  floor_index: int
  floor_template_id: String
  start_room_id: String
  boss_room_id: String
  room_ids: Array[String]
  visited_room_ids: Array[String]
  completed_room_ids: Array[String]
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Dungeon generation creates a reachable boss path | Unit | `game/tests/test_dungeon_generator.gd` |
| Boss and encounter definitions map to valid rewards and floors | Validation | `game/tests/test_content_catalog.gd` |
| Combat resolution applies player then enemy turn in order | Integration | `game/tests/test_combat_controller.gd` |
| Run completion awards Echo Shards and unlocks | Integration | `game/tests/test_boss_encounter.gd` |
| Exploration-to-combat transition and post-combat reward transition | Integration | `game/tests/test_exploration_flow.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] A run can progress across multiple rooms and at least one branching floor
- [ ] Generated or loaded floor graphs always contain a reachable boss path
- [ ] Room entry and completion state are preserved across exploration, combat, and reward transitions
- [ ] Boss encounters can trigger multi-phase combat behavior and return structured floor-complete or run-complete outcomes
- [ ] Clearing a non-final boss advances the run into the next floor with deterministic floor-state initialization
- [ ] Defeating the final boss or dying marks the run as complete and routes into the run-end flow
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity check passes: `make verify`

## Implementation Notes

- Keep floor generation deterministic and seed-driven to support later Daily Void reuse.
- Preserve the Phase 04 reward loop by treating floor-complete rewards as an extension of reward routing rather than a separate ad hoc flow.
- Use authored floor templates plus deterministic generation rules; do not hardcode boss access directly in scene scripts.
- Boss design should express counterplay but does not need final polish effects yet.
- If run-end progression data shape is incomplete, return a structured placeholder and finish persistence in Phase 06.
- Do NOT implement persistent save/load, Echo Shard spending, or unlock resolution here; those belong to Phase 06.
