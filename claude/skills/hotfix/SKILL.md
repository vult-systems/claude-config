---
name: hotfix
description: Ship the smallest safe fix for a confirmed bug in a released version - issue with reproduction, regression test, minimal fix, PR with green CI, patch release candidate.
argument-hint: "<issue number or bug description>"
disable-model-invocation: true
---

# /hotfix

Bug: $ARGUMENTS

Follow the project's `CLAUDE.md` where it defines its own procedure, for example during a feature freeze.

1. **Confirm the bug.** It needs an issue with a reproduction; use `/issue` if it has none. If you can't reproduce it, stop and say so. Label it `bug`, and `release-blocker` if it blocks a release.
2. **Pick the base.** Find the latest stable tag (`git tag --sort=-v:refname`) and what's on the default branch since then (`git log <tag>..HEAD --oneline`).
   - Normally branch from the default branch: `fix/<issue>-<slug>`.
   - If the default branch has unreleased work that mustn't ship yet, branch from the tag and tell the user. The fix must still reach the default branch through its own PR.
3. **Regression test first.** Write a test that reproduces the bug and check that it fails.
4. **Fix the root cause minimally.** No refactoring, unrelated cleanup or dependency changes, unless the dependency is the bug.
5. **Verify.** Run the full lint and test suite; the new test now passes. Note anything only real hardware or a real environment can confirm.
6. **Record it.** Add a `### Fixed` entry under `## Unreleased` in `CHANGELOG.md` with the effect, root cause and `#N`. Commit with `Refs #N`.
7. **PR.** Push, then `gh pr create` with root cause, fix, verification and what's unverified. Wait for CI with `gh pr checks --watch`. Merge with a merge commit after the user confirms, then confirm CI on the default branch.
8. **Issue comment.** Root cause, commits, what was verified and how, what wasn't. Leave the issue open until it's verified where it was reported.
9. **Release.** Bump the patch version through `/release-candidate`. Release straight to stable only if the project's `CLAUDE.md` allows it and verification is complete.
