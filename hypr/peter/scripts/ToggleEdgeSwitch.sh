#!/usr/bin/env bash
# Toggle the edge window-switcher daemon on/off with a notification.

set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON="$SELF_DIR/EdgeWindowSwitch.sh"

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send -t 1500 -u low "Edge window switch" "$1" || true
}

if pgrep -f "$DAEMON" >/dev/null 2>&1; then
  pkill -f "$DAEMON" >/dev/null 2>&1
  notify "Desactivado"
else
  setsid "$DAEMON" >/dev/null 2>&1 &
  notify "Activado"
fi
