#!/usr/bin/env bash
# Cycle focus between APPLICATIONS (by window class) on a workspace.
# Unlike `cyclenext` (which walks window by window), this jumps to the next app,
# so an app with several windows still counts as ONE stop.
#
# The app order is STABLE (sorted by class). Using MRU order here would make the
# cycle ping-pong between two apps, because focusing an app moves it to the MRU front.
#
# Usage: CycleApp.sh [next|prev] [workspace-id]
#   DRY_RUN=1  print the target instead of focusing it.

set -u

dir="${1:-next}"
case "$dir" in
  next|prev) ;;
  *) echo "usage: $0 [next|prev] [workspace-id]" >&2; exit 2 ;;
esac
ws_arg="${2:-}"

if [ -n "$ws_arg" ]; then
  ws="$ws_arg"
else
  ws="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id // empty')"
fi
[ -n "$ws" ] || exit 0

active_class="$(hyprctl -j activewindow 2>/dev/null | jq -r '.class // empty')"

# Stable, deduplicated class list for this workspace (alphabetical, locale-independent).
mapfile -t classes < <(
  hyprctl -j clients 2>/dev/null \
    | jq -r --argjson ws "$ws" '.[] | select(.workspace.id == $ws) | .class' \
    | LC_ALL=C sort -u
)

n=${#classes[@]}
(( n > 1 )) || exit 0

# Focus target per app = its most recently used window (lowest focusHistoryID).
declare -A class_addr=()
while IFS=$'\t' read -r _h class addr; do
  [ -n "$class" ] || continue
  [ -n "${class_addr[$class]:-}" ] && continue
  class_addr["$class"]="$addr"
done < <(
  hyprctl -j clients 2>/dev/null \
    | jq -r --argjson ws "$ws" '.[] | select(.workspace.id == $ws) | "\(.focusHistoryID)\t\(.class)\t\(.address)"' \
    | sort -n
)

idx=-1
for i in "${!classes[@]}"; do
  if [ "${classes[$i]}" = "$active_class" ]; then idx=$i; break; fi
done
(( idx >= 0 )) || exit 0

if [ "$dir" = "prev" ]; then
  target=$(( (idx - 1 + n) % n ))
else
  target=$(( (idx + 1) % n ))
fi

target_class="${classes[$target]}"
target_addr="${class_addr[$target_class]:-}"
[ -n "$target_addr" ] || exit 0

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "ws=$ws active=${classes[$idx]} -> ${target_class} (${target_addr})"
  exit 0
fi

hyprctl dispatch focuswindow "address:${target_addr}" >/dev/null 2>&1 || true
