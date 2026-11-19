#!/usr/bin/env bash
set -euo pipefail

version=4.7.2
project_dir="gameCode/slay-the-strat"
tools_dir="${XDG_CACHE_HOME:-$HOME/.cache}/sd5913-godot-$version"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}"
base="https://github.com/godotengine/godot/releases/download/$version-stable/Godot_v$version-stable"

mkdir -p "$tools_dir" "$data_dir/godot/export_templates/$version.stable"

if [[ ! -x "$tools_dir/godot" ]]; then
  curl -fL --retry 3 "${base}_linux.x86_64.zip" -o "$tools_dir/editor.zip"
  unzip -oq "$tools_dir/editor.zip" -d "$tools_dir"
  mv "$tools_dir/Godot_v$version-stable_linux.x86_64" "$tools_dir/godot"
  chmod +x "$tools_dir/godot"
fi

if [[ ! -f "$data_dir/godot/export_templates/$version.stable/linux_release.x86_64" ]]; then
  curl -fL --retry 3 "${base}_export_templates.tpz" -o "$tools_dir/templates.tpz"
  unzip -oq "$tools_dir/templates.tpz" -d "$tools_dir"
  cp -a "$tools_dir/templates/." "$data_dir/godot/export_templates/$version.stable/"
fi

"$tools_dir/godot" --headless --path "$project_dir" --import