# Facetbound

Facetbound is a Godot 4 prototype for a 2D dice-driven roguelike. The repository now includes a playable end-to-end prototype with exploration, deterministic dice combat, rewards, forge mutations, floor progression, persistence, meta progression, Daily Void mode, and a Docker-based local build flow for headless validation and Linux desktop export.

## Stack

- Engine: Godot `4.3-stable`
- Scripting: GDScript
- Runtime target in scope: Linux desktop export
- Local tooling: Docker Compose and `make`

## Repository Layout

```text
docker/         Container images for development and export
dist/           Generated build artifacts
docs/           Active concept and setup docs, plus archived planning material
game/           Godot project files
scripts/        Build and verification scripts
```

## Prerequisites

- Docker Desktop or a compatible Docker Engine with Compose support
- GNU Make

## Commands

- `make help`
  Shows the available local commands.
- `make dev`
  Opens the interactive development container with the repository mounted at `/workspace`.
- `make verify`
  Runs headless Godot validation against the project in `game/`, including the deterministic gameplay test harness.
- `make test`
  Runs the deterministic Godot-native gameplay tests headlessly in the export container.
- `make export`
  Re-runs verification and exports the Linux desktop build into `dist/`.
- `make screenshots`
  Runs the Docker-based screenshot capture flow and saves image output into `dist/screenshots/`.

## Current Feature Set

- Start a run from the archetype menu and continue a saved active run.
- Explore seeded room graphs and trigger encounter transitions.
- Resolve deterministic turn-based dice combat against standard enemies and bosses.
- Claim post-combat rewards and mutate active dice in the forge.
- Advance across multiple floors and finish runs into a progression summary.
- Persist active-run and meta progression data locally.
- Play Daily Void as a fixed-seed local challenge with rotating modifiers.

## Daily Void Notes

- Daily Void is fully playable in local-only mode.
- The current content is configured with `submission_context: local_only`, so leaderboard submission is not attempted by default.
- Submission behavior remains isolated behind the optional `LeaderboardGateway` boundary for future online integration.

## Current Output

After a successful `make export`, the repository produces:

- `dist/facetbound.x86_64`
- `dist/facetbound.pck`

## Notes

- Generated Godot editor metadata under `game/.godot/` is ignored.
- Generated build artifacts under `dist/` are ignored except for `dist/.gitkeep`.
- Startup now routes through `res://scenes/app_root.tscn`, with `main.tscn` retained as a compatibility wrapper.
- Seed gameplay content currently lives under `game/content/` and is validated before runtime use.
- The shared headless test harness covers content validation, exploration, combat, bosses, forge flow, persistence, progression, modifiers, and Daily Void mode.
- Docker screenshot capture is available through `make screenshots` for environments that cannot run a native Godot editor or export locally.

More setup detail is in [setup.md](/Users/vcozmulici/workspace/ai/Diceforge/docs/setup.md). Gameplay rules are summarized in [game-rules.md](/Users/vcozmulici/workspace/ai/Diceforge/docs/game-rules.md).
