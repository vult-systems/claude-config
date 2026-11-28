<#
.SYNOPSIS
    Validate the repository content and, unless -RepoOnly, this workstation's installation.

.DESCRIPTION
    Repository checks (also run in CI):
      - every expected skill exists with matching name and a description
      - agents have a name and description
      - JSON parses; PowerShell scripts parse and are ASCII-only
      - shared settings grant no permissions and hold no credentials
      - no credentials, tokens, private keys, history files, user-specific paths
        or personal email addresses

    Workstation checks: required tools and Claude Code version, sign-in state,
    installed files match the repo, and settings.json holds the shared values.

    Exit code 0 = no failures (warnings allowed), 1 = failures,
    2 = warnings when -Strict is given.

.PARAMETER RepoOnly
    Check the repository content only (used by CI).

.PARAMETER SkipTools
    Skip the tool and sign-in checks (setup.ps1 or bootstrap.ps1 has just run them).

.PARAMETER Strict
    Exit with code 2 when there are warnings but no failures.
#>
[CmdletBinding()]
param(
    [switch]$RepoOnly,
    [switch]$SkipTools,
    [switch]$Strict
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ClaudeConfig.psm1') -Force

$repo = Get-RepoRoot
$sourceDir = Join-Path $repo 'claude'
$script:failures = 0
$script:warnings = 0
function Fail([string]$m) { Write-CcFail $m; $script:failures++ }
function Warn([string]$m) { Write-CcWarn $m; $script:warnings++ }

$expectedSkills = @('vult-fast', 'vult-dev', 'vult-prod', 'init-project', 'production-audit', 'issue', 'hotfix', 'vult-ship',
    'release-candidate', 'promote-stable', 'handoff', 'resume-project')

# Built-in Claude Code command names and aliases a skill must not reuse, or one
# of them may shadow the other (#3). Collected on Claude Code 2.1.332 from a
# headless session's command list and the binary's command registrations
# (e.g. ship-local registers the alias "ship"). Extend when re-validating.
$reservedNames = @(
    'add-dir', 'advisor', 'agents', 'autocompact', 'batch', 'bug', 'clear', 'code-review',
    'color', 'compact', 'config', 'context', 'cost', 'debug', 'deep-research', 'design',
    'doctor', 'effort', 'exit', 'export', 'fast', 'feedback', 'focus', 'goal', 'help',
    'hooks', 'ide', 'import', 'init', 'insights', 'install-github-app', 'login', 'logout',
    'loop', 'mcp', 'memory', 'model', 'output-style', 'permissions', 'plan', 'plugin',
    'pr-comments', 'recap', 'release-notes', 'reload-plugins', 'reload-skills', 'rename',
    'resume', 'review', 'rewind', 'run', 'schedule', 'security-review', 'ship', 'ship-local',
    'simplify', 'skill-doctor', 'statusline', 'status', 'steward', 'tasks', 'theme',
    'ultrareview', 'update-config', 'upgrade', 'usage', 'verify', 'vim')

function Get-Frontmatter([string]$Path) {
    $lines = (ConvertTo-Lf (Read-TextFile $Path)) -split "`n"
    $fm = @{}
    if ($lines.Count -lt 3 -or $lines[0] -ne '---') { return $null }
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq '---') { return $fm }
        $m = [regex]::Match($lines[$i], '^([A-Za-z0-9_-]+):\s*(.*)$')
        if ($m.Success) { $fm[$m.Groups[1].Value] = $m.Groups[2].Value.Trim().Trim('"') }
    }
    return $null
}

function Get-RepoFiles {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $r = Invoke-Git -RepoRoot $repo -Arguments @('ls-files', '--cached', '--others', '--exclude-standard')
        if ($r.Code -eq 0) {
            return @($r.Output | Where-Object { $_ } | ForEach-Object { Join-Path $repo $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
        }
    }
    return @(Get-ChildItem -LiteralPath $repo -Recurse -File -Force |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } | ForEach-Object { $_.FullName })
}

# ------------------------------------------------------------------ repository
Write-CcStep "Repository content ($repo)"

