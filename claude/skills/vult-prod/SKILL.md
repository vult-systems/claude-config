---
name: vult-prod
description: Switch this session to production mode - planned changes, independent review, full regression, compatibility and security validation, and formal release acceptance where warranted.
disable-model-invocation: true
---

# /vult-prod

This session is now in **production mode** until another mode skill is invoked. Use it for critical infrastructure, high-risk changes and major releases.

- **Plan** consequential or multi-file changes and wait for approval before editing.
- **Track** every change in an issue. Every fix gets a regression test that fails without it.
- **Validate** fully: the whole test suite, compatibility, security and deployment implications. Still don't repeat a check whose inputs haven't changed.
- **Review** every non-trivial diff with `production-reviewer` before its PR.
- **Release** through `/release-candidate` and `/promote-stable` with an acceptance checklist when real-environment checks are outstanding. Fixes stay open until verified where they were reported.
- **Ship** with `/vult-ship`.
