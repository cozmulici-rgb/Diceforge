# Game Design Document: Facetbound

## 1. Product Summary

### Working Title

Facetbound: Echoes of the Void

### Genre

Single-player 2D top-down roguelike with turn-based dice-driven combat and build-crafting between encounters.

### Pillars

- Dice are the player’s combat engine, build identity, and risk surface.
- Runs should create strong emergent synergies from a small number of understandable rules.
- Bad luck should hurt, but player build choices and sequencing should matter more than raw randomness.
- Meta progression should expand variety without invalidating the core roguelike loop.

### Player Fantasy

The player is a Facetwalker trapped in a repeating Void Labyrinth, salvaging dice parts and forging unstable living dice into increasingly absurd combinations.

## 2. Target Player Experience

- Early game: understand the dice-building trinity and survive a few rooms.
- Mid run: discover a strong build direction through rune/face/body interactions.
- Late run: manage extreme power spikes, counters, and boss-specific pressure.
- Long-term: chase unlocks, achievements, and Daily Void optimization.

## 3. Core Gameplay Loop

1. Select a starting archetype.
2. Enter a dungeon floor with a starter dice pool and initial action slots.
3. Explore rooms, reveal map information, and trigger encounters.
4. Resolve combat by rolling dice and assigning results to actions.
5. Claim rewards, shops, events, and forge opportunities.
6. Rebuild the active dice pool for the next encounter.
7. Defeat the floor boss or die.
8. Convert run outcome into Echo Shards and unlock progress.
9. Start another run with expanded options.

## 4. Run Structure

### Baseline Run Shape

- A run is composed of multiple floors.
- Each floor contains a start room, a branching set of encounter/event/shop rooms, and one boss room.
- Floor completion moves the player into a forge/reward transition before the next floor begins.
- Run failure occurs when player health reaches zero and no revival rule is active.
- Run success occurs when the final boss is defeated.

### Recommended Initial Full-Game Targets

- Floors per full run: 4
- Rooms per floor: 6 to 10
- Mandatory boss rooms per floor: 1
- Optional reward/event/shop rooms per floor: 2 to 4

These values are design targets, not implementation locks.

## 5. Player State

Each run tracks:

- Current health
- Current floor and room
- Active dice pool
- Owned spare bodies, faces, and runes
- Current action slots
- Temporary currencies
- Active curses and blessings
- Encounter-specific status effects

Meta progression tracks:

- Echo Shards
- Unlocked archetypes
- Unlocked dice parts
- Achievement state
- Daily Void history

## 6. Dice System

## 6.1 Dice-Building Trinity

Every active die is composed of:

- `Body`: determines die size, base rule modifiers, allowed slots, and passive traits.
- `Face`: defines what a rolled side can do when assigned.
- `Rune`: modifies the body, a face, or synergy behavior.

## 6.2 Active Pool Rules

- The player begins a run with 3 active dice.
- The active pool can grow to a maximum of 6 dice.
- Extra parts not currently equipped remain in run inventory.
- At least 1 active die must always remain valid and usable.

## 6.3 Body Rules

Bodies define:

- Number of sides
- Number of face slots
- Rune socket rules
- Weight, volatility, or passive effects
- Special failure or critical behavior

Example body rule set:

| Body | Base Rule |
|------|-----------|
| Standard D6 | No modifier; balanced baseline |
| Heavy D6 | +1 minimum result floor after charge, but cannot be rerolled more than once per turn |
| Crystal D8 | 8 faces; if a natural 1 resolves, the die becomes cracked and loses 1 durability |
| Bone D4 | Low variance; every roll also triggers a passive skull-tag effect |
| Living Flesh D6 | Rolling 1 or 2 restores a small amount of player health |
| Void D20 | High variance; begins with one locked curse rune |

## 6.4 Face Rules

Faces define:

- Action family: attack, defense, utility, spell, wild, summon, support
- Scaling rule tied to the rolled value
- Tags used for rune synergy, archetype bonuses, and enemy counters
- Trigger timing: on assign, on resolve, on crit, on low roll, or persistent

Face examples:

| Face | Family | Rule |
|------|--------|------|
| Skull Strike | Attack | Deal `roll x 2` damage |
| Mirror Shield | Defense | Gain `roll` block and reflect 50% of blocked damage this round |
| Portal Step | Utility | Move `roll` tiles or reposition target |
| Frost Nova | Spell | Freeze enemies in radius equal to `roll` intensity |
| Chaos Joker | Wild | Copies another owned face effect at reduced stability |
| Dragon Eye | Legendary | On natural max result, trigger large burst damage and burn |

