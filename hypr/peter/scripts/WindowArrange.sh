#!/usr/bin/env bash
# Arrange the active window as a floating window.

set -euo pipefail

DEFAULT_WIDTH=900
DEFAULT_HEIGHT=600
DEFAULT_MARGIN=24

usage() {
  cat <<'EOF'
Usage:
  WindowArrange.sh float
  WindowArrange.sh size WIDTH HEIGHT
  WindowArrange.sh position center|top-left|top-right|bottom-left|bottom-right [MARGIN]
  WindowArrange.sh place POSITION WIDTH HEIGHT [MARGIN]

Examples:
  WindowArrange.sh place center 1000 700
  WindowArrange.sh place bottom-right 900 600 32
  WindowArrange.sh size 1200 800
  WindowArrange.sh position top-left
EOF
}

die() {
  printf 'WindowArrange: %s\n' "$1" >&2
  exit 1
}

number() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

active_window() {
  local window
  window="$(hyprctl -j activewindow 2>/dev/null | jq -c '.')"
  [[ -n "$window" && "$window" != "null" ]] || die "no active window"
  printf '%s' "$window"
}

monitor_for_window() {
  local monitor_id="$1"
  hyprctl -j monitors 2>/dev/null | jq -c --argjson id "$monitor_id" '.[] | select(.id == $id)'
}

ensure_floating() {
  local window="$1"
  local floating
  floating="$(jq -r '.floating // false' <<<"$window")"
  if [[ "$floating" != "true" ]]; then
    hyprctl dispatch setfloating "address:$(jq -r '.address' <<<"$window")" >/dev/null
    sleep 0.05
  fi
}

window_and_monitor() {
  local window monitor
  window="$(active_window)"
  ensure_floating "$window"
  window="$(active_window)"
  monitor="$(monitor_for_window "$(jq -r '.monitor' <<<"$window")")"
  [[ -n "$monitor" && "$monitor" != "null" ]] || die "could not resolve the active monitor"
  printf '%s\n%s\n' "$window" "$monitor"
}

resize_window() {
  local address="$1" width="$2" height="$3"
  hyprctl dispatch resizewindowpixel "exact ${width} ${height},address:${address}" >/dev/null
}

move_window() {
  local address="$1" x="$2" y="$3"
  hyprctl dispatch movewindowpixel "exact ${x} ${y},address:${address}" >/dev/null
}

place_window() {
  local position="$1" width="$2" height="$3" margin="$4"
  local window monitor address monitor_x monitor_y monitor_width monitor_height
  local x y

  mapfile -t state < <(window_and_monitor)
  window="${state[0]}"
  monitor="${state[1]}"
  address="$(jq -r '.address' <<<"$window")"
  monitor_x="$(jq -r '.x' <<<"$monitor")"
  monitor_y="$(jq -r '.y' <<<"$monitor")"
  monitor_width="$(jq -nr --argjson monitor "$monitor" '$monitor.width / $monitor.scale | floor')"
  monitor_height="$(jq -nr --argjson monitor "$monitor" '$monitor.height / $monitor.scale | floor')"

  case "$position" in
    center)
      x=$((monitor_x + (monitor_width - width) / 2))
      y=$((monitor_y + (monitor_height - height) / 2))
      ;;
    top-left)
      x=$((monitor_x + margin))
      y=$((monitor_y + margin))
      ;;
    top-right)
      x=$((monitor_x + monitor_width - width - margin))
      y=$((monitor_y + margin))
      ;;
    bottom-left)
      x=$((monitor_x + margin))
      y=$((monitor_y + monitor_height - height - margin))
      ;;
    bottom-right)
      x=$((monitor_x + monitor_width - width - margin))
      y=$((monitor_y + monitor_height - height - margin))
      ;;
    *)
      die "unknown position: $position"
      ;;
  esac

  resize_window "$address" "$width" "$height"
  move_window "$address" "$x" "$y"
}

[[ $# -gt 0 ]] || {
  usage
  exit 2
}

action="$1"
shift

case "$action" in
  float)
    window="$(active_window)"
    ensure_floating "$window"
    ;;
  size)
    number "${1:-}" && number "${2:-}" || die "size requires WIDTH HEIGHT"
    mapfile -t state < <(window_and_monitor)
    resize_window "$(jq -r '.address' <<<"${state[0]}")" "$1" "$2"
    ;;
  position)
    position="${1:-}"
    margin="${2:-$DEFAULT_MARGIN}"
    number "$margin" || die "margin must be an integer"
    place_window "$position" "$(jq -r '.size[0]' <<<"$(active_window)")" "$(jq -r '.size[1]' <<<"$(active_window)")" "$margin"
    ;;
  place)
    position="${1:-}"
    width="${2:-$DEFAULT_WIDTH}"
    height="${3:-$DEFAULT_HEIGHT}"
    margin="${4:-$DEFAULT_MARGIN}"
    number "$width" && number "$height" && number "$margin" || die "place requires POSITION WIDTH HEIGHT [MARGIN]"
    place_window "$position" "$width" "$height" "$margin"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    die "unknown action: $action"
    ;;
esac
