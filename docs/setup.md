# Setup Guide

## Overview

This project uses Docker to provide a reproducible Godot 4 environment for validation and export. The source project lives under `game/`, while generated artifacts are written to `dist/`.

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

### `make test`

Runs the deterministic gameplay harness directly:

```bash
make test
```

This command executes `scripts/run-godot-tests.sh`, which launches:

- `res://tests/test_content_catalog.gd`
- `res://tests/test_run_session.gd`

### `make export`

Builds the Linux desktop artifact:

```bash
make export
```

This command runs verification first, then exports:

- `dist/facetbound.x86_64`
- `dist/facetbound.pck`

## Manual Verification

New contributors can confirm the local setup with this sequence:

1. Run `make help` and confirm the command list is printed.
2. Run `make test` and confirm all Facetbound tests pass.
3. Run `make verify` and confirm Godot completes without errors.
4. Run `make export` and confirm both Linux export files appear under `dist/`.

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
