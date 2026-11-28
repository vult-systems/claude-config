# CLAUDE.md

claude-config holds shared Claude Code user configuration for Windows workstations (global standards, skills, agents and security settings) plus the PowerShell scripts that install and sync them. It's public (MIT) and meant to be used as is or forked by teams. The global standards apply. It changes other people's workstations, so script changes get dev-mode validation at least.

## Commands

```
.\setup.cmd                             # full workstation setup (tools, PATH, sign-in, install, validate); -DryRun to preview
.\scripts\validate.ps1 -RepoOnly        # content checks, as CI runs them
.\tests\Run-Tests.ps1                   # regression tests; locally in powershell.exe, CI also runs pwsh
.\scripts\validate.ps1                  # plus this workstation's tools, sign-in and install drift
.\scripts\sync.ps1 -DryRun              # what an install would change here
```

Tests use a temporary Claude home, fake tool shims and a scratch HKCU key; they never touch the real `~/.claude`, user PATH or installed tools.

CI (`.github/workflows/ci.yml`) runs on pull requests, pushes to `main` and manual dispatch. Every run validates content. The tests run on both editions in parallel only for pull requests that change more than `docs/`, root `*.md`, `LICENSE` or `VERSION`, and on manual runs. The always-running `validate` job is the required check.

## Layout

- `claude/` mirrors the Claude Code user directory: `CLAUDE.md` (installed as a managed block), `settings.json` (3-way merged), `skills/`, `agents/`.
- `install.ps1` at the root is the self-contained fresh-workstation entry point: users download and read it, and it gets Git, clones, and runs `setup.cmd`. Keep it short, readable and free of module dependencies.
- `README.md` is a short landing page (quick setup, everyday commands, modes, skill tables). Details live in `docs/`, one topic per page: installation, configuration, skills, troubleshooting, team-setup.
- `scripts/ClaudeConfig.psm1` has the shared logic; `setup.ps1` (onboarding flow), `bootstrap.ps1` (configuration only), `sync.ps1`, `validate.ps1` and `restore.ps1` are entry points. `setup.cmd` at the root launches `setup.ps1` with Windows PowerShell 5.1 from any shell.

## Design decisions to preserve

- **Standard user only.** No admin, no elevation, no execution-policy changes, no machine PATH edits. Only `setup.ps1` installs software: per-user (`winget --scope user`, the native Claude Code installer), after asking. Other scripts report missing tools with install commands.
- **Native Claude Code.** WinGet/npm copies are detected and removed only after an explicit default-No confirmation (never under `-Yes` or `-NonInteractive`).
- **Idempotent setup.** Every `setup.ps1` step checks state before acting, so reruns and interrupted runs need no saved progress. Keep it that way rather than adding a progress file.
- **Copy, don't link.** Symlinks need admin or Developer Mode. Installed file hashes go in `claude-config.state.json` in the Claude home, so local edits are detected and never silently overwritten.
- **Preserve local configuration.** Text outside the `CLAUDE.md` managed block, settings keys outside the repo, and locally changed values are kept. Everything replaced is backed up first.
- **Windows PowerShell 5.1 compatible.** A fresh machine has no pwsh. Keep scripts ASCII-only and write UTF-8 without a BOM. Avoid PS 7-only syntax (`??`, ternaries, `-AsHashtable`, `Join-Path` with more than one child path). Avoid cmdlets that 5.1 loads from script modules (e.g. `Get-FileHash`): 5.1 started from a pwsh session inherits pwsh's `PSModulePath` and can't load them.
- **Shared settings grant nothing.** No `permissions.allow`, permissive `defaultMode`, credentials or machine paths. `validate.ps1` enforces this.
- **Shared settings are safeguards only.** Model, theme, layout and other preferences stay personal. When a top-level scalar key leaves the repo, the merge keeps each workstation's value instead of resetting it. Removed lists, objects and nested values (policy, e.g. under `permissions`) are retired if unchanged locally.
- **Public by design.** No personal data, usernames, machine paths or personal email addresses in content (`validate.ps1` checks). Git history is never rewritten: commits before the switch to public carry the account's commit email, kept by owner decision (#8); later commits use a GitHub noreply address. Org-specific values are limited to the repository URL and the `/vult-ship` name, which forks change (`docs/team-setup.md`).
- **Global vs project.** `claude/CLAUDE.md` holds standards that apply to every project. Project specifics belong in each repo's own `CLAUDE.md`, which is never managed from here.

## Changes

- Skills stay concise and procedural. A skill that pushes, merges, tags or releases has `disable-model-invocation: true`. Typing it approves its normal scoped steps; it confirms before tags, releases and anything outside its scope.
- Adding or renaming a skill: update `$expectedSkills` in `validate.ps1`, the README skill tables and the list in `claude/CLAUDE.md` (validate checks the last two). Mode skills also go in `$modeSkills` and must keep `disable-model-invocation: true`. Names must not match a built-in Claude Code command or alias (`$reservedNames` in `validate.ps1`); prefer the `vult-` prefix for generic verbs. When re-validating on a newer Claude Code, check for new built-ins: compare the `slash_commands` in a headless `--output-format stream-json --verbose` init event, and search the binary for `aliases:[` and `name:"<skill>"`.
- Version in `VERSION`; `CHANGELOG.md` section `## vX.Y.Z` must match it (validate checks).
- After changing the scripts, run the tests in Windows PowerShell 5.1; CI covers PowerShell 7. Docs-only changes need only `validate.ps1 -RepoOnly`.
- Tested against Claude Code `2.1.332` (`$TestedClaudeVersion` in the module). Bump it after re-validating on a newer version.

## Current state

- **v1.0.0-rc.5**: proportional standards (#22). Modes scale process with risk and `/vult-ship` works at the current mode; release candidates and acceptance are optional for routine releases; CI is change-aware. The v1.0.0 freeze was reopened for this revision by owner decision. Also ships the README restructure (#20).
- **v1.0.0-rc.4** (`7f65486`): session modes (#16). **rc.3** (`6f73223`): the #12 sign-in fix. **rc.2** (`4004607`): public repository and onboarding. rc.1 was never tagged.
- **Feature freeze** until v1.0.0, reinstated after rc.5: no new features. Only fixes for acceptance failures (each with an issue and a regression test) and docs. A fix ships as a new RC, and the acceptance checklist is rerun against it. v1.0.0 is the accepted RC's code with only the version and changelog changed.
- Next step: run the acceptance issue (#2) on real workstations against rc.5, including fresh-workstation onboarding and a two-workstation sync round trip. #5, #6, #8, #12, #16 and #22 stay open until #2 verifies them (#12 needs a real `claude update`).
- Repository settings: `main` protected (PR required with 0 approvals, `validate` check required, conversations resolved, no force-push or deletion), merged branches auto-deleted, private vulnerability reporting enabled (SECURITY.md).