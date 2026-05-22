# ADRs: Project Initiation

**Ticket:** Define the initial game stack and Docker-based project bootstrapping for the Diceforge prototype
**Date:** 2026-03-21

## ADR-001: Use Godot 4 with GDScript for the Prototype

**Status:** Accepted

**Context:**
The concept describes a 2D top-down roguelike with room exploration, dice-driven combat, UI-heavy run management, and a need for fast iteration in a greenfield repository.

**Decision:**
Use Godot 4 as the initial engine and GDScript as the prototype language.

**Rationale:**
Godot is suited to 2D scene composition, UI, animation, and export automation from a small project footprint. GDScript keeps early gameplay iteration in the engine-native workflow.

**Alternatives Considered:**
- Unity with C#: Rejected for the first milestone because it adds more editor/runtime overhead for a small greenfield prototype and complicates headless container builds.
- Custom framework: Rejected because the concept needs engine services immediately rather than engine construction.

**Consequences:**
- Positive: Fast prototype iteration, simple scene workflow, straightforward headless export automation.
- Negative: Runtime performance-critical systems may later need selective optimization if combat simulation grows substantially.

## ADR-002: Containerize Development and Export as Separate Services

**Status:** Accepted

**Context:**
The repository needs reproducible local setup and a clean path to CI builds, but editor-like workflows and headless export workflows have different operating patterns.

**Decision:**
Create separate `dev` and `export` container services with dedicated Dockerfiles.

**Rationale:**
The `dev` service optimizes for interactive local work, while the `export` service optimizes for deterministic verification and artifact generation.

**Alternatives Considered:**
- Single all-purpose container: Rejected because interactive and export concerns would be coupled into one heavier image and workflow.
- No Docker support: Rejected because the ticket explicitly requests planning a new container build flow.

**Consequences:**
- Positive: Clear separation of responsibilities and easier CI reuse.
- Negative: Two images add some maintenance overhead.

## ADR-003: Limit the First Build Milestone to Linux Desktop Export

**Status:** Accepted

**Context:**
The repository has no existing build infrastructure. Adding multiple export targets at bootstrap time increases complexity before gameplay exists.

**Decision:**
Support Linux desktop export first and defer web or other targets.

**Rationale:**
A single target is enough to validate the toolchain, artifact generation, and CI pattern while keeping the first milestone focused.

**Alternatives Considered:**
- Linux plus web export immediately: Rejected because it broadens the bootstrap surface area without product validation.
- Web-only export: Rejected because the concept does not prioritize browser delivery in the current repository artifacts.

**Consequences:**
- Positive: Smaller first implementation slice and faster validation.
- Negative: Additional export presets will need a follow-up phase later.

