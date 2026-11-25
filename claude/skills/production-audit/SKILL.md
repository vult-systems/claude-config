---
name: production-audit
description: Read-only audit of the current repository against the production standards - issues, CI, tests, versioning, changelog, reproducible builds, portability, security and docs. Produces ranked findings with evidence. Use before a release or when adopting an existing project.
argument-hint: "[focus area]"
---

# /production-audit

Audit the repository in the current directory. Focus, if given: $ARGUMENTS

**Read-only.** Don't edit files, change git state, or write to GitHub. You may run the project's tests, lint and build when they are safe and local.

Read the project's `CLAUDE.md` first and audit against it as well as the global standards. Back every finding with evidence: `file:line`, a command and its output, or a URL.

## Checks

1. **Repository**: `git status`; default branch; stale branches; branch protection (`gh api repos/{owner}/{repo}/branches/<default>/protection`; a 404 means none).
2. **Secrets**: `git ls-files` for `.env`, keys, credential files, `settings.local.json`; grep tracked files for tokens and private keys; `.gitignore` coverage.
3. **CI**: workflows run on push and PR; lint and tests; actions pinned to SHAs; least-privilege `permissions:`; recent runs on the default branch (`gh run list --branch <default> -L 5`).
4. **Tests**: a suite exists and passes (run it); recent fixes have regression tests; a manual acceptance checklist exists for what CI can't cover.
5. **Versioning and releases**: a single version source; tags are semver (`git tag --sort=-v:refname`); `CHANGELOG.md` has `## Unreleased` and a section per tag; releases are built by CI, not uploaded by hand.
6. **Builds and deployment**: locked dependencies; reproducible build steps; no hardcoded usernames or absolute paths; works without admin; clear failure messages; a self-test or diagnostics command.
7. **Docs**: README covers setup, usage and troubleshooting; the commands in `CLAUDE.md` and README actually work.
8. **Dependencies**: unused or unjustified ones. Don't install new scanners to check.
9. **Issues**: open `release-blocker` issues; bugs closed without a verification comment.

## Report

1. Findings table, most severe first: severity (`blocker` / `high` / `medium` / `low`), area, evidence, recommended fix.
2. What passed, briefly.
3. What you couldn't verify, and why.

Then offer to file `blocker` and `high` findings with `/issue`. Only file after the user confirms.
