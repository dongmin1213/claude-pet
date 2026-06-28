# claude-pet 🦀

A floating macOS desktop pet that shows your Claude Code session state at a glance.
Built so you can glance at one screen and know whether Claude is working, waiting for
you, or done — while you do other things on another screen.

![states](docs/states.png)

## What it shows

- **Vertical = sessions.** One row per running Claude Code session (terminal).
- **Horizontal = subagents.** Each session's running subagents line up to the right
  as smaller, differently-colored crabs.
- **State per session** (emoji + motion):
  | state | icon | meaning |
  |-------|------|---------|
  | working | 🔨 | Claude is working (fast bob) |
  | waiting | 💬 | waiting for your input / permission (looks around) |
  | done | ✅ | just finished (jump + sparkle, reverts to idle after 4s) |
  | idle | 💤 | nothing running (slow breathing) |

The window auto-resizes (down for more sessions, right for more subagents) and stays
on screen. Drag the pet to move it; right-click → quit.

## How it works

```
Claude Code hooks → ~/.claude-pet/sessions/<session_id>/{state,agents,born} → pet polls → animates
```

`hooks/pet-event.sh` is the single hook entrypoint. It reads the hook JSON on stdin to
key state by `session_id`. `hooks/install-hooks.sh` wires the hooks into
`~/.claude/settings.json` (idempotent, backs up first).

## Build & run

```bash
./build.sh                       # -> build/ClaudePet.app (swiftc, no Xcode project)
open build/ClaudePet.app
./hooks/install-hooks.sh         # wire up Claude Code hooks (restart sessions after)
```

## Auto-start at login

`launchd/com.claudepet.agent.plist` is loaded into `~/Library/LaunchAgents/` to launch
the pet at login. Disable with:

```bash
launchctl unload ~/Library/LaunchAgents/com.claudepet.agent.plist
```

## Notes / TODO

- The orange pixel crab is an **original homage** to Anthropic's Clawd mascot (safe to
  share). Swap in real art later if desired.
- Future: remember last position, real Clawd sprite, per-session labels.
