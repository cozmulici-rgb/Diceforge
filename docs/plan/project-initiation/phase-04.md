# Phase 04: Finalize Developer Ergonomics and Build Documentation

## Objective

Document the new stack and command flow, and make the local developer experience predictable once the containerized build path exists.

## Dependencies

- Depends on: Phase 03
- Enables: None

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `README.md` | Explain the project stack, local setup, and build commands |
| `docs/setup.md` | Expanded developer setup and troubleshooting guide |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `Makefile` | Add any final help target or command descriptions if needed |
| `.gitignore` | Finalize ignore rules based on generated Godot and Docker outputs |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | N/A |

## Interface & Contract Changes

No new interfaces beyond documenting the existing command contracts.

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Dev container starts with workspace mounted | Integration | Documented manual verification or CI bootstrap check |
| Linux export produces an artifact | Smoke | Documentation-backed verification step |

## Acceptance Criteria for This Phase

- [ ] `README.md` describes the chosen stack and primary commands
- [ ] `docs/setup.md` explains prerequisites, build flow, and common failures
- [ ] Ignore rules reflect actual generated files from the implemented workflow
- [ ] Manual verification path is documented for new contributors

## Implementation Notes

- Keep documentation aligned with the implemented commands rather than planned commands.
- Do NOT expand scope into gameplay architecture or backend services in this phase.

