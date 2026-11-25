<#
.SYNOPSIS
    Set up Claude Code user configuration on this workstation from this repository.

.DESCRIPTION
    Checks required tools and sign-in state, then installs the shared
    configuration into the Claude Code user directory ($env:CLAUDE_CONFIG_DIR,
    else ~/.claude) and validates the result.

    Runs as a standard user. Never installs software, changes execution policy
    or grants permissions. Safe to rerun: unchanged files are left alone,
    local edits are kept, and anything replaced is backed up first.

.PARAMETER Force
    Overwrite managed files that were edited locally (they are backed up first).

.PARAMETER DryRun
    Show what would change without writing anything.

.PARAMETER SkipToolCheck
    Install even if required tools are missing.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\bootstrap.ps1
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$DryRun,
    [switch]$SkipToolCheck
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ClaudeConfig.psm1') -Force

$repo = Get-RepoRoot
$claudeHome = Get-ClaudeHome
Write-CcStep "claude-config $(Get-RepoVersion $repo)"
Write-CcInfo "Repository:  $repo"
Write-CcInfo "Claude home: $claudeHome"

Write-CcStep 'Checking tools'
$tools = Test-Tools
if ($tools.Missing -gt 0 -and -not $SkipToolCheck) {
    Write-CcFail "$($tools.Missing) required tool(s) missing. Run setup.ps1 to install them, or install them, open a new terminal, and rerun. (-SkipToolCheck installs the configuration anyway.)"
    exit 1
}

Write-CcStep 'Checking sign-in'
$warnings = $tools.Warnings + (Test-Auth)

Write-CcStep 'Installing configuration'
$result = Invoke-ClaudeConfigInstall -RepoRoot $repo -ClaudeHome $claudeHome -Force:$Force -DryRun:$DryRun
Write-InstallResult $result ([bool]$DryRun)
if ($DryRun) { exit 0 }

Write-CcStep 'Validating'
& (Join-Path $PSScriptRoot 'validate.ps1') -SkipTools -Strict
$validateCode = $LASTEXITCODE

Write-Host ''
if ($validateCode -eq 1) { Write-CcFail 'Validation failed; see above.'; exit 1 }
if ($result.Conflicts.Count -gt 0 -or $validateCode -ne 0 -or $warnings -gt 0) {
    Write-CcWarn 'Finished with warnings; see above.'
    exit 2
}
Write-CcOk 'Done. Start a new Claude Code session to load the skills.'
exit 0
