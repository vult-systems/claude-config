---
name: promote-stable
description: Promote an accepted release candidate to stable vX.Y.Z - verify acceptance passed and no code changed since the RC, release commit with only version and changelog, tag, CI-built draft release.
argument-hint: "<vX.Y.Z-rc.N>"
disable-model-invocation: true
---

# /promote-stable

Release candidate: $ARGUMENTS (default: the newest `git tag -l "v*-rc.*" --sort=-v:refname`).

Follow the project's `CLAUDE.md` or release docs where they exist.

## Gates (stop and report every one that fails)

- The acceptance issue for this version has every item checked, with results recorded (`gh issue view <n>`).
- No open `release-blocker` issues.
- CI is green on the default branch.
- No code has changed since the RC: `git diff vX.Y.Z-rc.N..<default> --stat` shows only docs, changelog or CI config. Any code change needs a new RC, not a promotion.

## Steps

1. Branch `release/vX.Y.Z`. Set the version source to `X.Y.Z`. Add a `## vX.Y.Z` section to `CHANGELOG.md` that summarises the RC sections, and keep the RC sections. Commit `Release vX.Y.Z`.
2. Open a PR and wait for green CI. Merge with a merge commit once the user confirms, then pull.
3. `git tag -a vX.Y.Z -m "vX.Y.Z"` on the merged commit. **Confirm, then** push the tag.
4. Check that the release workflow made a draft with CI-built assets. Write the notes: changes since the last stable release, **Verified** (link the acceptance issue), known limitations, checksums. Publishing it as Latest is the user's step unless they say otherwise.
5. Close the acceptance issue, and the `awaiting-acceptance` issues whose checks passed, each with a comment naming the release. Never delete or re-tag the RCs.
6. Update the "Current state" section of the project's `CLAUDE.md` through a small PR.
