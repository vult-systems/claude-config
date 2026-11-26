# Security policy

claude-config runs on workstations. It installs software for the current user, edits the user `PATH`, and writes Claude Code settings and instructions. Problems in it can affect every machine that syncs it, so security reports are welcome.

## Supported versions

Fixes go into the latest release and its release candidates. Older versions get no backported fixes; update with `scripts\sync.ps1` or rerun `setup.cmd`.

## Reporting a vulnerability

Report privately through GitHub: on the repository's **Security** tab, choose **Report a vulnerability**. Don't open a public issue, pull request or discussion for a vulnerability.

Include what's affected (script, setting or skill, plus version or commit), how to reproduce it, and the impact. Leave out real credentials, tokens and personal data; use placeholders.

You'll get an acknowledgement within 7 days. Once a fix is ready, it ships as a release candidate and the advisory is published, with credit if you'd like it.

## What counts

In scope:
- Scripts that elevate, change the execution policy or system-wide state, or remove software without confirmation.
- Shared settings or skills that grant permissions, weaken Claude Code's safeguards, or leak credentials, conversation history or personal data.
- Ways to make `install.ps1` or `setup.cmd` run code from somewhere other than the repository and the official installers they name (winget, the Claude Code native installer).
- Secrets or personal data committed to the repository.

Out of scope: vulnerabilities in Claude Code, Git, GitHub CLI or winget themselves (report those to their maintainers), and changes you make in your own fork.

## Safeguards built in

- Standard user only: nothing elevates, and the execution policy override applies to one process. Group Policy is never bypassed.
- Software is installed per user and only after confirmation, and removed only after an explicit default-No confirmation.
- Shared settings grant no permissions; they deny reads of `.env`, `*.pem` and `~/.ssh`. `validate.ps1` enforces this in CI, along with checks for credentials, private keys, machine paths and personal email addresses.
- Every file an install replaces is backed up first, and `restore.ps1` puts it back.
