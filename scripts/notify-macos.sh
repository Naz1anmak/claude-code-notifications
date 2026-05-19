#!/bin/bash
# notify-macos.sh — focus-guarded wrapper around terminal-notifier.
#
# Skips the toast if a terminal emulator is the frontmost app.
# Used by Claude Code hooks (Stop / PermissionRequest / Notification).
#
# Required: /opt/homebrew/bin/terminal-notifier (or /usr/local/bin/...).
# Forward all CLI args directly to terminal-notifier.

set -u

# --- focus guard --------------------------------------------------------------
FRONT=$(osascript -e 'tell application "System Events" to bundle identifier of first process whose frontmost is true' 2>/dev/null)

case "$FRONT" in
    com.apple.Terminal \
    | com.googlecode.iterm2 \
    | com.mitchellh.ghostty \
    | dev.warp.Warp-Stable \
    | io.alacritty \
    | org.alacritty \
    | net.kovidgoyal.kitty \
    | com.github.wez.wezterm \
    | co.zeit.hyper \
    | org.tabby)
        exit 0
        ;;
esac

# --- locate terminal-notifier -------------------------------------------------
if [ -x /opt/homebrew/bin/terminal-notifier ]; then
    NOTIFIER=/opt/homebrew/bin/terminal-notifier
elif [ -x /usr/local/bin/terminal-notifier ]; then
    NOTIFIER=/usr/local/bin/terminal-notifier
elif command -v terminal-notifier >/dev/null 2>&1; then
    NOTIFIER=$(command -v terminal-notifier)
else
    # Fallback: osascript. No icon control, default sound only.
    # Args are passed-through but only -title / -message / -subtitle are honored.
    TITLE="Claude Code"
    MSG="(no message)"
    SUB=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -title)        TITLE="$2"; shift 2;;
            -subtitle)     SUB="$2"; shift 2;;
            -message)      MSG="$2"; shift 2;;
            *)             shift;;
        esac
    done
    osascript -e "display notification \"$MSG\" with title \"$TITLE\" subtitle \"$SUB\""
    exit 0
fi

exec "$NOTIFIER" "$@"
