---
name: vult-fast
description: Switch this session to fast mode - direct implementation and quick iteration on a local experimental branch, smoke tests only, GitHub housekeeping deferred until /vult-ship.
disable-model-invocation: true
---

# /vult-fast

This session is now in **fast mode** until another mode skill is invoked. The rules that hold in every mode (global `CLAUDE.md`, "Working modes") still apply.

- **Branch first.** Never commit to the default branch or a protected branch. If you're on one, create `exp/<slug>` and carry uncommitted work over; don't stash, reset or discard it.
- **Build directly.** Skip the written plan unless the change is risky or ambiguous. Ask only when blocked.
- **Commit as you go.** WIP commits are fine; `/vult-ship` reshapes them later.
- **Smoke-test.** Run the narrowest check that shows the change works (one test, the script, the command). The full suite, independent review and lint are optional.
- **Defer housekeeping.** No issues, PRs, changelog entries, pushes or issue comments unless asked. Keep a running list of what's deferred (tests to write, docs, changelog, issue) and show it when asked or when leaving fast mode.
- **Still say what's unverified.** Report which checks ran and which didn't.

To take the work to production, switch to `/vult-dev` or `/vult-prod` and run `/vult-ship`.
