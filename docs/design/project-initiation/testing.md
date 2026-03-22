# Testing Strategy: Project Initiation

**Ticket:** Define the initial game stack and Docker-based project bootstrapping for the Facetbound prototype
**Date:** 2026-03-21

## Test Strategy

- Unit tests:
  - Not applicable for the infrastructure-only milestone until gameplay scripts exist.
- Integration tests:
  - Validate container image build
  - Validate headless project load
  - Validate Linux export artifact generation
- Smoke tests:
  - Confirm generated artifact exists in `dist/`
  - Confirm commands fail predictably when required project files are missing

## Test Cases

Test: Dev container starts with workspace mounted
Type: Integration
Scenario: Developer starts the local development container
Given: Docker is available and the repository contains the required compose and Docker files
When: `make dev` runs from the repository root
Then: The dev container starts successfully and `/workspace` contains the repo files
Covers: dev service wiring

Test: Headless verification succeeds on a valid project
Type: Integration
Scenario: A valid Godot project is checked in
Given: `game/project.godot` and referenced startup scene exist
When: `make verify` runs
Then: The command exits `0`
Covers: headless validation command

Test: Linux export produces an artifact
Type: Integration
Scenario: A valid export preset exists for Linux desktop
Given: The export container image is available and `game/export_presets.cfg` is configured
When: `make export` runs
Then: A build artifact is written under `dist/`
Covers: export service and export preset wiring

Test: Verification fails when the project file is missing
Type: Integration
Scenario: Required Godot project metadata is absent
Given: `game/project.godot` is missing or unreadable
When: `make verify` runs
Then: The command exits non-zero and prints a clear failure message
Covers: startup validation path

Test: Export fails when the Linux preset is missing
Type: Integration
Scenario: Export configuration is incomplete
Given: `game/export_presets.cfg` does not include the Linux preset
When: `make export` runs
Then: The command exits non-zero and no success artifact is produced
Covers: export error path

## Security Considerations

- No secrets should be baked into images.
- Build scripts must not assume host-global writable directories beyond the mounted workspace.
- Container images should use pinned engine versions for reproducibility.

## Performance Risks

- Initial image builds may be heavy because Godot and export templates are large.
- Asset re-import times can slow CI if import caches are not reused.
- Web export support would expand toolchain complexity and is intentionally deferred.

