# Phase 06: Persistence And Meta Progression

## Objective

Implement permanent progression, save validation, and the post-run loop. This phase makes Echo Shards, unlocks, achievements, and local save/load part of the playable game.

## Dependencies

- Depends on: Phase 05
- Enables: Phase 07

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scripts/persistence/persistence_service.gd` | Save and load run-state and meta-state |
| `game/scripts/persistence/save_schema.gd` | Central schema/version validation helpers |
| `game/scripts/progression/meta_progression_controller.gd` | Awards Echo Shards and resolves unlocks |
| `game/scripts/progression/unlock_registry.gd` | Stores unlock state and lookup helpers |
| `game/scripts/progression/achievement_tracker.gd` | Evaluates achievement conditions |
| `game/scenes/screens/progression_screen.tscn` | Run-end and Eternal Forge summary screen |
| `game/scripts/screens/progression_screen_controller.gd` | Displays shard gains, unlocks, and achievement results |
| `game/content/progression/unlocks.json` | Permanent unlock definitions |
| `game/content/progression/achievements.json` | Achievement definitions |
| `game/tests/test_persistence_service.gd` | Save/load validation and corruption handling tests |
| `game/tests/test_meta_progression.gd` | Echo Shard, unlock, and achievement tests |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `game/scripts/core/game_state_coordinator.gd` | Load save data, finalize runs, and route to progression screens |
| `game/scripts/core/run_session.gd` | Support serialization-friendly runtime fields |
| `game/scripts/content/content_catalog.gd` | Load unlock and achievement definitions |
| `game/scripts/rewards/run_inventory.gd` | Distinguish run-only vs persistent data where needed |
| `game/scripts/app_root.gd` | Offer continue-run and progression navigation paths |
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
```

```text
interface MetaProgressionController
  process_run_end(outcome: RunOutcome, meta_state: MetaState) -> ProgressionResult
  spend_echo_shards(cost: Integer, unlock_id: String, meta_state: MetaState) -> MetaState | RuleViolation
  list_available_unlocks(meta_state: MetaState) -> UnlockCatalogView
  evaluate_achievements(run_summary: RunSummary, meta_state: MetaState) -> AchievementResultSet
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Run completion awards Echo Shards and unlocks | Integration | `game/tests/test_meta_progression.gd` |
| Corrupt save file falls back safely | Integration | `game/tests/test_persistence_service.gd` |
| Save file with unknown schema version is rejected | Unit | `game/tests/test_persistence_service.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] Run-end results award Echo Shards and evaluate unlocks/achievements
- [ ] Meta progression can be viewed from a dedicated progression screen
- [ ] Run-state and meta-state can be saved and loaded locally through `PersistenceService`
- [ ] Corrupt or schema-incompatible save files are rejected safely without hydrating invalid runtime state
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity check passes: `make verify`

## Implementation Notes

- Maintain the separation between run-state and meta-state from `dataflow.md` and ADR-002.
- Treat all saved data as untrusted input; validation is part of the feature, not cleanup.
- Do NOT make online services a dependency of progression; Daily Void networking remains Phase 07.
