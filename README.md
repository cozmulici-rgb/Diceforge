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

## Running On Windows

The project can be executed on Windows through Docker Desktop. The simplest options are:

- Use `WSL 2`, Git Bash, or another shell with `make` available, then run the standard `make` commands from this README.
- Use PowerShell directly and replace the `make` targets with the equivalent `docker compose` commands below.

### PowerShell command equivalents

- `make dev`
  `docker compose run --rm dev`
- `make verify`
  `docker compose run --rm export bash /workspace/scripts/verify-headless-build.sh`
- `make test`
  `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- `make export`
  `docker compose run --rm export bash -lc "bash /workspace/scripts/verify-headless-build.sh && mkdir -p /workspace/dist && godot --headless --path /workspace/game --export-release \"Linux/X11\" /workspace/dist/facetbound.x86_64"`
- `make screenshots`
  `docker compose run --rm export bash /workspace/scripts/take_screenshots.sh`

### Recommended Windows setup

1. Install Docker Desktop and enable the `WSL 2` backend.
2. Clone the repository into your Windows user directory or inside your WSL home directory.
3. Open the repository in `PowerShell`, `Windows Terminal`, or a WSL shell.
4. Run `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh` to confirm the environment works.
5. Run `docker compose run --rm export bash -lc "bash /workspace/scripts/verify-headless-build.sh && mkdir -p /workspace/dist && godot --headless --path /workspace/game --export-release \"Linux/X11\" /workspace/dist/facetbound.x86_64"` to build the Linux desktop artifact.

### Windows notes

- The current export target is still Linux desktop, even when executed from Windows.
- If `make` is not installed on Windows, use the PowerShell commands above.
- If Docker Desktop reports file-sharing or mount issues, move the repository into a standard user-owned directory such as `C:\Users\<you>\source\` or into your WSL home directory.

## Running From Godot

You can also execute the project directly from the Godot editor without Docker.

### Editor launch

1. Install Godot `4.3-stable`.
2. Open Godot and choose `Import`.
3. Select [`game/project.godot`](/Users/vcozmulici/workspace/ai/Diceforge/game/project.godot).
4. Open the imported project.
5. Press `F5` or click `Run Project`.

The configured startup scene is `res://scenes/app_root.tscn`, so the game boots into the normal Facetbound flow automatically.

### Native CLI launch

If `godot` is on your PATH, you can run the project from the repository root with:

```bash
godot --path game
```

To run the configured main scene explicitly:

```bash
godot --path game res://scenes/app_root.tscn
```

### Godot notes

- The project targets Godot `4.3`, so using a different major or minor version may cause import or runtime issues.
- The renderer is configured for `gl_compatibility`, which is usually the safest option on older or mixed GPU/driver setups.
- The first native editor launch will generate local import metadata under `game/.godot/`.

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
