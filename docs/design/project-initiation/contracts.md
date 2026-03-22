# Contracts: Project Initiation

**Ticket:** Define the initial game stack and Docker-based project bootstrapping for the Facetbound prototype
**Date:** 2026-03-21

## Public API Endpoints

No HTTP or network API is in scope for the initial Dockerized project setup.

## Command Contracts

### `make dev`

- Purpose: Start the development workspace container
- Expected behavior:
  - Builds or reuses the `dev` image
  - Mounts the repository at `/workspace`
  - Opens an interactive shell or long-lived container session for local commands
- Success result:
  - Exit code `0`
  - Container is running and workspace is mounted
- Failure result:
  - Non-zero exit code with image-build or mount error output

### `make export`

- Purpose: Produce a Linux desktop artifact from the Godot project
- Expected behavior:
  - Starts the `export` container
  - Runs headless project validation before export
  - Writes output into `dist/`
- Success result:
  - Exit code `0`
  - Artifact exists under `dist/`
- Failure result:
  - Non-zero exit code with Godot validation or export failure logs

### `make verify`

- Purpose: Validate that the project loads headlessly without producing a distributable artifact
- Expected behavior:
  - Starts the `export` container or reuses its image
  - Executes a headless verification command against `game/project.godot`
- Success result:
  - Exit code `0`
- Failure result:
  - Non-zero exit code with parse/configuration errors

## Internal Interfaces

### Build Service Contract

```text
interface BuildService {
  dev(): start interactive development environment
  verify(): run headless project validation
  exportLinux(): build Linux desktop artifact into dist/
}
```

### Project Layout Contract

```text
game/
  project.godot
  scenes/
  scripts/
  assets/
docker/
  dev/Dockerfile
  export/Dockerfile
scripts/
  verify-headless-build.sh
dist/
```

## Validation Rules

- All build commands operate from the repository root.
- `dist/` is generated output and must not be used as source input.
- The export container must fail fast if `game/project.godot` or `game/export_presets.cfg` is missing.
- The first milestone supports Linux desktop export only.