## 6.5 Rune Rules

Runes modify dice by adding:

- Conditional triggers
- Passive stat shifts
- Conversion effects
- Reroll effects
- Combo hooks
- Risk/reward penalties

Rune examples:

| Rune | Rule |
|------|------|
| Cascade | On max roll, reroll all other unresolved dice once |
| Symbiosis | Gain +1 power per matching symbol on other active dice |
| Backlash | On natural 1, self-damage but permanently empower this die type for the current run |
| Echo | The used face remains available on the next roll |
| Resonance | Combines with specific rune tags to produce a hybrid effect |

## 6.6 Dice Validity Constraints

- Every equipped die must have exactly one body.
- Each body must have legal face assignments for all available sides.
- Locked or cursed slots cannot be replaced unless a rule explicitly allows it.
- A rune may only be equipped if the target body or face supports that rune category.
- A die cannot exceed its slot count or equip duplicate unique legendary faces unless a specific exception is granted.

## 7. Combat Rules

## 7.1 Combat Flow

Each combat round follows this order:

1. Start-of-round effects resolve.
2. Player rolls all active dice simultaneously.
3. Player assigns each eligible die to an action slot or leaves it unused if rules allow.
4. Player action effects resolve in chosen order.
5. Enemy turn resolves.
6. End-of-round status effects and decay rules resolve.
7. Check victory, defeat, or continuation.

## 7.2 Action Slot Rules

The player uses a Spell Codex of active action slots.

Baseline slot types:

- `Main Attack`: must receive at least 1 die each round if any attack-capable die exists.
- `Utility`: movement, control, reposition, buffs, scouting, or debuffs.
- `Ultimate`: requires all qualifying high-roll dice or a specific activation condition.

Additional slot rules:

- A die can be assigned only once per round unless a rune says otherwise.
- Some faces may be incompatible with some slot types.
- Utility actions may be skipped unless required by an encounter mechanic.
- Ultimate slots are optional and intentionally high-commitment.

## 7.3 Roll Semantics

- The rolled number determines effect magnitude.
- The face on the rolled side determines effect type.
- Natural minimum and natural maximum results can trigger extra rules.
- Rerolls preserve or replace prior state according to the source effect.
- Unassigned dice may fizzle, convert to defense, or be consumed by special passives depending on build rules.

## 7.4 Damage and Defense Model

Baseline combat uses:

- `Health`: persistent within the run.
- `Block`: absorbs damage for the current round unless a rule states otherwise.
- `Status effects`: damage-over-time, freeze, burn, weakness, curse, regen, shield break.

Resolution priorities:

1. Flat damage prevention
2. Block consumption
3. Reflection and retaliation
4. Health loss
5. On-hit and on-damage triggers

## 7.5 Enemy Rules

Enemies also use dice-driven behavior.

Each enemy has:

- A stat block
- One or more intent dice
- Face/action definitions
- Tags for elemental and archetype interactions
- AI priority rules

Enemy classes:

- Minions: simple low-variance actions
- Elites: higher synergy, control, or punishment mechanics
- Bosses: multi-phase rule changes, counter-build logic, stronger dice interactions

## 7.6 Boss Design Rules

Bosses must:

- Pressure a specific player habit or build pattern
- Have at least one rule shift across phases
- Expose a readable counterplay pattern
- Reward adaptation, not only raw damage output

Example boss counters:

- Punishes excessive rerolls
- Reflects repeated face tags
- Gains armor against mono-element builds
- Disrupts action slot order

## 8. Exploration Rules

## 8.1 Movement and Rooms

- The player traverses connected rooms in top-down real-time exploration outside combat.
- Entering an uncleared hostile room starts combat.
- Cleared rooms stay safe unless modified by a curse/event.
- Doors, hazards, and interactables are visible once a room is revealed.

## 8.2 Fog of War and Scouting

- Unvisited rooms are hidden.
- Adjacent room outlines may be partially visible.
- Scout effects reveal future rooms, elite nodes, traps, or shop/event markers.
- Scout values are generated by specific utility faces or run effects.

## 8.3 Room Types

- Standard combat
- Elite combat
- Event
- Shop
- Forge shrine
- Rest or recovery
- Boss

## 9. Reward, Economy, and Forge Rules

## 9.1 Reward Sources

The player may earn:

- New faces
- New runes
- Replacement or upgraded bodies
- Currency
- Health recovery
- Temporary buffs
- Action slot drafts

## 9.2 Reward Selection Rules

- Standard combat grants 1 of 3 reward choices.
- Elite combat grants 1 guaranteed high-rarity reward plus currency.
- Boss combat grants a major build-defining reward.
- Some events trade immediate power for future risk.

