# Setup Guide

## Overview

This project uses Docker to provide a reproducible Godot 4 environment for validation and export. The source project lives under `game/`, while generated artifacts are written to `dist/`.

The current prototype includes:

- exploration and encounter handoff
- deterministic dice combat
- reward and forge flows
- floor progression and boss completion
- local persistence and meta progression
- Daily Void seeded runs with local-only score persistence

## Prerequisites

- Docker with Compose support
- `make`

## First Run

1. Build the export image and validate the project:
   `make verify`
2. Export the Linux desktop artifact:
   `make export`

The first run is slower because the export image downloads the Godot editor and export templates.

## Command Reference

### `make dev`

Starts the interactive development container:

```bash
make dev
```

Use this when you want a consistent shell environment with the repository mounted at `/workspace`.

### `make verify`

Runs the verification script:

```bash
make verify
```

This command checks:

- `game/project.godot` exists
- `game/export_presets.cfg` exists
- `game/scenes/app_root.tscn` exists
- `game/scenes/main.tscn` exists as a compatibility wrapper
- The Linux export preset is present
- Godot can import and load the project headlessly
- The deterministic gameplay harness passes

`make verify` is the minimum integrity gate for repository changes.

### `make test`

Runs the deterministic gameplay harness directly:

```bash
make test
```

This command executes `scripts/run-godot-tests.sh`, which launches:

- `res://tests/test_combat_controller.gd`
- `res://tests/test_boss_encounter.gd`
- `res://tests/test_content_catalog.gd`
- `res://tests/test_daily_void_mode.gd`
- `res://tests/test_dice_model.gd`
- `res://tests/test_dungeon_generator.gd`
- `res://tests/test_exploration_flow.gd`
- `res://tests/test_forge_assembly.gd`
- `res://tests/test_meta_progression.gd`
- `res://tests/test_modifier_registry.gd`
- `res://tests/test_persistence_service.gd`
- `res://tests/test_reward_flow.gd`
- `res://tests/test_run_session.gd`

### `make export`

Builds the Linux desktop artifact:

```bash
make export
```

This command runs verification first, then exports:

- `dist/facetbound.x86_64`
- `dist/facetbound.pck`

### `make screenshots`

Runs the Docker-based screenshot capture flow:

```bash
make screenshots
```

This command:

- starts the game in a virtual X display inside the export container
- captures a deterministic sequence of UI/runtime screenshots
- writes images to `dist/screenshots/`

The current capture sequence includes:

- start menu
- first exploration room
- encounter-room exploration
- combat
- post-input combat frames

## Manual Verification

New contributors can confirm the local setup with this sequence:

1. Run `make help` and confirm the command list is printed.
2. Run `make test` and confirm the full Facetbound headless suite passes, including persistence, progression, modifiers, and Daily Void tests.
3. Run `make verify` and confirm project import, smoke startup, and the shared test harness all succeed.
4. Run `make export` and confirm both Linux export files appear under `dist/`.
5. Run `make screenshots` and confirm PNG screenshots appear under `dist/screenshots/`.

## Daily Void Verification Notes

- Daily Void is intended to remain playable with no online service configured.
- The shipped content uses local-only submission, so progression stores Daily Void results without attempting network submission.
- Gateway failure handling is covered by the deterministic test suite rather than requiring a live backend.

## Troubleshooting

### Export image build is slow

The first `make verify` or `make export` call builds the export image and downloads the Godot editor plus export templates. This is expected.

### `make verify` fails with a missing file error

Check that these files exist:

- `game/project.godot`
- `game/export_presets.cfg`
- `game/scenes/app_root.tscn`
- `game/scenes/main.tscn`

### Docker build uses the wrong CPU architecture

The export Dockerfile selects the correct Godot Linux binary based on Docker target architecture. If your Docker installation is misconfigured, rebuild the export image and confirm Docker is targeting your host architecture correctly.

### Export succeeds but artifacts are missing

Check that `dist/` is writable on the host and confirm the export command completed without error.

### Screenshot capture produces the wrong UI state

The screenshot pipeline currently uses fixed mouse coordinates and timed delays inside a virtual display. If the UI layout or flow changes, update `scripts/take_screenshots.sh` to match the new button positions or interaction timing.
