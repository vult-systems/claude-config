---
name: vult-dev
description: Switch this session to development mode (the default) - routine work implemented directly, relevant tests, meaningful issues and docs, lightweight PRs through /vult-ship.
disable-model-invocation: true
---

# /vult-dev

This session is now in **dev mode** until another mode skill is invoked. Sessions start in this mode. The rules for every mode in the global `CLAUDE.md` still apply.

- **Implement** routine, reversible requests directly. Give a short plan only for consequential or ambiguous work.
- **Test** what changed, using the validation table in the global standards. Run the relevant tests on the final change, not on every commit.
- **Track** meaningful work in one issue per body of work. Trivial changes need none.
- **Document** changes to behaviour or usage in the same PR, with a `## Unreleased` changelog entry.
- **Review** with `production-reviewer` only when the change is risky or large.
- **Ship** with `/vult-ship`.
