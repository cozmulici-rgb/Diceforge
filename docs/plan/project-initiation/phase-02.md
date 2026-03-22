# Phase 02: Add Godot Project Skeleton

## Objective

Create the initial Godot project structure so containerized validation has a real project to load, including a minimal startup scene and script layout.

## Dependencies

- Depends on: Phase 01
- Enables: Phase 03

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/project.godot` | Define the Godot project |
| `game/scenes/main.tscn` | Minimal startup scene |
| `game/scripts/main.gd` | Minimal startup script |
| `game/assets/.gitkeep` | Create asset directory |
| `game/scenes/.gitkeep` | Keep scenes directory tracked if needed |
| `game/scripts/.gitkeep` | Keep scripts directory tracked if needed |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `docker/dev/Dockerfile` | Ensure the image supports project bootstrapping commands if required |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | N/A |

## Interface & Contract Changes

Add the project layout contract from `docs/design/project-initiation/contracts.md`:

```text
game/
  project.godot
  scenes/
  scripts/
  assets/
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Headless verification succeeds on a valid project | Integration | Future `make verify` command |

## Acceptance Criteria for This Phase

- [ ] `game/project.godot` exists and references a startup scene
- [ ] The startup scene loads without missing-script errors
- [ ] The project directory matches the planned layout
- [ ] Relevant verification target is ready for Phase 03: `make verify`

## Implementation Notes

- Keep the scene minimal; this phase exists to validate the stack, not to implement gameplay.
- Avoid introducing combat systems, data models, or save logic here.

