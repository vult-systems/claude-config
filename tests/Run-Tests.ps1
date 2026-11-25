<#
.SYNOPSIS
    Regression tests for the install, merge, sync and restore logic.

.DESCRIPTION
    Uses a throwaway copy of the repo and a throwaway Claude home under the
    temp directory; never touches the real ~/.claude. No dependencies beyond
    Windows PowerShell 5.1 or PowerShell 7. Exit code = number of failures.
#>
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$scripts = Join-Path $repoRoot 'scripts'
Import-Module (Join-Path $scripts 'ClaudeConfig.psm1') -Force

$script:failed = 0
$script:passed = 0
function Check([string]$Name, [bool]$Condition) {
    if ($Condition) { $script:passed++; Write-Host "  [pass] $Name" -ForegroundColor Green }
    else { $script:failed++; Write-Host "  [FAIL] $Name" -ForegroundColor Red }
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("claude-config-tests-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null

function New-Sandbox([string]$Name) {
    $root = Join-Path $work $Name
    $fakeRepo = Join-Path $root 'repo'
    $home_ = Join-Path $root 'claude-home'
    New-Item -ItemType Directory -Path $fakeRepo -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'claude') -Destination $fakeRepo -Recurse
    Copy-Item -LiteralPath (Join-Path $repoRoot 'VERSION') -Destination $fakeRepo
    return @{ Repo = $fakeRepo; Home = $home_ }
}
function Install($Sb, [switch]$Force) {
    return (Invoke-ClaudeConfigInstall -RepoRoot $Sb.Repo -ClaudeHome $Sb.Home -Force:$Force)
}
# Writes fake git, gh and claude .cmd shims (signed in, identity set) into $Dir
# and returns a PATH holding only them and System32, so tool checks are
# deterministic and no real tool is run.
function New-FakeTools([string]$Dir, [string]$ClaudeVersion = '9.9.9') {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    $shims = @{
        'claude.cmd' = @('@echo off', "if `"%~1`"==`"--version`" echo $ClaudeVersion Claude Code", 'if "%~1"=="auth" echo {"loggedIn":true}', 'exit /b 0')
        'gh.cmd'     = @('@echo off', 'if "%~1"=="--version" echo gh version 2.100.0', 'exit /b 0')
        'git.cmd'    = @('@echo off', 'if "%~1"=="--version" (echo git version 2.50.0& exit /b 0)', 'if "%~1"=="config" (echo Test User& exit /b 0)', 'exit /b 1')
    }
    foreach ($k in $shims.Keys) { Write-TextFile (Join-Path $Dir $k) (($shims[$k] -join "`r`n") + "`r`n") }
    return "$Dir;$(Join-Path $env:SystemRoot 'System32')"
}
# Runs $Block with environment variables temporarily set, then restores them.
function Invoke-WithEnv([hashtable]$Vars, [scriptblock]$Block) {
    $saved = @{}
    foreach ($k in $Vars.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k, 'Process'); [Environment]::SetEnvironmentVariable($k, $Vars[$k], 'Process') }
    try { & $Block } finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k], 'Process') }
    }
}
function HomeFile($Sb, [string]$Rel) { return (Join-Path $Sb.Home (ConvertTo-NativeRel $Rel)) }
function RepoFile($Sb, [string]$Rel) { return (Join-Path (Join-Path $Sb.Repo 'claude') (ConvertTo-NativeRel $Rel)) }

