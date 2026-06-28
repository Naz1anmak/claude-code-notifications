#!/bin/bash
# notify-linux.sh — focus-guarded wrapper around notify-send + paplay.
#
# Skips the toast if a terminal emulator is the frontmost window.
# Used by Claude Code hooks (Stop / PermissionRequest / Notification).
#
# Required: notify-send (libnotify-bin), optional: paplay/aplay (for -sound).
#
# Args supported (subset of terminal-notifier's, for cross-platform parity):
#   -title TEXT
#   -subtitle TEXT       (rendered as bold prefix in body)
#   -message TEXT
#   -sound NAME|PATH     (PulseAudio sound name or absolute .wav/.ogg path)
#   -appIcon PATH        (passed to notify-send -i)
#   -contentImage PATH   (used as -i if -appIcon absent)
#   -group ID            (notify-send doesn't dedup natively — used as urgency-hint key)

set -u

TITLE="Claude Code"
SUBTITLE=""
MESSAGE=""
SOUND=""
ICON=""
GROUP="claude-code"

while [ $# -gt 0 ]; do
    case "$1" in
        -title)        TITLE="$2"; shift 2;;
        -subtitle)     SUBTITLE="$2"; shift 2;;
        -message)      MESSAGE="$2"; shift 2;;
        -sound)        SOUND="$2"; shift 2;;
        -appIcon)      ICON="$2"; shift 2;;
        -contentImage) [ -z "$ICON" ] && ICON="$2"; shift 2;;
        -group)        GROUP="$2"; shift 2;;
        *)             shift;;
    esac
done

# --- focus guard --------------------------------------------------------------
# Suppress only if the host that runs Claude is itself frontmost. $TERM_PROGRAM
# is set by every terminal emulator (vscode, gnome-terminal, ...). When known,
# we compare it to the active window. When unset, fall back to a generic list.

FRONT=""

if [ -n "${WAYLAND_DISPLAY-}" ]; then
    if command -v hyprctl >/dev/null 2>&1; then
        FRONT=$(hyprctl activewindow -j 2>/dev/null | grep -oE '"class":"[^"]*"' | head -1 | cut -d'"' -f4)
    elif command -v swaymsg >/dev/null 2>&1; then
        FRONT=$(swaymsg -t get_tree 2>/dev/null | grep -oE '"app_id":"[^"]*"[^}]*"focused":true' | head -1 | cut -d'"' -f4)
    fi
elif [ -n "${DISPLAY-}" ]; then
    if command -v xdotool >/dev/null 2>&1; then
        FRONT=$(xdotool getactivewindow getwindowclassname 2>/dev/null)
    fi
fi

# VS Code family: env vars are set for both integrated terminal AND extension
# subprocesses. TERM_PROGRAM may be missing in the extension-subprocess case.
if [ -n "${VSCODE_PID:-}" ] || [ -n "${VSCODE_IPC_HOOK:-}" ]; then
    case "$FRONT" in
        *[Cc]ode*|*VSCodium*|*Cursor*|*Windsurf*)
            exit 0 ;;
    esac
fi

# Claude desktop app: the "Code" section runs Claude Code as an app subprocess
# ($CLAUDE_CODE_ENTRYPOINT=claude-desktop). The app owns notifications entirely
# (silent while focused, native toast when backgrounded), so our wrapper must
# never emit there — otherwise the user gets two toasts when away.
if [ "${CLAUDE_CODE_ENTRYPOINT:-}" = "claude-desktop" ]; then
    exit 0
fi

case "${TERM_PROGRAM:-}" in
    ghostty)
        case "$FRONT" in *[Gg]hostty*) exit 0 ;; esac ;;
    WarpTerminal)
        case "$FRONT" in *[Ww]arp*) exit 0 ;; esac ;;
    "")
        case "$FRONT" in
            *[Tt]erminal* \
            | *[Aa]lacritty* \
            | *[Kk]itty* \
            | *[Ww]ezTerm* \
            | *[Gg]nome-terminal* \
            | *[Kk]onsole* \
            | *[Xx]term* \
            | *[Gg]hostty* \
            | *[Ww]arp*)
                exit 0 ;;
        esac ;;
esac

# --- notify -------------------------------------------------------------------
BODY="$MESSAGE"
[ -n "$SUBTITLE" ] && BODY="<b>$SUBTITLE</b>\n$MESSAGE"

ARGS=(--app-name="Claude Code" --hint=string:desktop-entry:claude-code --hint=string:x-dunst-stack-tag:"$GROUP")
[ -n "$ICON" ] && ARGS+=(-i "$ICON")

notify-send "${ARGS[@]}" "$TITLE" "$BODY"

# --- sound --------------------------------------------------------------------
play_sound() {
    local name="$1"
    if [ -f "$name" ]; then
        # Absolute path
        if command -v paplay >/dev/null 2>&1; then
            paplay "$name" 2>/dev/null &
        elif command -v aplay >/dev/null 2>&1; then
            aplay -q "$name" 2>/dev/null &
        fi
    elif command -v canberra-gtk-play >/dev/null 2>&1; then
        canberra-gtk-play -i "$name" 2>/dev/null &
    fi
}

[ -n "$SOUND" ] && play_sound "$SOUND"

exit 0
