<div align="right">

[![English](https://img.shields.io/badge/lang-English-blue?style=for-the-badge)](README.md)
[![Русский](https://img.shields.io/badge/lang-Русский-red?style=for-the-badge)](README.ru.md)

</div>

# Claude Code Notifications

A guided skill that adds native desktop notifications to [Claude Code](https://docs.claude.com/en/docs/claude-code) on **macOS**, **Linux**, and **Windows** — alerts when Claude finishes a turn, when a tool needs permission, or when an interactive question is waiting.

Built around the `Stop` / `PermissionRequest` hooks in `~/.claude/settings.json`. Each hook calls a small wrapper script that **suppresses the toast when a terminal emulator is in the foreground** — same behaviour as Slack or VS Code: apps in focus don't ping themselves.

## Why this exists

Out of the box Claude Code is silent — if you ALT-TAB to a browser while it's working, you'll miss the moment it finishes, or the moment it asks for permission to run a command. This skill wires up:

- 🔔 **Stop** — "response ready" toast the moment Claude finishes its turn
- 🚦 **PermissionRequest** — separate toasts (and optionally separate sounds) for tool approvals (`Bash`/`Edit`/`Write`/...) versus interactive choice prompts (`AskUserQuestion`/`ExitPlanMode`)
- 🙈 **Focus guard** — silently skipped when your terminal is already on screen
- 🔊 Per-category sounds, customisable per OS
- 🖼 Optional icon (Claude Desktop's, if installed)

## Install

```bash
git clone https://github.com/<your-username>/claude-code-notifications.git ~/.claude/skills/claude-code-notifications
```

Then in any Claude Code session, run:

```
/skill claude-code-notifications
```

Claude will walk you through:

1. Detect OS, check for `terminal-notifier` / `notify-send` / `BurntToast`. Offer to install via `brew` / `apt` / `Install-Module` if missing — never installs without your consent.
2. Ask which hooks to wire (Stop / generic PermissionRequest / question PermissionRequest / idle Notification).
3. Ask language for notification text (English / Russian / custom).
4. Ask whether you want one sound or different sounds per category, and which sounds.
5. Ask about icon — extract from Claude Desktop, point at your own file, or skip.
6. Ask whether to suppress when a terminal is focused (recommended).
7. Install the wrapper script to `~/.claude/bin/notify.<sh|ps1>` and patch `~/.claude/settings.json`.
8. Pipe-test each hook so you confirm the toasts arrive before finishing.

## Audition macOS sounds

The wizard suggests a default per category, but you can preview them all first:

```bash
for s in /System/Library/Sounds/*.aiff; do
  echo "$(basename "$s" .aiff)"
  afplay "$s"
  sleep 0.3
done
```

Or open them in Finder and tap Space for QuickLook playback:

```bash
open /System/Library/Sounds/
```

## Supported platforms

| OS | Backend | Sound | Icon | Focus guard |
|---|---|---|---|---|
| macOS 12+ | `terminal-notifier` (or `osascript` fallback) | `/System/Library/Sounds/*.aiff` | `-contentImage` (large, right side) — `-appIcon` is silently ignored by macOS 13+ | `osascript` against frontmost bundle ID |
| Linux (X11) | `notify-send` + `paplay`/`aplay` | event sound name or `.wav`/`.ogg` path | `notify-send -i` | `xdotool getactivewindow getwindowclassname` |
| Linux (Wayland) | `notify-send` + `paplay` | as above | as above | best-effort via `hyprctl` / `swaymsg`; otherwise always notifies |
| Windows 10/11 | `BurntToast` PowerShell module | preset name (`IM`, `Reminder`, …) or `.wav` path | `-AppLogo` | `GetForegroundWindow` via P/Invoke |

## Caveats

- **macOS 13+ ignores the top-left app icon** — the sender (terminal-notifier) is always shown. Only `-contentImage` (large right-side image) can be customised. Not a bug in this skill; system-level limitation.
- **Linux Wayland focus detection** is unreliable outside Hyprland/Sway. The wrapper falls back to always-notify.
- **BurntToast** requires a Windows Store/MSIX-style sender — the toast will be attributed to "PowerShell" unless you register a custom AppId. This is mentioned in the wizard.
- **No icon is bundled**. If you pick "use Claude Desktop's icon" the wizard extracts it from your local `/Applications/Claude.app` (macOS only). The icon's copyright stays with Anthropic.

## License

MIT — see [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome. Especially:
- New terminal emulator bundle IDs / WM classes for the focus guard
- Translations for the notification phrasebook
- Windows-specific polish (custom AppId registration for proper sender attribution)