## 9.3 Shop Rules

- Shops sell parts, reroll services, healing, curse removal, and rare actions.
- Prices increase by rarity and by current run power.
- Some shops permit sacrifice exchanges instead of currency purchases.

## 9.4 Forge Rules

- Forge access occurs between floors and at selected shrine/event rooms.
- The player can swap bodies, replace faces, socket or remove runes, and inspect synergies.
- Some mutations cost currency, durability, or temporary instability.
- Changes are previewed before confirmation.

## 10. Archetypes

Archetypes shape the opening build and early incentives.

Each archetype defines:

- Starter dice bodies
- Starter face pool
- Starter rune bias
- Preferred tags or mechanics
- One passive starting modifier

Initial examples:

| Archetype | Identity |
|-----------|----------|
| Pyroclast | Fire damage, burn propagation, explosive crits |
| Chronomancer | Rerolls, turn manipulation, echo effects |
| Bonecaster | Skull-tag synergies, fragile aggression, death triggers |

Design rule:

- Archetypes should bias the first ten minutes of play without locking the player out of cross-build pivots.

## 11. Progression and Unlock Rules

## 11.1 In-Run Progression

During a run, the player increases power through:

- Better parts
- More coherent rune/face synergies
- Extra action slots
- Additional active dice
- Temporary blessings

## 11.2 Meta Progression

After a run, the player retains Echo Shards.

Echo Shards can unlock:

- New base bodies
- New rune families
- New rare faces
- New archetypes
- Additional event and shop possibilities

Meta-progression rules:

- Unlocks expand option space more than flat stats.
- Permanent power gain should be meaningful but bounded.
- A new player should still be able to win with skill and a coherent build.

## 11.3 Achievements

Achievements unlock challenge-oriented content.

Examples:

- Win with only D4-based dice
- Win without equipping legendary faces
- Clear a boss without taking damage

## 12. Curses, Blessings, and Variance Management

## 12.1 Curses

Curses add pressure, instability, or forced tradeoffs.

Examples:

- All natural 1s deal self-damage
- One action slot is sealed every third combat
- First reroll each fight also buffs enemies

## 12.2 Blessings

Blessings create short-lived or run-long power spikes.

Examples:

- First natural max result each combat duplicates itself
- First forge mutation on each floor is free
- Scout effects also reveal reward rarity

## 12.3 Fairness Rules

To prevent randomness from feeling arbitrary:

- Every archetype must have at least one stable line of play early.
- Shops, events, and rewards must offer recovery paths after weak rolls.
- Rerolls and mitigation should exist but never remove uncertainty entirely.
- Extremely swingy bodies must come with visible upside and visible risk.

## 13. Difficulty and Balance Rules

## 13.1 Difficulty Curve

- Floor 1 teaches core assignment and build editing.
- Floor 2 pressures synergy quality and positional choices.
- Floor 3 tests adaptation to counters and resource scarcity.
- Floor 4 tests full build mastery and boss sequencing.

## 13.2 Power Budget Guidelines

- A single common reward should improve either consistency or output, not both at top tier.
- Legendary effects should feel run-defining but should still require setup.
- Defensive builds must trade speed for safety.
- High-randomness builds need a higher ceiling but lower baseline reliability.

## 13.3 Balance Levers

The game can be balanced through:

- Drop rates
- Face scaling formulas
- Rune trigger frequency
- Action slot costs
- Enemy resistances and counters
- Shop prices
- Echo Shard income

## 14. Daily Void Mode

- Uses a fixed daily seed.
- All players receive the same starting conditions and content generation.
- Score is derived from progress, efficiency, risk multipliers, and synergy bonuses.
- Online leaderboard support is optional and can be deferred.

Example score sources:

- Floors cleared
- Bosses defeated
- Build complexity bonus
- Remaining health
- Curse multiplier
- Time efficiency bonus

## 15. Audio-Visual Rule Support

Presentation must reinforce mechanics, not obscure them.

- Each die roll needs readable impact timing.
- High rolls, crits, rune procs, and self-damage events need distinct feedback.
- Enemy intent must be visible before resolution.
- Forge previews must clearly show what changed and why.
- Boss phase changes need strong visual/audio signaling.

## 15.1 Current Screen Surface Inventory

The current prototype exposes the following player-facing screens and overlays as the active media-design scope.

### Start Menu

Purpose:

- Archetype selection
- Continue-run entry point
- Daily Void entry point
- Starter summary and recovery messaging

Media-design needs:

