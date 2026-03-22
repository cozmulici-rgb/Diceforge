# Phase 03: Implement Headless Verification and Linux Export

## Objective

Wire the export container, verification script, and Linux export preset so the repository can produce a reproducible build artifact.

## Dependencies

- Depends on: Phase 02
- Enables: Phase 04

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/export_presets.cfg` | Define Linux desktop export |
| `scripts/verify-headless-build.sh` | Run headless validation before export |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `docker/export/Dockerfile` | Install/export required headless tooling and templates |
| `docker-compose.yml` | Wire the export and verify commands |
| `Makefile` | Add `verify` and `export` targets |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | N/A |

## Interface & Contract Changes

Implement the command contracts:

```text
make verify
make export
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Headless verification succeeds on a valid project | Integration | `scripts/verify-headless-build.sh` via `make verify` |
| Linux export produces an artifact | Integration | `make export` |
| Verification fails when the project file is missing | Integration | Negative command-path check |
| Export fails when the Linux preset is missing | Integration | Negative command-path check |

## Acceptance Criteria for This Phase

- [ ] `make verify` exits `0` on a valid project
- [ ] `make export` generates a Linux artifact under `dist/`
- [ ] Missing project or preset conditions fail with non-zero exit codes
- [ ] Relevant tests pass: `make verify` and `make export`

## Implementation Notes

- Fail fast before export if `game/project.godot` or `game/export_presets.cfg` is absent.
- Keep the first export target limited to Linux desktop per ADR-003.

