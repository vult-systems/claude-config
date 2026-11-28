# Changelog

Notable changes, newest first. Versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

### Fixed

- `validate.ps1`, `bootstrap.ps1` and `setup` could report "Claude Code not signed in" while it was signed in, for example right after `claude update`. The check parsed all of `claude auth status` output, stderr included, as one JSON document, so any extra line made it fail. It now passes `--json`, reads stdout only and finds the JSON object in it. A check that fails or can't be read is reported as "Could not check Claude Code sign-in" with the error, separately from a real signed-out state, and setup no longer offers a browser sign-in in that case. (#12)

## v1.0.0-rc.2

### Added

- `setup.cmd` / `scripts/setup.ps1`: one-step, rerunnable workstation setup. Each step checks first and does only what's missing: it installs Git, GitHub CLI and native Claude Code per user without admin rights (asking first), keeps `PATH` up to date for the user and the running session, signs in to GitHub and Claude and sets the git identity only when needed, then installs the configuration and validates. It runs from Command Prompt, Windows Terminal or PowerShell on Windows PowerShell 5.1 or PowerShell 7. (#6)
- `install.ps1`: a fresh-workstation installer to download, read, then run from Windows PowerShell or Command Prompt. It installs Git for the user if missing, clones (or reuses a clone), and runs `setup.cmd`. It never overwrites a folder and is safe to rerun. (#8)
- Detection of Claude Code installed with WinGet or npm alongside the native install. `validate.ps1` warns about it, and `setup` removes it only after you confirm. (#6)
- `validate.ps1` rejects personal email addresses in repository content (noreply and `example.com` addresses are allowed), and masks the address in its output. (#8)
- MIT `LICENSE`, `CONTRIBUTING.md` and `SECURITY.md`. The README explains how a team forks and customizes the repository, including renaming `/vult-ship`. (#8)

### Changed

- New-workstation setup is now download, review, run with `install.ps1` from Windows PowerShell or Command Prompt, replacing the manual install, sign-in, clone and bootstrap steps. (#6, #8)
- Shared settings now hold only the security safeguards (the `.env`/`*.pem`/`~/.ssh` deny list). `model`, `theme` and `tui` are no longer shared, so new installs use Claude Code's defaults. Workstations that already have them keep their current values: when the repo stops sharing a preference, sync keeps your value instead of resetting it. (#8)

### Fixed

- Install and validate failed with "The term 'Get-FileHash' is not recognized" when Windows PowerShell 5.1 was started from a PowerShell 7 session, because 5.1 inherited PowerShell 7's `PSModulePath`. Files are now hashed with .NET directly, and `setup.cmd` clears the inherited path. (#6)
- `validate.ps1` now counts every warning it prints. The tool check printed warnings that were left out of the summary, so it could say "0 warning(s)" under visible warnings. A missing PowerShell 7 or winget is now information, since both are optional. `validate.ps1 -Strict` exits 2 on warnings, and `bootstrap.ps1` uses it, so it no longer reports "Done" after warnings. (#5)

## v1.0.0-rc.1

### Added

- Global development standards (`claude/CLAUDE.md`), installed as a managed block in the user `CLAUDE.md`, so existing text outside the block is kept.
- Shared user settings, 3-way merged into `settings.json`. Local keys and locally changed values are kept, and the settings grant no permissions; they only deny reads of `.env`, `*.pem` and `~/.ssh`.
- Skills: `/init-project`, `/production-audit`, `/issue`, `/hotfix`, `/vult-ship`, `/release-candidate`, `/promote-stable`, `/handoff`, `/resume-project`.
- Agent: `production-reviewer`, a read-only reviewer for diffs and PRs.
- Non-admin scripts: `bootstrap.ps1` (tool and sign-in checks, install, validate), `sync.ps1` (fast-forward pull and install, or `-Capture` local edits back into the repo), `validate.ps1` (content, security and drift checks), `restore.ps1` (list and restore timestamped backups).
- Regression tests for install, merge, drift, removal, dry run, restore and capture, run on Windows PowerShell 5.1 and PowerShell 7 in CI.
