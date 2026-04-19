#!/bin/bash
set -e

SCREENSHOTS_DIR=/workspace/dist/screenshots
mkdir -p "$SCREENSHOTS_DIR"

# Start virtual framebuffer
Xvfb :99 -screen 0 1280x720x24 &
XVFB_PID=$!
export DISPLAY=:99
sleep 1

# Launch the game
cd /workspace/game
godot --display-driver x11 --rendering-driver opengl3 --path . &
GODOT_PID=$!

# Wait for game to load
sleep 6

# Screenshot 1: Start Menu
scrot "$SCREENSHOTS_DIR/01_start_menu.png" --overwrite
echo "Captured: 01_start_menu.png"

# Click "Start Run" button
xdotool mousemove 637 456 click 1
sleep 4

# Screenshot 2: Exploration - Gate of Splinters
scrot "$SCREENSHOTS_DIR/02_exploration_start.png" --overwrite
echo "Captured: 02_exploration_start.png"

# Click "Move to Echo Span (encounter)" - first button in the exits list (~y=167)
xdotool mousemove 380 167 click 1
sleep 3

# Screenshot 3: Echo Span room
scrot "$SCREENSHOTS_DIR/03_echo_span.png" --overwrite
echo "Captured: 03_echo_span.png"

# Click "Trigger Encounter" button to start combat
xdotool mousemove 380 244 click 1
sleep 3

# Screenshot 4: Combat screen
scrot "$SCREENSHOTS_DIR/04_combat.png" --overwrite
echo "Captured: 04_combat.png"

# Look for any action buttons in combat - try clicking around various areas
xdotool mousemove 640 400 click 1
sleep 2

# Screenshot 5: Combat continued
scrot "$SCREENSHOTS_DIR/05_combat_action.png" --overwrite
echo "Captured: 05_combat_action.png"

# Try more clicks to progress combat
xdotool mousemove 640 500 click 1
sleep 2
xdotool mousemove 640 450 click 1
sleep 2

# Screenshot 6: After combat actions
scrot "$SCREENSHOTS_DIR/06_after_combat.png" --overwrite
echo "Captured: 06_after_combat.png"

# Cleanup
kill $GODOT_PID 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true

echo "All screenshots saved to $SCREENSHOTS_DIR"
ls -lh "$SCREENSHOTS_DIR/"
