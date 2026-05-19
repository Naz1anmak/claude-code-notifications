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
# Suppress only if the host that runs Claude is itself frontmost. $TERM_PROGRAM
# is set by every terminal emulator (Apple_Terminal, iTerm.app, vscode, ...) —
# we use it to know which GUI app actually contains the Claude session.
# Falls back to the old "any known terminal" list when TERM_PROGRAM is unset.

FRONT=$(osascript -e 'tell application "System Events" to bundle identifier of first process whose frontmost is true' 2>/dev/null)

case "${TERM_PROGRAM:-}" in
    Apple_Terminal)
        [ "$FRONT" = "com.apple.Terminal" ] && exit 0 ;;
    iTerm.app)
        [ "$FRONT" = "com.googlecode.iterm2" ] && exit 0 ;;
    ghostty)
        [ "$FRONT" = "com.mitchellh.ghostty" ] && exit 0 ;;
    WarpTerminal)
        [ "$FRONT" = "dev.warp.Warp-Stable" ] && exit 0 ;;
    Hyper)
        [ "$FRONT" = "co.zeit.hyper" ] && exit 0 ;;
    vscode)
        # All VS Code forks set TERM_PROGRAM=vscode (Cursor, Codium, Insiders, etc).
        # Match by bundle-ID substring instead of an exact list.
        case "$FRONT" in
            *VSCode*|*vscode*|*code-oss*|*VSCodium*|*todesktop*|*Cursor*|*Windsurf*)
                exit 0 ;;
        esac ;;
    "")
        # Unknown host — fall back to historical generic-terminal list.
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
                exit 0 ;;
        esac ;;
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
