---
name: release-candidate
description: Cut a release candidate vX.Y.Z-rc.N from the default branch when a release needs real-environment validation first - version and changelog, annotated tag, pre-release, acceptance checklist.
argument-hint: "<X.Y.Z> (rc number is inferred)"
disable-model-invocation: true
---

# /release-candidate

Target version: $ARGUMENTS

Use a release candidate when real-environment validation is outstanding or the release warrants it. Routine releases can go straight to stable with `/promote-stable X.Y.Z`. Follow the project's `CLAUDE.md` or release docs where they exist.

## Gates (stop and report if any fails)

- On the default branch, clean and up to date (`git pull --ff-only`), with the latest CI run on it green.
- No open `release-blocker` issues.
- `CHANGELOG.md` has entries for the release. Derive the bump (breaking: major; feature: minor; fix: patch) and confirm the version with the user. `N` is the next number after `git tag -l "vX.Y.Z-rc.*"`.

## Steps

1. **Version.** If the version source and changelog already name `vX.Y.Z-rc.N` (bumped in the work's PR), skip to step 2. Otherwise branch `release/vX.Y.Z-rc.N`, set the version, rename `## Unreleased` to `## vX.Y.Z-rc.N` above a new empty `## Unreleased`, and merge it through the `/vult-ship` steps.
2. **Tag** the default branch commit: `git tag -a vX.Y.Z-rc.N -m "vX.Y.Z-rc.N"`, check it matches the version source, and push it after the user confirms. Tags are permanent.
3. **Pre-release.** If there's a release workflow, check its draft pre-release has CI-built assets. Otherwise `gh release create vX.Y.Z-rc.N --prerelease --notes-file <file>`. Notes cover the changes, Verified, Not yet verified and known issues. Never upload locally built artifacts or mark an RC as Latest.
4. **Acceptance.** Add the real-environment checks to the version's acceptance issue (`/issue`), or create `Acceptance: vX.Y.Z` with a checklist.

Promote it later with `/promote-stable vX.Y.Z-rc.N`.
