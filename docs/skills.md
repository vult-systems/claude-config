# Skills and modes

The skill list with examples is in the [README](../README.md#skills). This page explains how modes work and how the skills fit together.

## How modes work

Sessions start in dev mode. `/vult-fast`, `/vult-dev` and `/vult-prod` switch the mode for the rest of the session, and the most recent one wins. Process scales with the risk of the work, and every skill, `/vult-ship` included, works at the current mode instead of escalating it.

| | Fast | Dev (default) | Prod |
|---|---|---|---|
| Planning | None | Only for consequential or ambiguous work | Plan consequential changes and wait for approval |
| Validation | Smoke test | Tests relevant to the change | Full regression, compatibility, security and deployment checks |
| Issues | Optional | One per meaningful body of work | Every change tracked |
| Docs, changelog | Optional | When behaviour or usage changes | Always kept in sync |
| Review | None | When the risk justifies it | Independent review of non-trivial diffs |
| Budget | 2-5 min | 5-10 min | 15-30 min |

The budget is a soft target for validation and administration, not for the implementation. Claude says why when a change needs more.

Validation follows what changed in every mode: a docs edit gets link, accuracy and formatting checks; a bug fix gets a targeted regression test; dependency and build changes get build and compatibility checks. Claude tests the final change rather than every commit, doesn't repeat a passing check unless its inputs changed, and leaves compatibility matrices to CI.

These hold in every mode:

- Security settings, and asking before consequential, destructive, security-sensitive or out-of-scope steps.
- The project's own `CLAUDE.md`, including any feature freeze.
- Nothing is committed to the default branch directly; work reaches it through a PR.
- Failed required checks are never bypassed, and Claude reports what it verified and what it didn't.

Your own text outside the managed block in your Claude home's `CLAUDE.md` can adjust how a mode plans and asks. Installs never overwrite it.

## Who can run a skill

The mode skills, and the skills that push, merge, tag or release, run only when you type them. Typing `/vult-ship` approves its normal steps (push, PR, merge once required checks pass, branch cleanup). Tags and releases are confirmed first. `/issue`, `/production-audit` and `/resume-project` can also be started by Claude when the task calls for them.

## Review agent

The `production-reviewer` agent gives an independent, read-only review of a branch, diff or PR: correctness, scope creep, missing tests, docs drift, secrets and release consistency. `/vult-ship` uses it in prod mode, and you can ask for it for any risky change ("review this branch with the production-reviewer agent").

## Releases

Routine releases go straight to stable with `/promote-stable X.Y.Z` once their changes are validated. Use `/release-candidate` when a release needs checks in a real environment first (new workstations, hardware, managed machines), run the acceptance checklist, then `/promote-stable vX.Y.Z-rc.N`. The version bump and changelog can go in the work's own PR, and the release skills skip their release PR when they find it already done.

## A typical workflow

1. `/resume-project` at the start of a session to see where things stand.
2. Work on a branch. Track meaningful work with `/issue`; small fixes need none. Use `/vult-fast` to try an idea quickly.
3. `/vult-ship` to validate, open the PR, wait for the required checks and merge.
4. `/handoff` before switching machines, then `/resume-project` on the other one.
5. Release with `/promote-stable`, or `/release-candidate` first when real-environment checks are needed. A bug found in a release goes through `/hotfix`.
