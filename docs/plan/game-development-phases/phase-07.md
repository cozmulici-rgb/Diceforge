# Phase 07: Daily Void, Modifiers, And Final Validation

## Objective

Complete the planned feature set with curses, blessings, Daily Void mode, and final validation hooks. This phase also isolates optional online leaderboard behavior behind a gateway while keeping the mode fully functional offline.

## Dependencies

- Depends on: Phase 06
- Enables: Full feature completion

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scripts/modes/daily_void_mode_adapter.gd` | Builds deterministic daily challenge sessions |
| `game/scripts/integrations/leaderboard_gateway.gd` | Optional leaderboard boundary per ADR-003 |
| `game/scripts/modifiers/modifier_registry.gd` | Applies curses and blessings to runs |
| `game/scripts/modifiers/modifier_effect.gd` | Structured modifier payload used by combat and run-state systems |
| `game/scripts/modes/daily_score_entry.gd` | Structured Daily Void score submission payload |
| `game/content/modifiers/curses.json` | Curse definitions |
| `game/content/modifiers/blessings.json` | Blessing definitions |
| `game/content/modes/daily_void.json` | Daily mode configuration and score rules |
| `game/tests/test_daily_void_mode.gd` | Seeded run and gateway fallback tests |
| `game/tests/test_modifier_registry.gd` | Modifier application tests |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `game/scripts/core/game_state_coordinator.gd` | Start Daily Void runs, thread modifier state through run creation, and preserve offline-first result handling |
| `game/scripts/core/run_session.gd` | Track modifier state, seed id, daily-mode metadata, and score summary fields |
| `game/scripts/content/content_catalog.gd` | Load modifier and daily-mode definitions and validate leaderboard-facing score rules content |
| `game/scripts/combat/combat_controller.gd` | Respect modifier-driven combat rule changes without embedding network concerns |
| `game/scripts/exploration/dungeon_generator.gd` | Accept seeded generation inputs for Daily Void |
| `game/scripts/progression/meta_progression_controller.gd` | Calculate Daily Void result payloads |
| `game/scripts/progression/meta_state.gd` | Persist Daily Void history and last submission outcome metadata |
| `game/scripts/persistence/persistence_service.gd` | Save and reload Daily Void history through the existing meta-state flow |
| `game/scripts/persistence/save_schema.gd` | Validate Daily Void result payloads and any new meta-state schema fields |
| `game/scripts/app_root.gd` | Route Daily Void start, completion, and progression return flow |
| `game/scripts/screens/start_menu_controller.gd` | Expose Daily Void start option |
| `game/scripts/screens/progression_screen_controller.gd` | Show Daily Void submission status and local results |
| `game/tests/test_content_catalog.gd` | Validate modifier and Daily Void content references |
| `game/tests/test_runner.gd` | Register Daily Void and modifier tests |
| `README.md` | Document the playable feature set and local-only Daily Void expectations |
| `docs/setup.md` | Document any new test or mode-specific verification steps |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | No deletions required in this phase |

## Interface & Contract Changes

New interface implemented from `contracts.md`:

```text
interface LeaderboardGateway
  submit_daily_score(entry: DailyScoreEntry) -> SubmitResult | GatewayFailure
  fetch_daily_leaderboard(seed_id: String) -> LeaderboardSnapshot | GatewayFailure
```

This phase also makes the Daily Void mode boundary explicit so seeded runs do not leak special-case logic into unrelated systems:

```text
interface DailyVoidModeAdapter
  create_daily_run_config(calendar_day: String, meta_state: MetaState) -> DailyVoidRunConfig
  create_daily_run_session(config: DailyVoidRunConfig, archetype_id: String) -> RunSession
  finalize_daily_result(run_state: RunSession, progression_result: ProgressionResult) -> ProgressionResult
```

Supporting runtime payloads introduced or made explicit in this phase:

```text
DailyVoidRunConfig
  seed_id: String
  numeric_seed: int
  modifier_ids: Array[String]
  scoring_rule_id: String
  allowed_archetype_ids: Array[String]
```

```text
ModifierEffect
  modifier_id: String
  modifier_type: curse | blessing
  application_scope: run | combat | reward | exploration
  effect_tags: Array[String]
  stack_mode: unique | stackable | replace
```

```text
DailyScoreEntry
  seed_id: String
  score: int
  run_summary: Dictionary
  submission_context: local_only | online_attempt
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Deterministic Daily Void config produces the same run seed and modifier set for the same calendar day | Unit | `game/tests/test_daily_void_mode.gd` |
| Daily Void score submission handles service outage | Integration | `game/tests/test_daily_void_mode.gd` |
| Leaderboard request without valid authorization is rejected | Integration | `game/tests/test_daily_void_mode.gd` |
| Daily Void seeded run setup and leaderboard gateway fallback behavior | Integration | `game/tests/test_daily_void_mode.gd` |
| Modifier application remains deterministic and isolated from unrelated combat state | Unit | `game/tests/test_modifier_registry.gd` |
| Daily Void, curse, and blessing definitions resolve referenced ids correctly | Validation | `game/tests/test_content_catalog.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] Daily Void can start from a fixed seed and produce a deterministic local run
- [ ] The same calendar day and content set always produce the same Daily Void config, floor generation seed, and modifier bundle
- [ ] Curses and blessings can alter run-state and combat behavior through a dedicated modifier system
- [ ] Daily Void remains playable if the leaderboard service is absent or unavailable
- [ ] Daily Void score results are preserved locally even when submission fails or is skipped
- [ ] Daily Void completion writes local history through the existing meta-state persistence path
- [ ] Online leaderboard communication, if configured, is isolated behind `LeaderboardGateway`
- [ ] Modifier definitions remain data-driven and can be validated without executing full combat scenes
- [ ] Player-facing docs describe the completed local feature set and verification flow
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity checks pass: `make verify` and `make export`

## Implementation Notes

- Offline Daily Void behavior is not optional; online ranking is optional.
- Do not leak network behavior into core combat, exploration, persistence, or progression components.
- Follow `sequence.md` and `dataflow.md` by handling leaderboard failures as non-blocking result states, not hard runtime errors.
- Reuse the existing Phase 05 deterministic generation and Phase 06 persistence boundaries instead of introducing a parallel Daily Void save path.
- Keep Daily Void seed derivation deterministic and explicit so test fixtures can reproduce exact floor, reward, and modifier states.
- Keep modifier rules data-driven where practical so balance iteration stays in content files rather than controller code.
- Do NOT introduce mandatory backend dependencies, account systems, or cloud save requirements as part of Daily Void completion.
