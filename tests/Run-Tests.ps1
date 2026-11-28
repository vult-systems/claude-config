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
# Adds shared preferences to a sandbox repo, as v1.0.0-rc.1 shipped them, so
# merge behaviour is tested independently of the current repo settings.
function Add-RepoPreferences($Sb) {
    $rs = Read-JsonFile (RepoFile $Sb 'settings.json')
    $rs['model'] = 'opus'; $rs['theme'] = 'dark-daltonized'; $rs['tui'] = 'fullscreen'
    $rs['statusLine'] = [ordered]@{ type = 'command'; command = 'echo shared' }
    $rs['permissions']['disableBypassPermissionsMode'] = 'disable'
    Write-JsonFile (RepoFile $Sb 'settings.json') $rs
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
    Add-RepoPreferences $sb
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
    Add-RepoPreferences $sb
    [void](Install $sb)
    $rs = Read-JsonFile (RepoFile $sb 'settings.json')
    $rs['model'] = 'sonnet'
    $rs['permissions']['deny'] = @($rs['permissions']['deny'] | Where-Object { $_ -ne 'Read(**/*.pem)' })
    $rs.Remove('tui')
    $rs.Remove('statusLine')
    $rs['permissions'].Remove('disableBypassPermissionsMode')
    Write-JsonFile (RepoFile $sb 'settings.json') $rs
    $local = Read-JsonFile (HomeFile $sb 'settings.json')
    $local['theme'] = 'light'
    Write-JsonFile (HomeFile $sb 'settings.json') $local
    $r = Install $sb
    $s = Read-JsonFile (HomeFile $sb 'settings.json')
    Check 'unchanged scalar updated' ($s['model'] -eq 'sonnet')
    Check 'locally changed scalar kept' ($s['theme'] -eq 'light')
    Check 'removed array item removed' (@($s['permissions']['deny']) -notcontains 'Read(**/*.pem)')
    Check 'removed object key removed' (-not $s.Contains('statusLine'))
    Check 'removed scalar released, value kept' ($s['tui'] -eq 'fullscreen')
    Check 'released scalar reported' (@($r.Notes | Where-Object { $_ -match 'settings\.tui is no longer shared' }).Count -eq 1)
    Check 'removed nested policy scalar retired' (-not $s['permissions'].Contains('disableBypassPermissionsMode'))

    Write-Host '== rc.1 preferences survive the move to security-only settings (#8)'
    $sb = New-Sandbox 'prefs'
    Add-RepoPreferences $sb
    [void](Install $sb)
    $local = Read-JsonFile (HomeFile $sb 'settings.json')
    $local['theme'] = 'light'
    Write-JsonFile (HomeFile $sb 'settings.json') $local
    Copy-Item -LiteralPath (Join-Path (Join-Path $repoRoot 'claude') 'settings.json') -Destination (RepoFile $sb 'settings.json') -Force
    $r = Install $sb
    $s = Read-JsonFile (HomeFile $sb 'settings.json')
    Check 'unchanged model kept' ($s['model'] -eq 'opus')
    Check 'unchanged tui kept' ($s['tui'] -eq 'fullscreen')
    Check 'locally changed theme kept' ($s['theme'] -eq 'light')
    Check 'security deny list still applied' (@($s['permissions']['deny']).Count -eq 4)
    $r = Install $sb
    Check 'second run quiet' ($r.Changes.Count -eq 0 -and $r.Notes.Count -eq 0)
    $fresh = New-Sandbox 'prefs-fresh'
    [void](Install $fresh)
    $s = Read-JsonFile (HomeFile $fresh 'settings.json')
    Check 'fresh install gets Claude Code defaults' (-not ($s.Contains('model') -or $s.Contains('theme') -or $s.Contains('tui')))

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

    Write-Host '== validate rejects personal email addresses (#8)'
    $mailFile = Join-Path $vr 'docs-note.md'
    Write-TextFile $mailFile ("Contact jane.doe" + "@acme-corp.net for access.`n")
    $out = & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $vr 'scripts\validate.ps1') -RepoOnly 6>&1 2>&1 | Out-String
    Check 'validate fails on a personal email' ($LASTEXITCODE -eq 1 -and $out -match 'docs-note.md: contains an email address')
    Check 'the address is masked in the output' ($out -notmatch 'jane\.doe')
    Write-TextFile $mailFile ("Commits: 1+someone" + "@users.noreply.github.com, tests: a" + "@example.com, b" + "@docs.example.org`n" +
        "SSH: git" + "@github.com:owner/repo.git, placeholder: c" + "@contoso.test, d" + "@host.invalid, asset: icon" + "@2x.png`n")
    & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $vr 'scripts\validate.ps1') -RepoOnly | Out-Null
    Check 'noreply, example, reserved, SSH and asset names are allowed' ($LASTEXITCODE -eq 0)
    Remove-Item -LiteralPath $mailFile

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
    # (PowerShell 7 puts its own folder on PATH, so check winget, absent in both.)
    Check 'missing optional tool is information, not a warning' ($out -match 'winget not found \(optional\)' -and $out -notmatch '\[warn\][^\n]*(pwsh|winget)')
    Check 'summary counts the printed warnings' ($out -match 'passed with 1 warning\(s\)' -and $printed -eq 2)
    Check 'warnings alone exit 0' ($code -eq 0)
    Invoke-WithEnv @{ Path = $fake; CLAUDE_CONFIG_DIR = $sb.Home; LOCALAPPDATA = (Join-Path $work 'empty'); APPDATA = (Join-Path $work 'empty') } {
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $vr 'scripts\validate.ps1') -Strict | Out-Null
    }
    Check '-Strict exits 2 on warnings' ($LASTEXITCODE -eq 2)

    Write-Host '== Claude Code sign-in check tolerates extra output (#12)'
    Check 'plain JSON, signed in' ((Get-ClaudeLoggedIn '{"loggedIn":true}') -eq $true)
    Check 'plain JSON, signed out' ((Get-ClaudeLoggedIn '{"loggedIn":false}') -eq $false)
    Check 'notice before the JSON' ((Get-ClaudeLoggedIn "Update installed, restart to apply`n{`n  `"loggedIn`": true`n}") -eq $true)
    Check 'notice after the JSON' ((Get-ClaudeLoggedIn "{`"loggedIn`":true}`nA new version is available") -eq $true)
    Check 'malformed JSON is unreadable' ($null -eq (Get-ClaudeLoggedIn '{"loggedIn":'))
    Check 'JSON without loggedIn is unreadable' ($null -eq (Get-ClaudeLoggedIn '{"authMethod":"none"}'))
    Check 'non-boolean loggedIn is unreadable' ($null -eq (Get-ClaudeLoggedIn '{"loggedIn":"true"}'))
    Check 'plain text is unreadable' ($null -eq (Get-ClaudeLoggedIn 'Not logged in. Run claude auth login to authenticate.'))
    Check 'empty output is unreadable' ($null -eq (Get-ClaudeLoggedIn ''))

    # Each shim is a fake claude.cmd. It answers `auth status` only when --json
    # is passed (otherwise text, as Claude Code does), so the flag is covered too.
    $authCases = @{
        'stderr-notice' = @('echo Update installed, restart to apply 1>&2', 'echo {"loggedIn":true}', 'exit /b 0')
        'stdout-notice' = @('echo Claude Code has been updated.', 'echo {"loggedIn":true}', 'exit /b 0')
        'signed-out'    = @('echo {"loggedIn":false,"authMethod":"none"}', 'exit /b 1')
        'malformed'     = @('echo {"loggedIn":', 'exit /b 0')
        'crash'         = @('echo Error: cannot read configuration 1>&2', 'exit /b 1')
        'silent'        = @('exit /b 3')
    }
    $authPath = @{}
    foreach ($k in $authCases.Keys) {
        $d = Join-Path (Join-Path $work 'fake-auth') $k
        [void](New-FakeTools $d)
        $body = @('@echo off', 'if "%~1"=="--version" (echo 9.9.9 Claude Code& exit /b 0)', 'if not "%~3"=="--json" (echo Signed in with text output& exit /b 0)') + $authCases[$k]
        Write-TextFile (Join-Path $d 'claude.cmd') (($body -join "`r`n") + "`r`n")
        $authPath[$k] = "$d;$(Join-Path $env:SystemRoot 'System32')"
    }
    $authOf = { param([string]$Case) Invoke-WithEnv @{ Path = $authPath[$Case] } { Get-ClaudeAuthStatus } }
    Check 'stderr notice with loggedIn true: signed in' ((& $authOf 'stderr-notice').State -eq 'signed-in')
    Check 'Test-ClaudeAuth true despite a stderr notice' ((Invoke-WithEnv @{ Path = $authPath['stderr-notice'] } { Test-ClaudeAuth }) -eq $true)
    Check 'stdout notice with loggedIn true: signed in' ((& $authOf 'stdout-notice').State -eq 'signed-in')
    Check 'loggedIn false with exit 1: signed out' ((& $authOf 'signed-out').State -eq 'signed-out')
    $st = & $authOf 'malformed'
    Check 'malformed output: unknown, not signed out' ($st.State -eq 'unknown' -and $st.Detail -match 'exit code 0')
    $st = & $authOf 'crash'
    Check 'command failure: unknown with the error' ($st.State -eq 'unknown' -and $st.Detail -match 'exit code 1: Error: cannot read configuration')
    $st = & $authOf 'silent'
    Check 'no output: unknown with the exit code' ($st.State -eq 'unknown' -and $st.Detail -eq 'exit code 3, no output')
    Check 'Test-ClaudeAuth false when the check fails' (-not (Invoke-WithEnv @{ Path = $authPath['crash'] } { Test-ClaudeAuth }))

    foreach ($case in @(
            @{ Name = 'stderr-notice'; Expect = 'Claude Code signed in'; Warns = 0 },
            @{ Name = 'signed-out'; Expect = 'Claude Code not signed in'; Warns = 1 },
            @{ Name = 'crash'; Expect = 'Could not check Claude Code sign-in \(exit code 1: Error: cannot read configuration\)'; Warns = 1 })) {
        $out = Invoke-WithEnv @{ Path = $authPath[$case.Name]; CLAUDE_CONFIG_DIR = $sb.Home; LOCALAPPDATA = (Join-Path $work 'empty'); APPDATA = (Join-Path $work 'empty') } {
            & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $vr 'scripts\validate.ps1') 6>&1 2>&1 | Out-String
        }
        $summary = 'Validation passed \(0 warnings\)'
        if ($case.Warns -gt 0) { $summary = "passed with $($case.Warns) warning\(s\)" }
        Check "validate, $($case.Name): reports '$($case.Expect -replace '\\', '')'" ($out -match $case.Expect)
        Check "validate, $($case.Name): counts $($case.Warns) warning(s)" ($out -match $summary)
    }

    Write-Host '== PATH helpers (#6)'
    Check 'adds a missing entry' ((Add-PathEntry 'C:\a;C:\b' 'C:\c') -eq 'C:\a;C:\b;C:\c')
    Check 'adds to an empty PATH' ((Add-PathEntry '' 'C:\c') -eq 'C:\c')
    Check 'drops empty segments when adding' ((Add-PathEntry 'C:\a;;C:\b;' 'C:\c') -eq 'C:\a;C:\b;C:\c')
    Check 'case and trailing slash are equivalent' ((Add-PathEntry 'C:\A\Bin\;C:\b' 'c:\a\bin') -eq 'C:\A\Bin\;C:\b')
    Check '%VAR% entries match their expansion' (Test-PathContains '%USERPROFILE%\.local\bin' (Join-Path $env:USERPROFILE '.local\bin'))
    $key = "HKCU:\Software\claude-config-tests\$([guid]::NewGuid().ToString('N'))"
    try {
        New-Item -Path $key -Force | Out-Null
        New-ItemProperty -LiteralPath $key -Name Path -Value '%SystemRoot%\x;C:\y' -PropertyType ExpandString | Out-Null
        Check 'user PATH add reports a change' (Add-UserPathEntry -Entry 'C:\z' -RegistryKey $key)
        Check 'user PATH keeps %VAR% unexpanded' ((Get-UserPathRaw $key) -eq '%SystemRoot%\x;C:\y;C:\z')
        Check 'user PATH stays REG_EXPAND_SZ' ((Get-Item -LiteralPath $key).GetValueKind('Path') -eq 'ExpandString')
        Check 'user PATH add is idempotent' (-not (Add-UserPathEntry -Entry 'C:\Z\' -RegistryKey $key))
        Check 'dry run reports without writing' ((Add-UserPathEntry -Entry 'C:\w' -RegistryKey $key -DryRun $true) -and (Get-UserPathRaw $key) -notmatch 'w$')
        $oldPath = $env:Path
        try {
            $env:Path = 'C:\session-only'
            Update-SessionPath $key
            Check 'session refresh keeps session entries first' ($env:Path.StartsWith('C:\session-only;'))
            Check 'session refresh adds user entries' ($env:Path -match [regex]::Escape('C:\z'))
        } finally { $env:Path = $oldPath }
    } finally { Remove-Item -LiteralPath (Split-Path -Parent $key) -Recurse -Force -ErrorAction SilentlyContinue }

    Write-Host '== attached commands (#6)'
    Check 'plain arguments unquoted' ((ConvertTo-ArgumentString @('auth', '--web')) -eq 'auth --web')
    Check 'spaces quoted' ((ConvertTo-ArgumentString @('a b')) -eq '"a b"')
    Check 'trailing backslash doubled inside quotes' ((ConvertTo-ArgumentString @('C:\a b\')) -eq '"C:\a b\\"')
    Check 'embedded quote escaped' ((ConvertTo-ArgumentString @('say "hi"')) -eq '"say \"hi\""')
    $fakeGit = Join-Path (Join-Path $work 'fake-old') 'git.cmd'
    Check 'attached command returns exit 0' ((Invoke-Attached $fakeGit @('--version')) -eq 0)
    Check 'attached command returns non-zero exit' ((Invoke-Attached $fakeGit @('nope')) -eq 1)

    Write-Host '== Claude Code installation detection (#6)'
    $fx = Join-Path $work 'detect'
    $fxProfile = Join-Path $fx 'profile'; $fxLocal = Join-Path $fx 'local'; $fxRoaming = Join-Path $fx 'roaming'; $fxPf = Join-Path $fx 'pf'
    foreach ($d in @($fxProfile, $fxLocal, $fxRoaming, $fxPf)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    $detect = { Find-ClaudeInstallations -UserProfile $fxProfile -LocalAppData $fxLocal -AppData $fxRoaming -ProgramFiles $fxPf }
    Check 'nothing installed: nothing found' (@(& $detect).Count -eq 0)
    New-Item -ItemType Directory -Path (Join-Path $fxProfile '.local\bin') -Force | Out-Null
    Write-TextFile (Join-Path $fxProfile '.local\bin\claude.exe') 'x'
    $found = @(& $detect)
    Check 'native install found' ($found.Count -eq 1 -and $found[0].Kind -eq 'native')
    New-Item -ItemType Directory -Path (Join-Path $fxLocal 'Microsoft\WinGet\Packages\Anthropic.ClaudeCode_Microsoft.Winget.Source_8wekyb3d8bbwe') -Force | Out-Null
    $found = @(& $detect)
    Check 'winget package folder found (user)' (@($found | Where-Object { $_.Kind -eq 'winget' -and $_.Scope -eq 'user' }).Count -eq 1)
    New-Item -ItemType Directory -Path (Join-Path $fxLocal 'Microsoft\WinGet\Links') -Force | Out-Null
    Write-TextFile (Join-Path $fxLocal 'Microsoft\WinGet\Links\claude.exe') 'x'
    $found = @(& $detect)
    Check 'winget link preferred and not duplicated' (@($found | Where-Object { $_.Kind -eq 'winget' }).Count -eq 1 -and @($found | Where-Object { $_.Kind -eq 'winget' })[0].Path -match 'Links')
    New-Item -ItemType Directory -Path (Join-Path $fxPf 'WinGet\Links') -Force | Out-Null
    Write-TextFile (Join-Path $fxPf 'WinGet\Links\claude.exe') 'x'
    New-Item -ItemType Directory -Path (Join-Path $fxRoaming 'npm') -Force | Out-Null
    Write-TextFile (Join-Path $fxRoaming 'npm\claude.cmd') 'x'
    $found = @(& $detect)
    Check 'machine winget and npm found' (@($found | Where-Object { $_.Scope -eq 'machine' }).Count -eq 1 -and @($found | Where-Object { $_.Kind -eq 'npm' }).Count -eq 1)
    New-Item -ItemType Directory -Path (Join-Path $fxLocal 'Microsoft\WinGet\Packages\Other.Tool_x') -Force | Out-Null
    Check 'unrelated winget package ignored' (@(& $detect).Count -eq 4)

    Write-Host '== validate warns about a WinGet copy of Claude Code (#6)'
    $fakeNew = New-FakeTools (Join-Path $work 'fake-new')
    $out = Invoke-WithEnv @{ Path = $fakeNew; CLAUDE_CONFIG_DIR = $sb.Home; LOCALAPPDATA = $fxLocal; APPDATA = (Join-Path $work 'empty') } {
        & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $vr 'scripts\validate.ps1') 6>&1 2>&1 | Out-String
    }
    Check 'winget copy reported' ($out -match 'also installed via winget')
    Check 'winget copy counted' ($out -match 'passed with 1 warning\(s\)')

    Write-Host '== setup.cmd end to end (#6)'
    # Fake tools that are installed and signed in, a fake native Claude Code in
    # a scratch profile, and a scratch registry key instead of the user PATH.
    # setup.cmd always runs Windows PowerShell 5.1, so under PowerShell 7 this
    # also covers starting 5.1 from a 7 session.
    $sx = Join-Path $work 'setup'
    $sxProfile = Join-Path $sx 'profile'; $sxLocal = Join-Path $sx 'local'
    New-Item -ItemType Directory -Path (Join-Path $sxProfile '.local\bin') -Force | Out-Null
    New-Item -ItemType Directory -Path $sxLocal -Force | Out-Null
    Write-TextFile (Join-Path $sxProfile '.local\bin\claude.exe') 'placeholder'
    $sxHome = Join-Path $sx 'claude-home'
    $sxKey = "HKCU:\Software\claude-config-tests\$([guid]::NewGuid().ToString('N'))"
    $elevated = Test-IsElevated
    $okCode = 0; if ($elevated) { $okCode = 2 }   # running elevated is a warning (CI runners are)
    $setupEnv = @{ Path = $fakeNew; CLAUDE_CONFIG_DIR = $sxHome; USERPROFILE = $sxProfile; LOCALAPPDATA = $sxLocal; APPDATA = (Join-Path $work 'empty') }
    $runSetup = {
        param([string[]]$Extra)
        $argList = @('/c', (Join-Path $vr 'setup.cmd'), '-NonInteractive', '-PathRegistryKey', $sxKey) + $Extra
        Invoke-WithEnv $setupEnv { & cmd.exe @argList 2>&1 | Out-String }
    }
    try {
        $out = & $runSetup @('-DryRun')
        Check 'dry run exits 0' ($LASTEXITCODE -eq 0)
        Check 'dry run installs nothing' (-not (Test-Path $sxHome))
        Check 'dry run leaves PATH alone' (-not (Test-Path $sxKey))
        Check 'dry run says what it would add' ($out -match '\(dry run\) added .*\.local\\bin to your user PATH')

        $out = & $runSetup @()
        Check "setup exits $okCode" ($LASTEXITCODE -eq $okCode)
        Check 'setup installed the configuration' (Test-Path (Join-Path $sxHome 'skills\vult-ship\SKILL.md'))
        Check 'setup added the native bin to user PATH' (Test-PathContains (Get-UserPathRaw $sxKey) (Join-Path $sxProfile '.local\bin'))
        Check 'setup reports sign-in state' ($out -match 'GitHub CLI signed in' -and $out -match 'Claude Code signed in' -and $out -match 'git identity configured')
        Check 'setup validated' ($out -match 'Validation passed')
        $warnLines = @([regex]::Matches($out, '\[warn\][^\r\n]*') | ForEach-Object { $_.Value } | Where-Object { $_ -notmatch 'administrator|finished with' })
        Check 'setup has no unexpected warnings' ($warnLines.Count -eq 0)
        if ($warnLines.Count -gt 0) { Write-Host ($warnLines -join "`n") }

        $out = & $runSetup @()
        Check "rerun exits $okCode" ($LASTEXITCODE -eq $okCode)
        Check 'rerun changes nothing' ($out -match 'Already up to date' -and $out -notmatch 'to your user PATH')
        Check 'rerun does not duplicate the PATH entry' (@((Get-UserPathRaw $sxKey) -split ';' | Where-Object { $_ -like '*.local\bin' }).Count -eq 1)

        New-Item -ItemType Directory -Path (Join-Path $sxLocal 'Microsoft\WinGet\Links') -Force | Out-Null
        Write-TextFile (Join-Path $sxLocal 'Microsoft\WinGet\Links\claude.exe') 'x'
        $out = & $runSetup @()
        Check 'conflict: exits 2' ($LASTEXITCODE -eq 2)
        Check 'conflict: reported with the remove command' ($out -match 'winget uninstall --id Anthropic.ClaudeCode')
        Check 'conflict: nothing removed without confirmation' (Test-Path (Join-Path $sxLocal 'Microsoft\WinGet\Links\claude.exe'))

        $out = & $runSetup @('-Yes')
        Check '-Yes: removal still not done without an explicit answer' ((Test-Path (Join-Path $sxLocal 'Microsoft\WinGet\Links\claude.exe')) -and $out -match 'was kept|Remove it with')

        $out = & $runSetup @('-NoInstall', '-SkipAuth')
        Check '-NoInstall -SkipAuth runs without prompting' ($LASTEXITCODE -eq 2 -and $out -match 'Sign-in \(skipped\)')
        Remove-Item -LiteralPath $sxKey -Recurse -Force
        $out = & $runSetup @('-NoInstall', '-SkipAuth')
        Check '-NoInstall reports PATH instead of changing it' ((-not (Test-Path $sxKey)) -and $out -match 'is not on your user PATH')
    } finally {
        Remove-Item -LiteralPath (Split-Path -Parent $sxKey) -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host '== install.ps1 end to end (#8)'
    # Clones a throwaway git repo built from this working tree with real git;
    # the other tools are the signed-in fakes, minus the fake git.
    $src = Join-Path $work 'install-src'
    Copy-Item -LiteralPath $vr -Destination $src -Recurse
    # Prefer Git's cmd launcher; its internal binaries need sibling folders on PATH.
    $gits = @(Get-Command git -All -CommandType Application)
    $realGit = @($gits | Where-Object { $_.Source -like '*\cmd\git.exe' } | Select-Object -First 1)
    if ($realGit.Count -eq 0) { $realGit = @($gits | Select-Object -First 1) }
    $realGit = $realGit[0].Source
    foreach ($a in @(@('init', '-q'), @('add', '-A'), @('-c', 'user.name=test', '-c', 'user.email=test@example.com', 'commit', '-q', '-m', 'snapshot'))) {
        [void](Invoke-Exe -FilePath $realGit -Arguments (@('-C', $src) + $a))
    }
    $noGit = Join-Path $work 'fake-nogit'
    [void](New-FakeTools $noGit)
    Remove-Item -LiteralPath (Join-Path $noGit 'git.cmd')
    $ix = Join-Path $work 'install'
    $ixProfile = Join-Path $ix 'profile'
    New-Item -ItemType Directory -Path (Join-Path $ixProfile '.local\bin') -Force | Out-Null
    Write-TextFile (Join-Path $ixProfile '.local\bin\claude.exe') 'placeholder'
    $ixClone = Join-Path $ix 'repos\claude-config'
    $ixKey = "HKCU:\Software\claude-config-tests\$([guid]::NewGuid().ToString('N'))"
    $ixEnv = @{ Path = "$noGit;$(Split-Path -Parent $realGit);$(Join-Path $env:SystemRoot 'System32')"; CLAUDE_CONFIG_DIR = (Join-Path $ix 'claude-home'); USERPROFILE = $ixProfile; LOCALAPPDATA = (Join-Path $work 'empty'); APPDATA = (Join-Path $work 'empty') }
    $runInstall = {
        param([string]$Target, [string[]]$Extra)
        $argList = @('-NoProfile', '-ExecutionPolicy', 'RemoteSigned', '-File', (Join-Path $src 'install.ps1'), '-Path', $Target, '-Repository', $src, '-NonInteractive') + $Extra
        # git writes progress to stderr; under 5.1 with Stop, 2>&1 would throw on it.
        $ErrorActionPreference = 'Continue'
        Invoke-WithEnv $ixEnv { & $ps @argList 2>&1 | Out-String }
    }
    try {
        $out = & $runInstall $ixClone @('-DryRun')
        Check 'install dry run exits 0 and clones nothing' ($LASTEXITCODE -eq 0 -and -not (Test-Path $ixClone) -and $out -match '\(dry run\) would run: git clone')

        $out = & $runInstall $ixClone @('-SkipAuth', '-PathRegistryKey', $ixKey)
        $ixCode = $LASTEXITCODE
        Check "install exits with setup's code ($okCode)" ($ixCode -eq $okCode)
        Check 'install cloned the repo' (Test-Path (Join-Path $ixClone '.git'))
        Check 'install ran setup with passed-through arguments' ($out -match 'Sign-in \(skipped\)' -and $out -match 'Setup (complete|finished)')
        Check 'install left configuration installed' (Test-Path (Join-Path $ix 'claude-home\skills\vult-ship\SKILL.md'))

        $out = & $runInstall $ixClone @('-SkipAuth', '-PathRegistryKey', $ixKey)
        Check 'install rerun reuses the clone' ($LASTEXITCODE -eq $okCode -and $out -match 'Using the existing clone' -and $out -notmatch '==> Cloning')

        $other = Join-Path $ix 'occupied'
        New-Item -ItemType Directory -Path $other | Out-Null
        Write-TextFile (Join-Path $other 'keep.txt') 'mine'
        $out = & $runInstall $other @()
        Check 'install refuses a non-empty folder' ($LASTEXITCODE -eq 1 -and $out -match 'is not a claude-config clone' -and (Test-Path (Join-Path $other 'keep.txt')))

        $partial = Join-Path $ix 'partial'
        New-Item -ItemType Directory -Path (Join-Path $partial '.git') -Force | Out-Null
        $out = & $runInstall $partial @()
        Check 'install reports an unreadable clone with git''s reason' ($LASTEXITCODE -eq 1 -and $out -match 'git cannot read the clone')

        $foreign = Join-Path $ix 'foreign'
        [void](Invoke-Exe -FilePath $realGit -Arguments @('clone', '-q', $src, $foreign))
        [void](Invoke-Exe -FilePath $realGit -Arguments @('-C', $foreign, 'remote', 'set-url', 'origin', 'https://example.com/someone-else/repo.git'))
        $out = & $runInstall $foreign @()
        Check 'install refuses a clone of another repository' ($LASTEXITCODE -eq 1 -and $out -match 'is a clone of' -and $out -notmatch 'Running ')

        $out = & $runInstall $ixClone @('-NoInstall', '-SkipAuth', '-PathRegistryKey', $ixKey)
        Check 'install passes -NoInstall on to setup' ($out -match 'setup.cmd.*-NoInstall')
    } finally {
        Remove-Item -LiteralPath (Split-Path -Parent $ixKey) -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    $script:failed++
    Write-Host "  [FAIL] unexpected error: $($_.Exception.Message)`n$($_.ScriptStackTrace)" -ForegroundColor Red
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "PowerShell $($PSVersionTable.PSVersion): $($script:passed) passed, $($script:failed) failed"
exit $script:failed
