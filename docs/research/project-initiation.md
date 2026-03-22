# Research: Project Initiation

**Ticket:** Define the initial game stack and plan Docker-based project bootstrapping for the Facetbound prototype
**Date:** 2026-03-21
**Status:** Complete

---

## 1. Relevant Files & Modules

### By Role
| Role | File Path | Notes |
|------|-----------|-------|
| Product concept | `docs/concept.md` | Describes the game genre, core loop, combat model, progression, and visual direction. |
| License | `LICENSE` | Repository license file. |
| Git ignore | `.gitignore` | Ignores `.idea/` only. |
| Repository metadata | `.git/` | Git repository exists on branch `feat/project-initiation`. |

---

## 2. Current Behavior

The repository is a greenfield project with no game engine files, no application source code, no container definitions, no test suite, and no CI configuration. The only product artifact is [`docs/concept.md`](/Users/vcozmulici/workspace/mysites/df-sandbox/docs/concept.md), which describes a 2D top-down pixel-art roguelike centered on modular dice construction, turn-based combat, room exploration, bosses, meta progression, and a future daily leaderboard mode.

No executable gameplay loop, content pipeline, or build process exists in the repository at this time.

---

## 3. Relevant API Endpoints / Flows

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| None | N/A | N/A | No API endpoints exist in the repository. |

Relevant product flows described in [`docs/concept.md`](/Users/vcozmulici/workspace/mysites/df-sandbox/docs/concept.md):
- Run start with archetype selection
- Top-down room exploration with fog of war
- Turn-based combat driven by rolling multiple dice
- Between-floor forge flow for body/face/rune assembly
- Meta progression with Echo Shards
- Future fixed-seed daily mode with leaderboard

---

## 4. Data Models

### Domain Models

The following game concepts are explicitly described in [`docs/concept.md`](/Users/vcozmulici/workspace/mysites/df-sandbox/docs/concept.md) but are not implemented in code:

- `Archetype`: starting build identity such as Pyroclast, Chronomancer, or Bonecaster.
- `DieBody`: die chassis with size and behavior such as Standard D6, Heavy D6, Crystal D8, Bone D4, Living Flesh D6, and Void D20.
- `DieFace`: a swappable side defining an action such as Skull Strike, Mirror Shield, Portal Step, Frost Nova, Chaos Joker, or Dragon Eye.
- `Rune`: modifier applied to a body or face such as Cascade, Symbiosis, Backlash, Echo, or Resonance.
- `Die`: composed object assembled from body, faces, and runes.
- `ActionSlot`: combat assignment target such as Main Attack, Utility, or Ultimate.
- `EnemyDie`: enemy-controlled die defining opposing actions.
- `Run`: current run state with rooms, dice pool, inventory, events, boss state, and death resolution.
- `MetaProgression`: persistent unlock state funded by Echo Shards.

### Persistence Models

No persistence layer, save format, database schema, or serialization contract exists in the repository.

---

## 5. Existing Patterns to Follow

There are no implementation patterns in the codebase yet. The only observable project conventions are:

- Markdown documentation under [`docs/`](/Users/vcozmulici/workspace/mysites/df-sandbox/docs)
- Git tracking with repository root configuration in [`.gitignore`](/Users/vcozmulici/workspace/mysites/df-sandbox/.gitignore)

---

## 6. Integration Points

| Integration | Type | Location | Notes |
|------------|------|----------|-------|
| Git | Tooling | `.git/` | Repository is version controlled. |
| JetBrains IDE ignore | Tooling | `.gitignore` | `.idea/` excluded from version control. |
| Game engine | Missing | N/A | No engine, SDK, or export toolchain is present. |
| Container runtime | Missing | N/A | No Dockerfiles, compose files, or container scripts exist. |
| CI platform | Missing | N/A | No workflow definitions exist. |
| Backend/leaderboards | Missing | N/A | Daily mode is described conceptually, but no service exists. |

---

## 7. Test Locations & Conventions

| Test Type | Location | Coverage Notes |
|-----------|----------|----------------|
| Automated tests | N/A | No tests or test runner configuration exist. |
| Build verification | N/A | No build/export scripts exist. |
| Documentation | `docs/concept.md` | Design intent only; not executable validation. |

---

## 8. Boundaries — What Must Not Be Touched

- [`LICENSE`](/Users/vcozmulici/workspace/mysites/df-sandbox/LICENSE) is unrelated to stack selection and container planning.
- [`.idea/`](/Users/vcozmulici/workspace/mysites/df-sandbox/.idea) is local IDE state and should remain excluded from version control.
- No assumptions can be made about an existing gameplay codebase, persistence layer, or deployment environment because none is present in the repository.

---

## 9. Unknowns / Missing Information

- Unknown: target release platform priority order (desktop only, web, Steam Deck, consoles). Needs: product/platform decision.
- Unknown: preferred engine and language. Needs: explicit stack decision in design phase.
- Unknown: whether online services are required in the first playable milestone. Needs: milestone scope definition.
- Unknown: whether art/audio tooling must run inside containers or only build/export tasks must be containerized. Needs: developer workflow decision.
- Unknown: CI provider and artifact storage target. Needs: infrastructure decision.
- Unknown: save-file persistence requirements for the prototype. Needs: product scope decision.

