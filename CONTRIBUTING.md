# Contributing

Thanks for helping. This repository is configuration plus PowerShell scripts that run on other people's workstations, so changes are small, tested and reviewed.

## Before you start

- **Search the issues** first. Open one for a bug (steps to reproduce, expected and actual results, Windows and PowerShell versions) or a proposal before a large change.
- **Security problems** go through [SECURITY.md](SECURITY.md), not public issues.
- Read [CLAUDE.md](CLAUDE.md). Its design decisions are requirements: standard user only, Windows PowerShell 5.1 compatible, ASCII-only scripts, UTF-8 without BOM, preserve local configuration, shared settings grant nothing, idempotent setup.

## Workflow

1. Fork, then create a branch from `main`.
2. Keep each commit to one concern, explain what and why, and reference the issue with `Refs #N`.
3. Add or update tests in `tests/Run-Tests.ps1`. A bug fix gets a regression test that fails without the fix. Tests use temporary folders, fake tool shims and a scratch registry key; they must never touch the real `~/.claude`, user `PATH` or installed tools.
4. Run both checks in **both** PowerShell editions:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -RepoOnly
   powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
   pwsh -NoProfile -File .\tests\Run-Tests.ps1
   ```
5. Update the docs in the same change: `README.md` (kept short: quick start, modes, skills), the page in `docs/` that covers the topic, `CHANGELOG.md` (under `## Unreleased`: Added / Changed / Fixed / Removed / Security) and `CLAUDE.md` where relevant.
6. Open a pull request that references the issue and says how you tested it, including anything you couldn't test (real installs, a fresh workstation, managed machines). CI must be green. Maintainers merge with a merge commit.

## Your identity and data

- Commit with your own Git identity. A GitHub noreply address (`<id>+<login>@users.noreply.github.com`, shown under GitHub email settings) keeps your email out of public history.
- Never commit credentials, tokens, `.env` files, conversation history, `settings.local.json`, machine paths or personal email addresses. `validate.ps1` checks for these, but review your diff too.

## Adding or renaming a skill

Follow the checklist under "Changes" in [CLAUDE.md](CLAUDE.md): update `$expectedSkills` in `scripts/validate.ps1`, the README skill tables and the list in `claude/CLAUDE.md`. Names must not clash with built-in Claude Code commands. Skills that push, merge, tag or release need `disable-model-invocation: true` and must confirm before outward-facing steps.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
