# Configuration and sync

## What gets installed

Files go to your Claude home: `%USERPROFILE%\.claude`, or `$env:CLAUDE_CONFIG_DIR` if set.

| Repo path | Installed to | How |
|---|---|---|
| `claude/CLAUDE.md` | `CLAUDE.md` | Managed block. Text outside the block is yours and is kept. |
| `claude/settings.json` | `settings.json` | 3-way merge of the shared security safeguards (a deny list for `.env`, `*.pem` and `~/.ssh`). Your other keys and locally changed values are kept. |
| `claude/skills/` | `skills/` | Copied. Edited copies are detected and not overwritten. |
| `claude/agents/` | `agents/` | Copied, same rules as skills. |

Files are copied, not linked, and their hashes are recorded so local edits are detected. The global standards in `CLAUDE.md` apply to every project. Project-specific instructions (commands, design decisions, release steps, current state) belong in each repository's own `CLAUDE.md`, which takes precedence and is never managed from here. `/init-project` creates one from a template.

## Personal settings

Model, theme, layout and extra permissions aren't shared. New installs use Claude Code's defaults, and you choose yours with `/config` or by editing `settings.json`. Sync keeps local values, and when the repo stops sharing a preference, your current value stays. Project permissions belong in each project's `.claude/settings.local.json`, which is never shared.

## Syncing workstations

```powershell
.\scripts\sync.ps1            # fast-forward from GitHub, then install
.\scripts\sync.ps1 -DryRun    # preview
.\scripts\sync.ps1 -NoPull    # install the working tree without fetching
.\scripts\validate.ps1        # tools, sign-in, and drift between the repo and your Claude home
```

`sync.ps1` only fast-forwards. With uncommitted changes in the repo, it installs your working tree without pulling. If the branch has diverged, it stops and asks you to resolve it.

`validate.ps1` exits 1 on failures. With `-Strict` it also exits 2 when there are warnings. `-RepoOnly` checks the repository content only, as CI does.

## Changing shared configuration

Edit the repo, then run `.\tests\Run-Tests.ps1` and `.\scripts\validate.ps1 -RepoOnly`. Commit (on a branch with a PR for anything non-trivial), push, and run `sync.ps1` on each workstation.

If you edited a skill or the `CLAUDE.md` managed block directly in your Claude home, run `sync.ps1 -Capture` to copy those edits into the repo, review `git diff`, commit and push, then run `sync.ps1` to record the new baseline. Settings are not captured: edit `claude/settings.json` by hand.

To discard a local edit and take the repo version instead, run `sync.ps1 -Force`. The edited file is backed up first.

## Backups and restore

Every install that changes something first copies the old files to `backups\claude-config\<timestamp>\` in your Claude home. The newest 20 are kept.

```powershell
.\scripts\restore.ps1 -List
.\scripts\restore.ps1 -Latest          # or -Name <timestamp>
```

A restore backs up the current state first, so it can be undone.
