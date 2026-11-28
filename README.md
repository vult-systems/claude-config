# claude-config

Shared Claude Code configuration for Windows workstations. It installs a set of development standards, workflow skills, a review agent and security safeguards into your Claude Code user folder, and keeps every workstation in sync from one Git repository.

- Works as a standard user: no admin rights, no execution policy changes.
- Safe to rerun. Your own settings and edits are kept, and anything replaced is backed up first.
- Use it as is, or fork it as your team's shared configuration ([team setup](docs/team-setup.md)).

## New workstation setup

Open **Windows PowerShell** or **Command Prompt** as yourself (not as administrator), then download the installer, read it, and run it:

```bat
curl.exe -fsSLo install.ps1 https://raw.githubusercontent.com/vult-systems/claude-config/main/install.ps1
notepad install.ps1
powershell -NoProfile -ExecutionPolicy RemoteSigned -File install.ps1
```

The installer gets Git, clones this repository to `%USERPROFILE%\repos\claude-config` and runs `setup.cmd`. Setup asks before it installs or removes anything, then signs you in to GitHub and Claude Code where needed. If you already have a clone, run `setup.cmd` from its folder.

When it finishes, open a new terminal, start `claude` and type `/` to see the skills. Options, sign-in details and what each step does are in [Installation](docs/installation.md).

## Everyday use

Run these from the repository folder:

```powershell
.\scripts\sync.ps1            # pull the latest shared config and install it
.\scripts\validate.ps1        # check tools, sign-in and local drift
.\scripts\restore.ps1 -Latest # undo the last install
```

Add `-DryRun` to `sync.ps1` to preview changes. How sync treats your local edits and settings is in [Configuration and sync](docs/configuration.md).

## Modes

Every session starts in development mode. Type a mode skill to change how much process Claude applies for the rest of the session.

| Skill | Use it for |
|---|---|
| `/vult-fast` | Prototyping. Claude builds directly on a local `exp/` branch with smoke tests only, and defers issues, PRs and changelog to `/vult-ship`. |
| `/vult-dev` | Normal work (the default). A brief plan for non-trivial changes, relevant tests, the usual PR flow. |
| `/vult-prod` | Release-critical work. Every standard in full: plan approval, review, CI, acceptance. |

In every mode, security settings and project rules (such as a feature freeze) still apply, Claude confirms before outward-facing steps, and work reaches the default branch only through `/vult-ship`. See [Skills and modes](docs/skills.md) for the details.

## Skills

**Start and track work**

| Skill | What it does | Example |
|---|---|---|
| `/init-project` | Adds a project `CLAUDE.md`, changelog, version file, CI and labels without overwriting anything. | `/init-project Maya shelf tools in Python` |
| `/issue` | Checks for duplicates, then files a well-formed bug, feature, tech-debt or acceptance issue. | `/issue playblast export ignores frame range` |
| `/production-audit` | Read-only audit of a repository against the standards, with ranked findings. | `/production-audit tests` |

**Ship and release**

| Skill | What it does | Example |
|---|---|---|
| `/vult-ship` | Tests, focused commits, PR, green CI, merge commit, and a check of the default branch. | `/vult-ship 42` |
| `/hotfix` | Smallest safe fix for a released bug, with a regression test and a patch release candidate. | `/hotfix 57` |
| `/release-candidate` | Version bump and changelog, `vX.Y.Z-rc.N` tag, draft pre-release, acceptance issue. | `/release-candidate 1.2.0` |
| `/promote-stable` | Promotes an accepted release candidate to `vX.Y.Z` once acceptance passes and no code has changed. | `/promote-stable v1.2.0-rc.2` |

**Move between machines**

| Skill | What it does | Example |
|---|---|---|
| `/handoff` | Pushes the branch and posts a handoff note on its draft PR. | `/handoff finish the export dialog` |
| `/resume-project` | Syncs the branch, reads the project notes and latest handoff, and lists next steps. | `/resume-project` |

Skills that push, merge, tag or release only run when you type them, and they confirm before each outward-facing step.

## Documentation

- [Installation](docs/installation.md): installer and setup options, sign-in, exit codes
- [Configuration and sync](docs/configuration.md): what gets installed, local edits, personal settings, backups
- [Skills and modes](docs/skills.md): mode rules, the review agent, a typical workflow
- [Troubleshooting](docs/troubleshooting.md): common errors and fixes
- [Team setup](docs/team-setup.md): forking and customizing for your team

Contributions are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md). Report vulnerabilities through [SECURITY.md](SECURITY.md). Release history is in [CHANGELOG.md](CHANGELOG.md). Licensed under the [MIT License](LICENSE).
