#!/bin/bash
set -euo pipefail

project_path="${GODOT_PROJECT_PATH:-/workspace/game}"
main_scene="${GODOT_MAIN_SCENE:-res://scenes/app_root.tscn}"
display_num="${DISPLAY_NUM:-:99}"
screen_geometry="${SCREEN_GEOMETRY:-1470x956x24}"
http_port="${HTTP_PORT:-6080}"
vnc_port="${VNC_PORT:-5900}"
novnc_web="${NOVNC_WEB:-/usr/share/novnc}"

cleanup() {
    for pid in "${GODOT_PID:-}" "${WEBSOCKIFY_PID:-}" "${X11VNC_PID:-}" "${OPENBOX_PID:-}" "${XVFB_PID:-}"; do
        if [[ -n "$pid" ]]; then
            kill "$pid" 2>/dev/null || true
        fi
    done
}
trap cleanup EXIT INT TERM

echo "Starting Xvfb on ${display_num} with screen ${screen_geometry}"
display_id="${display_num#:}"
rm -f "/tmp/.X${display_id}-lock"
Xvfb "$display_num" -screen 0 "$screen_geometry" &
XVFB_PID=$!
export DISPLAY="$display_num"
sleep 1
if ! kill -0 "$XVFB_PID" 2>/dev/null; then
    echo "Xvfb failed to start on ${display_num}" >&2
    exit 1
fi

echo "Starting window manager"
openbox >/tmp/openbox.log 2>&1 &
OPENBOX_PID=$!

echo "Starting x11vnc on port ${vnc_port}"
x11vnc -display "$display_num" -forever -shared -nopw -rfbport "$vnc_port" >/tmp/x11vnc.log 2>&1 &
X11VNC_PID=$!

echo "Starting noVNC on http://localhost:${http_port}/vnc.html"
websockify --web "$novnc_web" "$http_port" "localhost:${vnc_port}" >/tmp/websockify.log 2>&1 &
WEBSOCKIFY_PID=$!

cd "$project_path"
echo "Importing project assets"
godot --headless --path . --import

echo "Launching Godot project from ${project_path}"
godot --display-driver x11 --rendering-driver opengl3 --path . "$main_scene" &
GODOT_PID=$!

wait "$GODOT_PID"
