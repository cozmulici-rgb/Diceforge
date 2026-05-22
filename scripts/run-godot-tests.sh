#!/usr/bin/env bash
set -euo pipefail

project_dir="${GODOT_PROJECT_PATH:-/workspace/game}"

echo "Running deterministic Diceforge tests"
godot --headless --path "${project_dir}" -s res://tests/test_runner.gd
