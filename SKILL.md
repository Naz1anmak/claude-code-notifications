---
name: claude-code-notifications
description: Use when the user wants desktop notifications for Claude Code — alerts when a turn finishes, when a tool needs permission, or when an interactive question (AskUserQuestion/ExitPlanMode) is waiting. Covers macOS, Linux, and Windows. Triggers on phrases like "notify me when claude finishes", "desktop notification for permission prompts", "set up sounds for claude code", "I miss claude's responses when in another window".
---

# Claude Code Notifications

## Overview

A guided wizard that installs OS-native desktop notifications for Claude Code by wiring three hooks in `settings.json`:

- `Stop` — fires when Claude finishes its turn
- `PermissionRequest` — fires when a tool (Bash/Edit/Write/AskUserQuestion/ExitPlanMode/…) waits for approval
- *(optional)* `Notification` — fires on idle "still waiting for input" pings

Each hook calls a small platform-specific wrapper script that:
1. **Skips the alert if a terminal emulator is currently focused** — the user can already see Claude Code, no need to interrupt.
2. Shows a native toast with a custom title, body, sound, and icon.

Cross-platform: macOS uses `terminal-notifier`, Linux uses `notify-send` + `paplay`, Windows uses PowerShell `BurntToast`.

## When to Use

- User asks how to get desktop alerts from Claude Code
- User says they miss Claude's responses while working in another window/space
- User wants different sounds for different events (permission vs question vs done)
- User asks about hooks in `settings.json` for notifications

