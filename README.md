# Facetbound

Facetbound is a Godot 4 prototype for a 2D dice-driven roguelike. This repository currently contains the project bootstrap, a minimal Godot project skeleton, and a Docker-based local build flow for headless validation and Linux desktop export.

## Stack

- Engine: Godot `4.3-stable`
- Scripting: GDScript
- Runtime target in scope: Linux desktop export
- Local tooling: Docker Compose and `make`

## Repository Layout

```text
docker/         Container images for development and export
dist/           Generated build artifacts
docs/           Concept, research, design, plan, and setup docs
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
  Runs headless Godot validation against the project in `game/`.
- `make export`
  Re-runs verification and exports the Linux desktop build into `dist/`.

## Current Output

After a successful `make export`, the repository produces:

- `dist/facetbound.x86_64`
- `dist/facetbound.pck`

## Notes

- Generated Godot editor metadata under `game/.godot/` is ignored.
- Generated build artifacts under `dist/` are ignored except for `dist/.gitkeep`.
- The current Godot project is intentionally minimal and exists to validate the toolchain rather than gameplay.

More setup and troubleshooting detail is in [docs/setup.md](/Users/vcozmulici/workspace/mysites/df-sandbox/docs/setup.md).
