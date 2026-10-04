#!/usr/bin/env bash
# Toggle a disposable btop special workspace.

set -u

SPECIAL_NAME="btop"
SPECIAL_WS="special:$SPECIAL_NAME"
APP_ID="btop-scratchpad"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-btop-scratchpad.lock"

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

if hyprctl -j clients 2>/dev/null | jq -e --arg app "$APP_ID" \
  'any(.[]; .class == $app or .initialClass == $app)' >/dev/null; then
  hyprctl dispatch togglespecialworkspace "$SPECIAL_NAME" >/dev/null 2>&1
  exit 0
fi

hyprctl dispatch exec \
  "[workspace $SPECIAL_WS silent;float;size 1250 720;center] kitty --class $APP_ID --app-id $APP_ID --title btop -e btop" \
  >/dev/null 2>&1

# Show it only after the window has been created.
for _ in $(seq 1 30); do
  if hyprctl -j clients 2>/dev/null | jq -e --arg app "$APP_ID" \
    'any(.[]; .class == $app or .initialClass == $app)' >/dev/null; then
    hyprctl dispatch togglespecialworkspace "$SPECIAL_NAME" >/dev/null 2>&1
    exit 0
  fi
  sleep 0.1
done
