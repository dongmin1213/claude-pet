#!/bin/bash
# Single hook entrypoint. Reads the hook JSON on stdin to key state by session_id,
# then applies one or more actions.
# Usage: pet-event.sh <action>...
#   actions: working done waiting idle agent-inc agent-dec agent-reset session-start session-end
BASE="$HOME/.claude-pet/sessions"
input=$(cat 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="default"
SDIR="$BASE/$sid"
AG="$SDIR/agents"
mkdir -p "$SDIR"

for act in "$@"; do
  case "$act" in
    working|done|waiting|idle) printf '%s' "$act" > "$SDIR/state" ;;
    agent-inc)   n=$(cat "$AG" 2>/dev/null || echo 0); printf '%s' $(( ${n:-0} + 1 )) > "$AG" ;;
    agent-dec)   n=$(cat "$AG" 2>/dev/null || echo 0); n=${n:-0}; printf '%s' $(( n > 0 ? n - 1 : 0 )) > "$AG" ;;
    agent-reset) printf '0' > "$AG" ;;
    session-start) [ -f "$SDIR/born" ] || date +%s > "$SDIR/born"; printf 'idle' > "$SDIR/state"; printf '0' > "$AG" ;;
    session-end) rm -rf "$SDIR" ;;
  esac
done
