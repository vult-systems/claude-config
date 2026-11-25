<#
.SYNOPSIS
    One-step workstation setup: tools, PATH, sign-in, configuration, validation.

.DESCRIPTION
    Brings this workstation to a working claude-config setup and is safe to
    rerun at any point (after an interruption, or on a machine that is already
    set up). Each step checks the current state first and only acts on what
    is missing:

      1. Tools: Git for Windows and GitHub CLI (winget, per-user scope) and
         Claude Code (official native installer, per-user). Asks first.
      2. Claude Code: standardises on the native install. WinGet or npm
         copies are reported and removed only after you confirm.
      3. PATH: adds the Claude Code folder to the user PATH if needed and
         refreshes this session, so no new terminal is needed mid-setup.
      4. Sign-in: GitHub CLI, git credentials (gh auth setup-git), git
         identity and Claude Code, each only when it is not already done.
      5. Configuration: installs this repo like bootstrap.ps1 (backups,
         3-way settings merge, local edits kept).
      6. Validation.

    Runs as a standard user: never elevates, never changes the execution
    policy, never touches the machine PATH. PowerShell 7 is optional.

    Exit code 0 = done, 1 = something still needs fixing, 2 = done with warnings.

.PARAMETER Yes
    Answer yes to install and sign-in prompts. Removing software still asks.

.PARAMETER NonInteractive
    Never prompt. Steps that need an answer are skipped and reported with the
    command to run.

.PARAMETER NoInstall
    Do not install or remove software or change PATH; only report what is missing.

.PARAMETER SkipAuth
    Skip the sign-in and git identity steps.

.PARAMETER Force
    Overwrite managed files that were edited locally (they are backed up first).

.PARAMETER DryRun
    Show what would be done without changing anything.

.EXAMPLE
    .\setup.cmd
    From Command Prompt, Windows Terminal or PowerShell.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\setup.ps1
