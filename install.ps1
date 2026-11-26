<#
.SYNOPSIS
    Get claude-config onto a fresh Windows workstation, then run its setup.

.DESCRIPTION
    Meant to be downloaded, read, then run (see README "New workstation
    setup"). It is short on purpose. It:

      1. Finds Git, or offers to install Git for Windows for this user only
         (winget --scope user, no admin rights).
      2. Clones the repository to -Path (default: <your profile>\repos\claude-config),
         or reuses an existing clone there. It never deletes or overwrites a folder.
      3. Runs setup.cmd from the clone, which does the rest (tools, PATH,
         sign-in, configuration, validation) and asks before installing or
         removing anything.

    Safe to rerun. Runs on Windows PowerShell 5.1 and PowerShell 7. It never
    elevates and never changes the execution policy.

    Exit code: setup's exit code (0 done, 1 needs fixing, 2 warnings), or 1
    if Git or the clone is not available.

.PARAMETER Path
    Where to clone. An existing clone there is reused.

.PARAMETER Repository
    Git URL to clone. Forks pass their own URL.

.PARAMETER Yes
    Install Git without asking, and pass -Yes to setup.

.PARAMETER NonInteractive
    Never prompt; pass -NonInteractive to setup.

.PARAMETER DryRun
    Change nothing: report what would be installed or cloned, and run setup
    with -DryRun if a clone already exists.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy RemoteSigned -File install.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy RemoteSigned -File install.ps1 -Path D:\src\claude-config
#>
[CmdletBinding()]
param(
    [string]$Path = (Join-Path (Join-Path $HOME 'repos') 'claude-config'),
    [string]$Repository = 'https://github.com/vult-systems/claude-config.git',
    [switch]$Yes,
    [switch]$NonInteractive,
    [switch]$DryRun,
    # Anything else (e.g. -SkipAuth, -NoInstall, -Force) is passed to setup.
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$SetupArguments = @()
)
$ErrorActionPreference = 'Stop'

function Say([string]$m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Info([string]$m) { Write-Host "  $m" }
function Stop-Install([string]$m) { Write-Host "  [fail] $m" -ForegroundColor Red; exit 1 }
function Find-Git { return (Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1) }
# Picks up tools installed after this window was opened (e.g. by winget).
function Update-SessionPath {
    $known = @{}
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($src in @($env:Path, [Environment]::GetEnvironmentVariable('Path', 'Machine'), [Environment]::GetEnvironmentVariable('Path', 'User'))) {
        if (-not $src) { continue }
        foreach ($e in ($src -split ';')) {
            $k = $e.Trim().TrimEnd('\').ToLowerInvariant()
            if ($k -and -not $known.ContainsKey($k)) { $known[$k] = $true; $parts.Add($e) }
        }
    }
    $env:Path = $parts -join ';'
}
function Confirm-Step([string]$Question) {
    if ($Yes) { return $true }
    if ($NonInteractive) { return $false }
    $a = (Read-Host "  ? $Question [Y/n]").Trim().ToLowerInvariant()
    return (-not $a -or $a -eq 'y' -or $a -eq 'yes')
}

Say 'claude-config installer'
Info "Repository: $Repository"
Info "Clone to:   $Path"

# ------------------------------------------------------------------ Git
Update-SessionPath
if (Find-Git) {
    Info "Git found: $((Find-Git).Source)"
} else {
    $cmdLine = 'winget install --id Git.Git -e --source winget --scope user'
    if ($DryRun) { Info "(dry run) would install Git for Windows: $cmdLine"; exit 0 }
    if (-not (Confirm-Step 'Git for Windows is not installed. Install it for this user with winget?')) {
        Stop-Install "Git is required. Install it ($cmdLine), then run this again."
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        # Often provisioned but not yet registered on a new Windows profile.
        try { Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop } catch { }
        Update-SessionPath
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Stop-Install 'winget is not available. Update "App Installer" from the Microsoft Store (or install Git from https://git-scm.com), then run this again.'
    }
    & winget install --id Git.Git -e --source winget --scope user --accept-source-agreements --accept-package-agreements --disable-interactivity
    Update-SessionPath
    if (-not (Find-Git)) { Stop-Install "Git install did not complete (winget exit code $LASTEXITCODE). Fix the error above and run this again." }
    Info "Git installed: $((Find-Git).Source)"
}

# ------------------------------------------------------------------ clone
$setupCmd = Join-Path $Path 'setup.cmd'
if (Test-Path -LiteralPath (Join-Path $Path '.git')) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & git -C $Path rev-parse --verify --quiet HEAD *> $null
    $ok = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $old
    if (-not $ok -or -not (Test-Path -LiteralPath $setupCmd)) {
        Stop-Install "$Path holds an incomplete clone (an interrupted download?). Delete that folder and run this again, or pass -Path."
    }
    Info "Using the existing clone. (To update it later: scripts\sync.ps1)"
} elseif ((Test-Path -LiteralPath $Path) -and @(Get-ChildItem -LiteralPath $Path -Force).Count -gt 0) {
    Stop-Install "$Path exists and is not a claude-config clone. Choose another folder with -Path."
} elseif ($DryRun) {
    Info "(dry run) would run: git clone $Repository `"$Path`""
    exit 0
} else {
    Say 'Cloning'
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & git clone $Repository $Path
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $setupCmd)) { Stop-Install "git clone failed (exit code $code). Check the URL and your connection, delete $Path if it was created, and run this again." }
}

# ------------------------------------------------------------------ setup
$pass = @()
if ($Yes) { $pass += '-Yes' }
if ($NonInteractive) { $pass += '-NonInteractive' }
if ($DryRun) { $pass += '-DryRun' }
$pass += $SetupArguments
Say "Running $setupCmd $($pass -join ' ')"
& $setupCmd @pass
exit $LASTEXITCODE
