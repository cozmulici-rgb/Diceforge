# Diceforge Combat Screen Assets

Generated combat art plates for the Diceforge combat screen.

## Backgrounds
- `bg-combat-void-dais-v1.png` — primary combat backdrop with an obsidian ritual dais and restrained side detail
- `bg-combat-void-fog-v1.png` — atmosphere pass with cyan void haze and particulate framing

## Overlay
- `overlay-combat-runes-v1.png` — ceremonial rune and frame treatment for top-layer use

## Portrait Plates
- `combat-portrait-enemy-colossus-v1.png` — generic enemy-side medallion portrait in the uploaded prototype's ash-forged boss style
- `combat-portrait-player-facetwalker-v1.png` — generic player-side medallion portrait in the uploaded prototype's cyan rune-lit helm style

## Notes
- Target usage is layered full-screen `TextureRect` background art in `game/scenes/screens/combat_screen.tscn`.
- Portrait plates are integrated into the combat side panels as focal medallion art behind the live combat summaries.
- Source renders were generated with the built-in image generation workflow and normalized to `1920x1080`.
- The visual direction matches the shipped start-menu and exploration palette: void-black, steel blue, cold cyan, muted gold, and minimal ember-red.