#>
[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$NonInteractive,
    [switch]$NoInstall,
    [switch]$SkipAuth,
    [switch]$Force,
    [switch]$DryRun,
    # Registry key holding the user PATH; tests point it at a scratch key.
    [Parameter(DontShow = $true)][string]$PathRegistryKey = 'HKCU:\Environment'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ClaudeConfig.psm1') -Force

$script:failures = 0
$script:warnings = 0
function Fail([string]$m) { Write-CcFail $m; $script:failures++ }
function Warn([string]$m) { Write-CcWarn $m; $script:warnings++ }

$interactive = (-not $NonInteractive) -and [Environment]::UserInteractive
if ($interactive) { try { if ([Console]::IsInputRedirected) { $interactive = $false } } catch { } }

# Install and sign-in prompts: -Yes answers them; without a console they are skipped.
function Confirm-Action([string]$Question) {
    if ($DryRun) { Write-CcInfo "(dry run) would ask: $Question"; return $false }
    if ($Yes) { return $true }
    if (-not $interactive) { return $false }
    return (Read-YesNo $Question $true)
}
# Removal prompts always need an explicit answer, default No.
function Confirm-Removal([string]$Question) {
    if ($DryRun) { Write-CcInfo "(dry run) would ask: $Question"; return $false }
    if (-not $interactive) { return $false }
    return (Read-YesNo $Question $false)
}
function Find-Tool([string]$Name) {
    return (Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
}
function Get-ToolVersion([string]$Name) {
    $r = Invoke-Exe -FilePath $Name -Arguments @('--version')
    return (Get-VersionFromText (($r.Output | Select-Object -First 1) -join ''))
}
function Initialize-Winget {
    if (Find-Tool 'winget') { return $true }
    # On a new Windows profile, App Installer (winget) is often provisioned but
    # not yet registered for the user. Registering it needs no admin rights.
    Write-CcInfo 'winget not found; registering App Installer for this user'
    try { Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -ErrorAction Stop } catch { }
    Update-SessionPath $PathRegistryKey
    if (Find-Tool 'winget') { return $true }
    Fail 'winget is not available. Install or update "App Installer" from the Microsoft Store (or ask IT), then rerun setup.'
    return $false
}

$repo = Get-RepoRoot
$claudeHome = Get-ClaudeHome
$dry = ''
if ($DryRun) { $dry = '(dry run) ' }
Write-CcStep "claude-config $(Get-RepoVersion $repo) setup"
Write-CcInfo "Repository:  $repo"
Write-CcInfo "Claude home: $claudeHome"
Write-CcInfo "PowerShell:  $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"

if (Test-IsElevated) {
    Warn "Running as administrator. Tools and configuration are installed for $env:USERNAME only; run setup from a normal terminal if that is not the account you work in."
    if ($interactive -and -not (Read-YesNo 'Continue as administrator?' $false)) { exit 1 }
}

# Pick up tools installed by an earlier, interrupted run or another terminal.
Update-SessionPath $PathRegistryKey

# ------------------------------------------------------------------ tools
Write-CcStep 'Tools'
$tools = @(
    @{ Name = 'git'; Id = 'Git.Git'; Label = 'Git for Windows' },
    @{ Name = 'gh'; Id = 'GitHub.cli'; Label = 'GitHub CLI' }
)
foreach ($t in $tools) {
    if (Find-Tool $t.Name) { Write-CcOk "$($t.Name) $(Get-ToolVersion $t.Name)"; continue }
    $cmdLine = "winget install --id $($t.Id) -e --source winget --scope user"
    if ($NoInstall) { Fail "$($t.Name) not found. Install: $cmdLine"; continue }
    if (-not (Confirm-Action "$($t.Label) is not installed. Install it for this user with winget?")) {
        if (-not $DryRun) { Fail "$($t.Name) not found. Install: $cmdLine (or rerun setup and answer yes)" }
        continue
    }
    if (-not (Initialize-Winget)) { continue }
    Write-CcInfo "Installing $($t.Label) ..."
    $code = Invoke-Attached 'winget' @('install', '--id', $t.Id, '-e', '--source', 'winget', '--scope', 'user',
        '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
    Update-SessionPath $PathRegistryKey
    if (Find-Tool $t.Name) { Write-CcOk "$($t.Name) $(Get-ToolVersion $t.Name) installed" }
    else { Fail "$($t.Label) install did not complete (winget exit code $code). Fix the error above and rerun setup." }
}

# ------------------------------------------------------------------ Claude Code
Write-CcStep 'Claude Code'
$installs = Find-ClaudeInstallations
$native = @($installs | Where-Object { $_.Kind -eq 'native' })
$others = @($installs | Where-Object { $_.Kind -ne 'native' })
$nativeBin = Get-NativeClaudeBin
if ($native.Count -eq 0) {
    $installCmd = 'irm https://claude.ai/install.ps1 | iex'
    if ($NoInstall) {
        if ($others.Count -gt 0 -or (Find-Tool 'claude')) { Warn "Claude Code native install not found. Install it: $installCmd" }
        else { Fail "Claude Code not found. Install: $installCmd" }
    } elseif (Confirm-Action 'Install Claude Code with the official native installer (per user, updates itself)?') {
        Write-CcInfo 'Installing Claude Code ...'
        $ps = (Get-Process -Id $PID).Path
        $code = Invoke-Attached $ps @('-NoProfile', '-Command', "& { $installCmd }")
        $installs = Find-ClaudeInstallations
        $native = @($installs | Where-Object { $_.Kind -eq 'native' })
        if ($native.Count -eq 0) { Fail "Claude Code install did not complete (exit code $code). Fix the error above and rerun setup." }
    } elseif (-not $DryRun) {
        Fail "Claude Code native install not found. Install: $installCmd (or rerun setup and answer yes)"
    }
}
if ($native.Count -gt 0) {
    Write-CcOk "native install: $($native[0].Path)"
    if ($NoInstall) {
        if (-not (Test-PathContains (Get-UserPathRaw $PathRegistryKey) $nativeBin)) { Warn "$nativeBin is not on your user PATH; rerun setup without -NoInstall to add it" }
    } elseif (Add-UserPathEntry -Entry $nativeBin -RegistryKey $PathRegistryKey -DryRun ([bool]$DryRun)) {
        Write-CcInfo "${dry}added $nativeBin to your user PATH"
    }
    if (-not $DryRun -and -not $NoInstall) { Update-SessionPath $PathRegistryKey }
}

# Standardise on the native install: other copies shadow it on PATH and do
# not update themselves. Remove only with explicit confirmation.
foreach ($o in $others) {
    $what = "Claude Code from $($o.Kind) ($($o.Scope)): $($o.Path)"
    if ($native.Count -eq 0) { Warn "$what. Keeping it until the native install is in place."; continue }
    if ($o.Kind -eq 'winget' -and $o.Scope -eq 'machine') {
        Warn "$what is installed for all users; removing it needs admin rights. Ask IT to run: winget uninstall --id Anthropic.ClaudeCode -e"
        continue
    }
    # --scope user so winget never picks a machine-wide copy (which would need elevation).
    $removeCmd = 'winget uninstall --id Anthropic.ClaudeCode -e --scope user'
    $tool = 'winget'
    $removeArgs = @('uninstall', '--id', 'Anthropic.ClaudeCode', '-e', '--scope', 'user', '--disable-interactivity')
    if ($o.Kind -eq 'npm') {
        $removeCmd = 'npm uninstall -g @anthropic-ai/claude-code'
        $tool = 'npm'
        $removeArgs = @('uninstall', '-g', '@anthropic-ai/claude-code')
    }
    if ($NoInstall -or -not (Find-Tool $tool)) { Warn "$what conflicts with the native install. Remove it with: $removeCmd"; continue }
    if (Confirm-Removal "Found a second copy of Claude Code ($($o.Kind)) at $($o.Path). Remove it so only the native install is used?") {
        $code = Invoke-Attached $tool $removeArgs
        $still = @(Find-ClaudeInstallations | Where-Object { $_.Kind -eq $o.Kind -and $_.Scope -eq $o.Scope })
        if ($still.Count -eq 0) { Write-CcOk "removed the $($o.Kind) copy" }
        else { Warn "$what is still present (exit code $code). Remove it with: $removeCmd" }
    } else {
        Warn "$what was kept; it may shadow the native install. Remove it later with: $removeCmd"
    }
}
$claudeCmd = Find-Tool 'claude'
if ($claudeCmd) {
    $ver = Get-ToolVersion 'claude'
    Write-CcOk "claude $ver ($($claudeCmd.Source))"
    $shadow = @(Find-ClaudeInstallations | Where-Object { $_.Kind -ne 'native' -and $claudeCmd.Source -like "$($_.Path)*" })
    if ($shadow.Count -gt 0) { Warn "claude on PATH is the $($shadow[0].Kind) copy, not the native install" }
    try {
        if ($ver -and [version]$ver -lt [version](Get-TestedClaudeVersion)) { Warn "Claude Code $ver is older than the tested $(Get-TestedClaudeVersion); run: claude update" }
    } catch { }
}

if (Find-Tool 'pwsh') { Write-CcOk "pwsh $(Get-ToolVersion 'pwsh') (optional)" }
else { Write-CcInfo 'PowerShell 7 not installed (optional; Windows PowerShell is enough).' }

# ------------------------------------------------------------------ sign-in
if ($SkipAuth) {
    Write-CcStep 'Sign-in (skipped)'
} else {
    Write-CcStep 'Sign-in'
    $ghReady = $false
    if (Find-Tool 'gh') {
        $ghReady = Test-GhAuth
        if ($ghReady) { Write-CcOk 'GitHub CLI signed in' }
        elseif (Confirm-Action 'Sign in to GitHub now? (opens your browser)') {
            [void](Invoke-Attached 'gh' @('auth', 'login', '--hostname', 'github.com', '--git-protocol', 'https', '--web'))
            $ghReady = Test-GhAuth
            if ($ghReady) { Write-CcOk 'GitHub CLI signed in' } else { Warn 'GitHub sign-in did not complete. Rerun setup, or: gh auth login --hostname github.com --git-protocol https --web' }
        } elseif (-not $DryRun) { Warn 'GitHub CLI not signed in. Run: gh auth login --hostname github.com --git-protocol https --web' }
    }

    # git over HTTPS: configure gh as the credential helper only if git cannot
    # already reach the repo without prompting (e.g. via Git Credential Manager).
    if ((Find-Tool 'git') -and $ghReady) {
        $origin = Invoke-Git -RepoRoot $repo -Arguments @('remote', 'get-url', 'origin')
        if ($origin.Code -eq 0 -and "$($origin.Output | Select-Object -First 1)" -match '^https://github\.com/') {
            $saved = @($env:GIT_TERMINAL_PROMPT, $env:GCM_INTERACTIVE)
            $env:GIT_TERMINAL_PROMPT = '0'; $env:GCM_INTERACTIVE = 'never'
            try { $reach = (Invoke-Git -RepoRoot $repo -Arguments @('ls-remote', '--heads', 'origin')).Code -eq 0 }
            finally { $env:GIT_TERMINAL_PROMPT = $saved[0]; $env:GCM_INTERACTIVE = $saved[1] }
            if ($reach) { Write-CcOk 'git can reach GitHub' }
            elseif (Confirm-Action 'git cannot reach GitHub without prompting. Let git use your GitHub CLI sign-in (gh auth setup-git)?') {
                $r = Invoke-Exe -FilePath 'gh' -Arguments @('auth', 'setup-git', '--hostname', 'github.com')
                if ($r.Code -eq 0) { Write-CcOk 'git now uses GitHub CLI credentials (gh auth setup-git)' }
                else { Warn "gh auth setup-git failed: $($r.Output -join ' ')" }
            } elseif (-not $DryRun) { Warn 'git cannot reach GitHub without prompting (offline, or no credentials). If signing in is the problem, run: gh auth setup-git' }
        }
    }

    if (Find-Tool 'git') {
        if (Test-GitIdentity) { Write-CcOk 'git identity configured' }
        elseif (-not $interactive -or $DryRun) { Warn 'git identity not set. Run: git config --global user.name "<name>"; git config --global user.email "<email>"' }
        else {
            # Suggest the GitHub profile name and private noreply address.
            $defName = ''; $defEmail = ''
            if ($ghReady) {
                $u = Invoke-Exe -FilePath 'gh' -Arguments @('api', 'user')
                if ($u.Code -eq 0) {
                    try {
                        $j = ConvertFrom-Json -InputObject ($u.Output -join "`n")
                        if ($j.name) { $defName = [string]$j.name } else { $defName = [string]$j.login }
                        $defEmail = "$($j.id)+$($j.login)@users.noreply.github.com"
                    } catch { }
                }
            }
            Write-CcInfo 'git needs your name and email for commits (press Enter to accept a suggestion).'
            foreach ($pair in @(@('user.name', 'Name', $defName), @('user.email', 'Email', $defEmail))) {
                $cur = Invoke-Exe -FilePath 'git' -Arguments @('config', '--global', $pair[0])
                if ($cur.Code -eq 0) { continue }
                $prompt = "  ? $($pair[1])"
                if ($pair[2]) { $prompt += " [$($pair[2])]" }
                $v = (Read-Host $prompt).Trim()
                if (-not $v) { $v = $pair[2] }
                if ($v) { [void](Invoke-Exe -FilePath 'git' -Arguments @('config', '--global', $pair[0], $v)) }
            }
            if (Test-GitIdentity) { Write-CcOk 'git identity configured' } else { Warn 'git identity still not set. Run: git config --global user.name "<name>"; git config --global user.email "<email>"' }
        }
    }

    if (Find-Tool 'claude') {
        if (Test-ClaudeAuth) { Write-CcOk 'Claude Code signed in' }
        elseif (Confirm-Action 'Sign in to Claude Code now? (opens your browser)') {
            [void](Invoke-Attached 'claude' @('auth', 'login'))
            if (Test-ClaudeAuth) { Write-CcOk 'Claude Code signed in' } else { Warn 'Claude Code sign-in did not complete. Rerun setup, or start claude and use /login' }
        } elseif (-not $DryRun) { Warn 'Claude Code not signed in. Run: claude auth login   (or start claude and use /login)' }
    }
}

# ------------------------------------------------------------------ configuration
Write-CcStep 'Configuration'
$result = Invoke-ClaudeConfigInstall -RepoRoot $repo -ClaudeHome $claudeHome -Force:$Force -DryRun:$DryRun
Write-InstallResult $result ([bool]$DryRun)
$script:warnings += $result.Conflicts.Count

if (-not $DryRun) {
    Write-CcStep 'Validating'
    & (Join-Path $PSScriptRoot 'validate.ps1') -SkipTools -Strict
    if ($LASTEXITCODE -eq 1) { $script:failures++ } elseif ($LASTEXITCODE -ne 0) { $script:warnings++ }
}

Write-Host ''
if ($DryRun) { Write-CcOk 'Dry run complete; nothing was changed.'; exit 0 }
if ($script:failures -gt 0) {
    Write-CcFail "Setup incomplete: $($script:failures) problem(s) above. Fix them and rerun setup; finished steps are skipped."
    exit 1
}
if ($script:warnings -gt 0) {
    Write-CcWarn "Setup finished with $($script:warnings) warning(s); see above. Rerunning setup is safe."
    exit 2
}
Write-CcOk 'Setup complete. Open a new terminal so it picks up PATH changes, then run: claude'
exit 0
