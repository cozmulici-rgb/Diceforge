# Facetbound

Facetbound is a Godot 4 prototype for a 2D dice-driven roguelike. The repository now includes the phase-01 runtime scaffold, seeded gameplay content, and a Docker-based local build flow for headless validation, deterministic tests, and Linux desktop export.

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

## Current Output

After a successful `make export`, the repository produces:

- `dist/facetbound.x86_64`
- `dist/facetbound.pck`

## Notes

- Generated Godot editor metadata under `game/.godot/` is ignored.
- Generated build artifacts under `dist/` are ignored except for `dist/.gitkeep`.
- Startup now routes through `res://scenes/app_root.tscn`, with `main.tscn` retained as a compatibility wrapper.
- Seed gameplay content currently lives under `game/content/` and is validated before use by the runtime scaffold.

More setup and troubleshooting detail is in [docs/setup.md](/Users/vcozmulici/workspace/mysites/df-sandbox/docs/setup.md).
