#!/usr/bin/env bash
# Set the layout of the active workspace at runtime (not persisted).
# Persisted defaults live in ~/.config/hypr/peter/workspaces.conf
# Usage: SetWorkspaceLayout.sh <dwindle|master|scrolling|monocle> [workspace-id]

set -euo pipefail

layout="${1:-}"
case "$layout" in
  dwindle|master|scrolling|monocle) ;;
  *)
    echo "usage: $0 <dwindle|master|scrolling|monocle> [workspace-id]" >&2
    exit 2
    ;;
esac

ws="${2:-}"
if [[ -z "$ws" ]]; then
  ws="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id // empty')"
fi

if [[ -z "$ws" ]]; then
  echo "unable to resolve active workspace" >&2
  exit 1
fi

hyprctl keyword workspace "${ws}, layout:${layout}" >/dev/null

if command -v notify-send >/dev/null 2>&1; then
  notify-send -t 1500 -u low "Workspace ${ws}" "Layout: ${layout}" 2>/dev/null || true
fi
