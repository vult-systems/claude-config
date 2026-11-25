<#
.SYNOPSIS
    Pull the latest shared configuration and apply it, or capture local edits back into the repo.

.DESCRIPTION
    Default: fast-forwards the repository from its upstream (never merges,
    rebases or discards anything), then installs it like bootstrap.ps1.

    -Capture copies managed skills, agents and the CLAUDE.md block that were
    edited in the Claude Code user directory back into the repository working
    tree so they can be reviewed, committed and pushed to other workstations.

.PARAMETER Capture
    Copy locally edited managed files into the repo instead of installing.

.PARAMETER NoPull
    Skip git fetch/pull; install the working tree as it is.

.PARAMETER Force
    Overwrite managed files that were edited locally (they are backed up first).

.PARAMETER DryRun
    Show what would change without writing anything.
#>
[CmdletBinding()]
param(
    [switch]$Capture,
    [switch]$NoPull,
    [switch]$Force,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ClaudeConfig.psm1') -Force

$repo = Get-RepoRoot
$claudeHome = Get-ClaudeHome
$sourceDir = Join-Path $repo 'claude'

if ($Capture) {
    Write-CcStep 'Capturing local edits into the repository'
    $captured = 0
    foreach ($d in (Get-InstallDrift -RepoRoot $repo -ClaudeHome $claudeHome)) {
        if ($d.Status -ne 'modified') { continue }
        if ($d.Item -like 'CLAUDE.md*') {
            $block = Get-ManagedBlock (Read-TextFile (Join-Path $claudeHome 'CLAUDE.md'))
            if (-not $DryRun) { Write-TextFile -Path (Join-Path $sourceDir 'CLAUDE.md') -Text ($block.TrimEnd() + "`n") }
            Write-CcInfo 'captured CLAUDE.md managed block -> claude/CLAUDE.md'
        } else {
            $src = Join-Path $claudeHome (ConvertTo-NativeRel $d.Item)
            if (-not $DryRun) { Copy-Item -LiteralPath $src -Destination (Join-Path $sourceDir (ConvertTo-NativeRel $d.Item)) -Force }
            Write-CcInfo "captured $($d.Item)"
        }
        $captured++
    }
    if ($captured -eq 0) { Write-CcOk 'No local edits to capture'; exit 0 }
    foreach ($n in (Get-SettingsDivergence -RepoRoot $repo -ClaudeHome $claudeHome)) {
        Write-CcWarn "Not captured (edit claude/settings.json by hand if it should be shared): $n"
    }
    Write-Host ''
    Write-CcInfo 'Review, commit and push, then run sync.ps1 here to record the new baseline:'
    Write-CcInfo "  git -C `"$repo`" diff"
    Write-CcInfo "  git -C `"$repo`" commit -am `"<what and why>`"; git -C `"$repo`" push"
    exit 0
}

if (-not $NoPull) {
    Write-CcStep 'Updating repository'
    $dirty = Invoke-Git -RepoRoot $repo -Arguments @('status', '--porcelain')
    if ($dirty.Code -ne 0) { Write-CcFail ($dirty.Output -join "`n"); exit 1 }
    if (@($dirty.Output | Where-Object { $_ }).Count -gt 0) {
        Write-CcWarn 'Repository has uncommitted changes; skipping pull and installing the working tree.'
    } else {
        $fetch = Invoke-Git -RepoRoot $repo -Arguments @('fetch', '--prune', 'origin')
        if ($fetch.Code -ne 0) {
            Write-CcWarn "git fetch failed; installing the local copy. $($fetch.Output -join ' ')"
        } else {
            $counts = Invoke-Git -RepoRoot $repo -Arguments @('rev-list', '--left-right', '--count', 'HEAD...@{upstream}')
            if ($counts.Code -ne 0) {
                Write-CcWarn 'Current branch has no upstream; skipping pull.'
            } else {
                $parts = ($counts.Output | Select-Object -First 1) -split '\s+'
                $ahead = [int]$parts[0]; $behind = [int]$parts[1]
                if ($ahead -gt 0 -and $behind -gt 0) {
                    Write-CcFail "Local branch has diverged from upstream ($ahead ahead, $behind behind). Resolve it in $repo, then rerun."
                    exit 1
                }
                if ($behind -gt 0) {
                    $pull = Invoke-Git -RepoRoot $repo -Arguments @('merge', '--ff-only', '@{upstream}')
                    if ($pull.Code -ne 0) { Write-CcFail ($pull.Output -join "`n"); exit 1 }
                    Write-CcOk "Fast-forwarded $behind commit(s)"
                } else {
                    Write-CcOk 'Repository up to date'
                }
                if ($ahead -gt 0) { Write-CcWarn "$ahead local commit(s) not pushed. Run: git -C `"$repo`" push" }
            }
        }
    }
}

Write-CcStep 'Installing configuration'
$result = Invoke-ClaudeConfigInstall -RepoRoot $repo -ClaudeHome $claudeHome -Force:$Force -DryRun:$DryRun
Write-InstallResult $result ([bool]$DryRun)
if ($result.Conflicts.Count -gt 0) { exit 2 }
exit 0
