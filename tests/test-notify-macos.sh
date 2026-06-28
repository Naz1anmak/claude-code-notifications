#!/bin/bash
# test-notify-macos.sh — black-box tests for the focus guard in notify-macos.sh.
#
# No real toasts and no real frontmost lookup: we stub `osascript` (to report a
# chosen frontmost bundle id via $FAKE_FRONT) and point $NOTIFIER at a stub that
# records whether a notification *would* have fired.
#
# Run: bash tests/test-notify-macos.sh

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../scripts/notify-macos.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Stub osascript: ignore args, echo the frontmost bundle id we want to simulate.
cat > "$WORK/osascript" <<'EOF'
#!/bin/bash
echo "${FAKE_FRONT:-}"
EOF
chmod +x "$WORK/osascript"

# Stub notifier: record that it was invoked.
MARKER="$WORK/notified"
cat > "$WORK/notifier" <<EOF
#!/bin/bash
touch "$MARKER"
EOF
chmod +x "$WORK/notifier"

PASS=0
FAIL=0

# run_case <name> <expect: notify|suppress>  — remaining args are extra env (KEY=VAL)
run_case() {
    local name="$1" expect="$2"; shift 2
    rm -f "$MARKER"
    env -i \
        PATH="$WORK:/usr/bin:/bin" \
        HOME="$HOME" \
        NOTIFIER="$WORK/notifier" \
        "$@" \
        bash "$SCRIPT" -title "test" -message "test" >/dev/null 2>&1

    local got="notify"
    [ -f "$MARKER" ] || got="suppress"

    if [ "$got" = "$expect" ]; then
        echo "ok   - $name (expected $expect)"
        PASS=$((PASS + 1))
    else
        echo "FAIL - $name (expected $expect, got $got)"
        FAIL=$((FAIL + 1))
    fi
}

# --- Claude desktop app ("Code" section) -------------------------------------
# The desktop app owns notifications entirely: it stays silent while focused and
# fires its own native toast when backgrounded. Our wrapper must never emit there
# (it would duplicate the app's notification) — regardless of what's frontmost.
run_case "desktop app frontmost -> suppress" suppress \
    CLAUDE_CODE_ENTRYPOINT=claude-desktop FAKE_FRONT=com.anthropic.claudefordesktop

run_case "desktop session, user switched away -> suppress" suppress \
    CLAUDE_CODE_ENTRYPOINT=claude-desktop FAKE_FRONT=com.apple.Safari

# --- Standalone terminal (regression) ----------------------------------------
run_case "Apple Terminal frontmost -> suppress" suppress \
    TERM_PROGRAM=Apple_Terminal FAKE_FRONT=com.apple.Terminal

run_case "Terminal session, browser frontmost -> notify" notify \
    TERM_PROGRAM=Apple_Terminal FAKE_FRONT=com.apple.Safari

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
