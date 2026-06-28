#!/bin/bash
# Wires Claude Code hooks -> per-session pet state (keyed by session_id).
# Idempotent: strips any prior claude-pet entries before re-adding.
# Backs up settings.json first. Requires jq.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PE="$ROOT/pet-event.sh"
SET="$HOME/.claude/settings.json"

chmod +x "$PE"
mkdir -p "$HOME/.claude"
[ -f "$SET" ] || echo '{}' > "$SET"
cp "$SET" "$SET.bak"

jq --arg pe "$PE" --arg root "$ROOT" '
  def clean(ev): (.hooks[ev] // []) | map(select(((.hooks[0].command) // "") | contains($root) | not));
  .hooks = (.hooks // {})
  | .hooks.SessionStart = (clean("SessionStart")
      + [{"hooks":[{"type":"command","command":($pe + " session-start")}]}])
  | .hooks.UserPromptSubmit = (clean("UserPromptSubmit")
      + [{"hooks":[{"type":"command","command":($pe + " working")}]}])
  | .hooks.PreToolUse = (clean("PreToolUse")
      + [{"matcher":"*",    "hooks":[{"type":"command","command":($pe + " working")}]}]
      + [{"matcher":"Task", "hooks":[{"type":"command","command":($pe + " agent-inc")}]}])
  | .hooks.SubagentStop = (clean("SubagentStop")
      + [{"hooks":[{"type":"command","command":($pe + " agent-dec")}]}])
  | .hooks.Stop = (clean("Stop")
      + [{"hooks":[{"type":"command","command":($pe + " done agent-reset")}]}])
  | .hooks.Notification = (clean("Notification")
      + [{"hooks":[{"type":"command","command":($pe + " waiting")}]}])
  | .hooks.SessionEnd = (clean("SessionEnd")
      + [{"hooks":[{"type":"command","command":($pe + " session-end")}]}])
' "$SET" > "$SET.tmp" && mv "$SET.tmp" "$SET"

echo "Hooks installed -> $SET (backup: $SET.bak)"
echo "Restart any running Claude Code session to pick them up."
