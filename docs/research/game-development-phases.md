# Research: Game Development Phases

**Ticket:** Research `docs/concept.md` to define the game development phases
**Date:** 2026-03-22
**Status:** Complete

---

## 1. Relevant Files & Modules

### By Role
| Role | File Path | Notes |
|------|-----------|-------|
| Product concept | `docs/concept.md` | Defines the target game loop, player-facing systems, progression, and presentation goals. |
| Project overview | `README.md` | States the repository is a Godot 4 prototype with local Docker-based verification and export flow. |
| Engine entry point | `game/project.godot` | Configures Godot application name and main scene. |
| Bootstrap scene | `game/scenes/main.tscn` | Current main scene contains a single `Node2D`. |
| Bootstrap script | `game/scripts/main.gd` | Current runtime behavior is a single startup log line. |
| Build verification | `scripts/verify-headless-build.sh` | Validates project structure and headless loading for the checked-in Godot project. |
| Local setup doc | `docs/setup.md` | Describes the existing local development, verification, and export commands. |

---

## 2. Current Behavior

The checked-in project is currently a repository bootstrap and Godot shell rather than a playable game.

- `game/project.godot` points the application to `res://scenes/main.tscn`.
- `game/scenes/main.tscn` instantiates a single `Node2D` with `res://scripts/main.gd`.
- `game/scripts/main.gd` prints `Facetbound bootstrap scene ready` during `_ready()`.
- `README.md` states the current project exists to validate the toolchain rather than gameplay.

No exploration, combat, dice building, progression, enemy logic, UI flows, save systems, or content pipelines are implemented in the current codebase.

---

## 3. Relevant Gameplay Flows

The following player flows are explicitly described in `docs/concept.md` and are the main capability groups that drive phase separation:

| Flow | Source | Description |
|------|--------|-------------|
| Run start | `docs/concept.md` | Player selects a starting archetype before entering a run. |
| Exploration | `docs/concept.md` | Player moves through a 2D top-down dungeon made of connected rooms with fog of war and scout-based reveal. |
| Combat turn | `docs/concept.md` | Player rolls 3 to 6 active dice, then assigns results to prepared actions. |
| Between-floor forging | `docs/concept.md` | Player assembles dice from Bodies, Faces, and Runes in a drag-and-drop forge menu. |
| Reward and economy loop | `docs/concept.md` | Events, shops, sacrifices, gambling, and NPC interactions modify the run state. |
| Boss encounter | `docs/concept.md` | Bosses use their own dice pools and counter the player build. |
| Death and meta loop | `docs/concept.md` | Death destroys the run build while preserving Echo Shards for future unlocks. |
| Long-term progression | `docs/concept.md` | Eternal Forge unlocks new bodies, runes, faces, and starting archetypes. |
| Variant run modifiers | `docs/concept.md` | Curses, blessings, and achievements alter runs and unlock content. |
| Competitive repeatable mode | `docs/concept.md` | Daily Void mode uses a fixed seed with weekly leaderboards. |

### Dependency Ordering Observed From The Concept

The concept describes a layered dependency chain among those flows:

1. A controllable in-run state is required before exploration, combat, or rewards can function.
2. Combat depends on a working dice model, action assignment model, and enemy turn resolution.
3. Forging depends on persistent definitions for Bodies, Faces, and Runes, plus run-state inventory.
4. Meta progression depends on run completion and death outcomes producing Echo Shards and unlock state.
5. Daily mode and leaderboards depend on the core run loop already being deterministic enough to support seeded runs and score comparison.

These dependencies map the game into distinct development phases without yet defining implementation tasks.

---

## 4. Data Models

### Domain Models Explicitly Named In The Concept

| Model | Source | Notes |
|------|--------|-------|
| Archetype | `docs/concept.md` | Starting build identity such as Pyroclast, Chronomancer, or Bonecaster. |
| Die / Dice Pool | `docs/concept.md` | Player uses 3 to 6 active dice during combat. |
| Body | `docs/concept.md` | Chassis defining die shape or inherent rules, such as Standard D6 or Void D20. |
| Face | `docs/concept.md` | Swappable side defining an action type such as attack, defense, utility, spell, or wild effect. |
| Rune | `docs/concept.md` | Modifier socketed into a body or face to change behavior or create synergies. |
| Action Slot / Spell Codex | `docs/concept.md` | Prepared actions that receive dice results during combat. |
| Enemy Dice | `docs/concept.md` | Enemy attacks are also represented as dice with their own faces and rune-like rules. |
| Room / Floor / Dungeon | `docs/concept.md` | Exploration structure for connected spaces and floor transitions. |
| Event / Shop / NPC Offer | `docs/concept.md` | Non-combat interactions that modify build or progression state. |
| Boss | `docs/concept.md` | Major encounter with a bespoke counter-build. |
| Echo Shard | `docs/concept.md` | Meta-currency kept after death. |
| Unlock | `docs/concept.md` | Permanent progression items available in the Eternal Forge hub. |
| Curse / Blessing | `docs/concept.md` | Global run modifiers. |
| Achievement | `docs/concept.md` | Goal-based unlock source for new starting dice sets. |
| Daily Void Seed / Leaderboard Entry | `docs/concept.md` | Fixed-seed challenge and comparative score record. |

