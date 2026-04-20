# Phase 07 Breakdown: Daily Void, Modifiers, And Final Validation

## Purpose

Translate [Phase 07](/Users/vcozmulici/workspace/ai/Diceforge/docs/plan/game-development-phases/phase-07.md) into an execution sequence that can be implemented incrementally without breaking the existing offline run loop.

## Delivery Strategy

Phase 07 should be built in five slices:

1. Modifier data model and content validation
2. Runtime modifier application in combat and run-state
3. Daily Void deterministic run creation
4. Daily Void result persistence and optional leaderboard submission
5. Final validation, docs, and export gates

The ordering matters:

- Modifiers come first because Daily Void depends on them for challenge rules.
- Deterministic run creation comes before submission because score handling is meaningless until runs are reproducible.
- Local persistence comes before optional online submission because ADR-003 requires offline-first completion.

## Slice 1: Modifier Data Model And Content Validation

### Goal

Introduce the modifier domain without changing live gameplay behavior yet.

### Primary Files

- `game/scripts/modifiers/modifier_effect.gd`
- `game/scripts/modifiers/modifier_registry.gd`
- `game/content/modifiers/curses.json`
- `game/content/modifiers/blessings.json`
- `game/scripts/content/content_catalog.gd`
- `game/tests/test_modifier_registry.gd`
- `game/tests/test_content_catalog.gd`

### Implementation Tasks

- Define `ModifierEffect` as the canonical runtime payload.
- Add content loading for curse and blessing definitions.
- Validate modifier ids, scopes, stack modes, and referenced effect tags.
- Add unit tests for deterministic modifier parsing and registry lookup.
- Extend content validation tests so malformed modifier content fails before runtime.

### Exit Criteria

- Modifier content loads through `ContentCatalog`.
- Invalid modifier content fails deterministically.
- No runtime systems depend on ad hoc modifier dictionaries.

## Slice 2: Runtime Modifier Application

### Goal

Thread modifier state through `RunSession` and apply effects through a dedicated boundary instead of embedding rules directly in combat flow.

### Primary Files

- `game/scripts/core/run_session.gd`
- `game/scripts/core/game_state_coordinator.gd`
- `game/scripts/combat/combat_controller.gd`
- `game/scripts/modifiers/modifier_registry.gd`
- `game/tests/test_modifier_registry.gd`
- `game/tests/test_combat_controller.gd`

### Implementation Tasks

- Add modifier storage fields to `RunSession`.
- Decide the minimal supported scopes for the first pass:
  `run` and `combat` first, with `reward` and `exploration` only if needed by authored content.
- Add an application API that produces derived combat or run-state adjustments without network or UI dependencies.
- Update combat setup to read modifier-derived adjustments from the registry.
- Add tests proving modifier application is deterministic and isolated from unrelated combat state.

### Exit Criteria

- A run can carry active modifiers without breaking existing non-Daily flow.
- Combat behavior changes route through the modifier system, not special-case conditionals spread across controllers.
- Existing combat and reward tests still pass after modifier threading.

## Slice 3: Daily Void Deterministic Run Creation

### Goal

Create a reproducible Daily Void run from a calendar day and the current content set.

### Primary Files

- `game/scripts/modes/daily_void_mode_adapter.gd`
- `game/scripts/core/game_state_coordinator.gd`
- `game/scripts/core/run_session.gd`
- `game/scripts/exploration/dungeon_generator.gd`
- `game/scripts/screens/start_menu_controller.gd`
- `game/content/modes/daily_void.json`
- `game/tests/test_daily_void_mode.gd`

### Implementation Tasks

- Define `DailyVoidRunConfig` generation rules from `calendar_day`.
- Produce explicit deterministic inputs:
  `seed_id`, `numeric_seed`, `modifier_ids`, `allowed_archetype_ids`, and scoring rule id.
