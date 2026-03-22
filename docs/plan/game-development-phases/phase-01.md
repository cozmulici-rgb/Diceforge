# Phase 01: Runtime Scaffold And Test Harness

## Objective

Establish the core gameplay project structure so later phases can add features without collapsing into one scene script. This phase creates the app root, run-state coordinator skeleton, content catalog seed, and a deterministic headless test runner.

## Dependencies

- Depends on: None
- Enables: Phase 02

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scenes/app_root.tscn` | New top-level runtime scene replacing the bootstrap shell |
| `game/scripts/app_root.gd` | App root scene controller and routing entry point |
| `game/scripts/core/game_state_coordinator.gd` | Central runtime orchestrator per ADR-001 |
| `game/scripts/core/run_session.gd` | Mutable run-session data object |
| `game/scripts/content/content_catalog.gd` | Immutable content loader and lookup service |
| `game/scripts/content/content_validator.gd` | Validates content definitions before runtime use |
| `game/content/archetypes/starter_archetypes.json` | Seed archetype definitions |
| `game/content/floors/tutorial_floor.json` | Seed floor shell definition for initial playable content |
| `game/scripts/ui/hud_controller.gd` | Minimal HUD shell for run-state display |
| `game/tests/test_runner.gd` | Headless deterministic gameplay test entry point |
| `game/tests/test_content_catalog.gd` | Verifies content load and validation behavior |
| `game/tests/test_run_session.gd` | Verifies run creation and session defaults |
| `scripts/run-godot-tests.sh` | Shell wrapper for the headless test command |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `game/project.godot` | Point the startup scene to `res://scenes/app_root.tscn` and register any required autoloads if used |
| `game/scenes/main.tscn` | Either retire the bootstrap scene from startup or repurpose it as a temporary child scene owned by app root |
| `game/scripts/main.gd` | Remove bootstrap-only behavior or convert it into a thin compatibility wrapper if retained |
| `scripts/verify-headless-build.sh` | Run the deterministic gameplay test harness after the startup smoke check |
| `Makefile` | Add a `test` target that runs `scripts/run-godot-tests.sh` via the export container |
| `README.md` | Document the new headless test command |
| `docs/setup.md` | Add test-run instructions and expected behavior |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | The bootstrap files can be retained temporarily as compatibility shims if useful |

## Interface & Contract Changes

New interfaces introduced from `contracts.md`:

```text
interface GameStateCoordinator
  create_run_session(archetype_id: String) -> RunSession
  load_run_session(save_slot_id: String) -> RunSession | LoadFailure
  enter_room(room_id: String) -> RoomTransitionResult
  begin_encounter(encounter_id: String) -> EncounterStartResult
  apply_encounter_result(result: EncounterResolution) -> RunSession
  open_reward_flow(source: RewardSource) -> RewardFlowState
  finalize_run(result: RunOutcome) -> ProgressionResult
```

```text
interface ContentCatalog
  load_archetype(id: String) -> ArchetypeDefinition | MissingContent
  load_floor_template(id: String) -> FloorDefinition | MissingContent
  load_encounter(id: String) -> EncounterDefinition | MissingContent
  load_reward_table(id: String) -> RewardTableDefinition | MissingContent
  load_part_definition(id: String) -> BodyDefinition | FaceDefinition | RuneDefinition | MissingContent
  validate_saved_state(state: SavedState) -> ValidationResult
```

## Tests to Add / Modify

Reference test cases from `docs/design/game-development-phases/testing.md`:

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Start run loads a valid archetype into a new session | Integration | `game/tests/test_run_session.gd` |
| Invalid archetype id is rejected at run creation | Unit | `game/tests/test_content_catalog.gd` |
| All content definitions resolve referenced ids correctly | Validation | `game/tests/test_content_catalog.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] Starting the project loads `res://scenes/app_root.tscn` instead of relying on the bootstrap-only `main.tscn`
- [ ] `GameStateCoordinator` can create a starter run session from seeded archetype content
- [ ] Content files under `game/content/` are loaded through `ContentCatalog` rather than hardcoded scene values
- [ ] Invalid archetype ids fail deterministically without creating runtime state
- [ ] The headless test command succeeds via `scripts/run-godot-tests.sh`
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity check passes: `make verify`

## Implementation Notes

- Keep `GameStateCoordinator` narrow in this phase: startup, content lookup, and session creation only.
- Do NOT implement combat, forge, persistence, or progression logic here; placeholders are acceptable if interfaces need them.
- Content validation must happen before runtime state hydration per `dataflow.md`.
- Avoid introducing an external test framework in this phase; use a Godot-native scripted harness aligned with the current container setup.
