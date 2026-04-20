# Facetbound Prototype Rules

This document describes the current gameplay rules for the Facetbound prototype in this repository. It focuses on the rules that are implemented now, with light references to intended structure where that helps explain the loop.

## 1. Objective

Facetbound is a single-player dice-driven roguelike prototype. The player enters a run, clears rooms, defeats bosses, claims rewards, mutates dice in the forge, and either dies or completes the current run path.

At the end of a run, the player earns Echo Shards and may unlock additional parts for future runs.

## 2. Run Start Rules

- A run begins from the start menu by selecting an available archetype.
- The current prototype starts with `Starter Facetwalker`.
- The starter archetype begins with:
  - `30` health
  - `3` active dice
  - floor `1`
  - the starting room of `floor_01`
- Each starter die is a balanced six-sided die with this face set:
  - `Strike`
  - `Guard`
  - `Focus`
  - `Strike`
  - `Guard`
  - `Surge`

## 3. Core Run Loop

Each run follows this loop:

1. Choose an archetype.
2. Enter a floor and move between connected rooms.
3. Trigger an encounter in hostile rooms.
4. Roll active dice during combat and assign them to action slots.
5. Resolve player actions, then enemy actions.
6. On victory, choose one reward.
7. If forge access is granted, apply one or more dice mutations from inventory.
8. Continue exploration, advance to the next floor after boss victories, or end the run on defeat or final completion.

## 4. Exploration Rules

- Floors are made of connected rooms.
- The player may move only to neighboring rooms.
- Entering a room reveals it and records it in room history.
- A room may contain an encounter.
- Encounter rooms remain part of the route after they are cleared.
- Boss victories may mark the floor for advancement.
- When the final boss is defeated, the run ends after reward resolution.

## 5. Dice Rules

### 5.1 Active Dice

- The player uses an active pool of dice during combat.
- Each die has:
  - an `id`
  - a number of `sides`
  - a `face_set`
  - optionally a `body_id`
  - optionally equipped runes

### 5.2 Bodies

Current body definitions include:

- `Standard D6`
  - `6` sides
  - one `core` rune slot
  - accepts `neutral` runes
- `Forged D8`
  - `8` sides
  - one `core` rune slot
  - accepts `attack` and `neutral` runes

### 5.3 Faces

Current face definitions include:

- `Strike`
  - family: `attack`
  - effect scaling: rolled value x `2`
- `Guard`
  - family: `defense`
  - effect scaling: rolled value x `1`
- `Focus`
  - family: `utility`
  - grants `1` bonus block when resolved
- `Surge`
  - family: `attack`
  - effect scaling: rolled value x `1`
- `Heavy Strike`
  - family: `attack`
  - effect scaling: rolled value x `3`
- `Bulwark`
  - family: `defense`
  - effect scaling: rolled value x `2`

### 5.4 Runes

Current rune definitions include:

- `Blank Rune`
  - family: `neutral`
- `Ember Rune`
  - family: `attack`

The prototype currently uses rune family compatibility in forge validation. Runes are present as inventory parts and socket targets even though the current content set is intentionally small.

## 6. Combat Rules

### 6.1 Combat Sequence

Each combat round follows this order:

1. The player rolls all active dice.
2. Rolled dice are assigned to action slots.
3. The player turn resolves.
4. The enemy turn resolves if combat is still active.
5. If either side reaches zero health, the encounter ends.

### 6.2 Action Slots

The default player action slots are:

- `Main Attack`
  - allowed families: `attack`
  - minimum assignments: `1`
- `Guard`
  - allowed families: `defense`
  - minimum assignments: `0`
- `Utility`
  - allowed families: `utility`
  - minimum assignments: `0`

A die can be assigned only once per round.

### 6.3 Resolution Rules

- Attack faces contribute damage based on rolled value and face multiplier.
- Defense faces contribute block based on rolled value and face multiplier.
- Utility faces currently contribute bonus block according to their face rule.
- Modifier bonuses can increase player attack, block, health, enemy health, and enemy damage.

