# Facetbound Wiki

This wiki summarizes the current Facetbound prototype as it exists in this repository. It is meant to be a readable reference for the game's world, systems, content, and progression rather than a strict implementation contract.

For exact rules, see [game-rules.md](/Users/vcozmulici/workspace/ai/Diceforge/docs/game-rules.md). For setup and local validation, see [setup.md](/Users/vcozmulici/workspace/ai/Diceforge/docs/setup.md).

## Overview

Facetbound is a single-player, dice-driven roguelike built in Godot 4. The current prototype already supports a full loop:

- start a run
- move through connected rooms
- fight deterministic encounters
- claim rewards
- mutate dice in the forge
- defeat bosses
- earn meta progression
- replay the Daily Void challenge mode

The active content set is deliberately small, but the entire loop is already present.

## Setting

The player is a Facetwalker moving through the Void Labyrinth, a shard-fractured dungeon made of branching routes, ritual shrines, merchant alcoves, and boss chambers. Runs move through two named floors:

- `Fractured Approach`
- `Silent Apex`

The prototype emphasizes systems clarity over lore volume, so most setting information is implied through room names, enemy names, and progression language such as Echo Shards, Warden, and Overseer.

## Core Gameplay Loop

Each run follows this structure:

1. Choose an available archetype.
2. Enter the first floor with starter dice and action slots.
3. Move through connected rooms.
4. Start combat in hostile rooms.
5. Roll all active dice and assign them to action slots.
6. Resolve the player turn and then the enemy turn.
7. Claim one reward after a victory.
8. Enter the forge if the reward source allows it.
9. Advance to the next floor after defeating the floor boss.
10. Finish the run by defeating the final boss or lose by reaching zero health.
11. Receive Echo Shards, unlocks, achievements, and Daily Void result updates.

## Archetypes

### Starter Facetwalker

The current playable archetype is `Starter Facetwalker`.

Starting state:

- Health: `30`
- Starting floor: `floor_01`
- Active dice: `3`
- Status effects: none

Each starter die is a `Balanced D6` with this face set:

- `Strike`
- `Guard`
- `Focus`
- `Strike`
- `Guard`
- `Surge`

## Dice System

Dice are the heart of the game. Every encounter depends on the player's active dice pool and the rolled values produced each round.

### Dice Anatomy

Each active die can include:

- a die identity
- a side count
- a face set
- a body assignment
- optional rune sockets

### Bodies

#### Standard D6

- Sides: `6`
- Rune slots: `core`
- Allowed rune families: `neutral`
- Role: default starter body

#### Forged D8

- Sides: `8`
- Rune slots: `core`
- Allowed rune families: `attack`, `neutral`
- Role: early upgrade reward body

### Faces

#### Strike

- Family: `attack`
- Power rule: rolled value x `2`

#### Guard

- Family: `defense`
- Power rule: rolled value x `1`

#### Focus

- Family: `utility`
- Grants `1` bonus block

#### Surge

- Family: `attack`
- Power rule: rolled value x `1`

#### Heavy Strike

- Family: `attack`
- Power rule: rolled value x `3`

#### Bulwark

- Family: `defense`
- Power rule: rolled value x `2`

### Runes

#### Blank Rune

- Family: `neutral`
- Use: basic forge-compatible rune part

#### Ember Rune

- Family: `attack`
- Use: attack-family rune for compatible bodies

## Combat

Combat logic for Facetbound is defined in [`design/combat-algorithm.md`](/Users/vcozmulici/workspace/ai/Diceforge/docs/design/combat-algorithm.md). That document is the single source of truth for turn structure, roll and sequencing phases, per-die resolution, status timing, damage rules, and determinism.

This wiki only covers content that combat consumes — encounters, enemies, bosses, and rewards — in the sections that follow.

## Enemies

The current game defines three enemy units.

### Slime Echo

- Id: `slime_echo`
- Type: standard enemy
- HP: `26`
- Starting block: `0`
- Intent: `Gel Strike`
- Damage: `3`

### Shard Overseer

- Id: `shard_overseer`
- Type: boss
- HP: `8`
- Starting block: `1`
- Intent: `Lattice Swipe`
- Damage: `4`

Phase 2:

- HP: `10`
- Starting block: `0`
- Intent: `Refraction Pulse`
- Damage: `5`

### Final Warden

- Id: `final_warden_core`
- Type: final boss
- HP: `10`
- Starting block: `1`
- Intent: `Seal Break`
- Damage: `5`

Phase 2:

- HP: `12`
- Starting block: `0`
- Intent: `Warden's Fury`
- Damage: `6`

## Encounters

### Tutorial Slime

- Id: `tutorial_slime`
- Enemy: `Slime Echo`
- Fixed player rolls: `4, 5, 6`
- Reward table: `tutorial_slime_rewards`

### Floor 01 Overseer

- Id: `floor_01_overseer`
- Enemy: `Shard Overseer`
- Fixed player rolls: six `4`s
- Reward table: `floor_01_boss_rewards`

### Final Warden

- Id: `final_warden`
- Enemy: `Final Warden`
- Fixed player rolls: six `4`s
- Reward table: `final_boss_rewards`

## Floors And Rooms

### Floor 01: Fractured Approach

- Starting room: `Gate of Splinters`
- Boss room: `Overseer Gate`
- Seed: `101`
- Next floor: `floor_02`

Rooms:

- `Gate of Splinters`
  - type: `start`
- `Echo Span`
  - type: `encounter`
  - encounter: `tutorial_slime`
