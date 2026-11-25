# ClaudeConfig.psm1 - shared helpers for bootstrap.ps1, sync.ps1, validate.ps1
# and restore.ps1.
#
# Compatible with Windows PowerShell 5.1 and PowerShell 7+. Keep this file
# ASCII-only: 5.1 reads BOM-less files as ANSI.
#
# What gets installed into the Claude Code user directory
# ($env:CLAUDE_CONFIG_DIR, else ~/.claude):
#   claude/CLAUDE.md      -> managed block inside CLAUDE.md (text outside it is kept)
#   claude/settings.json  -> 3-way merged into settings.json (local changes are kept)
#   claude/skills/**      -> skills/**  (copied; skipped if modified locally)
#   claude/agents/**      -> agents/**  (copied; skipped if modified locally)
# Every file that is changed is first copied to backups/claude-config/<timestamp>/.

Set-StrictMode -Version 2.0

$script:TestedClaudeVersion = '2.1.332'
$script:StateFileName = 'claude-config.state.json'
$script:BackupManifestName = 'claude-config-backup.json'
$script:BlockBegin = '<!-- BEGIN claude-config: managed block, edit it in the claude-config repo -->'
$script:BlockEnd = '<!-- END claude-config -->'
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:ManagedDirs = @('skills', 'agents')

# ---------------------------------------------------------------- output

function Write-CcInfo([string]$Message) { Write-Host "  $Message" }
function Write-CcStep([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-CcOk([string]$Message) { Write-Host "  [ok]   $Message" -ForegroundColor Green }
function Write-CcWarn([string]$Message) { Write-Host "  [warn] $Message" -ForegroundColor Yellow }
function Write-CcFail([string]$Message) { Write-Host "  [fail] $Message" -ForegroundColor Red }

# ---------------------------------------------------------------- paths

function Get-ClaudeHome {
    if ($env:CLAUDE_CONFIG_DIR) { return $env:CLAUDE_CONFIG_DIR }
    return (Join-Path $HOME '.claude')
}

function Get-RepoRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-TestedClaudeVersion { return $script:TestedClaudeVersion }

function Get-StatePath([string]$ClaudeHome) {
    return (Join-Path $ClaudeHome $script:StateFileName)
}

function Get-BackupRoot([string]$ClaudeHome) {
    return (Join-Path (Join-Path $ClaudeHome 'backups') 'claude-config')
}

function ConvertTo-NativeRel([string]$Rel) {
    return $Rel.Replace('/', [IO.Path]::DirectorySeparatorChar)
}

function ConvertTo-PortableRel([string]$Rel) {
    return $Rel.Replace('\', '/')
}

# ---------------------------------------------------------------- files

function Read-TextFile([string]$Path) {
    return [IO.File]::ReadAllText($Path)
}

function Write-TextFile([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

function Get-TextHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash($script:Utf8NoBom.GetBytes($Text))
        return ([BitConverter]::ToString($bytes)).Replace('-', '')
    } finally { $sha.Dispose() }
}

# .NET instead of Get-FileHash: Windows PowerShell 5.1 started from a
# PowerShell 7 session inherits its PSModulePath and cannot load Get-FileHash.
function Get-FileHashHex([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
}

function ConvertTo-Lf([string]$Text) {
    return ($Text -replace "`r`n", "`n")
}

# ---------------------------------------------------------------- native commands

# Runs a native command without letting Windows PowerShell 5.1 turn stderr
# output into terminating errors. Returns @{ Code; Output }.
function Invoke-Exe {
    param([Parameter(Mandatory = $true)][string]$FilePath, [string[]]$Arguments = @())
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $FilePath @Arguments 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    } catch {
        $out = @("$_")
        $code = 1
    } finally {
        $ErrorActionPreference = $old
    }
    return @{ Code = $code; Output = @($out) }
}

function Invoke-Git {
    param([string]$RepoRoot, [string[]]$Arguments)
    return (Invoke-Exe -FilePath 'git' -Arguments (@('-C', $RepoRoot) + $Arguments))
}

# ---------------------------------------------------------------- JSON

function ConvertTo-PlainObject($InputObject) {
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [string]) { return $InputObject }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $h = [ordered]@{}
        foreach ($k in $InputObject.Keys) { $h[$k] = ConvertTo-PlainObject $InputObject[$k] }
        return $h
    }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = ConvertTo-PlainObject $p.Value }
        return $h
    }
    if ($InputObject -is [System.Collections.IEnumerable]) {
        $list = @()
        foreach ($i in $InputObject) { $list += , (ConvertTo-PlainObject $i) }
        return , $list
    }
    return $InputObject
}

function ConvertFrom-JsonText([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return [ordered]@{} }
    return (ConvertTo-PlainObject (ConvertFrom-Json -InputObject $Text))
}

