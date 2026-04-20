# Implementation Plan: Game Development Phases

**Based on:**
- Research: `docs/research/game-development-phases.md`
- Design: `docs/design/game-development-phases/`

**Phases:**
| Phase | File | Objective | Dependencies |
|-------|------|-----------|-------------|
| 1 | `phase-01.md` | Establish the gameplay runtime scaffold, content catalog seed, and headless test harness | None |
| 2 | `phase-02.md` | Replace the bootstrap scene with a playable run-start flow and exploration shell | Phase 1 |
| 3 | `phase-03.md` | Implement deterministic dice combat and encounter resolution | Phase 2 |
| 4 | `phase-04.md` | Add reward flow, run inventory, and forge mutation rules | Phase 3 |
| 5 | `phase-05.md` | Add floor progression, branching room graph, and boss encounters | Phase 4 |
| 6 | `phase-06.md` | Implement persistence and meta progression with Echo Shards and unlocks | Phase 5 |
| 7 | `phase-07.md` | Add curses, blessings, Daily Void mode, and final validation/polish wiring | Phase 6 |

**Execution breakdowns:**
- `phase-07-breakdown.md`: Ordered implementation slices for Daily Void, modifiers, persistence integration, and final validation.

**Total phases:** 7
**Estimated complexity:** High

**Key constraints:**
- Preserve the existing Docker-based `make verify` and `make export` workflow as the minimum integrity gate.
- Follow ADR-001 by keeping run/session orchestration in a `GameStateCoordinator` rather than a monolithic scene script.
- Follow ADR-002 by separating immutable content definitions from mutable run-state and meta-state.
- Treat online leaderboard support as optional and isolated behind a gateway per ADR-003.
- Use deterministic inputs for gameplay tests wherever randomness would otherwise block repeatable headless validation.

**Definition of Done (full feature):**
- [ ] All phases implemented
- [ ] Headless gameplay test harness passes across runtime, combat, forge, progression, and Daily Void flows
- [ ] `make verify` passes
- [ ] `make export` passes
- [ ] Save validation and content validation paths are covered by automated tests
- [ ] Daily Void works in local-only mode even if no online leaderboard backend exists
- [ ] Acceptance criteria from the approved design documents are met