**Do NOT use** for:
- Mobile push notifications (use `inputNeededNotifEnabled` / `agentPushNotifEnabled` settings — they go through Anthropic's mobile app, not OS toasts)
- Configuring sounds *inside* the terminal (that's the emulator's bell setting, not a Claude Code hook)

## Workflow

Follow these steps in order. Use **AskUserQuestion** for every user-facing choice, not free-form text.

### Step 1 — Detect platform

Run `uname -s`. Map: `Darwin` → macOS, `Linux` → Linux, `MINGW*`/`MSYS*`/`CYGWIN*` → Windows (also check `$OS` for `Windows_NT`).

If undetected: ask the user explicitly via AskUserQuestion.

### Step 2 — Check & install dependencies

| OS | Tool | Install command | Where it lives |
|---|---|---|---|
| macOS | `terminal-notifier` | `brew install terminal-notifier` | `/opt/homebrew/bin/terminal-notifier` (Apple Silicon) or `/usr/local/bin/...` (Intel) |
| Linux | `libnotify-bin` (notify-send), `pulseaudio-utils` (paplay) | `sudo apt install libnotify-bin pulseaudio-utils` (Debian/Ubuntu); `sudo dnf install libnotify` (Fedora); `sudo pacman -S libnotify` (Arch) | `/usr/bin/notify-send`, `/usr/bin/paplay` |
| Windows | `BurntToast` PowerShell module | `Install-Module -Name BurntToast -Scope CurrentUser -Force` | PSGallery |

Run `which terminal-notifier` / `which notify-send` / `Get-Module -ListAvailable BurntToast` first. If missing, ask the user via AskUserQuestion whether to install. Never install without explicit consent — these touch the system.

**macOS without brew fallback:** `osascript -e 'display notification ...'`. Caveats: no custom icon, no sound control (always plays the system Default), no group dedup. Mention these tradeoffs to the user if they decline brew.

### Step 3 — Ask which hooks to wire

AskUserQuestion (multiSelect: true):
- ☑ "Claude finished turn" (Stop hook) — recommended
- ☑ "Permission requests for Bash/Edit/Write/etc" (PermissionRequest, generic tools)
- ☑ "Interactive questions: AskUserQuestion / ExitPlanMode" (PermissionRequest, question tools)
- ☐ "Idle reminder after ~60s" (Notification) — usually overkill if Stop is on

Save which were chosen — only emit hooks for the chosen subset.

### Step 4 — Ask language for notification text

AskUserQuestion: English / Russian / другое (ask user to provide strings).

Keep a small phrasebook keyed by event:

| Key | English | Russian |
|---|---|---|
| done.body | "Response ready" | "Ответ готов" |
| permission.subtitle | "Permission needed" | "Нужно разрешение" |
| permission.body | "Request: $TOOL" | "Запрос: $TOOL" |
| question.subtitle | "Your input needed" | "Нужен ваш выбор" |
| question.body | "Claude is waiting" | "Claude ждёт ответа" |

### Step 5 — Ask sounds per category

AskUserQuestion: "Same sound for everything" / "Different sound per category" / "Silent (visual only)".

If different, ask one sound per chosen category. Show platform-appropriate options:

- **macOS**: `Glass`, `Hero`, `Submarine`, `Blow`, `Tink`, `Ping`, `Pop`, `Sosumi` (see `/System/Library/Sounds/`). User can preview with `afplay /System/Library/Sounds/<Name>.aiff` — suggest the one-liner from the README to audition all of them.
- **Linux**: freedesktop event sound IDs (`bell`, `complete`, `dialog-information`, `message-new-instant`) or a path to a `.wav` / `.ogg`. Played via `paplay` (PulseAudio) or `aplay` (ALSA).
- **Windows**: `Default`, `IM`, `Mail`, `Reminder`, `SMS`, or path to a `.wav`. BurntToast accepts these as `-Sound` values.

### Step 6 — Ask about icon

AskUserQuestion:
- "Use Claude Desktop's icon" — only offer if `/Applications/Claude.app` exists (macOS). Extract via `sips -s format png /Applications/Claude.app/Contents/Resources/electron.icns --out ~/.claude/assets/claude-icon.png -Z 256`.
- "Use a custom file" — ask for absolute path. Validate it exists and is PNG/JPG/ICNS.
- "Default (none)" — skip the `-appIcon`/`-contentImage` flags.

Save final icon path. On Linux/Windows: `-contentImage` equivalent is `notify-send -i <path>` and BurntToast `-AppLogo <path>`.

**macOS caveat to mention:** the app-icon (top-left badge) on macOS 13+ is *always* the sender's icon (terminal-notifier). The bundled icon shows up reliably only as `-contentImage` (the larger image on the right). This is a system limitation.

### Step 7 — Focus guard

AskUserQuestion: "Suppress notifications when a terminal is focused?" → recommend yes (matches IDE/Slack behavior — apps in focus don't ping themselves).

If yes, the wrapper script checks the frontmost app via:
- **macOS**: `osascript -e 'tell application "System Events" to bundle identifier of first process whose frontmost is true'`
- **Linux/X11**: `xdotool getactivewindow getwindowclassname`
- **Linux/Wayland**: best-effort via `hyprctl activewindow` (Hyprland) / `swaymsg -t get_tree` (Sway). Otherwise no-op.
- **Windows**: `(Get-Process | Where-Object {$_.MainWindowHandle -eq [Win32]::GetForegroundWindow()}).ProcessName` — match against `WindowsTerminal`, `pwsh`, `cmd`, `alacritty`, `kitty`, `WezTerm`.

Bundle IDs / class names that count as "terminal" (extend this list as needed):
`com.apple.Terminal`, `com.googlecode.iterm2`, `com.mitchellh.ghostty`, `dev.warp.Warp-Stable`, `io.alacritty`, `org.alacritty`, `net.kovidgoyal.kitty`, `com.github.wez.wezterm`, `co.zeit.hyper`, `org.tabby`, `org.gnome.Terminal`, `org.gnome.Console`, `org.kde.konsole`, `Alacritty`, `kitty`, `WezTerm`, `WindowsTerminal`.

### Step 8 — Install wrapper script

Copy the platform-specific script from `scripts/` to `~/.claude/bin/notify.<sh|ps1>`. `chmod +x` on POSIX. The script ships with the focus-guard list already populated; the wizard substitutes the user's choices (sounds, icon path, phrasebook) at install time.

See `scripts/notify-macos.sh`, `scripts/notify-linux.sh`, `scripts/notify-windows.ps1` for the canonical implementations — they're already correct, don't rewrite them inline.

### Step 9 — Patch `~/.claude/settings.json`

**Read existing file first**, then merge. Do not overwrite. Use Edit, not Write.

For each chosen hook, append (or replace if a hook on the same event already exists — ask the user first) into `.hooks.<EventName>[].hooks[]`:

```json
{
  "type": "command",
  "command": "<extract-payload>; $HOME/.claude/bin/notify.sh <args>"
}
```

`<extract-payload>` for PermissionRequest is `TOOL=$(jq -r .tool_name); case \"$TOOL\" in AskUserQuestion|ExitPlanMode) … ;; *) … ;; esac`.

For Stop hook the payload is fixed — no jq needed.

Validate with `jq -e '.hooks | keys' ~/.claude/settings.json` after writing.

### Step 10 — Test

Pipe-test each hook command standalone:

```bash
echo '{"tool_name":"Bash"}' | bash -c '<the hook command body>'
echo '{"tool_name":"AskUserQuestion"}' | bash -c '<the hook command body>'
```

Confirm with the user that the toasts arrived. If not, walk the troubleshooting table.

### Step 11 — Activation note

Hook watcher only re-reads `settings.json` if hooks already existed when the session started. If you just *added* a new event (e.g. Stop wasn't there before), tell the user to open `/hooks` or restart Claude Code for it to take effect. Existing hooks reload automatically on file change.

## Quick Reference — Event → Defaults

| Event | Recommended sound (macOS) | Body text (en) | Notes |
|---|---|---|---|
| Stop | `Blow` | "Response ready" | One per turn end |
| PermissionRequest (Bash/Edit/Write/etc) | `Hero` | "Request: $TOOL" | Most common |
| PermissionRequest (AskUserQuestion/ExitPlanMode) | `Submarine` | "Claude is waiting" | Interactive choice |
| Notification (idle) | `Glass` | from `.message` | Often redundant with Stop |

## Common Mistakes

- **Overwriting `settings.json`**: always Read → Edit → merge. Other settings (model, plugins, statusLine) MUST be preserved.
- **Hardcoding `/opt/homebrew/bin/terminal-notifier` on Intel Macs**: use `which terminal-notifier` at install time, hardcode the resolved path.
- **Forgetting `-group`**: without `-group claude-code` each notification stacks separately. Pass it so a new toast replaces the previous one.
- **Trying to override `-appIcon` on macOS 13+ and reporting success**: it's silently ignored. Tell the user explicitly that the large `-contentImage` is the one that takes effect.
- **Installing brew/apt packages without consent**: ALWAYS ask via AskUserQuestion before `brew install` or `sudo apt install`.
- **Skipping the focus guard**: gets old fast — Claude Code pings itself while the user is staring at it.
- **Using `Bash` with multi-line heredocs in hook commands**: hook commands are single-line shell strings in JSON. Keep them one-line, escape `"` properly.
- **Forgetting Linux Wayland limitation**: focus detection on Wayland (non-Hyprland/Sway) is unreliable. Document it and fall back to "always notify".

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| No toast appears at all | Hook not registered, or invalid JSON in `settings.json` | `jq -e .hooks ~/.claude/settings.json`; check `/hooks` UI |
| Toast appears, no sound | macOS Focus mode / Do Not Disturb; system Notification sound disabled for `terminal-notifier` | System Settings → Notifications → terminal-notifier → Allow Sounds |
| New hook added but doesn't fire | Watcher didn't see new event type | Open `/hooks` or restart Claude Code session |
| Linux notify-send works in shell but not from hook | DBus session env missing in hook env | Add `eval "$(dbus-launch --sh-syntax)"` to wrapper, or set `DBUS_SESSION_BUS_ADDRESS` |
| Icon doesn't show on macOS | Trying to set top-left app icon | Only `-contentImage` (right-side large) is reliable on macOS 13+ |
| Toast for every keystroke / spam | Wired Notification *and* Stop *and* PermissionRequest with overlapping triggers | Drop Notification — Stop covers turn-end, PermissionRequest covers tool prompts |

## Implementation Files

- `scripts/notify-macos.sh` — focus-guarded `terminal-notifier` wrapper
- `scripts/notify-linux.sh` — focus-guarded `notify-send` wrapper, sound via `paplay`/`aplay`
- `scripts/notify-windows.ps1` — focus-guarded `New-BurntToastNotification` wrapper

The wizard copies the right script to `~/.claude/bin/notify.<sh|ps1>` and patches `settings.json` to call it. The scripts themselves are stable — do not rewrite them per-user.

**Icon sourcing**: the wizard offers to extract the icon from `Claude.app` if it's installed locally (it ships in the user's own copy of Anthropic's Claude Desktop). This repo does NOT bundle any icon — copyright stays with the user's local install.
