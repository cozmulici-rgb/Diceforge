# Design Spec — Diceforge Graphic Design Bible

**Status:** Draft — awaiting author review
**Date:** 2026-04-21
**Owner:** vcozmulici
**Scope:** Author a consolidated graphic design bible for Diceforge covering the style system, per-screen visual specs, and asset-production protocols.

---

## 1. Problem

Diceforge has coherent visual intent embodied in three places — the `DiceforgeTheme` runtime theme, the start-menu art pack in `game/assets/start-menu/exports/`, and the media-design brief in `docs/archive/design/game-development-phases/game-design.md` §15 — but no single document an artist or illustrator can read cold and produce against.

Consequences today:

- Only the start-menu has bespoke art; the other five screens (exploration, combat, reward, forge, progression) reuse start-menu assets through tinting and layout tricks.
- The Diceforge visual language is encoded in GDScript constants, not in prose; production decisions cannot be made without reading code.
- The existing design brief lists "media-design needs" per screen but does not prescribe palette, motif, composition, or deliverables.
- Future screen work has no canonical reference for what the game looks like.

## 2. Goal

Produce a graphic design bible that:

- Distills the shipped Diceforge style from the theme code, shipped art pack, and current `.tscn` compositions into a designer-readable reference.
- Extends that foundation with forward-looking production briefs for the five screens that still lack bespoke art.
- Is written in a directive, visual tone — aimed at a human illustrator or an AI tool producing art, not at developers.
- Lives alongside the codebase and stays grounded to shipped constants through a mapped appendix rather than invented new conventions.

## 3. Non-Goals

- Not a full brand book (no logo construction grids, no merchandising, no print specs).
- Not a developer style guide — component wiring and theme-code details live in the `DiceforgeTheme` source.
- Not a creative re-brief — the shipped Diceforge look is the reference, not a proposal to replace.
- No animation keyframe specs, sound, or non-visual design domains.
- No full visual mockups or rendered plates produced as part of this spec — the bible describes intent; art production is a downstream activity.

## 4. Audience

Primary: an illustrator, concept artist, or AI image tool producing or directing Diceforge art.

Secondary: the developer (author) referencing the bible while wiring new screens or validating that shipped art matches intent.

Writing register: directive and visual. ("Matte void-black backdrop; cold blue fog at 18% opacity; gold sigils never exceed 8% luminance.") Not prescriptive at the pixel level — that is the `.tscn`'s job.

## 5. File Layout

All bible files live under `docs/graphic-design/`.

```
docs/graphic-design/
├── README.md                        # one-page hub; map to every other file
├── diceforge-style-guide.md        # foundation: palette, type, motifs, components, voice
├── asset-production.md              # resolutions, formats, naming, delivery, pipeline
└── screen-briefs/
    ├── start-menu.md
    ├── exploration.md
    ├── combat.md
    ├── reward.md
    ├── forge.md
    ├── progression.md
    └── hud-overlay.md
```

Ten files total. Split rationale: stable foundation (changes rarely) separated from per-screen briefs (living documents), with operational production protocols separated from visual language. One file per screen so artists touch only what they are producing.

## 6. Foundation Doc — `diceforge-style-guide.md`

Section-by-section table of contents. Each section is tight (≤400 words where possible) and contains prose plus a structured reference table where appropriate.

