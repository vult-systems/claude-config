---
name: vult-dev
description: Switch this session to development mode (the default) - planned changes on a branch, relevant regression tests, focused docs, normal PR flow through /vult-ship.
disable-model-invocation: true
---

# /vult-dev

This session is now in **development mode** until another mode skill is invoked. Sessions start in this mode. The rules that hold in every mode (global `CLAUDE.md`, "Working modes") still apply.

- **Plan** multi-file or non-trivial changes briefly and let the user review before editing.
- **Branch** as the global standards say. Commits are focused and reference issues when one exists.
- **Test** new behaviour and bug fixes with automated tests. Run the tests related to the change while iterating; run the full suite before pushing.
- **Document** user-visible changes in the same change (README, docs, `## Unreleased` in `CHANGELOG.md`).
- **Track** bugs and planned work as issues. Small self-contained changes may go straight to a PR.
- **Review** with `production-reviewer` when the change is risky or large.
- **Ship** with `/vult-ship`.

If leaving fast mode, show the deferred list first and work through it before shipping.