function Read-JsonFile([string]$Path) {
    return (ConvertFrom-JsonText (Read-TextFile $Path))
}

function ConvertTo-JsonText($Value) {
    $json = ConvertTo-Json -InputObject $Value -Depth 32
    return ((ConvertTo-Lf $json) + "`n")
}

function Write-JsonFile([string]$Path, $Value) {
    Write-TextFile -Path $Path -Text (ConvertTo-JsonText $Value)
}

function Test-JsonEqual($A, $B) {
    $ja = ConvertTo-Json -InputObject $A -Depth 32 -Compress
    $jb = ConvertTo-Json -InputObject $B -Depth 32 -Compress
    return ($ja -ceq $jb)
}

function Test-IsArray($Value) {
    return ($null -ne $Value -and $Value -is [System.Array])
}

function Test-InArray($Item, $Array) {
    foreach ($x in $Array) { if (Test-JsonEqual $x $Item) { return $true } }
    return $false
}

# Three-way merge of repo settings into local settings.
#   $Local - current local value ($null when missing)
#   $Repo  - value from the repo
#   $Base  - repo value applied by the previous install ($null when unknown)
# Objects merge per key; keys outside the repo are kept. Arrays are unioned,
# and items removed from the repo since $Base are removed locally. A scalar
# takes the repo value unless it was changed locally, in which case the local
# value is kept and a note is added.
function Merge-Settings {
    param($Local, $Repo, $Base, [string]$Path, $Notes)

    if ($Repo -is [System.Collections.IDictionary]) {
        if ($null -ne $Local -and -not ($Local -is [System.Collections.IDictionary])) {
            if ($null -ne $Base -and (Test-JsonEqual $Local $Base)) { return $Repo }
            $Notes.Add("$Path is not an object locally; kept the local value")
            return $Local
        }
        $result = [ordered]@{}
        if ($null -ne $Local) { foreach ($k in $Local.Keys) { $result[$k] = $Local[$k] } }
        $baseDict = $null
        if ($Base -is [System.Collections.IDictionary]) { $baseDict = $Base }
        foreach ($k in $Repo.Keys) {
            $lv = $null
            if ($result.Contains($k)) { $lv = $result[$k] }
            $bv = $null
            if ($null -ne $baseDict -and $baseDict.Contains($k)) { $bv = $baseDict[$k] }
            $merged = Merge-Settings -Local $lv -Repo $Repo[$k] -Base $bv -Path "$Path.$k" -Notes $Notes
            $result[$k] = $merged
        }
        if ($null -ne $baseDict) {
            foreach ($k in @($baseDict.Keys)) {
                if (-not $Repo.Contains($k) -and $result.Contains($k) -and (Test-JsonEqual $result[$k] $baseDict[$k])) {
                    $result.Remove($k)
                }
            }
        }
        return $result
    }

    if (Test-IsArray $Repo) {
        $localArr = @()
        if ($null -ne $Local) {
            if (Test-IsArray $Local) {
                $localArr = $Local
            } elseif ($null -ne $Base -and (Test-JsonEqual $Local $Base)) {
                return , $Repo
            } else {
                $Notes.Add("$Path is not a list locally; kept the local value")
                return $Local
            }
        }
        $removed = @()
        if (Test-IsArray $Base) {
            foreach ($b in $Base) { if (-not (Test-InArray $b $Repo)) { $removed += , $b } }
        }
        $out = @()
        foreach ($i in $localArr) { if (-not (Test-InArray $i $removed)) { $out += , $i } }
        foreach ($i in $Repo) { if (-not (Test-InArray $i $out)) { $out += , $i } }
        return , $out
    }

    if ($null -eq $Local) { return $Repo }
    if (Test-JsonEqual $Local $Repo) { return $Repo }
    if ($null -ne $Base -and (Test-JsonEqual $Local $Base)) { return $Repo }
    $lj = ConvertTo-Json -InputObject $Local -Compress
    $rj = ConvertTo-Json -InputObject $Repo -Compress
    $Notes.Add("$Path kept local value $lj (repo has $rj)")
    return $Local
}

# ---------------------------------------------------------------- managed CLAUDE.md block

function Get-ManagedBlock([string]$Text) {
    $pattern = '(?s)' + [regex]::Escape($script:BlockBegin) + '\n(.*?)\n?' + [regex]::Escape($script:BlockEnd)
    $m = [regex]::Match((ConvertTo-Lf $Text), $pattern)
    if (-not $m.Success) { return $null }
    return $m.Groups[1].Value
}