foreach ($f in @('VERSION', 'CHANGELOG.md', 'README.md', 'claude/CLAUDE.md', 'claude/settings.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $repo (ConvertTo-NativeRel $f)))) { Fail "missing $f" }
}
$version = Get-RepoVersion $repo
if ($version -notmatch '^\d+\.\d+\.\d+(-rc\.\d+)?$') { Fail "VERSION '$version' is not X.Y.Z or X.Y.Z-rc.N" }
elseif (-not (Select-String -LiteralPath (Join-Path $repo 'CHANGELOG.md') -SimpleMatch "## v$version" -Quiet)) {
    Fail "CHANGELOG.md has no '## v$version' section"
}

$skillsDir = Join-Path $sourceDir 'skills'
foreach ($s in $expectedSkills) {
    if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $skillsDir $s) 'SKILL.md'))) { Fail "skill $s is missing" }
}
foreach ($dir in @(Get-ChildItem -LiteralPath $skillsDir -Directory)) {
    $p = Join-Path $dir.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $p)) { Fail "skills/$($dir.Name) has no SKILL.md"; continue }
    $fm = Get-Frontmatter $p
    if ($null -eq $fm) { Fail "skills/$($dir.Name)/SKILL.md has no frontmatter"; continue }
    if ($fm['name'] -ne $dir.Name) { Fail "skills/$($dir.Name): name '$($fm['name'])' does not match the folder" }
    if ($dir.Name -notmatch '^[a-z0-9-]{1,64}$') { Fail "skills/$($dir.Name): name must be lowercase letters, digits and hyphens" }
    if ($reservedNames -contains $dir.Name) { Fail "skills/$($dir.Name): conflicts with a built-in Claude Code command; rename it" }
    if (-not $fm['description']) { Fail "skills/$($dir.Name): description is empty" }
}
$agentsDir = Join-Path $sourceDir 'agents'
if (Test-Path -LiteralPath $agentsDir) {
    foreach ($a in @(Get-ChildItem -LiteralPath $agentsDir -Filter *.md -File)) {
        $fm = Get-Frontmatter $a.FullName
        if ($null -eq $fm -or -not $fm['name'] -or -not $fm['description']) { Fail "agents/$($a.Name) needs name and description frontmatter" }
    }
}

# Shared settings must not grant permissions or carry credentials.
try {
    $s = Read-JsonFile (Join-Path $sourceDir 'settings.json')
    if ($s.Contains('permissions')) {
        $perm = $s['permissions']
        if ($perm.Contains('allow') -and @($perm['allow']).Count -gt 0) { Fail 'settings.json: permissions.allow must stay empty; grant permissions per machine or per project' }
        if ($perm.Contains('defaultMode') -and @('default', 'plan') -notcontains $perm['defaultMode']) { Fail "settings.json: permissions.defaultMode '$($perm['defaultMode'])' is not allowed in shared settings" }
        if ($perm.Contains('additionalDirectories')) { Fail 'settings.json: additionalDirectories is machine-specific' }
    }
    foreach ($k in @('apiKeyHelper', 'awsAuthRefresh', 'awsCredentialExport', 'skipDangerousModePermissionPrompt', 'otelHeadersHelper')) {
        if ($s.Contains($k)) { Fail "settings.json: '$k' must not be in shared settings" }
    }
    if ($s.Contains('env')) {
        foreach ($k in @($s['env'].Keys)) { if ($k -match 'KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL') { Fail "settings.json: env.$k looks like a credential" } }
    }
    if ($s.Contains('hooks')) { Warn 'settings.json: hooks run commands on every workstation; review them carefully' }
} catch { Fail "claude/settings.json: $($_.Exception.Message)" }

$secretPatterns = @(
    'sk-ant-[A-Za-z0-9_-]{10,}',
    'gh[pousr]_[A-Za-z0-9]{20,}',
    'github_pat_[A-Za-z0-9_]{20,}',
    'AKIA[0-9A-Z]{16}',
    'xox[baprs]-[A-Za-z0-9-]{10,}',
    '-----BEGIN [A-Z ]*PRIVATE KEY-----',
    '"(accessToken|refreshToken|oauthAccount)"\s*:'
)
$pathPatterns = @('[A-Za-z]:\\Users\\', '/Users/[A-Za-z]', '/home/[A-Za-z]')
# Personal email addresses must not be published; noreply and example
# addresses (commit attribution, tests, docs) are fine.
$emailPattern = '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
# Allowed: noreply attribution, SSH remotes (git@host), RFC 2606 example and
# reserved names, and asset names like icon@2x.png.
$emailAllowed = '(?i)(@users\.noreply\.github\.com|^noreply@github\.com|^noreply@anthropic\.com|^git@.*|@([a-z0-9-]+\.)*example\.(com|org|net)|\.(example|invalid|test|localhost)|\.(png|jpe?g|gif|svg|webp|ico|bmp))$'
$forbiddenNames = '^(\.credentials\.json|settings\.local\.json|\.claude\.json|claude-config\.state\.json|\.env(\..*)?|.*\.jsonl|.*\.pem)$'
$user = $env:USERNAME
if (-not $user) { $user = $env:USER }

