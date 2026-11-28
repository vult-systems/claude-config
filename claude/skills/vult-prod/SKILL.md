---
name: vult-prod
description: Switch this session to production mode - every global production standard in full, including issues, full test suites, independent review, CI, acceptance checklists and release management.
disable-model-invocation: true
---

# /vult-prod

This session is now in **production mode** until another mode skill is invoked.

- Apply every section of the global standards and the project's `CLAUDE.md` in full, with no shortcuts.
- Every change has an issue. Every fix has a regression test that fails without it. Run the full lint and test suite before each push.
- Have `production-reviewer` review every non-trivial diff before its PR.
- Releases go through `/release-candidate` and `/promote-stable`, and acceptance items go in an issue. Fixes stay open until verified where they were reported.
- Ship with `/vult-ship`.

If leaving fast mode, show the deferred list first. Each item must be done or turned into an issue before shipping.