function Set-ManagedBlock([string]$Text, [string]$Inner) {
    $block = $script:BlockBegin + "`n" + $Inner + "`n" + $script:BlockEnd
    $lf = ConvertTo-Lf $Text
    $start = $lf.IndexOf($script:BlockBegin, [StringComparison]::Ordinal)
    if ($start -ge 0) {
        $end = $lf.IndexOf($script:BlockEnd, $start, [StringComparison]::Ordinal)
        if ($end -ge 0) {
            $end += $script:BlockEnd.Length
            return $lf.Substring(0, $start) + $block + $lf.Substring($end)
        }
    }
    if ([string]::IsNullOrWhiteSpace($lf)) { return $block + "`n" }
    return $lf.TrimEnd() + "`n`n" + $block + "`n"
}

function Get-RepoClaudeMd([string]$SourceDir) {
    return (ConvertTo-Lf (Read-TextFile (Join-Path $SourceDir 'CLAUDE.md'))).TrimEnd()
}

# ---------------------------------------------------------------- state

function Read-State([string]$ClaudeHome) {
    $p = Get-StatePath $ClaudeHome
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    try { return (Read-JsonFile $p) } catch { return $null }
}

function Get-StateValue($State, [string]$Key) {
    if ($null -eq $State -or -not $State.Contains($Key)) { return $null }
    return $State[$Key]
}

function Get-ManagedFiles([string]$SourceDir) {
    $root = (Resolve-Path -LiteralPath $SourceDir).ProviderPath.TrimEnd('\', '/')
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($sub in $script:ManagedDirs) {
        $d = Join-Path $root $sub
        if (Test-Path -LiteralPath $d) {
            Get-ChildItem -LiteralPath $d -Recurse -File | Sort-Object FullName | ForEach-Object {
                $list.Add((ConvertTo-PortableRel $_.FullName.Substring($root.Length + 1)))
            }
        }
    }
    return , $list.ToArray()
}

function Get-RepoVersion([string]$RepoRoot) {
    $p = Join-Path $RepoRoot 'VERSION'
    if (Test-Path -LiteralPath $p) { return (Read-TextFile $p).Trim() }
    return 'unknown'
}

function Get-RepoCommit([string]$RepoRoot) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    $r = Invoke-Git -RepoRoot $RepoRoot -Arguments @('rev-parse', 'HEAD')
    if ($r.Code -ne 0) { return $null }
    return ($r.Output | Select-Object -First 1)
}

# ---------------------------------------------------------------- backups

function New-InstallContext([string]$ClaudeHome, [bool]$DryRun) {
    return @{
        ClaudeHome = $ClaudeHome
        DryRun     = $DryRun
        BackupDir  = $null
        BackedUp   = New-Object System.Collections.Generic.List[string]
        Created    = New-Object System.Collections.Generic.List[string]
        Changes    = New-Object System.Collections.Generic.List[string]
        Conflicts  = New-Object System.Collections.Generic.List[string]
        Notes      = New-Object System.Collections.Generic.List[string]
    }
}

# Copies the current version of a target file into this run's backup folder
# (or records that it did not exist) before it is written or removed.
function Save-Backup($Ctx, [string]$Rel) {
    if ($Ctx.DryRun) { return }
    if ($Ctx.BackedUp.Contains($Rel) -or $Ctx.Created.Contains($Rel)) { return }
    if (-not $Ctx.BackupDir) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $Ctx.BackupDir = Join-Path (Get-BackupRoot $Ctx.ClaudeHome) $stamp
        New-Item -ItemType Directory -Path $Ctx.BackupDir -Force | Out-Null
    }
    $target = Join-Path $Ctx.ClaudeHome (ConvertTo-NativeRel $Rel)
    if (Test-Path -LiteralPath $target) {
        $dest = Join-Path $Ctx.BackupDir (ConvertTo-NativeRel $Rel)
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath $target -Destination $dest -Force
        $Ctx.BackedUp.Add($Rel)
    } else {
        $Ctx.Created.Add($Rel)
    }
}

function Complete-Backup($Ctx, [string]$Reason) {
    if ($Ctx.DryRun -or -not $Ctx.BackupDir) { return }
    $manifest = [ordered]@{
        reason   = $Reason
        created  = @($Ctx.Created.ToArray())
        backedUp = @($Ctx.BackedUp.ToArray())
    }
    Write-JsonFile -Path (Join-Path $Ctx.BackupDir $script:BackupManifestName) -Value $manifest
}

function Get-Backups([string]$ClaudeHome) {
    $root = Get-BackupRoot $ClaudeHome
    if (-not (Test-Path -LiteralPath $root)) { return @() }
    return @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending)
}

function Remove-OldBackups([string]$ClaudeHome, [int]$Keep) {
    if ($Keep -lt 1) { return }
    Get-Backups $ClaudeHome | Select-Object -Skip $Keep | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }
}