1. **Identity.** One-paragraph creative thesis. Anchors the game's visual worldview (e.g., cold cosmic horror with warm forge-ember accents; occult geometry over void starfields; silence interrupted by gold).
2. **Visual register.** Mood anchors and tonal boundaries. Explicit "what Diceforge is" and "what Diceforge is not" lists (yes to ritual occult; no to fantasy-bright; no to neon cyber).
3. **Palette.** Five functional bands: void background, panel neutrals, gold accent, cyan accent, ember red. Each entry: display name, hex, role, `DiceforgeTheme` constant it maps to (e.g. `ACCENT_GOLD = #c6a85a`), and a "never use for" line. Values match the current `DiceforgeTheme` source.
4. **Typography.** The eight label roles already declared in code (FacetTitle, FacetSubtitle, FacetSectionLabel, FacetBodyMuted, FacetMeta, FacetDanger, FacetInfo, default). For each: size, color, tracking intent, usage, tonal register. Kickers are ceremonial uppercase; body copy is hushed secondary-gray.
5. **Motif library.** Sigils, rune circles, dice silhouettes, starfield, void fog, embers, frame corners. Each with construction notes: line weight, symmetry rules, acceptable deformations, what belongs "in canon."
6. **Component language.** Panels (Panel, FacetCard, InfoPanel), strips (WarningStrip, RecoveryStrip, StatusStrip), button tiers (Primary gold, Secondary cyan, Tertiary neutral), inputs, scrollbars, tooltips. Described visually, not in code — "gold-bordered card, 2px border, 24px inset, inset shadow," etc.
7. **Composition rules.** Layering order (backdrop → fog → embers → sigils → frame → content → HUD). Negative space discipline. Rule-of-thirds for hero art. Where gold is allowed to glow and where it must be restrained.
8. **Motion & state feedback.** Hover brightens borders; pressed dims; focus ring glows in accent; transitions ≥250ms; no bounces; no particle spam. Short section — motion policy is minimal in the current build.
9. **Voice.** Copy register for labels, buttons, kickers, flavor quotes. "Archaic, terse, second-person, never cute."
10. **Appendix A — Theme constant map.** Compact table: every named visual decision (color, type role, component, stylebox) → the `DiceforgeTheme` constant or class it is bound to. Keeps the bible honest to the engine.
11. **Appendix B — Reference list.** The shipped `game/assets/start-menu/exports/` pack catalogued by what each asset exemplifies (e.g., `bg-starfield.png` → "canonical void backdrop treatment").

## 7. Per-Screen Brief Template — `screen-briefs/<screen>.md`

All seven briefs follow the same eight-section shape so a reader can jump to the same place in any file.

1. **Purpose & emotional register.** The one-line purpose from `game-design.md` §15 plus a tonal anchor specific to this screen ("exploration is quiet apprehension; combat is ritual tempo; reward is sacred offering").
2. **Shipped state distillation.** What currently exists, described visually: composition, palette emphasis, type hierarchy, reused motifs. Snapshot derived from the current `.tscn`.
3. **Composition & layout anatomy.** Annotated zones (content column, playfield, HUD strip, decor layer, background stack). Visual logic of why zones sit where they do. No pixel specs — those belong to `.tscn`.
4. **Atmosphere prescription.** Colors, light direction, density of motifs, how loud gold is allowed to be on this screen relative to others.
5. **State treatments.** Default / highlighted / disabled / success / danger / mid-transition. What the screen looks like during each.
6. **Art deliverables needed.** The gap list. Bespoke backgrounds, foreground elements, icons, frames, portraits — each with resolution target, format, naming, and priority (P0/P1/P2).
7. **Production brief for the artist.** A directive paragraph an illustrator can draw from cold, plus explicit do/don't bullets.
8. **References & anti-references.** What to look at, what to avoid.

**Screens covered** (seven briefs total):

- `start-menu.md` — shipped-state reference brief; deliverables list should be minimal or empty.
- `exploration.md` — top-down room atmosphere + route UI.
- `combat.md` — dice slots, enemy plates, round flow readability.
- `reward.md` — card-style reward choices, rarity presentation.
- `forge.md` — dice inspection, mutation preview UI.
- `progression.md` — run-end summary, Echo Shard gain, unlock framing.
- `hud-overlay.md` — persistent HUD: HP, shards, floor, room state, inventory summary. Treated separately because it rides on top of all runtime screens and has its own visual discipline.

## 8. Operational Doc — `asset-production.md`

Cross-cutting production protocol. No visual-language content — that lives in the foundation.

Sections:

