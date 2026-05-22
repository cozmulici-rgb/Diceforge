# Architecture: Game Development Phases

## Scope

This design defines the target architecture needed to deliver the six game development phases identified in `docs/research/game-development-phases.md`. The system remains a single-player Godot 4 application with local tooling for verification and export.

## Context Diagram

```mermaid
graph TD
    Player["Player<br/>Modified: interacts with all gameplay phases"] --> Game["Diceforge Godot Client<br/>Modified: grows from bootstrap into playable game"]
    Designer["Developer / Content Author<br/>Modified: creates content definitions and balance data"] --> Game
    Game --> LocalSave["Local Save Storage<br/>Created: run and meta progression persistence"]
    Game --> BuildFlow["Local Verify/Export Tooling<br/>Unchanged: Docker + make + headless verification"]
    Game --> Leaderboard["Daily Void Leaderboard Service<br/>Created in Phase 6 if online mode is approved"]
```

### Context Notes

- The player interacts only with the Godot client.
- Local save storage is required once run-state and meta-state persistence are introduced.
- Build and export tooling already exists and remains outside gameplay scope.
- The leaderboard service is conditional because the research document identifies it as an unresolved scope question.

## Container Diagram

```mermaid
graph TD
    subgraph Workstation["Player / Developer Workstation"]
        Game["Godot Runtime Client<br/>Modified"]
        Save["Save Files / Persistence Layer<br/>Created"]
        Content["Game Content Definitions<br/>Created"]
        Verify["Docker Verify & Export Workflow<br/>Unchanged"]
    end

    External["Leaderboard Backend API<br/>Created if approved"]:::external

    Game --> Save
    Game --> Content
    Game --> Verify
    Game --> External

    classDef external fill:#f5f5f5,stroke:#666,stroke-dasharray: 5 5;
```

### Container Notes

- `Godot Runtime Client` is the only gameplay container and owns all runtime orchestration.
- `Save Files / Persistence Layer` covers local run-state checkpoints and permanent progression data.
- `Game Content Definitions` store archetypes, dice parts, enemy kits, encounters, and progression unlock data.
- `Docker Verify & Export Workflow` remains unchanged and continues to validate project integrity.

## Component Diagram

```mermaid
graph TD
    AppRoot["App Root / Scene Router<br/>Modified"] --> GameState["Game State Coordinator<br/>Created"]
    AppRoot --> UI["HUD + Menus + Forge UI<br/>Created"]

    GameState --> Exploration["Exploration Controller<br/>Created"]
    GameState --> Combat["Combat Controller<br/>Created"]
    GameState --> Rewards["Reward / Event Controller<br/>Created"]
    GameState --> Progression["Meta Progression Controller<br/>Created"]
    GameState --> Persistence["Persistence Service<br/>Created"]
    GameState --> ContentRepo["Content Catalog / Definitions<br/>Created"]

    Combat --> DiceModel["Dice Domain Model<br/>Created"]
    Combat --> EnemyModel["Enemy Encounter Model<br/>Created"]
    Rewards --> Forge["Forge Assembly System<br/>Created"]
    Rewards --> Inventory["Run Inventory Model<br/>Created"]
    Exploration --> Dungeon["Dungeon / Floor Generator<br/>Created"]
    Progression --> Unlocks["Unlock Registry<br/>Created"]
    Progression --> DailyVoid["Daily Void Mode Adapter<br/>Created in Phase 6"]
    DailyVoid --> LeaderboardGateway["Leaderboard Gateway<br/>Created if online mode is approved"]

    Persistence --> SaveFiles["Run Save + Meta Save Files<br/>Created"]
```

### Component Responsibilities

| Component | State | Responsibility |
|-----------|-------|----------------|
| App Root / Scene Router | Modified | Replaces the bootstrap scene with screen and state routing. |
| Game State Coordinator | Created | Owns phase transitions between menus, exploration, combat, rewards, and progression updates. |
| HUD + Menus + Forge UI | Created | Presents core game state, action choices, rewards, and progression screens. |
| Exploration Controller | Created | Runs room traversal, fog-of-war reveal state, and encounter entry. |
| Combat Controller | Created | Runs dice rolling, action assignment, turn sequencing, enemy turns, and encounter outcomes. |
| Reward / Event Controller | Created | Resolves post-combat rewards, shops, events, and forge entry points. |
| Meta Progression Controller | Created | Awards Echo Shards, unlocks content, tracks achievements, and handles daily mode state. |
| Persistence Service | Created | Saves and restores local run-state and permanent progression. |
| Content Catalog / Definitions | Created | Loads immutable definitions for archetypes, bodies, faces, runes, enemies, floors, and unlocks. |
| Dice Domain Model | Created | Represents die bodies, faces, runes, roll results, and synergy effects. |
| Enemy Encounter Model | Created | Represents enemy actions, AI intent, stats, and boss encounter composition. |
| Forge Assembly System | Created | Applies part swapping and validation rules for die construction. |
| Run Inventory Model | Created | Tracks acquired parts, currencies, action slots, and run modifiers. |
| Dungeon / Floor Generator | Created | Produces room graph, encounter placement, and boss progression structure. |
| Unlock Registry | Created | Stores permanent unlock state and achievement-derived progression. |
| Daily Void Mode Adapter | Created in Phase 6 | Adapts seeded runs and score submission flow for daily challenge mode. |
| Leaderboard Gateway | Created if approved | Sends and retrieves challenge leaderboard data from an external service. |

## Phase-to-Architecture Mapping

| Phase | Components Primarily Introduced |
|-------|---------------------------------|
| 1. Playable Foundation | App Root, Game State Coordinator, HUD shell, Exploration Controller skeleton, Content Catalog seed |
| 2. Core Dice Combat | Combat Controller, Dice Domain Model, Enemy Encounter Model |
| 3. Dice Forging And Run Rewards | Reward Controller, Forge Assembly System, Run Inventory Model |
| 4. Run Structure And Bosses | Dungeon Generator, full Exploration Controller, boss-specific encounter definitions |
| 5. Meta Progression | Persistence Service, Meta Progression Controller, Unlock Registry |
| 6. Advanced Modes And Polish | Daily Void Mode Adapter, Leaderboard Gateway, expanded presentation systems |

## Security Considerations

- All content definitions loaded from disk must be validated before use to avoid invalid runtime state.
- Save files must be treated as untrusted input and validated before deserialization into runtime state.
- If a leaderboard service is added, score submission must avoid trusting arbitrary client claims without validation rules.

## Performance Considerations

- Combat resolution may chain multiple rune and synergy effects; the design keeps effect resolution inside dedicated combat and dice components to contain complexity.
- Dungeon generation and content loading should front-load immutable definitions rather than rebuilding them per encounter.
- UI and animation polish added in later phases must not block deterministic state resolution for combat and seeded daily runs.

## Out of Scope

- Multiplayer or synchronous network play.
- Account systems or cloud save requirements.
- Backend implementation details for leaderboard hosting beyond the gateway contract.