function Remove-EmptyParents([string]$ClaudeHome, [string]$Path) {
    $stop = @()
    foreach ($d in $script:ManagedDirs) { $stop += (Join-Path $ClaudeHome $d) }
    $dir = Split-Path -Parent $Path
    while ($dir -and ($stop -notcontains $dir) -and (Test-Path -LiteralPath $dir)) {
        if (@(Get-ChildItem -LiteralPath $dir -Force).Count -gt 0) { break }
        Remove-Item -LiteralPath $dir -Force
        $dir = Split-Path -Parent $dir
    }
}

# ---------------------------------------------------------------- install

function Install-ManagedFile($Ctx, [string]$SourceDir, [string]$Rel, $PrevHashes, [bool]$Force) {
    $src = Join-Path $SourceDir (ConvertTo-NativeRel $Rel)
    $dest = Join-Path $Ctx.ClaudeHome (ConvertTo-NativeRel $Rel)
    $srcHash = Get-FileHashHex $src
    if (Test-Path -LiteralPath $dest) {
        $destHash = Get-FileHashHex $dest
        if ($destHash -eq $srcHash) { return $srcHash }
        $prev = $null
        if ($null -ne $PrevHashes -and $PrevHashes.Contains($Rel)) { $prev = $PrevHashes[$Rel] }
        if ($destHash -ne $prev -and -not $Force) {
            if ($null -eq $prev) {
                $Ctx.Conflicts.Add("$Rel exists and is not managed by claude-config; left unchanged (rerun with -Force to replace it; a backup is kept)")
            } else {
                $Ctx.Conflicts.Add("$Rel was modified locally; left unchanged (sync.ps1 -Capture copies it into the repo, -Force overwrites it with a backup)")
            }
            return $prev
        }
        $Ctx.Changes.Add("update $Rel")
    } else {
        $Ctx.Changes.Add("add    $Rel")
    }
    if (-not $Ctx.DryRun) {
        Save-Backup $Ctx $Rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
    return $srcHash
}

function Remove-StaleFile($Ctx, [string]$Rel, [string]$PrevHash, [bool]$Force) {
    $dest = Join-Path $Ctx.ClaudeHome (ConvertTo-NativeRel $Rel)
    if (-not (Test-Path -LiteralPath $dest)) { return }
    if ((Get-FileHashHex $dest) -ne $PrevHash -and -not $Force) {
        $Ctx.Conflicts.Add("$Rel was removed from the repo but modified locally; left in place")
        return
    }
    $Ctx.Changes.Add("remove $Rel")
    if (-not $Ctx.DryRun) {
        Save-Backup $Ctx $Rel
        Remove-Item -LiteralPath $dest -Force
        Remove-EmptyParents -ClaudeHome $Ctx.ClaudeHome -Path $dest
    }
}

function Install-ClaudeMd($Ctx, [string]$SourceDir, $PrevHash, [bool]$Force) {
    $inner = Get-RepoClaudeMd $SourceDir
    $innerHash = Get-TextHash $inner
    $dest = Join-Path $Ctx.ClaudeHome 'CLAUDE.md'
    $existing = ''
    if (Test-Path -LiteralPath $dest) { $existing = Read-TextFile $dest }
    $current = Get-ManagedBlock $existing
    if ($null -ne $current) {
        $currentHash = Get-TextHash $current.TrimEnd()
        if ($currentHash -eq $innerHash) { return $innerHash }
        if ($currentHash -ne $PrevHash -and -not $Force) {
            $Ctx.Conflicts.Add('CLAUDE.md managed block was edited locally; left unchanged (sync.ps1 -Capture copies it into the repo, -Force overwrites it with a backup)')
            return $PrevHash
        }
        $Ctx.Changes.Add('update CLAUDE.md (managed block)')
    } elseif ($existing.Trim().Length -gt 0) {
        $Ctx.Changes.Add('update CLAUDE.md (managed block appended; existing content kept)')
    } else {
        $Ctx.Changes.Add('add    CLAUDE.md')
    }
    if (-not $Ctx.DryRun) {
        Save-Backup $Ctx 'CLAUDE.md'
        Write-TextFile -Path $dest -Text (Set-ManagedBlock $existing $inner)
    }
    return $innerHash
}

function Install-Settings($Ctx, [string]$SourceDir, $Base) {
    $repoSettings = Read-JsonFile (Join-Path $SourceDir 'settings.json')
    $dest = Join-Path $Ctx.ClaudeHome 'settings.json'
    $local = $null
    if (Test-Path -LiteralPath $dest) {
        try { $local = Read-JsonFile $dest } catch {
            $Ctx.Conflicts.Add("settings.json is not valid JSON; left unchanged ($($_.Exception.Message))")
            return $Base
        }
    }
    $merged = Merge-Settings -Local $local -Repo $repoSettings -Base $Base -Path 'settings' -Notes $Ctx.Notes
    if ($null -ne $local -and (Test-JsonEqual $merged $local)) { return $repoSettings }
    if ($null -eq $local) { $Ctx.Changes.Add('add    settings.json') } else { $Ctx.Changes.Add('update settings.json (merged)') }
    if (-not $Ctx.DryRun) {
        Save-Backup $Ctx 'settings.json'
        Write-JsonFile -Path $dest -Value $merged
    }
    return $repoSettings
}

function Invoke-ClaudeConfigInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string]$ClaudeHome = (Get-ClaudeHome),
        [switch]$Force,
        [switch]$DryRun,
        [int]$KeepBackups = 20
    )
    $sourceDir = Join-Path $RepoRoot 'claude'
    if (-not (Test-Path -LiteralPath (Join-Path $sourceDir 'CLAUDE.md'))) {
        throw "Not a claude-config repository: $RepoRoot"
    }
    if (-not (Test-Path -LiteralPath $ClaudeHome)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null }
    }
    $ctx = New-InstallContext -ClaudeHome $ClaudeHome -DryRun ([bool]$DryRun)
    $state = Read-State $ClaudeHome
    $prevFiles = Get-StateValue $state 'files'
    if ($null -eq $prevFiles) { $prevFiles = [ordered]@{} }

    $files = [ordered]@{}
    foreach ($rel in (Get-ManagedFiles $sourceDir)) {
        $h = Install-ManagedFile -Ctx $ctx -SourceDir $sourceDir -Rel $rel -PrevHashes $prevFiles -Force ([bool]$Force)
        if ($null -ne $h) { $files[$rel] = $h }
    }
    foreach ($rel in @($prevFiles.Keys)) {
        if (-not $files.Contains($rel)) {
            Remove-StaleFile -Ctx $ctx -Rel $rel -PrevHash $prevFiles[$rel] -Force ([bool]$Force)
            $dest = Join-Path $ClaudeHome (ConvertTo-NativeRel $rel)
            if (Test-Path -LiteralPath $dest) { $files[$rel] = $prevFiles[$rel] }
        }
    }
    $mdHash = Install-ClaudeMd -Ctx $ctx -SourceDir $sourceDir -PrevHash (Get-StateValue $state 'claudeMdHash') -Force ([bool]$Force)
    $settingsBase = Install-Settings -Ctx $ctx -SourceDir $sourceDir -Base (Get-StateValue $state 'settingsBase')

    $newState = [ordered]@{
        version      = Get-RepoVersion $RepoRoot
        commit       = Get-RepoCommit $RepoRoot
        repoPath     = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath
        installedAt  = (Get-Date).ToUniversalTime().ToString('o')
        claudeMdHash = $mdHash
        settingsBase = $settingsBase
        files        = $files
    }
    if (-not $ctx.DryRun) {
        $stateChanged = $true
        if ($null -ne $state) {
            $a = [ordered]@{}; $b = [ordered]@{}
            foreach ($k in 'version', 'commit', 'repoPath', 'claudeMdHash', 'settingsBase', 'files') {
                $a[$k] = Get-StateValue $state $k; $b[$k] = $newState[$k]
            }
            $stateChanged = -not (Test-JsonEqual $a $b)
        }
        # Back up the state file only alongside real changes, so a restore
        # stays consistent; a new commit or version alone needs no backup.
        if ($ctx.Changes.Count -gt 0) { Save-Backup $ctx $script:StateFileName }
        if ($stateChanged -or $ctx.Changes.Count -gt 0) {
            Write-JsonFile -Path (Get-StatePath $ClaudeHome) -Value $newState
        }
        Complete-Backup $ctx 'install'
        Remove-OldBackups -ClaudeHome $ClaudeHome -Keep $KeepBackups
    }
    return [pscustomobject]@{
        Changes   = $ctx.Changes.ToArray()
        Conflicts = $ctx.Conflicts.ToArray()
        Notes     = $ctx.Notes.ToArray()
        BackupDir = $ctx.BackupDir
    }
}

