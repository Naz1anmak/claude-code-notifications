# notify-windows.ps1 — focus-guarded wrapper around BurntToast.
#
# Skips the toast if a terminal emulator is the foreground window.
# Used by Claude Code hooks (Stop / PermissionRequest / Notification).
#
# Required: BurntToast module (`Install-Module BurntToast -Scope CurrentUser`).
#
# Args (named, to mirror terminal-notifier semantics):
#   -Title TEXT
#   -Subtitle TEXT
#   -Body TEXT
#   -Sound NAME|PATH       (BurntToast preset name or .wav path)
#   -Icon PATH             (image shown in toast)
#   -Group ID              (BurntToast deduplication key)

param(
    [string]$Title    = "Claude Code",
    [string]$Subtitle = "",
    [string]$Body     = "",
    [string]$Sound    = "Default",
    [string]$Icon     = "",
    [string]$Group    = "claude-code"
)

# --- focus guard --------------------------------------------------------------
Add-Type -Namespace Win32 -Name User32 -MemberDefinition @"
    [DllImport("user32.dll")]
    public static extern System.IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint lpdwProcessId);
"@

$hwnd = [Win32.User32]::GetForegroundWindow()
$pid_out = 0
[Win32.User32]::GetWindowThreadProcessId($hwnd, [ref]$pid_out) | Out-Null
$frontProcess = (Get-Process -Id $pid_out -ErrorAction SilentlyContinue).ProcessName

# Suppress only if the host that runs Claude is itself frontmost.
#
# 1. VS Code env vars catch both the integrated terminal AND extension
#    subprocesses (e.g. the Claude Code VS Code plugin), where TERM_PROGRAM
#    isn't set.
# 2. $env:TERM_PROGRAM covers standalone emulators.
# Falls back to a generic terminal list when neither is present.

if ($env:VSCODE_PID -or $env:VSCODE_IPC_HOOK) {
    if ($frontProcess -match '^(Code|Code - Insiders|VSCodium|Cursor|Windsurf)$') { exit 0 }
}

# Claude desktop app: the "Code" section runs Claude Code as an app subprocess
# ($env:CLAUDE_CODE_ENTRYPOINT = "claude-desktop"). The app owns notifications
# entirely (silent while focused, native toast when backgrounded), so our
# wrapper must never emit there — otherwise the user gets two toasts when away.
if ($env:CLAUDE_CODE_ENTRYPOINT -eq "claude-desktop") {
    exit 0
}

switch ($env:TERM_PROGRAM) {
    default {
        $terminals = @("WindowsTerminal", "pwsh", "powershell", "cmd", "conhost",
                       "alacritty", "kitty", "wezterm-gui", "wezterm", "Hyper",
                       "Tabby", "wt", "mintty")
        if ($terminals -contains $frontProcess) { exit 0 }
    }
}

# --- toast --------------------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name BurntToast)) {
    Write-Error "BurntToast not installed. Run: Install-Module BurntToast -Scope CurrentUser"
    exit 1
}

Import-Module BurntToast -ErrorAction Stop

$params = @{
    UniqueIdentifier = $Group
}

if ($Body)     { $params.Text = @($Title, $(if ($Subtitle) { "$Subtitle`n$Body" } else { $Body })) }
else           { $params.Text = $Title }

if ($Icon -and (Test-Path $Icon)) { $params.AppLogo = $Icon }

# Sound: BurntToast accepts -Sound (preset) or -Path (.wav). Map both.
if ($Sound) {
    if (Test-Path $Sound) { $params.Path = $Sound }
    else                  { $params.Sound = $Sound }
}

New-BurntToastNotification @params
