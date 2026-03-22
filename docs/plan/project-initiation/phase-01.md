# Phase 01: Bootstrap Repository and Container Scaffolding

## Objective

Create the baseline repository structure and Docker/Compose scaffolding required to support a Godot-based project without adding gameplay code yet.

## Dependencies

- Depends on: None
- Enables: Phase 02

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `docker/dev/Dockerfile` | Build the interactive development image |
| `docker/export/Dockerfile` | Build the headless export image |
| `docker-compose.yml` | Define `dev` and `export` services |
| `Makefile` | Expose `make dev`, `make verify`, and `make export` |
| `game/.gitkeep` | Establish project root directory |
| `dist/.gitkeep` | Establish artifact directory |
| `scripts/.gitkeep` | Establish scripts directory |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `.gitignore` | Ignore generated build artifacts, Godot import/cache files, and container-local outputs |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | N/A |

## Interface & Contract Changes

Introduce the command contracts defined in `docs/design/project-initiation/contracts.md`:

```text
BuildService {
  dev()
  verify()
  exportLinux()
}
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Dev container starts with workspace mounted | Integration | Future CI/local command check via `make dev` |

## Acceptance Criteria for This Phase

- [ ] `docker compose config` succeeds from the repository root
- [ ] `make dev` resolves to the `dev` service command path
- [ ] `.gitignore` excludes generated outputs and engine cache files
- [ ] Repository contains the planned `game/`, `docker/`, `scripts/`, and `dist/` directories
- [ ] Relevant verification passes: `docker compose config`

## Implementation Notes

- Keep image responsibilities separate per ADR-002.
- Do NOT add export presets or gameplay scenes in this phase.
- Pin the base engine/tooling version in both Dockerfiles.