### 6.4 Damage Rules

- Enemy block is removed before health damage is applied.
- Player block reduces incoming enemy damage.
- Remaining incoming damage is subtracted from player health.
- If enemy health reaches `0`, the encounter ends in victory.
- If player health reaches `0`, the encounter ends in defeat.

### 6.5 Enemy and Boss Rules

- Encounters load an enemy definition and create combat state from it.
- Bosses may have multiple phases.
- Boss victories can:
  - increment the boss counter for the run
  - unlock floor advancement
  - complete the run if the defeated boss is marked as final

## 7. Reward Rules

After a victorious encounter, the player may enter a reward flow.

- Reward flow presents a fixed set of choices from a reward table.
- The player chooses exactly one reward option.
- Reward types currently include:
  - `body`
  - `face`
  - `currency`
  - `modifier`
  - `forge_access`

Current sample rewards include:

- `Heavy Strike`
- `Forged D8`
- `Echo Shards`
- `Bulwark`
- `Warden Breaker`

Rewards are added to run inventory or modifier state immediately after selection.

## 8. Forge Rules

Forge access is granted by specific reward tables.

When the forge is available, the player can mutate active dice using spare inventory parts. Current supported mutation types are:

- `swap_body`
- `replace_face`
- `socket_rune`

Forge rules:

- The player previews a mutation before applying it.
- A mutation must target a valid active die.
- The target part must exist in inventory.
- Rune socketing must respect the target body's allowed rune families.
- Applied mutations update both the active die and the remaining inventory.

In the current UI flow, the forge operates on available candidate mutations and applies changes directly to the current run session.

## 9. Modifier Rules

Modifiers are persistent effects applied during the run. They can come from Daily Void configuration or rewards.

Current modifier examples:

- `Void Pressure`
  - curse
  - increases enemy health
  - increases enemy damage
  - adds score bonus
- `Glass Core`
  - curse
  - increases player health
  - increases enemy damage
  - adds score bonus
- `Ember Blessing`
  - blessing
  - increases attack
  - increases block
  - adds score bonus
- `Warden Breaker`
  - blessing
  - increases Echo Shard gain
  - adds score bonus

## 10. Progression Rules

At run end, the prototype calculates a progression result.

### 10.1 Echo Shards

The player gains Echo Shards from run outcome using these rules:

- base gain: `5`
- plus `10` per floor cleared
- plus `15` if a boss was defeated
- plus `25` for a completed victorious run
- plus any modifier-based Echo Shard bonus

### 10.2 Unlocks

Meta progression tracks cumulative Echo Shards and unlockable content.

Current unlock thresholds include:

- `unlock_forged_d8` at `20` Echo Shards
- `unlock_bulwark` at `30` Echo Shards

### 10.3 Persistence

- The active run is saved into the `active_run` slot while the run is in progress.
- Meta progression is saved separately.
- Invalid run-state or meta-state data is rejected by schema validation.
- Corrupt active-run data is discarded instead of loaded.

## 11. Daily Void Rules

Daily Void is a seeded alternate run mode.

- The daily seed is based on the calendar day.
- The active modifier bundle rotates by day.
- Only allowed archetypes may enter the daily run.
- The current content is configured for local-only submission.

Current Daily Void scoring uses:

- `100` points per cleared floor
- plus collected Echo Shards
- plus `75` per boss defeated
- plus `20` per active modifier
- plus any modifier score bonus
- plus `125` if the run completes

Daily Void results are stored in meta progression history even when online submission is not attempted.

## 12. Prototype Scope Notes

This document describes the playable prototype rules present in the repository today. It does not attempt to define all long-term design ambitions from the concept and design files.

The current implementation emphasizes:

- deterministic headless test coverage
- a complete start-to-run-end gameplay loop
- a small but functional content set
- persistence, rewards, forge mutations, and meta progression

Future iterations can expand content variety, combat complexity, events, shops, and online leaderboard behavior without changing the basic rule structure described here.
