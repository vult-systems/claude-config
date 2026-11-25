<#
.SYNOPSIS
    List or restore backups made by bootstrap.ps1 / sync.ps1.

.DESCRIPTION
    Every install copies the files it replaces into
    <Claude home>/backups/claude-config/<timestamp>/. Restoring puts those
    files back and removes files that the install created. The current
    versions are backed up first, so a restore can itself be undone.

    After restoring, sync.ps1 treats the restored files as installed by that
    earlier run; run it again only when you want the repo version back.

.PARAMETER Name
    Backup folder name to restore (see -List).

.PARAMETER Latest
    Restore the most recent backup.

.PARAMETER List
    List available backups (default when no other option is given).
#>
[CmdletBinding()]
param(
    [string]$Name,
    [switch]$Latest,
    [switch]$List
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ClaudeConfig.psm1') -Force

$claudeHome = Get-ClaudeHome
$backups = @(Get-Backups $claudeHome)

if ($List -or (-not $Name -and -not $Latest)) {
    if ($backups.Count -eq 0) { Write-CcInfo "No backups in $(Get-BackupRoot $claudeHome)"; exit 0 }
    Write-CcStep "Backups in $(Get-BackupRoot $claudeHome) (newest first)"
    foreach ($b in $backups) {
        $m = Join-Path $b.FullName 'claude-config-backup.json'
        $summary = ''
        if (Test-Path -LiteralPath $m) {
            $j = Read-JsonFile $m
            $summary = "$($j['reason']): $(@($j['backedUp']).Count) replaced, $(@($j['created']).Count) created"
        }
        Write-CcInfo "$($b.Name)  $summary"
    }
    Write-CcInfo 'Restore with: restore.ps1 -Name <name>   or   restore.ps1 -Latest'
    exit 0
}

if ($Latest) {
    if ($backups.Count -eq 0) { Write-CcFail 'No backups to restore'; exit 1 }
    $target = $backups[0]
} else {
    $target = $backups | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $target) { Write-CcFail "Backup not found: $Name"; exit 1 }
}

$manifestPath = Join-Path $target.FullName 'claude-config-backup.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { Write-CcFail "Backup has no manifest: $($target.FullName)"; exit 1 }
$manifest = Read-JsonFile $manifestPath
$backedUp = @($manifest['backedUp'] | Where-Object { $_ })
$created = @($manifest['created'] | Where-Object { $_ })

Write-CcStep "Restoring $($target.Name)"
$ctx = New-InstallContext -ClaudeHome $claudeHome -DryRun $false
foreach ($rel in ($backedUp + $created)) { Save-Backup $ctx $rel }
Complete-Backup $ctx "pre-restore of $($target.Name)"

foreach ($rel in $backedUp) {
    $src = Join-Path $target.FullName (ConvertTo-NativeRel $rel)
    $dest = Join-Path $claudeHome (ConvertTo-NativeRel $rel)
    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
    Copy-Item -LiteralPath $src -Destination $dest -Force
    Write-CcInfo "restored $rel"
}
foreach ($rel in $created) {
    $dest = Join-Path $claudeHome (ConvertTo-NativeRel $rel)
    if (Test-Path -LiteralPath $dest) {
        Remove-Item -LiteralPath $dest -Force
        Remove-EmptyParents -ClaudeHome $claudeHome -Path $dest
        Write-CcInfo "removed  $rel"
    }
}
if ($ctx.BackupDir) { Write-CcInfo "Previous state saved as $(Split-Path -Leaf $ctx.BackupDir)" }
Write-CcOk 'Restore complete'
exit 0
