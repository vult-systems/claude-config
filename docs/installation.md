# Installation

The quick start is in the [README](../README.md#new-workstation-setup). This page covers what the installer and setup do, their options, and sign-in.

## install.ps1

`install.ps1` is the fresh-workstation entry point. It is short so you can read it before running it, and it needs nothing preinstalled (`curl.exe` ships with Windows 10 and 11). It:

1. Uses Git if it's present, or offers to install Git for Windows for your user only.
2. Clones this repository to `%USERPROFILE%\repos\claude-config`, or reuses an existing clone there. It never deletes or overwrites a folder.
3. Runs `setup.cmd` from the clone.

| Option | Effect |
|---|---|
| `-Path <folder>` | Clone somewhere else. |
| `-Repository <url>` | Clone a fork instead (see [Team setup](team-setup.md)). |
| `-DryRun` | Report what would be installed or cloned, change nothing. |
| `-Yes`, `-NonInteractive`, `-NoInstall` | Same meaning as for setup (below), and passed on to it. |

Any other option, such as `-SkipAuth` or `-Force`, is passed to setup. To review the whole repository first, clone it yourself (`git clone https://github.com/vult-systems/claude-config`) and run `setup.cmd` from the clone.

## setup.cmd

`setup.cmd` runs `scripts\setup.ps1` with Windows PowerShell 5.1, from Command Prompt, Windows Terminal or PowerShell. Each step checks the current state and does only what's missing:

1. **Tools**: offers to install Git for Windows and GitHub CLI for your user (`winget --scope user`), and Claude Code with the official native installer. On a new Windows profile where winget isn't set up yet, it registers App Installer for your user first.
2. **One Claude Code**: standardizes on the native install, which updates itself. A copy installed with WinGet or npm shadows it on `PATH` and goes stale, so setup offers to remove it. Nothing is removed unless you answer yes (the default is No).
3. **PATH**: adds `%USERPROFILE%\.local\bin` to your user `PATH` if needed and refreshes the running session. The machine `PATH` is never edited.
4. **Sign-in**, only where needed (see [Sign-in](#sign-in)).
5. **Configuration**: backs up anything it replaces, installs the configuration and validates it.

If setup is interrupted or a step fails, fix the problem and run it again. Finished steps are skipped.

| Option | Effect |
|---|---|
| `-DryRun` | Show what would happen without changing anything. |
| `-NoInstall` | Only report: install or remove no software and leave `PATH` alone. |
| `-SkipAuth` | Skip the sign-in and git identity steps. |
| `-NonInteractive` | Never prompt. Steps that need an answer are skipped and the commands to run are printed. |
| `-Yes` | Accept install and sign-in prompts. Removals still ask. |
| `-Force` | Replace managed files you edited locally, after backing them up. |

**Exit codes**: 0 when done, 1 when something still needs fixing, 2 when it finished with warnings. `install.ps1` returns setup's exit code, or 1 if Git or the clone isn't available.

**Permissions**: setup never elevates, changes the execution policy or grants Claude Code permissions. `-ExecutionPolicy RemoteSigned` applies to that one process only, and it can't override a Group Policy (don't try to). PowerShell 7 is optional: everything runs on Windows PowerShell 5.1.

## bootstrap.ps1

`scripts\bootstrap.ps1` installs the configuration only. It checks tools and sign-in without installing anything or prompting, then installs and validates. Options: `-DryRun`, `-Force`, and `-SkipToolCheck` to install even when required tools are missing.

## Sign-in

| Tool | Sign in | Check | Credentials live in |
|---|---|---|---|
| GitHub CLI | `gh auth login --web` | `gh auth status` | Windows Credential Manager |
| git over HTTPS | Git Credential Manager (browser, on first clone) or `gh auth setup-git` | `git ls-remote https://github.com/vult-systems/claude-config` | Windows Credential Manager |
| Claude Code | `claude auth login` (or `/login` in a session) | `claude auth status` | your Claude home, outside this repo |

Setup offers `gh auth setup-git` only if git can't already reach GitHub. For your git `user.name` and `user.email`, it suggests your GitHub name and your private `...@users.noreply.github.com` address, which keeps your email out of public commit history. Use your own identity.

If `claude auth status` fails or prints something setup can't read, setup and `validate.ps1` warn "Could not check Claude Code sign-in" with the error, and setup doesn't start a sign-in. Run `claude auth status` to see the full output.

Credentials are never copied into the repository, and `validate.ps1` fails if credential files, tokens, private keys or history files are committed.