function Write-InstallResult($Result, [bool]$DryRun) {
    $prefix = ''
    if ($DryRun) { $prefix = '(dry run) ' }
    if ($Result.Changes.Count -eq 0) { Write-CcOk "${prefix}Already up to date" }
    foreach ($c in $Result.Changes) { Write-CcInfo "$prefix$c" }
    foreach ($n in $Result.Notes) { Write-CcWarn $n }
    foreach ($c in $Result.Conflicts) { Write-CcWarn $c }
    if ($Result.BackupDir) { Write-CcInfo "Backup of replaced files: $($Result.BackupDir)" }
}

# ---------------------------------------------------------------- drift (installed vs repo)

# Returns objects { Item; Status } where Status is ok, missing, modified
# (changed locally since install) or outdated (repo has a newer version).
function Get-InstallDrift([string]$RepoRoot, [string]$ClaudeHome) {
    $sourceDir = Join-Path $RepoRoot 'claude'
    $state = Read-State $ClaudeHome
    $prevFiles = Get-StateValue $state 'files'
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($rel in (Get-ManagedFiles $sourceDir)) {
        $dest = Join-Path $ClaudeHome (ConvertTo-NativeRel $rel)
        $status = 'ok'
        if (-not (Test-Path -LiteralPath $dest)) {
            $status = 'missing'
        } else {
            $dh = Get-FileHashHex $dest
            if ($dh -ne (Get-FileHashHex (Join-Path $sourceDir (ConvertTo-NativeRel $rel)))) {
                $prev = $null
                if ($null -ne $prevFiles -and $prevFiles.Contains($rel)) { $prev = $prevFiles[$rel] }
                if ($dh -eq $prev) { $status = 'outdated' } else { $status = 'modified' }
            }
        }
        $out.Add([pscustomobject]@{ Item = $rel; Status = $status })
    }
    $md = Join-Path $ClaudeHome 'CLAUDE.md'
    $mdStatus = 'missing'
    if (Test-Path -LiteralPath $md) {
        $block = Get-ManagedBlock (Read-TextFile $md)
        if ($null -ne $block) {
            $bh = Get-TextHash $block.TrimEnd()
            if ($bh -eq (Get-TextHash (Get-RepoClaudeMd $sourceDir))) { $mdStatus = 'ok' }
            elseif ($bh -eq (Get-StateValue $state 'claudeMdHash')) { $mdStatus = 'outdated' }
            else { $mdStatus = 'modified' }
        }
    }
    $out.Add([pscustomobject]@{ Item = 'CLAUDE.md (managed block)'; Status = $mdStatus })
    return , $out.ToArray()
}

