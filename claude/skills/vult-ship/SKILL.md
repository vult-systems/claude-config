---
name: vult-ship
description: Take the current work to a merged pull request at the current mode's level - scope check, proportionate validation, push, PR, required checks, merge commit, branch cleanup.
argument-hint: "[issue number]"
disable-model-invocation: true
---

# /vult-ship

Related issue(s): $ARGUMENTS

Typing `/vult-ship` approves the normal steps below, merge included. Stop and ask only when something is out of scope, a check fails and can't be fixed on task, or the project's `CLAUDE.md` forbids the change (a feature freeze, for example). Work at the current mode; never escalate it.

1. **Context.** `git status`, `git diff`, `git log <default>..HEAD --oneline`, and any related issue. On the default branch, create `<feat|fix|docs|chore>/<slug>` first.
2. **Scope.** Leave unrelated edits unstaged and mention them. Remove debug code; check for secrets, personal paths and generated files.
3. **Validate** in proportion to the change (validation table in the global standards) and the mode:
   - Fast: the smoke test that shows it works.
   - Dev: the tests relevant to the change, and docs and `## Unreleased` changelog where behaviour or usage changed.
   - Prod: the full suite, plus `production-reviewer` on non-trivial diffs. Fix blockers.

   Reuse results already run on the final tree. Leave compatibility matrices to CI.
4. **Commit** the remaining changes descriptively, staging by path, with `Refs #N` where an issue exists. Keep existing commits as they are; don't rebuild history.
5. **PR.** `git push -u origin HEAD`, then `gh pr create --body-file <file>` with a short Summary, Testing (what ran) and Not verified, plus `Refs #N` (`Fixes #N` only if verified). Reuse an existing PR; mark a draft ready with `gh pr ready`.
6. **Checks.** `gh pr checks --watch --required`. On a failure, read `gh run view <id> --log-failed`, fix it in a new commit and repeat. Never bypass a failed required check.
7. **Merge** with `gh pr merge --merge --delete-branch`, then `git switch <default>`, `git pull --ff-only` and `git branch -d <branch>` if it's still there.
8. **Report** the PR URL and what was and wasn't verified. Where an issue is linked, comment once with the same. Don't start releases, audits or other follow-up work.
