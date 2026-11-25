# CLAUDE.md

claude-config holds the shared Claude Code user configuration for all of my Windows workstations: global standards, skills, agents and settings, plus the PowerShell scripts that install and sync them. It is itself a production project, so the global standards apply.

## Commands

```
.\scripts\validate.ps1 -RepoOnly        # content checks, as CI runs them
.\tests\Run-Tests.ps1                   # regression tests; run in BOTH powershell.exe and pwsh
.\scripts\validate.ps1                  # plus this workstation's tools, sign-in and install drift
.\scripts\sync.ps1 -DryRun              # what an install would change here
```

Tests use a temporary Claude home; they never touch the real `~/.claude`.

## Layout

- `claude/` mirrors the Claude Code user directory: `CLAUDE.md` (installed as a managed block), `settings.json` (3-way merged), `skills/`, `agents/`.
- `scripts/ClaudeConfig.psm1` has all the logic; `bootstrap.ps1`, `sync.ps1`, `validate.ps1` and `restore.ps1` are thin entry points.

## Design decisions to preserve

- **Standard user only.** No admin, no execution-policy changes, no software installs. Missing tools are reported with install commands.
- **Copy, don't link.** Symlinks need admin or Developer Mode. Installed file hashes go in `claude-config.state.json` in the Claude home, so local edits are detected and never silently overwritten.
- **Preserve local configuration.** Text outside the `CLAUDE.md` managed block, settings keys outside the repo, and locally changed values are kept. Everything replaced is backed up first.
- **Windows PowerShell 5.1 compatible.** A fresh machine has no pwsh. Keep scripts ASCII-only and write UTF-8 without a BOM. Avoid PS 7-only syntax (`??`, ternaries, `-AsHashtable`, `Join-Path` with more than one child path).
- **Shared settings grant nothing.** No `permissions.allow`, permissive `defaultMode`, credentials or machine paths. `validate.ps1` enforces this.
- **Global vs project.** `claude/CLAUDE.md` holds standards that apply to every project. Project specifics belong in each repo's own `CLAUDE.md`, which is never managed from here.

## Changes

- Skills stay concise and procedural. A skill that pushes, merges, tags or releases has `disable-model-invocation: true` and confirms before outward-facing steps.
- Adding or renaming a skill: update `$expectedSkills` in `validate.ps1`, the README table and the list in `claude/CLAUDE.md`. Names must not match a built-in Claude Code command or alias (`$reservedNames` in `validate.ps1`); prefer the `vult-` prefix for generic verbs. When re-validating on a newer Claude Code, check for new built-ins: compare the `slash_commands` in a headless `--output-format stream-json --verbose` init event, and search the binary for `aliases:[` and `name:"<skill>"`.
- Version in `VERSION`; `CHANGELOG.md` section `## vX.Y.Z` must match it (validate checks).
- After changing the scripts, run the tests in both PowerShell editions.
- Tested against Claude Code `2.1.332` (`$TestedClaudeVersion` in the module). Bump it after re-validating on a newer version.

## Current state

- **v1.0.0-rc.1**: validated on one workstation. Before promoting to v1.0.0, it needs a fresh-workstation bootstrap and a two-workstation sync round trip (see the acceptance issue).
