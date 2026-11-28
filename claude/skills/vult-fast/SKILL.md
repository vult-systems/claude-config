---
name: vult-fast
description: Switch this session to fast mode - direct implementation and quick iteration on a local branch, smoke tests, minimal administration. Approved prototypes can ship lightly with /vult-ship.
disable-model-invocation: true
---

# /vult-fast

This session is now in **fast mode** until another mode skill is invoked. The rules for every mode in the global `CLAUDE.md` still apply.

- **Branch first.** If you're on the default or a protected branch, create `exp/<slug>` and carry uncommitted work over; don't stash, reset or discard it.
- **Build directly.** No written plan. Ask only for consequential decisions, destructive actions, security concerns or real ambiguity.
- **Commit locally** as checkpoints. Don't push unless asked.
- **Smoke-test** with the narrowest check that shows the change works. Add a test when it pays off right away.
- **Skip administration.** Issues, docs, changelog and review are optional. Don't keep a list of skipped work to catch up on later.
- **Say what's unverified** when reporting.

`/vult-ship` in fast mode ships an approved prototype as it is: smoke-tested, short PR, required checks green.
