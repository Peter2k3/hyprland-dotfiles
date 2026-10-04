#!/usr/bin/env bash
# Resolve a workspace slot relative to the focused monitor.

set -euo pipefail

slot="${1:-}"
action="${2:-switch}"

if [[ ! "$slot" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Usage: %s SLOT [switch|move|silent]\n' "$0" >&2
  exit 2
fi

monitor="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name')"
[[ -n "$monitor" ]] || exit 1

target="$(hyprctl -j workspaces | jq -r --arg monitor "$monitor" --argjson slot "$slot" '
  [.[] | select(.monitor == $monitor and .id > 0) | .id]
  | sort
  | .[$slot - 1] // empty
')"

if [[ -z "$target" ]]; then
  printf 'No workspace slot %s exists on monitor %s\n' "$slot" "$monitor" >&2
  exit 1
fi

case "$action" in
  switch)
    hyprctl dispatch workspace "$target" >/dev/null
    ;;
  move)
    hyprctl dispatch movetoworkspace "$target" >/dev/null
    ;;
  silent)
    hyprctl dispatch movetoworkspacesilent "$target" >/dev/null
    ;;
  *)
    printf 'Unknown action: %s\n' "$action" >&2
    exit 2
    ;;
esac
