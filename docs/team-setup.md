# Team setup

Fork the repository to make it your team's shared configuration.

## Point onboarding at your fork

Change the `$Repository` default in `install.ps1`, and the `vult-systems/claude-config` URLs in the [README](../README.md) (the `curl.exe` line) and in [Installation](installation.md) (the `git clone` example and the sign-in table).

Users of a private fork can't download `install.ps1` anonymously. They clone with `git clone <your fork URL>` instead (Git opens the browser to sign in) and run `setup.cmd`.

## Change the content

- `claude/CLAUDE.md`: the global standards
- `claude/skills/` and `claude/agents/`: skills and agents
- `claude/settings.json`: shared settings

Keep shared settings to safeguards. `validate.ps1` rejects permission grants, credentials, machine paths and personal email addresses.

## Rename a skill

For example, to give `/vult-ship` your team's prefix:

1. Rename the skill folder and the `name:` in its `SKILL.md`.
2. Update `$expectedSkills` in `scripts/validate.ps1`, the skill tables in the README and the skill list in `claude/CLAUDE.md`. `validate.ps1` checks the last two.
3. Make sure the name doesn't match a built-in Claude Code command (`$reservedNames` in `validate.ps1`).

On the next `sync.ps1`, installed copies move to the new name unless they were edited locally.

## Roll out

Run `.\tests\Run-Tests.ps1` and `.\scripts\validate.ps1 -RepoOnly`, merge, then run `sync.ps1` on each workstation.
