# Phase 06: Persistence And Meta Progression

## Objective

Implement permanent progression, save validation, and the post-run loop. This phase makes Echo Shards, unlocks, achievements, continue-run support, and local save/load part of the playable game.

## Dependencies

- Depends on: Phase 05
- Enables: Phase 07

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scripts/persistence/persistence_service.gd` | Save and load run-state and meta-state |
| `game/scripts/persistence/save_schema.gd` | Central schema/version validation helpers |
| `game/scripts/persistence/save_slot_summary.gd` | Lightweight continue-run metadata for menu display |
| `game/scripts/progression/meta_progression_controller.gd` | Awards Echo Shards and resolves unlocks |
| `game/scripts/progression/unlock_registry.gd` | Stores unlock state and lookup helpers |
| `game/scripts/progression/achievement_tracker.gd` | Evaluates achievement conditions |
| `game/scenes/screens/progression_screen.tscn` | Run-end and Eternal Forge summary screen |
| `game/scripts/screens/progression_screen_controller.gd` | Displays shard gains, unlocks, and achievement results |
| `game/scripts/progression/meta_state.gd` | Mutable permanent progression state object |
| `game/content/progression/unlocks.json` | Permanent unlock definitions |
| `game/content/progression/achievements.json` | Achievement definitions |
| `game/tests/test_persistence_service.gd` | Save/load validation and corruption handling tests |
| `game/tests/test_meta_progression.gd` | Echo Shard, unlock, and achievement tests |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `game/scripts/core/game_state_coordinator.gd` | Load save data, save active runs, finalize runs, and route to progression screens |
| `game/scripts/core/run_session.gd` | Support serialization-friendly runtime fields and versioned save payload mapping |
| `game/scripts/content/content_catalog.gd` | Load unlock and achievement definitions and validate progression content references |
| `game/scripts/rewards/run_inventory.gd` | Distinguish run-only vs persistent data where needed |
| `game/scripts/app_root.gd` | Offer continue-run, safe recovery fallback, and progression navigation paths |
| `game/scripts/screens/start_menu_controller.gd` | Surface continue-run availability and unlocked archetype options |
| `game/tests/test_runner.gd` | Register persistence and progression tests |
| `scripts/verify-headless-build.sh` | Ensure headless validation includes persistence-related tests through the shared test harness |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | No deletions required in this phase |

## Interface & Contract Changes

New interfaces implemented from `contracts.md`:

```text
interface PersistenceService
  save_run_state(slot_id: String, run_state: RunState) -> SaveResult
  load_run_state(slot_id: String) -> RunState | LoadFailure
  save_meta_state(meta_state: MetaState) -> SaveResult
  load_meta_state() -> MetaState | LoadFailure
  delete_corrupt_run_state(slot_id: String) -> DeleteResult
  list_run_slots() -> Array[SaveSlotSummary]
```

```text
interface MetaProgressionController
  process_run_end(outcome: RunOutcome, meta_state: MetaState) -> ProgressionResult
  spend_echo_shards(cost: Integer, unlock_id: String, meta_state: MetaState) -> MetaState | RuleViolation
  list_available_unlocks(meta_state: MetaState) -> UnlockCatalogView
  evaluate_achievements(run_summary: RunSummary, meta_state: MetaState) -> AchievementResultSet
```

Supporting runtime payloads made explicit in this phase:

```text
MetaState
  schema_version: int
  echo_shards: int
  unlocked_archetype_ids: Array[String]
  unlocked_part_ids: Array[String]
  unlocked_upgrade_ids: Array[String]
  achievement_ids: Array[String]
  daily_void_history: Array[Dictionary]
```

```text
SaveSlotSummary
  slot_id: String
  session_id: String
  archetype_id: String
  floor_index: int
  room_id: String
  updated_at_unix: int
  is_corrupt: bool
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Run completion awards Echo Shards and unlocks | Integration | `game/tests/test_meta_progression.gd` |
| Corrupt save file falls back safely | Integration | `game/tests/test_persistence_service.gd` |
| Save file with unknown schema version is rejected | Unit | `game/tests/test_persistence_service.gd` |
| Unlock tables reference existing bodies, faces, runes, and archetypes | Validation | `game/tests/test_content_catalog.gd` |
| End-of-run progression persistence and later reload | Integration | `game/tests/test_meta_progression.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] Run-end results award Echo Shards and evaluate unlocks/achievements
- [ ] Progression processing persists meta-state changes without mutating live run-state after completion
- [ ] Meta progression can be viewed from a dedicated progression screen
- [ ] Run-state and meta-state can be saved and loaded locally through `PersistenceService`
- [ ] Start-run flow can detect an existing valid run slot and offer a continue-run path
- [ ] Corrupt or schema-incompatible save files are rejected safely without hydrating invalid runtime state
- [ ] Recovery UI or fallback routing is available when a saved run or meta-state payload fails validation
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity check passes: `make verify`

## Implementation Notes

- Maintain the separation between run-state and meta-state from `dataflow.md` and ADR-002.
- Treat all saved data as untrusted input; validation is part of the feature, not cleanup.
- Follow the startup recovery path from `sequence.md` and `dataflow.md`: invalid saved data must fail closed and route to safe defaults.
- Keep schema/version checks centralized in `save_schema.gd`; do not scatter ad hoc validation across screens.
- Save slot summaries should be lightweight enough to inspect without fully hydrating a run.
- Do NOT make online services a dependency of progression; Daily Void networking remains Phase 07.