# Lists repo settings whose values differ from the local settings.json.
function Get-SettingsDivergence([string]$RepoRoot, [string]$ClaudeHome) {
    $repoSettings = Read-JsonFile (Join-Path (Join-Path $RepoRoot 'claude') 'settings.json')
    $dest = Join-Path $ClaudeHome 'settings.json'
    if (-not (Test-Path -LiteralPath $dest)) { return @('settings.json is missing') }
    $local = Read-JsonFile $dest
    $notes = New-Object System.Collections.Generic.List[string]
    $merged = Merge-Settings -Local $local -Repo $repoSettings -Base $null -Path 'settings' -Notes $notes
    if (-not (Test-JsonEqual $merged $local)) { $notes.Add('settings.json is missing values from the repo (run sync.ps1)') }
    return , $notes.ToArray()
}

# ---------------------------------------------------------------- tools

function Get-ToolSpecs {
    return @(
        @{ Name = 'git'; Required = $true; Args = @('--version'); Install = 'setup.ps1, or: winget install --id Git.Git -e --source winget --scope user' },
        @{ Name = 'gh'; Required = $true; Args = @('--version'); Install = 'setup.ps1, or: winget install --id GitHub.cli -e --source winget --scope user' },
        @{ Name = 'claude'; Required = $true; Args = @('--version'); Install = 'irm https://claude.ai/install.ps1 | iex   (per-user, no admin)' },
        @{ Name = 'pwsh'; Required = $false; Args = @('--version'); Install = 'winget install --id Microsoft.PowerShell -e --source winget --scope user' },
        @{ Name = 'winget'; Required = $false; Args = @('--version'); Install = 'Install "App Installer" from the Microsoft Store' }
    )
}

function Get-VersionFromText([string]$Text) {
    $m = [regex]::Match($Text, '\d+(\.\d+)+')
    if ($m.Success) { return $m.Value }
    return $null
}

# Checks the tools and prints one line each. Returns { Missing; Warnings }:
# every [warn] printed here is counted in Warnings, so callers can report an
# accurate total (#5). Optional tools that are missing are information only.
function Test-Tools {
    $result = [pscustomobject]@{ Missing = 0; Warnings = 0 }
    foreach ($t in (Get-ToolSpecs)) {
        $cmd = Get-Command $t.Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) {
            if ($t.Required) { Write-CcFail "$($t.Name) not found. Install: $($t.Install)"; $result.Missing++ }
            else { Write-CcInfo "$($t.Name) not found (optional). Install: $($t.Install)" }
            continue
        }
        $r = Invoke-Exe -FilePath $cmd.Source -Arguments $t.Args
        $ver = Get-VersionFromText (($r.Output | Select-Object -First 1) -join '')
        Write-CcOk "$($t.Name) $ver"
        if ($t.Name -eq 'claude' -and $ver) {
            try {
                if ([version]$ver -lt [version]$script:TestedClaudeVersion) {
                    Write-CcWarn "Claude Code $ver is older than the tested version $($script:TestedClaudeVersion); run: claude update"
                    $result.Warnings++
                }
            } catch { }
        }
    }
    foreach ($i in (Find-ClaudeInstallations)) {
        if ($i.Kind -eq 'native') { continue }
        Write-CcWarn "Claude Code is also installed via $($i.Kind) ($($i.Path)); run setup.ps1 to keep only the native install"
        $result.Warnings++
    }
    return $result
}

