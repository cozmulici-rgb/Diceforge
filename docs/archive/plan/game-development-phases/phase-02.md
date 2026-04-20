# Phase 02: Run Start And Exploration Shell

## Objective

Replace the static bootstrap with a playable start-run flow and a minimal exploration loop. This phase makes the player able to start a run, enter a room graph shell, and trigger encounters from exploration.

## Dependencies

- Depends on: Phase 01
- Enables: Phase 03

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scenes/screens/start_menu.tscn` | Start-run menu scene |
| `game/scenes/screens/exploration_screen.tscn` | Exploration runtime scene |
| `game/scripts/screens/start_menu_controller.gd` | Handles archetype selection and new-run launch |
| `game/scripts/exploration/exploration_controller.gd` | Owns room traversal shell and encounter entry |
| `game/scripts/exploration/room_graph.gd` | Represents reachable room topology |
| `game/scripts/exploration/room_state.gd` | Tracks room type, reveal state, and completion state |
| `game/scripts/player/player_controller.gd` | Handles top-down movement input in exploration scenes |
| `game/content/rooms/tutorial_rooms.json` | Seed room graph and room type content |
| `game/tests/test_exploration_flow.gd` | Verifies start-run into exploration transition |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `game/scripts/app_root.gd` | Route between start menu and exploration scenes |
| `game/scripts/core/game_state_coordinator.gd` | Support room entry, current-room tracking, and encounter trigger state |
| `game/scripts/core/run_session.gd` | Add current room, floor, and reveal-tracking fields |
| `game/scripts/content/content_catalog.gd` | Load room graph and room definitions |
| `game/scripts/ui/hud_controller.gd` | Display room and run-state basics during exploration |
| `game/tests/test_runner.gd` | Register exploration tests |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | Bootstrap compatibility can remain until the exploration shell is stable |

## Interface & Contract Changes

This phase begins implementing:

```text
interface GameStateCoordinator
  create_run_session(archetype_id: String) -> RunSession
  enter_room(room_id: String) -> RoomTransitionResult
  begin_encounter(encounter_id: String) -> EncounterStartResult
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Start run loads a valid archetype into a new session | Integration | `game/tests/test_run_session.gd` |
| Encounter start transitions exploration state into combat state | Integration | `game/tests/test_exploration_flow.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] The player can select a starter archetype from a start menu
- [ ] Starting a run creates a valid exploration session with a current room and visible HUD state
- [ ] Exploration input can move through at least a tutorial room shell and trigger a stub encounter transition
- [ ] Room reveal and completion state are tracked in `RunSession`
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity check passes: `make verify`

## Implementation Notes

- Keep exploration state minimal: one starter floor with deterministic room definitions is enough here.
- Encounter transition may still hand off to a stub combat scene in this phase; full combat belongs to Phase 03.
- Preserve separation between authored room content and mutable room completion state.
