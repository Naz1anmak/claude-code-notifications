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
# $env:TERM_PROGRAM is set by every modern emulator (vscode, etc.).
# Falls back to a generic terminal list when unset.
switch ($env:TERM_PROGRAM) {
    'vscode' {
        # VS Code forks: Code, Code - Insiders, VSCodium, Cursor, Windsurf...
        if ($frontProcess -match '^(Code|Code - Insiders|VSCodium|Cursor|Windsurf)$') { exit 0 }
    }
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
