#!/bin/bash
set -euo pipefail

SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-/workspace/dist/screenshots}"
SCREENSHOT_SIZE="${SCREENSHOT_SIZE:-1470x956x24}"
DISPLAY_ID="${DISPLAY_ID:-:99}"
GAME_PATH="${GAME_PATH:-/workspace/game}"
LOAD_DELAY="${LOAD_DELAY:-14}"
STEP_DELAY="${STEP_DELAY:-3}"
SHORT_DELAY="${SHORT_DELAY:-2}"

mkdir -p "$SCREENSHOTS_DIR"

cleanup() {
    if [[ -n "${GODOT_PID:-}" ]]; then
        kill "$GODOT_PID" 2>/dev/null || true
    fi
    if [[ -n "${XVFB_PID:-}" ]]; then
        kill "$XVFB_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "Starting Xvfb on ${DISPLAY_ID} with screen ${SCREENSHOT_SIZE}"
Xvfb "$DISPLAY_ID" -screen 0 "$SCREENSHOT_SIZE" &
XVFB_PID=$!
export DISPLAY="$DISPLAY_ID"
sleep 1

cd "$GAME_PATH"
echo "Importing project assets for headless capture"
godot --headless --path . --import

echo "Launching Diceforge from ${GAME_PATH}"
godot --display-driver x11 --rendering-driver opengl3 --path . &
GODOT_PID=$!

echo "Waiting ${LOAD_DELAY}s for the start menu"
sleep "$LOAD_DELAY"

capture() {
    local name="$1"
    scrot "${SCREENSHOTS_DIR}/${name}" --overwrite
    echo "Captured: ${name}"
}

click_at() {
    local x="$1"
    local y="$2"
    xdotool mousemove "$x" "$y" click 1
}

press_key() {
    local key="$1"
    xdotool key "$key"
}

focus_game() {
    xdotool search --name "Diceforge" windowfocus --sync 2>/dev/null || true
    sleep 0.3
}

capture "01_start_menu.png"

# Trigger the highlighted New Run action from the redesigned start menu.
focus_game
press_key Return
sleep "$STEP_DELAY"
capture "02_exploration_start.png"

# Select Echo Span on the route map (node center at x=912, y≈163), then commit via Enter.
# The exploration screen handles Return key to fire the primary action button.
focus_game
click_at 912 163
sleep "$SHORT_DELAY"
press_key Return
sleep "$STEP_DELAY"
capture "03_echo_span.png"

# Enter the encounter from the current hostile room via Enter key.
focus_game
press_key Return
sleep "$STEP_DELAY"
capture "04_combat.png"

# Click Roll Dice (center panel, button row near bottom).
focus_game
click_at 617 914
sleep "$SHORT_DELAY"
capture "05_combat_action.png"

# Capture the battle decision point — all dice assigned, resolution queue ready.
sleep "$STEP_DELAY"
capture "06_battle_active.png"

# Click Resolve Round, then select the first reward option.
focus_game
click_at 833 914
sleep "$SHORT_DELAY"
click_at 735 234
sleep "$SHORT_DELAY"
capture "07_after_combat.png"

echo "All screenshots saved to ${SCREENSHOTS_DIR}"
ls -lh "$SCREENSHOTS_DIR/"