### Persistence Models

No persistence layer is implemented in the current codebase.

The concept implies at least two persistence categories:

- Run-state data: active dice, room progression, rewards, enemies, and current modifiers.
- Meta-state data: Echo Shards, unlocked content, achievements, and Daily Void results.

No file format, save system, database, or service contract is currently present in the repository.

---

## 5. Existing Patterns To Follow

The current repository contains project-level patterns rather than gameplay architecture patterns:

- Godot scene entry pattern: `game/project.godot` points to a single main scene at `res://scenes/main.tscn`.
- Scene-script pairing pattern: `game/scenes/main.tscn` delegates logic to `game/scripts/main.gd`.
- Root-level documentation pattern: `README.md` and `docs/setup.md` describe the current development workflow.
- Build-validation pattern: `scripts/verify-headless-build.sh` verifies expected project files and headless startup behavior.

No gameplay system architecture, UI composition pattern, content authoring pattern, save-game pattern, or combat-system pattern exists yet in code.

---

## 6. Integration Points

| Integration | Type | Location | Notes |
|------------|------|----------|-------|
| Godot 4.3 runtime | Engine | `game/project.godot`, `README.md` | The project targets Godot `4.3-stable`. |
| Docker Compose local workflow | Tooling | `docker-compose.yml`, `README.md`, `docs/setup.md` | Used for development container access and export tooling. |
| Headless verification | Tooling | `scripts/verify-headless-build.sh` | Current automated validation path for the Godot project shell. |

No online services, account systems, analytics, backend leaderboard service, or live content delivery integration is currently implemented.

---

## 7. Test Locations & Conventions

| Test Type | Location | Coverage Notes |
|-----------|----------|----------------|
| Build verification script | `scripts/verify-headless-build.sh` | Confirms required Godot files exist, Linux export preset exists, and the project loads headlessly. |
| Manual export validation | `README.md`, `docs/setup.md` | Documents `make verify` and `make export` as the current validation flow. |

No gameplay tests, simulation tests, save/load tests, balancing tests, UI tests, or content validation suites are present.

---

## 8. Boundaries — What Must Not Be Touched

- Existing container and export workflow files under `docker/`, `docker-compose.yml`, and `Makefile` are infrastructure for the current prototype shell.
- Existing setup and verification behavior documented in `README.md` and `docs/setup.md` define the current contributor workflow.
- Archived project-initiation documentation under `docs/archive/` is historical process material and not part of the active gameplay concept source for this research ticket.

---

## 9. Unknowns / Missing Information

- Unknown: Exact target for the first playable milestone. Needs: a decision on whether the first milestone ends at exploration plus one combat loop, one full run, or a broader vertical slice.
- Unknown: Whether initial development phases should optimize for a vertical slice or for foundational systems shared across all content. Needs: product direction for milestone strategy.
- Unknown: Canonical numeric rule set for dice rolling, action resolution, enemy AI, damage, status effects, and balance formulas. Needs: system design details beyond the high-level concept.
- Unknown: Whether Daily Void leaderboards are intended to be local-only, deferred, or backed by an online service. Needs: product and technical scope decision.
- Unknown: Save format, persistence boundary, and data ownership between run-state and meta-state. Needs: architecture and persistence decisions.
- Unknown: Final content scope for archetypes, body counts, face pools, rune pools, enemies, and bosses in the initial release phases. Needs: milestone content targets.

---

## 10. Phase Candidates Derived From The Concept

The concept and current codebase support the following dependency-driven phase breakdown:

| Phase | Scope Supported By Source Material | Dependency Basis |
|------|------------------------------------|------------------|
| 1. Playable Foundation | Replace the bootstrap scene with controllable game state, room traversal shell, and core HUD scaffolding. | Required before any gameplay loop can be exercised. |
| 2. Core Dice Combat | Add player dice pool, action assignment, enemy turns, combat resolution, and encounter completion. | Combat is the central run mechanic and depends on a playable foundation. |
| 3. Dice Forging And Run Rewards | Add Bodies, Faces, Runes, forge flow, loot rewards, shops, and event interactions between encounters. | Build crafting depends on combat rewards and in-run inventory/state. |
| 4. Run Structure And Bosses | Add floor progression, boss encounters, death handling, and run-end outputs. | A complete roguelike run depends on exploration, combat, and reward systems already existing. |
| 5. Meta Progression | Add Echo Shards, Eternal Forge unlocks, achievements, and expanding starting archetypes. | Persistent progression depends on run completion and death outcomes. |
| 6. Advanced Modes And Polish | Add curses, blessings, Daily Void, leaderboard support, and stronger visual/audio feedback. | Variant modes and competitive features depend on stable core systems and progression. |

This table identifies a research-stage phase model derived from stated system dependencies. It is not yet an implementation plan and does not define files, estimates, or acceptance criteria.
