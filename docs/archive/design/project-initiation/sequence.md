# Sequence Design: Project Initiation

**Ticket:** Define the initial game stack and Docker-based project bootstrapping for the Diceforge prototype
**Date:** 2026-03-21

## Scenario 1: Developer Opens the Project in the Dev Container

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Compose as docker compose
    participant DevContainer as dev container
    participant Repo as Repository workspace

    Dev->>Compose: up dev
    Compose->>DevContainer: build/start service
    DevContainer->>Repo: mount workspace
    DevContainer->>Repo: read game project files
    DevContainer-->>Dev: ready shell/editor-compatible environment
```

## Scenario 2: Headless Build Succeeds

```mermaid
sequenceDiagram
    participant Dev as Developer or CI
    participant Compose as docker compose
    participant Export as export container
    participant Godot as Godot headless
    participant Repo as Repository workspace
    participant Dist as dist/

    Dev->>Compose: run export
    Compose->>Export: start export service
    Export->>Repo: mount workspace
    Export->>Godot: load project and verify scripts/scenes
    Godot-->>Export: verification passed
    Export->>Godot: export Linux preset
    Godot->>Dist: write artifact
    Export-->>Dev: success status and artifact path
```

## Scenario 3: Headless Build Fails on Project Validation

```mermaid
sequenceDiagram
    participant Dev as Developer or CI
    participant Compose as docker compose
    participant Export as export container
    participant Godot as Godot headless

    Dev->>Compose: run export
    Compose->>Export: start export service
    Export->>Godot: load project and verify scripts/scenes
    Godot-->>Export: parse or configuration error
    Export-->>Dev: non-zero exit and error logs
```

