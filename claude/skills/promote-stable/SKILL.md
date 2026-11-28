---
name: promote-stable
description: Publish stable vX.Y.Z - either promote an accepted release candidate unchanged, or release the default branch directly when routine validation is enough. Version and changelog, tag, release.
argument-hint: "<vX.Y.Z-rc.N | X.Y.Z>"
disable-model-invocation: true
---

# /promote-stable

Release: $ARGUMENTS (default: the newest `git tag -l "v*-rc.*" --sort=-v:refname`).

Follow the project's `CLAUDE.md` or release docs where they exist, including any rule that stable releases need an RC.

## Gates (stop and report every one that fails)

- On the default branch, clean and up to date, with the latest CI run on it green.
- No open `release-blocker` issues.
- **Promoting an RC:** its acceptance checklist is complete with results recorded, and `git diff vX.Y.Z-rc.N..<default> --stat` shows only docs, changelog or CI config. A code change needs a new RC.
- **Direct release (`X.Y.Z`):** the changes since the last release were validated in proportion (their PRs say how), and none needs a real-environment check that hasn't happened. Confirm the version with the user.

## Steps

1. **Version.** If the version source and changelog already name `vX.Y.Z`, skip to step 2. Otherwise branch `release/vX.Y.Z`, set the version, and add a `## vX.Y.Z` changelog section (summarising the RC sections, which stay, or renaming `## Unreleased`). Merge it through the `/vult-ship` steps.
2. **Tag** `git tag -a vX.Y.Z -m "vX.Y.Z"` on the default branch and push it after the user confirms.
3. **Release.** Check the release workflow's draft has CI-built assets, or run `gh release create vX.Y.Z --notes-file <file>` when there are no artifacts. Notes: changes since the last stable release, Verified (link the acceptance issue if any), known limitations. Publishing as Latest is the user's step unless they say otherwise. The previous release stays available for rollback.
4. **Close** the acceptance issue and the issues whose checks passed, each with a comment naming the release. Never delete or re-tag RCs.
5. **Update** "Current state" in the project's `CLAUDE.md` in the same release PR where possible, otherwise in a small follow-up.
