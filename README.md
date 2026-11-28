# claude-config

Shared Claude Code configuration for Windows workstations: global development standards, workflow skills, a review agent and security-focused user settings, plus PowerShell scripts that install them at the user level and keep workstations in sync. Use it as is, or fork it as your team's shared configuration. The scripts need no admin rights and are safe to rerun.

| Repo path | Installed to (`%USERPROFILE%\.claude`, or `$env:CLAUDE_CONFIG_DIR`) | How |
|---|---|---|
| `claude/CLAUDE.md` | `CLAUDE.md` | Managed block. Text outside the block is yours and is kept. |
| `claude/settings.json` | `settings.json` | 3-way merge of the shared security safeguards (a deny list for `.env`, `*.pem` and `~/.ssh`). Your other keys and locally changed values are kept. |
| `claude/skills/` | `skills/` | Copied. Edited copies are detected and not overwritten. |
| `claude/agents/` | `agents/` | Copied, same rules as skills. |

Global standards apply to every project. Project-specific instructions (commands, design decisions, release steps, current state) stay in each repository's own `CLAUDE.md`, which takes precedence. `/init-project` creates one from a template.

## New workstation setup

Open **Windows PowerShell** or **Command Prompt** as yourself (not "Run as administrator"). Download the installer, read it, then run it. The same three commands work in both shells:

```bat
curl.exe -fsSLo install.ps1 https://raw.githubusercontent.com/vult-systems/claude-config/main/install.ps1
notepad install.ps1
powershell -NoProfile -ExecutionPolicy RemoteSigned -File install.ps1
```

`install.ps1` is short and needs nothing preinstalled (`curl.exe` ships with Windows 10 and 11). It:

1. Uses Git if it's present, or offers to install Git for Windows for your user only.
2. Clones this repository to `%USERPROFILE%\repos\claude-config` (`-Path <folder>` to choose another), or reuses an existing clone. It never overwrites a folder.
3. Runs `setup.cmd` from the clone, which asks before installing or removing anything.

Running it again is safe. Add `-DryRun` to see what it would do without changing anything. To review the whole repository first, clone it yourself (`git clone https://github.com/vult-systems/claude-config`) and run `setup.cmd` from the clone.

**Already have the repo?** Run `setup.cmd` from its folder, in Command Prompt, Windows Terminal or PowerShell.

`setup.cmd` runs `scripts\setup.ps1` with Windows PowerShell 5.1. It checks the current state at each step and does only what's missing:

1. **Tools**: offers to install Git for Windows and GitHub CLI for your user (`winget --scope user`, no admin rights), and Claude Code with the official native installer. If winget isn't set up yet on a new Windows profile, it registers App Installer for your user first.
2. **One Claude Code**: standardizes on the native install, which updates itself. A copy installed with WinGet or npm shadows it on `PATH` and goes stale. Setup offers to remove that copy, and removes nothing unless you answer yes (default No).
3. **PATH**: adds `%USERPROFILE%\.local\bin` to your user `PATH` if needed and refreshes the running session. Setup never edits the machine `PATH`.
4. **Sign-in**, only where needed: GitHub CLI (browser), git credentials (`gh auth setup-git`, offered only if git can't already reach GitHub), git `user.name`/`user.email` (use your own; setup suggests your GitHub name and your private `...@users.noreply.github.com` address, which keeps your email out of public commit history), and Claude Code (browser).
5. **Configuration**: backs up anything it replaces, installs, and validates, the same as `bootstrap.ps1`.

If setup is interrupted or a step fails, fix the problem and run it again; finished steps are skipped. It exits 0 when done, 1 when something still needs fixing, and 2 when it finished with warnings. When it's done, open a new terminal, start `claude`, and type `/` to see the skills.

Options (pass them to `setup.cmd` or `setup.ps1`): `-DryRun` shows what would happen; `-NoInstall` only reports: it installs and removes no software and leaves `PATH` alone; `-SkipAuth` skips sign-in; `-NonInteractive` never prompts and prints the commands to run instead; `-Yes` accepts install and sign-in prompts (removals still ask); `-Force` replaces managed files you edited locally, after backing them up.

Setup never elevates, changes the execution policy or grants permissions. `-ExecutionPolicy RemoteSigned` in `setup.cmd` applies to that one process only. It can't override a Group Policy, and you shouldn't try to. PowerShell 7 is optional: everything runs on Windows PowerShell 5.1.

`scripts\bootstrap.ps1` is still there for configuration only. It checks tools and sign-in without installing or prompting, installs the configuration and validates.

## Authentication

| Tool | Sign in | Check | Credentials live in |
|---|---|---|---|
| GitHub CLI | `gh auth login --web` | `gh auth status` | Windows Credential Manager |
| git over HTTPS | Git Credential Manager (browser, on first clone) or `gh auth setup-git` | `git ls-remote https://github.com/vult-systems/claude-config` | Windows Credential Manager |
| Claude Code | `claude auth login` (or `/login` in a session) | `claude auth status` | your Claude home, outside this repo |

`setup.cmd` runs each sign-in only if it's missing. If `claude auth status` fails or prints something setup can't read, setup and `validate.ps1` warn "Could not check Claude Code sign-in" with the error, and setup doesn't start a sign-in. Run `claude auth status` to see the full output. None of these are ever copied into the repository. `validate.ps1` fails if credential files, tokens, private keys or history files are committed.

## Synchronising workstations

```powershell
cd <repos>\claude-config
.\scripts\sync.ps1            # fast-forward from GitHub, then install
.\scripts\sync.ps1 -DryRun    # preview
.\scripts\validate.ps1        # tools, sign-in, and drift between the repo and ~/.claude
```

`validate.ps1` exits 1 on failures. With `-Strict`, it also exits 2 when there are warnings.

`sync.ps1` only fast-forwards. With uncommitted changes in the repo it installs your working tree without pulling. If the branch has diverged, it stops and asks you to resolve it.

**To change shared config**, edit the repo, then run `.\tests\Run-Tests.ps1` and `.\scripts\validate.ps1 -RepoOnly`. Commit (on a branch with a PR for anything non-trivial), push, and run `sync.ps1` on each workstation.

**Edited a skill or `CLAUDE.md` block directly in `~/.claude`?** Run `sync.ps1 -Capture` to copy those edits into the repo, review `git diff`, commit, push, then run `sync.ps1` to record the new baseline. Settings are not captured; edit `claude/settings.json` by hand.

**Personal settings** (model, theme, layout, extra permissions) aren't shared; new installs use Claude Code's defaults. Choose yours with `/config` or by editing `settings.json`. Sync keeps local values, and when the repo stops sharing a preference your current value stays. Project permissions belong in each project's `.claude/settings.local.json`, which is never shared.

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
| "running scripts is disabled on this system" | Use `setup.cmd`, or the `powershell -NoProfile -ExecutionPolicy RemoteSigned -File ...` form. If it says the policy is set by Group Policy, ask IT. |
| `winget` is not recognized | Common on a new Windows profile. `install.ps1` and `setup.cmd` register App Installer for your user. If that fails, update "App Installer" from the Microsoft Store (or install Git from git-scm.com) and run `install.ps1` again. |
| `curl.exe` fails or is blocked | Download `install.ps1` from the repository page in a browser instead. If Windows marks it as downloaded from the internet, read it, then run `Unblock-File install.ps1` before running it. |
| An install asks for administrator approval | Setup only uses per-user installs. If a prompt still appears, cancel it and ask IT rather than working around it. |
| `git`, `gh` or `claude` not found right after setup | Setup fixes `PATH` for its own session and your user account. Terminals that were already open keep their old `PATH`, so open a new one. |
| `Claude Code is also installed via winget` / `npm` | Run `setup.cmd` and confirm removal, or run `winget uninstall --id Anthropic.ClaudeCode -e --scope user` / `npm uninstall -g @anthropic-ai/claude-code`. A machine-wide WinGet copy needs IT. |
| `Running as administrator` | Close the elevated window and run setup from a normal terminal, so tools and configuration go to your own account. |
| `... holds an incomplete clone` / `... is not a claude-config clone` | `install.ps1` never deletes folders. Delete the interrupted clone (or pick another folder with `-Path`) and run it again. |
| `The term 'Get-FileHash' is not recognized` | Fixed in this release: Windows PowerShell started from PowerShell 7 couldn't load it. Update the repo (`git pull`), or run `setup.cmd`. |
| Claude Code on Windows complains about Git Bash | Install Git for Windows; Claude Code needs it. |
| `... was modified locally; left unchanged` | Keep it: `sync.ps1 -Capture`, then commit. Discard it: `sync.ps1 -Force` (backed up). |
| `settings.<key> kept local value ...` | Informational: your local value differs from the repo. Change either side to match, or leave it. |
| `settings.<key> is no longer shared; kept your value ...` | Informational, shown once: the repo stopped sharing that preference (after v1.0.0-rc.1, `model`, `theme` and `tui` stopped being shared). Your value stays; change it with `/config` if you like. |
| `settings.json is not valid JSON` | Fix the file (or `restore.ps1 -Latest`), then rerun. Sync never rewrites a file it can't parse. |
| `Local branch has diverged from upstream` | In the repo, `git status` and `git log --oneline --graph --all -10`, resolve it, then rerun. |
| Skills don't show up | Start a new session. Run `validate.ps1`. Check `~/.claude/skills/<name>/SKILL.md` exists. |
| A skill name clashes with a built-in command | `validate.ps1` rejects names on its list of known built-ins (that's why the ship skill is `/vult-ship`). If a newer Claude Code adds a clashing command, rename the skill folder and its `name:`, and add the built-in name to `$reservedNames` in `validate.ps1`. |

## Using it for a team (forks)

Fork the repository and make it yours:

- **Point onboarding at your fork**: change the `$Repository` default in `install.ps1` and the `vult-systems/claude-config` URLs in this README (the `curl.exe` line, the `git clone` example and the Authentication table). Users of a private fork can't download `install.ps1` anonymously. They clone with `git clone <your fork URL>` instead (Git opens the browser to sign in) and run `setup.cmd`.
- **Change the content**: `claude/CLAUDE.md` (global standards), `claude/skills/`, `claude/agents/` and `claude/settings.json`. Keep shared settings to safeguards; `validate.ps1` rejects permission grants, credentials, machine paths and personal email addresses.
- **Rename a skill**, e.g. `/vult-ship`: rename its folder and the `name:` in its `SKILL.md`, then update `$expectedSkills` in `scripts/validate.ps1`, the Skills table above and the list in `claude/CLAUDE.md`. The name must not clash with a built-in Claude Code command. On the next `sync.ps1`, installed copies move to the new name (unless they were edited locally).
- Run `.\tests\Run-Tests.ps1` and `.\scripts\validate.ps1 -RepoOnly`, then roll out with `sync.ps1` on each workstation.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and [SECURITY.md](SECURITY.md) for reporting vulnerabilities. Licensed under the [MIT License](LICENSE).

## Repository maintenance

See [CLAUDE.md](CLAUDE.md) for commands, design decisions and the release process; [CHANGELOG.md](CHANGELOG.md) for history. Version: `VERSION`. CI runs `validate.ps1 -RepoOnly` and the tests on Windows PowerShell 5.1 and PowerShell 7.