- Reuse Phase 05 floor generation instead of creating a parallel dungeon path.
- Add start-menu wiring for a Daily Void entry point.
- Record Daily Void metadata inside `RunSession`.
- Add tests proving the same day produces the same config and seeded run setup.

### Exit Criteria

- Starting Daily Void creates a reproducible local run.
- The run uses the standard exploration/combat/reward loop with seeded inputs, not a separate rules engine.
- Different days can produce different configs without breaking determinism for a given day.

## Slice 4: Result Persistence And Optional Leaderboard Submission

### Goal

Finalize Daily Void outcomes through the existing progression path, save local history, and isolate any optional submission behind `LeaderboardGateway`.

### Primary Files

- `game/scripts/modes/daily_void_mode_adapter.gd`
- `game/scripts/modes/daily_score_entry.gd`
- `game/scripts/integrations/leaderboard_gateway.gd`
- `game/scripts/progression/meta_progression_controller.gd`
- `game/scripts/progression/meta_state.gd`
- `game/scripts/persistence/persistence_service.gd`
- `game/scripts/persistence/save_schema.gd`
- `game/scripts/screens/progression_screen_controller.gd`
- `game/tests/test_daily_void_mode.gd`
- `game/tests/test_persistence_service.gd`

### Implementation Tasks

- Define `DailyScoreEntry` and any local submission status fields.
- Extend `MetaState` to store Daily Void history and last-known submission outcome.
- Save Daily Void results through the existing meta-state persistence flow.
- Keep `LeaderboardGateway` optional and failure-tolerant.
- Treat unavailable, unauthorized, and skipped submission states as non-fatal progression outcomes.
- Add tests for:
  local result preservation,
  service outage handling,
  unauthorized submission handling,
  schema validation for stored Daily Void history.

### Exit Criteria

- Completing a Daily Void run updates local history even when no service exists.
- Submission failure never invalidates the run result or blocks progression UI.
- No combat or exploration code depends on gateway availability.

## Slice 5: Final Validation And Docs

### Goal

Close the phase with stable automation and user-facing documentation.

### Primary Files

- `game/tests/test_runner.gd`
- `README.md`
- `docs/setup.md`
- `scripts/run-godot-tests.sh`
- `scripts/verify-headless-build.sh`
- `Makefile`

### Implementation Tasks

- Register Daily Void and modifier tests in the shared headless runner.
- Confirm `make verify` still covers the required validation path.
- Confirm `make export` remains green after the Phase 07 additions.
- Document local-only Daily Void behavior and optional leaderboard expectations.
- Document any environment assumptions for submission mocking or offline fallback tests.

### Exit Criteria

- Headless test flow covers Daily Void and modifier behavior.
- `make verify` passes.
- `make export` passes.
- Docs describe the completed local feature set accurately.

## Recommended Commit Sequence

1. `game: add modifier content model and validation`
2. `game: thread modifiers into run and combat state`
3. `game: add deterministic daily void run setup`
4. `game: persist daily void results and gateway fallback`
5. `docs: finalize daily void verification and setup notes`

## Risk Notes

- The main regression risk is leaking Daily Void branches into normal run creation. Keep all mode-specific branching inside `DailyVoidModeAdapter` and coordinator entry points.
- The next largest risk is overloading `CombatController` with effect-specific rules. Prefer derived modifier outputs over direct content lookups during turn resolution.
- Persistence changes must stay schema-versioned. Do not append unvalidated Daily Void payloads directly into save data.
- Avoid implementing real network coupling in tests. Gateway tests should use deterministic stubs or mocked failure responses.

## Done Checklist

- [x] Modifier content is data-driven and validated
- [x] Modifier effects apply deterministically to runtime state
- [x] Daily Void run creation is deterministic for a given calendar day
- [x] Daily Void results persist locally through meta-state
- [x] Leaderboard submission remains optional and isolated
- [x] Daily Void failure states are non-blocking
- [x] Headless tests cover the new mode and modifier paths
- [x] `make verify` passes
- [x] `make export` passes
