# Testing Strategy: Game Development Phases

## Strategy

The current repository only validates project boot and export. The gameplay build needs tests organized around deterministic state transitions, content validation, persistence safety, and optional external integration failure handling.

### Unit Tests

- Dice domain calculations and rune interaction rules
- Combat turn resolution and action assignment validation
- Forge mutation validation and die-build legality checks
- Progression reward calculations, achievement checks, and unlock gating
- Persistence schema validation and corrupt save rejection

### Integration Tests

- Start-run flow from archetype selection into first room
- Exploration-to-combat transition and post-combat reward transition
- Full encounter resolution against representative enemy definitions
- End-of-run progression persistence and later reload
- Daily Void seeded run setup and leaderboard gateway fallback behavior

### Content Validation Tests

- All content definitions resolve referenced ids correctly
- Boss and encounter definitions map to valid rewards and floors
- Unlock tables reference existing bodies, faces, runes, and archetypes

### Tooling Expectations

- Existing `make verify` remains the minimal project integrity gate.
- Additional automated tests should be runnable headlessly in CI-compatible local environments.
- Deterministic tests should isolate randomness with seeded or injected roll sources.

## Test Cases

Test: Start run loads a valid archetype into a new session  
Type: Integration  
Scenario: A player begins a fresh run from the start flow  
Given: A valid archetype definition exists and no active run is loaded  
When: `create_run_session(archetype_id)` is called  
Then: A run session is created with the selected archetype, starting room, and starter dice state  
Covers: `GameStateCoordinator.create_run_session`

Test: Invalid archetype id is rejected at run creation  
Type: Unit  
Scenario: A caller requests a run with missing content  
Given: The content catalog does not contain the requested archetype id  
When: `create_run_session(archetype_id)` is called  
Then: The request fails without creating runtime state  
Covers: `GameStateCoordinator.create_run_session`, `ContentCatalog.load_archetype`

Test: Encounter start transitions exploration state into combat state  
Type: Integration  
Scenario: The player enters a room containing an encounter  
Given: A run session with a valid current room and encounter mapping  
When: `begin_encounter(encounter_id)` is called  
Then: Combat state is created and the exploration state is paused  
Covers: `GameStateCoordinator.begin_encounter`, `CombatController.begin_encounter`

Test: Dice assignment rejects unrolled or invalid dice ids  
Type: Unit  
Scenario: A player tries to assign a die result that is not available in the current roll set  
Given: A combat state with a known roll result set  
When: `assign_die_to_action` is called with an invalid die id  
Then: The method returns a rule violation and combat state remains unchanged  
Covers: `CombatController.assign_die_to_action`

Test: Combat resolution applies player then enemy turn in order  
Type: Integration  
Scenario: A standard encounter resolves a full round  
Given: A deterministic roll source and enemy definition  
When: Player assignments are submitted and the round is resolved  
Then: Player action effects apply before enemy turn effects and resulting hp/state are persisted in combat state  
Covers: `CombatController.resolve_player_turn`, `CombatController.resolve_enemy_turn`

Test: Forge mutation rejects incompatible rune slotting  
Type: Unit  
Scenario: A rune is applied to an incompatible slot or part type  
Given: An active die build and inventory containing the rune  
When: `apply_change` receives an invalid mutation  
Then: The mutation is rejected and the die build is unchanged  
Covers: `ForgeAssemblySystem.apply_change`

Test: Reward flow adds acquired parts into run inventory  
Type: Integration  
Scenario: Combat rewards grant a new face and currency  
Given: A completed encounter and reward table definition  
When: Reward flow resolves the selected reward  
Then: Run inventory contains the granted items and the active session reflects them  
Covers: `RewardController`, `RunInventoryModel`

Test: Dungeon generation creates a reachable boss path  
Type: Unit  
Scenario: A new floor graph is generated  
Given: A floor template and deterministic seed  
When: The dungeon generator produces a floor layout  
Then: The generated room graph contains a valid path from start room to boss room  
Covers: `DungeonGenerator`

Test: Run completion awards Echo Shards and unlocks  
Type: Integration  
Scenario: The player completes or loses a run  
Given: A run summary and current meta-state  
When: `process_run_end` is called  
Then: Echo Shards, unlocks, and achievements are evaluated and returned in a progression result  
Covers: `MetaProgressionController.process_run_end`

Test: Corrupt save file falls back safely  
Type: Integration  
Scenario: A user attempts to load malformed saved data  
Given: A save slot containing invalid schema or broken content references  
When: `load_run_state` or `load_meta_state` is called  
Then: The load fails safely, no invalid runtime state is hydrated, and recovery UI can be shown  
Covers: `PersistenceService.load_run_state`, `PersistenceService.load_meta_state`

Test: Daily Void score submission handles service outage  
Type: Integration  
Scenario: The optional leaderboard service is unavailable  
Given: A completed Daily Void run and a gateway configured to return a network failure  
When: `submit_daily_score` is called  
Then: The local result remains available and submission status reports unavailable without crashing progression flow  
Covers: `LeaderboardGateway.submit_daily_score`, `DailyVoidModeAdapter`

## Security Tests

Test: Save file with unknown schema version is rejected  
Type: Unit  
Scenario: Untrusted local save input is incompatible with the current runtime  
Given: Saved data with an unsupported schema version  
When: Validation runs before hydration  
Then: The save is rejected  
Covers: `PersistenceService`, save validation helpers

Test: Leaderboard request without valid authorization is rejected  
Type: Integration  
Scenario: The optional online leaderboard endpoint is called with missing or invalid credentials  
Given: A configured gateway and a mocked service response  
When: `submit_daily_score` is called without valid authorization context  
Then: The gateway returns an unauthorized failure result  
Covers: `LeaderboardGateway.submit_daily_score`

## Performance Risks To Observe In Testing

- Rune and synergy chains causing excessive per-turn resolution time
- Large content catalogs increasing startup load time
- Save/load latency as meta progression content expands
- UI update churn during combat animation and reward presentation

## Out of Scope

- Multiplayer load testing
- Backend leaderboard infrastructure benchmarks
- Device compatibility matrix beyond the current local Linux desktop target
