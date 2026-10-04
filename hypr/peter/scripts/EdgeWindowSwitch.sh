#!/usr/bin/env bash
# EdgeWindowSwitch.sh
# Cycle the focused window when the pointer touches the left or right screen edge.
#
# Left edge  -> focus the window to the left  (movefocus l)
# Right edge -> focus the window to the right (movefocus r)
#
# Tunables (env vars):
#   EDGE_PX      px from the edge that counts as "touching"   (default 6)
#   DWELL_MS     ms the pointer must stay on the edge          (default 150)
#   COOLDOWN_MS  ms between two triggers                       (default 700)
#   REARM_PX     px to move away before the edge can trigger again (default 28)
#   POLL_MS      polling interval                              (default 70)
#   LEFT_CMD     command for the left edge  (default "hyprctl dispatch movefocus l")
#   RIGHT_CMD    command for the right edge (default "hyprctl dispatch movefocus r")
#
# Test helpers:
#   DRY_RUN=1                      log instead of dispatching
#   CURSOR_OVERRIDE="x,y"          use a fixed cursor position instead of hyprctl

set -u

EDGE_PX="${EDGE_PX:-6}"
DWELL_MS="${DWELL_MS:-150}"
COOLDOWN_MS="${COOLDOWN_MS:-700}"
REARM_PX="${REARM_PX:-28}"
POLL_MS="${POLL_MS:-70}"
LEFT_CMD="${LEFT_CMD:-hyprctl dispatch movefocus l}"
RIGHT_CMD="${RIGHT_CMD:-hyprctl dispatch movefocus r}"
DRY_RUN="${DRY_RUN:-0}"
CURSOR_OVERRIDE="${CURSOR_OVERRIDE:-}"

command -v hyprctl >/dev/null 2>&1 || exit 0

# single-instance lock
exec 9>/tmp/.edge_window_switch.lock
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || exit 0
fi

now_ms() { date +%s%3N; }
poll_s="$(awk "BEGIN{printf \"%.3f\", ${POLL_MS}/1000}")"

# monitors as "x y w h" (logical), refreshed periodically
declare -a MONITORS=()
refresh_monitors() {
  mapfile -t MONITORS < <(
    hyprctl -j monitors 2>/dev/null \
      | jq -r '.[] | "\(.x|floor) \(.y|floor) \((.width/.scale)|floor) \((.height/.scale)|floor)"'
  )
}

# find the monitor containing the cursor; fallback to the first one
select_monitor() {
  local px="$1" py="$2" m mx my mw mh
  for m in "${MONITORS[@]}"; do
    read -r mx my mw mh <<<"$m"
    if (( px >= mx && px < mx + mw && py >= my && py < my + mh )); then
      echo "$mx $mw"
      return
    fi
  done
  if ((${#MONITORS[@]} > 0)); then
    read -r mx my mw mh <<<"${MONITORS[0]}"
    echo "$mx $mw"
  else
    echo "0 0"
  fi
}

log() { [ "$DRY_RUN" = "1" ] && printf '%s\n' "$*"; }
dispatch() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '[edge] %s\n' "$1"
  else
    sh -c "$1" >/dev/null 2>&1
  fi
}

refresh_monitors
last_refresh=$(now_ms)
in_left_since=0
in_right_since=0
armed_left=1
armed_right=1
last_trigger=0

while sleep "$poll_s"; do
  command -v hyprctl >/dev/null 2>&1 || exit 0

  if [ -n "$CURSOR_OVERRIDE" ]; then
    pos="$CURSOR_OVERRIDE"
  else
    pos="$(hyprctl cursorpos 2>/dev/null)" || continue
  fi
  case "$pos" in *,*) ;; *) continue ;; esac

  x="${pos%%,*}"; y="${pos#*,}"
  x="${x// /}"; y="${y// /}"
  [[ "$x" =~ ^-?[0-9]+$ && "$y" =~ ^-?[0-9]+$ ]] || continue

  now=$(now_ms)
  if (( now - last_refresh > 5000 )); then
    refresh_monitors
    last_refresh=$now
  fi

  read -r mon_x mon_w < <(select_monitor "$x" "$y")
  (( mon_w > 0 )) || continue

  left_edge=$(( mon_x + EDGE_PX ))
  right_edge=$(( mon_x + mon_w - EDGE_PX ))

  # --- left edge ---
  if (( x <= left_edge )); then
    (( in_left_since == 0 )) && in_left_since=$now
    if (( armed_left == 1 && now - in_left_since >= DWELL_MS && now - last_trigger >= COOLDOWN_MS )); then
      dispatch "$LEFT_CMD"
      last_trigger=$now
      armed_left=0
    fi
  else
    in_left_since=0
    (( x > mon_x + REARM_PX )) && armed_left=1
  fi

  # --- right edge ---
  if (( x >= right_edge )); then
    (( in_right_since == 0 )) && in_right_since=$now
    if (( armed_right == 1 && now - in_right_since >= DWELL_MS && now - last_trigger >= COOLDOWN_MS )); then
      dispatch "$RIGHT_CMD"
      last_trigger=$now
      armed_right=0
    fi
  else
    in_right_since=0
    (( x < mon_x + mon_w - REARM_PX )) && armed_right=1
  fi
done