try {
    Write-Host '== fresh install'
    $sb = New-Sandbox 'fresh'
    $r = Install $sb
    Check 'no conflicts' ($r.Conflicts.Count -eq 0)
    Check 'skills installed' (Test-Path (HomeFile $sb 'skills/vult-ship/SKILL.md'))
    Check 'skill templates installed' (Test-Path (HomeFile $sb 'skills/init-project/templates/CLAUDE.md'))
    Check 'agent installed' (Test-Path (HomeFile $sb 'agents/production-reviewer.md'))
    $md = Read-TextFile (HomeFile $sb 'CLAUDE.md')
    Check 'CLAUDE.md has managed block' ($null -ne (Get-ManagedBlock $md))
    $settings = Read-JsonFile (HomeFile $sb 'settings.json')
    Check 'settings.json equals repo settings' (Test-JsonEqual $settings (Read-JsonFile (RepoFile $sb 'settings.json')))
    Check 'settings.json written without BOM' ([IO.File]::ReadAllBytes((HomeFile $sb 'settings.json'))[0] -eq [byte][char]'{')
    Check 'state file written' (Test-Path (Get-StatePath $sb.Home))
    $backupsBefore = @(Get-Backups $sb.Home).Count

    Write-Host '== rerun is idempotent'
    $r = Install $sb
    Check 'no changes on rerun' ($r.Changes.Count -eq 0)
    Check 'no new backup on rerun' (@(Get-Backups $sb.Home).Count -eq $backupsBefore)
    Check 'drift all ok' (@(Get-InstallDrift -RepoRoot $sb.Repo -ClaudeHome $sb.Home | Where-Object { $_.Status -ne 'ok' }).Count -eq 0)
    Write-TextFile (Join-Path $sb.Repo 'VERSION') "9.9.9`n"
    $r = Install $sb
    Check 'version-only change: no changes reported' ($r.Changes.Count -eq 0)
    Check 'version-only change: no backup' (@(Get-Backups $sb.Home).Count -eq $backupsBefore)
    Check 'version-only change: state updated' ((Read-State $sb.Home)['version'] -eq '9.9.9')

    Write-Host '== existing configuration is preserved'
    $sb = New-Sandbox 'existing'
    New-Item -ItemType Directory -Path $sb.Home | Out-Null
    Write-TextFile (HomeFile $sb 'CLAUDE.md') "# My notes`r`nKeep this line.`r`n"
    Write-JsonFile (HomeFile $sb 'settings.json') ([ordered]@{
            theme       = 'light'
            statusLine  = [ordered]@{ type = 'command'; command = 'echo hi' }
            permissions = [ordered]@{ allow = @('Bash(npm test)'); deny = @('Read(./secret.txt)') }
        })
    New-Item -ItemType Directory -Path (Split-Path -Parent (HomeFile $sb 'skills/vult-ship/SKILL.md')) -Force | Out-Null
    Write-TextFile (HomeFile $sb 'skills/vult-ship/SKILL.md') "my own ship skill`n"
    $r = Install $sb
    $md = Read-TextFile (HomeFile $sb 'CLAUDE.md')
    Check 'user CLAUDE.md content kept' ($md -match 'Keep this line\.')
    Check 'managed block appended' ($null -ne (Get-ManagedBlock $md))
    $s = Read-JsonFile (HomeFile $sb 'settings.json')
    Check 'local theme kept' ($s['theme'] -eq 'light')
    Check 'theme divergence reported' (@($r.Notes | Where-Object { $_ -match 'settings\.theme' }).Count -eq 1)
    Check 'unrelated key kept' ($s['statusLine']['command'] -eq 'echo hi')
    Check 'local allow kept, none added' ((@($s['permissions']['allow']) -join ',') -eq 'Bash(npm test)')
    Check 'deny lists unioned' (@($s['permissions']['deny']).Count -eq 5)
    Check 'repo model added' ($s['model'] -eq 'opus')
    Check 'unmanaged skill not overwritten' ((Read-TextFile (HomeFile $sb 'skills/vult-ship/SKILL.md')) -eq "my own ship skill`n")
    Check 'unmanaged skill reported' (@($r.Conflicts | Where-Object { $_ -match 'skills/vult-ship/SKILL.md' }).Count -eq 1)
    $bk = @(Get-Backups $sb.Home)
    Check 'originals backed up' ($bk.Count -eq 1 -and (Test-Path (Join-Path $bk[0].FullName 'settings.json')) -and (Test-Path (Join-Path $bk[0].FullName 'CLAUDE.md')))

    Write-Host '== -Force replaces with backup'
    $r = Install $sb -Force
    Check 'forced skill replaced' ((Get-FileHashHex (HomeFile $sb 'skills/vult-ship/SKILL.md')) -eq (Get-FileHashHex (RepoFile $sb 'skills/vult-ship/SKILL.md')))
    Check 'forced original in backup' ((Read-TextFile (Join-Path $r.BackupDir 'skills\vult-ship\SKILL.md')) -eq "my own ship skill`n")
    Check 'force does not override local settings' ((Read-JsonFile (HomeFile $sb 'settings.json'))['theme'] -eq 'light')

    Write-Host '== local edits survive updates'
    $sb = New-Sandbox 'edits'
    [void](Install $sb)
    Add-Content -LiteralPath (HomeFile $sb 'skills/issue/SKILL.md') -Value 'local tweak'
    Add-Content -LiteralPath (RepoFile $sb 'skills/hotfix/SKILL.md') -Value 'repo update'
    $r = Install $sb
    Check 'locally edited skill kept' ((Read-TextFile (HomeFile $sb 'skills/issue/SKILL.md')) -match 'local tweak')
    Check 'edit reported as conflict' (@($r.Conflicts | Where-Object { $_ -match 'skills/issue' }).Count -eq 1)
    Check 'unmodified skill updated' ((Read-TextFile (HomeFile $sb 'skills/hotfix/SKILL.md')) -match 'repo update')
    $drift = Get-InstallDrift -RepoRoot $sb.Repo -ClaudeHome $sb.Home
    Check 'drift shows modified' (@($drift | Where-Object { $_.Item -eq 'skills/issue/SKILL.md' -and $_.Status -eq 'modified' }).Count -eq 1)

    Write-Host '== settings updates propagate unless changed locally'
    $sb = New-Sandbox 'settings'
    [void](Install $sb)
    $rs = Read-JsonFile (RepoFile $sb 'settings.json')
    $rs['model'] = 'sonnet'
    $rs['permissions']['deny'] = @($rs['permissions']['deny'] | Where-Object { $_ -ne 'Read(**/*.pem)' })
    $rs.Remove('tui')
    Write-JsonFile (RepoFile $sb 'settings.json') $rs
    $local = Read-JsonFile (HomeFile $sb 'settings.json')
    $local['theme'] = 'light'
    Write-JsonFile (HomeFile $sb 'settings.json') $local
    $r = Install $sb
    $s = Read-JsonFile (HomeFile $sb 'settings.json')
    Check 'unchanged scalar updated' ($s['model'] -eq 'sonnet')
    Check 'locally changed scalar kept' ($s['theme'] -eq 'light')
    Check 'removed array item removed' (@($s['permissions']['deny']) -notcontains 'Read(**/*.pem)')
    Check 'removed key removed' (-not $s.Contains('tui'))

    Write-Host '== removed skill is uninstalled'
    $sb = New-Sandbox 'removed'
    [void](Install $sb)
    Remove-Item -LiteralPath (Split-Path -Parent (RepoFile $sb 'skills/handoff/SKILL.md')) -Recurse
    $r = Install $sb
    Check 'skill file removed' (-not (Test-Path (HomeFile $sb 'skills/handoff/SKILL.md')))
    Check 'empty skill folder removed' (-not (Test-Path (Split-Path -Parent (HomeFile $sb 'skills/handoff/SKILL.md'))))
    Check 'skills folder kept' (Test-Path (Join-Path $sb.Home 'skills'))

    Write-Host '== renamed skill migrates (ship -> vult-ship, #3)'
    $sb = New-Sandbox 'rename'
    Rename-Item -LiteralPath (Split-Path -Parent (RepoFile $sb 'skills/vult-ship/SKILL.md')) -NewName 'ship'
    [void](Install $sb)
    Check 'old name installed first' (Test-Path (HomeFile $sb 'skills/ship/SKILL.md'))
    Rename-Item -LiteralPath (Split-Path -Parent (RepoFile $sb 'skills/ship/SKILL.md')) -NewName 'vult-ship'
    $r = Install $sb
    Check 'rename: no conflicts' ($r.Conflicts.Count -eq 0)
    Check 'rename: old skill folder removed' (-not (Test-Path (Split-Path -Parent (HomeFile $sb 'skills/ship/SKILL.md'))))
    Check 'rename: new skill installed' (Test-Path (HomeFile $sb 'skills/vult-ship/SKILL.md'))
    Check 'rename: state tracks only new name' (-not (Read-State $sb.Home)['files'].Contains('skills/ship/SKILL.md'))

    Write-Host '== invalid settings.json is left alone'
    $sb = New-Sandbox 'invalid'
    New-Item -ItemType Directory -Path $sb.Home | Out-Null
    Write-TextFile (HomeFile $sb 'settings.json') '{ not json'
    $r = Install $sb
    Check 'invalid settings untouched' ((Read-TextFile (HomeFile $sb 'settings.json')) -eq '{ not json')
    Check 'invalid settings reported' (@($r.Conflicts | Where-Object { $_ -match 'not valid JSON' }).Count -eq 1)

    Write-Host '== CLAUDE.md block updates in place'
    $sb = New-Sandbox 'block'
    [void](Install $sb)
    Add-Content -LiteralPath (HomeFile $sb 'CLAUDE.md') -Value "`nMy trailing note"
    Add-Content -LiteralPath (RepoFile $sb 'CLAUDE.md') -Value 'New global rule.'
    [void](Install $sb)
    $md = Read-TextFile (HomeFile $sb 'CLAUDE.md')
    Check 'block updated' ((Get-ManagedBlock $md) -match 'New global rule\.')
    Check 'text after block kept' ($md -match 'My trailing note')
    Check 'single block' (([regex]::Matches($md, 'BEGIN claude-config')).Count -eq 1)

    Write-Host '== dry run writes nothing'
    $sb = New-Sandbox 'dryrun'
    $r = Invoke-ClaudeConfigInstall -RepoRoot $sb.Repo -ClaudeHome $sb.Home -DryRun
    Check 'dry run lists changes' ($r.Changes.Count -gt 0)
    Check 'dry run created nothing' (-not (Test-Path $sb.Home))

    Write-Host '== restore.ps1 and sync.ps1 -Capture (end to end)'
    $sb = New-Sandbox 'e2e'
    New-Item -ItemType Directory -Path $sb.Home | Out-Null
    Write-JsonFile (HomeFile $sb 'settings.json') ([ordered]@{ theme = 'light' })
    Copy-Item -LiteralPath $scripts -Destination $sb.Repo -Recurse
    $oldHome = $env:CLAUDE_CONFIG_DIR
    $env:CLAUDE_CONFIG_DIR = $sb.Home
    try {
        $ps = (Get-Process -Id $PID).Path
        [void](Install $sb)
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sb.Repo 'scripts\restore.ps1') -Latest | Out-Null
        Check 'restore exit code 0' ($LASTEXITCODE -eq 0)
        Check 'restore brought back original settings' (Test-JsonEqual (Read-JsonFile (HomeFile $sb 'settings.json')) ([ordered]@{ theme = 'light' }))
        Check 'restore removed created files' (-not (Test-Path (HomeFile $sb 'skills/vult-ship/SKILL.md')))
        Check 'restore kept a pre-restore backup' (@(Get-Backups $sb.Home).Count -eq 2)

        [void](Install $sb -Force)
        Add-Content -LiteralPath (HomeFile $sb 'skills/vult-ship/SKILL.md') -Value 'captured edit'
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sb.Repo 'scripts\sync.ps1') -Capture | Out-Null
        Check 'capture exit code 0' ($LASTEXITCODE -eq 0)
        Check 'capture copied edit into repo' ((Read-TextFile (RepoFile $sb 'skills/vult-ship/SKILL.md')) -match 'captured edit')
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sb.Repo 'scripts\sync.ps1') -NoPull | Out-Null
        Check 'sync after capture is clean' ($LASTEXITCODE -eq 0)
    } finally {
        $env:CLAUDE_CONFIG_DIR = $oldHome
    }

    Write-Host '== validate rejects skills named after built-in commands (#3)'
    $vr = Join-Path $work 'validate-repo'
    New-Item -ItemType Directory -Path $vr | Out-Null
    foreach ($item in @(Get-ChildItem -LiteralPath $repoRoot -Force | Where-Object { $_.Name -ne '.git' })) {
        Copy-Item -LiteralPath $item.FullName -Destination $vr -Recurse
    }
    $ps = (Get-Process -Id $PID).Path
    & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $vr 'scripts\validate.ps1') -RepoOnly | Out-Null
    Check 'validate passes on a clean copy' ($LASTEXITCODE -eq 0)
    $shipDir = Join-Path $vr 'claude\skills\ship'
    New-Item -ItemType Directory -Path $shipDir | Out-Null
    Write-TextFile (Join-Path $shipDir 'SKILL.md') "---`nname: ship`ndescription: clashes with a built-in`n---`n"
    $out = & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $vr 'scripts\validate.ps1') -RepoOnly 6>&1 2>&1 | Out-String
    Check 'validate fails on a built-in name' ($LASTEXITCODE -eq 1)
    Check 'failure names the conflict' ($out -match 'skills/ship: conflicts with a built-in')
    Remove-Item -LiteralPath $shipDir -Recurse -Force

    Write-Host '== validate counts every warning it prints (#5)'
    # Fake tools on a controlled PATH: claude is older than the tested version,
    # pwsh and winget are absent (optional, so information only).
    $fake = New-FakeTools (Join-Path $work 'fake-old') -ClaudeVersion '2.0.0'
    $sb = New-Sandbox 'warncount'
    [void](Install $sb)
    $out = Invoke-WithEnv @{ Path = $fake; CLAUDE_CONFIG_DIR = $sb.Home; LOCALAPPDATA = (Join-Path $work 'empty'); APPDATA = (Join-Path $work 'empty') } {
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $vr 'scripts\validate.ps1') 6>&1 2>&1 | Out-String
    }
    $code = $LASTEXITCODE
    $printed = ([regex]::Matches($out, '\[warn\]')).Count
    Check 'old Claude Code is a warning' ($out -match 'older than the tested version')
    Check 'missing pwsh is information, not a warning' ($out -match 'pwsh not found \(optional\)' -and $out -notmatch '\[warn\][^\n]*pwsh')
    Check 'summary counts the printed warnings' ($out -match 'passed with 1 warning\(s\)' -and $printed -eq 2)
    Check 'warnings alone exit 0' ($code -eq 0)
    Invoke-WithEnv @{ Path = $fake; CLAUDE_CONFIG_DIR = $sb.Home; LOCALAPPDATA = (Join-Path $work 'empty'); APPDATA = (Join-Path $work 'empty') } {
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $vr 'scripts\validate.ps1') -Strict | Out-Null
    }
    Check '-Strict exits 2 on warnings' ($LASTEXITCODE -eq 2)
} catch {
    $script:failed++
    Write-Host "  [FAIL] unexpected error: $($_.Exception.Message)`n$($_.ScriptStackTrace)" -ForegroundColor Red
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "PowerShell $($PSVersionTable.PSVersion): $($script:passed) passed, $($script:failed) failed"
exit $script:failed
