# claude-config

Shared Claude Code configuration for my Windows workstations: global development standards, workflow skills, an agent and user settings, plus PowerShell scripts that install them at the user level and keep workstations in sync. They need no admin rights and are safe to rerun.

| Repo path | Installed to (`%USERPROFILE%\.claude`, or `$env:CLAUDE_CONFIG_DIR`) | How |
|---|---|---|
| `claude/CLAUDE.md` | `CLAUDE.md` | Managed block. Text outside the block is yours and is kept. |
| `claude/settings.json` | `settings.json` | 3-way merge. Your other keys and locally changed values are kept. |
| `claude/skills/` | `skills/` | Copied. Edited copies are detected and not overwritten. |
| `claude/agents/` | `agents/` | Copied, same rules as skills. |

Global standards apply to every project. Project-specific instructions (commands, design decisions, release steps, current state) stay in each repository's own `CLAUDE.md`, which takes precedence. `/init-project` creates one from a template.

## New workstation setup

Open **Windows PowerShell** as a standard user (not "Run as administrator").

```powershell
# 1. Tools. Skip any already installed. Machine-wide installers may ask for
#    elevation; if you can't elevate, ask IT rather than working around it.
winget install --id Git.Git -e --source winget
winget install --id GitHub.cli -e --source winget
winget install --id Microsoft.PowerShell -e --source winget   # optional
irm https://claude.ai/install.ps1 | iex                       # Claude Code (per-user, no admin)
```

Close the terminal and open a new one so `PATH` picks up the tools.

```powershell
# 2. Sign in (browser-based; nothing is stored in this repo)
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
git config --global user.name  "<your name>"
git config --global user.email "<your email>"
claude auth login

# 3. Clone next to your other repositories and bootstrap
$repos = 'C:\repos'   # wherever you keep repositories
New-Item -ItemType Directory -Force $repos | Out-Null
gh repo clone vult-systems/claude-config (Join-Path $repos 'claude-config')
powershell -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $repos 'claude-config\scripts\bootstrap.ps1')
```

Then start a new `claude` session and type `/` to see the skills.

`bootstrap.ps1` checks the tools and sign-in, backs up anything it replaces, installs, and validates. It never installs software, changes the execution policy, or grants permissions. `-ExecutionPolicy RemoteSigned` applies to that one process only; it can't override a Group Policy, and you shouldn't try to.

Options: `-DryRun` shows the changes without writing; `-Force` replaces managed files you edited locally, after backing them up.

## Authentication

| Tool | Sign in | Check | Credentials live in |
|---|---|---|---|
| GitHub CLI | `gh auth login --web` | `gh auth status` | Windows Credential Manager |
| git over HTTPS | `gh auth setup-git` | `git ls-remote https://github.com/vult-systems/claude-config` | via `gh` |
| Claude Code | `claude auth login` (or `/login` in a session) | `claude auth status` | your Claude home, outside this repo |

None of these are ever copied into the repository. `validate.ps1` fails if credential files, tokens, private keys or history files are committed.

## Synchronising workstations

```powershell
cd <repos>\claude-config
.\scripts\sync.ps1            # fast-forward from GitHub, then install
.\scripts\sync.ps1 -DryRun    # preview
.\scripts\validate.ps1        # tools, sign-in, and drift between the repo and ~/.claude
```

`sync.ps1` only fast-forwards. With uncommitted changes in the repo it installs your working tree without pulling. If the branch has diverged, it stops and asks you to resolve it.

**To change shared config**, edit the repo, then run `.\tests\Run-Tests.ps1` and `.\scripts\validate.ps1 -RepoOnly`. Commit (on a branch with a PR for anything non-trivial), push, and run `sync.ps1` on each workstation.

**Edited a skill or `CLAUDE.md` block directly in `~/.claude`?** Run `sync.ps1 -Capture` to copy those edits into the repo, review `git diff`, commit, push, then run `sync.ps1` to record the new baseline. Settings are not captured; edit `claude/settings.json` by hand.

**Per-machine settings** (a different theme, extra permissions) can be changed normally with `/config` or by editing `settings.json`. Sync keeps local values and reports the difference. Project permissions belong in each project's `.claude/settings.local.json`, which is never shared.

### Backups and restore

Every install that changes something first copies the old files to `~/.claude/backups/claude-config/<timestamp>/` (the newest 20 are kept).

```powershell
.\scripts\restore.ps1 -List
.\scripts\restore.ps1 -Latest          # or -Name <timestamp>
```

A restore also backs up the current state first, so it can be undone.

## Skills

| Skill | Purpose |
|---|---|
| `/init-project` | Add project CLAUDE.md, CHANGELOG, version source, .gitignore, CI and labels to a repository, without overwriting what exists. |
| `/production-audit` | Read-only audit against the standards; ranked findings with evidence. |
| `/issue` | Duplicate check, then a well-formed bug, enhancement, tech-debt or acceptance issue. |
| `/vult-ship` | Scope check, tests, focused commits, PR, green CI, merge commit, post-merge check. |
| `/hotfix` | Reproduction, regression test, minimal fix, PR, patch RC. |
| `/release-candidate` | Version bump and changelog via PR, `vX.Y.Z-rc.N` tag, draft pre-release, acceptance issue. |
| `/promote-stable` | Gate on acceptance and no code change since the RC, then tag `vX.Y.Z` and draft the release. |
| `/handoff` | Push the branch and post a structured handoff note on its draft PR. |
| `/resume-project` | Sync the branch, read CLAUDE.md, the latest handoff note and CI status, then summarise the next steps. |

The skills that push, merge, tag or release run only when you type them, and they confirm before each outward-facing step. The `production-reviewer` agent gives a read-only review of a diff or PR; `/vult-ship` uses it for non-trivial changes.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "running scripts is disabled on this system" | Use the `powershell -NoProfile -ExecutionPolicy RemoteSigned -File ...` form above. If it says the policy is set by Group Policy, ask IT. |
| `git`, `gh` or `claude` not found right after installing | Open a new terminal. For Claude Code, check that `%USERPROFILE%\.local\bin` is on `PATH`. |
| Claude Code on Windows complains about Git Bash | Install Git for Windows; Claude Code needs it. |
| `... was modified locally; left unchanged` | Keep it: `sync.ps1 -Capture`, then commit. Discard it: `sync.ps1 -Force` (backed up). |
| `settings.theme kept local value ...` | Informational: your local value differs from the repo. Change either side to match, or leave it. |
| `settings.json is not valid JSON` | Fix the file (or `restore.ps1 -Latest`), then rerun. Sync never rewrites a file it can't parse. |
| `Local branch has diverged from upstream` | In the repo, `git status` and `git log --oneline --graph --all -10`, resolve it, then rerun. |
| Skills don't show up | Start a new session. Run `validate.ps1`. Check `~/.claude/skills/<name>/SKILL.md` exists. |
| A skill name clashes with a built-in command | `validate.ps1` rejects names on its list of known built-ins (that's why the ship skill is `/vult-ship`). If a newer Claude Code adds a clashing command, rename the skill folder and its `name:`, and add the built-in name to `$reservedNames` in `validate.ps1`. |

## Repository maintenance

See [CLAUDE.md](CLAUDE.md) for commands, design decisions and the release process; [CHANGELOG.md](CHANGELOG.md) for history. Version: `VERSION`. CI runs `validate.ps1 -RepoOnly` and the tests on Windows PowerShell 5.1 and PowerShell 7.
