# Skills and modes

The skill list with examples is in the [README](../README.md#skills). This page explains how modes work and how the skills fit together.

## How modes work

Sessions start in development mode. `/vult-fast`, `/vult-dev` and `/vult-prod` switch the mode for the rest of the session, and the most recent one wins. The mode decides how much process work on a branch gets:

- **Fast**: Claude implements directly on a local experimental branch and asks only about consequential decisions, destructive actions, security concerns or real ambiguity. It keeps a list of what it deferred (tests, docs, changelog, issue) and shows it when asked.
- **Development**: for multi-file or non-trivial work, Claude gives a brief plan when one is needed and waits for your review before editing.
- **Production**: Claude gives a plan and waits for approval before any multi-file or non-trivial edit, and applies every standard in full.

These hold in every mode:

- Security settings and confirmation before outward-facing steps (pushing, merging, tagging, releasing, closing issues).
- The project's own `CLAUDE.md`, including any feature freeze.
- Experimental work never goes to the default branch directly. It gets there through `/vult-ship`, which brings it up to the full standards first.

Your own text outside the managed block in your Claude home's `CLAUDE.md` can adjust how a mode plans and asks. Installs never overwrite it, and it can't relax the rules above.

## Who can run a skill

The mode skills, and the skills that push, merge, tag or release, run only when you type them. Claude never starts them on its own, and they confirm before each outward-facing step. `/issue`, `/production-audit` and `/resume-project` can also be started by Claude when the task calls for them.

## Review agent

The `production-reviewer` agent gives an independent, read-only review of a branch, diff or PR: correctness, scope creep, missing tests, docs and changelog drift, secrets and release consistency. `/vult-ship` uses it for non-trivial changes, and you can ask for it directly ("review this branch with the production-reviewer agent").

## A typical workflow

1. `/resume-project` at the start of a session to see where things stand.
2. `/issue` to track the bug or feature, then work on a branch. Use `/vult-fast` to try an idea quickly.
3. `/vult-ship` to test, commit, open the PR, wait for green CI and merge.
4. `/handoff` before switching machines, then `/resume-project` on the other one.
5. When a version is ready: `/release-candidate`, run the acceptance checklist on real workstations, then `/promote-stable`. A bug found in a release goes through `/hotfix`.
