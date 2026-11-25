# Changelog

Notable changes, newest first. Versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Fixed

- `validate.ps1` now counts every warning it prints. The tool check printed warnings that were left out of the summary, so it could say "0 warning(s)" under visible warnings. A missing PowerShell 7 or winget is now information, since both are optional. `validate.ps1 -Strict` exits 2 on warnings, and `bootstrap.ps1` uses it, so it no longer reports "Done" after warnings. (#5)

## v1.0.0-rc.1

### Added

- Global development standards (`claude/CLAUDE.md`), installed as a managed block in the user `CLAUDE.md`, so existing text outside the block is kept.
- Shared user settings, 3-way merged into `settings.json`. Local keys and locally changed values are kept, and the settings grant no permissions; they only deny reads of `.env`, `*.pem` and `~/.ssh`.
- Skills: `/init-project`, `/production-audit`, `/issue`, `/hotfix`, `/vult-ship`, `/release-candidate`, `/promote-stable`, `/handoff`, `/resume-project`.
- Agent: `production-reviewer`, a read-only reviewer for diffs and PRs.
- Non-admin scripts: `bootstrap.ps1` (tool and sign-in checks, install, validate), `sync.ps1` (fast-forward pull and install, or `-Capture` local edits back into the repo), `validate.ps1` (content, security and drift checks), `restore.ps1` (list and restore timestamped backups).
- Regression tests for install, merge, drift, removal, dry run, restore and capture, run on Windows PowerShell 5.1 and PowerShell 7 in CI.