$files = Get-RepoFiles
foreach ($f in $files) {
    $rel = ConvertTo-PortableRel $f.Substring($repo.Length).TrimStart('\', '/')
    $leaf = Split-Path -Leaf $f
    if ($leaf -match $forbiddenNames) { Fail "$rel must not be committed (credentials, history or machine state)" }
    $bytes = [IO.File]::ReadAllBytes($f)
    if ($bytes -contains 0) { continue }
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    foreach ($p in $secretPatterns) { if ($text -match $p) { Fail "${rel}: matches secret pattern $p" } }
    foreach ($p in $pathPatterns) { if ($text -cmatch $p) { Fail "${rel}: contains a user-specific path ($p)" } }
    foreach ($m in [regex]::Matches($text, $emailPattern)) {
        if ($m.Value -notmatch $emailAllowed) {
            # Masked, so the address itself never lands in CI logs.
            Fail "${rel}: contains an email address ($($m.Value.Substring(0, 1))***@...); use a users.noreply.github.com or example.com address"
        }
    }
    if ($user -and $user.Length -ge 3 -and $text -match ('(?i)\b' + [regex]::Escape($user) + '\b')) {
        Fail "${rel}: contains the current username"
    }
    if ($leaf -match '\.json$') {
        try { [void](ConvertFrom-Json -InputObject $text) } catch { Fail "${rel}: invalid JSON" }
    }
    if ($leaf -match '\.ps(m?)1$') {
        if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) { Fail "${rel}: must be ASCII-only (Windows PowerShell 5.1)" }
        $tokens = $null; $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errors)
        foreach ($e in @($errors)) { Fail "${rel}:$($e.Extent.StartLineNumber): $($e.Message)" }
    }
}
if ($script:failures -eq 0) { Write-CcOk "$($files.Count) files checked, $($expectedSkills.Count) skills" }

# ------------------------------------------------------------------ workstation
if (-not $RepoOnly) {
    $claudeHome = Get-ClaudeHome
    if (-not $SkipTools) {
        Write-CcStep 'Tools'
        $tools = Test-Tools
        $script:failures += $tools.Missing
        $script:warnings += $tools.Warnings
        Write-CcStep 'Sign-in'
        $script:warnings += Test-Auth
    }

    Write-CcStep "Installation ($claudeHome)"
    $settingsPath = Join-Path $claudeHome 'settings.json'
    if (Test-Path -LiteralPath $settingsPath) {
        try { [void](Read-JsonFile $settingsPath) } catch { Fail "settings.json is not valid JSON: $($_.Exception.Message)" }
    }
    if ($null -eq (Read-State $claudeHome)) {
        Warn 'claude-config is not installed here. Run scripts/bootstrap.ps1'
    } else {
        $drift = Get-InstallDrift -RepoRoot $repo -ClaudeHome $claudeHome
        foreach ($d in $drift) {
            switch ($d.Status) {
                'missing' { Warn "$($d.Item) is not installed; run scripts/sync.ps1" }
                'outdated' { Warn "$($d.Item) is older than the repo; run scripts/sync.ps1" }
                'modified' { Warn "$($d.Item) was edited locally; run scripts/sync.ps1 -Capture to keep it, or -Force to discard it" }
            }
        }
        $okCount = @($drift | Where-Object { $_.Status -eq 'ok' }).Count
        Write-CcOk "$okCount of $($drift.Count) managed items match the repo"
        foreach ($n in (Get-SettingsDivergence -RepoRoot $repo -ClaudeHome $claudeHome)) { Warn $n }
    }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        $c = Invoke-Git -RepoRoot $repo -Arguments @('rev-list', '--left-right', '--count', 'HEAD...@{upstream}')
        if ($c.Code -eq 0) {
            $parts = ($c.Output | Select-Object -First 1) -split '\s+'
            if ([int]$parts[0] -gt 0) { Warn "repo has $($parts[0]) unpushed commit(s)" }
            if ([int]$parts[1] -gt 0) { Warn "repo is $($parts[1]) commit(s) behind its last fetch; run scripts/sync.ps1" }
        }
    }
}

Write-Host ''
if ($script:failures -gt 0) { Write-CcFail "$($script:failures) failure(s), $($script:warnings) warning(s)"; exit 1 }
if ($script:warnings -gt 0) {
    Write-CcWarn "Validation passed with $($script:warnings) warning(s)"
    if ($Strict) { exit 2 }
    exit 0
}
Write-CcOk 'Validation passed (0 warnings)'
exit 0
