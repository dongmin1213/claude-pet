# claude-pet 🦀

A macOS **menu bar** pet that shows your Claude Code session state at a glance.
A small crab lives in the menu bar; click it to pop open a panel of animated crabs —
one per running session. Built so you can glance up and know whether Claude is
working, waiting for you, or done — without a window covering your work.

![states](docs/states.png)

## What it shows

- **Menu bar icon.** A 🦀 plus a glanceable summary of the busiest state across all
  sessions (e.g. `🦀🔨2` = two sessions working). Priority: working > waiting > done > idle.
- **Click → panel.** Opens directly under the icon with the full scene:
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

The panel auto-fits (down for more sessions, right for more subagents), stays on
screen, and closes when you click away. Left-click the menu bar icon toggles it;
right-click → quit.

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
- Future: animate the menu bar icon itself, real Clawd sprite, autostart toggle in the
  right-click menu.
