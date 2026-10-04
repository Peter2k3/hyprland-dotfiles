#!/usr/bin/env bash
# Move the focused special-workspace window to the normal workspace below it.

set -u

window_workspace="$(hyprctl -j activewindow 2>/dev/null | jq -r '.workspace.id // 0')"
target_workspace="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id // 0')"

if [[ "$window_workspace" =~ ^- ]] && [[ "$target_workspace" =~ ^[0-9]+$ ]]; then
  hyprctl dispatch movetoworkspacesilent "$target_workspace" >/dev/null 2>&1
fi
