# Phase 04: Rewards, Inventory, And Forge

## Objective

Add the between-encounter loop that turns combat wins into build changes. This phase introduces reward selection, run inventory, and forge mutation validation for bodies, faces, and runes.

## Dependencies

- Depends on: Phase 03
- Enables: Phase 05

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scenes/screens/reward_screen.tscn` | Reward selection scene after combat |
| `game/scenes/screens/forge_screen.tscn` | Forge interaction scene for build mutations |
| `game/scripts/rewards/reward_controller.gd` | Resolves reward tables, shop/event entry points, and reward application |
| `game/scripts/rewards/run_inventory.gd` | Mutable run inventory for parts, currencies, and modifiers |
| `game/scripts/rewards/forge_assembly_system.gd` | Validates and applies forge mutations |
| `game/scripts/rewards/forge_mutation.gd` | Structured forge mutation request object |
| `game/content/rewards/tutorial_rewards.json` | Starter combat reward tables |
| `game/content/events/tutorial_events.json` | Minimal event data for non-combat reward paths |
| `game/content/shops/tutorial_shop.json` | Minimal shop data for deterministic purchase flow |
| `game/tests/test_reward_flow.gd` | Reward application tests |
| `game/tests/test_forge_assembly.gd` | Forge validation and mutation tests |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `game/scripts/core/game_state_coordinator.gd` | Support reward flow entry and application of reward results |
| `game/scripts/core/run_session.gd` | Add inventory, currencies, modifiers, and owned spare parts |
| `game/scripts/combat/combat_controller.gd` | Emit reward-ready encounter result payloads |
| `game/scripts/content/content_catalog.gd` | Load reward, event, and shop definitions |
| `game/scripts/ui/hud_controller.gd` | Show inventory and reward state where needed |
| `game/tests/test_runner.gd` | Register reward and forge tests |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | No deletions required in this phase |

## Interface & Contract Changes

New interface implemented from `contracts.md`:

```text
interface ForgeAssemblySystem
  preview_change(active_die: DieBuild, mutation: ForgeMutation, inventory: RunInventory) -> ForgePreview | RuleViolation
  apply_change(active_die: DieBuild, mutation: ForgeMutation, inventory: RunInventory) -> ForgeResult | RuleViolation
  validate_die_build(die_build: DieBuild) -> ValidationResult
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Reward flow adds acquired parts into run inventory | Integration | `game/tests/test_reward_flow.gd` |
| Forge mutation rejects incompatible rune slotting | Unit | `game/tests/test_forge_assembly.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] Winning a combat encounter opens a deterministic reward flow
- [ ] Reward selection can add parts and currency into run inventory
- [ ] Forge mutations preview and apply legal body/face/rune changes to active dice
- [ ] Invalid forge mutations are rejected without mutating active dice or inventory state
- [ ] Reward and forge flows return control to exploration or floor progression state cleanly
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity check passes: `make verify`

## Implementation Notes

- Keep event and shop content intentionally small here; this phase is about flow correctness, not content volume.
- Respect ADR-002: reward definitions and part definitions live in content files, while owned items live in run-state.
- Do NOT implement full floor graph progression or boss rewards here; that belongs to Phase 05.