- `Shard Broker`
  - type: `shop`
  - reward source: `tutorial_vendor`
- `Overseer Gate`
  - type: `boss`
  - encounter: `floor_01_overseer`

Layout:

- The start room branches into a fight path and a shop path.
- Both branches converge at the first boss.

### Floor 02: Silent Apex

- Starting room: `Apex Threshold`
- Boss room: `Warden Core`
- Seed: `202`
- Final floor: yes

Rooms:

- `Apex Threshold`
  - type: `start`
- `Still Shrine`
  - type: `event`
  - reward source: `tutorial_shrine`
- `Guardwalk`
  - type: `encounter`
  - encounter: `tutorial_slime`
- `Warden Core`
  - type: `boss`
  - encounter: `final_warden`

Layout:

- The second floor branches into an event path and a fight path.
- Both routes lead to the final boss.

## Rewards

Victorious encounters open a reward flow. The player chooses one option from the available table.

### Tutorial Slime Rewards

- `Heavy Strike`
- `Forged D8`
- `12 Echo Shards`

Forge access: yes

### Floor 01 Boss Rewards

- `Bulwark`
- `18 Echo Shards`

Forge access: yes

### Final Boss Rewards

- `40 Echo Shards`
- `Warden Breaker`

Forge access: no

## Events And Shops

### Tutorial Shrine

Type: event

Options:

- `Blank Rune`
- `5 Echo Shards`

### Tutorial Vendor

Type: shop

Options:

- `Bulwark`
- `Ember Rune`

The current shop implementation behaves as a deterministic reward source rather than a full currency-driven transaction system.

## Forge

The forge is where run inventory becomes build customization.

Current supported mutation types:

- `swap_body`
- `replace_face`
- `socket_rune`

Forge rules:

- a mutation must target an active die
- the part must exist in run inventory
- the game previews the result before applying it
- rune family compatibility must match the target body's slot rules
- the applied mutation updates both the die and the inventory

In the current prototype UI, forge mutations are generated from available spare parts and applied directly to the current run.

## Modifiers

Modifiers are persistent run effects. They can come from Daily Void bundles or reward choices.

### Curses

#### Void Pressure

- Type: `curse`
- Scope: `combat`
- Effects:
  - enemy HP +`6`
  - enemy damage +`2`
  - score bonus +`25`

#### Glass Core

- Type: `curse`
- Scope: `run`
- Effects:
  - player HP +`3`
  - enemy damage +`1`
  - score bonus +`15`

### Blessings

#### Ember Blessing

- Type: `blessing`
- Scope: `combat`
- Effects:
  - attack bonus +`2`
  - block bonus +`1`
  - score bonus +`10`

#### Warden Breaker

- Type: `blessing`
- Scope: `reward`
- Effects:
  - Echo Shard bonus +`5`
  - score bonus +`20`

## Progression

### Echo Shards

Echo Shards are the prototype's meta currency.

Current run-end calculation:

- base: `5`
- plus `10` per cleared floor
- plus `15` for defeating a boss
- plus `25` for a completed winning run
- plus modifier-based shard bonuses

### Unlocks

Current unlock thresholds:

- `unlock_forged_d8`
  - target: `forged_d8`
  - threshold: `20 Echo Shards`
- `unlock_bulwark`
  - target: `bulwark`
  - threshold: `30 Echo Shards`

### Achievements

Current achievements:

- `first_boss_clear`
  - requirement: `defeat_any_boss`
- `first_run_victory`
  - requirement: `win_run`

### Persistence

The prototype supports:

- saving the active run to `active_run`
- saving meta progression separately
- continue-run summaries on the start screen
- rejection of invalid or incompatible save payloads
- safe fallback when corrupt data is detected

## Daily Void

Daily Void is the prototype's fixed-seed challenge mode.

Rules:

- the configuration is derived from the calendar day
- the same day produces the same seed and modifier bundle
- the mode uses the same exploration, combat, reward, and progression systems as standard runs
- results are recorded in local meta progression history
- online leaderboard submission is optional and currently not attempted by shipped content

### Current Daily Void Configuration

- mode id: `daily_void`
- seed salt: `7000`
- submission context: `local_only`
- default allowed archetype: `starter_facetwalker`

Modifier rotations:

- `pressure_rotation`
  - `void_pressure`
  - `glass_core`
- `ember_rotation`
  - `void_pressure`
  - `ember_blessing`
- `breaker_rotation`
  - `glass_core`
  - `warden_breaker`

### Daily Void Score Formula

- `100` points per cleared floor
- plus collected Echo Shards
- plus `75` per boss defeated
- plus `20` per active modifier
- plus modifier score bonuses
- plus `125` if the run completes

## Current Prototype Scope

What the prototype already supports:

- a full start-to-finish run loop
- deterministic exploration and combat validation
- a small but functional content catalog
- run persistence and continue-run support
- meta progression, unlocks, and achievements
- Daily Void seeded challenge runs

What is still intentionally limited:

- only one starting archetype
- a very small enemy roster
- a small part catalog
- limited event and shop variety
- local-only Daily Void submission

## See Also

- [game-rules.md](/Users/vcozmulici/workspace/ai/Diceforge/docs/game-rules.md)
- [setup.md](/Users/vcozmulici/workspace/ai/Diceforge/docs/setup.md)
- [concept.md](/Users/vcozmulici/workspace/ai/Diceforge/docs/concept.md)
- [design/combat-algorithm.md](/Users/vcozmulici/workspace/ai/Diceforge/docs/design/combat-algorithm.md)
