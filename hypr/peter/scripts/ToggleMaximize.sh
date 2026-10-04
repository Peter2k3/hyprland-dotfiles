#!/usr/bin/env bash
# Toggle maximize without using real fullscreen.

set -u

window="$(hyprctl -j activewindow 2>/dev/null)"
workspace_id="$(jq -r '.workspace.id // 0' <<<"$window")"
workspace_layout=""
if [[ "$workspace_id" =~ ^[0-9]+$ ]]; then
  workspace_layout="$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.tiledLayout // empty')"
fi
state="$(jq -r '[.fullscreen // 0, .fullscreenClient // 0] | max' <<<"$window")"

if [[ -z "$window" || "$window" == "null" ]]; then
  exit 0
fi

if [[ "$workspace_layout" == "scrolling" ]]; then
  if [[ "$state" == "2" ]]; then
    hyprctl dispatch fullscreenstate 0 0 >/dev/null 2>&1
    exit 0
  fi

  direction="$(hyprctl getoption scrolling:direction -j 2>/dev/null | jq -r '.str // "right"')"
  column_width="$(hyprctl getoption scrolling:column_width -j 2>/dev/null | jq -r '.float // 0.9')"
  monitor="$(hyprctl -j monitors 2>/dev/null | jq -c '.[] | select(.focused == true)')"

  if [[ -z "$monitor" || "$monitor" == "null" ]]; then
    exit 0
  fi

  if [[ "$direction" == "up" || "$direction" == "down" ]]; then
    current_size="$(jq -r '.size[1]' <<<"$window")"
    monitor_size="$(jq -nr --argjson monitor "$monitor" '$monitor.height / $monitor.scale')"
    axis="y"
  else
    current_size="$(jq -r '.size[0]' <<<"$window")"
    monitor_size="$(jq -nr --argjson monitor "$monitor" '$monitor.width / $monitor.scale')"
    axis="x"
  fi

  is_maximized="$(jq -nr --argjson current "$current_size" --argjson monitor "$monitor_size" '$current >= ($monitor * 0.96)')"
  if [[ "$is_maximized" == "true" ]]; then
    delta="$(jq -nr --argjson current "$current_size" --argjson width "$column_width" '(-($current * (1 - $width))) | round')"
    if [[ "$axis" == "x" ]]; then
      hyprctl dispatch resizeactive "$delta" 0 >/dev/null 2>&1
    else
      hyprctl dispatch resizeactive 0 "$delta" >/dev/null 2>&1
    fi
    hyprctl dispatch fullscreenstate 0 0 >/dev/null 2>&1
  else
    hyprctl dispatch fullscreenstate 1 1 >/dev/null 2>&1
  fi
elif [[ "$state" == "0" ]]; then
  hyprctl dispatch fullscreenstate 1 1 >/dev/null 2>&1
else
  hyprctl dispatch fullscreenstate 0 0 >/dev/null 2>&1
fi
