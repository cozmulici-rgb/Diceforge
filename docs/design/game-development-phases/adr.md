# ADR: Game Development Phases

## ADR-001: Use A Runtime State Coordinator As The Primary Gameplay Orchestrator

**Status:** Accepted

**Context:**  
The current project has no gameplay architecture. The concept introduces multiple tightly related gameplay domains: exploration, combat, forging, rewards, progression, and optional daily challenge flow. A design decision is required for how these domains transition between screens and state changes.

**Decision:**  
Introduce a `GameStateCoordinator` that owns run-session lifecycle, transitions between exploration/combat/reward/progression states, and delegates domain-specific work to dedicated controllers.

**Rationale:**  
The research document shows only a simple Godot scene bootstrap, so there is no existing gameplay orchestration pattern to extend. A coordinator keeps state transitions explicit while allowing combat, forging, progression, and persistence logic to remain isolated in their own components.

**Alternatives Considered:**
- Single monolithic main scene script: Rejected because the concept already spans too many gameplay domains for one script to remain clear.
- Fully decentralized scene-to-scene coordination: Rejected because cross-phase state such as run inventory, current floor, and progression outcomes would become harder to control consistently.

**Consequences:**
- Positive: Centralized transition logic and clearer ownership of run-state.
- Positive: Easier integration of later systems like progression and daily mode.
- Negative: The coordinator becomes a critical dependency and must be kept narrow to avoid becoming a god-object.

## ADR-002: Separate Immutable Content Definitions From Mutable Run-State And Meta-State

**Status:** Accepted

**Context:**  
The concept relies on many reusable definitions, including archetypes, bodies, faces, runes, enemies, floors, and unlocks. The runtime also needs mutable data for current runs and permanent progression. These concerns require a clear data ownership boundary.

**Decision:**  
Use a `ContentCatalog` for immutable design-time definitions and keep mutable state in separate run-state and meta-state models managed by runtime systems and persistence services.

**Rationale:**  
The game’s dice-building and progression systems depend on validating ids and references against shared definitions. Separating immutable content from mutable player state reduces mutation errors and makes validation and persistence boundaries explicit.

**Alternatives Considered:**
- Store all gameplay data in one mutable save-driven model: Rejected because it mixes authored content with player progress and makes validation weaker.
- Hardcode all content directly into scene scripts: Rejected because the concept explicitly expects growing content breadth and unlockable sets.

**Consequences:**
- Positive: Cleaner validation, safer persistence, and better support for content expansion.
- Positive: Deterministic daily runs can reference the same immutable content set.
- Negative: Requires content loading and schema validation infrastructure before many gameplay systems feel complete.

## ADR-003: Defer Leaderboard Integration Behind A Gateway Until Core Offline Systems Are Stable

**Status:** Accepted

**Context:**  
The concept mentions Daily Void mode with weekly leaderboards, but the research document identifies leaderboard scope and service ownership as unresolved. The current repository has no online services.

**Decision:**  
Treat leaderboard support as a Phase 6 concern behind a dedicated `LeaderboardGateway`, keeping core gameplay and progression fully functional without network dependency.

**Rationale:**  
Core gameplay phases can be completed and validated locally without blocking on backend decisions. Isolating leaderboard networking behind a gateway preserves the option to add a service later without contaminating exploration, combat, forging, or progression flows.

**Alternatives Considered:**
- Design the whole game around an always-online service from the start: Rejected because it conflicts with the current local-only repository and unresolved product scope.
- Omit leaderboard support from the design entirely: Rejected because the concept explicitly includes Daily Void as a future mode.

**Consequences:**
- Positive: Keeps early phases focused on the playable local game.
- Positive: Contains network failure handling to one boundary.
- Negative: Daily Void ranking behavior remains partially deferred until service decisions are made.
