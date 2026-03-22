#!/usr/bin/env bash
set -euo pipefail

project_dir="${GODOT_PROJECT_PATH:-/workspace/game}"
project_file="${project_dir}/project.godot"
preset_file="${project_dir}/export_presets.cfg"
main_scene="${project_dir}/scenes/main.tscn"

if [[ ! -f "${project_file}" ]]; then
    echo "Missing Godot project file: ${project_file}" >&2
    exit 1
fi

if [[ ! -f "${preset_file}" ]]; then
    echo "Missing export preset file: ${preset_file}" >&2
    exit 1
fi

if [[ ! -f "${main_scene}" ]]; then
    echo "Missing startup scene: ${main_scene}" >&2
    exit 1
fi

if ! grep -q 'name="Linux/X11"' "${preset_file}"; then
    echo "Missing Linux/X11 export preset in ${preset_file}" >&2
    exit 1
fi

mkdir -p /workspace/dist

echo "Importing and validating Godot project from ${project_dir}"
godot --headless --path "${project_dir}" --import

echo "Running startup scene smoke check"
godot --headless --path "${project_dir}" --quit-after 1
