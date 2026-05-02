# Dice reorder + slot cycle — visual validation

Screenshots captured by driving the live combat scene with `xdotool` inside an
Xvfb display. Each click targets one of the new controls in `_make_die_card`
(see `game/scripts/combat/combat_controller.gd`). Source spec lives at
`docs/superpowers/specs/2026-05-01-combat-dice-reorder-design.md`; plan at
`docs/superpowers/plans/2026-05-01-combat-dice-reorder.md`.

| Frame | Click target | Assertion validated | Visible result |
|-------|--------------|---------------------|----------------|
| `click_00_baseline.png` | — (after auto-roll) | starting state | `[4 Strike → Main Attack]  [5 Guard → Guard]  [6 Surge → Main Attack]` |
| `click_01_first_right_arrow.png` | first card `▶` | `move_die_in_order(state, dice[0], +1)` swaps neighbours | `[5 Guard]  [4 Strike]  [6 Surge]` — dice[0] and dice[1] swapped |
| `click_02_middle_left_arrow.png` | middle card `◀` | `move_die_in_order(state, dice[1], -1)` swaps back | original order restored |
| `click_03_first_pill_cycle.png` | first card slot pill | `cycle_die_slot` from `main_attack`: next slot `guard` rejects an attack-family die, so the cycle restores to `main_attack` per spec §10 | unchanged from `click_02` (intended) |
| `click_04_first_pill_cycle_again.png` | first card slot pill (again) | repeated cycle is still rejected and still restores | unchanged (intended) |
| `click_05_third_right_disabled.png` | third card `▶` (boundary) | last die's right arrow is disabled (`roll_index >= rolls.size() - 1`) | dice unchanged; focus highlight on the disabled button confirms the click landed |
| `click_06_first_left_disabled.png` | first card `◀` (boundary) | first die's left arrow is disabled (`roll_index <= 0`) | dice unchanged; focus highlight on the disabled button confirms the click landed |

## What the click test caught that unit tests missed

The unit tests in `game/tests/test_combat_dice_reorder.gd` use a permissive
slot fixture (every slot accepts every face family) so the cycle always
succeeds. The live encounter has stricter slots (`main_attack` accepts only
`attack`, `guard` only `defense`, `utility` only `utility`). Driving the real
UI revealed two regressions:

1. The dice card was 155 px tall — too short to render the new control row.
   Fix: bump to 195 px in commit [`c1dbef0`](#).
2. `cycle_die_slot` cleared the previous assignment before attempting the
   next, so a rejected target left the die unassigned. Fix in commit
   [`5f248db`](#) restores the previous slot if the next rejects, plus a new
   strict-fixture test (`_test_cycle_die_slot_restores_on_rejection`) so the
   regression is caught automatically next time.