- **Resolution targets.** Master UI layout `1920×1080`; high-res source `3840×2160`; preview export `1280×720` — these match `game-design.md` §15.2.
- **File formats per asset class.** Painted backdrops `PNG`; layered overlays transparent `PNG`; logos vector source exported to transparent `PNG`; icons transparent `PNG` with vector source retained.
- **Naming conventions.** Aligned with the existing export pack: `bg-<name>.png`, `sigil-<size>.png`, `die-<body>[-blank].png`, `frame-<region>.png`, etc. One table.
- **Directory structure.** `game/assets/<screen>/exports/` for runtime; source files policy (where `.psd`/`.ai`/`.blend` sources live, if at all).
- **Import pipeline.** Godot `.import` file conventions, compression settings, mipmap policy, lossy vs. lossless choices per asset class.
- **Delivery checklist.** A short list an artist runs before handoff (resolution confirmed, alpha cleaned, naming correct, preview rendered, README updated).
- **Asset backlog.** Flat prioritized list of everything still missing across the five unfinished screens. Derived from aggregating each screen brief's "Art deliverables needed" section. Maintained here to give a single place to schedule production.

## 9. README Hub — `docs/graphic-design/README.md`

One page. Points a new reader at the right file for their task:

- "Producing art for screen X" → `screen-briefs/<x>.md` then `asset-production.md`.
- "Need palette, type, or a specific motif" → `diceforge-style-guide.md`.
- "Need to know what's missing" → `asset-production.md` (Asset backlog).
- "Need the theme constant behind a color" → `diceforge-style-guide.md` Appendix A.
- "Need resolution, format, naming, or delivery conventions" → `asset-production.md`.

No content duplicated — README is navigation only.

## 10. Content Source Policy

The bible is grounded in shipped material; it does not invent a visual language. Specifically:

- **Palette values** come from `game/scripts/ui/diceforge_theme.gd` constants. If the bible says a color, it must be verifiable against that file.
- **Type role sizes and colors** come from the same file's `_add_fonts` / `_add_label_styles` sections.
- **Component language** is distilled from the stylebox factories in the same file.
- **Shipped screen composition** is read from the corresponding `.tscn` in `game/scenes/screens/`.
- **Shipped asset inventory** is the file list in `game/assets/start-menu/exports/` plus its `README.md`.
- **Per-screen purpose and media-design needs** come from `docs/archive/design/game-development-phases/game-design.md` §15.
- **Forward-looking production briefs** extend the above but do not contradict them.

If the bible ever says something the shipped code or art disagrees with, the shipped code wins and the bible is wrong.

## 11. Success Criteria

- An illustrator who has never opened the repo can read `diceforge-style-guide.md` + one `screen-briefs/<screen>.md` + `asset-production.md` and produce art that looks like it belongs in Diceforge.
- Every color, type role, and component referenced in the bible maps to a real `DiceforgeTheme` constant or a real shipped asset.
- Every currently-missing art asset across the five unfinished screens appears in exactly one screen brief and is aggregated in `asset-production.md`'s backlog.
- The README hub answers "where do I look for X" in one glance for at least the five common lookup tasks listed in §9.
- No bible file exceeds ~2000 words except possibly the foundation, which may reach ~3500 words.

## 12. Out-of-Scope Follow-Ups

Explicitly deferred to later work:

- Actually producing the missing art assets.
- Writing the missing-screen `.tscn` compositions the new art will slot into.
- Any motion/VFX design beyond the brief §8 statement.
- Localization impact on typography.
- Accessibility contrast audit (would use the palette table but is its own document).

## 13. Risks

- **Drift risk.** The bible can fall out of sync with `DiceforgeTheme` if the theme changes. Mitigation: Appendix A is the single cross-check surface; include a note that it must be updated when the theme file changes.
- **Overreach.** Writing a designer brief invites the urge to propose new visuals. Mitigation: §10 content source policy is enforced in review.
- **Scope creep via screen briefs.** Each brief can balloon into a mini-design doc. Mitigation: briefs follow the eight-section template strictly; anything outside the template goes to a separate doc.

## 14. Deliverables

Ten markdown files authored and committed under `docs/graphic-design/`. The implementation plan (writing-plans step) will decide the authoring order and decompose per-file work.