function Test-GhAuth {
    $r = Invoke-Exe -FilePath 'gh' -Arguments @('auth', 'status', '--hostname', 'github.com')
    return ($r.Code -eq 0)
}

function Test-ClaudeAuth {
    $r = Invoke-Exe -FilePath 'claude' -Arguments @('auth', 'status')
    try { return [bool]((ConvertFrom-Json -InputObject ($r.Output -join "`n")).loggedIn) } catch { return $false }
}

function Test-GitIdentity {
    $n = Invoke-Exe -FilePath 'git' -Arguments @('config', '--global', 'user.name')
    $e = Invoke-Exe -FilePath 'git' -Arguments @('config', '--global', 'user.email')
    return ($n.Code -eq 0 -and $e.Code -eq 0)
}

function Test-Auth {
    $problems = 0
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        if (Test-GhAuth) { Write-CcOk 'GitHub CLI authenticated' }
        else { Write-CcWarn 'GitHub CLI not authenticated. Run setup.ps1, or: gh auth login --hostname github.com --git-protocol https --web'; $problems++ }
    }
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        if (Test-ClaudeAuth) { Write-CcOk 'Claude Code signed in' }
        else { Write-CcWarn 'Claude Code not signed in. Run setup.ps1, or: claude auth login   (or start claude and use /login)'; $problems++ }
    }
    if (Get-Command git -ErrorAction SilentlyContinue) {
        if (Test-GitIdentity) { Write-CcOk 'git identity configured' }
        else { Write-CcWarn 'git identity not set. Run setup.ps1, or: git config --global user.name "<name>"; git config --global user.email "<email>"'; $problems++ }
    }
    return $problems
}

# ---------------------------------------------------------------- onboarding (setup.ps1)

$script:UserEnvKey = 'HKCU:\Environment'
$script:ClaudeWingetId = 'Anthropic.ClaudeCode'

