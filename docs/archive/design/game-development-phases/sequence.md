# Sequence Diagrams: Game Development Phases

## 1. Primary Success Scenario: Start Run To First Resolved Encounter

```mermaid
sequenceDiagram
    participant Player
    participant Router as App Root / Router
    participant State as Game State Coordinator
    participant Content as Content Catalog
    participant Explore as Exploration Controller
    participant Combat as Combat Controller
    participant Rewards as Reward Controller
    participant UI as HUD / Menus

    Player->>Router: Start new run
    Router->>State: create_run_session()
    State->>Content: load_starting_archetype_and_room_data()
    Content-->>State: starter definitions
    State->>Explore: initialize_floor(starter definitions)
    Explore-->>State: first room ready
    State->>UI: render room + HUD
    Player->>Explore: move into encounter room
    Explore->>State: encounter_triggered()
    State->>Combat: begin_encounter(run state, encounter data)
    Combat-->>UI: show rolled dice and actions
    Player->>Combat: assign dice to actions
    Combat->>Combat: resolve player turn
    Combat->>Combat: resolve enemy turn
    Combat-->>State: encounter_result(victory, damage, rewards)
    State->>Rewards: open_reward_flow(encounter_result)
    Rewards-->>State: updated inventory / dice parts
    State->>UI: render updated run state
```

## 2. Error Scenario: Invalid Save Or Content Load At Startup

```mermaid
sequenceDiagram
    participant Player
    participant Router as App Root / Router
    participant Persistence
    participant Content as Content Catalog
    participant UI as HUD / Menus

    Player->>Router: Continue run / open progression
    Router->>Persistence: load_saved_state()
    Persistence-->>Router: saved data payload
    Router->>Content: validate_content_dependencies(saved data)
    Content-->>Router: validation failure
    Router->>Router: discard invalid runtime hydration
    Router->>UI: show recovery message and safe fallback options
    UI-->>Player: prompt for new run or reset progression view
```

## 3. Edge Scenario: Invalid Forge Mutation

```mermaid
sequenceDiagram
    participant Player
    participant UI as Forge UI
    participant Rewards as Reward Controller
    participant Forge as Forge Assembly System
    participant State as Game State Coordinator

    Player->>UI: attach rune to die face
    UI->>Rewards: submit_forge_change(change request)
    Rewards->>Forge: validate_and_apply(change request, inventory, active dice)
    Forge-->>Rewards: invalid combination / missing part / locked slot
    Rewards-->>UI: reject change with reason
    UI-->>Player: display validation error and unchanged build
    Note over State: Run-state remains unchanged
```

## 4. End-Of-Run Success Scenario: Death Or Victory To Meta Progression

```mermaid
sequenceDiagram
    participant Combat
    participant State as Game State Coordinator
    participant Progression as Meta Progression Controller
    participant Unlocks as Unlock Registry
    participant Persistence
    participant UI as Menus

    Combat-->>State: run_complete(result, score, rewards)
    State->>Progression: process_run_end(result, current meta state)
    Progression->>Unlocks: evaluate_unlocks_and_achievements()
    Unlocks-->>Progression: unlocked content changes
    Progression->>Persistence: save_meta_state(echo shards, unlocks, achievements)
    Persistence-->>Progression: save successful
    Progression-->>UI: show run summary and newly unlocked content
```

## 5. External Integration Scenario: Daily Void Score Submission

```mermaid
sequenceDiagram
    participant Player
    participant Progression as Daily Void Mode Adapter
    participant Gateway as Leaderboard Gateway
    participant Service as Leaderboard Service
    participant UI as Menus

    Player->>Progression: finish daily run
    Progression->>Gateway: submit_score(seed, score, build summary)
    Gateway->>Service: POST daily score payload
    alt Service available
        Service-->>Gateway: accepted + rank snapshot
        Gateway-->>Progression: submission success
        Progression-->>UI: show rank and leaderboard state
    else Service unavailable
        Service--xGateway: timeout / error
        Gateway-->>Progression: unavailable
        Progression-->>UI: show local result and unavailable status
    end
```

## Covered Scenarios

- New run initialization and first encounter
- Invalid save or content recovery path
- Invalid forge action rejection
- Run completion and progression persistence
- Optional leaderboard integration success and failure
