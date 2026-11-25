---
name: release-candidate
description: Cut a release candidate vX.Y.Z-rc.N from the default branch - version bump and changelog via PR, annotated tag, CI-built draft pre-release, and a manual acceptance issue.
argument-hint: "<X.Y.Z> (rc number is inferred)"
disable-model-invocation: true
---

# /release-candidate

Target version: $ARGUMENTS

Follow the project's `CLAUDE.md` or release docs where they exist; this is the default procedure.

## Gates (stop and report if any fails)

- On the default branch, clean and up to date (`git pull --ff-only`).
- CI is green on the default branch (`gh run list --branch <default> -L 3`).
- No open `release-blocker` issues (`gh issue list --label release-blocker`).
- `## Unreleased` in `CHANGELOG.md` has entries.
- Version: derive the bump from the changelog (breaking change: major; feature: minor; fix: patch) and confirm it with the user. `N` is the next number after `git tag -l "vX.Y.Z-rc.*"`.

## Steps

1. Branch `release/vX.Y.Z-rc.N`. Change only the version source and the changelog: rename `## Unreleased` to `## vX.Y.Z-rc.N` and add an empty `## Unreleased` above it. Commit `Release vX.Y.Z-rc.N`.
2. Open a PR and wait for green CI. Merge with a merge commit once the user confirms, then pull the default branch.
3. Tag the merged commit: `git tag -a vX.Y.Z-rc.N -m "vX.Y.Z-rc.N"`. Check the tag matches the version source. **Confirm, then** `git push origin vX.Y.Z-rc.N`. Tags are permanent.
4. If there's a release workflow, watch it (`gh run watch`) and check that it creates a draft pre-release with CI-built assets and checksums. If there isn't one and the project has no build artifacts, run `gh release create vX.Y.Z-rc.N --draft --prerelease --notes-file <file>`. Never upload locally built artifacts.
5. Draft notes cover the changes, **Verified**, **Not yet verified**, known issues and checksums. Publish only as a pre-release, never as Latest, and only after the user confirms.
6. Create or update the acceptance issue `Acceptance: vX.Y.Z` with `/issue`, with a checklist of manual checks against this RC. Label fixes awaiting those checks `awaiting-acceptance`.

Promote to stable later with `/promote-stable`.
