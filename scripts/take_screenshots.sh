#!/bin/bash
set -euo pipefail

SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-/workspace/dist/screenshots}"
SCREENSHOT_SIZE="${SCREENSHOT_SIZE:-1280x720x24}"
DISPLAY_ID="${DISPLAY_ID:-:99}"
GAME_PATH="${GAME_PATH:-/workspace/game}"
LOAD_DELAY="${LOAD_DELAY:-6}"
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

echo "Launching Facetbound from ${GAME_PATH}"
cd "$GAME_PATH"
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

capture "01_start_menu.png"

click_at 637 456
sleep "$STEP_DELAY"
capture "02_exploration_start.png"

click_at 376 212
sleep "$STEP_DELAY"
capture "03_echo_span.png"

click_at 376 340
sleep "$STEP_DELAY"
capture "04_combat.png"

click_at 165 371
sleep "$SHORT_DELAY"
capture "05_combat_action.png"

click_at 329 545
sleep "$SHORT_DELAY"
click_at 329 545
sleep "$SHORT_DELAY"
capture "06_after_combat.png"

echo "All screenshots saved to ${SCREENSHOTS_DIR}"
ls -lh "$SCREENSHOTS_DIR/"
