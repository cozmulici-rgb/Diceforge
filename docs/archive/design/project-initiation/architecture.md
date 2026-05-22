# Architecture Design: Project Initiation

**Ticket:** Define the initial game stack and Docker-based project bootstrapping for the Diceforge prototype
**Date:** 2026-03-21

## Context Diagram

```mermaid
graph TD
    Player["Player"] -->|plays builds from exported binaries| DesktopBuild["Desktop Game Build [created]"]
    Developer["Developer"] -->|edits code/assets| Workspace["Repository Workspace [modified]"]
    Developer -->|docker compose up| DevContainer["Godot Dev Container [created]"]
    Developer -->|docker compose run export| ExportContainer["Headless Export Container [created]"]
    DevContainer -->|reads/writes| Workspace
    ExportContainer -->|reads project| Workspace
    ExportContainer -->|produces artifacts| BuildArtifacts["Build Artifacts Directory [created]"]
```

## Container Diagram

```mermaid
graph TD
    subgraph Repo["Diceforge Repository"]
        GameProject["Godot 4 Project [created]"]
        Tooling["Docker/Compose/Make Tooling [created]"]
        Docs["Pipeline Docs [modified]"]
    end

    subgraph Containers["Local and CI Containers"]
        Dev["dev: Godot editor-compatible workspace image [created]"]
        Export["export: headless Godot build image [created]"]
        Test["test: headless verification command in export image [created]"]
    end

    Developer["Developer"] --> Dev
    Dev --> GameProject
    Dev --> Tooling
    Export --> GameProject
    Export --> Tooling
    Test --> GameProject
    Export --> Artifacts["dist/ artifacts [created]"]
```

## Component Diagram

```mermaid
graph TD
    Compose["docker-compose.yml [created]"] --> DevService["dev service [created]"]
    Compose --> ExportService["export service [created]"]
    Makefile["Makefile [created]"] --> Compose
    DevDockerfile["docker/dev/Dockerfile [created]"] --> DevService
    ExportDockerfile["docker/export/Dockerfile [created]"] --> ExportService
    GodotProject["game/project.godot [created]"] --> Scenes["game/scenes/ [created]"]
    GodotProject --> Scripts["game/scripts/ [created]"]
    ExportPresets["game/export_presets.cfg [created]"] --> ExportService
    SmokeTests["scripts/verify-headless-build.sh [created]"] --> ExportService
```

## Stack Definition

- Engine: Godot 4 LTS-compatible 2D engine
- Scripting language: GDScript for the prototype milestone
- Rendering/gameplay scope: 2D top-down rooms, pixel-art pipeline, deterministic turn-resolution logic
- Source layout root: `game/`
- Build/runtime containerization scope: editor-compatible dev shell, headless export/test image, artifact output under `dist/`
- Initial export targets: Linux desktop first, web export optional but not in the first container milestone

## Responsibilities

- `dev` container:
  - Mount repository workspace
  - Provide a consistent Godot-compatible environment for scripting, scene editing support files, and CLI tooling
  - Run formatting, import generation, and local project checks
- `export` container:
  - Run headless Godot commands
  - Validate the project can load in headless mode
  - Produce export artifacts for CI and local testing
- Godot project:
  - Hold gameplay scenes, scripts, and project settings
  - Keep game logic independent from container-specific paths

## Security Considerations

- Containers mount only the project workspace and generated build directories.
- No secrets are required for the first milestone.
- The initial design excludes external leaderboard or account services, so there is no authentication surface in scope.

## Performance Considerations

- Godot asset import caches should be isolated to mounted project directories to avoid repeated CI import costs.
- Headless exports should be deterministic and scriptable to support CI caching later.
- Desktop-first export keeps the first milestone narrower than multi-target export support.

## Out of Scope

- Multiplayer or networked gameplay
- Cloud save sync
- Online leaderboards backend
- Console export pipeline
- Asset production containers for DCC tools

