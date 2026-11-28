---
name: production-audit
description: Read-only audit of the current repository against the standards, in proportion to what the project is - CI, tests, versioning, changelog, builds, portability, security and docs. Produces ranked findings with evidence. Use before a major release or when adopting an existing project.
argument-hint: "[focus area]"
---

# /production-audit

Audit the repository in the current directory. Focus, if given: $ARGUMENTS

**Read-only.** Don't edit files, change git state, or write to GitHub. You may run the project's tests, lint and build when they are safe and local.

Read the project's `CLAUDE.md` first and audit against it as well as the global standards. Judge findings by the project's risk: an internal tool doesn't need what a published product does. Back every finding with evidence: `file:line`, a command and its output, or a URL.

## Checks

1. **Repository**: `git status`; default branch; stale branches; branch protection (`gh api repos/{owner}/{repo}/branches/<default>/protection`; a 404 means none).
2. **Secrets**: `git ls-files` for `.env`, keys, credential files, `settings.local.json`; grep tracked files for tokens and private keys; `.gitignore` coverage.
3. **CI**: runs on PRs and the default branch without duplicate push and PR runs; change-aware, with a required gate check that path filtering can't leave pending; actions pinned to SHAs; least-privilege `permissions:`; recent runs on the default branch (`gh run list --branch <default> -L 5`).
4. **Tests**: a suite exists and passes (run it); recent fixes have regression tests where practical.
5. **Versioning and releases**: one version source; semver tags; `CHANGELOG.md` with `## Unreleased` and a section per release; release artifacts built by CI.
6. **Builds and deployment**: locked dependencies; no hardcoded usernames or absolute paths; works without admin; clear failure messages.
7. **Docs**: README covers setup and usage; the commands in `CLAUDE.md` and README work.
8. **Dependencies**: unused or unjustified ones. Don't install new scanners to check.
9. **Issues**: open `release-blocker` issues.

## Report

1. Findings table, most severe first: severity (`blocker` / `high` / `medium` / `low`), area, evidence, recommended fix.
2. What passed, briefly.
3. What you couldn't verify, and why.

Then offer to file `blocker` and `high` findings with `/issue`, grouped into one issue where they're related. Only file after the user confirms.