- Title treatment and game identity
- Primary CTA hierarchy for standard run, continue, and Daily Void
- Clear summary typography for starter state and recovery status

### Exploration Screen

Purpose:

- Room presentation
- Exit selection
- Encounter trigger
- Current room state and route comprehension

Media-design needs:

- Strong floor/room atmosphere
- Clear separation between playfield and route UI
- Readable room metadata and exit hierarchy
- Visual emphasis for encounter, event, shop, and boss room types

### Combat Screen

Purpose:

- Enemy state
- Player state
- Action slot visibility
- Rolled dice visibility
- Combat log and round controls

Media-design needs:

- Strong combat readability
- Clear enemy intent treatment
- Distinct visual grouping for slots, rolls, and controls
- Better emphasis on round flow and result feedback

### Reward Screen

Purpose:

- Reward source identity
- Reward choice presentation
- Outcome framing after combat

Media-design needs:

- High-value choice presentation
- Distinct card or option treatment
- Rarity, part type, and reward-category readability

### Forge Screen

Purpose:

- Active dice inspection
- Inventory part inspection
- Mutation candidate list
- Preview and apply flow

Media-design needs:

- Side-by-side comparison of current and previewed die state
- Strong visual distinction between equipped and spare parts
- Clear mutation affordances and confirmation hierarchy

### Progression Screen

Purpose:

- Run-end summary
- Echo Shard gain
- Unlock and achievement visibility
- Daily Void result visibility when applicable

Media-design needs:

- Strong end-of-run payoff framing
- Clear differentiation between temporary run results and permanent progress
- Readable milestone presentation for unlocks and achievements

### Shared HUD Overlay

Purpose:

- Persistent run status
- Current room and floor state
- Inventory summary
- Screen-state feedback

Media-design needs:

- Compact information density without crowding screen-specific UI
- Consistent placement across all runtime screens
- Fast scanning for HP, shards, floor, and state changes

## 15.2 Media Format And Resolution Guidelines

The current prototype is presented as a desktop-first landscape game surface. Media design for current screens should therefore target a `16:9` master layout.

### Master Resolution

- Primary UI/media layout target: `1920x1080`
- High-resolution source target for paintovers, key art, or layered composites: `3840x2160`
- Lightweight preview export: `1280x720`

### Recommended Asset Formats

- Full-screen painted backdrops: `PNG`
- Layered atmosphere, ornament, and frame overlays: transparent `PNG`
- Logos and title treatments: vector source preferred, exported to transparent `PNG` for runtime use
- Icons and small UI glyphs: transparent `PNG`, with vector source retained where possible

### Screen Media Packaging

For each major screen, the recommended production package is:

- Background plate at `1920x1080`
- Midground effects or atmosphere layer at `1920x1080` with transparency
- UI ornament or frame overlay at `1920x1080` with transparency
- Title or screen-heading treatment as a separate transparent asset when needed
- Icons exported separately

### Icon Export Sizes

- Standard icon export: `256x256`
- High-detail icon export: `512x512`

These sizes give enough headroom for runtime scaling and promotional reuse without making the working asset set unnecessarily heavy.

### Start Menu Media Spec

The `Start Menu` should be authored with:

- Master mockup: `1920x1080`
- High-resolution concept source: `3840x2160`
- Optional preview image: `1280x720`
- Background plate: `1920x1080`
- Decorative overlay: `1920x1080` transparent
- Title/logo asset: transparent export, sized to fit the menu composition

### Design Constraint

Media should be authored so that it still reads cleanly when the layout compresses below the master target. Decorative detail should live mostly in peripheral regions, while primary information remains centered and readable.

## 16. Content Scope Targets For A Full Initial Game

Suggested initial full-game content targets:

- Archetypes: 3 to 5
- Bodies: 12 to 16
- Common/uncommon faces: 30 to 50
- Rare/legendary faces: 8 to 12
- Rune types: 20 to 30
- Standard enemies: 12 to 20
- Elite enemies: 6 to 10
- Bosses: 4
- Event types: 10 to 15
- Shop variants: 3 to 5

## 17. Open Design Decisions

- Exact formulas for damage, block, healing, and status durations
- Whether scouting is purely utility-slot driven or also map-system driven
- Whether body durability and shatter mechanics apply only to specific bodies or to all dice
- Whether permanent empowerment effects like `Backlash` persist for a run only or across meta progression
- Whether Daily Void is offline-only at first release
- Whether the first shipped version targets the full game or a smaller vertical slice of these rules

## 18. Out of Scope

- Multiplayer combat
- PvP ranking
- Real-money economy
- Narrative quest structure beyond lightweight event flavor
