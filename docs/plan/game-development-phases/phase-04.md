# Phase 04: Dice Forging And Run Rewards

## Objective

Add the between-encounter loop that turns combat victories into deterministic build changes. This phase introduces reward selection, run inventory, shop and event entry points, and forge mutation validation for bodies, faces, and runes.

## Dependencies

- Depends on: Phase 03
- Enables: Phase 05

## Exact File Changes

### Files to Create
| File Path | Purpose |
|-----------|---------|
| `game/scenes/screens/reward_screen.tscn` | Reward selection scene after combat |
| `game/scenes/screens/forge_screen.tscn` | Forge interaction scene for build mutations |
| `game/scripts/screens/reward_screen_controller.gd` | Handles reward choice UI and coordinator callbacks |
| `game/scripts/screens/forge_screen_controller.gd` | Handles preview/apply forge UI interactions |
| `game/scripts/rewards/reward_controller.gd` | Resolves reward tables, shop/event entry points, and reward application |
| `game/scripts/rewards/run_inventory.gd` | Mutable run inventory for parts, currencies, and modifiers |
| `game/scripts/rewards/forge_assembly_system.gd` | Validates and applies forge mutations |
| `game/scripts/rewards/forge_mutation.gd` | Structured forge mutation request object |
| `game/scripts/rewards/reward_option.gd` | Structured reward choice payload for UI and tests |
| `game/content/rewards/tutorial_rewards.json` | Starter combat reward tables |
| `game/content/events/tutorial_events.json` | Minimal event data for non-combat reward paths |
| `game/content/shops/tutorial_shop.json` | Minimal shop data for deterministic purchase flow |
| `game/tests/test_reward_flow.gd` | Reward application tests |
| `game/tests/test_forge_assembly.gd` | Forge validation and mutation tests |

### Files to Modify
| File Path | What Changes |
|-----------|-------------|
| `game/scripts/app_root.gd` | Route post-combat victories into reward and forge screens, then back into exploration |
| `game/scripts/core/game_state_coordinator.gd` | Support reward flow entry, reward application, forge routing, and return-to-run state updates |
| `game/scripts/core/run_session.gd` | Add inventory, currencies, modifiers, reward state, and owned spare parts |
| `game/scripts/combat/combat_controller.gd` | Emit reward-ready encounter result payloads with reward source metadata |
| `game/scripts/content/content_catalog.gd` | Load reward, event, and shop definitions |
| `game/scripts/exploration/exploration_controller.gd` | Pause traversal while reward or forge screens are active |
| `game/scripts/ui/hud_controller.gd` | Show inventory and reward state where needed |
| `game/tests/test_runner.gd` | Register reward and forge tests |

### Files to Delete
| File Path | Reason |
|-----------|--------|
| None | No deletions required in this phase |

## Interface & Contract Changes

This phase begins implementing the remaining reward-facing coordinator contract:

```text
interface GameStateCoordinator
  apply_encounter_result(result: EncounterResolution) -> RunSession
  open_reward_flow(source: RewardSource) -> RewardFlowState
```

New interface implemented from `contracts.md`:

```text
interface ForgeAssemblySystem
  preview_change(active_die: DieBuild, mutation: ForgeMutation, inventory: RunInventory) -> ForgePreview | RuleViolation
  apply_change(active_die: DieBuild, mutation: ForgeMutation, inventory: RunInventory) -> ForgeResult | RuleViolation
  validate_die_build(die_build: DieBuild) -> ValidationResult
```

Supporting runtime payloads introduced in this phase should align with the sequence and data-flow docs:

```text
RewardFlowState
  reward_source_id: String
  reward_type: encounter | event | shop
  available_options: Array[RewardOption]
  inventory_snapshot: RunInventory
  can_enter_forge: bool
```

```text
RewardOption
  option_id: String
  grant_type: body | face | rune | currency | modifier | forge_access
  content_id: String
  quantity: int
```

## Tests to Add / Modify

| Test Case | Type | File to Create/Modify |
|-----------|------|----------------------|
| Reward flow adds acquired parts into run inventory | Integration | `game/tests/test_reward_flow.gd` |
| Forge mutation rejects incompatible rune slotting | Unit | `game/tests/test_forge_assembly.gd` |
| Exploration-to-combat transition and post-combat reward transition | Integration | `game/tests/test_exploration_flow.gd` |
| All content definitions resolve referenced ids correctly | Validation | `game/tests/test_content_catalog.gd` |

## Acceptance Criteria for This Phase

At the end of this phase, ALL of the following must be true:

- [ ] Winning a combat encounter opens a deterministic reward flow
- [ ] Post-combat reward routing uses structured encounter result data rather than hardcoded scene assumptions
- [ ] Reward selection can add parts and currency into run inventory
- [ ] Event and shop definitions can be loaded through the same reward controller path, even if content volume stays minimal
- [ ] Forge mutations preview and apply legal body/face/rune changes to active dice
- [ ] Invalid forge mutations are rejected without mutating active dice or inventory state
- [ ] At least one valid forge mutation consumes an owned spare part and updates the active dice pool
- [ ] Reward and forge flows return control to exploration or floor progression state cleanly
- [ ] Relevant tests pass: `docker compose run --rm export bash /workspace/scripts/run-godot-tests.sh`
- [ ] Relevant integrity check passes: `make verify`

## Implementation Notes

- Keep event and shop content intentionally small here; this phase is about flow correctness, not content volume.
- Respect ADR-002: reward definitions and part definitions live in content files, while owned items live in run-state.
- Follow `sequence.md` by routing encounter victory into `RewardController` before returning to exploration.
- Follow `dataflow.md` by treating reward grants and forge mutations as separate state transitions: inventory grant first, active dice mutation second.
- Keep reward resolution deterministic for tests by selecting explicit reward table entries rather than random rolls.
- Do NOT implement branching floor progression, boss reward differentiation, or run-end progression here; those belong to Phase 05 and Phase 06.
