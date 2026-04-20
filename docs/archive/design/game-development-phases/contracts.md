# Contracts: Game Development Phases

## Overview

This project currently has no HTTP API. The contracts below define gameplay-facing scene/service interfaces and the optional external leaderboard API needed by later phases.

## Internal Runtime Interfaces

### `GameStateCoordinator`

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

### `ContentCatalog`

```text
interface ContentCatalog
  load_archetype(id: String) -> ArchetypeDefinition | MissingContent
  load_floor_template(id: String) -> FloorDefinition | MissingContent
  load_encounter(id: String) -> EncounterDefinition | MissingContent
  load_reward_table(id: String) -> RewardTableDefinition | MissingContent
  load_part_definition(id: String) -> BodyDefinition | FaceDefinition | RuneDefinition | MissingContent
  validate_saved_state(state: SavedState) -> ValidationResult
```

### `CombatController`

```text
interface CombatController
  begin_encounter(run_state: RunState, encounter: EncounterDefinition) -> CombatState
  roll_active_dice(state: CombatState) -> RollResultSet
  assign_die_to_action(state: CombatState, die_id: String, action_slot_id: String) -> CombatState | RuleViolation
  resolve_player_turn(state: CombatState) -> CombatState
  resolve_enemy_turn(state: CombatState) -> CombatState
  finish_encounter(state: CombatState) -> EncounterResolution
```

### `ForgeAssemblySystem`

```text
interface ForgeAssemblySystem
  preview_change(active_die: DieBuild, mutation: ForgeMutation, inventory: RunInventory) -> ForgePreview | RuleViolation
  apply_change(active_die: DieBuild, mutation: ForgeMutation, inventory: RunInventory) -> ForgeResult | RuleViolation
  validate_die_build(die_build: DieBuild) -> ValidationResult
```

### `MetaProgressionController`

```text
interface MetaProgressionController
  process_run_end(outcome: RunOutcome, meta_state: MetaState) -> ProgressionResult
  spend_echo_shards(cost: Integer, unlock_id: String, meta_state: MetaState) -> MetaState | RuleViolation
  list_available_unlocks(meta_state: MetaState) -> UnlockCatalogView
  evaluate_achievements(run_summary: RunSummary, meta_state: MetaState) -> AchievementResultSet
```

### `PersistenceService`

```text
interface PersistenceService
  save_run_state(slot_id: String, run_state: RunState) -> SaveResult
  load_run_state(slot_id: String) -> RunState | LoadFailure
  save_meta_state(meta_state: MetaState) -> SaveResult
  load_meta_state() -> MetaState | LoadFailure
  delete_corrupt_run_state(slot_id: String) -> DeleteResult
```

### `LeaderboardGateway`

```text
interface LeaderboardGateway
  submit_daily_score(entry: DailyScoreEntry) -> SubmitResult | GatewayFailure
  fetch_daily_leaderboard(seed_id: String) -> LeaderboardSnapshot | GatewayFailure
```

## Runtime Data Contracts

### `RunSession`

```json
{
  "session_id": "string",
  "archetype_id": "string",
  "floor_index": 1,
  "current_room_id": "string",
  "player_state": {
    "hp": 0,
    "status_effects": []
  },
  "active_dice": [],
  "inventory": {
    "bodies": [],
    "faces": [],
    "runes": [],
    "currencies": {}
  },
  "modifiers": [],
  "flags": {}
}
```

### `EncounterResolution`

```json
{
  "outcome": "victory | defeat | retreat",
  "player_hp_after": 0,
  "rewards_unlocked": [],
  "echo_shards_awarded": 0,
  "boss_defeated": false,
  "run_complete": false
}
```

### `ForgeMutation`

```json
{
  "target_die_id": "string",
  "operation": "attach_face | replace_face | socket_rune | swap_body | remove_part",
  "part_id": "string",
  "slot_id": "string"
}
```

### `ProgressionResult`

```json
{
  "echo_shards_total": 0,
  "new_unlock_ids": [],
  "achievement_ids": [],
  "daily_void_result": {
    "seed_id": "string",
    "score": 0,
    "submission_status": "not_attempted | submitted | unavailable"
  }
}
```

## Optional External API Contract

### `POST /daily-void/scores`

Used only if online leaderboard support is approved in Phase 6.

```http
POST /daily-void/scores
Content-Type: application/json
Authorization: Bearer <client token or signed session>
```

Request:

```json
{
  "seed_id": "2026-03-22",
  "score": 183450,
  "run_summary": {
    "archetype_id": "pyroclast",
    "floors_cleared": 4,
    "bosses_defeated": 1
  }
}
```

Response `202 Accepted`:

```json
{
  "status": "accepted",
  "rank": 17,
  "submitted_at": "2026-03-22T18:00:00Z"
}
```

Response `400 Bad Request`:

```json
{
  "message": "Invalid score submission"
}
```

Response `401 Unauthorized`:

```json
{
  "message": "Unauthorized"
}
```

Response `503 Service Unavailable`:

```json
{
  "message": "Leaderboard unavailable"
}
```

## Validation Rules

- `archetype_id`, content ids, and part ids must exist in the content catalog before runtime use.
- Combat assignments may only target legal action slots and currently rolled dice.
- Forge mutations may only consume parts present in run inventory and must respect slot compatibility rules.
- Meta progression spends must not reduce Echo Shards below zero.
- Save payloads must reject unknown schema versions or malformed content references.

## Security Considerations

- Save files are treated as untrusted input and require schema/version validation.
- If an online leaderboard is introduced, score submission requires request authentication and server-side validation policy.
- Runtime contracts avoid direct mutation of global state outside the coordinator and dedicated services.

## Out of Scope

- Backend contract for account management.
- Matchmaking or multiplayer networking.
- Remote authoritative combat simulation.
