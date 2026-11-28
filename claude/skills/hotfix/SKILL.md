---
name: hotfix
description: Ship the smallest safe fix for a confirmed bug in a released version - reproduction, regression test, minimal fix, PR, and a patch release.
argument-hint: "<issue number or bug description>"
disable-model-invocation: true
---

# /hotfix

Bug: $ARGUMENTS

Follow the project's `CLAUDE.md` where it defines its own procedure, for example during a feature freeze.

1. **Confirm the bug.** Reproduce it. If you can't, stop and say so. Record it in an issue (`/issue`) unless it's trivial.
2. **Pick the base.** Normally the default branch: `fix/<slug>`. If the default branch has unreleased work that mustn't ship yet, branch from the latest release tag, tell the user, and bring the fix to the default branch afterwards.
3. **Regression test first** where practical: it fails before the fix and passes after.
4. **Fix the root cause minimally.** No refactoring, cleanup or dependency changes unless the dependency is the bug.
5. **Validate** the regression test and the tests around the fix. Note anything only the real environment can confirm.
6. **Record it** under `### Fixed` in `## Unreleased` of `CHANGELOG.md`: effect, root cause, `#N`. Bump the patch version in the same PR if releasing right away.
7. **Ship** through the `/vult-ship` steps.
8. **Release** the patch with `/promote-stable X.Y.Z`, or `/release-candidate` if the fix needs checking in a real environment first. Leave the issue open until the fix is verified where it was reported.
