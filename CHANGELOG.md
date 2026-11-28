# Changelog

Notable changes, newest first. Versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

## v1.0.0-rc.5

Proportional standards, by owner decision during the v1.0.0 freeze. The freeze applies again from this release.

### Changed

- Shared standards scale process with risk, scope and impact. Each mode has a clear level of planning, validation, issues, docs, review and a soft time budget, and validation follows what changed: docs edits get docs checks, not the full test suite. Fast and dev mode no longer need plan approval for routine, reversible work, and fast mode no longer keeps a list of deferred housekeeping. The managed `CLAUDE.md` is shorter and drops rules that duplicated or contradicted each other. (#22)
- `/vult-ship` works at the current mode instead of applying full production standards to everything. It keeps working commit history, reuses validation already run on the final change, merges once required checks pass without a second confirmation, and deletes the merged branch. (#22)
- Releases: release candidates and acceptance checklists are for releases that need real-environment checks. `/promote-stable X.Y.Z` releases the default branch directly, and both release skills skip their release PR when the version and changelog were already bumped in the work's PR. `/hotfix` ships a patch release directly unless the fix needs field checks. (#22)
- `/issue` steers related work into one issue with a checklist; `/production-audit`, `production-reviewer` and `/init-project` judge in proportion to the project's risk. `/init-project` proposes fewer labels and a change-aware CI workflow from a new `templates/ci.yml`. (#22)
- CI runs on pull requests, pushes to `main` and manual dispatch instead of every branch push plus the PR. Docs-only pull requests skip the regression tests, the two PowerShell editions test in parallel, and pushes to `main` re-check content only. The required `validate` check is now an always-running gate job, so skipped tests never leave it pending. (#22)
- The README is now a short landing page: quick setup, everyday commands, modes and the skills grouped by purpose with examples. Installation options, sign-in, configuration and sync, troubleshooting and team setup moved to pages under `docs/`. Documentation only.

## v1.0.0-rc.4

The one feature added during the v1.0.0 freeze, by owner decision. The freeze applies again from this release.

### Added

- Session modes: `/vult-fast` (direct implementation on a local experimental branch, smoke tests, housekeeping deferred), `/vult-dev` (the default) and `/vult-prod` (all production standards). The global `CLAUDE.md` lists the rules that hold in every mode, and `/vult-ship` brings experimental work up to the full standards before it reaches the default branch. (#16)
- Mode-aware planning in the shared standards: fast mode implements directly, development mode plans non-trivial work when needed, production mode plans before every multi-file or non-trivial edit. Personal preferences outside the managed block may adjust this but don't relax the rules that hold in every mode. (#16)
- `validate.ps1` requires mode skills to be user-invoked only (`disable-model-invocation: true`) and every shipped skill to be listed in `claude/CLAUDE.md` and the README skill table. (#16)

## v1.0.0-rc.3

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
