#!/usr/bin/env bash
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-:99}"
SCREEN_GEOMETRY="${SCREEN_GEOMETRY:-1470x956x24}"
HTTP_PORT="${HTTP_PORT:-6080}"
VNC_PORT="${VNC_PORT:-5900}"
GODOT_PROJECT_PATH="${GODOT_PROJECT_PATH:-/workspace/game}"
GODOT_MAIN_SCENE="${GODOT_MAIN_SCENE:-res://scenes/app_root.tscn}"

cleanup() {
  local status=$?
  jobs -pr | xargs -r kill >/dev/null 2>&1 || true
  wait || true
  exit "$status"
}
trap cleanup EXIT INT TERM

mkdir -p /tmp/facetbound-gui

echo "Starting Xvfb on ${DISPLAY_NUM} with screen ${SCREEN_GEOMETRY}"
Xvfb "${DISPLAY_NUM}" -screen 0 "${SCREEN_GEOMETRY}" -ac +extension GLX +render -noreset &
sleep 1

export DISPLAY="${DISPLAY_NUM}"

echo "Starting Openbox window manager"
openbox >/tmp/facetbound-gui/openbox.log 2>&1 &

echo "Starting x11vnc on port ${VNC_PORT}"
x11vnc \
  -display "${DISPLAY_NUM}" \
  -forever \
  -shared \
  -nopw \
  -rfbport "${VNC_PORT}" \
  >/tmp/facetbound-gui/x11vnc.log 2>&1 &

echo "Starting noVNC on http://localhost:${HTTP_PORT}/vnc.html"
websockify \
  --web=/usr/share/novnc/ \
  "${HTTP_PORT}" \
  "localhost:${VNC_PORT}" \
  >/tmp/facetbound-gui/websockify.log 2>&1 &

echo "Launching Facetbound from ${GODOT_PROJECT_PATH}"
exec godot --path "${GODOT_PROJECT_PATH}" "${GODOT_MAIN_SCENE}"
