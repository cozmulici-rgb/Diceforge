#!/usr/bin/env bash
set -euo pipefail

# Runs the Godot project headfully inside the container with Xvfb + x11vnc +
# noVNC so it can be reached at http://localhost:${HTTP_PORT}/vnc.html .
# Mirrors run-browser-editor.sh but launches the game itself (no --editor),
# optionally pinned to a specific scene via GODOT_MAIN_SCENE.

DISPLAY_NUM=${DISPLAY_NUM:-:99}
SCREEN_GEOMETRY=${SCREEN_GEOMETRY:-1470x956x24}
HTTP_PORT=${HTTP_PORT:-6080}
VNC_PORT=${VNC_PORT:-5900}
GODOT_PROJECT_PATH=${GODOT_PROJECT_PATH:-/workspace/game}
GODOT_MAIN_SCENE=${GODOT_MAIN_SCENE:-}

export LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE:-1}
export GALLIUM_DRIVER=${GALLIUM_DRIVER:-llvmpipe}
export MESA_GL_VERSION_OVERRIDE=${MESA_GL_VERSION_OVERRIDE:-4.5}
export DISPLAY="$DISPLAY_NUM"

pids=()
cleanup() {
    for pid in "${pids[@]:-}"; do
        kill "$pid" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM

display_n="${DISPLAY_NUM#:}"
rm -f "/tmp/.X${display_n}-lock" "/tmp/.X11-unix/X${display_n}" 2>/dev/null || true

echo "[entrypoint] Starting Xvfb on $DISPLAY_NUM (geometry $SCREEN_GEOMETRY) ..."
Xvfb "$DISPLAY_NUM" -screen 0 "$SCREEN_GEOMETRY" -ac \
    +extension GLX +extension RENDER -noreset \
    >/tmp/xvfb.log 2>&1 &
pids+=($!)

for attempt in {1..50}; do
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        echo "[entrypoint] Xvfb is up (after ${attempt} attempts)."
        break
    fi
    if [ "$attempt" -eq 50 ]; then
        echo "[entrypoint] ERROR: Xvfb did not come up within 5s." >&2
        cat /tmp/xvfb.log >&2 || true
        exit 1
    fi
    sleep 0.1
done

echo "[entrypoint] Starting openbox ..."
openbox >/tmp/openbox.log 2>&1 &
pids+=($!)

echo "[entrypoint] Starting x11vnc on port $VNC_PORT ..."
x11vnc -display "$DISPLAY" -forever -shared -nopw -localhost \
    -rfbport "$VNC_PORT" -quiet >/tmp/x11vnc.log 2>&1 &
pids+=($!)

echo "[entrypoint] Starting noVNC/websockify on http://localhost:${HTTP_PORT} ..."
websockify --web=/usr/share/novnc "$HTTP_PORT" "localhost:$VNC_PORT" \
    >/tmp/websockify.log 2>&1 &
pids+=($!)

echo "[entrypoint] Importing project assets ..."
godot --headless --path "$GODOT_PROJECT_PATH" --import >/tmp/godot-import.log 2>&1 || true

echo ""
echo "[entrypoint] Game available at:"
echo "    http://localhost:${HTTP_PORT}/vnc.html?autoconnect=1&resize=remote"
echo ""

godot_args=(
    --rendering-driver opengl3
    --display-driver x11
    --path "$GODOT_PROJECT_PATH"
)
if [ -n "$GODOT_MAIN_SCENE" ]; then
    godot_args+=("$GODOT_MAIN_SCENE")
fi

exec godot "${godot_args[@]}"
