#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
project="$PWD/gameCode/slay-the-strat"
godot="${GODOT_BIN:-godot}"
gut_revision=c80954f47bed74a0a2c471d472c0389f98e0a8f6 # GUT v9.6.1
gut_sha256=1674b52d25eceb8b1ab968f82c09d4874366ffcb0f7167cef326471969c406f5
gut_dir="$project/addons/gut"
gut_stamp="$gut_dir/.$gut_revision"

if [[ ! -f "$gut_stamp" ]]; then
  if [[ -e "$gut_dir" ]]; then
    echo "Move the existing GUT installation at $gut_dir before running the pinned suite." >&2
    exit 1
  fi
  staging=$(mktemp -d)
  trap 'rm -rf "$staging"' EXIT
  curl -fsSL --retry 3 "https://codeload.github.com/bitwes/Gut/tar.gz/$gut_revision" -o "$staging/gut.tar.gz"
  printf '%s  %s\n' "$gut_sha256" "$staging/gut.tar.gz" | sha256sum -c -
  tar -xzf "$staging/gut.tar.gz" -C "$staging" --strip-components=1 "Gut-$gut_revision/addons/gut"
  mkdir -p "$project/addons"
  touch "$staging/addons/gut/.$gut_revision"
  mv -T "$staging/addons/gut" "$gut_dir"
fi

if [[ "${1:-}" == "--install-only" ]]; then
  exit 0
fi

# Isolate the runner and child game from the desktop game's user data.
test_data=$(mktemp -d)
trap 'rm -rf "$test_data" ${staging:+"$staging"}' EXIT
for kind in data config cache; do
  mkdir -p "$test_data/$kind"
done
export XDG_DATA_HOME="$test_data/data"
export XDG_CONFIG_HOME="$test_data/config"
export XDG_CACHE_HOME="$test_data/cache"

"$godot" --headless --path "$project" --import
"$godot" --headless --path "$project" -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit -gdisable_colors "$@"