# Normalised form of a PATH entry for comparison: env vars expanded, no
# surrounding quotes or trailing separator, case-insensitive.
function Get-PathEntryKey([string]$Entry) {
    $e = [Environment]::ExpandEnvironmentVariables($Entry.Trim().Trim('"')).TrimEnd('\', '/')
    return $e.ToLowerInvariant()
}

function Get-PathEntries([string]$PathValue) {
    if (-not $PathValue) { return , @() }
    return , @($PathValue -split ';' | Where-Object { $_.Trim() })
}

function Test-PathContains([string]$PathValue, [string]$Entry) {
    $key = Get-PathEntryKey $Entry
    foreach ($e in (Get-PathEntries $PathValue)) { if ((Get-PathEntryKey $e) -eq $key) { return $true } }
    return $false
}

# Returns $PathValue with $Entry appended unless an equivalent entry exists.
function Add-PathEntry([string]$PathValue, [string]$Entry) {
    if (Test-PathContains $PathValue $Entry) { return $PathValue }
    $entries = Get-PathEntries $PathValue
    return ((@($entries) + $Entry) -join ';')
}

# The user PATH as stored (unexpanded, so %VAR% entries survive a rewrite).
function Get-UserPathRaw([string]$RegistryKey = $script:UserEnvKey) {
    if (-not (Test-Path -LiteralPath $RegistryKey)) { return '' }
    $v = (Get-Item -LiteralPath $RegistryKey).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    if ($null -eq $v) { return '' }
    return [string]$v
}

# Adds $Entry to the user PATH (REG_EXPAND_SZ, like Windows writes it).
# Returns $true when it changed something. Never touches the machine PATH.
function Add-UserPathEntry([string]$Entry, [string]$RegistryKey = $script:UserEnvKey, [bool]$DryRun = $false) {
    $raw = Get-UserPathRaw $RegistryKey
    if (Test-PathContains $raw $Entry) { return $false }
    if ($DryRun) { return $true }
    if (-not (Test-Path -LiteralPath $RegistryKey)) { New-Item -Path $RegistryKey -Force | Out-Null }
    New-ItemProperty -LiteralPath $RegistryKey -Name 'Path' -Value (Add-PathEntry $raw $Entry) -PropertyType ExpandString -Force | Out-Null
    if ($RegistryKey -eq $script:UserEnvKey) {
        # Setting a user variable through .NET broadcasts WM_SETTINGCHANGE, so
        # terminals opened from now on see the new PATH without signing out.
        [Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_PATH_REFRESH', '1', 'User')
        [Environment]::SetEnvironmentVariable('CLAUDE_CONFIG_PATH_REFRESH', $null, 'User')
    }
    return $true
}

# Refreshes this session's PATH from the machine and user PATH, so tools
# installed by this run (or another terminal) are found without restarting.
# Existing session entries stay first.
function Update-SessionPath([string]$RegistryKey = $script:UserEnvKey) {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::ExpandEnvironmentVariables((Get-UserPathRaw $RegistryKey))
    $result = $env:Path
    foreach ($e in (Get-PathEntries $machine) + (Get-PathEntries $user)) { $result = Add-PathEntry $result $e }
    $env:Path = $result
}

function Get-NativeClaudeBin([string]$UserProfile = $env:USERPROFILE) {
    return (Join-Path (Join-Path $UserProfile '.local') 'bin')
}

# Finds Claude Code installations by their known locations. Returns objects
# { Kind = native|winget|npm; Scope = user|machine; Path }. Only the native
# install (official installer, self-updating) is the standard.
function Find-ClaudeInstallations {
    param(
        [string]$UserProfile = $env:USERPROFILE,
        [string]$LocalAppData = $env:LOCALAPPDATA,
        [string]$AppData = $env:APPDATA,
        [string]$ProgramFiles = $env:ProgramFiles
    )
    $found = New-Object System.Collections.Generic.List[object]
    $native = Join-Path (Get-NativeClaudeBin $UserProfile) 'claude.exe'
    if (Test-Path -LiteralPath $native -PathType Leaf) { $found.Add([pscustomobject]@{ Kind = 'native'; Scope = 'user'; Path = $native }) }
    $wingetRoots = @()
    if ($LocalAppData) { $wingetRoots += , @('user', (Join-Path (Join-Path $LocalAppData 'Microsoft') 'WinGet')) }
    if ($ProgramFiles) { $wingetRoots += , @('machine', (Join-Path $ProgramFiles 'WinGet')) }
    foreach ($w in $wingetRoots) {
        $link = Join-Path (Join-Path $w[1] 'Links') 'claude.exe'
        $pkgDir = Join-Path $w[1] 'Packages'
        $pkg = $null
        if (Test-Path -LiteralPath $pkgDir) {
            $pkg = Get-ChildItem -LiteralPath $pkgDir -Directory -Filter "$($script:ClaudeWingetId)_*" -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if (Test-Path -LiteralPath $link) { $found.Add([pscustomobject]@{ Kind = 'winget'; Scope = $w[0]; Path = $link }) }
        elseif ($pkg) { $found.Add([pscustomobject]@{ Kind = 'winget'; Scope = $w[0]; Path = $pkg.FullName }) }
    }
    if ($AppData) {
        $npm = Join-Path (Join-Path $AppData 'npm') 'claude.cmd'
        if (Test-Path -LiteralPath $npm) { $found.Add([pscustomobject]@{ Kind = 'npm'; Scope = 'user'; Path = $npm }) }
    }
    # Unrolled so callers can pipe it; wrap calls in @() for a count.
    return $found.ToArray()
}

function Test-IsElevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Read-YesNo([string]$Question, [bool]$Default = $true) {
    $hint = '[Y/n]'
    if (-not $Default) { $hint = '[y/N]' }
    while ($true) {
        $a = (Read-Host "  ? $Question $hint").Trim().ToLowerInvariant()
        if (-not $a) { return $Default }
        if (@('y', 'yes') -contains $a) { return $true }
        if (@('n', 'no') -contains $a) { return $false }
    }
}

# Quotes arguments for a Windows command line (CommandLineToArgvW rules):
# backslashes before a quote, or before the closing quote, are doubled.
function ConvertTo-ArgumentString([string[]]$Arguments) {
    $quoted = foreach ($a in $Arguments) {
        if ($a -match '[\s"]' -or $a -eq '') {
            '"' + (($a -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
        } else { $a }
    }
    return ($quoted -join ' ')
}

# Runs a command attached to this console (real TTY, live output, prompts and
# browser sign-in work) and returns its exit code. Waits for that process only,
# not its descendants, so a browser opened during sign-in does not block setup
# (Start-Process -Wait would wait for the whole process tree).
function Invoke-Attached([string]$FilePath, [string[]]$Arguments = @()) {
    $cmd = Get-Command $FilePath -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { Write-CcFail "$FilePath not found"; return 127 }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $cmd.Source
    $psi.Arguments = ConvertTo-ArgumentString $Arguments
    $psi.UseShellExecute = $false
    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.WaitForExit()
        return $p.ExitCode
    } catch { Write-CcFail "$FilePath failed: $($_.Exception.Message)"; return 1 }
}

Export-ModuleMember -Function *
