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
# Suppress only if the host that runs Claude is itself frontmost.
#
# Two detection signals, in order of reliability:
#   1. VS Code env vars ($VSCODE_PID / $VSCODE_IPC_HOOK) — set by the VS Code
#      extension host for BOTH the integrated terminal AND extension
#      subprocesses (e.g. the Claude Code VS Code plugin). $TERM_PROGRAM is
#      NOT set in the extension-subprocess case, so this is the only way to
#      catch it. Same vars work for VS Code forks (Cursor, Codium, ...).
#   2. $TERM_PROGRAM — set by every standalone emulator (Apple_Terminal,
#      iTerm.app, ghostty, ...).
# Falls back to a generic-terminal list if neither signal is present.

FRONT=$(osascript -e 'tell application "System Events" to bundle identifier of first process whose frontmost is true' 2>/dev/null)

# 1. VS Code family (integrated terminal OR extension subprocess)
if [ -n "${VSCODE_PID:-}" ] || [ -n "${VSCODE_IPC_HOOK:-}" ]; then
    case "$FRONT" in
        *VSCode*|*vscode*|*code-oss*|*VSCodium*|*todesktop*|*Cursor*|*Windsurf*)
            exit 0 ;;
    esac
fi

# 1b. Claude desktop app — the "Code" section runs Claude Code as a subprocess
#     of the app, which sets $CLAUDE_CODE_ENTRYPOINT=claude-desktop and does NOT
#     set $TERM_PROGRAM. Without this branch it would fall through to the generic
#     list below (which has no desktop bundle id) and the toast would fire even
#     while the user is looking right at the session.
if [ "${CLAUDE_CODE_ENTRYPOINT:-}" = "claude-desktop" ]; then
    [ "$FRONT" = "com.anthropic.claudefordesktop" ] && exit 0
fi

# 2. Standalone emulator via TERM_PROGRAM
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
# Honor a caller-provided $NOTIFIER (custom installs / tests) before probing.
if [ -n "${NOTIFIER:-}" ] && [ -x "$NOTIFIER" ]; then
    exec "$NOTIFIER" "$@"
elif [ -x /opt/homebrew/bin/terminal-notifier ]; then
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
